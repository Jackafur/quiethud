-- What shows an element: the columns of the trigger grid (triggered), mouse over, moving, a dungeon or raid, the mouse
-- moving, and the player frame's health or power changing.
local _, ns = ...
local SPLIT = ns.SPLIT
local DB, gTrig, woc, wakeLoop = ns.DB, ns.gTrig, ns.woc, ns.wakeLoop
local barBit = ns.barBit

-- Visible, not just shown: a frame whose parent is hidden is not on the screen. ClassicUI Forever puts the buttons of a bar
-- that is turned off in the game's options into a hidden holder, and those buttons still say they are shown, so bars 6 to 8
-- (in the middle of the screen by default) woke the action bars while switched off.
-- A frame with qhudButtons (WackyBars' holders, Frames.lua) has no size of its own: its buttons count instead. Its parent
-- (the WackyBars bar) has a real size, so it is asked first: hidden or not under the mouse, no button of it can be, and its
-- buttons are not walked. Cost: one or two calls per holder per look instead of two per button.
local function hovered(f)
	if type(f) ~= "table" or not f.IsMouseOver or woc.noHover[f] then return false end
	local kids = f.qhudButtons
	if type(kids) == "table" then
		if #kids == 0 then return false end -- (most holders are empty: no call at all)
		local bar = f.GetParent and f:GetParent()
		if type(bar) == "table" and bar.IsMouseOver and bar.IsVisible and not (bar:IsVisible() and bar:IsMouseOver()) then
			return false
		end
		for i = 1, #kids do
			local b = kids[i]
			if b.IsVisible and b:IsVisible() and b:IsMouseOver() then return true end
		end
		return false
	end
	return f:IsVisible() and f:IsMouseOver()
end

local function anyHovered(names)
	for i = 1, #names do
		if hovered(_G[names[i]]) then return true end
	end
	return false
end

-- Some windows are a small frame with their panels hanging off it as children (the RestedXP guide is a bar with the
-- steps above it), so the frame's own rectangle is only part of what you see. This checks the children too. It looks
-- about ten times a second, because listing the children makes garbage. Each list keeps its own answer, so two groups
-- (the RestedXP windows, the chat) never answer for each other.
local deepCache = setmetatable({}, { __mode = "k" })
local function anyHoveredDeep(names)
	if not names then return false end
	local now = GetTime()
	local cache = deepCache[names]
	if not cache then
		cache = { at = 0, result = false }
		deepCache[names] = cache
	end
	if now - cache.at < 0.1 then return cache.result end
	cache.at, cache.result = now, false
	for i = 1, #names do
		local f = _G[names[i]]
		if hovered(f) then
			cache.result = true
			break
		end
		if type(f) == "table" and f.GetChildren and f:IsShown() then
			local kids = { f:GetChildren() }
			for j = 1, #kids do
				local c = kids[j]
				if c.IsShown and c.IsMouseOver and c:IsShown() and c:IsMouseOver() then
					cache.result = true
					break
				end
			end
			if cache.result then break end
		end
	end
	return cache.result
end

-- What brings an element up comes from its row of the trigger grid (bit i of the mask is trigger i): while moving, new
-- info, mouse over, hide in combat (which beats the rest), being inside a dungeon or raid, and the four wake columns:
-- combat, the weapon drawn, a target, the mouse moving. wake holds those four as they are right now (see update in
-- Loop.lua). COMBAT is Hide in combat, FIGHT is Show in combat (the two untick each other on the Elements page).
local T = { MOVING = 2, NEWS = 3, HOVER = 4, COMBAT = 5, INST = 6, FIGHT = 7, WEAPON = 8, TARGET = 9, MOUSE = 10 }
-- Whether one of a row's four wake columns is ticked and true right now.
local function woken(mask, wake)
	return (wake.fight and barBit(mask, T.FIGHT)) or (wake.weapon and barBit(mask, T.WEAPON))
		or (wake.target and barBit(mask, T.TARGET)) or (wake.mouse and barBit(mask, T.MOUSE)) or false
end
-- Whether any row has a column ticked: the weapon state and the mouse watcher are only looked at while a row can use them.
-- A row of an addon that is not loaded does not count (woc.off, see rebuildLists): it is not on the page to be unticked.
woc.anyRow = function(bit)
	local off = woc.off
	for _, k in ipairs(SPLIT.mainTrig) do
		if not (off and ((off.rxp and k == "trigRxp") or (off.nav and k == "trigNav"))) and barBit(DB[k], bit) then return true end
	end
	for _, s in ipairs(SPLIT) do
		if not (off and off[s.g]) and barBit(gTrig(s), bit) then return true end
	end
	return false
end
local function triggered(mask, wake, moved, news, combat, inside, names, deep, hoverNow)
	if barBit(mask, T.COMBAT) and combat then return false end
	if woken(mask, wake) then return true end
	if barBit(mask, T.MOVING) and moved then return true end
	if barBit(mask, T.NEWS) and news then return true end
	if barBit(mask, T.INST) and inside then return true end
	if barBit(mask, T.HOVER) then
		if hoverNow ~= nil then return hoverNow and true or false end
		if deep then return anyHoveredDeep(names) end
		return anyHovered(names) and true or false
	end
	return false
end

-- Moving is read two ways, so one of them failing (the game can hide the speed value) does not break it: the
-- walking speed, and whether the player's position changed since the last check.
local lastPosX, lastPosY = nil, nil
ns.lastMoveReason, ns.lastSpeedText = "none", "?"

-- On a flight path (or flying, where the game has it) moving does not count: the HUD stays faded in the air (a CurseForge
-- ask, 2026-11-06). The game is asked only when moving is checked, no new polling; a hidden or failed answer counts as not
-- flying.
local function yes(fn, ...)
	if not fn then return false end
	local ok, v = pcall(fn, ...)
	return ok and not (issecretvalue and issecretvalue(v)) and v and true or false
end
local function flightIgnored()
	return yes(UnitOnTaxi, "player") or yes(IsFlying)
end

-- forget: only forget the last position (the loop stopped asking, no row has Moving), so the next ask starts fresh.
local function isMoving(forget)
	if forget then
		lastPosX, lastPosY = nil, nil
		return false
	end
	local reason = "none"
	if flightIgnored() then
		lastPosX, lastPosY = nil, nil -- (so landing is not read as one long step)
		ns.lastMoveReason, ns.lastSpeedText = "flight", "?"
		return false
	end
	local speed = GetUnitSpeed("player")
	ns.lastSpeedText = (issecretvalue and issecretvalue(speed)) and "hidden" or tostring(speed)
	if not (issecretvalue and issecretvalue(speed)) and (speed or 0) > 0 then reason = "speed" end
	if UnitPosition then
		local y, x = UnitPosition("player")
		if type(x) == "number" and type(y) == "number" and not (issecretvalue and (issecretvalue(x) or issecretvalue(y))) then
			if reason == "none" and lastPosX and (math.abs(x - lastPosX) > 0.01 or math.abs(y - lastPosY) > 0.01) then
				reason = "position"
			end
			lastPosX, lastPosY = x, y
		end
	end
	ns.lastMoveReason = reason
	return reason ~= "none"
end

-- Any instance that is not PvP counts, so instance types this client adds or names differently still work.
-- The whole check is in a pcall and skips secret values, so it can never break the fade loop.
-- A test switch (/qhud fakeinstance): for trying the "Dungeon or raid" column without being in one. Not saved, so a reload ends it.
ns.fakeInstance = false
local function inDungeonOrRaid()
	if ns.fakeInstance then return true end
	if not IsInInstance then return false end
	local ok, inside, kind = pcall(IsInInstance)
	if not ok or (issecretvalue and (issecretvalue(inside) or issecretvalue(kind))) then return false end
	return inside and kind ~= "pvp" and kind ~= "arena" and true or false
end

-- The Mouse move column (off by default): true while the cursor moves, a controller stick is pushed (see below) or a mouse button is held (the cursor stands still
-- while the camera is turned with a button down), and for "Stay shown after the mouse stops" seconds after. Only looked at while a row has it ticked: one cursor position read per update,
-- compared with the one before.
local mouseActive
do
	local lastX, lastY, activeUntil = nil, nil, 0
	-- The stick read makes a table, so it has its own clock: at most ten reads a second, also while a fade runs the loop
	-- every frame; in between the last answer stands (padAt, padPushed).
	local padAt, padPushed = -1, false
	mouseActive = function(now)
		local stay = math.max(1, DB.mouseSeconds or 3)
		local ok, x, y = pcall(GetCursorPosition)
		if ok and type(x) == "number" and type(y) == "number" and not (issecretvalue and (issecretvalue(x) or issecretvalue(y))) then
			if lastX and (x ~= lastX or y ~= lastY) then activeUntil = now + stay end
			lastX, lastY = x, y
		end
		-- A controller's sticks count too, but only while the game says a controller is what you are playing with
		-- (ns.padActive, from the GAME_PAD_ACTIVE_CHANGED message in Events.lua): no stick is ever read for someone on
		-- mouse and keyboard. The Movement stick is left out (walking is the Moving column), under either of its names: the
		-- game treats "Left" and "Movement" as the same stick (Blizzard_RadialWheel.lua). The camera stick and any other
		-- count. len is 0 inside the game's dead zone.
		if ns.padActive and C_GamePad and C_GamePad.GetDeviceMappedState then
			if now - padAt >= 0.1 or now < padAt then
				padAt, padPushed = now, false
				local okS, state = pcall(C_GamePad.GetDeviceMappedState)
				if okS and type(state) == "table" and type(state.sticks) == "table" then
					for i, stick in ipairs(state.sticks) do
						if type(stick) == "table" and type(stick.len) == "number" and stick.len > 0 then
							local okN, name = pcall(C_GamePad.StickIndexToConfigName, i - 1) -- (0 based)
							if not (okN and (name == "Movement" or name == "Left")) then
								padPushed = true
								break
							end
						end
					end
				end
			end
			if padPushed then activeUntil = now + stay end
		end
		if IsMouseButtonDown then
			local okL, left = pcall(IsMouseButtonDown, "LeftButton")
			local okR, right = pcall(IsMouseButtonDown, "RightButton")
			if (okL and left) or (okR and right) then activeUntil = now + stay end
		end
		return now < activeUntil
	end
end

-- "Show the player frame while health or power is changing" (off by default): the player frame alone comes up while health or
-- the power bar on show goes up or down, and for a few seconds after the last change (HOLD). In practice: until you are topped
-- off, since regeneration stops there. It goes by the game's "health changed" and "power changed" messages and never by the
-- numbers: on client 70338 your own health and power are kept from addons (secret values) even outside a fight, and two secrets
-- cannot be combined, so "not full" cannot be read. Nothing runs on a timer, and with the box unticked nothing is listened to at
-- all. Not while dead or a ghost. Called from the main loop: on is whether the box counts now, now is GetTime().
local playerChanging
do
	-- How long after a change the frame stays: long enough that the next regeneration tick would have come. Health, energy and
	-- rage tick about every 2 seconds. Mana waits about 5 seconds after a cast first, so it needs longer, and so does a power
	-- change whose kind cannot be told at all (neither the message nor the bar on show says it).
	local HOLD = { short = 3, mana = 8 }
	local watcher, watching, changedAt, showUntil = CreateFrame("Frame"), false, 0, 0
	local function plain(v) return type(v) == "string" and not (issecretvalue and issecretvalue(v)) end
	watcher:SetScript("OnEvent", function(_, event, unit, token)
		-- Dying ends a wait that started while alive; the frame fades as usual.
		if event == "PLAYER_DEAD" then showUntil = 0 return end
		-- (only when the player-only listening was refused and every unit's changes arrive)
		if plain(unit) and unit ~= "player" then return end
		local hold = HOLD.short
		if event == "UNIT_POWER_UPDATE" then
			local ok, _, onShow = pcall(UnitPowerType, "player")
			onShow = ok and plain(onShow) and onShow or nil
			local kind = plain(token) and token or nil
			-- A power that is not the bar on show (combo points, a druid's mana in cat form) does not count.
			if kind and onShow and kind ~= onShow then return end
			kind = kind or onShow
			if not kind or kind == "MANA" then hold = HOLD.mana end
		end
		-- Only a plain "not dead" goes on: dead, a failed call and an answer the game keeps back all mean no say. A plain "dead"
		-- also ends a running wait, in case the "you died" message above never came.
		local okDead, dead = pcall(UnitIsDeadOrGhost, "player")
		if not okDead or (issecretvalue and issecretvalue(dead)) then return end
		if dead then showUntil = 0 return end
		changedAt = GetTime()
		-- (never cut short: a health tick does not end the longer wait a mana change started)
		showUntil = math.max(showUntil, changedAt + hold)
		wakeLoop()
	end)
	-- peek (for /qhud state): seconds since the last change that counted and seconds the frame still stays for it (nil: no
	-- change yet, or not listening).
	playerChanging = function(on, now, peek)
		if peek then
			if not watching or changedAt == 0 then return nil end
			return now - changedAt, math.max(0, showUntil - now)
		end
		if on ~= watching then
			watching, changedAt, showUntil = on, 0, 0
			if on then
				for _, e in ipairs({ "UNIT_HEALTH", "UNIT_POWER_UPDATE" }) do
					-- (for the player only; if the game refuses that, for every unit, sorted out when the message comes)
					if not pcall(watcher.RegisterUnitEvent, watcher, e, "player") then pcall(watcher.RegisterEvent, watcher, e) end
				end
				pcall(watcher.RegisterEvent, watcher, "PLAYER_DEAD")
			else
				pcall(watcher.UnregisterAllEvents, watcher)
			end
		end
		return on and now < showUntil
	end
end

-- Mouse over by itself (the owner, 2026-11-05: the Naowh bag counter came up with the bars and the bars with it). Two users:
-- the mouseover list (/qhud add mouseover, woc.mouseOnly below) and the bars ticked in the Action bars page's Mouse over
-- column (woc.mouseBars, ActionBars.lua). Each such frame or bar has its own 0 to 1 (c) that steps toward 1 while the mouse is
-- on it and toward 0 when it leaves, at the usual fade in and fade out times. Cost: one look per frame or bar at the loop's
-- 10 Hz, every frame only while one fades; nothing at all while the list is empty and no bar is ticked.
woc.moCur, woc.moA, woc.mbCur, woc.mbA = {}, {}, {}, {}
woc.moStep = function(c, target, dt)
	if c < target then return math.min(1, c + dt / ns.FADE) end
	if c > target then return math.max(0, c - dt / math.max(DB.fadeOutSeconds or ns.FADE, 0.01)) end
	return c
end
-- A frame or one of its children under the mouse (Naowh's bag counter is an empty holder with its card as a child).
-- The children are listed at most ten times a second per frame (listing them makes garbage; ChatGPT's audit, Nov 5).
woc.ocCache = setmetatable({}, { __mode = "k" })
woc.overOrChild = function(f)
	if hovered(f) then return true end
	if type(f) ~= "table" or not (f.GetChildren and f:IsShown()) then return false end
	local now, cache = GetTime(), woc.ocCache[f]
	if cache and now - cache.at < 0.1 then return cache.result end
	cache = cache or {}
	woc.ocCache[f] = cache
	cache.at, cache.result = now, false
	local kids = { f:GetChildren() }
	for j = 1, #kids do
		local k = kids[j]
		if k.IsShown and k.IsMouseOver and k:IsShown() and k:IsMouseOver() then
			cache.result = true
			break
		end
	end
	return cache.result
end
-- The frames of a row that count for its mouse over: only those the row owns (one also in the mouseover or hidden list is
-- that list's; second audit, F3, the same rule as the bars' woc.groupHover). Kept until the lists change.
woc.onCache = setmetatable({}, { __mode = "k" })
woc.ownedNames = function(g, names)
	if not names then return names end
	local cache = woc.onCache[names]
	if cache and cache.owner == woc.owner then return cache.out end
	local out = {}
	for _, n in ipairs(names) do
		local o = woc.owner[n]
		if o == nil or o == g then out[#out + 1] = n end
	end
	woc.onCache[names] = { owner = woc.owner, out = out }
	return out
end
-- The mouseover list. on: QuietHUD on and Edit Mode closed (else each frame goes back to full); all: show everything (the
-- peek key). Written on change; a frame owned by a later list (hidden) is left to it. Returns whether one is still fading.
woc.mouseOnly = function(dt, on, all)
	local busy, list = false, ns.LISTS.mouseover or {}
	for i = 1, #list do
		local n = list[i]
		local f = _G[n]
		if type(f) == "table" and f.SetAlpha and woc.owner[n] == "mouseover" then
			if not on then
				-- (moCur, not moA: woc.forget clears moA, and a frame faded to 0 must still be let go; audit F1)
				if woc.moCur[n] then woc.write(f, 1) end
				woc.moCur[n], woc.moA[n] = nil, nil
			else
				local target = (all or woc.overOrChild(f)) and 1 or 0
				local c = woc.moStep(woc.moCur[n] or 0, target, dt)
				if c ~= target then busy = true end
				woc.moCur[n] = c
				local peak = DB.base or 0.6
				local low = math.min(DB.idle or 0, peak)
				local a = low + (peak - low) * c
				if woc.moA[n] ~= a then
					woc.moA[n] = a
					woc.write(f, a)
				end
			end
		end
	end
	return busy
end

-- For the files after this one (QuietHUD.toc).
ns.hovered, ns.anyHovered, ns.anyHoveredDeep, ns.T, ns.triggered = hovered, anyHovered, anyHoveredDeep, T, triggered
ns.isMoving, ns.inDungeonOrRaid, ns.mouseActive = isMoving, inDungeonOrRaid, mouseActive
ns.flightIgnored = flightIgnored
ns.playerChanging = playerChanging
