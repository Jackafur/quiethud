-- Setting opacity: a list of frames (setAlpha, applyList), the mirror timers the breath bar waits for, and the small helpers
-- every file uses (barBit, step).
local _, ns = ...
local FADE, SELF_FADING = ns.FADE, ns.SELF_FADING
local LISTS, woc, wakeLoop, trace = ns.LISTS, ns.woc, ns.wakeLoop, ns.trace

-- Whether a mirror timer (breath, fatigue, feign death) is running. Kept from the game's MIRROR_TIMER_START and _STOP events
-- (the game's own breath bar works from them on Forever too), and asked from the game when you enter the world, in case one was
-- already running, never polled. With /qhud debug on, each start and stop is printed.
local mirror = { running = {} }
local function mirrorTimerActive()
	return next(mirror.running) ~= nil
end
do
	local function usable(name)
		return type(name) == "string" and not (issecretvalue and issecretvalue(name)) and name ~= "" and name ~= "UNKNOWN"
	end
	local events = CreateFrame("Frame")
	for _, e in ipairs({ "MIRROR_TIMER_START", "MIRROR_TIMER_STOP", "PLAYER_ENTERING_WORLD" }) do
		pcall(events.RegisterEvent, events, e)
	end
	events:SetScript("OnEvent", function(_, event, timer)
		wakeLoop()
		if event == "PLAYER_ENTERING_WORLD" then
			mirror.running = {}
			for i = 1, 3 do
				local ok, name = pcall(GetMirrorTimerInfo or error, i)
				if ok and usable(name) then mirror.running[name] = true end
			end
		else
			-- (a name the game hides is kept as "?", so its stop still matches its start)
			local name = usable(timer) and timer or "?"
			mirror.running[name] = event == "MIRROR_TIMER_START" or nil
			trace("QuietHUD: " .. (event == "MIRROR_TIMER_START" and "started" or "stopped") .. " timer " .. name
				.. ", breath bar shown by QuietHUD: " .. tostring(mirrorTimerActive()))
		end
	end)
end

-- A cast bar another addon hid during a cast is left hidden (the owner, 2026-11-06, crafting bandages: "cast bar freaks out").
-- The game sets a cast bar to 1 when a cast starts and never to 0 during one, so 0 in a cast that QuietHUD did not write is
-- someone else's: Naowh's craft timer hides the cast bars every frame while you craft (NaowhForever_Professions
-- CraftTimer.lua, unless its "show cast bar" setting is on), and QuietHUD putting it back each update made it blink.
-- selfWrote: what QuietHUD last wrote to such a frame (weak keys).
local selfWrote = setmetatable({}, { __mode = "k" })
local function hiddenByOther(f)
	local ok, now = pcall(f.GetAlpha, f)
	if not ok or type(now) ~= "number" or (issecretvalue and issecretvalue(now)) then return false end
	return now < 0.01 and (selfWrote[f] or 1) >= 0.01
end

-- list: the list being written; a frame that belongs to another list (woc.owner) is left to that one.
local function setAlpha(names, a, onlySelfFading, list)
	for i = 1, #names do
		local f = _G[names[i]]
		local owner = list and woc.owner[names[i]]
		if f and f.SetAlpha and (owner == nil or owner == list) then
			if SELF_FADING[names[i]] then
				local kind = SELF_FADING[names[i]]
				if (kind == "cast" and (f.casting or f.channeling) and not hiddenByOther(f)) or (kind == "mirror" and mirrorTimerActive()) then
					f:SetAlpha(a)
					selfWrote[f] = a
				end
			else
				if not onlySelfFading then woc.write(f, a) end
			end
		end
	end
end

local function applyList(name, a)
	setAlpha(LISTS[name], a, nil, name)
end

-- Per-bar options are stored as a bitmask: bit i is Action Bar i.
local function barBit(mask, i)
	return (math.floor((mask or 0) / 2 ^ (i - 1)) % 2) == 1
end

-- Fading in takes FADE. Fading out takes the "Fade out animation" time of the Show when page (FADE unless it was changed), and
-- the chat has a fade-out time of its own.
local function step(v, target, dt, outSeconds)
	if v < target then return math.min(target, v + dt / FADE) end
	return math.max(target, v - dt / math.max(0.05, outSeconds or FADE))
end

-- For the files after this one (QuietHUD.toc).
ns.mirrorTimerActive, ns.setAlpha, ns.applyList, ns.barBit = mirrorTimerActive, setAlpha, applyList, barBit
ns.step = step
