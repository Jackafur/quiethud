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
ns.spyUntil = 0 -- (Spy's alarm, the Spy row's New info: Events.lua hookSpy)
ns.peekUntil = 0   -- the "hold to show" key: everything is shown until this time
ns.peekLingerUntil = 0 -- (after a hold key is let go, with Stay shown while the mouse moves: Loop.lua)
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
	-- Except a frame whose addon only copies another frame's opacity into it (by name, filled below: Polestar: UI's unit
	-- frames copy the game frame's they sit on). Its 0 is the game frame faded to 0, not a hide: on a new target it repainted
	-- with that 0, and its frames came up only at its next repaint (the owner, 2026-11-16: "the actionbars load in faster then
	-- the player frame", "on target"). Looked at only when a 0 comes in.
	woc.copiesAlpha = {}
	local function copies(f)
		local ok, n = pcall(f.GetName, f)
		return ok and n ~= nil and woc.copiesAlpha[n] or false
	end
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
				-- (a frame that copies another's opacity gets QuietHUD's back, below: see copies)
				if not copies(f) then
					yielded[f], want[f], lowKept[f] = true, nil, nil
					return
				end
			elseif yielded[f] then
				yielded[f] = nil
				woc.forget() -- (shown again by its owner: written at the next update)
				return
			end
		end
		if not DB.enabled then return end
		local w = want[f]
		if w == nil then return end
		-- (a frame that copies another's opacity times a factor of its own, Polestar: UI's party frames: a lower value is kept)
		if num(a) and a < w - 0.005 and copies(f) == "lower" then return end
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
			if okA and num(now) and now < 0.01 and not copies(f) then
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
		-- A listed name whose frame did not exist at the last list rebuild: an addon that makes its window with no name and
		-- sets the global itself (Guidelime's window two seconds after login and its arrow on first use, audit 2026-11-16
		-- F3) never reaches the CreateFrame hook below. Its groups are written again once it appears. Cost: one table look
		-- per such name twice a second, about 70 in a real game (the default names of addons that are not loaded count too).
		local absent = woc.absent
		if absent and next(absent) then
			for n in pairs(absent) do
				if type(_G[n]) == "table" then
					absent[n] = nil
					woc.forget()
					if woc.hookAll then woc.hookAll() end
				end
			end
		end
		if ns.partyBgCheck then ns.partyBgCheck() end
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
			-- (Polestar: UI's party frames dim a phased member below the row's value: kept, as in keep; second audit F4)
			if ok and num(a) and a < w - 0.005 and copies(f) == "lower" then ok = false end
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
-- Rogue Resources' bar has no name and its table is private (Settings.lua, the Rogue Resources row), so it is found by what
-- it carries: its list of cooldown icons, its Slice and Dice icon, its panel and the panel's outline. One pass over
-- UIParent's children; nothing in the loop. It builds the bar in its own PLAYER_LOGIN, after QuietHUD's (Q loads before R),
-- and only on a rogue, so a pass that finds nothing is tried again two seconds later, ROGUE_LOOKS times, then never
-- again (another class, or a version built differently: the row then does nothing). Its lock is the bar taking the mouse
-- (its SetLocked: EnableMouse(not locked)), heard through that one frame's EnableMouse, hooked once, no polling: while it
-- is unlocked everything is shown as in Edit Mode (Loop.lua), and it is read once here for a bar left unlocked at the
-- last logout.
local ROGUE_LOOKS = 5
woc.nameRogueResources = function()
	if _G.QuietHUDRogueResources then return true end
	if (woc.rogueLooks or 0) >= ROGUE_LOOKS or not (UIParent and UIParent.GetChildren) then return false end
	for _, f in ipairs({ UIParent:GetChildren() }) do
		if type(f) == "table" and type(rawget(f, "icons")) == "table" and rawget(f, "snd") and rawget(f, "panel")
			and rawget(f, "panelOutline") then
			_G.QuietHUDRogueResources = f
			if type(f.EnableMouse) == "function" then
				hooksecurefunc(f, "EnableMouse", function(_, on)
					ns.rogueEditing = on and true or false
					wakeLoop()
				end)
				local ok, on = pcall(f.IsMouseEnabled, f)
				ns.rogueEditing = (ok and on) and true or false
			end
			return true
		end
	end
	-- (one look to come at a time, however often the lists are made in between)
	if not woc.rogueRetry and C_Timer and C_Timer.After then
		woc.rogueRetry = true
		C_Timer.After(2, function()
			woc.rogueRetry = nil
			woc.rogueLooks = (woc.rogueLooks or 0) + 1
			if woc.nameRogueResources() then
				woc.forget() -- (the Rogue Resources row is written again, with the bar)
				wakeLoop()
			end
		end)
	end
	return false
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
-- Naowh's Dungeon Quest Tracker (NaowhForever_DungeonJournal/UI/QuestTracker.lua): a window with no name on UIParent, told
-- apart from Naowh's other tracker windows by its dungeon picker and its Share All button. True when it was found.
function woc.nameNaowhQuestTracker()
	local kids = { UIParent:GetChildren() }
	for i = 1, #kids do
		local f = kids[i]
		if type(f) == "table" and type(f.dungeonNames) == "table" and type(f.picker) == "table" and type(f.share) == "table" then
			_G.QuietHUDNaowhQuestTracker = f
			return true
		end
	end
	return false
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
-- Every other piece in Naowh's HUD Editor joins a Naowh row by itself, so a Naowh piece no longer needs its own ask (the
-- owner, 2026-11-14, its Library Books tracker: "i'd add as much as naowhs shit to qhud as possible", "like with out me
-- asking"). Each piece Naowh lets you move is in its HUD Editor's list (placement.items: the label and the frame), built as
-- Naowh makes it. A piece QuietHUD already lists by name, or has a row of its own (the waypoint, the threat meter, the flight
-- timer), is left where it is. The rest are named QuietHUDNaowhAuto<label>: the panels that sit on the screen go into the
-- Naowh row, everything else (pop-up reminders and alerts, fight displays, and any piece a later Naowh adds) into Naowh
-- alerts, which never fades it out completely, so a warning still reaches you. Labels are Naowh's English ones; on another
-- language a panel lands in Naowh alerts. Cost: one pass over Naowh's list at a rebuild; a piece built later is picked up
-- by the BindMover hook below (one rebuild half a second later, however many pieces came); nothing in the loop.
local NAOWH_PANELS = { ["Library Books"] = true, ["Sleeping Bag"] = true, ["Zone Info"] = true,
	["Instance Tracker"] = true, ["Layer Tracker"] = true, ["Group XP"] = true, ["Group Buttons"] = true,
	["Boat and Zeppelin Timers"] = true, ["Tracking"] = true, ["PvP Flag"] = true }
-- (Druid Mana and Trinkets are combat displays: with the alerts, which never fade out completely; in the Naowh row, Mouse
-- over only by default, they vanished in fights; audit 2026-11-16 F9)
local NAOWH_OWN_ROW = { ["Waypoint Navigator"] = true, ["Threat Meter"] = true, ["Flight Timer"] = true }
woc.naowhAuto = { naowh = {}, naowhAlerts = {} } -- the names given, per row
woc.naowhAutoFrames = setmetatable({}, { __mode = "k" }) -- frame -> its name
woc.nameNaowhAuto = function()
	local editor = type(_G.NaowhForever) == "table" and _G.NaowhForever.HudEditor
	local items = type(editor) == "table" and type(editor.placement) == "table" and editor.placement.items
	if type(items) ~= "table" then return end
	local listed = {}
	for _, list in pairs(DEFAULT_LISTS) do
		for _, n in ipairs(list) do
			local f = _G[n]
			if type(f) == "table" and not n:find("^QuietHUDNaowhAuto") then listed[f] = true end
		end
	end
	for _, n in ipairs({ "QuietHUDNaowhWaypointNav", "QuietHUDNaowhWaypointPin", "QuietHUDNaowhWaypointCue" }) do
		if type(_G[n]) == "table" then listed[_G[n]] = true end
	end
	-- (a piece the player added himself with /qhud add, to any row, stays where he put it and is not named into a Naowh
	-- row: these are picked by QuietHUD itself, not a support he asked for. Under two names it was written by two rows and
	-- hidden in Naowh alerts (audit Nov 16, F6); a hidden one came back with the Naowh row, and one in a Naowh row with Fade
	-- unticked, as everyone who updated from 1.5.0 has it, sat at full (second audit Nov 16, F2, F5))
	for _, list in pairs(DB.extra or {}) do
		for _, n in ipairs(type(list) == "table" and list or {}) do
			local f = _G[n]
			if type(f) == "table" and not n:find("^QuietHUDNaowhAuto") then listed[f] = true end
		end
	end
	local rows = { naowh = {}, naowhAlerts = {} }
	for _, item in ipairs(items) do
		local f, label = type(item) == "table" and item.frame, type(item) == "table" and item.label
		if type(f) == "table" and type(label) == "string" and not listed[f] and not NAOWH_OWN_ROW[label] then
			local name = woc.naowhAutoFrames[f] or ("QuietHUDNaowhAuto" .. label:gsub("[^%w]", ""))
			if _G[name] == nil or _G[name] == f or woc.naowhAutoFrames[_G[name]] then
				_G[name] = f
				woc.naowhAutoFrames[f] = name
				local list = rows[NAOWH_PANELS[label] and "naowh" or "naowhAlerts"]
				list[#list + 1] = name
			end
		end
	end
	woc.naowhAuto = rows
end
-- The quest guide rows (Guide window, Targets, Arrow) work for Guidelime too (the owner, 2026-11-14: "ok just add them.
-- guidelimes bullshit and sage guide"; a commenter asked for Guidelime in October, when its windows had no names; by
-- v6.021 they have: GuidelimeWindow, GuidelimeOngoingWindow, GuidelimeArrow, made on UIParent. Its target and use-item
-- buttons sit inside GuidelimeWindow, so they fade with it. Guidelime_Sage is guide text shown in those same windows). The
-- rows show while RestedXP or Guidelime is loaded; nothing is special-cased, the names go into the same lists.
-- Polestar too (the owner, 2026-11-16: "just put in support for both to put that shit to bed", after a CurseForge report on
-- Polestar; Polestar 0.3.7.2, POLESTAR below).
ns.guideAddon = function()
	local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
	if not isLoaded then return "RXPGuides" end -- (a client that cannot say: the rows show, as before)
	for _, a in ipairs({ "RXPGuides", "Guidelime", "Polestar" }) do
		local ok, yes = pcall(isLoaded, a)
		if ok and yes then return a end
	end
end
-- The name the quest guide rows' heading shows (the Elements and Opacity pages)
ns.guideName = function()
	local a = ns.guideAddon()
	return (a == "Guidelime" or a == "Polestar") and a or "RestedXP"
end
-- Polestar's frames, by list. Its windows, cards and toasts all hang off one layer as big as the screen (PolestarUIParent,
-- its Core/Init.lua); only the guide window goes in a list, never the layer (a hosted move would take the window out of
-- Polestar's own hide, and the toasts and setup windows are not HUD). Its action buttons (quest item, hearthstone, target,
-- rare, bag, and the travel button under the arrow) are secure buttons on UIParent: the Targets, items row, faded where
-- they are. So is its target list (the owner, 2026-11-17, a screenshot: "polestars target list doesnt fade"): the mark
-- PolestarTargetAnchor and up to 8 secure rows PolestarTargetRow1 to 8 on UIParent (QoL/Buttons.lua, TL.MAX), made only
-- when a step first names that many targets; a row made later is found by woc.drift (woc.absent).
-- Its arrow is a plain frame on UIParent: the Arrow row, hosted, so Polestar's own arrow opacity still counts.
-- Polestar: UI (another author's companion) draws unit frames of its own over the game's, which it leaves in place with
-- their art hidden; it copies the game frame's opacity only when it repaints (a health or power change), so they faded late
-- and in jumps. Each goes in the row of the game frame it sits on. Its boss frames are left alone, like the game's.
-- Names only while that addon is loaded.
local POLESTAR = {
	guide = { "PolestarGuideFrame" },
	targets = { "PolestarQuestItemButton", "PolestarHearthButton", "PolestarTargetButton", "PolestarRareButton",
		"PolestarBagButton", "PolestarTravelButton", "PolestarTargetAnchor", "PolestarTargetRow1", "PolestarTargetRow2",
		"PolestarTargetRow3", "PolestarTargetRow4", "PolestarTargetRow5", "PolestarTargetRow6", "PolestarTargetRow7",
		"PolestarTargetRow8" },
	arrow = { "PolestarNavArrow" },
}
local POLESTAR_UI = {
	player = { "PolestarUIPlayerFrame" },
	target = { "PolestarUITargetFrame", "PolestarUIFocusFrame", "PolestarUITargetToT", "PolestarUIFocusToT" },
	pet = { "PolestarUIPetFrame" },
	party = { "PolestarUIPartyFrame1", "PolestarUIPartyFrame2", "PolestarUIPartyFrame3", "PolestarUIPartyFrame4" },
}
-- (they copy the game frame's opacity, a 0 included: never taken as a hide, see woc.copiesAlpha. The party frames copy the
-- member's opacity times the party frame's, and the game dims a member who is phased or in another group to 0.6: a lower
-- value from them is kept, "lower"; audit 2026-11-16 F4)
for g, names in pairs(POLESTAR_UI) do
	for _, n in ipairs(names) do woc.copiesAlpha[n] = (g == "party") and "lower" or true end
end
-- A row's name as the Elements page shows it, for the messages about frames added by hand (woc.ignoredExtra).
local ROW_LABELS = { bars = "Action bars", player = "Player frame", hud = "Added frames", quest = "Objective tracker",
	map = "Minimap", chat = "Chat", nav = "Arrow", rxp = "Guide window", bags = "Bags bar", micro = "Menu bar",
	reporter = "Menu bar" }
woc.rowLabel = function(g)
	if SPLIT_BY[g] then return SPLIT_BY[g].label end
	if type(g) == "string" and g:find("^bar%d") then return "Action bars" end
	return ROW_LABELS[g] or tostring(g)
end
local function rebuildLists()
	local rxpTimers = _G.RXPFrameBarContainer
	if not woc.rxpTimersHooked and type(rxpTimers) == "table" and type(rxpTimers.ClearAllPoints) == "function" then
		woc.rxpTimersHooked = pcall(hooksecurefunc, rxpTimers, "ClearAllPoints", woc.nameRxpTimers) or nil
	end
	-- RestedXP's new guide window (its beta "V2 interface") is an AceGUI frame with no name on UIParent, shown in place of
	-- RXPFrame, so it stayed solid while the Guide window row faded (the owner, 2026-11-14, a screenshot with Naowh off;
	-- with Naowh on, Naowh's own window takes its place). RestedXP keeps the widget as _G.RXPV2GuideWindow once built
	-- (at its login setup, before PLAYER_ENTERING_WORLD), so its frame is named here.
	local v2 = _G.RXPV2GuideWindow
	if type(v2) == "table" and type(v2.frame) == "table" and _G.QuietHUDRXPV2Window ~= v2.frame then
		_G.QuietHUDRXPV2Window = v2.frame
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
			-- (any other piece built after login: the lists are made again once, half a second after the last one, so it
			-- joins its Naowh row; see woc.nameNaowhAuto)
			if type(frame) == "table" and not woc.naowhAutoFrames[frame] and not woc.naowhAutoSoon then
				woc.naowhAutoSoon = true
				C_Timer.After(0.5, function() woc.naowhAutoSoon = nil; rebuildLists() end)
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
	-- Nock's edit mode (its Edit button, its setup's steps, the Lock button) goes through Nock:SetLocked, and its frames take the
	-- mouse only while it is unlocked: while it is, everything is shown as in Edit Mode, so a faded Nock piece can be found and
	-- dragged. Told by that call and by a profile change, copy, reset or import (Nock:OnProfileSwitched; the lock is part of
	-- the profile), hooked once, no polling; read once here for a Nock left unlocked at the last logout. Only on a hunter:
	-- Nock loads on every class (its HUD hidden), and a profile shared with the hunter, left unlocked there, kept every row
	-- in full and the pixel shift paused on a mage (audit Nov 17).
	local nock = _G.Nock
	if type(nock) == "table" and type(nock.SetLocked) == "function" and type(nock.IsLocked) == "function"
		and not woc.nockEditHooked then
		woc.nockEditHooked = true
		local function nockEdit()
			local ok, locked = pcall(nock.IsLocked)
			ns.nockEditing = (nock.isHunter and ok and locked == false) or false
			wakeLoop()
		end
		hooksecurefunc(nock, "SetLocked", nockEdit)
		if type(nock.OnProfileSwitched) == "function" then hooksecurefunc(nock, "OnProfileSwitched", nockEdit) end
		nockEdit()
		-- Nock places its HUD box again from its saved spot now and then (a pet summoned or lost, a spell learned, a profile
		-- change: its HUD:ApplyPosition). The shift is told, so it goes back on top at once instead of the box jumping to its
		-- own spot for a second, and three such places close together never get the box left out of the shift (audit Nov 17).
		local okM, hud = pcall(nock.GetModule, nock, "HUD", true)
		if okM and type(hud) == "table" and type(hud.ApplyPosition) == "function" then
			hooksecurefunc(hud, "ApplyPosition", function()
				if ns.shiftOwnerPlaced then ns.shiftOwnerPlaced(_G.NockHUD, true) end
			end)
		end
	end
	-- Rogue Resources' bar (no name, see woc.nameRogueResources): looked for only while that addon is loaded
	do
		local isOn = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
		local ok, yes = pcall(isOn or function() end, "RogueResources")
		if ok and yes then woc.nameRogueResources() end
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
	-- Naowh's Dungeon Quest Tracker is not in its HUD Editor (it is dragged by its title), so neither BindMover nor the
	-- automatic pickup below ever sees it (the owner, 2026-11-16, a screenshot of it: "add this in the naowh group"). Naowh
	-- builds it the first time it opens, and every way it opens goes through Journal.QuestTracker.Show (the journal, its
	-- settings, the auto-open on a loading screen): hooked once, the window is named on its first show (one pass over
	-- UIParent's children, once a session; nothing in the loop). It goes in the Naowh row (Settings.lua).
	local journal = type(_G.NaowhForever) == "table" and _G.NaowhForever.Journal
	local questTracker = type(journal) == "table" and journal.QuestTracker
	if type(questTracker) == "table" and type(questTracker.Show) == "function" then
		if not woc.naowhQuestHooked then
			woc.naowhQuestHooked = true
			hooksecurefunc(questTracker, "Show", function()
				if not _G.QuietHUDNaowhQuestTracker and woc.nameNaowhQuestTracker() then woc.forget() end
			end)
		end
		-- (opened before the hook went on: Naowh has built it once it showed a dungeon; looked for once)
		if not _G.QuietHUDNaowhQuestTracker and not woc.naowhQuestLooked and type(questTracker.Showing) == "function"
			and questTracker.Showing() ~= nil then
			woc.naowhQuestLooked = true
			woc.nameNaowhQuestTracker()
		end
	end
	-- (the Waypoint Pin built before the hook above: found from the HUD Editor's list the same way)
	if not (_G.QuietHUDNaowhWaypointPin and _G.QuietHUDNaowhWaypointCue) then
		local editor = type(_G.NaowhForever) == "table" and _G.NaowhForever.HudEditor
		local item = type(editor) == "table" and type(editor.placement) == "table" and type(editor.placement.byLabel) == "table"
			and editor.placement.byLabel["Waypoint Navigator"]
		if type(item) == "table" and type(item.frame) == "table" then woc.nameNaowhWaypoint(item.frame) end
	end
	woc.nameNaowhAuto()
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
		-- (the Controller row while no controller is set up: not on the page either)
		if s.when and not s.when() then woc.off[s.g] = true end
	end
	-- The same for RestedXP's rows (Guide window, Arrow): without RestedXP, and with no frame added to their groups by hand,
	-- their boxes count for nothing. The Arrow row's boxes still count while Naowh Forever is loaded: its waypoint is in the
	-- nav list without RestedXP too (ChatGPT's audit, 2026-11-08 F1: a Weapon tick there was never looked at).
	if isLoaded then
		if not ns.guideAddon() and #(DB.extra.rxp or {}) == 0 and #(DB.extra.nav or {}) == 0 then
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
	-- Polestar's and Polestar: UI's names (POLESTAR, POLESTAR_UI above), only while each is loaded
	-- (Guidelime's: listed as before when the client cannot say)
	local polestar, polestarUI, guidelime = false, false, true
	if isLoaded then
		local ok, yes = pcall(isLoaded, "Polestar")
		polestar = ok and yes and true or false
		ok, yes = pcall(isLoaded, "Polestar_UI")
		polestarUI = ok and yes and true or false
		ok, yes = pcall(isLoaded, "Guidelime")
		guidelime = ok and yes and true or false
	end
	local before = {}
	for g, list in pairs(LISTS) do
		if not HOSTED[g] and g ~= "shift" then
			for _, n in ipairs(list) do before[n] = true end
		end
	end
	local extrasFor = {} -- (the frames added with /qhud add, per group: joined after every built-in list is made, below)
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
		if polestarUI then for _, n in ipairs(POLESTAR_UI[g] or {}) do add(n) end end
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
					for _, n in ipairs(woc.naowhAuto[g] or {}) do add(n) end -- (the HUD Editor's other pieces)
				end
			end
			-- RestedXP's guide window and Naowh's own window for it (the owner, Nov 10: "naowhs RXP stuff doesnt shift"); its
			-- timer bars sit on the window's footer and RestedXP places them again as they run, so they are not listed
			if loaded("RXPGuides") then
				add("RXPG_ARROW")
				add("RXPFrame")
				add("QuietHUDRXPV2Window") -- (RestedXP's new window, named in rebuildLists)
				add("NaowhRXPWindow")
			end
			if loaded("Guidelime") then -- (its windows and arrow, see ns.guideAddon)
				add("GuidelimeWindow")
				add("GuidelimeOngoingWindow")
				add("GuidelimeArrow")
			end
			-- Polestar's guide window and arrow sit in one spot too. Polestar saves their spot only when dragged or resized,
			-- so the shift never creeps into it (audit 2026-11-16 F10). Polestar: UI's unit frames are placed from the game's
			-- Edit Mode boxes and are not shifted.
			if polestar then
				add("PolestarGuideFrame")
				add("PolestarNavArrow")
			end
			-- Warlock HUD's rows (one full-screen frame, named in findWarlockHud) and its Multi-Target window sit in one spot
			-- in the middle of the screen (the owner, Nov 10: "the warlock hud rows thats like weak auras doesnt move").
			if loaded("Warlock_Hud") then
				for i = 1, WARLOCK_ROWS do add("QuietHUDWarlockRow" .. i) end
				add("QuietHUDWarlockMulti")
				add("WarlockHudMultiTargetWindow")
			end
			-- Spy's window (its Nearby list) sits in one spot (the owner, Nov 12: "make it so the screen shift thing moves it
			-- around"). Only while Spy is loaded. Spy places it again from where it is now whenever the list changes size:
			-- Events.lua hookSpy tells the shift (ns.shiftOwnerPlaced), so the shift is never taken into its place.
			if loaded("Spy") then add("Spy_MainWindow") end
			-- Nock's HUD box and its alerts, the frames of its two rows (the owner, Nov 17: "yea add nock to the
			-- shift"; beside WackyBars' bars, which shift, the box that stayed put looked unbalanced). Nock keeps its box on
			-- whole screen pixels and puts it back when it is off them (its HUD:Refresh), so the shift moves by whole screen
			-- pixels (stepShift, Shift.lua).
			if loaded("Nock") then
				for _, row in ipairs({ "nock", "nockAlerts" }) do
					for _, n in ipairs(SPLIT_BY[row] and SPLIT_BY[row].frames or {}) do add(n) end
				end
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
		-- Naowh's other HUD Editor pieces, named in woc.nameNaowhAuto
		if g == "naowh" or g == "naowhAlerts" then
			for _, n in ipairs(woc.naowhAuto[g] or {}) do add(n) end
		end
		if g == "rxp" then
			if DB.rxpGuide then
				add("RXPFrame")
				add("QuietHUDRXPV2Window") -- (RestedXP's new window, named in rebuildLists)
				for i = 1, 4 do add("QuietHUDRXPTimer" .. i) end -- (its timer bars, named above)
			-- Naowh Forever's own window for RestedXP's guide (NaowhForever/Core/Integrations/RestedXP/Window.lua), shown in
			-- place of RestedXP's while Naowh's RestedXP window is on (the owner, 2026-11-07: "add naowhs guide thing for rxp")
			add("NaowhRXPWindow")
			-- Guidelime's guide window (its target and use-item buttons are inside it) and its ongoing-steps window (only
			-- while Guidelime is loaded, like Polestar's names; audit 2026-11-16 F11)
			if guidelime then
				add("GuidelimeWindow")
				add("GuidelimeOngoingWindow")
			end
			if polestar then for _, n in ipairs(POLESTAR.guide) do add(n) end end
			end
			if DB.rxpTargets then
				add("RXPTargetFrame")
				add("RXPItemFrame")
				if polestar then for _, n in ipairs(POLESTAR.targets) do add(n) end end
			end
		elseif g == "nav" then
			if DB.rxpArrow then
				add("RXPG_ARROW")
				if guidelime then add("GuidelimeArrow") end
				if polestar then for _, n in ipairs(POLESTAR.arrow) do add(n) end end
			end
			-- Naowh's Waypoint Pin, named above (nothing while Naowh is not there or the pin was never built)
			add("QuietHUDNaowhWaypointNav")
			add("QuietHUDNaowhWaypointPin")
			add("QuietHUDNaowhWaypointCue")
		elseif g == "chat" then
			-- Chattynator's chat window hangs off this frame (it has no size of its own, its windows are its children).
			-- Skipped when that addon is not there.
			add("ChattynatorHyperlinkHandler")
			-- Chattynator 240 (Nov 21) lays that frame over its first window at opacity 0 and makes the window ignore its
			-- parent's opacity, so the window stopped following the chat's fade (the owner, 2026-11-21: "qhud isnt hiding
			-- chattys black back box thing"; its text fades by itself, its background stayed). A window that ignores its
			-- parent's opacity is faded by its own name; the others still follow the frame above (both would fade them twice).
			-- Windows are looked for as the lists are built, like the pixel shift's (nameChattynator).
			local okC, chatty = pcall(isLoaded or function() end, "Chattynator")
			if okC and chatty then
				woc.nameChattynator()
				for i = 1, 10 do
					local w = woc.chattyWindows[i]
					local okI, own = pcall(function() return w and w.IsIgnoringParentAlpha and w:IsIgnoringParentAlpha() end)
					if okI and own then add("QuietHUDChattynator" .. i) end
				end
			end
		end
		-- (a name whose global is not a frame, a function or a number, is left out: /qhud add refuses one, a file changed by
		-- hand can still hold one)
		-- (WackyBars' frames are faded through its holders, with their Action bars row: one added here too faded twice,
		-- Faded times Faded; /qhud add refuses them now, a file from before can still hold one; audit Nov 10)
		for _, n in ipairs(DB.extra[g] or {}) do
			local v = _G[n]
			if (v == nil or type(v) == "table") and not n:find("^WackyBars") then
				extrasFor[g] = extrasFor[g] or {}
				table.insert(extrasFor[g], n)
			end
		end
		LISTS[g] = merged
	end
	-- A frame added by hand with /qhud add that QuietHUD now fades by itself, or that holds a frame it fades by itself (a
	-- layer as big as the screen, like Polestar's PolestarUIParent, under its guide window), is left out of a plain fade
	-- row: the built-in support wins, so nothing fades twice and nobody has to /qhud remove anything after an update (the
	-- owner, 2026-11-16: "if something wasnt added, and someone /added it, after we add support for it, whatever they
	-- /added gets ignored"). Compared by frame, so a frame QuietHUD lists under a name of its own (Naowh's pieces) counts.
	-- The hidden and mouseover rows keep their frames: those are choices, not a stand-in for support. /qhud list shows the
	-- ones left out, /qhud add says so. Cost: at a list rebuild only (a parent walk per built-in frame), nothing in the loop.
	local KEEP_EXTRA = { hidden = true, mouseover = true, shift = true }
	-- (a frame holding a built-in one counts only when it is as big as the screen, a layer like Polestar's: the game's own
	-- containers, RightManagedFrameContainer and BottomManagedFrameContainer, hold built-in frames next to boss frames, the
	-- extra action button and the like, which a hover add of them faded; second audit Nov 16, F3)
	local function screenWide(f)
		local ok, w, h, sc = pcall(function() return f:GetWidth(), f:GetHeight(), f:GetEffectiveScale() end)
		local W, H, S = UIParent:GetWidth(), UIParent:GetHeight(), UIParent:GetEffectiveScale()
		return ok and type(w) == "number" and type(h) == "number" and type(sc) == "number" and W > 0 and H > 0
			and w * sc >= 0.95 * W * S and h * sc >= 0.95 * H * S or false
	end
	local builtinFrame, builtinAncestor = {}, {}
	for g, list in pairs(LISTS) do
		if not KEEP_EXTRA[g] then
			for _, n in ipairs(list) do
				local f = _G[n]
				if type(f) == "table" and not builtinFrame[f] then
					builtinFrame[f] = g
					local p = f
					for _ = 1, 8 do
						local ok, parent = pcall(p.GetParent, p)
						if not ok or type(parent) ~= "table" or parent == UIParent or parent == WorldFrame then break end
						if not builtinAncestor[parent] then builtinAncestor[parent] = n end
						p = parent
					end
				end
			end
		end
	end
	woc.builtinFrame, woc.ignoredExtra = builtinFrame, {}
	woc.builtinAncestor = setmetatable({}, { __index = function(_, f) return builtinAncestor[f] and screenWide(f) and builtinAncestor[f] or nil end })
	for g, names in pairs(extrasFor) do
		local list, have = LISTS[g], {}
		for _, n in ipairs(list) do have[n] = true end
		for _, n in ipairs(names) do
			local f = _G[n]
			local mine = not KEEP_EXTRA[g] and type(f) == "table" and (builtinFrame[f] or (builtinAncestor[f] and screenWide(f)))
			if mine then
				woc.ignoredExtra[n] = builtinFrame[f] and ("QuietHUD fades it with its " .. woc.rowLabel(builtinFrame[f]) .. " row")
					or ("it holds " .. builtinAncestor[f] .. ", which QuietHUD fades by itself")
			elseif not have[n] then
				have[n] = true
				list[#list + 1] = n
			end
		end
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
	local handAdded = DB.extra.bars or {}
	for _, list in ipairs({ ACTION_BARS, ns.discovered, not dominosOwn and dominos.barHover or {}, handAdded }) do
		for _, n in ipairs(list) do
			-- (a built-in bar's own name stays even when a hand-added copy of it is left out; second audit Nov 16, F1)
			if not seen[n] and not wbSkip(n) and not (list == handAdded and woc.ignoredExtra[n]) then
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
	woc.absent = {} -- (a listed name with no frame yet: looked for again in woc.drift)
	for g, list in pairs(LISTS) do
		for _, n in ipairs(list) do
			woc.names[n] = true
			if SELF_FADING[n] then woc.selfFading[g] = true end
			if g ~= "shift" and _G[n] == nil then woc.absent[n] = true end
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
	-- (and the Action bars' own Faded, which its bars faded to while they sat in the Action bars list; audit Nov 17)
	if type(DB[d.fdKey]) ~= "number" or DB[d.fdKey] < 0 then DB[d.fdKey] = DB.fdBars end
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
-- 1.7.0 to the next. The controller's bar, aiming dot and button reminder box got a group of their own, a row each (the owner,
-- Nov 12); they faded with the Action bars row before, so each row starts as a copy of it: Fade, what shows it, Shown.
MIGRATIONS[4] = function(saved)
	for _, g in ipairs({ "PadBar", "PadDot", "PadLegend" }) do
		if saved["fade" .. g] == nil and type(saved.fadeBars) == "boolean" then saved["fade" .. g] = saved.fadeBars end
		if saved["trig" .. g] == nil and type(saved.trigBars) == "number" then saved["trig" .. g] = saved.trigBars end
		if saved["ov" .. g] == nil and type(saved.ovBars) == "number" then saved["ov" .. g] = saved.ovBars end
	end
end
-- (5: a settings update was tried for 1.7.3 on 2026-11-16 and dropped after the audit: unticking Fade on a row whose Shown
-- sat below the Global Faded wrote every action bar, lost Hide in combat and stranded the cast and breath bars. An element
-- set below the Global Faded now fades lower instead, the changelog says so. The number stays used: SETTINGS_VERSION 5.)
-- 1.7.3 to the next. 1.7.3 lowered the Faded of an element whose Shown was set below the Global Faded by the same share
-- (Shown 0.2 of a Global 0.8 faded to a quarter of the Global Faded). That rule is gone: an element fades to the Global Faded
-- or to its own (Faded per element, fd<Group>). An element that used the share gets the level it faded to as its own Faded,
-- so nothing changes on the screen and the level is now on the page. Only for an element that fades (Fade ticked) and has no
-- Faded of its own yet; not the cast bar and the breath bar, which have no row there and are only up for a cast or a timer.
-- Only a 1.7.3 file (version 5): before 1.7.3 such an element stayed at its Shown, which is the rule again now, so an older
-- file needs nothing (audit Nov 17: a 1.7.2 file's player frame went from 0.30 to 0.19). The file still holds its own
-- version while the updates run; initDB writes the new one after them.
MIGRATIONS[6] = function(saved)
	if saved.settingsVersion ~= 5 then return end
	local function get(k)
		local v = saved[k]
		if v == nil then v = DEFAULTS[k] end
		return v
	end
	local function num(k) local v = get(k); return type(v) == "number" and v or 0 end
	local base, idle = num("base"), num("idle")
	-- (a Global Faded at or above the Global Shown, only in a file changed by hand: the share never showed there)
	if base <= 0 or idle <= 0 or idle >= base then return end
	-- (its Shown, as the loop works it out, and whether it fades)
	local function own(key) local v = num(key); return v > 0 and math.max(v, 0.1) or nil end
	local list = {
		{ "fdBars", own("ovBars") or base, get("fadeBars") },
		{ "fdPlayer", own("ovPlayer") or base, get("fadePlayer") },
		{ "fdHud", own("ovHud") or base, get("fadeUnits") },
		{ "fdQuest", own("ovQuest") or base, get("fadeTracker") },
		{ "fdMap", own("ovMap") or (get("mapFollowsHud") and base or 1), get("fadeMinimap") },
		{ "fdChat", get("chatDim") and base or (num("chatOpacity") > 0 and num("chatOpacity") or 1), get("fadeChat") },
		{ "fdBagsBar", own("ovBagsBar") or base, get("fadeBags") },
		{ "fdMicro", own("ovMicro") or base, get("fadeMicro") },
		{ "fdRxp", num("rxpShown") > 0 and num("rxpShown") or base, true }, -- (these two as the loop reads them, no 0.1 floor)
		{ "fdNav", num("navShown") > 0 and num("navShown") or base, true },
	}
	for _, s in ipairs(SPLIT) do
		if not s.noGrid then
			local fades = saved[s.fadeKey]
			if fades == nil then
				if s.follows then fades = get(s.follows[1]) else fades = DEFAULTS[s.fadeKey] end
			end
			list[#list + 1] = { s.fdKey, own(s.ovKey) or base, fades }
		end
	end
	for _, e in ipairs(list) do
		local key, peak, fades = e[1], e[2], e[3]
		local has = type(saved[key]) == "number" and saved[key] >= 0
		if fades == true and not has and peak < idle - 0.001 then saved[key] = math.min(idle * peak / base, peak) end
	end
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
-- An element's Faded: its own (Faded per element on the Opacity page), else the Global Faded; 0 while Hide in combat holds
-- it. Never above its Shown: the callers take the lower of the two, so an element whose Shown is set below its Faded stays at
-- its Shown. (1.7.3 lowered the Faded of an element set below the Global Faded by the same share, with nothing on the page to
-- show it: a CurseForge ask, "set my player frame more transparent than everything else", that turned out to mean a Faded of
-- its own, 0.35 faded and the Global Shown on mouse over. The owner, Nov 17: no second bar on every row, so the list you add
-- to; and of the share, "cant we just remove it". MIGRATIONS[6] gives an element that used the share that level as its own
-- Faded, so nothing changes on the screen.)
-- g: the group, gone: Hide in combat holds it at 0 now.
woc.fadedFloor = function(g, gone)
	if gone then return 0 end
	local own = DB[ns.FADED_KEYS[g] or ""]
	if type(own) == "number" and own >= 0 then return own end
	return DB.idle or 0
end
local OVERRIDE_KEYS = { bars = "ovBars", player = "ovPlayer", hud = "ovHud", quest = "ovQuest", map = "ovMap", bags = "ovBagsBar", micro = "ovMicro" }
for _, s in ipairs(SPLIT) do OVERRIDE_KEYS[s.g] = s.ovKey end


-- For the files after this one (QuietHUD.toc).
ns.DB, ns.gFade, ns.gTrig, ns.LISTS, ns.elsewhere, ns.woc, ns.loop = DB, gFade, gTrig, LISTS, elsewhere, woc, loop
ns.wakeLoop, ns.trace, ns.discoverBars, ns.rebuildLists = wakeLoop, trace, discoverBars, rebuildLists
ns.mergeExtra, ns.settingChanged, ns.initDB, ns.OVERRIDE_KEYS = mergeExtra, settingChanged, initDB, OVERRIDE_KEYS
