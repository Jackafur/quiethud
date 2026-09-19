local ADDON = ...

-- Settings. code is the short key used when the settings are stored as text.
local FIELDS = {
	{ key = "enabled", code = "e", kind = "bool", def = true },
	{ key = "base", code = "b", kind = "num", def = 0.6 },
	{ key = "idle", code = "i", kind = "num", def = 0 },
	{ key = "inCombat", code = "k", kind = "bool", def = true },
	{ key = "sheathShows", code = "w", kind = "bool", def = true },
	{ key = "showOnTarget", code = "t", kind = "bool", def = false },
	{ key = "inInstance", code = "ii", kind = "bool", def = false },
	{ key = "barsMouseover", code = "o", kind = "bool", def = true },
	{ key = "linger", code = "l", kind = "num", def = 4 },
	{ key = "fadeBars", code = "fb", kind = "bool", def = true },
	{ key = "fadePlayer", code = "fp", kind = "bool", def = true },
	{ key = "fadeUnits", code = "fu", kind = "bool", def = true },
	{ key = "fadeMinimap", code = "fm", kind = "bool", def = true },
	{ key = "minimapMoving", code = "m", kind = "bool", def = true },
	{ key = "minimapDim", code = "md", kind = "bool", def = false },
	{ key = "mapDimOpacity", code = "mo", kind = "num", def = 0.3 },
	{ key = "fadeTracker", code = "fq", kind = "bool", def = true },
	{ key = "fadeChat", code = "fc", kind = "bool", def = true },
	{ key = "chatDim", code = "cd", kind = "bool", def = false },
	{ key = "chatSeconds", code = "c", kind = "num", def = 8 },
	{ key = "chatKinds", code = "ck", kind = "num", def = 71 },
	{ key = "questSeconds", code = "q", kind = "num", def = 10 },
	{ key = "hideBags", code = "hb", kind = "bool", def = false },
	{ key = "hideMicro", code = "hm", kind = "bool", def = false },
	{ key = "barFade", code = "af", kind = "num", def = 255 },
	{ key = "barHotkeys", code = "ah", kind = "num", def = 0 },
	{ key = "barNames", code = "an", kind = "num", def = 0 },
	{ key = "hideReporter", code = "hr", kind = "bool", def = false },
	{ key = "questTarget", code = "qt", kind = "bool", def = false },
}
local DEFAULTS, BY_CODE = {}, {}
for _, f in ipairs(FIELDS) do
	DEFAULTS[f.key] = f.def
	BY_CODE[f.code] = f
end

local FADE = 0.35
local MOVE_LINGER = 1.5
local SKULL = 8

local DEFAULT_LISTS = {
	bars = { "StatusTrackingBarManager", "StanceBar", "PetActionBar", "PossessActionBar" },
	player = { "PlayerFrame", "PlayerCastingBarFrame", "CastingBarFrame" },
	hud = {
		"TargetFrame", "FocusFrame", "PetFrame", "PartyFrame", "CompactRaidFrameContainer",
		"CompactRaidFrameManager", "BuffFrame", "DebuffFrame", "TemporaryEnchantFrame", "DamageMeter",
		"TotemFrame", "EssentialCooldownViewer", "UtilityCooldownViewer",
		"BuffIconCooldownViewer", "BuffBarCooldownViewer",
	},
	quest = { "ObjectiveTrackerFrame" },
	map = { "MinimapCluster" },
	micro = { "MicroMenuContainer" },
	bags = { "BagsBar" },
	reporter = { "PTR_IssueReporter", "PTR_IssueReporterButton", "PTR_IssueReporterFrame" },
	hidden = {},
}
local ALL_LISTS = { "bars", "player", "hud", "quest", "map", "micro", "bags", "reporter", "hidden" }
-- Action Bars 1 to 8: the frame(s) of each bar and the prefix of its button names.
local BAR_DEFS = {
	{ frames = { "MainActionBar", "MainMenuBar" }, buttons = "ActionButton" },
	{ frames = { "MultiBarBottomLeft" }, buttons = "MultiBarBottomLeftButton" },
	{ frames = { "MultiBarBottomRight" }, buttons = "MultiBarBottomRightButton" },
	{ frames = { "MultiBarRight" }, buttons = "MultiBarRightButton" },
	{ frames = { "MultiBarLeft" }, buttons = "MultiBarLeftButton" },
	{ frames = { "MultiBar5" }, buttons = "MultiBar5Button" },
	{ frames = { "MultiBar6" }, buttons = "MultiBar6Button" },
	{ frames = { "MultiBar7" }, buttons = "MultiBar7Button" },
}
local KNOWN_BAR_FRAMES = {}
for i, def in ipairs(BAR_DEFS) do
	DEFAULT_LISTS["bar" .. i] = def.frames
	ALL_LISTS[#ALL_LISTS + 1] = "bar" .. i
	for _, name in ipairs(def.frames) do KNOWN_BAR_FRAMES[name] = true end
end
local EXTRA_GROUPS = { "bars", "player", "hud", "quest", "map", "hidden" }
local FADE_ORDER = { "bars", "player", "hud", "quest", "map", "chat" }
local HIDE_TOGGLES = { { "micro", "hideMicro" }, { "bags", "hideBags" }, { "reporter", "hideReporter" } }
local ACTION_BARS = {
	"MainActionBar", "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight",
	"MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7", "MultiBar8", "StanceBar", "PetActionBar",
}
local CHAT_EXTRAS = {
	"GeneralDockManager", "ChatFrameMenuButton", "ChatFrameChannelButton",
	"ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton", "QuickJoinToastButton",
}

-- What can bring the chat up. Bit i of the chatKinds setting turns category i on. The default (71) is whispers,
-- party/raid/instance chat, guild chat and system messages.
local CHAT_KINDS = {
	{ "Whispers", { "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
		"CHAT_MSG_AFK", "CHAT_MSG_DND" } },
	{ "Party, raid and instance chat", { "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID",
		"CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER" } },
	{ "Guild and officer chat", { "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_GUILD_ACHIEVEMENT" } },
	{ "Say, yell and emotes from players", { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE" } },
	{ "Channels (General, Trade, ...)", { "CHAT_MSG_CHANNEL" } },
	{ "Loot, money, XP, reputation, skills", { "CHAT_MSG_LOOT", "CHAT_MSG_MONEY", "CHAT_MSG_COMBAT_XP_GAIN",
		"CHAT_MSG_COMBAT_FACTION_CHANGE", "CHAT_MSG_SKILL" } },
	{ "System messages and achievements", { "CHAT_MSG_SYSTEM", "CHAT_MSG_ACHIEVEMENT" } },
	{ "NPC speech and emotes", { "CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_MONSTER_EMOTE",
		"CHAT_MSG_MONSTER_WHISPER" } },
}
local chatKindOf = {}
for i, kind in ipairs(CHAT_KINDS) do
	for _, e in ipairs(kind[2]) do chatKindOf[e] = i end
end

local DB = { extra = {} }
for k, v in pairs(DEFAULTS) do DB[k] = v end
local LISTS = {}
local drawn, questUntil, mapUntil, chatUntil, combatEnd, moveUntil = false, 0, 0, 0, 0, 0
local cur = { bars = 0, player = 0, hud = 0, quest = 0, map = 0, chat = 0 }
local fading, hiddenOn, barExcluded, textHidden = {}, {}, {}, {}
local minimapShown = true
local chatList = {}
local barHover, discovered = {}, {}
local debugOn = false
local lastActive = false

-- Debug output: printed, and also kept in DB.trace (saved to the addon's saved-variables file on /reload).
local function trace(msg)
	if not debugOn then return end
	print(msg)
	DB.trace = DB.trace or {}
	DB.trace[#DB.trace + 1] = string.format("%.1f %s", GetTime(), msg)
	if #DB.trace > 300 then table.remove(DB.trace, 1) end
end
local armEntry

local function discoverBars()
	discovered = {}
	for k, v in pairs(_G) do
		if type(k) == "string" and k:find("^MultiBar") and not k:find("Button") and type(v) == "table"
			and type(v.GetObjectType) == "function" then
			local ok, kind = pcall(v.GetObjectType, v)
			if ok and kind == "Frame" then discovered[#discovered + 1] = k end
		end
	end
	table.sort(discovered)
end

local function rebuildLists()
	for _, g in ipairs(ALL_LISTS) do
		local merged, seen = {}, {}
		local function add(n)
			if not seen[n] then
				seen[n] = true
				merged[#merged + 1] = n
			end
		end
		for _, n in ipairs(DEFAULT_LISTS[g]) do add(n) end
		if g == "bars" then
			for _, n in ipairs(discovered) do
				if not KNOWN_BAR_FRAMES[n] then add(n) end
			end
		end
		for _, n in ipairs(DB.extra[g] or {}) do add(n) end
		LISTS[g] = merged
	end
	barHover = {}
	local seen = {}
	for _, list in ipairs({ ACTION_BARS, discovered }) do
		for _, n in ipairs(list) do
			if not seen[n] then
				seen[n] = true
				barHover[#barHover + 1] = n
			end
		end
	end
end
rebuildLists()

-- Persistence. The Forever beta writes saved variables at logout but never reads them back, so settings are
-- also stored in an account-wide macro, which the client saves and reloads itself (no file path needed).
local MACRO_NAME = "QuietHUD data"
local MACRO_PREFIX = "#QuietHUD settings, do not delete\n"
local CVAR = "QuietHUDcfg"
local cvarRegistered, restored, userChanged, macroPending = false, false, false, false
local onRestored

local function registerCVar()
	if cvarRegistered then return end
	local reg = (C_CVar and C_CVar.RegisterCVar) or RegisterCVar
	if reg then cvarRegistered = pcall(reg, CVAR, "") end
end
registerCVar()

local function getCVarString()
	local get = (C_CVar and C_CVar.GetCVar) or GetCVar
	if not get then return nil end
	local ok, value = pcall(get, CVAR)
	return ok and value or nil
end

local function encodeSettings()
	local parts = {}
	for _, f in ipairs(FIELDS) do
		local v = DB[f.key]
		if f.kind == "bool" then
			parts[#parts + 1] = f.code .. "=" .. (v and "1" or "0")
		else
			parts[#parts + 1] = f.code .. "=" .. string.format("%.3g", v or f.def)
		end
	end
	local base = table.concat(parts, ";")
	local extras = {}
	for _, g in ipairs(EXTRA_GROUPS) do
		local list = DB.extra and DB.extra[g]
		if list and #list > 0 then extras[#extras + 1] = "x" .. g .. "=" .. table.concat(list, ",") end
	end
	if #extras > 0 then
		local full = base .. ";" .. table.concat(extras, ";")
		if #MACRO_PREFIX + #full <= 255 then return full end
	end
	return base
end

local function readMacroString()
	if not (GetMacroIndexByName and GetMacroBody) then return nil end
	local ok, index = pcall(GetMacroIndexByName, MACRO_NAME)
	if not ok or not index or index == 0 then return nil end
	local ok2, body = pcall(GetMacroBody, index)
	if not ok2 or type(body) ~= "string" then return nil end
	local rest = body:gsub("^#[^\n]*\n", "")
	return (rest:match("^%s*(.-)%s*$"))
end

local function writeMacro()
	macroPending = false
	if InCombatLockdown() or not (CreateMacro and EditMacro and GetMacroIndexByName) then return end
	local body = MACRO_PREFIX .. encodeSettings()
	local ok, index = pcall(GetMacroIndexByName, MACRO_NAME)
	if ok and index and index > 0 then
		pcall(EditMacro, index, nil, nil, body)
	else
		pcall(CreateMacro, MACRO_NAME, "INV_Misc_Note_01", body, false)
	end
end

local function persist()
	registerCVar()
	local set = (C_CVar and C_CVar.SetCVar) or SetCVar
	if set then pcall(set, CVAR, encodeSettings()) end
	if C_Timer and C_Timer.After then
		if not macroPending then
			macroPending = true
			C_Timer.After(1.5, writeMacro)
		end
	else
		writeMacro()
	end
end

local function persistSoon()
	userChanged = true
	persist()
	if C_Timer and C_Timer.After then
		C_Timer.After(2, persist)
		C_Timer.After(8, persist)
	end
end

local function restoreFromStore()
	if restored then return end
	local s = readMacroString() or getCVarString()
	if not s or s == "" then return end
	restored = true
	if userChanged then return end
	for part in s:gmatch("[^;]+") do
		local k, v = part:match("^%s*([^=%s]+)%s*=%s*(.-)%s*$")
		if k then
			local f = BY_CODE[k]
			if f then
				if f.kind == "bool" then
					DB[f.key] = (v == "1")
				else
					DB[f.key] = tonumber(v) or DB[f.key]
				end
			elseif k:sub(1, 1) == "x" then
				local g = k:sub(2)
				DB.extra[g] = {}
				for name in v:gmatch("[^,]+") do DB.extra[g][#DB.extra[g] + 1] = name end
			end
		end
	end
	rebuildLists()
	if onRestored then onRestored() end
	if armEntry then armEntry() end
end

local function initDB()
	local source = type(QuietHUDDB) == "table" and QuietHUDDB or nil
	if source then DB = source end
	for k, v in pairs(DEFAULTS) do
		if DB[k] == nil then DB[k] = v end
	end
	DB.extra = DB.extra or {}
	DB.trace, DB.debug = nil, nil
	if source then restored = true else restoreFromStore() end
	rebuildLists()
end

-- Helpers
local function setAlpha(names, a)
	for i = 1, #names do
		local f = _G[names[i]]
		if f and f.SetAlpha then f:SetAlpha(a) end
	end
end

local function applyList(name, a)
	setAlpha(LISTS[name], a)
end

local function applyChat(a)
	for i = 1, #chatList do chatList[i]:SetAlpha(a) end
end

-- Per-bar options are stored as a bitmask: bit i is Action Bar i.
local function barBit(mask, i)
	return (math.floor((mask or 0) / 2 ^ (i - 1)) % 2) == 1
end

local function applyBars(a, respectMask)
	applyList("bars", a)
	for i = 1, #BAR_DEFS do
		if (not respectMask) or barBit(DB.barFade, i) then
			applyList("bar" .. i, a)
			barExcluded[i] = false
		elseif not barExcluded[i] then
			applyList("bar" .. i, 1)
			barExcluded[i] = true
		end
	end
end

local function step(v, target, dt)
	local d = dt / FADE
	if v < target then return math.min(target, v + d) end
	return math.max(target, v - d)
end

local function hovered(f)
	return f and f.IsMouseOver and f:IsShown() and f:IsMouseOver()
end

local function anyHovered(names)
	for i = 1, #names do
		if hovered(_G[names[i]]) then return true end
	end
	return false
end

local function chatActive()
	if ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then return true end
	for i = 1, #chatList do
		if hovered(chatList[i]) then return true end
	end
	return false
end

local function bumpChat()
	chatUntil = GetTime() + (DB.chatSeconds or 8)
end

local function buildChat()
	chatList = {}
	for i = 1, NUM_CHAT_WINDOWS or 10 do
		local name = "ChatFrame" .. i
		local main = _G[name]
		if main then chatList[#chatList + 1] = main end
		for _, suffix in ipairs({ "Tab", "ButtonFrame", "EditBox" }) do
			local f = _G[name .. suffix]
			if f then chatList[#chatList + 1] = f end
		end
	end
	for i = 1, #CHAT_EXTRAS do
		local f = _G[CHAT_EXTRAS[i]]
		if f then chatList[#chatList + 1] = f end
	end
end

local function toggleDrawn()
	drawn = not drawn
	print("QuietHUD: HUD " .. (drawn and "shown" or "hidden"))
end

-- WoW does not expose whether the weapon is sheathed, so follow the Toggle Sheath key.
local lastSheath, hooked = 0, false
local function sheathToggled(source)
	local now = GetTime()
	if now - lastSheath < 0.25 then return end
	lastSheath = now
	drawn = not drawn
	if debugOn then print("QuietHUD: sheath toggle via " .. source .. ", HUD " .. (drawn and "shown" or "hidden")) end
end

local function bindingPressed(binding, key)
	if not binding or binding:match("([^%-]+)$") ~= key then return false end
	local alt = binding:find("ALT%-") ~= nil
	local ctrl = binding:find("CTRL%-") ~= nil
	local shift = binding:find("SHIFT%-") ~= nil
	return alt == (IsAltKeyDown() and true or false)
		and ctrl == (IsControlKeyDown() and true or false)
		and shift == (IsShiftKeyDown() and true or false)
end

local keys = CreateFrame("Frame")
if keys.SetPropagateKeyboardInput then
	keys:SetPropagateKeyboardInput(true)
	keys:EnableKeyboard(true)
	keys:SetScript("OnKeyDown", function(_, key)
		local a, b = GetBindingKey("TOGGLESHEATH")
		if bindingPressed(a, key) or bindingPressed(b, key) then sheathToggled("key") end
	end)
end

-- Moving is read two ways, so one of them failing (the game can hide the speed value) does not break it: the
-- walking speed, and whether the player's position changed since the last check.
local lastPosX, lastPosY, lastMoveReason, lastSpeedText, lastLoggedMoving = nil, nil, "none", "?", nil
local function isMoving()
	local reason = "none"
	local speed = GetUnitSpeed("player")
	lastSpeedText = (issecretvalue and issecretvalue(speed)) and "hidden" or tostring(speed)
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
	lastMoveReason = reason
	return reason ~= "none"
end

-- A short log of the minimap decisions, saved with the settings on /reload. It is kept even without debug mode,
-- so a minimap that does not show can be diagnosed afterwards.
local function mapLog(msg)
	DB.mapLog = DB.mapLog or {}
	DB.mapLog[#DB.mapLog + 1] = string.format("%.1f %s", GetTime(), msg)
	if #DB.mapLog > 80 then table.remove(DB.mapLog, 1) end
end

-- The player arrow, the quest arrow and the quest-area overlays are drawn by the game and ignore the opacity of
-- the minimap cluster, so a faded minimap is hidden outright.
local function setMinimapVisible(visible, alpha)
	if not Minimap then return end
	Minimap:SetShown(visible)
	mapLog(string.format("minimap %s (cluster alpha %.2f, Minimap:IsShown=%s)", visible and "shown" or "hidden", alpha or -1,
		tostring(Minimap:IsShown())))
end
-- Main loop
local TEXT_SPECS = { { "HotKey", "barHotkeys" }, { "Name", "barNames" } }
local hotkeyClock = 0
-- Any instance that is not PvP counts, so instance types this client adds or names differently still work.
-- The whole check is in a pcall and skips secret values, so it can never break the fade loop.
local function inDungeonOrRaid()
	if not IsInInstance then return false end
	local ok, result = pcall(function()
		local inside, kind = IsInInstance()
		if issecretvalue and (issecretvalue(inside) or issecretvalue(kind)) then return false end
		return inside and kind ~= "pvp" and kind ~= "arena"
	end)
	return ok and result and true or false
end

local function update(dt)
	local now = GetTime()
	local edit = EditModeManagerFrame and EditModeManagerFrame:IsShown() or false
	local combat = UnitAffectingCombat("player") and true or false
	local enabled = DB.enabled

	local instanceOn = DB.inInstance and inDungeonOrRaid()
	local active = edit or (DB.inCombat and (combat or now < combatEnd)) or (DB.sheathShows and drawn)
		or (DB.showOnTarget and UnitExists("target")) or instanceOn
	lastActive = active and true or false
	local okMove, moving = pcall(isMoving)
	if okMove and moving then moveUntil = now + MOVE_LINGER end
	if (okMove and moving and true or false) ~= lastLoggedMoving then
		lastLoggedMoving = okMove and moving and true or false
		mapLog(string.format("moving=%s by %s (speed %s, fade=%s, movingMode=%s, dim=%s)", tostring(lastLoggedMoving),
			lastMoveReason, lastSpeedText, tostring(DB.fadeMinimap), tostring(DB.minimapMoving), tostring(DB.minimapDim)))
	end

	local vis = {}
	vis.bars = active or (DB.barsMouseover and anyHovered(barHover))
	vis.player = active
	vis.hud = active
	vis.quest = active or now < questUntil or hovered(_G.ObjectiveTrackerFrame)
	local mapShow = now < mapUntil or hovered(_G.MinimapCluster) or instanceOn
	if DB.minimapDim then
		mapShow = mapShow or active or now < moveUntil
	elseif DB.minimapMoving then
		mapShow = mapShow or now < moveUntil
	else
		mapShow = mapShow or active
	end
	vis.map = mapShow
	vis.chat = now < chatUntil or chatActive()
	if edit then
		for g in pairs(vis) do vis[g] = true end
	end

	local flags = {
		bars = DB.fadeBars, player = DB.fadePlayer, hud = DB.fadeUnits,
		quest = DB.fadeTracker, map = DB.fadeMinimap, chat = DB.fadeChat,
	}
	local idle = DB.idle or 0
	local mapAlpha = 1
	for _, g in ipairs(FADE_ORDER) do
		if enabled and flags[g] then
			cur[g] = step(cur[g], vis[g] and 1 or 0, dt)
			local peak = DB.base or 0.6
			if edit or g == "map" or (g == "chat" and not DB.chatDim) then peak = 1 end
			local floor = idle
			if g == "map" and DB.minimapDim then floor = DB.mapDimOpacity or 0.3 end
			local low = math.min(floor, peak)
			local a = low + (peak - low) * cur[g]
			if g == "chat" then
				applyChat(a)
			elseif g == "bars" then
				applyBars(a, true)
			else
				applyList(g, a)
			end
			if g == "map" then mapAlpha = a end
			fading[g] = true
		elseif fading[g] then
			if g == "chat" then
				applyChat(1)
			elseif g == "bars" then
				applyBars(1, false)
			else
				applyList(g, 1)
			end
			fading[g] = false
			cur[g] = 1
		end
	end

	local wantMinimap = not (enabled and DB.fadeMinimap) or mapAlpha > 0.01
	if Minimap and wantMinimap ~= minimapShown then
		minimapShown = wantMinimap
		setMinimapVisible(wantMinimap, mapAlpha)
	end

	for _, pair in ipairs(HIDE_TOGGLES) do
		local on = enabled and DB[pair[2]] and not edit
		if on then
			applyList(pair[1], 0)
			hiddenOn[pair[1]] = true
		elseif hiddenOn[pair[1]] then
			applyList(pair[1], 1)
			hiddenOn[pair[1]] = false
		end
	end
	if enabled and not edit then
		applyList("hidden", 0)
		hiddenOn.hidden = true
	elseif hiddenOn.hidden then
		applyList("hidden", 1)
		hiddenOn.hidden = false
	end

	hotkeyClock = hotkeyClock + dt
	if hotkeyClock > 0.5 then
		hotkeyClock = 0
		for i = 1, #BAR_DEFS do
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
	end
end

local lastError
local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, dt)
	local ok, err = pcall(update, dt)
	if not ok and err ~= lastError then
		lastError = err
		print("QuietHUD error (shown once): " .. tostring(err))
	end
end)

-- Settings menu
local PAGES = {
	{ title = "Show when", items = {
		{ "check", "enabled", "Enable QuietHUD" },
		{ "slider", "base", "Opacity when active (combat, target...)", 0.1, 1, 0.05, "%.2f" },
		{ "slider", "idle", "Opacity when idle (0 = fully hidden)", 0, 1, 0.05, "%.2f" },
		{ "check", "inCombat", "Show in combat" },
		{ "check", "sheathShows", "Show while my weapon is drawn" },
		{ "check", "showOnTarget", "Show while I have a target" },
		{ "check", "inInstance", "Always show in dungeons and raids" },
		{ "check", "barsMouseover", "Show action bars on mouse over" },
		{ "slider", "linger", "Stay visible after combat (seconds)", 0, 15, 1, "%.0f" },
	} },
	{ title = "Elements", items = {
		{ "check", "fadeBars", "Fade action bars" },
		{ "check", "fadePlayer", "Fade player frame" },
		{ "check", "fadeUnits", "Fade target, party, raid frames and buffs" },
		{ "check", "fadeTracker", "Fade objective tracker" },
		{ "check", "fadeChat", "Fade chat" },
		{ "check", "chatDim", "Chat uses the HUD opacity when active" },
		{ "minimap" },
	} },
	{ title = "Bars", items = {
		{ "bargrid" },
	} },
	{ title = "Chat", items = {
		{ "slider", "chatSeconds", "Chat stays after a message (seconds)", 2, 30, 1, "%.0f" },
		{ "kinds" },
	} },
	{ title = "Extras", items = {
		{ "slider", "questSeconds", "Tracker and minimap stay (seconds)", 3, 30, 1, "%.0f" },
		{ "check", "hideBags", "Always hide the bags bar" },
		{ "check", "hideMicro", "Always hide the menu bar" },
		{ "check", "hideReporter", "Hide the beta Issue Reporter button" },
		{ "check", "questTarget", "Enable quest-mob targeting key (experimental)" },
	} },
}

local config
local pages, tabs, controls = {}, {}, {}

local function syncControls()
	for _, fn in ipairs(controls) do fn() end
end
onRestored = syncControls

local function makeCheck(parent, y, label, key)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetPoint("TOPLEFT", 12, y)
	check:SetScript("OnClick", function(self)
		DB[key] = not DB[key]
		self:SetChecked(DB[key] and true or false)
		persistSoon()
		if armEntry then armEntry() end
	end)
	local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:SetPoint("LEFT", check, "RIGHT", 4, 0)
	text:SetText(label)
	controls[#controls + 1] = function() check:SetChecked(DB[key] and true or false) end
	controls[#controls]()
end

local function makeSlider(parent, y, label, key, minV, maxV, stepV, fmt)
	local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 16, y)
	title:SetText(label)
	local s = CreateFrame("Slider", nil, parent)
	s:SetPoint("TOPLEFT", 16, y - 22)
	s:SetSize(220, 16)
	s:SetOrientation("HORIZONTAL")
	s:SetMinMaxValues(minV, maxV)
	local bar = s:CreateTexture(nil, "BACKGROUND")
	bar:SetColorTexture(1, 1, 1, 0.25)
	bar:SetPoint("LEFT", s, "LEFT", 0, 0)
	bar:SetPoint("RIGHT", s, "RIGHT", 0, 0)
	bar:SetHeight(4)
	s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
	local thumb = s:GetThumbTexture()
	if thumb then thumb:SetSize(16, 24) end
	local readout = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	readout:SetPoint("LEFT", s, "RIGHT", 12, 0)
	s:SetScript("OnValueChanged", function(self, val)
		local dragging = IsMouseButtonDown and IsMouseButtonDown("LeftButton") and self:IsMouseOver()
		if not dragging then return end
		val = math.floor(val / stepV + 0.5) * stepV
		DB[key] = val
		readout:SetText(string.format(fmt, val))
		-- Idle can never be brighter than shown: dragging one past the other carries the other with it.
		local carried = false
		if key == "idle" and val > (DB.base or 0) + 0.001 then
			DB.base, carried = val, true
		elseif key == "base" and val < (DB.idle or 0) - 0.001 then
			DB.idle, carried = val, true
		end
		persistSoon()
		if carried then syncControls() end
	end)
	controls[#controls + 1] = function()
		local v = DB[key]
		if v == nil then v = minV end
		s:SetValue(v)
		readout:SetText(string.format(fmt, v))
	end
	controls[#controls]()
end

local function makeMaskCheck(parent, x, y, key, index)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetPoint("TOPLEFT", x, y)
	check:SetScript("OnClick", function(self)
		local mask = DB[key] or 0
		local weight = 2 ^ (index - 1)
		if barBit(mask, index) then mask = mask - weight else mask = mask + weight end
		DB[key] = mask
		self:SetChecked(barBit(mask, index))
		persistSoon()
	end)
	controls[#controls + 1] = function() check:SetChecked(barBit(DB[key], index)) end
	controls[#controls]()
	return check
end

-- The list of what brings the chat up, one checkbox per category in CHAT_KINDS.
local function makeChatKinds(parent, y)
	local heading = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	heading:SetPoint("TOPLEFT", 16, y)
	heading:SetText("What brings the chat up")
	for i, kind in ipairs(CHAT_KINDS) do
		local check = makeMaskCheck(parent, 12, y - 14 - (i - 1) * 26, "chatKinds", i)
		local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		text:SetPoint("LEFT", check, "RIGHT", 4, 0)
		text:SetText(kind[1])
	end
end

local function makeBarGrid(parent, y)
	local cols = {
		{ "Fade", "barFade", 120 },
		{ "Hide hotkeys", "barHotkeys", 190 },
		{ "Hide names", "barNames", 290 },
	}
	for _, c in ipairs(cols) do
		local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		header:SetPoint("TOPLEFT", c[3], y)
		header:SetText(c[1])
	end
	local rowY = y - 22
	for i = 1, #BAR_DEFS do
		local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		label:SetPoint("TOPLEFT", 16, rowY - 5)
		label:SetText("Action Bar " .. i)
		for _, c in ipairs(cols) do makeMaskCheck(parent, c[3], rowY, c[2], i) end
		rowY = rowY - 24
	end
end

-- One button instead of overlapping checkboxes. Each mode: name, fadeMinimap, minimapMoving, minimapDim, description.
local MINIMAP_MODES = {
	{ "follows the HUD", true, false, false, "Fades with everything else." },
	{ "only while I am moving", true, true, false, "Hidden while you stand still, shown when you move or change zone." },
	{ "always shown", false, false, false, "Never fades." },
	{ "always on, dimmed", true, false, true, "Stays faintly visible and brightens when you move or the HUD wakes." },
}

local function minimapMode()
	if not DB.fadeMinimap then return 3 end
	if DB.minimapDim then return 4 end
	return DB.minimapMoving and 2 or 1
end

-- A "Minimap" row (label + mode button), a line describing the current mode, and the dimmed-opacity
-- slider, which only shows in the dimmed mode. Takes 108 px of the page.
local function makeMinimapMode(parent, y)
	local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("TOPLEFT", 16, y - 5)
	label:SetText("Minimap")
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetPoint("TOPLEFT", 84, y)
	button:SetSize(250, 22)
	local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("TOPLEFT", 16, y - 28)
	hint:SetWidth(318)
	hint:SetJustifyH("LEFT")
	local dimBox = CreateFrame("Frame", nil, parent)
	dimBox:SetPoint("TOPLEFT", 0, y - 60)
	dimBox:SetSize(340, 46)
	makeSlider(dimBox, 0, "Minimap opacity when dimmed", "mapDimOpacity", 0.05, 1, 0.05, "%.2f")
	local function refresh()
		local mode = minimapMode()
		button:SetText(MINIMAP_MODES[mode][1])
		hint:SetText(MINIMAP_MODES[mode][5])
		dimBox:SetShown(mode == 4)
	end
	button:SetScript("OnClick", function()
		local nextMode = MINIMAP_MODES[minimapMode() % #MINIMAP_MODES + 1]
		DB.fadeMinimap, DB.minimapMoving, DB.minimapDim = nextMode[2], nextMode[3], nextMode[4]
		persistSoon()
		refresh()
	end)
	controls[#controls + 1] = refresh
	refresh()
end

local function showPage(index)
	for i, frame in ipairs(pages) do
		frame:SetShown(i == index)
		if tabs[i].SetEnabled then tabs[i]:SetEnabled(i ~= index) end
	end
end

local function resetDefaults()
	for _, f in ipairs(FIELDS) do DB[f.key] = f.def end
	persistSoon()
	syncControls()
	if armEntry then armEntry() end
end

local function buildConfig()
	config = CreateFrame("Frame", "QuietHUDConfig", UIParent)
	config:SetSize(360, 418)
	config:SetPoint("CENTER")
	config:SetFrameStrata("DIALOG")
	config:SetMovable(true)
	config:EnableMouse(true)
	config:RegisterForDrag("LeftButton")
	config:SetScript("OnDragStart", config.StartMoving)
	config:SetScript("OnDragStop", config.StopMovingOrSizing)
	local bg = config:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.05, 0.05, 0.05, 0.92)
	local title = config:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -10)
	title:SetText("QuietHUD")
	local close = CreateFrame("Button", nil, config, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)

	local tabX = 12
	for i, page in ipairs(PAGES) do
		local frame = CreateFrame("Frame", nil, config)
		frame:SetPoint("TOPLEFT", 0, -68)
		frame:SetPoint("BOTTOMRIGHT", 0, 44)
		local y = -4
		for _, item in ipairs(page.items) do
			if item[1] == "check" then
				makeCheck(frame, y, item[3], item[2])
				y = y - 26
			elseif item[1] == "minimap" then
				makeMinimapMode(frame, y - 8)
				y = y - 116
			elseif item[1] == "kinds" then
				makeChatKinds(frame, y)
				y = y - (18 + #CHAT_KINDS * 26)
			elseif item[1] == "bargrid" then
				makeBarGrid(frame, y)
				y = y - 220
			else
				makeSlider(frame, y, item[3], item[2], item[4], item[5], item[6], item[7])
				y = y - 46
			end
		end
		pages[i] = frame
		local tab = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
		local tabWidth = math.max(44, math.floor(#page.title * 6.6 + 22))
		tab:SetSize(tabWidth, 22)
		tab:SetPoint("TOPLEFT", tabX, -36)
		tabX = tabX + tabWidth + 4
		tab:SetText(page.title)
		tab:SetScript("OnClick", function() showPage(i) end)
		tabs[i] = tab
	end

	local now = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
	now:SetSize(150, 24)
	now:SetPoint("BOTTOMLEFT", 16, 14)
	now:SetText("Show/hide HUD now")
	now:SetScript("OnClick", toggleDrawn)
	local reset = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
	reset:SetSize(140, 24)
	reset:SetPoint("BOTTOMRIGHT", -16, 14)
	reset:SetText("Reset to defaults")
	reset:SetScript("OnClick", resetDefaults)

	config:SetScript("OnShow", syncControls)
	showPage(1)
	config:Hide()
end

local function toggleConfig()
	if not config then buildConfig() end
	config:SetShown(not config:IsShown())
end

-- Quest-mob targeting (experimental)
local function singular(s)
	s = s:lower()
	s = s:gsub("ves$", "f")
	s = s:gsub("ies$", "y")
	s = s:gsub("s$", "")
	return s
end

local function objectiveName(text)
	local n = text:gsub("^%s*%-?%s*", "")
	n = n:gsub("^%d+/%d+%s*", "")
	n = n:gsub(":%s*%d+/%d+%s*$", "")
	n = n:gsub("%s+slain%s*$", "")
	return n
end

local function highlightedQuestID()
	local id
	if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
		id = C_SuperTrack.GetSuperTrackedQuestID()
	elseif GetSuperTrackedQuestID then
		id = GetSuperTrackedQuestID()
	end
	if id and id ~= 0 then return id end
end

-- Adds the open objectives of one quest to names (kill objectives) and needles (everything else, matched
-- against the mob's tooltip). Returns how many open objectives the quest has.
local function collectNames(names, needles, questID)
	local open = 0
	for _, o in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
		if not o.finished and o.text then
			open = open + 1
			local n = objectiveName(o.text)
			if o.type == "monster" then
				names[singular(n)] = true
			elseif n ~= "" then
				needles[#needles + 1] = n
			end
		end
	end
	return open
end

local function questNames(questID)
	local names, needles = {}, {}
	if not (C_QuestLog and C_QuestLog.GetQuestObjectives) then return names, needles end
	if questID then
		collectNames(names, needles, questID)
		local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
		if title and title ~= "" then needles[#needles + 1] = title end
	elseif C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
		-- No quest highlighted: every quest with open objectives, checked the same way as a highlighted one.
		for i = 1, C_QuestLog.GetNumQuestLogEntries() do
			local info = C_QuestLog.GetInfo(i)
			if info and not info.isHeader and info.questID and collectNames(names, needles, info.questID) > 0 then
				local title = info.title
				if (not title or title == "") and C_QuestLog.GetTitleForQuestID then
					title = C_QuestLog.GetTitleForQuestID(info.questID)
				end
				if title and title ~= "" then needles[#needles + 1] = title end
			end
		end
	end
	return names, needles
end

-- Returns found, the needle that matched and the tooltip line it matched in (the last two are for /qhud debug).
local function tooltipMentions(unit, needles)
	local ok, found, needle, line = pcall(function()
		local data = C_TooltipInfo.GetUnit(unit)
		if not data or not data.lines then return false end
		for _, l in ipairs(data.lines) do
			local text = l.leftText
			if type(text) == "string" then
				for _, n in ipairs(needles) do
					if text:find(n, 1, true) then return true, n, text end
				end
			end
		end
		return false
	end)
	return ok and found, needle, line
end

-- Returns whether the unit is a quest mob, and why (used by /qhud debug).
local function isQuestUnit(unit, names, needles)
	local n = UnitName(unit)
	if n and names[singular(n)] then return true, "its name is a kill objective" end
	if C_TooltipInfo and C_TooltipInfo.GetUnit then
		if #needles == 0 then return false end
		local found, needle, line = tooltipMentions(unit, needles)
		if found then return true, 'tooltip line "' .. tostring(line) .. '" contains "' .. tostring(needle) .. '"' end
		return false
	end
	-- Only clients without the tooltip API fall back to the game's looser "related to a quest" flag.
	if C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest then
		local ok, related = pcall(C_QuestLog.UnitIsRelatedToActiveQuest, unit)
		return ok and related and true or false, "the game flags it as related to a quest"
	end
	return false
end

-- Quest-mob targeting. Addons cannot change the target, and this client lets only one Tab take effect per key
-- press (the buttons a macro clicks never run their own macros), so a chain of Tabs cannot skip the mobs that are
-- not quest mobs. Instead the addon looks at the enemy nameplates, decides which quest mob to go to, and writes a
-- fixed macro for that one name just before the key press: /targetexact <name>, then the skull. The target is
-- therefore always a quest mob, and the skull always lands on it.
local run = { active = false, names = {}, needles = {}, plan = nil }

local function targetIsQuestMob()
	if not UnitExists("target") or not UnitCanAttack("player", "target") or UnitIsDead("target") then
		return false
	end
	if UnitIsTapDenied and UnitIsTapDenied("target") then return false end
	return isQuestUnit("target", run.names, run.needles)
end

-- The quest mobs among the visible enemy nameplates, nearest first. Returns nil when there are no nameplates at
-- all (for example when enemy nameplates are turned off).
local function questMobsOnScreen(names, needles)
	if not (C_NamePlate and C_NamePlate.GetNamePlates) then return nil end
	local ok, plates = pcall(C_NamePlate.GetNamePlates)
	if not ok or type(plates) ~= "table" or #plates == 0 then return nil end
	local list = {}
	for _, plate in ipairs(plates) do
		local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
		if unit then
			local okUnit, mob, why = pcall(function()
				if not UnitCanAttack("player", unit) or UnitIsDead(unit) then return false end
				if UnitIsTapDenied and UnitIsTapDenied(unit) then return false end
				return isQuestUnit(unit, names, needles)
			end)
			if debugOn then
				pcall(function()
					trace(string.format("  plate %s: attackable=%s dead=%s tapped=%s -> quest=%s%s", tostring(UnitName(unit)),
						tostring(UnitCanAttack("player", unit)), tostring(UnitIsDead(unit)),
						tostring(UnitIsTapDenied and UnitIsTapDenied(unit)), tostring(okUnit and mob),
						(okUnit and mob and why) and (", because " .. why) or ""))
				end)
			end
			if okUnit and mob then
				local dist
				if UnitDistanceSquared then
					local okDist, d = pcall(UnitDistanceSquared, unit)
					if okDist and type(d) == "number" and not (issecretvalue and issecretvalue(d)) then dist = d end
				end
				local name = UnitName(unit)
				if name and not (issecretvalue and issecretvalue(name)) then list[#list + 1] = { name = name, dist = dist } end
			end
		end
	end
	table.sort(list, function(a, b) return (a.dist or math.huge) < (b.dist or math.huge) end)
	return list
end

-- Which quest mob name to go to. If you are already on a quest mob, move to a different kind when there is one
-- (a name cannot pick one mob out of several with the same name); otherwise the nearest.
local function chooseQuestName(list)
	local okQ, onQuestMob = pcall(targetIsQuestMob)
	local current = (okQ and onQuestMob) and UnitName("target") or nil
	if current then
		for _, mob in ipairs(list) do
			if mob.name ~= current then return mob.name, "a different kind of quest mob" end
		end
		return current, "the nearest " .. current
	end
	return list[1].name, "the nearest quest mob"
end

local targetButton = CreateFrame("Button", "QuietHUDTargetButton", UIParent, "SecureActionButtonTemplate")
targetButton:SetAttribute("type", "macro")
targetButton:SetAttribute("macrotext", "")
targetButton:RegisterForClicks("AnyDown", "AnyUp")

-- The game locks addon changes to secure buttons during combat, so the button is kept armed with a plain Tab
-- and the skull (when the feature is on). Out of combat every press replaces it with the quest mob macro.
local COMBAT_MACRO = "/targetenemy\n/tm 0\n/tm " .. SKULL
armEntry = function()
	if InCombatLockdown() then return end
	targetButton:SetAttribute("macrotext", DB.questTarget and COMBAT_MACRO or "")
end
armEntry()

local function isActionClick(down)
	local useDown = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown") and true or false
	return (down and true or false) == useDown
end

targetButton:SetScript("PreClick", function(self, _, down)
	if not isActionClick(down) then return end
	run.plan = nil
	if not DB.questTarget then
		print("QuietHUD: quest targeting is off. Turn it on in /qhud, Extras.")
		return
	end
	if InCombatLockdown() then
		if not run.combatWarned then
			run.combatWarned = true
			print("QuietHUD: in combat the key works as a plain Tab, because the game locks addon changes in combat")
		end
		return
	end
	local questID = highlightedQuestID()
	local ok, names, needles = pcall(questNames, questID)
	if not ok then
		self:SetAttribute("macrotext", "")
		print("QuietHUD: could not read your quests just now")
		return
	end
	run.names, run.needles = names, needles
	if debugOn then
		local kills = {}
		for name in pairs(names) do kills[#kills + 1] = name end
		trace("QuietHUD: --- key press. start target=" .. tostring(UnitName("target")))
		trace("QuietHUD: highlighted quest id " .. tostring(questID) .. ", kill names: [" .. table.concat(kills, ", ")
			.. "], tooltip needles: [" .. table.concat(needles, ", ") .. "]")
	end
	local mobs = questMobsOnScreen(names, needles)
	if not mobs then
		self:SetAttribute("macrotext", "")
		print("QuietHUD: no enemy nameplates to look at. Turn on enemy nameplates so the key can find quest mobs.")
		trace("QuietHUD: there are no nameplates, so nothing was pressed")
		return
	end
	if #mobs == 0 then
		self:SetAttribute("macrotext", "")
		print("QuietHUD: no quest mob found among the nearby enemies")
		trace("QuietHUD: no quest mob on the nameplates, so nothing was pressed")
		return
	end
	local name, why = chooseQuestName(mobs)
	run.plan = why
	local text = "/targetexact " .. name .. "\n/tm 0\n/tm " .. SKULL
	trace("QuietHUD: " .. #mobs .. " quest mob(s) on the nameplates, going to " .. why .. ": " .. text:gsub("\n", " | "))
	self:SetAttribute("macrotext", text)
end)

targetButton:SetScript("PostClick", function(self, _, down)
	if not InCombatLockdown() then armEntry() end
	if isActionClick(down) and run.plan then
		local name = UnitName("target")
		if name and not (issecretvalue and issecretvalue(name)) then
			print("QuietHUD: " .. name .. " (" .. run.plan .. ")")
		end
		run.plan = nil
	end
end)

-- Adding frames by hand
local function frameUnderMouse()
	local f
	if GetMouseFoci then
		local t = GetMouseFoci()
		f = t and t[1]
	elseif GetMouseFocus then
		f = GetMouseFocus()
	end
	while f do
		local p = f.GetParent and f:GetParent()
		if not p or p == UIParent or p == WorldFrame then break end
		f = p
	end
	local name = f and f.GetName and f:GetName()
	if name == "UIParent" or name == "WorldFrame" then name = nil end
	return name
end

local function addExtra(group, name)
	DB.extra[group] = DB.extra[group] or {}
	for _, n in ipairs(DB.extra[group]) do
		if n == name then return end
	end
	DB.extra[group][#DB.extra[group] + 1] = name
	rebuildLists()
	persistSoon()
end

local function removeExtra(name)
	local removed = false
	for _, g in ipairs(EXTRA_GROUPS) do
		local list = DB.extra[g] or {}
		for i = #list, 1, -1 do
			if list[i] == name then
				table.remove(list, i)
				removed = true
			end
		end
	end
	rebuildLists()
	persistSoon()
	return removed
end

-- Finding a frame by the text it shows, for things like a notice you want to hide
local function frameChain(f)
	local parts = {}
	while f and #parts < 6 do
		local ok, name = pcall(f.GetName, f)
		parts[#parts + 1] = (ok and name) or ("<" .. tostring(f.GetObjectType and f:GetObjectType()) .. ">")
		local okParent, parent = pcall(f.GetParent, f)
		if not okParent or parent == UIParent or parent == WorldFrame then break end
		f = parent
	end
	return table.concat(parts, " < ")
end

local function scanFrame(frame, needle, hits)
	if frame.IsForbidden and frame:IsForbidden() then return end
	if not frame:IsVisible() then return end
	for _, region in ipairs({ frame:GetRegions() }) do
		if region.GetObjectType and region:GetObjectType() == "FontString" and region:IsVisible() then
			local text = region:GetText()
			if type(text) == "string" and not (issecretvalue and issecretvalue(text)) and text:lower():find(needle, 1, true) then
				hits[#hits + 1] = { chain = frameChain(frame), text = text }
				return
			end
		end
	end
end

local function scanForText(needle)
	needle = needle:lower()
	local hits = {}
	local frame = EnumerateFrames()
	while frame do
		pcall(scanFrame, frame, needle, hits)
		frame = EnumerateFrames(frame)
	end
	return hits
end

local function reportHits(text, hits)
	print('QuietHUD: "' .. text .. '" is shown by (frame, then the frames that hold it):')
	for i = 1, math.min(#hits, 6) do
		print("  " .. hits[i].chain .. ' : "' .. hits[i].text:sub(1, 60) .. '"')
	end
	print("QuietHUD: to hide one, use /qhud add hidden <a frame name from the list>")
end

local finder
local function findText(text)
	if finder then
		finder:Cancel()
		finder = nil
	end
	local hits = scanForText(text)
	if #hits > 0 then
		reportHits(text, hits)
		return
	end
	print('QuietHUD: nothing on screen contains "' .. text .. '" right now. Watching for 10 minutes, I will report when it shows up.')
	if not (C_Timer and C_Timer.NewTicker) then return end
	local tries = 0
	finder = C_Timer.NewTicker(1, function(ticker)
		tries = tries + 1
		local found = scanForText(text)
		if #found > 0 then
			ticker:Cancel()
			finder = nil
			reportHits(text, found)
		elseif tries >= 600 then
			ticker:Cancel()
			finder = nil
			print('QuietHUD: stopped watching for "' .. text .. '"')
		end
	end)
end

-- Events
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
pcall(ev.RegisterEvent, ev, "VARIABLES_LOADED")
pcall(ev.RegisterEvent, ev, "PLAYER_STARTED_MOVING")
local kindOf = {}
for _, e in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "QUEST_WATCH_UPDATE", "UI_INFO_MESSAGE" }) do
	kindOf[e] = "quest"
end
for _, e in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }) do
	kindOf[e] = "map"
end
for e in pairs(kindOf) do pcall(ev.RegisterEvent, ev, e) end
for e in pairs(chatKindOf) do pcall(ev.RegisterEvent, ev, e) end

ev:SetScript("OnEvent", function(_, event, arg1, _, _, arg4)
	if event == "ADDON_LOADED" then
		if arg1 == ADDON then initDB() end
	elseif event == "VARIABLES_LOADED" then
		initDB()
	elseif event == "PLAYER_ENTERING_WORLD" then
		initDB()
		discoverBars()
		rebuildLists()
	elseif event == "PLAYER_LOGOUT" then
		persist()
		writeMacro()
		QuietHUDDB = DB
	elseif event == "PLAYER_LOGIN" then
		initDB()
		armEntry()
		if C_Timer and C_Timer.NewTicker then
			C_Timer.NewTicker(1, function() restoreFromStore() end, 60)
		end
		discoverBars()
		rebuildLists()
		buildChat()
		if ToggleSheath then
			hooksecurefunc("ToggleSheath", function() sheathToggled("hook") end)
			hooked = true
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		if DB.inCombat then drawn = true end
	elseif event == "PLAYER_REGEN_ENABLED" then
		combatEnd = GetTime() + (DB.linger or 4)
		run.combatWarned = false
		armEntry()
	elseif event == "PLAYER_STARTED_MOVING" then
		moveUntil = GetTime() + MOVE_LINGER
	elseif kindOf[event] == "quest" then
		questUntil = GetTime() + (DB.questSeconds or 10)
	elseif kindOf[event] == "map" then
		mapUntil = GetTime() + (DB.questSeconds or 10)
	elseif chatKindOf[event] then
		local i = chatKindOf[event]
		if barBit(DB.chatKinds, i) then
			bumpChat()
			if debugOn then
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
BINDING_NAME_QUIETHUD_TOGGLE = "Show/hide HUD"
_G["BINDING_NAME_CLICK QuietHUDTargetButton:LeftButton"] = "Target highlighted quest mob"

SLASH_QUIETHUD1 = "/qhud"
SlashCmdList["QUIETHUD"] = function(msg)
	local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)%s*$")
	cmd = cmd:lower()
	if cmd == "" or cmd == "config" then
		toggleConfig()
	elseif cmd == "toggle" then
		toggleDrawn()
	elseif cmd == "target" or cmd == "t" then
		print("QuietHUD: turn quest targeting on in /qhud, Extras, then use the QuietHUD key (Keybindings, AddOns) or the macro /click QuietHUDTargetButton")
	elseif cmd == "quest" or cmd == "q" then
		questUntil = GetTime() + (DB.questSeconds or 10)
	elseif cmd == "map" then
		mapUntil = GetTime() + (DB.questSeconds or 10)
	elseif cmd == "chat" or cmd == "c" then
		bumpChat()
	elseif cmd == "reset" then
		resetDefaults()
		print("QuietHUD: settings reset to defaults")
	elseif cmd == "debug" then
		debugOn = not debugOn
		if debugOn then DB.trace = {} end
		print("QuietHUD debug " .. (debugOn and "on" or "off") .. ", ToggleSheath hooked: " .. tostring(hooked)
			.. ", sheath key: " .. tostring((GetBindingKey("TOGGLESHEATH"))) .. ", HUD drawn state: " .. tostring(drawn))
	elseif cmd == "state" then
		local ok, err = pcall(function()
			-- Everything this command prints is also kept in the trace, so it can be read from the saved-variables
			-- file after a /reload.
			local function print(msg)
				_G.print(msg)
				DB.trace = DB.trace or {}
				DB.trace[#DB.trace + 1] = string.format("%.1f state: %s", GetTime(), tostring(msg))
			end
			local function alpha(name)
				local f = _G[name]
				return (f and f.GetAlpha) and string.format("%.2f", f:GetAlpha()) or "none"
			end
			print(string.format("QuietHUD state: enabled=%s, shown opacity=%.2f, idle opacity=%.2f, HUD active=%s",
				tostring(DB.enabled and true or false), DB.base or 0, DB.idle or 0, tostring(lastActive)))
			print(string.format("QuietHUD triggers: in combat=%s, after-combat linger=%s, weapon drawn=%s, has target=%s",
				tostring(UnitAffectingCombat("player") and true or false), tostring(GetTime() < combatEnd),
				tostring(drawn), tostring(UnitExists("target") and true or false)))
			print("QuietHUD alpha now: PlayerFrame=" .. alpha("PlayerFrame") .. ", MainActionBar=" .. alpha("MainActionBar")
				.. ", TargetFrame=" .. alpha("TargetFrame") .. ", MinimapCluster=" .. alpha("MinimapCluster"))
			local okSpeed, speed = pcall(GetUnitSpeed, "player")
			local speedText = not okSpeed and "unreadable" or ((issecretvalue and issecretvalue(speed)) and "hidden by the game" or tostring(speed))
			print(string.format("QuietHUD minimap: mode=%s, Minimap shown=%s, alpha=%s, walking speed=%s, moving detected by=%s, moving window left=%.1fs, zone-change window=%s, indoors=%s, in %s / %s",
				MINIMAP_MODES[minimapMode()][1], tostring(Minimap and Minimap:IsShown()), alpha("Minimap"), speedText,
				lastMoveReason, math.max(0, moveUntil - GetTime()), tostring(GetTime() < mapUntil),
				tostring(IsIndoors and IsIndoors() or false), tostring(GetZoneText()), tostring(GetSubZoneText())))
		end)
		if not ok then print("QuietHUD: could not read the state (" .. tostring(err) .. ")") end
	elseif cmd == "instance" then
		local ok, line = pcall(function()
			local inside, kind = IsInInstance()
			return "IsInInstance = " .. tostring(inside) .. ", " .. tostring(kind) .. ", option on: "
				.. tostring(DB.inInstance and true or false) .. ", HUD forced on: " .. tostring(inDungeonOrRaid())
		end)
		print("QuietHUD: " .. (ok and line or "could not read the instance state"))
	elseif cmd == "bars" then
		print("QuietHUD action bar frames found: " .. table.concat(discovered, ", "))
	elseif cmd == "where" then
		print("QuietHUD: frame under mouse = " .. tostring(frameUnderMouse()))
	elseif cmd == "find" then
		if rest == "" then
			print("QuietHUD: usage /qhud find <part of the text>, for example /qhud find refresh")
		else
			findText(rest)
		end
	elseif cmd == "add" then
		local group, explicit = rest:match("^(%S*)%s*(.-)%s*$")
		group = group:lower()
		local name = explicit ~= "" and explicit or frameUnderMouse()
		local valid = false
		for _, g in ipairs(EXTRA_GROUPS) do
			if g == group then valid = true end
		end
		if not valid then
			print("QuietHUD: usage /qhud add bars|player|hud|quest|map|hidden [frame name] (or hover the frame first)")
		elseif not name then
			print("QuietHUD: no named frame under the mouse")
		elseif not _G[name] then
			print("QuietHUD: there is no frame named " .. name)
		else
			addExtra(group, name)
			print("QuietHUD: added " .. name .. " to " .. group)
		end
	elseif cmd == "remove" then
		print(removeExtra(rest) and ("QuietHUD: removed " .. rest) or ("QuietHUD: " .. rest .. " is not in your added list"))
	elseif cmd == "list" then
		for _, g in ipairs(EXTRA_GROUPS) do
			print("QuietHUD " .. g .. " extras: " .. table.concat(DB.extra[g] or {}, ", "))
		end
	else
		print("QuietHUD: /qhud (menu), toggle, reset, target, quest, map, chat, bars, instance, state, debug, where, find <text>, add <group> [name], remove <name>, list")
	end
end
