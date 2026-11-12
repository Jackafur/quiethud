-- The core: the settings table (DB), the state the files share, writing opacity only when it changes (woc), waking the main
-- loop, the frame lists (rebuildLists) and the saved file (initDB).
local _, ns = ...
local DEFAULTS, SETTINGS_VERSION, SPLIT, SPLIT_BY = ns.DEFAULTS, ns.SETTINGS_VERSION, ns.SPLIT, ns.SPLIT_BY
local DEFAULT_LISTS, ALL_LISTS, BAR_DEFS = ns.DEFAULT_LISTS, ns.ALL_LISTS, ns.BAR_DEFS
local EXTRA_BUTTONS, KNOWN_BAR_FRAMES, WRITE_ORDER = ns.EXTRA_BUTTONS, ns.KNOWN_BAR_FRAMES, ns.WRITE_ORDER
local SELF_FADING, ACTION_BARS, HOSTED = ns.SELF_FADING, ns.ACTION_BARS, ns.HOSTED

local DB = { extra = {} }
for k, v in pairs(DEFAULTS) do DB[k] = v end

-- Whether a split group fades, and what brings it up. The Dominos row follows the Action bars row until it has settings of
-- its own (see SPLIT).
local function gFade(s)
	local v = DB[s.fadeKey]
	if v == nil and s.follows then return DB[s.follows[1]] end
	return v
end
local function gTrig(s)
	local v = DB[s.trigKey]
	if v == nil and s.follows then return DB[s.follows[2]] end
	return v
end
local LISTS = {}
-- Shared state, changed in more than one file: the fallback weapon guess (Weapon.lua); until when new quest info, a new zone,
-- a chat message, the end of a fight and moving keep their elements shown; the frames that count for the action bars' mouse
-- over and the action bars found by name (rebuildLists); /qhud debug.
ns.drawn, ns.questUntil, ns.mapUntil, ns.chatUntil, ns.combatEnd, ns.moveUntil = false, 0, 0, 0, 0, 0
ns.peekUntil = 0   -- the "hold to show" key: everything is shown until this time
ns.barHover, ns.discovered = {}, {}
-- Buttons that another addon has moved out of their bar (bars[i] for Action Bar i, extra[k] for the sets in EXTRA_BUTTONS):
-- faded on their own and counted for mouse over. ignoring: the buttons told to ignore their parent's opacity (checkElsewhere).
local elsewhere = { bars = {}, extra = {}, ignoring = {} }
ns.debugOn = false

-- Write on change. Setting the opacity of every faded frame on every frame drawn costs about 50 SetAlpha calls a frame at
-- idle, up to about 180 with another addon's buttons out of their bars. So a group is written when its opacity changes, and
-- when something else could have changed its frames: the lists, a setting, buttons moving out of or back into their bar, an addon loading,
-- a listed frame being made later. A frame QuietHUD holds below full opacity is watched: the game or another addon setting
-- it back (RestedXP on every redraw of its targets window) is undone in the same call, by a hook on that frame's SetAlpha,
-- not a frame later. An opacity moved without a SetAlpha call (an animation, as on the loss of control frame) is caught on
-- the half-second pass (woc.drift). At full opacity a frame is let go: nothing is held there, so a frame that left a group,
-- or an unticked bar, is another addon's to set. The cast bar and the breath bar are the exception: the game puts them to
-- full itself at every cast, so while a cast or a timer runs they are written every frame (SELF_FADING).
local woc = {
	applied = {}, all = {},         -- per group: the opacity last written, and whether it went to every action bar
	names = {}, selfFading = {},    -- every frame name in a list; the groups with a cast bar or a breath bar in them
	owner = {},                     -- frame name -> the list that owns it (the last in WRITE_ORDER that holds the name)
}
do
	local want = setmetatable({}, { __mode = "k" })    -- frame -> the opacity QuietHUD holds it at (below full)
	local hooked = setmetatable({}, { __mode = "k" })
	local written = setmetatable({}, { __mode = "k" }) -- every frame QuietHUD has written at least once
	-- Frames another addon hid by setting their opacity to 0. EllesmereUI hides the game's main action bar that way and keeps
	-- it in place; QuietHUD's own opacity put back over that showed the bar's art behind EllesmereUI's bars. So such a frame
	-- is left at 0 and nothing is written to it until something shows it again (its owner setting it
	-- above 0, or the half-second pass seeing it above 0), then QuietHUD takes it back. In the 1.60.1 UI source the game
	-- sets no frame in QuietHUD's lists to a plain 0 (the chat tabs go down to 0.2); the loss of control alert can pass
	-- through a computed 0 as it runs out, and its next update sets 1, which takes it back.
	local yielded = setmetatable({}, { __mode = "k" })
	-- The Low health column's value per frame (a hidden value from the game, only ever handed back to SetAlpha, never
	-- compared): what keep and the drift pass put back over the plain want (ChatGPT's audit of Nov 6, F1).
	local lowKept = setmetatable({}, { __mode = "k" })
	local writing = false
	local function num(a) return type(a) == "number" and not (issecretvalue and issecretvalue(a)) end
	-- Someone else set a held frame's opacity: QuietHUD's goes back on in the same call, unless they hid it (see yielded).
	local function keep(f, a)
		if writing then return end
		if num(a) then
			if a < 0.01 then
				yielded[f], want[f], lowKept[f] = true, nil, nil
				return
			elseif yielded[f] then
				yielded[f] = nil
				woc.forget() -- (shown again by its owner: written at the next update)
				return
			end
		end
		if not DB.enabled then return end
		local w = want[f]
		if w == nil then return end
		-- (a frame with a Low health or Low mana overlay is written again also when the outside value equals the plain one: that
		-- write dropped the overlay; audit 2026-11-06 pre-1.6.0 F3)
		if not lowKept[f] and type(a) == "number" and not (issecretvalue and issecretvalue(a)) and math.abs(a - w) < 0.005 then return end
		writing = true
		pcall(f.SetAlpha, f, w)
		if lowKept[f] then pcall(f.SetAlpha, f, lowKept[f]) end
		writing = false
	end
	woc.write = function(f, a)
		if yielded[f] then return end
		-- (a WackyBars bar shown while its key is held: up to the Action bars' Shown, as under the mouse; QuietHUD_HeldBar)
		if woc.lift[f] and type(a) == "number" then a = math.max(a, woc.liftTo()) end
		-- The hook goes on every written frame, also one written at full, so another addon hiding it later is seen (tried
		-- again at the next write if the game refused it once).
		if not hooked[f] then hooked[f] = pcall(hooksecurefunc, f, "SetAlpha", keep) or nil end
		if not written[f] then
			-- First sight: a frame already at 0 that QuietHUD never wrote was hidden by another addon, shown or not (one
			-- set to 0 and hidden, then shown again by the game with no SetAlpha call, stays at 0).
			local okA, now = pcall(f.GetAlpha, f)
			if okA and num(now) and now < 0.01 then
				yielded[f] = true
				return
			end
			written[f] = true
		end
		want[f] = (a < 0.999) and a or nil
		writing = true
		local ok, err = pcall(f.SetAlpha, f, a)
		-- The Low health column (ActionBars.lua): over a faded bar goes the opacity the game works out from your health
		-- (a hidden value, so only the game can use it). want keeps the plain a: the drift pass cannot read the result and
		-- leaves it alone; a frame another addon sets gets it back from keep (lowKept).
		if ok and woc.lowAlpha and a == woc.lowFor then
			pcall(f.SetAlpha, f, woc.lowAlpha)
			lowKept[f] = woc.lowAlpha
		else
			lowKept[f] = nil
		end
		writing = false
		if not ok then error(err, 0) end -- (said once by the loop; the flag is clear by then)
	end
	-- Every group is written again at the next update.
	woc.forget = function()
		woc.applied, woc.all = {}, {}
		woc.moA, woc.mbA = {}, {} -- (the mouse over list and the mouse over bars are written again too)
	end
	-- Twice a second: a held frame whose opacity moved without a SetAlpha call gets QuietHUD's back, and a frame left to
	-- another addon (yielded) that is above 0 again, however it got there, is QuietHUD's again.
	woc.drift = function()
		for f in pairs(yielded) do
			local ok, a = pcall(f.GetAlpha, f)
			if ok and num(a) and a >= 0.01 then
				yielded[f] = nil
				woc.forget()
			end
		end
		if not DB.enabled then return end
		for f, w in pairs(want) do
			local ok, a = pcall(f.GetAlpha, f)
			-- (with an overlay kept the game reads back a hidden value; a plain one means the overlay was dropped)
			if ok and type(a) == "number" and not (issecretvalue and issecretvalue(a)) and (math.abs(a - w) > 0.01 or lowKept[f]) then
				writing = true
				pcall(f.SetAlpha, f, w)
				if lowKept[f] then pcall(f.SetAlpha, f, lowKept[f]) end
				writing = false
			end
		end
	end
	-- A listed frame made after its group was last written (an addon making its window on demand) is faded at the next update.
	pcall(hooksecurefunc, "CreateFrame", function(_, name)
		if type(name) == "string" and woc.names[name] then woc.forget() end
	end)
end

-- The sleeping loop. update() (Loop.lua) runs every frame only while a fade is moving (loop.moving, set by update itself).
-- Otherwise it runs ten times a second, and at
-- once when something wakes it (wakeLoop): a game message (combat, a target, a cast, moving, a zone, the sheath key, a
-- timer, health or power), the mouse entering or leaving a listed frame, a setting, a slash command. The tick keeps it right
-- on its own for anything that lasts; a wake only makes it instant. What a tick can miss is something shorter than a tenth
-- of a second that leaves no trace: with a Mouse move column ticked, the cursor leaving and coming back to the very same
-- spot between two looks (accepted; a mouse press has a message and wakes it).
local loop = { clock = 0, wake = true, moving = false, hovered = setmetatable({}, { __mode = "k" }) }
local function wakeLoop() loop.wake = true end
-- WackyBars' bars that show only while a key is held (Hypershift, Shift, Ctrl; its Hold.lua; the owner, Nov 12: "follows
-- qhuds transparency", then none showed: his idle opacity is 0 and their rows Mouse over only). While one shows, its holders
-- come up to the Action bars' Shown opacity, as a bar under the mouse does; let go, they are written as before. Cost: one
-- table look per written frame; on each press and release every group is written again once (woc.forget).
woc.lift = setmetatable({}, { __mode = "k" })
woc.liftTo = function()
	local ov = DB.ovBars
	return (ov and ov > 0) and math.max(ov, 0.1) or (DB.base or 0.6)
end
QuietHUD_HeldBar = function(holders, on)
	for _, h in ipairs(holders or {}) do woc.lift[h] = on and true or nil end
	woc.forget()
	wakeLoop()
end
-- Frames as big as the screen: always under the mouse, so they never count as mouse over and get no hover hook.
woc.noHover = setmetatable({}, { __mode = "k" })
-- The mouse entering or leaving a frame wakes the loop (a frame with no mouse never fires these: the tick sees it).
-- Hooking OnEnter switches the mouse on for a frame in this client (Dominos' tooltip code says the same of its own wrap),
-- so a container that lets clicks through would catch every click over its whole box (a Dominos bar's wide frame around its
-- buttons, over the middle of the screen: no talking to NPCs or turning the camera behind it). The frame's mouse goes back to
-- what it was, so only frames that already took the mouse fire these. A protected frame cannot change its mouse in a fight:
-- it is hooked when the fight ends (loop.pending, woc.hookAll), not at the next list rebuild, which after a /reload in a
-- fight could be the next loading screen.
local function hookHover(f)
	if type(f) ~= "table" or not f.HookScript or woc.noHover[f] then return end
	-- (WackyBars' holders: their buttons take the mouse, not they; each button is hooked once, whichever holder it is in)
	if type(f.qhudButtons) == "table" then
		for _, b in ipairs(f.qhudButtons) do hookHover(b) end
		return
	end
	if loop.hovered[f] then return end
	if InCombatLockdown and InCombatLockdown() and f.IsProtected and f:IsProtected() then
		loop.pending = true
		return
	end
	local okC, click = pcall(function() return f:IsMouseClickEnabled() end)
	local okM, motion = pcall(function() return f:IsMouseMotionEnabled() end)
	local okE, any = pcall(function() return f:IsMouseEnabled() end)
	loop.hovered[f] = true
	pcall(f.HookScript, f, "OnEnter", wakeLoop)
	pcall(f.HookScript, f, "OnLeave", wakeLoop)
	if okC and okM and f.SetMouseClickEnabled and f.SetMouseMotionEnabled then
		pcall(f.SetMouseClickEnabled, f, click and true or false)
		pcall(f.SetMouseMotionEnabled, f, motion and true or false)
	elseif okE and f.EnableMouse then
		pcall(f.EnableMouse, f, any and true or false)
	end
end
woc.hookHover = hookHover -- (WackyBars' buttons, after it sorts them: QuietHUD_RefreshBarClicks, ActionBars.lua)

-- Debug output: printed, and also kept in DB.trace (saved to the addon's saved-variables file on /reload).
local function trace(msg)
	if not ns.debugOn then return end
	print(msg)
	DB.trace = DB.trace or {}
	DB.trace[#DB.trace + 1] = string.format("%.1f %s", GetTime(), msg)
	if #DB.trace > 300 then table.remove(DB.trace, 1) end
end

local function discoverBars()
	ns.discovered = {}
	for k, v in pairs(_G) do
		if type(k) == "string" and k:find("^MultiBar") and not k:find("Button") and type(v) == "table"
			and type(v.GetObjectType) == "function" then
			local ok, kind = pcall(v.GetObjectType, v)
			if ok and kind == "Frame" then ns.discovered[#ns.discovered + 1] = k end
		end
	end
	table.sort(ns.discovered)
end

-- Frames the pixel shift checkboxes add to the shift group. They are protected frames, so they only move out of combat.
local SHIFT_FRAMES = {
	bars = {
		"MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "MultiBar5", "MultiBar6",
		"MultiBar7", "MultiBar8", "StanceBar", "PetActionBar", "PossessActionBar", "StatusTrackingBarManager", "MicroMenuContainer",
		"BagsBar", "MultiCastActionBarFrame", "GamepadMainActionBarFrame",
		"WackyBarsPlain", "WackyBarsShift", "WackyBarsCtrl", "WackyBarsAlt", "WackyBarsMousePlain", "WackyBarsMouseShift",
		"WackyBarsMouseCtrl", "WackyBarsMouseAlt", "WackyBarsMouseHyper",
	},
	units ={ "PlayerFrame", "PlayerCastingBarFrame", "TargetFrame", "FocusFrame", "PetFrame", "PartyFrame" },
}
-- Whether the Dominos row has a setting of its own (see SPLIT): until then Dominos' frames stay in the rows they were in.
woc.dominosOwn = function()
	local d = SPLIT_BY.dominos
	return DB[d.fadeKey] ~= nil or DB[d.trigKey] ~= nil or DB[d.ovKey] ~= nil
end
-- Every listed frame and every frame that counts for the action bars' mouse over gets its hover hook (see hookHover).
woc.hookAll = function()
	loop.pending = false
	for n in pairs(woc.names) do hookHover(_G[n]) end
	for _, n in ipairs(ns.barHover) do hookHover(_G[n]) end
end
-- Warlock HUD draws its rows inside one frame with no name, as big as the screen, and makes a new one at each rebuild. It sets
-- the opacity of the frames under it, never of this one. So this one gets a name, which is in the Added frames list (Frames.lua),
-- and the function Warlock HUD calls while it builds tells us about a new one: no cost between rebuilds. Skipped without it.
-- Its rows (the aura icons, procs, buffs, consumables, cooldowns, shards) each sit on a small anchor frame with no name, a
-- child of a row mask, placed against the screen itself (not against the big frame), so moving the big frame moved none of
-- them (the owner, Nov 10, a screenshot). The pixel shift moves those anchors: each child of a mask placed against
-- UIParent gets a name, QuietHUDWarlockRow<n>. Done when Warlock HUD builds and before each shift move; a few masks, a
-- few children each.
local WARLOCK_ROWS = 12
woc.nameWarlockRows = function()
	local rows = _G.WarlockHudRowVisibility
	local masks = rows and rows.masks
	if type(masks) ~= "table" then return end
	local n = 0
	for _, key in ipairs({ "main", "utility", "consumes", "buffs", "procs", "shards" }) do
		local mask = masks[key]
		if mask and mask.GetChildren then
			for _, child in ipairs({ mask:GetChildren() }) do
				local ok, _, rel = pcall(child.GetPoint, child, 1)
				if ok and rel == UIParent and n < WARLOCK_ROWS then
					n = n + 1
					_G["QuietHUDWarlockRow" .. n] = child
				end
			end
		end
	end
	for i = n + 1, WARLOCK_ROWS do _G["QuietHUDWarlockRow" .. i] = nil end
end
local function findWarlockHud()
	local rows = _G.WarlockHudRowVisibility
	local main = rows and rows.masks and rows.masks.main
	local root = main and main:GetParent()
	if not root or root == UIParent or root == _G.QuietHUDWarlockHud then return end
	woc.noHover[root] = true
	_G.QuietHUDWarlockHud = root
	woc.nameWarlockRows()
	woc.forget()
	wakeLoop()
end
-- Its Multi-Target window has its name only the first time it is built, and a rebuild makes a new one with no name (a change
-- to the spell list can do it, around login too). The window's title is a direct child, and its font is set through a global
-- table at each build, which tells us about a new one: no cost between rebuilds.
woc.findWarlockMulti = function(text, _, sizeKey)
	if sizeKey ~= "fontMultiTargetSize" or not text or not text.GetParent then return end
	local window = text:GetParent()
	if not window or window == _G.QuietHUDWarlockMulti or not window.GetParent or window:GetParent() ~= UIParent then return end
	_G.QuietHUDWarlockMulti = window
	woc.forget()
	wakeLoop()
end
woc.watchWarlockMulti = function()
	local fonts = _G.WarlockHudFonts
	if woc.multiWatched or type(fonts) ~= "table" or not fonts.Apply then return end
	woc.multiWatched = true
	hooksecurefunc(fonts, "Apply", woc.findWarlockMulti)
end
woc.watchWarlockHud = function()
	if _G.WarlockHudPrepareAssignmentFlash then hooksecurefunc("WarlockHudPrepareAssignmentFlash", findWarlockHud) end
	findWarlockHud()
	woc.watchWarlockMulti()
end
-- RestedXP's timer bars (a flight's time left, "Undercity, Tirisfal 1:30") are LibCandyBar bars: no name, made on UIParent and
-- only placed over the guide window's footer, so they stayed solid while the window faded (the owner, 2026-11-06, a
-- screenshot). Named here while RestedXP runs them (QuietHUDRXPTimer1 to 4) and listed with the guide window. Found when
-- RestedXP sorts its bars, which it does each time one starts or stops (its container's ClearAllPoints, hooked once; no
-- polling). A bar RestedXP lets go of goes back to LibCandyBar's pool, which other addons share, so it loses its name and
-- gets its opacity back at once (audit 2026-11-06 update path F1: another addon's timer could come out of the pool faded).
woc.rxpTimers = {} -- slot i: the bar named QuietHUDRXPTimer<i>
woc.nameRxpTimers = function()
	local timers = _G.RXPFrameBarContainer
	if type(timers) ~= "table" or type(timers.bars) ~= "table" then return end
	local running, changed = {}, false
	for _, bar in pairs(timers.bars) do
		if type(bar) == "table" then running[bar] = true end
	end
	for i = 1, 4 do
		local bar = woc.rxpTimers[i]
		if bar and not running[bar] then
			woc.rxpTimers[i], changed = nil, true
			_G["QuietHUDRXPTimer" .. i] = nil
			if bar.SetAlpha then woc.write(bar, 1) end
		elseif bar then
			running[bar] = "named"
		end
	end
	for bar, state in pairs(running) do
		if state ~= "named" then
			for i = 1, 4 do
				if not woc.rxpTimers[i] then
					woc.rxpTimers[i], changed = bar, true
					_G["QuietHUDRXPTimer" .. i] = bar
					break
				end
			end
		end
	end
	if changed then woc.forget() end
end
-- Naowh's Waypoint Pin (NaowhForever_QoL/Interface/Waypoints.lua): the navigator card at the top, the pin with its card in
-- the world and the "behind you" cue at the bottom. None has a name, and Naowh builds all three at once, the first time
-- the pin is needed: the pin, then the navigator (which gets its HUD Editor plate, "Waypoint Navigator"), then the cue.
-- So the navigator is found by its plate, and the other two beside it among UIParent's children, each checked by its
-- parts. They go in the nav group, with a quest guide's arrow (the owner, 2026-11-07: "naowh taking over rxp's arrow",
-- "transparent. and hide when im not moving"); the pin sets its own opacity when you get close, so it is hosted there.
local function isWaypointPin(f)
	return type(f) == "table" and type(f.card) == "table" and f.beam ~= nil and f.ground ~= nil and f.ring ~= nil
end
local function isWaypointCue(f)
	return type(f) == "table" and f.arrow ~= nil and f.text ~= nil and f.card == nil and f.ring == nil
end
function woc.nameNaowhWaypoint(nav)
	if type(nav) ~= "table" then return end
	local changed = false
	if _G.QuietHUDNaowhWaypointNav ~= nav then _G.QuietHUDNaowhWaypointNav, changed = nav, true end
	if not (_G.QuietHUDNaowhWaypointPin and _G.QuietHUDNaowhWaypointCue) then
		local kids = { UIParent:GetChildren() }
		for i = 1, #kids do
			if kids[i] == nav then
				for j = i - 1, math.max(1, i - 3), -1 do -- (the pin is made just before the navigator)
					if not _G.QuietHUDNaowhWaypointPin and isWaypointPin(kids[j]) then
						_G.QuietHUDNaowhWaypointPin, changed = kids[j], true
					end
				end
				if not _G.QuietHUDNaowhWaypointCue and isWaypointCue(kids[i + 1]) then -- (the cue just after it)
					_G.QuietHUDNaowhWaypointCue, changed = kids[i + 1], true
				end
				break
			end
		end
	end
	if changed then woc.forget() end
end
-- Chattynator's chat windows have no names (a frame pool under ChattynatorHyperlinkHandler, placed against UIParent), so the
-- pixel shift could not list them. Named here by their window number (QuietHUDChattynator1, 2, ...), looked for only when
-- the lists are built and only while Chattynator is loaded (the owner, 2026-11-10: "will it move chattynator to?"). A window
-- made later in the session gets its name at the next rebuild (a setting changed, a /reload).
woc.chattyWindows = {} -- number: the window named QuietHUDChattynator<number>
woc.nameChattynator = function()
	local host = _G.ChattynatorHyperlinkHandler
	if type(host) ~= "table" or not host.GetChildren then return end
	local found = {}
	for _, f in ipairs({ host:GetChildren() }) do
		local okS, shown = pcall(f.IsShown, f)
		local okI, id = pcall(f.GetID, f)
		if type(f.TabsBar) == "table" and type(f.SavePosition) == "function" and okS and shown and okI and type(id) == "number"
			and id >= 1 and id <= 10 then
			found[id] = f
		end
	end
	for i = 1, 10 do
		if woc.chattyWindows[i] ~= found[i] then
			woc.chattyWindows[i] = found[i]
			_G["QuietHUDChattynator" .. i] = found[i]
		end
	end
end
local function rebuildLists()
	local rxpTimers = _G.RXPFrameBarContainer
	if not woc.rxpTimersHooked and type(rxpTimers) == "table" and type(rxpTimers.ClearAllPoints) == "function" then
		woc.rxpTimersHooked = pcall(hooksecurefunc, rxpTimers, "ClearAllPoints", woc.nameRxpTimers) or nil
	end
	-- Naowh's FPS / MS readout is a button with no name beside its top bar (bar.sys): named here so the Naowh row can fade it.
	if not _G.QuietHUDNaowhSystem then
		local bar = _G.NaowhForeverTopBar
		if type(bar) == "table" and type(bar.sys) == "table" then _G.QuietHUDNaowhSystem = bar.sys end
	end
	-- Naowh's Journey card has no name either. Naowh lists it in its HUD Editor ("Journey Card"), built when first needed:
	-- named from that list, and from the moment Naowh builds it (its BindMover, hooked once; no polling).
	local naowhUI = type(_G.NaowhForever) == "table" and _G.NaowhForever.UI
	if type(naowhUI) == "table" and type(naowhUI.BindMover) == "function" and not woc.naowhHooked then
		woc.naowhHooked = true
		hooksecurefunc(naowhUI, "BindMover", function(_, frame, label)
			if label == "Journey Card" and type(frame) == "table" and not _G.QuietHUDNaowhJourney then
				_G.QuietHUDNaowhJourney = frame
				woc.forget() -- (the Naowh row is written again, with the card)
			elseif label == "Top Bar" and type(frame) == "table" and type(frame.sys) == "table" and not _G.QuietHUDNaowhSystem then
				-- (a Top Bar switched on after login: its readout exists by now; second audit, F2)
				_G.QuietHUDNaowhSystem = frame.sys
				woc.forget()
			elseif label == "Campfire Bag" and type(frame) == "table" and _G.QuietHUDNaowhCampBag ~= frame then
				-- (the Sleeping Bag button beside Naowh's campfire, a button with no name on UIParent, built when first
				-- needed: his "why didnt you add sleeping bag into the qhud naowh family", Nov 11, it showed by itself)
				_G.QuietHUDNaowhCampBag = frame
				woc.forget()
			elseif label == "Waypoint Navigator" and type(frame) == "table" then
				-- (the cue is made right after this call returns: looked for once the build is done)
				C_Timer.After(0, function() woc.nameNaowhWaypoint(frame) end)
			end
		end)
	end
	-- Naowh's HUD Editor puts its mover plates inside the frames it moves, so a faded frame hides its plate: while it is open,
	-- everything is shown as in Edit Mode (Loop.lua). Told by its own open and close (hooked once; no polling).
	local naowh = _G.NaowhForever
	if type(naowh) == "table" and type(naowh.ShowUnlockMode) == "function" and type(naowh.HideUnlockMode) == "function"
		and not woc.naowhEditHooked then
		woc.naowhEditHooked = true
		hooksecurefunc(naowh, "ShowUnlockMode", function() ns.naowhEditing = true; wakeLoop() end)
		hooksecurefunc(naowh, "HideUnlockMode", function() ns.naowhEditing = false; wakeLoop() end)
	end
	if not _G.QuietHUDNaowhJourney then
		local editor = type(_G.NaowhForever) == "table" and _G.NaowhForever.HudEditor
		local item = type(editor) == "table" and type(editor.placement) == "table" and type(editor.placement.byLabel) == "table"
			and editor.placement.byLabel["Journey Card"]
		if type(item) == "table" and type(item.frame) == "table" then _G.QuietHUDNaowhJourney = item.frame end
	end
	-- (the Campfire Bag built before the hook above: found from the HUD Editor's list the same way)
	if not _G.QuietHUDNaowhCampBag then
		local editor = type(_G.NaowhForever) == "table" and _G.NaowhForever.HudEditor
		local item = type(editor) == "table" and type(editor.placement) == "table" and type(editor.placement.byLabel) == "table"
			and editor.placement.byLabel["Campfire Bag"]
		if type(item) == "table" and type(item.frame) == "table" then _G.QuietHUDNaowhCampBag = item.frame end
	end
	-- (the Waypoint Pin built before the hook above: found from the HUD Editor's list the same way)
	if not (_G.QuietHUDNaowhWaypointPin and _G.QuietHUDNaowhWaypointCue) then
		local editor = type(_G.NaowhForever) == "table" and _G.NaowhForever.HudEditor
		local item = type(editor) == "table" and type(editor.placement) == "table" and type(editor.placement.byLabel) == "table"
			and editor.placement.byLabel["Waypoint Navigator"]
		if type(item) == "table" and type(item.frame) == "table" then woc.nameNaowhWaypoint(item.frame) end
	end
	local dominos = SPLIT_BY.dominos
	local dominosOwn = woc.dominosOwn()
	-- An addon's row (Dominos) counts for nothing while that addon is not loaded: the row is not on the Elements page then,
	-- so a Weapon or Mouse move box ticked on it could not be unticked (woc.anyRow). Its mouse over is only looked at once
	-- it has its frames.
	woc.off = {}
	local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
	for _, s in ipairs(SPLIT) do
		if s.addon and isLoaded then
			local ok, yes = pcall(isLoaded, s.addon)
			if ok and not yes then woc.off[s.g] = true end
		end
	end
	-- The same for RestedXP's rows (Guide window, Arrow): without RestedXP, and with no frame added to their groups by hand,
	-- their boxes count for nothing. The Arrow row's boxes still count while Naowh Forever is loaded: its waypoint is in the
	-- nav list without RestedXP too (ChatGPT's audit, 2026-11-08 F1: a Weapon tick there was never looked at).
	if isLoaded then
		local ok, yes = pcall(isLoaded, "RXPGuides")
		if ok and not yes and #(DB.extra.rxp or {}) == 0 and #(DB.extra.nav or {}) == 0 then
			woc.off.rxp = true
			local okN, naowhOn = pcall(isLoaded, "NaowhForever")
			if not (okN and naowhOn) then woc.off.nav = true end
		end
	end
	dominos.hover = (dominosOwn and not woc.off.dominos) and dominos.hoverAll or nil
	-- WackyBars' names (its holders in the action bar lists and the mouse over list, its bars in the pixel shift list) only
	-- while it is loaded: without it they are 72 names looked up for nothing on every mouse over check, and 9 "no frame"
	-- lines in /qhud shift. Cost: one name test per listed name at a rebuild; nothing in the loop. (Can the game not be
	-- asked, they stay.)
	local wbOff = false
	if isLoaded then
		local ok, yes = pcall(isLoaded, "WackyBars")
		wbOff = ok and not yes
	end
	local function wbSkip(n) return wbOff and n:find("^WackyBars") ~= nil end
	local before = {}
	for g, list in pairs(LISTS) do
		if not HOSTED[g] and g ~= "shift" then
			for _, n in ipairs(list) do before[n] = true end
		end
	end
	for _, g in ipairs(ALL_LISTS) do
		local merged, seen = {}, {}
		local function add(n)
			if not seen[n] then
				seen[n] = true
				merged[#merged + 1] = n
			end
		end
		-- The beta's Issue Reporter button: hidden with its box ticked; with it unticked (the default) it fades and comes back
		-- with the Menu bar row instead of sitting solid on the screen.
		if g == "reporter" then
			if DB.hideReporter then for _, n in ipairs(DEFAULT_LISTS.reporter) do add(n) end end
		else
			for _, n in ipairs(DEFAULT_LISTS[g]) do if not wbSkip(n) then add(n) end end
		end
		-- Dominos' frames: in the Action bars, Bags bar and Menu bar lists until the Dominos row has a setting of its own,
		-- then all in its list (see the Dominos block in Frames.lua).
		for _, n in ipairs((g == "dominos" and dominosOwn and dominos.all) or (not dominosOwn and dominos.parts[g]) or {}) do add(n) end
		if g == "micro" and not DB.hideReporter then
			for _, n in ipairs(DEFAULT_LISTS.reporter) do add(n) end
		end
		if g == "bars" then
			for _, n in ipairs(ns.discovered) do
				if not KNOWN_BAR_FRAMES[n] then add(n) end
			end
		end
		if g == "shift" then
			-- The waypoint arrows sit in one spot on the screen while you travel (the owner, 2026-11-09: "can we have naowhs
			-- rxp arrow move 4 pixels every 4 mins as well"): Naowh's navigator card and its "behind you" cue (placed once,
			-- not every frame), and RestedXP's arrow. Not Naowh's pin, which follows the world. Only while that addon is loaded.
			local function loaded(a) local ok, yes = pcall(isLoaded or function() end, a) return ok and yes end
			if loaded("NaowhForever") then
				add("QuietHUDNaowhWaypointNav")
				add("QuietHUDNaowhWaypointCue")
				-- Naowh's HUD pieces and alerts, the frames of its two rows, and its flight card (the owner, Nov 10: "the naowh
				-- stuff on my screen doesnt shift either")
				for _, g in ipairs({ "naowh", "naowhAlerts", "flightTimer" }) do
					for _, n in ipairs(SPLIT_BY[g] and SPLIT_BY[g].frames or {}) do add(n) end
				end
			end
			-- RestedXP's guide window and Naowh's own window for it (the owner, Nov 10: "naowhs RXP stuff doesnt shift"); its
			-- timer bars sit on the window's footer and RestedXP places them again as they run, so they are not listed
			if loaded("RXPGuides") then
				add("RXPG_ARROW")
				add("RXPFrame")
				add("NaowhRXPWindow")
			end
			-- Warlock HUD's rows (one full-screen frame, named in findWarlockHud) and its Multi-Target window sit in one spot
			-- in the middle of the screen (the owner, Nov 10: "the warlock hud rows thats like weak auras doesnt move").
			if loaded("Warlock_Hud") then
				for i = 1, WARLOCK_ROWS do add("QuietHUDWarlockRow" .. i) end
				add("QuietHUDWarlockMulti")
				add("WarlockHudMultiTargetWindow")
			end
			-- Chattynator's windows, with the game's chat windows (named just above)
			if loaded("Chattynator") then
				woc.nameChattynator()
				for i = 1, 10 do add("QuietHUDChattynator" .. i) end
			end
			if DB.shiftBars then for _, n in ipairs(SHIFT_FRAMES.bars) do if not wbSkip(n) then add(n) end end end
			if DB.shiftUnits then for _, n in ipairs(SHIFT_FRAMES.units) do add(n) end end
		end
		-- The RestedXP windows are added by their checkboxes. The frames do not have to exist yet: they are looked up
		-- by name every time they are faded.
		if g == "rxp" then
			if DB.rxpGuide then
				add("RXPFrame")
				for i = 1, 4 do add("QuietHUDRXPTimer" .. i) end -- (its timer bars, named above)
			-- Naowh Forever's own window for RestedXP's guide (NaowhForever/Core/Integrations/RestedXP/Window.lua), shown in
			-- place of RestedXP's while Naowh's RestedXP window is on (the owner, 2026-11-07: "add naowhs guide thing for rxp")
			add("NaowhRXPWindow")
			end
			if DB.rxpTargets then
				add("RXPTargetFrame")
				add("RXPItemFrame")
			end
		elseif g == "nav" then
			if DB.rxpArrow then add("RXPG_ARROW") end
			-- Naowh's Waypoint Pin, named above (nothing while Naowh is not there or the pin was never built)
			add("QuietHUDNaowhWaypointNav")
			add("QuietHUDNaowhWaypointPin")
			add("QuietHUDNaowhWaypointCue")
		elseif g == "chat" then
			-- Chattynator's chat window hangs off this frame (it has no size of its own, its windows are its children).
			-- Skipped when that addon is not there.
			add("ChattynatorHyperlinkHandler")
		end
		-- (a name whose global is not a frame, a function or a number, is left out: /qhud add refuses one, a file changed by
		-- hand can still hold one)
		-- (WackyBars' frames are faded through its holders, with their Action bars row: one added here too faded twice,
		-- Faded times Faded; /qhud add refuses them now, a file from before can still hold one; audit Nov 10)
		for _, n in ipairs(DB.extra[g] or {}) do
			local v = _G[n]
			if (v == nil or type(v) == "table") and not n:find("^WackyBars") then add(n) end
		end
		LISTS[g] = merged
	end
	-- A frame that left a group (a box unticked, /qhud remove) is no longer faded, so it gets its opacity back.
	-- A hosted list (the nav group, Naowh's alerts) does this itself, when it takes a frame out of its container.
	local stillListed = {}
	for g, list in pairs(LISTS) do
		if g ~= "shift" then
			for _, n in ipairs(list) do stillListed[n] = true end
		end
	end
	for n in pairs(before) do
		local f = not stillListed[n] and _G[n]
		if type(f) == "table" and f.SetAlpha then woc.write(f, 1) end
	end
	ns.barHover = {}
	local seen = {}
	for _, list in ipairs({ ACTION_BARS, ns.discovered, not dominosOwn and dominos.barHover or {}, DB.extra.bars or {} }) do
		for _, n in ipairs(list) do
			if not seen[n] and not wbSkip(n) then
				seen[n] = true
				ns.barHover[#ns.barHover + 1] = n
			end
		end
	end
	-- Buttons moved out of their bar by another addon count for mouse over themselves (see checkElsewhere).
	for i, def in ipairs(BAR_DEFS) do
		if elsewhere.bars[i] and i ~= ns.PET_BAR then -- (the pet bar's mouse over is its own Elements row's)
			for j = 1, def.count or 12 do ns.barHover[#ns.barHover + 1] = def.buttons .. j end
		end
	end
	for k, set in ipairs(EXTRA_BUTTONS) do
		if elsewhere.extra[k] then
			for j = 1, set[2] do ns.barHover[#ns.barHover + 1] = set[1] .. j end
		end
	end
	-- The pet bar's Elements row: Mouse over looks at its frames (the game's pet bar; WackyBars' holders only while it is
	-- loaded) and at its ten buttons only while another addon moved them out of the bar (audit Nov 10: twenty names were
	-- looked at on every update, WackyBars there or not).
	do
		local pet, hover = BAR_DEFS[ns.PET_BAR], {}
		for _, n in ipairs(pet.frames) do
			if not wbSkip(n) then hover[#hover + 1] = n end
		end
		if elsewhere.bars[ns.PET_BAR] then
			for j = 1, pet.count or 10 do hover[#hover + 1] = pet.buttons .. j end
		end
		SPLIT_BY.petBar.hover, SPLIT_BY.petBar.ownedHover = hover, true
	end
	-- The lists changed: every group is written again (write on change, above).
	woc.names, woc.selfFading, woc.owner = {}, {}, {}
	for g, list in pairs(LISTS) do
		for _, n in ipairs(list) do
			woc.names[n] = true
			if SELF_FADING[n] then woc.selfFading[g] = true end
		end
	end
	for _, list in ipairs(WRITE_ORDER) do
		for _, n in ipairs(LISTS[list] or {}) do woc.owner[n] = list end
	end
	woc.forget()
	woc.hookAll()
	if woc.applyBarClicks then woc.applyBarClicks() end -- (the Click through column, ActionBars.lua)
	-- (the mouse watcher follows woc.off: an addon's row that counts for nothing no longer needs it)
	if ns.applyMouseWatch then ns.applyMouseWatch() end
end
rebuildLists()
-- The Dominos row gets its settings once, copied from the Action bars row (Fade, triggers, Shown), and is a row of its own
-- from then on: changing Action bars never changes it, or the other way round (a row that followed Action bars and then
-- stopped the moment one of its boxes was clicked was confusing). The copy is made the first
-- time the settings window opens with Dominos loaded and after Reset to defaults. Then Dominos' frames move into its
-- group: its bag bar and menu go by this row, not by Bags bar and Menu bar.
woc.claimDominos = function()
	local d = SPLIT_BY.dominos
	if DB[d.fadeKey] ~= nil and DB[d.trigKey] ~= nil and DB[d.ovKey] ~= nil then return end
	for i, key in ipairs({ d.fadeKey, d.trigKey, d.ovKey }) do
		if DB[key] == nil then DB[key] = DB[d.follows[i]] end
	end
	rebuildLists()
end

-- Adds a frame to the added frames of a group unless it is there already. Returns whether it was new.
local function mergeExtra(g, name)
	DB.extra[g] = DB.extra[g] or {}
	for _, n in ipairs(DB.extra[g]) do
		if n == name then return false end
	end
	DB.extra[g][#DB.extra[g] + 1] = name
	return true
end

-- After any settings change: every group is written again at once, and the open bags and the minimap buttons follow.
local function settingChanged()
	woc.peekSetCache = nil -- (the Show with column follows the Show when page)
	woc.forget()
	wakeLoop()
	if woc.applyBarClicks then woc.applyBarClicks() end -- (a Click through box takes effect at once; audit 2026-11-10)
	if ns.applyMouseWatch then ns.applyMouseWatch() end
	if ns.applyExtras then ns.applyExtras() end
end

-- The saved file. The game reads it before ADDON_LOADED and writes QuietHUDDB back at a reload or logout (the logout event
-- in Events.lua sets it to DB), so a change made since the last reload is lost if the game crashes. 1.5.0 wrote no
-- settingsVersion: its file (it has awakeSplit) is read as version 0 and MIGRATIONS[1] brings it up to date, so an update
-- from 1.5.0 keeps everyone's settings (found before 1.6.0 shipped, 2026-11-06: the launch build was meant for an empty
-- folder, but 1.5.0 had been live on the launch client since). A file older than 1.5.0 is not read: it starts on the
-- defaults, as settings from the old builds can cause problems. MIGRATIONS[n] turns a file of version n - 1 into version n, so a change to what a setting means never
-- leaves anyone's HUD in a state they did not choose: each step runs once, in order, and gets a harness test (an old file
-- in, the right settings out). A file from a newer build is read as it is, except a known setting of the wrong kind, which
-- gets its default (below).
local MIGRATIONS = {}
-- 1.5.0 to 1.6.0. (1) A row split out of the Added frames row (Target and focus, Pet frame, ...) with no value of its own
-- followed that row in 1.5.0 (Debuffs followed Buffs; the cast and breath bars faded with no triggers). Rows no longer
-- follow, so what it followed is written into it: nothing changes on the screen. (2) The minimap's, RestedXP's and the
-- guide arrow's own Faded went on 2026-10-22: everything fades to the Global Faded. One set ABOVE the Global Faded (kept on
-- the screen at rest, dimmed) would now vanish at rest, so that element stops fading instead and stays on the screen, and a
-- chat line says so once (the owner, 2026-11-06: "check for any wacky like if player goes to new version this thing can
-- disappear"). One set below it just comes up a little more. (3) The rows for another addon that 1.5.0 did not have (Naowh,
-- Naowh alerts) start as they looked before for someone updating: Fade unticked, solid. A fresh install gets their defaults
-- (Mouse over only; alerts at 0.50), but on an update Naowh's XP bar or food bar would vanish until hovered (as RestedXP's
-- windows in 1.5.0: "if you already use QuietHUD, yours stay as you set them"). (4) The keys only the old conversions used
-- are taken out.
MIGRATIONS[1] = function(saved)
	local function key(kind, g) return kind .. g:sub(1, 1):upper() .. g:sub(2) end
	for _, g in ipairs({ "target", "pet", "party", "panel", "auras", "debuffs", "cooldowns", "meter", "alerts", "cast", "breath" }) do
		local own = g == "cast" or g == "breath"
		if saved[key("fade", g)] == nil then
			local v
			if g == "debuffs" then v = saved.fadeAuras end -- (Buffs is done by now: it comes first)
			if v == nil then v = own or saved.fadeUnits end
			saved[key("fade", g)] = v
		end
		if saved[key("trig", g)] == nil then
			local v
			if g == "debuffs" then v = saved.trigAuras end
			if v == nil then v = own and 0 or saved.trigUnits end
			saved[key("trig", g)] = v
		end
	end
	local idle = type(saved.idle) == "number" and saved.idle or 0
	local function above(v) return type(v) == "number" and v > idle + 0.001 end
	local kept = {}
	if above(saved.mapIdle) and saved.fadeMinimap ~= false then
		saved.fadeMinimap = false
		kept[#kept + 1] = "the minimap"
	end
	-- (frames added to those two groups with /qhud add go too, back to their own opacity, or they would vanish: audit
	-- 2026-11-06 update path F2)
	local extra = type(saved.extra) == "table" and saved.extra or {}
	if above(saved.rxpIdle) and (saved.rxpGuide ~= false or saved.rxpTargets ~= false or next(extra.rxp or {})) then
		saved.rxpGuide, saved.rxpTargets = false, false
		extra.rxp = nil
		kept[#kept + 1] = "RestedXP's windows"
	end
	if above(saved.navIdle) and (saved.rxpArrow ~= false or next(extra.nav or {})) then
		saved.rxpArrow = false
		extra.nav = nil
		kept[#kept + 1] = "the guide arrow"
	end
	if #kept > 0 then
		ns.upgradeNote = "QuietHUD 1.6.0: the Faded slider of " .. table.concat(kept, ", ") .. " is gone (everything fades to the one"
			.. " Faded now). Yours kept it on the screen, so it stays on the screen and no longer fades. To fade it again, tick its"
			.. " Fade on the Elements page (/qhud). Frames you had added to it with /qhud add were taken out too: add them again"
			.. " to fade them."
	end
	if saved.fadeNaowh == nil then saved.fadeNaowh = false end
	if saved.fadeNaowhAlerts == nil then saved.fadeNaowhAlerts = false end
	if saved.ovNaowhAlerts == nil then saved.ovNaowhAlerts = 0 end
	for _, k in ipairs({ "mapIdle", "rxpIdle", "navIdle", "awakeSplit", "sameDefaults", "inCombat", "mouseShows", "sheathShows",
		"showOnTarget" }) do
		saved[k] = nil
	end
end
-- 1.6.1 to the next. The pet bar got a row of its own on the Action bars page (bit 9 of each column, the owner, Nov 10). It
-- faded with the bars and went with Action Bar 8's Click through, so it starts that way: nothing changes on the screen.
MIGRATIONS[2] = function(saved)
	local function bit(m, i) return (math.floor((m or 0) / 2 ^ (i - 1)) % 2) == 1 end
	if type(saved.barFade) == "number" and not bit(saved.barFade, 9) then saved.barFade = saved.barFade + 256 end
	-- (its Shown slider's 0 is Global; an Action bars Shown of its own, which the pet bar followed, is copied to it)
	if saved.ovPetBar == nil and type(saved.ovBars) == "number" and saved.ovBars > 0 then saved.ovPetBar = saved.ovBars end
	if type(saved.barClicks) == "number" and bit(saved.barClicks, 8) and not bit(saved.barClicks, 9) then
		saved.barClicks = saved.barClicks + 256
	end
end
-- 1.7.0-beta1 to the next. The pet bar got a row of its own on the Elements page (the owner, Nov 10): its Fade and what
-- shows it start as they were: the Action bars row's, its Fade column box, and Mouse over only as just Mouse over.
-- Audit Nov 10: (1) beta1 put a pet bar with its Fade box unticked at full; here that is Fade off, and an own Shown would
-- now hold it dim, so that Shown goes back to Global. (2) A Mouse over only pet bar went to 0 in a fight when the Action bars
-- row had Hide in combat; it keeps that box. (3) The pet row has no Low health, Low mana, Mouse over only or Show with any
-- more: its bit in those columns is cleared (Show with: set, as ticked), or Low health kept listening for nothing.
MIGRATIONS[3] = function(saved)
	-- (a word or a table where a number belongs, from a file changed by hand, counts as nothing ticked)
	local function bit(m, i) return type(m) == "number" and (math.floor(m / 2 ^ (i - 1)) % 2) == 1 end
	if saved.fadePetBar == nil then
		local petFadeOff = saved.fadeBars ~= false and type(saved.barFade) == "number" and not bit(saved.barFade, 9)
		saved.fadePetBar = (saved.fadeBars ~= false) and not petFadeOff
		if petFadeOff then saved.ovPetBar = 0 end
	end
	if saved.trigPetBar == nil then
		if bit(saved.barMouse, 9) then
			saved.trigPetBar = 8 + (bit(saved.trigBars, 5) and 16 or 0) -- (Mouse over, and Hide in combat if the bars had it)
		elseif type(saved.trigBars) == "number" then
			saved.trigPetBar = saved.trigBars
		end
	end
	for _, k in ipairs({ "barLow", "barMana", "barMouse" }) do
		if bit(saved[k], 9) then saved[k] = saved[k] - 256 end
	end
	if type(saved.barPeek) == "number" and not bit(saved.barPeek, 9) then saved.barPeek = saved.barPeek + 256 end
end
local dbLoaded = false
local function initDB()
	if dbLoaded then return end
	dbLoaded = true
	local saved = QuietHUDDB
	if type(saved) == "table" and saved.settingsVersion == nil and saved.awakeSplit == true then saved.settingsVersion = 0 end -- (1.5.0's)
	if type(saved) == "table" and type(saved.settingsVersion) == "number" then
		for v = saved.settingsVersion + 1, SETTINGS_VERSION do
			-- (a file changed by hand or damaged can't stop the rest of the settings loading: an error here left QuietHUD half
			-- set up at every login; audit Nov 10)
			if MIGRATIONS[v] then pcall(MIGRATIONS[v], saved) end
		end
		-- (DB stays the one table every file holds: the saved file's settings go into it, and the game saves it from
		-- now on)
		for k in pairs(DB) do DB[k] = nil end
		for k, v in pairs(saved) do DB[k] = v end
		QuietHUDDB = DB
	end
	-- A setting the file does not have gets its default, and so does one of the wrong kind (only a file changed by hand or
	-- damaged has one: a word where a number belongs would stop the fading).
	for k, v in pairs(DEFAULTS) do
		if type(DB[k]) ~= type(v) then DB[k] = v end
	end
	for _, s in ipairs(SPLIT) do
		if s.follows then
			for i, key in ipairs({ s.fadeKey, s.trigKey, s.ovKey }) do
				if DB[key] ~= nil and type(DB[key]) ~= type(DEFAULTS[s.follows[i]]) then DB[key] = nil end
			end
		end
	end
	DB.settingsVersion = math.max(DB.settingsVersion or 0, SETTINGS_VERSION)
	-- The frames added with /qhud add: a list of names per group.
	if type(DB.extra) ~= "table" then DB.extra = {} end
	for g, list in pairs(DB.extra) do
		if type(list) ~= "table" then
			DB.extra[g] = nil
		else
			for i = #list, 1, -1 do
				if type(list[i]) ~= "string" then table.remove(list, i) end
			end
		end
	end
	if type(DB.mapLog) ~= "table" then DB.mapLog = nil end
	DB.trace, DB.debug = nil, nil
	rebuildLists()
end

-- The setting that gives a group its own opacity, in place of the Global Shown.
local OVERRIDE_KEYS = { bars = "ovBars", player = "ovPlayer", hud = "ovHud", quest = "ovQuest", map = "ovMap", bags = "ovBagsBar", micro = "ovMicro" }
for _, s in ipairs(SPLIT) do OVERRIDE_KEYS[s.g] = s.ovKey end

-- Which rows fade now (their Fade box, or the one they follow), by group; and the group of each Opacity bar's setting.
woc.fadeFlags = function()
	local fades = { bars = DB.fadeBars, player = DB.fadePlayer, hud = DB.fadeUnits, quest = DB.fadeTracker, map = DB.fadeMinimap,
		chat = DB.fadeChat, nav = true, rxp = true, bags = DB.fadeBags, micro = DB.fadeMicro }
	for _, s in ipairs(SPLIT) do fades[s.g] = gFade(s) end
	return fades
end
woc.groupOfKey = { chatOwn = "chat", mapOwn = "map", rxpShown = "rxp", navShown = "nav" }
for g, key in pairs(OVERRIDE_KEYS) do woc.groupOfKey[key] = g end

-- For the files after this one (QuietHUD.toc).
ns.DB, ns.gFade, ns.gTrig, ns.LISTS, ns.elsewhere, ns.woc, ns.loop = DB, gFade, gTrig, LISTS, elsewhere, woc, loop
ns.wakeLoop, ns.trace, ns.discoverBars, ns.rebuildLists = wakeLoop, trace, discoverBars, rebuildLists
ns.mergeExtra, ns.settingChanged, ns.initDB, ns.OVERRIDE_KEYS = mergeExtra, settingChanged, initDB, OVERRIDE_KEYS
