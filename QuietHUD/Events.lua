-- The game's events (loading, login, combat, quests, zones, chat messages), the /qhud mouse watcher, and the key binding
-- names.
local ADDON, ns = ...
local MOVE_LINGER, CHAT_KINDS, chatKindOf = ns.MOVE_LINGER, ns.CHAT_KINDS, ns.chatKindOf
local DB, woc, loop, wakeLoop, trace, discoverBars = ns.DB, ns.woc, ns.loop, ns.wakeLoop, ns.trace, ns.discoverBars
local rebuildLists, initDB = ns.rebuildLists, ns.initDB
local barBit = ns.barBit
local T = ns.T
local bumpChat, buildChat = ns.bumpChat, ns.buildChat
local sheathToggled = ns.sheathToggled
local releaseNav = ns.releaseNav
local restoreShift = ns.restoreShift
local highlightedQuestID, run = ns.highlightedQuestID, ns.run
local frameChain = ns.frameChain

-- /qhud mouse: for each right-click, prints the frame that received it, what it is like, and whether the camera started
-- to turn. For finding out what takes a right-click that should turn the camera. The setting survives a reload.
ns.mouseRegistered = false
local function describeFrame(f)
	local parts = {}
	local okW, w = pcall(f.GetWidth, f)
	local okH, h = pcall(f.GetHeight, f)
	if okW and okH and type(w) == "number" and type(h) == "number" then parts[#parts + 1] = string.format("%.0fx%.0f", w, h) end
	if f.IsMouseEnabled then
		local ok, v = pcall(f.IsMouseEnabled, f)
		if ok then parts[#parts + 1] = "mouse=" .. tostring(v) end
	end
	if f.IsMouseClickEnabled then
		local ok, v = pcall(f.IsMouseClickEnabled, f)
		if ok then parts[#parts + 1] = "clicks=" .. tostring(v) end
	end
	local okShown, shown = pcall(f.IsShown, f)
	if okShown then parts[#parts + 1] = "shown=" .. tostring(shown) end
	local okA, a = pcall(f.GetEffectiveAlpha, f)
	if okA and type(a) == "number" then parts[#parts + 1] = string.format("alpha=%.2f", a) end
	return table.concat(parts, ", ")
end
local function reportRightClick()
	local list
	if GetMouseFoci then
		list = GetMouseFoci()
	elseif GetMouseFocus then
		list = { GetMouseFocus() }
	end
	local frame = list and list[1]
	if not frame or frame == WorldFrame then
		-- The click went to the game world, which is what should happen. Stay quiet unless the camera then fails to turn.
		if C_Timer and C_Timer.After and IsMouselooking and IsMouseButtonDown then
			C_Timer.After(0.3, function()
				if IsMouseButtonDown("RightButton") and not IsMouselooking() then
					print("QuietHUD: right-click went to the game world but the camera is not turning")
				end
			end)
		end
		return
	end
	print("QuietHUD: right-click landed on: " .. frameChain(frame) .. "  [" .. describeFrame(frame) .. "]")
	for i = 2, math.min(#list, 4) do
		print("QuietHUD:   also under the mouse: " .. frameChain(list[i]))
	end
	local okT, owner = pcall(function() return GameTooltip:IsShown() and GameTooltip:GetOwner() end)
	if okT and owner then print("QuietHUD:   a tooltip is showing, owned by: " .. frameChain(owner) .. "  [" .. describeFrame(owner) .. "]") end
	local okM, mm = pcall(function() return MinimapCluster:GetScale() end)
	if okM and type(mm) == "number" then print(string.format("QuietHUD:   minimap size factor %.3f", mm)) end
end
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:RegisterEvent("PLAYER_LEAVING_WORLD")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
pcall(ev.RegisterEvent, ev, "VARIABLES_LOADED")
pcall(ev.RegisterEvent, ev, "PLAYER_STARTED_MOVING")
pcall(ev.RegisterEvent, ev, "SUPER_TRACKING_CHANGED")
-- Whether a controller is what you are playing with right now: the game says so when you switch between controller and
-- mouse. Only while it is true does the Mouse move column read the sticks (Triggers.lua). At load: a controller that is
-- switched on in the game's options and plugged in counts until the game says otherwise.
pcall(ev.RegisterEvent, ev, "GAME_PAD_ACTIVE_CHANGED")
pcall(ev.RegisterEvent, ev, "GAME_PAD_DISCONNECTED")
do
	local ok, on = pcall(function()
		return C_GamePad.IsEnabled() and #C_GamePad.GetAllDeviceIDs() > 0
	end)
	ns.padActive = ok and on and true or false
end

local kindOf = {}
for _, e in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "QUEST_WATCH_UPDATE", "UI_INFO_MESSAGE" }) do
	kindOf[e] = "quest"
end
for _, e in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }) do
	kindOf[e] = "map"
end
for e in pairs(kindOf) do pcall(ev.RegisterEvent, ev, e) end
for e in pairs(chatKindOf) do pcall(ev.RegisterEvent, ev, e) end
-- The mouse press event is only listened to while the watcher is on, so none of this runs for anyone who has not asked.
-- The Mouse move column listens too: a press wakes the sleeping loop at once, so a click shorter than its tenth of
-- a second still counts (the handler below takes any event as a wake; the watcher's own line stays behind its setting).
ns.applyMouseWatch = function()
	local want = DB.watchMouse or (DB.enabled and woc.anyRow(T.MOUSE)) -- (only while a row has Mouse move ticked)
	if want and not ns.mouseRegistered then
		ns.mouseRegistered = pcall(ev.RegisterEvent, ev, "GLOBAL_MOUSE_DOWN")
	elseif not want and ns.mouseRegistered then
		pcall(ev.UnregisterEvent, ev, "GLOBAL_MOUSE_DOWN")
		ns.mouseRegistered = false
	end
end
ns.applyMouseWatch()

-- Spy's alarm brings the Spy row up (its New info column): every alert function Spy has, hooked once Spy is loaded (Spy
-- loads after QuietHUD; its Forever port replaces AlertPlayer while loading, so the hook goes on after). Cost: one time
-- written per alarm, nothing between alarms.
local SPY_ALARMS = { "AlertPlayer", "AlertStealthPlayer", "AlertProwlPlayer", "AlertWatch", "AlertGuild" }
local function hookSpy()
	local spy = _G.Spy
	if ns.spyHooked or type(spy) ~= "table" then return end
	ns.spyHooked = true
	for _, n in ipairs(SPY_ALARMS) do
		if type(spy[n]) == "function" then
			hooksecurefunc(spy, n, function()
				ns.spyUntil = GetTime() + (DB.questSeconds or 10)
				wakeLoop()
			end)
		end
	end
	-- Pixel shift moves Spy's window (Core.lua, the shift list). Spy places it again whenever its list changes size, from its
	-- saved spot or from where it is now (shift included): the shift is told which, so it never adds up into its place.
	if type(spy.RestoreMainWindowPosition) == "function" then
		hooksecurefunc(spy, "RestoreMainWindowPosition", function(_, x, y)
			if not ns.shiftOwnerPlaced then return end
			local pos = spy.db and spy.db.profile and spy.db.profile.MainWindow and spy.db.profile.MainWindow.Position
			ns.shiftOwnerPlaced(spy.MainWindow, pos ~= nil and pos.x == x and pos.y == y)
		end)
	end
end

ev:SetScript("OnEvent", function(_, event, arg1, _, _, arg4)
	wakeLoop()
	if event == "ADDON_LOADED" then
		woc.forget()
		if arg1 == ADDON then initDB() end
		if arg1 == "Warlock_Hud" then woc.watchWarlockMulti() end
		if arg1 == "Spy" then pcall(hookSpy) end
	elseif event == "VARIABLES_LOADED" then
		initDB()
	elseif event == "PLAYER_ENTERING_WORLD" then
		initDB()
		discoverBars()
		rebuildLists()
	elseif event == "PLAYER_LEAVING_WORLD" then
		-- (shifted frames go back before a logout or a loading screen, ahead of any addon saving its frames' places there,
		-- so a saved place never takes the shift in and creeps further each session; audit 2026-11-10 evening. The shift
		-- picks up again after it.)
		pcall(restoreShift)
	elseif event == "PLAYER_LOGOUT" then
		pcall(restoreShift)
		QuietHUDDB = DB
	elseif event == "PLAYER_LOGIN" then
		initDB()
		if ns.upgradeNote and C_Timer and C_Timer.After then -- (said once, after the login messages; see MIGRATIONS[1])
			local note = ns.upgradeNote
			ns.upgradeNote = nil
			C_Timer.After(8, function()
				print(note)
				ns.noticeUntil = GetTime() + 20 -- (the chat comes up so it is seen, see Loop.lua)
				wakeLoop()
			end)
		end
		pcall(hookSpy)
		ns.armEntry()
		discoverBars()
		rebuildLists()
		woc.watchWarlockHud()
		buildChat()
		if ToggleSheath then
			hooksecurefunc("ToggleSheath", function() sheathToggled("hook") end)
			ns.sheathHooked = true
		end
	elseif event == "GLOBAL_MOUSE_DOWN" then
		if DB.watchMouse and arg1 == "RightButton" then reportRightClick() end
	elseif event == "PLAYER_REGEN_DISABLED" then
		ns.drawn = true -- (only the fallback guess; see weaponDrawn)
	elseif event == "PLAYER_REGEN_ENABLED" then
		ns.combatEnd = GetTime() + (DB.linger or 4)
		run.combatWarned = false
		releaseNav()
		ns.armEntry()
		if loop.pending then woc.hookAll() end -- (protected frames first seen in the fight, see hookHover)
		if woc.clicksPending then woc.applyBarClicks() end -- (Click through set during a fight: now)
	elseif event == "PLAYER_STARTED_MOVING" then
		if not ns.flightIgnored() then ns.moveUntil = GetTime() + MOVE_LINGER end
	elseif event == "GAME_PAD_ACTIVE_CHANGED" then
		ns.padActive = arg1 and true or false
	elseif event == "GAME_PAD_DISCONNECTED" then
		ns.padActive = false
	elseif event == "SUPER_TRACKING_CHANGED" then
		-- The game re-tracks quests by itself when one makes progress. That is not a choice, so the quest key stays on the
		-- one you picked. Any other change is you clicking a quest, and the key follows it.
		if not (run.pinned and run.progressAt and GetTime() - run.progressAt < 1.5) then run.pinned = highlightedQuestID() end
	elseif kindOf[event] == "quest" then
		ns.questUntil = GetTime() + (DB.questSeconds or 10)
		if event == "QUEST_WATCH_UPDATE" or event == "UI_INFO_MESSAGE" then run.progressAt = GetTime() end
		if (event == "QUEST_REMOVED" or event == "QUEST_TURNED_IN") and arg1 == run.pinned then run.pinned = nil end
	elseif kindOf[event] == "map" then
		ns.mapUntil = GetTime() + (DB.questSeconds or 10)
	elseif chatKindOf[event] then
		local i = chatKindOf[event]
		if barBit(DB.chatKinds, i) then
			bumpChat()
			if ns.debugOn then
				local channel = ""
				if event == "CHAT_MSG_CHANNEL" and not (issecretvalue and issecretvalue(arg4)) then
					channel = " in " .. tostring(arg4)
				end
				trace("QuietHUD: chat woken by " .. event .. channel .. " (" .. CHAT_KINDS[i][1] .. ")")
			end
		end
	end
end)

BINDING_HEADER_QUIETHUD = "QuietHUD"
BINDING_NAME_QUIETHUD_TOGGLE = "Toggle Weapon drawn"
BINDING_NAME_QUIETHUD_PEEK = "Hold to show the whole HUD"
BINDING_NAME_QUIETHUD_PEEKTOGGLE = "Toggle the whole HUD"
_G["BINDING_NAME_CLICK QuietHUDTargetButton:LeftButton"] = "Target highlighted quest mob"
