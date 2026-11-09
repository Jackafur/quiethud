-- The main loop: update() works out how far each group is shown and writes its opacity; the driver runs it (the sleeping
-- loop, see Core.lua).
local _, ns = ...
local SPLIT, SPLIT_BY = ns.SPLIT, ns.SPLIT_BY
local MOVE_LINGER, BAR_DEFS, EXTRA_BUTTONS, FADE_ORDER = ns.MOVE_LINGER, ns.BAR_DEFS, ns.EXTRA_BUTTONS, ns.FADE_ORDER
local HIDE_TOGGLES = ns.HIDE_TOGGLES
local DB, gFade, gTrig, LISTS, woc, loop, wakeLoop = ns.DB, ns.gFade, ns.gTrig, ns.LISTS, ns.woc, ns.loop, ns.wakeLoop
local OVERRIDE_KEYS = ns.OVERRIDE_KEYS
local mirrorTimerActive, setAlpha, applyList, barBit = ns.mirrorTimerActive, ns.setAlpha, ns.applyList, ns.barBit
local step = ns.step
local applyBars, checkElsewhere, shortened, shortenOne = ns.applyBars, ns.checkElsewhere, ns.shortened, ns.shortenOne
local TEXT_SPECS = ns.TEXT_SPECS
local anyHovered, T, triggered, isMoving = ns.anyHovered, ns.T, ns.triggered, ns.isMoving
local inDungeonOrRaid, mouseActive, playerChanging = ns.inDungeonOrRaid, ns.mouseActive, ns.playerChanging
local applyChat, chatTyping, chatHovered = ns.applyChat, ns.chatTyping, ns.chatHovered
local weaponDrawn, keepDrawn = ns.weaponDrawn, ns.keepDrawn
local applyRxp, applyHosted, HOSTED = ns.applyRxp, ns.applyHosted, ns.HOSTED
local mapLog, applyMap, rememberMapRect = ns.mapLog, ns.applyMap, ns.rememberMapRect
local mouseInMapRect, setMinimapVisible = ns.mouseInMapRect, ns.setMinimapVisible
local tickShift = ns.tickShift
local applyTooltips = ns.applyTooltips
local fadeModels = ns.fadeModels

-- Per group, how far it is shown: 0 faded to 1 shown.
local cur = { bars = 0, player = 0, hud = 0, quest = 0, map = 0, chat = 0, nav = 0, rxp = 0, bags = 0, micro = 0 }
for _, s in ipairs(SPLIT) do cur[s.g] = 0 end
-- The groups QuietHUD holds below full (fading), the hidden lists it holds (hiddenOn), the bar texts it hid (textHidden).
local fading, hiddenOn, textHidden = {}, {}, {}
local minimapShown = true -- (false while the faded-out minimap is shrunk, see setMinimapVisible)
local hotkeyClock = 0 -- (the half-second pass at the end of update)
local lastLoggedMoving -- (the moving state the map log last wrote)
-- What update() works out each time it runs, in tables kept from one run to the next (new ones each run were garbage, about
-- 19 KB a second at idle): the four wake columns, whether each group is wanted, whether it fades, and in a fight whether it
-- is gone (Hide in combat). Every group's entry is set again on every run.
local wake, vis, flags, gone = {}, {}, {}, {}
woc.wake = wake -- (for /qhud state)
local GONE_KEYS = { bars = "trigBars", player = "trigPlayer", hud = "trigUnits", bags = "trigBagsBar", micro = "trigMicro",
	quest = "trigTracker", map = "trigMap", chat = "trigChat", nav = "trigNav", rxp = "trigRxp" }

-- The Issue Reporter button: its checkbox hides it; unticked it fades with the Menu bar row (see rebuildLists in Core.lua).
-- This turns the stored value into an opacity: 1 leaves the frame alone, 0 hides it.
local function fixedAlpha(key)
	local v = DB[key]
	if type(v) == "boolean" then return v and 0 or 1 end
	return v or 1
end

-- The opacity an element has of its own on the Opacity page, or nil when it follows Global (or is solid). An element that
-- does not fade (Fade unticked on the Elements page) stays at this opacity; without one it is left alone, fully solid.
local function ownOpacity(g)
	local v
	if g == "chat" then
		v = (not DB.chatDim) and DB.chatOpacity or nil
	elseif g == "map" then
		v = (not DB.mapFollowsHud) and DB.ovMap or nil
	elseif OVERRIDE_KEYS[g] then
		v = DB[OVERRIDE_KEYS[g]]
	end
	if v and v > 0 and v < 0.999 then return math.max(v, 0.1) end
	return nil
end

-- Sets a group to opacity a. allBars: every action bar, not only the ones picked on the Action bars page.
local function applyGroup(g, a, allBars)
	if g == "chat" then
		applyChat(a)
	elseif g == "rxp" then
		applyRxp(a)
	elseif g == "bars" then
		-- Low health and Low mana (ActionBars.lua): while the bars are below their Shown, the game sets the ticked ones.
		woc.lowGroupA = woc.lowOn and woc.barsPeak and a < woc.barsPeak - 0.001 and a or nil
		applyBars(a, not allBars)
		woc.lowGroupA = nil
	elseif HOSTED[g] then
		applyHosted(g, a)
	elseif g == "map" then
		-- The game redraws the map of a building interior, or of a city, as you move through it, and draws a blank map
		-- if that happens while the minimap frame is partly transparent (which includes every fade in and out). So the
		-- frame keeps opacity 1 and the map fades through its mask (see applyMap).
		applyMap(a)
	else
		applyList(g, a)
	end
end

-- Sets a group when its opacity changed since the last write, or when woc.forget was called (write on change, Core.lua). The
-- minimap group goes through every time: applyMap picks between the mask, the dark layer and plain opacity as you move, and
-- writes only on a change itself. So does a hosted list (the nav group, Naowh's alerts) while a frame taken out of it waits
-- for a fight to end, or one has no host yet. A cast bar or
-- a breath bar in a steady group is still written while it runs.
woc.group = function(g, a, allBars)
	if g == "map" or woc.hostWaits[g] then
		applyGroup(g, a, allBars)
		return
	end
	if woc.applied[g] == a and woc.all[g] == allBars then
		if woc.selfFading[g] then setAlpha(LISTS[g], a, true, g) end
		return
	end
	woc.applied[g], woc.all[g] = a, allBars
	applyGroup(g, a, allBars)
end

-- The cast bar's row stays up this long after a cast ends: crafting several bandages left a gap between two casts where the
-- row faded, and the next cast came up from that dip, a fast blink at every craft. The bar itself is not written then (it
-- fades itself out, SELF_FADING).
local CAST_LINGER = 0.75
local castUntil = 0

local function update(dt)
	local now = GetTime()
	-- Edit Mode, or Naowh's HUD Editor (its mover plates sit inside the frames, so a faded frame would hide its plate; see
	-- rebuildLists in Core.lua): everything is shown in full and the pixel shift puts every frame back.
	local edit = (EditModeManagerFrame and EditModeManagerFrame:IsShown()) or ns.naowhEditing or false
	local combat = UnitAffectingCombat("player") and true or false
	local enabled = DB.enabled

	local inside = inDungeonOrRaid()
	woc.mouseMembership(enabled and not edit) -- (before any group is written)
	-- The four wake columns. The weapon is only asked about while a row has Weapon ticked, and the mouse only while a row has
	-- Mouse move ticked (nothing is asked every frame that nothing uses).
	local weaponOut = false
	if woc.anyRow(T.WEAPON) then
		local state
		weaponOut, state = weaponDrawn()
		-- (the weapon the game put away counts as out while QuietHUD draws it again; see keepDrawn)
		if keepDrawn((enabled and DB.keepDrawn) and true or false, now, state, combat) then weaponOut = true end
	else
		keepDrawn(false) -- (forgets the weapon state, so nothing is drawn on old news when a Weapon box is ticked again)
	end
	wake.fight = combat or now < ns.combatEnd
	wake.weapon = weaponOut
	wake.target = UnitExists("target") and true or false
	wake.mouse = woc.anyRow(T.MOUSE) and mouseActive(now) and true or false
	local okMove, moving = pcall(isMoving)
	if okMove and moving then ns.moveUntil = now + MOVE_LINGER end
	if (okMove and moving and true or false) ~= lastLoggedMoving then
		lastLoggedMoving = okMove and moving and true or false
		mapLog(string.format("moving=%s by %s (speed %s, fade=%s, triggers=%s, idle opacity=%s)", tostring(lastLoggedMoving),
			ns.lastMoveReason, ns.lastSpeedText, tostring(DB.fadeMinimap), tostring(DB.trigMap), tostring(DB.idle)))
	end

	local moved = now < ns.moveUntil
	-- (frames added with /qhud add bars count for mouse over with their children: a Naowh bag counter is an empty holder with its card as a child)
	local barNames = woc.groupHover() -- (without the bars that have Mouse over of their own, woc.mouseBars)
	vis.bars = triggered(DB.trigBars, wake, moved, false, combat, inside, barNames, false,
		barBit(DB.trigBars, T.HOVER) and (anyHovered(barNames) or (woc.groupExtras() and ns.anyHoveredDeep(woc.groupExtras())) or false) or nil)
	vis.player = triggered(DB.trigPlayer, wake, moved, false, combat, inside, LISTS.player)
	-- Health or power changing brings the player frame up too (its own box on the Show when page); Hide in combat still wins.
	if playerChanging((enabled and DB.notFullShows) and true or false, now) and not (combat and barBit(DB.trigPlayer, T.COMBAT)) then
		vis.player = true
	end
	vis.hud = triggered(DB.trigUnits, wake, moved, false, combat, inside, LISTS.hud)
	for _, s in ipairs(SPLIT) do
		vis[s.g] = triggered(gTrig(s), wake, moved, false, combat, inside, s.hover or woc.ownedNames(s.g, LISTS[s.g]), s.deep)
	end
	-- Casting shows the cast bar (not when it is set to hide in combat and you are in combat). A running breath, fatigue or feign
	-- death timer shows the breath bar whatever its settings: with the HUD idle the breath bar would be invisible while you drown.
	local castBar = PlayerCastingBarFrame or CastingBarFrame
	if castBar and (castBar.casting or castBar.channeling) then castUntil = now + CAST_LINGER end
	if now < castUntil and not (combat and barBit(gTrig(SPLIT_BY.cast), T.COMBAT)) then vis.cast = true end
	if mirrorTimerActive() then vis.breath = true end
	vis.bags = triggered(DB.trigBagsBar, wake, moved, false, combat, inside, LISTS.bags)
	vis.micro = triggered(DB.trigMicro, wake, moved, false, combat, inside, LISTS.micro)
	vis.quest = triggered(DB.trigTracker, wake, moved, now < ns.questUntil, combat, inside, LISTS.quest)
	vis.map = triggered(DB.trigMap, wake, moved, now < ns.mapUntil, combat, inside, LISTS.map, false,
		barBit(DB.trigMap, T.HOVER) and (mouseInMapRect() or anyHovered(LISTS.map)) or false)
	-- Chat is the one element whose hover is a list of frames, and typing always brings it up, even in combat.
	local chatMask = DB.trigChat
	-- (through triggered, with the chat's own hover answer)
	local chatWanted = triggered(chatMask, wake, moved, now < ns.chatUntil, combat, inside, nil, false,
		barBit(chatMask, T.HOVER) and chatHovered() or false)
	-- (the one-time update note brings the chat up for a moment by itself, whatever its boxes say: audit 2026-11-06 update
	-- path F3)
	vis.chat = (chatWanted or chatTyping() or now < (ns.noticeUntil or 0)) and true or false
	vis.nav = ns.navForce or triggered(DB.trigNav, wake, moved, false, combat, inside, LISTS.nav)
	vis.rxp = triggered(DB.trigRxp, wake, moved, now < ns.questUntil, combat, inside, LISTS.rxp, true)
	local showAll = edit or now < ns.peekUntil or (DB.peekAlt and IsAltKeyDown()) or (DB.peekCtrl and IsControlKeyDown())
		or (DB.peekShift and IsShiftKeyDown())
	if showAll then
		for g in pairs(vis) do vis[g] = true end
	end

	flags.bars, flags.player, flags.hud = DB.fadeBars, DB.fadePlayer, DB.fadeUnits
	flags.quest, flags.map, flags.chat, flags.nav, flags.rxp = DB.fadeTracker, DB.fadeMinimap, DB.fadeChat, true, true
	flags.bags, flags.micro = DB.fadeBags, DB.fadeMicro
	for _, s in ipairs(SPLIT) do flags[s.g] = gFade(s) end
	if DB.hidePanel then flags.panel = true end
	local idle = DB.idle or 0
	-- Hide in combat (bit 5): in a fight the element goes all the way to 0, whatever its Faded opacity. Only worked out in a
	-- fight: one bit per element per update then, nothing outside one.
	local goneNow = combat and gone or nil
	if combat then
		for g, key in pairs(GONE_KEYS) do gone[g] = barBit(DB[key], T.COMBAT) end
		for _, s in ipairs(SPLIT) do
			if not s.noGrid then gone[s.g] = barBit(gTrig(s), T.COMBAT) end
		end
	end
	-- The Low health and Low mana columns (ActionBars.lua): listened to only while a bar is ticked; a change of whether it
	-- counts now writes the bars again.
	woc.lowListen(enabled and (DB.barLow or 0) > 0, enabled and (DB.barMana or 0) > 0)
	local lowOn = (enabled and ((DB.barLow or 0) > 0 or (DB.barMana or 0) > 0) and DB.fadeBars and not edit
		and not (combat and barBit(DB.trigBars, T.COMBAT))) and true or false
	if lowOn then -- (asked only while a bar is ticked)
		local okDead, dead = pcall(UnitIsDeadOrGhost, "player")
		if okDead and dead then lowOn = false end
	end
	if lowOn ~= (woc.lowOn or false) then
		woc.lowOn = lowOn
		woc.applied.bars, woc.mbA = nil, {} -- (the group and the Mouse over bars)
	end
	local mapAlpha, anyFade = 1, false
	for _, g in ipairs(FADE_ORDER) do
		-- Fade is off for this element, but it has an opacity of its own: it stays at that opacity (Edit Mode shows it solid).
		local fixedA = enabled and not edit and not flags[g] and ownOpacity(g)
		if enabled and flags[g] then
			local target = vis[g] and 1 or 0
			if cur[g] ~= target then anyFade = true end
			-- (a fade that starts on a tick, after up to a tenth of a second asleep, begins with one small step, not a jump)
			cur[g] = step(cur[g], target, loop.moving and dt or math.min(dt, 1 / 60), g == "chat" and DB.chatFadeSeconds or DB.fadeOutSeconds)
			local peak = DB.base or 0.75
			if edit or (g == "map" and not DB.mapFollowsHud) then
				peak = 1
			elseif g == "chat" and not DB.chatDim then
				peak = DB.chatOpacity or 1
			elseif g == "rxp" and (DB.rxpShown or 0) > 0 then -- (RestedXP's own Shown; 0 is Global)
				peak = DB.rxpShown
			elseif g == "nav" and (DB.navShown or 0) > 0 then
				peak = DB.navShown
			end
			-- An element with its own opacity (Opacity page) uses that instead of the Global Shown.
			local ownKey = OVERRIDE_KEYS[g]
			if ownKey and not edit and (DB[ownKey] or 0) > 0 then peak = math.max(DB[ownKey], 0.1) end
			if g == "bars" then woc.barsPeak = peak end
			-- Everything fades to the Global Faded.
			local floor = idle
			if goneNow and goneNow[g] then floor = 0 end
			local low = math.min(floor, peak)
			local a = low + (peak - low) * cur[g]
			if g == "panel" and DB.hidePanel and not edit then a = 0 end
			woc.group(g, a, false)
			if g == "map" then mapAlpha = a end
			fading[g] = true
		elseif fixedA then
			woc.group(g, fixedA, true)
			fading[g] = true
			cur[g] = 1
		elseif fading[g] then
			woc.group(g, 1, true)
			fading[g] = false
			cur[g] = 1
		end
	end


	pcall(fadeModels, now)

	-- The minimap grows back as soon as something brings it up, not once its opacity has risen: a fight's start is the last
	-- moment it can be scaled (see setMinimapVisible). Hide in combat shrinks it at that moment too. In a fight a refused
	-- change is asked again on the next update.
	local wantMinimap = not (enabled and DB.fadeMinimap) or ((mapAlpha > 0.01 or vis.map)
		and not (goneNow and goneNow.map and not vis.map))
	if MinimapCluster and wantMinimap ~= minimapShown and setMinimapVisible(wantMinimap, mapAlpha) then
		minimapShown = wantMinimap
	end

	for _, pair in ipairs(HIDE_TOGGLES) do
		local fixed = enabled and not edit and fixedAlpha(pair[2]) or 1
		if fixed < 0.999 then
			woc.group(pair[1], fixed, false)
			hiddenOn[pair[1]] = true
		elseif hiddenOn[pair[1]] then
			woc.group(pair[1], 1, false)
			hiddenOn[pair[1]] = false
		end
	end
	-- The mouseover list and the bars with Mouse over of their own (Triggers.lua, ActionBars.lua).
	if woc.mouseOnly(dt, enabled and not edit, showAll) then anyFade = true end
	if woc.mouseBars(dt, showAll, combat and barBit(DB.trigBars, T.COMBAT)) then anyFade = true end
	if enabled and not edit then
		woc.group("hidden", 0, false)
		hiddenOn.hidden = true
	elseif hiddenOn.hidden then
		woc.group("hidden", 1, false)
		hiddenOn.hidden = false
	end

	-- Pixel shift: once a second, and at once when Edit Mode opens or closes.
	tickShift(dt, now, edit)
	applyTooltips()

	hotkeyClock = hotkeyClock + dt
	if hotkeyClock > 0.5 then
		hotkeyClock = 0
		pcall(checkElsewhere)
		pcall(woc.drift)
		if MinimapCluster and MinimapCluster:GetScale() > 0.5 then pcall(rememberMapRect) end
		if MinimapCluster and ns.mapSavedScale and MinimapCluster:GetScale() > 0.01 and ns.canScaleMap() then ns.setMapScale(0.001) end
		local wantShort = enabled and DB.shortHotkeys
		for i = 1, #BAR_DEFS do
			for j = 1, 12 do
				local fs = _G[BAR_DEFS[i].buttons .. j .. "HotKey"]
				if fs and (wantShort or shortened[fs]) then shortenOne(fs, wantShort) end
			end
			for _, spec in ipairs(TEXT_SPECS) do
				local on = enabled and barBit(DB[spec[2]], i)
				local tag = spec[1] .. i
				if on or textHidden[tag] then
					for j = 1, 12 do
						local fs = _G[BAR_DEFS[i].buttons .. j .. spec[1]]
						if fs then fs:SetAlpha(on and 0 or 1) end
					end
					textHidden[tag] = on and true or false
				end
			end
		end
		for _, set in ipairs(EXTRA_BUTTONS) do
			for j = 1, set[2] do
				local fs = _G[set[1] .. j .. "HotKey"]
				if fs and (wantShort or shortened[fs]) then shortenOne(fs, wantShort) end
			end
		end
	end
	loop.moving = anyFade
end

local lastError
local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, dt)
	loop.clock = loop.clock + dt
	if not (loop.wake or loop.moving or loop.clock >= 0.1) then
		-- Asleep, one thing is still looked at every frame, and only while a tooltip is on screen with the tooltip opacity
		-- below full: the game puts a tooltip back to full when something sets new content on it, and a frame that does so
		-- in its own update after the tooltip's (an action button refreshing its tooltip) would flash it until the next tick.
		if loop.tips then pcall(applyTooltips) end
		return
	end
	local elapsed = loop.clock
	loop.clock, loop.wake = 0, false
	local ok, err = pcall(update, elapsed)
	if not ok and err ~= lastError then
		lastError = err
		print("QuietHUD error (shown once): " .. tostring(err))
	end
end)
-- The messages that wake the loop besides the ones QuietHUD's own handlers already take (see wakeLoop).
do
	local waker = CreateFrame("Frame")
	for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "PLAYER_STOPPED_MOVING", "MODIFIER_STATE_CHANGED",
		"PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "UPDATE_SHAPESHIFT_FORM", "PLAYER_MOUNT_DISPLAY_CHANGED", "UNIT_PET",
		"GROUP_ROSTER_UPDATE", "UI_SCALE_CHANGED" }) do
		pcall(waker.RegisterEvent, waker, e)
	end
	for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
		"UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_SUCCEEDED" }) do
		if not pcall(waker.RegisterUnitEvent, waker, e, "player") then pcall(waker.RegisterEvent, waker, e) end
	end
	waker:SetScript("OnEvent", wakeLoop)
	-- A fight starting runs one update at once, while the game still lets the minimap be scaled (see setMinimapVisible): the
	-- next frame would already be in the fight. Once per fight.
	local fightStart = CreateFrame("Frame")
	fightStart:RegisterEvent("PLAYER_REGEN_DISABLED")
	-- (the loop's own pace is left as it was: the fade itself starts on the next frame, as for any other message)
	fightStart:SetScript("OnEvent", function()
		local wasMoving = loop.moving
		local ok, err = pcall(update, 0)
		loop.moving, loop.wake = wasMoving, true
		if not ok and err ~= lastError then
			lastError = err
			print("QuietHUD error (shown once): " .. tostring(err))
		end
	end)
	if EditModeManagerFrame and EditModeManagerFrame.HookScript then
		pcall(EditModeManagerFrame.HookScript, EditModeManagerFrame, "OnShow", wakeLoop)
		pcall(EditModeManagerFrame.HookScript, EditModeManagerFrame, "OnHide", wakeLoop)
	end
end
-- The tap watcher (the Tap boxes on the Show when page): a ticked Alt, Ctrl or Shift pressed and let go within
-- TAP_SECONDS, with no other key or mouse button going down meanwhile, flips the whole HUD on or off (ns.peekUntil, as the
-- Toggle the whole HUD key). The game says when a modifier goes down or up (MODIFIER_STATE_CHANGED) but not which other
-- keys are pressed with it, so while a ticked key is held, and only then, it asks the game every frame whether any key
-- that has a binding (its base key: "1" for ALT-1, so a [mod:alt] macro on 1 counts too) or a mouse button is down.
-- Per frame only while the key is held and its Tap box is ticked; nothing otherwise. A key already down when the modifier went
-- down (running with W held, the camera turned with the mouse) does not spoil the tap.
do
	local TAP_SECONDS = 0.4
	local MODS = { ALT = { "peekTapAlt", IsAltKeyDown }, CTRL = { "peekTapCtrl", IsControlKeyDown },
		SHIFT = { "peekTapShift", IsShiftKeyDown } }
	local BUTTONS = { "LeftButton", "RightButton", "MiddleButton", "Button4", "Button5" }
	local keys -- the base keys of every binding, built on first use and again when the bindings change
	local function buildKeys()
		keys = {}
		local seen = {}
		for i = 1, (GetNumBindings and GetNumBindings() or 0) do
			local b = { select(3, GetBinding(i)) }
			for _, k in ipairs(b) do
				if type(k) == "string" then
					local base = k:match("([^%-]+)$") or k
					if base ~= "" and not base:find("^MOUSEWHEEL") and not seen[base] then
						seen[base] = true
						keys[#keys + 1] = base
					end
				end
			end
		end
	end
	local tapMod, tapStart, spoiled, before = nil, 0, false, {}
	local function anyNewDown()
		for _, k in ipairs(keys) do
			if not before[k] and IsKeyDown(k) then return true end
		end
		for _, b in ipairs(BUTTONS) do
			if not before[b] and IsMouseButtonDown(b) then return true end
		end
		return false
	end
	local watcher = CreateFrame("Frame")
	local function onUpdate()
		if not spoiled and anyNewDown() then spoiled = true end
		if spoiled then watcher:SetScript("OnUpdate", nil) end -- (nothing left to learn until the key is let go)
	end
	local function othersDown(mod)
		for m, v in pairs(MODS) do
			if m ~= mod and v[2]() then return true end
		end
		return false
	end
	watcher:RegisterEvent("MODIFIER_STATE_CHANGED")
	watcher:RegisterEvent("UPDATE_BINDINGS")
	watcher:SetScript("OnEvent", function(_, event, key, down)
		if event == "UPDATE_BINDINGS" then keys = nil return end
		local mod = type(key) == "string" and key:match("^[LR](%u+)$")
		if not (mod and MODS[mod]) then return end
		if down == 1 then
			if not DB[MODS[mod][1]] then return end
			if not keys then buildKeys() end
			tapMod, tapStart, spoiled = mod, GetTime(), othersDown(mod)
			before = {}
			for _, k in ipairs(keys) do if IsKeyDown(k) then before[k] = true end end
			for _, b in ipairs(BUTTONS) do if IsMouseButtonDown(b) then before[b] = true end end
			if not spoiled then watcher:SetScript("OnUpdate", onUpdate) end
		elseif mod == tapMod then
			watcher:SetScript("OnUpdate", nil)
			tapMod = nil
			if spoiled or anyNewDown() or othersDown(mod) or GetTime() - tapStart > TAP_SECONDS then return end
			local now = GetTime()
			ns.peekUntil = now < ns.peekUntil and 0 or math.huge
			wakeLoop()
		end
	end)
end
