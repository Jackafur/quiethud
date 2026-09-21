local ADDON = ...

-- Settings. code is the short key used when the settings are stored as text.
local FIELDS = {
	{ key = "enabled", code = "e", kind = "bool", def = true },
	{ key = "base", code = "b", kind = "num", def = 0.6 },
	{ key = "idle", code = "i", kind = "num", def = 0 },
	{ key = "inCombat", code = "k", kind = "bool", def = true },
	{ key = "sheathShows", code = "w", kind = "bool", def = true },
	{ key = "showOnTarget", code = "t", kind = "bool", def = false },
	{ key = "linger", code = "l", kind = "num", def = 4 },
	{ key = "fadeBars", code = "fb", kind = "bool", def = true },
	{ key = "fadePlayer", code = "fp", kind = "bool", def = true },
	{ key = "fadeUnits", code = "fu", kind = "bool", def = true },
	{ key = "fadeMinimap", code = "fm", kind = "bool", def = true },
	{ key = "trigMap", code = "tm", kind = "num", def = 14 },
	{ key = "mapIdle", code = "mz", kind = "num", def = 0 },
	{ key = "mapFollowsHud", code = "mf", kind = "bool", def = false },
	{ key = "mapDarken", code = "mk", kind = "bool", def = false },
	{ key = "fadeTracker", code = "fq", kind = "bool", def = true },
	{ key = "fadeChat", code = "fc", kind = "bool", def = true },
	{ key = "chatDim", code = "cd", kind = "bool", def = false },
	{ key = "chatSeconds", code = "c", kind = "num", def = 8 },
	{ key = "chatKinds", code = "ck", kind = "num", def = 71 },
	{ key = "chatOpacity", code = "co", kind = "num", def = 1 },
	{ key = "chatFadeSeconds", code = "cf", kind = "num", def = 1.5 },
	-- What brings each element up: one number per element, where bit i is column i of the trigger grid (1 awake,
	-- 2 while moving, 3 new info, 4 mouse over, 5 hide in combat, 6 dungeon or raid). The defaults are what each element
	-- did before.
	{ key = "trigBars", code = "tb", kind = "num", def = 9 },
	{ key = "trigPlayer", code = "tp", kind = "num", def = 1 },
	{ key = "trigUnits", code = "tu", kind = "num", def = 1 },
	{ key = "trigTracker", code = "tq", kind = "num", def = 13 },
	{ key = "trigChat", code = "tc", kind = "num", def = 12 },
	{ key = "trigRxp", code = "tr", kind = "num", def = 13 },
	{ key = "trigNav", code = "tn", kind = "num", def = 26 },
	{ key = "rxpGuide", code = "rg", kind = "bool", def = false },
	{ key = "rxpTargets", code = "rt", kind = "bool", def = false },
	{ key = "rxpArrow", code = "ra", kind = "bool", def = false },
	{ key = "rxpShown", code = "rs", kind = "num", def = 0.7 },
	{ key = "rxpIdle", code = "ri", kind = "num", def = 0 },
	{ key = "navShown", code = "ns", kind = "num", def = 0.6 },
	{ key = "navIdle", code = "ni", kind = "num", def = 0 },
	{ key = "questSeconds", code = "q", kind = "num", def = 10 },
	{ key = "fadeBags", code = "fg", kind = "bool", def = false },
	{ key = "fadeMicro", code = "fo", kind = "bool", def = false },
	{ key = "trigBagsBar", code = "tg", kind = "num", def = 9 },
	{ key = "trigMicro", code = "to", kind = "num", def = 9 },
	{ key = "barFade", code = "af", kind = "num", def = 255 },
	{ key = "barHotkeys", code = "ah", kind = "num", def = 0 },
	{ key = "barNames", code = "an", kind = "num", def = 0 },
	{ key = "hideReporter", code = "hr", kind = "bool", def = false },
	{ key = "shortHotkeys", code = "sk", kind = "bool", def = false },
	{ key = "questTarget", code = "qt", kind = "bool", def = false },
	{ key = "watchMouse", code = "wm", kind = "bool", def = false },
	{ key = "pixelShift", code = "ps", kind = "bool", def = false },
	{ key = "shiftPixels", code = "sp", kind = "num", def = 2 },
	{ key = "shiftMinutes", code = "sm", kind = "num", def = 3 },
	{ key = "tooltipAlpha", code = "ta", kind = "num", def = 1 },
	{ key = "shiftBars", code = "sb", kind = "bool", def = false },
	{ key = "shiftUnits", code = "su", kind = "bool", def = false },
	{ key = "peekAlt", code = "pa", kind = "bool", def = false },
	{ key = "peekCtrl", code = "pc", kind = "bool", def = false },
	{ key = "peekShift", code = "pf", kind = "bool", def = false },
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
		"DurabilityFrame", "LossOfControlFrame", "ExternalDefensivesFrame",
	},
	quest = { "ObjectiveTrackerFrame" },
	map = { "MinimapCluster" },
	micro = { "MicroMenuContainer" },
	bags = { "BagsBar" },
	reporter = { "PTR_IssueReporter", "PTR_IssueReporterButton", "PTR_IssueReporterFrame" },
	hidden = {},
	chat = {},
	nav = {},
	rxp = {},
	shift = { "MinimapCluster", "ObjectiveTrackerFrame" },
}
local ALL_LISTS = { "bars", "player", "hud", "quest", "map", "micro", "bags", "reporter", "hidden", "chat", "nav", "rxp", "shift" }
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
local EXTRA_GROUPS = { "bars", "player", "hud", "quest", "map", "hidden", "chat", "nav", "rxp", "shift" }
local FADE_ORDER = { "bars", "player", "hud", "quest", "map", "chat", "nav", "rxp", "bags", "micro" }
local HIDE_TOGGLES = { { "reporter", "hideReporter" } }
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
local peekUntil = 0   -- the "hold to show" key: everything is shown until this time
local cur = { bars = 0, player = 0, hud = 0, quest = 0, map = 0, chat = 0, nav = 0, rxp = 0, bags = 0, micro = 0 }
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

local applyMouseWatch

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

-- Frames the pixel shift checkboxes add to the shift group. They are protected frames, so they only move out of combat.
local SHIFT_FRAMES = {
	bars = {
		"MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "MultiBar5", "MultiBar6",
		"MultiBar7", "MultiBar8", "StanceBar", "PetActionBar", "PossessActionBar", "StatusTrackingBarManager", "MicroMenuContainer",
		"BagsBar",
	},
	units = { "PlayerFrame", "PlayerCastingBarFrame", "TargetFrame", "FocusFrame", "PetFrame", "PartyFrame" },
}
local function rebuildLists()
	local before = {}
	for g, list in pairs(LISTS) do
		if g ~= "nav" and g ~= "shift" then
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
		for _, n in ipairs(DEFAULT_LISTS[g]) do add(n) end
		if g == "bars" then
			for _, n in ipairs(discovered) do
				if not KNOWN_BAR_FRAMES[n] then add(n) end
			end
		end
		if g == "shift" then
			if DB.shiftBars then for _, n in ipairs(SHIFT_FRAMES.bars) do add(n) end end
			if DB.shiftUnits then for _, n in ipairs(SHIFT_FRAMES.units) do add(n) end end
		end
		-- The RestedXP windows are added by their checkboxes. The frames do not have to exist yet: they are looked up
		-- by name every time they are faded.
		if g == "rxp" then
			if DB.rxpGuide then add("RXPFrame") end
			if DB.rxpTargets then
				add("RXPTargetFrame")
				add("RXPItemFrame")
			end
		elseif g == "nav" and DB.rxpArrow then
			add("RXPG_ARROW")
		end
		for _, n in ipairs(DB.extra[g] or {}) do add(n) end
		LISTS[g] = merged
	end
	-- A frame that left a group (a box unticked, /qhud remove) is no longer faded, so it gets its opacity back.
	-- The nav group does this itself, when it takes a frame out of its container.
	local stillListed = {}
	for g, list in pairs(LISTS) do
		if g ~= "shift" then
			for _, n in ipairs(list) do stillListed[n] = true end
		end
	end
	for n in pairs(before) do
		local f = not stillListed[n] and _G[n]
		if f and f.SetAlpha then f:SetAlpha(1) end
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

-- Only the settings that differ from their default are stored. The macro that holds them is limited to 255
-- characters, and storing every setting used most of it, which pushed the list of frames you added (/qhud add) out.
local warnedTooLong = false
local function encodeSettings()
	local parts = {}
	for _, f in ipairs(FIELDS) do
		local v = DB[f.key]
		local text, default
		if f.kind == "bool" then
			text, default = (v and "1" or "0"), (f.def and "1" or "0")
		else
			text, default = string.format("%.3g", v or f.def), string.format("%.3g", f.def)
		end
		if text ~= default then parts[#parts + 1] = f.code .. "=" .. text end
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
		if not warnedTooLong then
			warnedTooLong = true
			print("QuietHUD: your settings and added frames are too long to be saved together, so the added frames will be forgotten on the next reload")
		end
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
	local legacyInstance, legacyMapInstance, sawTrigMap = false, false, false
	local legacyMapMoving, legacyMapDim, legacyMapDimOpacity
	for part in s:gmatch("[^;]+") do
		local k, v = part:match("^%s*([^=%s]+)%s*=%s*(.-)%s*$")
		if k then
			local f = BY_CODE[k]
			if f then
				if f.kind == "bool" then
					DB[f.key] = (v == "1")
				else
					DB[f.key] = tonumber(v) or DB[f.key]
					if k == "tm" then sawTrigMap = true end
				end
			elseif k == "m" then
				-- Until 1.1.4 the minimap had four modes, set by these fields; they are boxes of its row in the grid now.
				legacyMapMoving = (v == "1")
			elseif k == "md" then
				legacyMapDim = (v == "1")
			elseif k == "mo" then
				legacyMapDimOpacity = tonumber(v)
			elseif k == "mi" then
				legacyMapInstance = (v == "1")
			elseif k == "ba" then
				-- An opacity slider for the bags bar and the menu bar existed for a short while; anything below 1 is hidden when idle now.
				if (tonumber(v) or 1) < 0.999 then DB.fadeBags, DB.trigBagsBar = true, 0 end
			elseif k == "ma" then
				if (tonumber(v) or 1) < 0.999 then DB.fadeMicro, DB.trigMicro = true, 0 end
			elseif k == "hb" then
				-- 1.1.4 and earlier hid the bags bar and the menu bar with checkboxes; they are rows of the grid now, hidden when idle.
				if v == "1" then DB.fadeBags, DB.trigBagsBar = true, 0 end
			elseif k == "hm" then
				if v == "1" then DB.fadeMicro, DB.trigMicro = true, 0 end
			elseif k == "ii" then
				-- 1.1.0 to 1.1.4 had one "always show in dungeons and raids" option; it is a column per element now.
				legacyInstance = (v == "1")
			elseif k == "o" then
				-- 1.1.4 stored "action bars on mouse over" on its own; it is a column of the trigger grid now.
				if v == "0" then DB.trigBars = 1 end
			elseif k:sub(1, 1) == "x" then
				local g = k:sub(2)
				DB.extra[g] = {}
				for name in v:gmatch("[^,]+") do DB.extra[g][#DB.extra[g] + 1] = name end
			end
		end
	end
	if not sawTrigMap then
		if legacyMapDim then
			DB.trigMap = 15
			DB.mapIdle = legacyMapDimOpacity or 0.3
		elseif legacyMapMoving == false then
			DB.trigMap = 13
		end
	end
	local function addInstanceBit(key)
		local mask = DB[key] or 0
		if math.floor(mask / 32) % 2 == 0 then DB[key] = mask + 32 end
	end
	if legacyInstance then
		for _, key in ipairs({ "trigBars", "trigPlayer", "trigUnits", "trigTracker", "trigRxp", "trigMap" }) do
			addInstanceBit(key)
		end
	elseif legacyMapInstance then
		addInstanceBit("trigMap")
	end
	rebuildLists()
	if onRestored then onRestored() end
	if applyMouseWatch then applyMouseWatch() end
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
	if applyMouseWatch then applyMouseWatch() end
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

-- Also fades the frames you added to the chat group (/qhud add chat <frame name>), for example the window or
-- background of a chat replacement addon.
local function applyChat(a)
	for i = 1, #chatList do chatList[i]:SetAlpha(a) end
	setAlpha(LISTS.chat, a)
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

-- Fading in and out both take FADE, unless a group is given its own fade-out time (the chat has one).
local function step(v, target, dt, outSeconds)
	if v < target then return math.min(target, v + dt / FADE) end
	return math.max(target, v - dt / math.max(0.05, outSeconds or FADE))
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

-- Some windows are a small frame with their panels hanging off it as children (the RestedXP guide is a bar with the
-- steps above it), so the frame's own rectangle is only part of what you see. This checks the children too. It looks
-- about ten times a second, because listing the children makes garbage.
local deepAt, deepResult = 0, false
local function anyHoveredDeep(names)
	local now = GetTime()
	if now - deepAt < 0.1 then return deepResult end
	deepAt, deepResult = now, false
	for i = 1, #names do
		local f = _G[names[i]]
		if hovered(f) then
			deepResult = true
			break
		end
		if f and f.GetChildren and f:IsShown() then
			local kids = { f:GetChildren() }
			for j = 1, #kids do
				local c = kids[j]
				if c.IsShown and c.IsMouseOver and c:IsShown() and c:IsMouseOver() then
					deepResult = true
					break
				end
			end
			if deepResult then break end
		end
	end
	return deepResult
end

-- What brings an element up comes from its row of the trigger grid (bit i of the mask is trigger i): awake, while
-- moving, new info, mouse over, hide in combat, which beats the rest, and being inside a dungeon or raid.
local T = { AWAKE = 1, MOVING = 2, NEWS = 3, HOVER = 4, COMBAT = 5, INST = 6 }
local function triggered(mask, awake, moved, news, combat, inside, names, deep, hoverNow)
	if barBit(mask, T.COMBAT) and combat then return false end
	if barBit(mask, T.AWAKE) and awake then return true end
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

local function chatTyping()
	return ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() and true or false
end

local function chatHovered()
	for i = 1, #chatList do
		if hovered(chatList[i]) then return true end
	end
	return anyHovered(LISTS.chat)
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

-- Frames in the nav group (for example the direction arrow of a quest guide) are moved under a small host frame of
-- ours, and the host is what fades. A frame that sets its own opacity to show and hide itself would fight with a fade
-- applied to it directly; under a host the two opacities multiply instead, so it can still show and hide itself.
local navHosts, navLastError = {}, nil
local navForce = false   -- /qhud arrow: keeps the nav group visible whatever else is going on
local function applyNav(a)
	local wanted = {}
	for _, name in ipairs(LISTS.nav) do
		local f = _G[name]
		if f and f.SetParent then
			wanted[f] = true
			local rec = navHosts[f]
			if not rec then
				local okHost, made = pcall(function()
					local host = CreateFrame("Frame", nil, UIParent)
					host:SetAllPoints(UIParent)
					local original = f:GetParent()
					f:SetParent(host)
					return { host = host, parent = original }
				end)
				if okHost then
					rec = made
					navHosts[f] = rec
				else
					navLastError = tostring(made)
				end
			end
			if rec then rec.host:SetAlpha(a) end
		end
	end
	-- frames taken out of the group go back where they were
	for f, rec in pairs(navHosts) do
		if not wanted[f] then
			pcall(function() f:SetParent(rec.parent or UIParent) end)
			rec.host:SetAlpha(1)
			navHosts[f] = nil
		end
	end
end
-- A short log of the minimap decisions, saved with the settings on /reload. It is kept even without debug mode,
-- so a minimap that does not show can be diagnosed afterwards.
local function mapLog(msg)
	DB.mapLog = DB.mapLog or {}
	DB.mapLog[#DB.mapLog + 1] = string.format("%.1f %s", GetTime(), msg)
	if #DB.mapLog > 80 then table.remove(DB.mapLog, 1) end
end

-- At partial opacity the game draws a blank map in cities and interiors, so the minimap cluster is never faded
-- with its own opacity. Instead a black overlay on the map darkens it (which also dims the player and quest arrows
-- the game draws on it), and the other parts of the cluster are faded one by one. The cluster and the frames the
-- map sits in keep opacity 1.
local mapOverlay, mapParts, mapDimApplied, mapAncestors

local function getMapOverlay()
	if mapOverlay then return mapOverlay end
	local frame = CreateFrame("Frame", nil, Minimap)
	frame:SetAllPoints(Minimap)
	frame:SetFrameLevel(Minimap:GetFrameLevel() + 20)
	local tex = frame:CreateTexture(nil, "OVERLAY")
	tex:SetAllPoints()
	tex:SetColorTexture(0, 0, 0, 1)
	if frame.CreateMaskTexture then
		local mask = frame:CreateMaskTexture()
		mask:SetAllPoints(tex)
		mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		tex:AddMaskTexture(mask)
	end
	frame:Hide()
	mapOverlay = frame
	return frame
end

local function fadeMapParts(frame, factor)
	for _, child in ipairs({ frame:GetChildren() }) do
		if child ~= Minimap and child ~= mapOverlay then
			if mapAncestors[child] then
				fadeMapParts(child, factor)
			else
				if mapParts[child] == nil then mapParts[child] = child:GetAlpha() end
				child:SetAlpha(mapParts[child] * factor)
			end
		end
	end
	for _, region in ipairs({ frame:GetRegions() }) do
		if mapParts[region] == nil then mapParts[region] = region:GetAlpha() end
		region:SetAlpha(mapParts[region] * factor)
	end
end

local function applyMinimapAlpha(a)
	if not (Minimap and MinimapCluster) then return end
	mapParts = mapParts or {}
	if not mapAncestors then
		mapAncestors = {}
		local f = Minimap:GetParent()
		while f and f ~= UIParent do
			mapAncestors[f] = true
			f = f:GetParent()
		end
	end
	if a >= 0.995 then
		if mapDimApplied then
			mapDimApplied = nil
			if mapOverlay then mapOverlay:Hide() end
			for part, alpha in pairs(mapParts) do part:SetAlpha(alpha) end
			mapParts = {}
		end
		applyList("map", 1)
		return
	end
	if mapDimApplied and math.abs(mapDimApplied - a) < 0.004 then return end
	mapDimApplied = a
	MinimapCluster:SetAlpha(1)
	local overlay = getMapOverlay()
	overlay:SetAlpha(1 - a)
	overlay:Show()
	local ok, err = pcall(function()
		fadeMapParts(MinimapCluster, a)
		fadeMapParts(Minimap, a)
	end)
	if not ok then mapLog("could not fade the minimap parts: " .. tostring(err)) end
	for _, name in ipairs(LISTS.map) do
		local f = name ~= "MinimapCluster" and _G[name]
		if f and f.SetAlpha then f:SetAlpha(a) end
	end
end
-- A faded-out minimap is shrunk to almost nothing (see below), so its own rectangle can no longer be hovered. The rectangle
-- it has at full size is remembered, and the mouse is compared with that one instead. The values are in UIParent units.
local mapRect
local function rememberMapRect()
	local f = MinimapCluster
	if not (f and f.GetRect and f:GetScale() > 0.5) then return end
	local l, b, w, h = f:GetRect()
	if not (l and b and w and h and w > 20 and h > 20) then return end
	local k = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
	mapRect = { l * k, b * k, (l + w) * k, (b + h) * k }
end
local function mouseInMapRect()
	if not mapRect or not GetCursorPosition then return false end
	local x, y = GetCursorPosition()
	local k = UIParent:GetEffectiveScale()
	x, y = x / k, y / k
	return x >= mapRect[1] and x <= mapRect[3] and y >= mapRect[2] and y <= mapRect[4]
end

-- Hiding the Minimap frame and showing it again breaks the map in cities and interiors (it does not come back until
-- the game redraws it), and the player arrow, quest arrow and quest-area overlays ignore opacity, so a faded minimap
-- can be neither hidden nor made transparent. Instead it is shrunk to almost nothing, which takes those along, and
-- put back to its size when it is wanted again. The frame itself is never hidden.
local mapSavedScale

-- Shrinking the minimap has a side effect on other addons that put frames on it: text is measured in whole pixels, so a
-- label measured while the minimap is shrunk comes out thousands of units wide (RestedXP's step pins ended up 6670 wide).
-- When the minimap comes back, that oversized frame sits invisibly over a large part of the screen, takes the mouse and
-- swallows right-clicks that should turn the camera. So whenever the minimap comes back, any frame on it that is much
-- bigger than the minimap itself is cut down to a small hover target (its own owner sets the size again the next time it
-- redraws it, and by then the minimap is not shrunk). Frames of any addon are treated the same, and nothing is switched
-- off, so a pin still shows its tooltip when the mouse is on it.
local function guardOversizedMinimapKids()
	if not (Minimap and Minimap.GetChildren) then return end
	local okKids, kids = pcall(function() return { Minimap:GetChildren() } end)
	if not okKids then return end
	for _, f in ipairs(kids) do
		local okBig, big = pcall(function()
			return f.SetSize and f:GetWidth() * f:GetEffectiveScale() > Minimap:GetWidth() * Minimap:GetEffectiveScale() * 1.5
		end)
		if okBig and big then
			pcall(f.SetSize, f, 24, 24)
			local okT, owner = pcall(function() return GameTooltip:IsShown() and GameTooltip:GetOwner() end)
			if okT and owner == f then GameTooltip:Hide() end
		end
	end
end

local function setMinimapVisible(visible, alpha)
	if not MinimapCluster then return end
	if visible then
		if mapSavedScale then
			MinimapCluster:SetScale(mapSavedScale)
			mapSavedScale = nil
			guardOversizedMinimapKids()
			if C_Timer and C_Timer.After then C_Timer.After(0.5, guardOversizedMinimapKids) end
		end
	else
		pcall(rememberMapRect)
		if not mapSavedScale then mapSavedScale = MinimapCluster:GetScale() end
		MinimapCluster:SetScale(0.001)
	end
	mapLog(string.format("minimap %s (cluster alpha %.2f, scale %.3f)", visible and "shown" or "hidden", alpha or -1,
		MinimapCluster:GetScale()))
end
-- Main loop
-- Shorter hotkey text, for keys such as the number pad or mouse buttons whose full names do not fit on an action
-- button (they show up as "NUM..."): Num Pad 1 becomes N1, Mouse Button 4 becomes M4, Shift- becomes s-, and so on.
-- Matching ignores case and only the parts that match are changed.
local function ci(word)
	return (word:gsub(".", function(c)
		if c:match("%a") then return "[" .. c:lower() .. c:upper() .. "]" end
		if c == " " then return "%s*" end
		return "%" .. c
	end))
end
local SHORT_RULES = {
	{ ci("shift") .. "[%-%+]", "s-" }, { ci("ctrl") .. "[%-%+]", "c-" }, { ci("alt") .. "[%-%+]", "a-" },
	{ ci("num pad") .. "%s*(%d+)", "N%1" }, { ci("num") .. "%s+(%d+)", "N%1" },
	{ ci("num pad") .. "%s*([%+%-%*/%.])", "N%1" },
	{ ci("num pad plus"), "N+" }, { ci("num pad minus"), "N-" }, { ci("num pad multiply"), "N*" },
	{ ci("num pad divide"), "N/" }, { ci("num pad decimal"), "N." }, { ci("num lock"), "NL" },
	{ ci("left mouse button"), "M1" }, { ci("right mouse button"), "M2" }, { ci("middle mouse button"), "M3" },
	{ ci("middle mouse"), "M3" }, { ci("mouse button") .. "%s*(%d+)", "M%1" },
	{ ci("mouse wheel up"), "MwU" }, { ci("mouse wheel down"), "MwD" },
	{ ci("page up"), "PgU" }, { ci("page down"), "PgD" }, { ci("insert"), "Ins" }, { ci("delete"), "Del" },
	{ ci("backspace"), "Bk" }, { ci("caps lock"), "Cap" }, { ci("escape"), "Esc" }, { ci("space"), "Sp" },
}
local function shortHotkey(text)
	for _, rule in ipairs(SHORT_RULES) do text = text:gsub(rule[1], rule[2]) end
	-- The slot on a button is only about three characters wide, so drop the dash after a modifier as well:
	-- c-N1 becomes cN1 and s-1 becomes s1.
	local prefix = ""
	while true do
		local mod, rest = text:match("^([scaSCA])%-(.+)$")
		if not mod then break end
		prefix, text = prefix .. mod, rest
	end
	return prefix .. text
end
local shortened = {}

-- Buttons outside the eight action bars that show a hotkey too: the pet bar, the stance bar and the possess bar.
local EXTRA_BUTTONS = { { "PetActionButton", 10 }, { "StanceButton", 10 }, { "PossessButton", 2 } }

-- Shortens (or, with wantShort false, restores) the hotkey text of one button.
local function shortenOne(fs, wantShort)
	local okText, text = pcall(fs.GetText, fs)
	if not (okText and type(text) == "string") or (issecretvalue and issecretvalue(text)) then return end
	local rec = shortened[fs]
	if wantShort then
		-- Blizzard writes the long text again on binding and page changes, so redo it when it changed.
		if not (rec and text == rec.short) then
			local short = shortHotkey(text)
			if short ~= text then
				-- The slot is narrow, so give the shorter text the width of the whole button as well.
				local width = rec and rec.width or fs:GetWidth()
				local parent = fs:GetParent()
				local room = parent and parent:GetWidth() or width
				shortened[fs] = { orig = text, short = short, width = width }
				fs:SetText(short)
				if room > width then fs:SetWidth(room) end
			else
				shortened[fs] = nil
			end
		end
	elseif rec and text == rec.short then
		fs:SetText(rec.orig)
		if rec.width then fs:SetWidth(rec.width) end
		shortened[fs] = nil
	end
end
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

-- Pixel shift (opt-in, experimental). OLED panels can burn in from shapes that stay in one place, so every few minutes the
-- frames in the shift group are moved a couple of pixels along a small circle. Nothing saved is ever changed: a frame's
-- anchors are remembered when it is first moved and put back exactly when the option is turned off, when Edit Mode opens
-- and at logout. Nothing is moved during combat. If the game or another addon moves a frame while it is shifted, the shift
-- steps aside and takes the new position as the normal one, so a restore can never drag a frame back to an old spot.
-- Everything lives inside one block and only five functions come out of it: a Lua file can have only 200 top-level
-- local variables, and the addon had reached that limit.
local tickShift, restoreShift, shiftNow, shiftReport, applyTooltips
do
	local SHIFT_STEPS = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 1 }, { -1, 1 }, { -1, 0 }, { -1, -1 }, { 0, -1 }, { 1, -1 } }
	local shiftIndex, shiftNextAt, shiftWantX, shiftWantY, shiftClock, lastEdit = 1, 0, 0, 0, 0, false
	local shiftState, shiftLastError = {}, nil

	local function anchorList(f)
		local t = {}
		for i = 1, f:GetNumPoints() do
			local point, rel, relPoint, x, y = f:GetPoint(i)
			t[i] = { point, rel, relPoint, x or 0, y or 0 }
		end
		return t
	end

	local function anchorSig(t)
		local parts = {}
		for i, a in ipairs(t) do
			parts[i] = tostring(a[1]) .. "|" .. tostring(a[2]) .. "|" .. tostring(a[3]) .. "|" .. string.format("%.3f|%.3f", a[4], a[5])
		end
		return table.concat(parts, ";")
	end

	local function setAnchors(f, t, dx, dy)
		f:ClearAllPoints()
		for _, a in ipairs(t) do
			f:SetPoint(a[1], a[2], a[3], a[4] + dx, a[5] + dy)
		end
	end

	local function anchoredToListed(t, listed, f)
		for _, a in ipairs(t) do
			if a[2] and a[2] ~= f and listed[a[2]] then return true end
		end
		return false
	end

	local function syncFrame(f, listed)
		local now = anchorList(f)
		if #now == 0 then return end
		local sig = anchorSig(now)
		local st = shiftState[f]
		if st and st.sig ~= sig then
			-- Something else moved it since: that position is the new normal, and ours is forgotten.
			st = nil
			shiftState[f] = nil
		end
		-- A frame anchored to another frame of the group moves along with it, so it is not shifted a second time.
		if anchoredToListed(now, listed, f) then
			if st then
				setAnchors(f, st.base, 0, 0)
				shiftState[f] = nil
			end
			return
		end
		if shiftWantX == 0 and shiftWantY == 0 then
			if st then
				setAnchors(f, st.base, 0, 0)
				shiftState[f] = nil
			end
			return
		end
		-- Offsets are in the frame's own units. A frame that is shrunk (the faded minimap) is left alone until it is back to size.
		local k = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
		if not (k >= 0.5 and k <= 2) then return end
		if not st then st = { base = now } end
		if st.wx ~= shiftWantX or st.wy ~= shiftWantY then
			setAnchors(f, st.base, shiftWantX / k, shiftWantY / k)
			st.wx, st.wy = shiftWantX, shiftWantY
			st.sig = anchorSig(anchorList(f))
			shiftState[f] = st
		end
	end

	local function syncShift()
		if InCombatLockdown() then return end
		local listed, frames = {}, {}
		for _, name in ipairs(LISTS.shift) do
			local f = _G[name]
			if f and f.GetNumPoints and f.GetPoint and not (f.IsForbidden and f:IsForbidden()) and not listed[f] then
				listed[f] = true
				frames[#frames + 1] = { f, name }
			end
		end
		for _, rec in ipairs(frames) do
			local ok, err = pcall(syncFrame, rec[1], listed)
			if not ok then shiftLastError = rec[2] .. ": " .. tostring(err) end
		end
		-- Frames taken out of the group are put back.
		for f, st in pairs(shiftState) do
			if not listed[f] then
				pcall(function()
					if anchorSig(anchorList(f)) == st.sig then setAnchors(f, st.base, 0, 0) end
				end)
				shiftState[f] = nil
			end
		end
	end

	local function stepShift(now, edit)
		if not DB.pixelShift and next(shiftState) == nil then return end
		if DB.pixelShift and not edit then
			if now >= shiftNextAt then
				shiftIndex = shiftIndex % #SHIFT_STEPS + 1
				shiftNextAt = now + (DB.shiftMinutes or 3) * 60
			end
			local s = SHIFT_STEPS[shiftIndex]
			local px = DB.shiftPixels or 2
			shiftWantX, shiftWantY = s[1] * px, s[2] * px
		else
			shiftWantX, shiftWantY = 0, 0
		end
		syncShift()
	end

	-- Once a second, and at once when Edit Mode opens or closes.
	tickShift = function(dt, now, edit)
		shiftClock = shiftClock + dt
		if shiftClock > 1 or edit ~= lastEdit then
			shiftClock = 0
			lastEdit = edit
			local ok, err = pcall(stepShift, now, edit)
			if not ok then shiftLastError = tostring(err) end
		end
	end

	restoreShift = function()
		shiftWantX, shiftWantY = 0, 0
		syncShift()
	end

	shiftNow = function()
		shiftNextAt = 0
	end

	shiftReport = function()
		print("QuietHUD pixel shift (experimental): " .. (DB.pixelShift and "on" or "off") .. ", offset now " .. shiftWantX .. "," .. shiftWantY .. " pixels, a move every " .. (DB.shiftMinutes or 3) .. " minutes, /qhud shift on, off or now")
		for _, name in ipairs(LISTS.shift) do
			local f = _G[name]
			local st = f and shiftState[f]
			print("  " .. name .. ": " .. (not f and "no frame with that name" or (st and ("shifted by " .. (st.wx or 0) .. "," .. (st.wy or 0)) or "at its normal position")))
		end
		if shiftLastError then print("  last problem: " .. shiftLastError) end
	end

	-- Tooltip opacity: the whole tooltip is faded, text included. Untouched while the setting is at 1. The game puts a tooltip
	-- back to full opacity each time it is shown, and an addon can re-show one many times a second (RestedXP does when it
	-- redraws its map pins), so the opacity is also applied the moment a tooltip is shown, or it would flash at full
	-- opacity before the next update. A tooltip the game is fading out is left alone: only one that is more opaque than
	-- wanted is lowered.
	local TOOLTIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "EmbeddedItemTooltip" }
	local tooltipTouched = false
	applyTooltips = function()
		local a = DB.tooltipAlpha or 1
		local restoring = false
		if a >= 0.999 then
			if not tooltipTouched then return end
			a = 1
			restoring = true
		end
		for i = 1, #TOOLTIPS do
			local f = _G[TOOLTIPS[i]]
			if f and f.SetAlpha and f.GetAlpha then
				local now = f:GetAlpha()
				if (restoring and math.abs(now - a) > 0.01) or (not restoring and now > a + 0.01) then f:SetAlpha(a) end
			end
		end
		tooltipTouched = a < 1
	end
	for i = 1, #TOOLTIPS do
		local f = _G[TOOLTIPS[i]]
		if f and f.HookScript then pcall(f.HookScript, f, "OnShow", function() applyTooltips() end) end
	end
end
-- The Issue Reporter button is hidden or not, with a checkbox, outside the fade. This turns the stored value into an
-- opacity: 1 leaves the frame alone, 0 hides it.
local function fixedAlpha(key)
	local v = DB[key]
	if type(v) == "boolean" then return v and 0 or 1 end
	return v or 1
end

local function update(dt)
	local now = GetTime()
	local edit = EditModeManagerFrame and EditModeManagerFrame:IsShown() or false
	local combat = UnitAffectingCombat("player") and true or false
	local enabled = DB.enabled

	local inside = inDungeonOrRaid()
	local active = edit or (DB.inCombat and (combat or now < combatEnd)) or (DB.sheathShows and drawn)
		or (DB.showOnTarget and UnitExists("target"))
	lastActive = active and true or false
	local okMove, moving = pcall(isMoving)
	if okMove and moving then moveUntil = now + MOVE_LINGER end
	if (okMove and moving and true or false) ~= lastLoggedMoving then
		lastLoggedMoving = okMove and moving and true or false
		mapLog(string.format("moving=%s by %s (speed %s, fade=%s, triggers=%s, idle opacity=%s)", tostring(lastLoggedMoving),
			lastMoveReason, lastSpeedText, tostring(DB.fadeMinimap), tostring(DB.trigMap), tostring(DB.mapIdle)))
	end

	local vis = {}
	local moved = now < moveUntil
	vis.bars = triggered(DB.trigBars, active, moved, false, combat, inside, barHover)
	vis.player = triggered(DB.trigPlayer, active, moved, false, combat, inside, LISTS.player)
	vis.hud = triggered(DB.trigUnits, active, moved, false, combat, inside, LISTS.hud)
	vis.bags = triggered(DB.trigBagsBar, active, moved, false, combat, inside, LISTS.bags)
	vis.micro = triggered(DB.trigMicro, active, moved, false, combat, inside, LISTS.micro)
	vis.quest = triggered(DB.trigTracker, active, moved, now < questUntil, combat, inside, LISTS.quest)
	vis.map = triggered(DB.trigMap, active, moved, now < mapUntil, combat, inside, LISTS.map, false,
		mouseInMapRect() or anyHovered(LISTS.map))
	-- Chat is the one element whose hover is a list of frames, and typing always brings it up, even in combat.
	local chatMask = DB.trigChat
	local chatWanted = (barBit(chatMask, T.AWAKE) and active) or (barBit(chatMask, T.MOVING) and moved)
		or (barBit(chatMask, T.NEWS) and now < chatUntil) or (barBit(chatMask, T.INST) and inside)
		or (barBit(chatMask, T.HOVER) and chatHovered())
	if barBit(chatMask, T.COMBAT) and combat then chatWanted = false end
	vis.chat = (chatWanted or chatTyping()) and true or false
	vis.nav = navForce or triggered(DB.trigNav, active, moved, false, combat, inside, LISTS.nav)
	vis.rxp = triggered(DB.trigRxp, active, moved, now < questUntil, combat, inside, LISTS.rxp, true)
	if edit or now < peekUntil or (DB.peekAlt and IsAltKeyDown()) or (DB.peekCtrl and IsControlKeyDown()) or (DB.peekShift and IsShiftKeyDown()) then
		for g in pairs(vis) do vis[g] = true end
	end

	local flags = {
		bars = DB.fadeBars, player = DB.fadePlayer, hud = DB.fadeUnits,
		quest = DB.fadeTracker, map = DB.fadeMinimap, chat = DB.fadeChat, nav = true, rxp = true,
		bags = DB.fadeBags, micro = DB.fadeMicro,
	}
	local idle = DB.idle or 0
	local mapAlpha = 1
	for _, g in ipairs(FADE_ORDER) do
		if enabled and flags[g] then
			cur[g] = step(cur[g], vis[g] and 1 or 0, dt, g == "chat" and DB.chatFadeSeconds or nil)
			local peak = DB.base or 0.6
			if edit or (g == "map" and not DB.mapFollowsHud) then
				peak = 1
			elseif g == "chat" and not DB.chatDim then
				peak = DB.chatOpacity or 1
			elseif g == "rxp" then
				peak = DB.rxpShown or 0.7
			elseif g == "nav" then
				peak = DB.navShown or 0.6
			end
			local floor = idle
			if g == "rxp" then
				floor = DB.rxpIdle or 0
			elseif g == "nav" then
				floor = DB.navIdle or 0
			end
			if g == "map" then floor = DB.mapIdle or 0 end
			local low = math.min(floor, peak)
			local a = low + (peak - low) * cur[g]
			local dimHere = false
			if g == "map" then
				-- The game redraws the map of a building interior as you move through it, and draws a blank map if that
				-- happens while the minimap is partly transparent. So indoors the map stays fully opaque and is dimmed
				-- with a dark layer instead. Outdoors it uses real transparency.
				local okIn, indoors = pcall(function() return IsIndoors and IsIndoors() end)
				dimHere = (DB.mapDarken or (okIn and indoors)) and true or false
			end
			if g == "chat" then
				applyChat(a)
			elseif g == "bars" then
				applyBars(a, true)
			elseif g == "nav" then
				applyNav(a)
			elseif g == "map" then
				if dimHere then
					applyMinimapAlpha(a)
				else
					if mapDimApplied then applyMinimapAlpha(1) end
					applyList(g, a)
				end
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
			elseif g == "map" then
				applyMinimapAlpha(1)
			elseif g == "nav" then
				applyNav(1)
			else
				applyList(g, 1)
			end
			fading[g] = false
			cur[g] = 1
		end
	end

	local wantMinimap = not (enabled and DB.fadeMinimap) or mapAlpha > 0.01
	if MinimapCluster and wantMinimap ~= minimapShown then
		minimapShown = wantMinimap
		setMinimapVisible(wantMinimap, mapAlpha)
	end

	for _, pair in ipairs(HIDE_TOGGLES) do
		local fixed = enabled and not edit and fixedAlpha(pair[2]) or 1
		if fixed < 0.999 then
			applyList(pair[1], fixed)
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

	-- Pixel shift: once a second, and at once when Edit Mode opens or closes.
	tickShift(dt, now, edit)
	applyTooltips()

	hotkeyClock = hotkeyClock + dt
	if hotkeyClock > 0.5 then
		hotkeyClock = 0
		if MinimapCluster and MinimapCluster:GetScale() > 0.5 then pcall(rememberMapRect) end
		if MinimapCluster and mapSavedScale and MinimapCluster:GetScale() > 0.01 then MinimapCluster:SetScale(0.001) end
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
		{ "note", "These three decide when the HUD counts as awake. Which elements come up when it is awake is set per element in the Awake column of the Elements page." },
		{ "check", "inCombat", "Show in combat" },
		{ "check", "sheathShows", "Show while my weapon is drawn" },
		{ "check", "showOnTarget", "Show while I have a target" },
		{ "slider", "linger", "Stay visible after combat (seconds)", 0, 15, 1, "%.0f" },
	} },
	{ title = "Elements", items = {
		{ "grid", "elements" },
		{ "note", "Awake: combat, a drawn weapon or a target. Dungeon or raid: while you are inside one. New info: chat messages, quest progress, a zone change (minimap). Hide in combat beats the rest. For mouse over only, leave just that box ticked." },
		{ "note", "Enemy, party, buffs: the frame of whatever you click on (enemy, NPC or player), your focus and pet, party and raid frames, buff and debuff icons, totems, cooldown trackers, the damage meter, the durability icon and the loss of control alert." },
		{ "slider", "mapIdle", "Minimap opacity when idle (0 = hidden)", 0, 1, 0.05, "%.2f" },
		{ "check", "mapFollowsHud", "Minimap: use the HUD opacity when shown, not solid" },
		{ "check", "mapDarken", "Minimap: darken it instead of fading it" },
	} },
	{ title = "Bars", items = {
		{ "note", "Fade picks which action bars fade. It only counts while Fade is ticked for Action bars on the Elements page, which is the master switch (the stance, pet and XP bars follow that switch)." },
		{ "bargrid" },
		{ "check", "shortHotkeys", "Shorten hotkey text (Num Pad 1 shows N1)" },
	} },
	{ title = "Chat", items = {
		{ "note", "Fading the chat, and what brings it up, is on the Elements page." },
		{ "check", "chatDim", "Chat uses the HUD opacity when active" },
		{ "slider", "chatOpacity", "Chat opacity when active (if not the HUD's)", 0.1, 1, 0.05, "%.2f" },
		{ "slider", "chatSeconds", "Chat stays after a message (seconds)", 2, 30, 1, "%.0f" },
		{ "slider", "chatFadeSeconds", "Chat fade out animation (seconds)", 0.3, 5, 0.1, "%.1f" },
		{ "kinds" },
	} },
	{ title = "RXP", items = {
		{ "check", "rxpGuide", "Fade the RestedXP guide window" },
		{ "check", "rxpTargets", "Fade the RestedXP targets and items windows" },
		{ "check", "rxpArrow", "Fade the RestedXP waypoint arrow" },
		{ "slider", "rxpShown", "Guide, targets, items: opacity when shown", 0.1, 1, 0.05, "%.2f" },
		{ "slider", "rxpIdle", "Guide, targets, items: opacity when idle (0 = hidden)", 0, 1, 0.05, "%.2f" },
		{ "slider", "navShown", "Arrow: opacity when shown", 0.1, 1, 0.05, "%.2f" },
		{ "slider", "navIdle", "Arrow: opacity when idle (0 = hidden)", 0, 1, 0.05, "%.2f" },
		{ "grid", "rxp" },
		{ "note", "The same columns as on the Elements page. At idle opacity 0 the windows are hidden completely, so a small value helps you find them." },
	} },
	{ title = "Extras", items = {
		{ "heading", "Show the whole HUD" },
		{ "check", "peekAlt", "While I hold Alt" },
		{ "check", "peekCtrl", "While I hold Ctrl" },
		{ "check", "peekShift", "While I hold Shift" },
		{ "heading", "Timing and tooltips" },
		{ "slider", "questSeconds", "New info stays, for quests and zone changes (seconds)", 3, 30, 1, "%.0f" },
		{ "slider", "tooltipAlpha", "Tooltip opacity (1 = normal)", 0.3, 1, 0.05, "%.2f" },
		{ "heading", "Pixel shift (OLED, experimental)" },
		{ "check", "pixelShift", "Move the minimap and tracker a little every few minutes" },
		{ "check", "shiftBars", "Also the action bars, bags and menu bar" },
		{ "check", "shiftUnits", "Also the player, target and party frames" },
		{ "slider", "shiftPixels", "Distance (pixels)", 1, 4, 1, "%.0f" },
		{ "slider", "shiftMinutes", "Minutes between moves", 1, 10, 1, "%.0f" },
		{ "heading", "Other" },
		{ "check", "hideReporter", "Hide the beta Issue Reporter button" },
		{ "check", "questTarget", "Enable quest-mob targeting key (experimental)" },
		{ "note", "Works like Tab, but only through the mobs your highlighted quest needs: each press goes to the next one. Needs enemy nameplates on (a kill objective can still be reached by name without). After ticking this, bind the key: Esc, Options, Keybindings, AddOns, QuietHUD, \"Target highlighted quest mob\"." },
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
		rebuildLists()
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
		local check = makeMaskCheck(parent, 12, y - 14 - (i - 1) * 22, "chatKinds", i)
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

-- The trigger grid: a row per element, a column per thing that can bring it up. Each cell is one bit of the row's
-- number, like the bar grid, and only the cells that mean something for that element are drawn. The columns are
-- ordered so that no row has a gap: the ones every element has come first, then hide in combat, then new info.
local TRIGGER_COLS = {
	{ "Awake", 1 }, { "While\nmoving", 2 }, { "Mouse\nover", 4 }, { "Dungeon\nor raid", 6 },
	{ "Hide in\ncombat", 5 }, { "New\ninfo", 3 },
}
local COL_AT = {}
for position, col in ipairs(TRIGGER_COLS) do COL_AT[col[2]] = position end
local GRIDS = {
	elements = {
		fade = true,
		rows = {
			{ "Action bars", "fadeBars", "trigBars", { 1, 2, 4, 6, 5 } },
			{ "Player frame", "fadePlayer", "trigPlayer", { 1, 2, 4, 6, 5 } },
			{ "Enemy, party, buffs", "fadeUnits", "trigUnits", { 1, 2, 4, 6, 5 } },
			{ "Objective tracker", "fadeTracker", "trigTracker", { 1, 2, 3, 4, 5, 6 } },
			{ "Chat", "fadeChat", "trigChat", { 1, 2, 3, 4, 5, 6 } },
			{ "Minimap", "fadeMinimap", "trigMap", { 1, 2, 3, 4, 5, 6 } },
			{ "Bags bar", "fadeBags", "trigBagsBar", { 1, 2, 4, 6, 5 } },
			{ "Menu bar", "fadeMicro", "trigMicro", { 1, 2, 4, 6, 5 } },
		},
	},
	rxp = {
		rows = {
			{ "Guide, targets, items", false, "trigRxp", { 1, 2, 3, 4, 5, 6 } },
			{ "Arrow", false, "trigNav", { 1, 2, 4, 5, 6 } },
		},
	},
}

local function makeFadeCell(parent, x, y, key)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetPoint("TOPLEFT", x, y)
	check:SetScript("OnClick", function(self)
		DB[key] = not DB[key]
		self:SetChecked(DB[key] and true or false)
		persistSoon()
	end)
	controls[#controls + 1] = function() check:SetChecked(DB[key] and true or false) end
	controls[#controls]()
end

-- Returns the height it took.
local function makeTriggerGrid(parent, y, grid)
	local fadeX, firstX, pitch = 144, 190, 46
	local function header(x, text)
		local h = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		h:SetPoint("TOP", parent, "TOPLEFT", x + 16, y)
		h:SetWidth(64)
		h:SetJustifyH("CENTER")
		h:SetText(text)
	end
	if grid.fade then header(fadeX, "Fade") end
	for position, col in ipairs(TRIGGER_COLS) do header(firstX + (position - 1) * pitch, col[1]) end
	local rowY = y - 30
	for _, row in ipairs(grid.rows) do
		local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		label:SetPoint("TOPLEFT", 16, rowY - 8)
		label:SetText(row[1])
		if row[2] then makeFadeCell(parent, fadeX, rowY, row[2]) end
		for _, i in ipairs(row[4]) do
			makeMaskCheck(parent, firstX + (COL_AT[i] - 1) * pitch, rowY, row[3], i)
		end
		rowY = rowY - 28
	end
	return 30 + #grid.rows * 28 + 6
end

-- A section heading. Returns the height it took.
local function makeHeading(parent, y, text)
	local heading = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	heading:SetPoint("TOPLEFT", 16, y - 2)
	heading:SetText(text)
	return 22
end

-- A paragraph of small grey text. Returns the height it took.
local function makeNote(parent, y, text)
	local note = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	note:SetPoint("TOPLEFT", 16, y)
	note:SetWidth(424)
	note:SetJustifyH("LEFT")
	note:SetTextColor(0.75, 0.75, 0.75)
	note:SetText(text)
	return math.max(16, math.ceil(note:GetStringHeight())) + 8
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
	rebuildLists()
	syncControls()
	if armEntry then armEntry() end
end

local function buildConfig()
	config = CreateFrame("Frame", "QuietHUDConfig", UIParent)
	config:SetSize(460, 700)
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
		for idx, item in ipairs(page.items) do
			if item[1] == "check" then
				makeCheck(frame, y, item[3], item[2])
				y = y - 26
			elseif item[1] == "kinds" then
				makeChatKinds(frame, y)
				y = y - (18 + #CHAT_KINDS * 22)
			elseif item[1] == "bargrid" then
				makeBarGrid(frame, y)
				y = y - 220
			elseif item[1] == "grid" then
				y = y - makeTriggerGrid(frame, y, GRIDS[item[2]])
			elseif item[1] == "note" then
				if page.items[idx - 1] and page.items[idx - 1][1] == "check" then y = y - 4 end
				y = y - makeNote(frame, y, item[2])
			elseif item[1] == "heading" then
				if idx > 1 then y = y - 10 end
				y = y - makeHeading(frame, y, item[2])
			else
				if page.items[idx - 1] and page.items[idx - 1][1] == "check" then y = y - 6 end
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
				names[singular(n)] = n
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

-- Quest-mob targeting. Addons cannot change the target themselves, and the game lets only one targeting change take
-- effect per key press, so a chain of Tabs cannot skip the mobs that are not quest mobs. Instead the addon looks at the
-- enemy nameplates just before the press, works out which quest mob comes next after the one you have (nearest first,
-- then round again, like Tab) and has the key target it by name with the skull. Targeting a nameplate directly was tried
-- and the game does not allow it here (the target ended up on the player), so identical mobs cannot be told apart: a name
-- always goes to the nearest one, and the key steps between different kinds of quest mob, skipping the identical ones. When no
-- quest mob is on a nameplate, because it is too far for one, a kill objective is still targeted by name, which reaches as
-- far as /target does.
local run = { active = false, names = {}, needles = {}, plan = nil }

-- The quest mobs among the visible enemy nameplates, nearest first. Returns nil when there are no nameplates at
-- all (for example when enemy nameplates are turned off).
local function questMobsOnScreen(names, needles)
	if not (C_NamePlate and C_NamePlate.GetNamePlates) then return nil end
	local ok, plates = pcall(C_NamePlate.GetNamePlates)
	if not ok or type(plates) ~= "table" or #plates == 0 then return nil end
	local list = {}
	local others = 0 -- attackable, living enemies on nameplates that are not quest mobs
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
			if not (okUnit and mob) then
				local okA, attackable = pcall(function() return UnitCanAttack("player", unit) and not UnitIsDead(unit) end)
				if okA and attackable then others = others + 1 end
			end
			if okUnit and mob then
				local dist
				if UnitDistanceSquared then
					local okDist, d = pcall(UnitDistanceSquared, unit)
					if okDist and type(d) == "number" and not (issecretvalue and issecretvalue(d)) then dist = d end
				end
				local name = UnitName(unit)
				if name and not (issecretvalue and issecretvalue(name)) then
					list[#list + 1] = { name = name, dist = dist, unit = unit, order = #list + 1 }
				end
			end
		end
	end
	table.sort(list, function(a, b)
		local da, db = a.dist or math.huge, b.dist or math.huge
		if da ~= db then return da < db end
		return a.order < b.order
	end)
	return list, others
end

-- The next quest mob after the one you have targeted (nearest first, then round again), or the nearest one when your
-- target is not one of them. Because the key targets by name, a mob with the same name as the current target is skipped
-- (the name would just give the same one again); when every quest mob has that name, the nearest one is used.
local function chooseNextMob(list)
	for i, mob in ipairs(list) do
		local okSame, same = pcall(UnitIsUnit, "target", mob.unit)
		if okSame and same then
			for step = 1, #list - 1 do
				local candidate = list[(i - 1 + step) % #list + 1]
				if candidate.name ~= mob.name then return candidate, "the next kind of quest mob" end
			end
			return list[1], "the nearest quest mob"
		end
	end
	return list[1], "the nearest quest mob"
end

local targetButton = CreateFrame("Button", "QuietHUDTargetButton", UIParent, "SecureActionButtonTemplate")
targetButton:SetAttribute("type", "macro")
targetButton:SetAttribute("macrotext", "")
targetButton:RegisterForClicks("AnyDown", "AnyUp")

-- The game locks addon changes to secure buttons during combat, so in combat the key can only do what it was set up to do
-- beforehand. Out of combat every press replaces the button's action with the quest mob it picks. For combat the button
-- is left holding a macro that targets the nearest quest mob kind by name, worked out while you were still out of combat
-- (see prepareCombat below). Without a quest mob to name, it is a plain Tab plus the skull. (A secure snippet that could
-- cycle a whole list in combat does not work in this client: the game cannot compile snippet text here.)
local COMBAT_MACRO = "/targetenemy\n/tm 0\n/tm " .. SKULL
armEntry = function()
	if InCombatLockdown() then return end
	targetButton:SetAttribute("type", "macro")
	targetButton:SetAttribute("unit", nil)
	targetButton:SetAttribute("macrotext", DB.questTarget and (run.combatMacro or COMBAT_MACRO) or "")
end
armEntry()

-- Everything about the quest and the combat macro is in one block, because a Lua file can have only 200 top-level local
-- variables.
do
	-- The quest the key is working from: the one you picked, unless it is complete or gone from the log.
	run.current = function()
		local trackedID = highlightedQuestID()
		local questID = run.pinned or trackedID
		if run.pinned then
			local okLog, gone = pcall(function()
				if C_QuestLog.GetLogIndexForQuestID and not C_QuestLog.GetLogIndexForQuestID(run.pinned) then return true end
				if C_QuestLog.IsComplete and C_QuestLog.IsComplete(run.pinned) then return true end
				return false
			end)
			if okLog and gone then
				run.pinned = nil
				questID = trackedID
			end
		end
		local ok, names, needles = pcall(questNames, questID)
		return questID, trackedID, names, needles, ok
	end

	-- The quest key does not chat about what a press did (that is only shown in debug mode). The few messages that explain why a
	-- press did nothing go through here, at most one every 3 seconds, so pressing the key over and over does not fill the chat.
	run.say = function(text)
		local now = GetTime()
		if run.lastSay and now - run.lastSay < 3 then return end
		run.lastSay = now
		print(text)
	end

	-- Picks the name the key will use in combat: the nearest quest mob on the nameplates, else the first kill objective.
	-- Only possible out of combat, and it does not touch the button (armEntry does that).
	run.prepare = function(mobs, names, others)
		if InCombatLockdown() then return end
		-- When every enemy around is a quest mob, the game's own Tab is quest-only, and it steps through identical mobs too.
		run.combatTab = (mobs and #mobs >= 2 and (others or 1) == 0) and true or false
		local name = mobs and mobs[1] and mobs[1].name
		if not name then
			local kills = {}
			for _, n in pairs(names or {}) do
				if type(n) == "string" then kills[#kills + 1] = n end
			end
			table.sort(kills)
			name = kills[1]
		end
		local label = run.combatTab and "a plain Tab, every enemy nearby is a quest mob"
			or (name and (name .. " by name")) or "a plain Tab, no quest mob is known"
		if label ~= run.combatLabel then
			run.combatLabel = label
			trace("QuietHUD: in combat the key will be " .. label)
		end
		run.combatName = (not run.combatTab) and name or nil
		run.combatMacro = (name and not run.combatTab) and ("/targetexact " .. name .. "\n/tm 0\n/tm " .. SKULL) or nil
	end

	-- Keep that current while you are out of combat.
	local pending = false
	local function refresh()
		pending = false
		if not DB.questTarget or InCombatLockdown() then return end
		local _, _, names, needles, ok = run.current()
		if not ok then return end
		local okMobs, mobs, others = pcall(questMobsOnScreen, names, needles)
		run.prepare(okMobs and mobs or nil, names, others)
		armEntry()
	end
	local function schedule()
		if pending or not (C_Timer and C_Timer.After) then return end
		pending = true
		C_Timer.After(0.5, refresh)
	end
	local armFrame = CreateFrame("Frame")
	for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED",
		"QUEST_LOG_UPDATE", "QUEST_WATCH_UPDATE", "SUPER_TRACKING_CHANGED", "PLAYER_REGEN_ENABLED" }) do
		pcall(armFrame.RegisterEvent, armFrame, e)
	end
	armFrame:SetScript("OnEvent", schedule)
end
local function isActionClick(down)
	local useDown = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown") and true or false
	return (down and true or false) == useDown
end

targetButton:SetScript("PreClick", function(self, _, down)
	if not isActionClick(down) then return end
	run.plan = nil
	if not DB.questTarget then
		run.say("QuietHUD: quest targeting is off. Turn it on in /qhud, Extras.")
		return
	end
	if InCombatLockdown() then
		if not run.combatWarned then
			run.combatWarned = true
			if run.combatName then
				trace("QuietHUD: in combat the key targets " .. run.combatName .. " by name, picked before the fight, because the game locks addon changes in combat")
			elseif run.combatTab then
				trace("QuietHUD: in combat the key is a plain Tab, because every enemy near you was a quest mob before the fight and the game locks addon changes in combat")
			else
				trace("QuietHUD: in combat the key works as a plain Tab, because the game locks addon changes in combat and no quest mob was known before the fight")
			end
		end
		return
	end
	local questID, trackedID, names, needles, ok = run.current()
	if not ok then
		self:SetAttribute("macrotext", "")
		run.say("QuietHUD: could not read your quests just now")
		return
	end
	run.names, run.needles = names, needles
	-- Say which quest this press is working from, so it is clear when no quest is tracked and every quest in the log is used.
	local forText = "all your quests, because none is tracked"
	if questID then
		local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
		forText = (title and title ~= "") and title or ("quest " .. tostring(questID))
		if trackedID and trackedID ~= questID then forText = forText .. " (the game is tracking another quest, the key stays on this one)" end
	end
	if debugOn then
		local kills = {}
		for _, n in pairs(names) do kills[#kills + 1] = tostring(n) end
		trace("QuietHUD: --- key press. start target=" .. tostring(UnitName("target")))
		trace("QuietHUD: tracked quest id " .. tostring(trackedID) .. ", using quest id " .. tostring(questID) .. ", kill names: [" .. table.concat(kills, ", ")
			.. "], tooltip needles: [" .. table.concat(needles, ", ") .. "]")
	end
	local mobs, others = questMobsOnScreen(names, needles)
	run.prepare(mobs, names, others)
	if mobs and #mobs > 0 then
		if #mobs >= 2 and others == 0 then
			-- Every enemy on a nameplate is a quest mob, so the game's own Tab only goes to quest mobs, and unlike a name it
			-- steps through identical ones.
			run.plan = "by Tab, every enemy nearby is a quest mob, for " .. forText
			self:SetAttribute("macrotext", COMBAT_MACRO)
			trace("QuietHUD: " .. #mobs .. " quest mobs and no other enemy on the nameplates, so this press is a plain Tab")
			return
		end
		local mob, why = chooseNextMob(mobs)
		run.plan = why .. " for " .. forText .. ", by name"
		local text = "/targetexact " .. mob.name .. "\n/tm 0\n/tm " .. SKULL
		trace("QuietHUD: " .. #mobs .. " quest mob(s) on the nameplates, going to " .. why .. " by name: " .. text:gsub("\n", " | "))
		self:SetAttribute("macrotext", text)
		return
	end
	-- Nothing on a nameplate (none at all, or none of them a quest mob): a kill objective can still be targeted by name,
	-- which reaches as far as /target does. With several kill objectives each press takes the next one.
	local kills = {}
	for _, n in pairs(names) do
		if type(n) == "string" then kills[#kills + 1] = n end
	end
	table.sort(kills)
	if #kills > 0 then
		run.rotor = (run.rotor or 0) % #kills + 1
		local name = kills[run.rotor]
		run.plan = "by name, nothing is on a nameplate, for " .. forText
		local text = "/targetexact " .. name .. "\n/tm 0\n/tm " .. SKULL
		trace("QuietHUD: no quest mob on the nameplates, trying " .. name .. " by name: " .. text:gsub("\n", " | "))
		self:SetAttribute("macrotext", text)
		return
	end
	self:SetAttribute("macrotext", "")
	if not mobs then
		if not run.plateWarned then
			run.plateWarned = true
			run.say("QuietHUD quest key: no enemy nameplates to look at. Turn on enemy nameplates so the key can find quest mobs (shown once per session, or untick the quest key in /qhud, Extras).")
		end
		trace("QuietHUD: there are no nameplates, so nothing was pressed")
	else
		run.say("QuietHUD: no quest mob found among the nearby enemies")
		trace("QuietHUD: no quest mob on the nameplates, so nothing was pressed")
	end
end)

targetButton:SetScript("PostClick", function(self, _, down)
	if not InCombatLockdown() then armEntry() end
	if not isActionClick(down) then return end
	if run.plan then
		local name = UnitName("target")
		if name and not (issecretvalue and issecretvalue(name)) then
			trace("QuietHUD: " .. name .. " (" .. run.plan .. ")")
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
	-- Also kept in the trace, so it can be read from the saved-variables file after a /reload.
	local function say(msg)
		print(msg)
		DB.trace = DB.trace or {}
		DB.trace[#DB.trace + 1] = string.format("%.1f find: %s", GetTime(), tostring(msg))
	end
	say('QuietHUD: "' .. text .. '" is shown by (frame, then the frames that hold it):')
	for i = 1, math.min(#hits, 6) do
		say("  " .. hits[i].chain .. ' : "' .. hits[i].text:sub(1, 60) .. '"')
	end
	say("QuietHUD: to hide one, use /qhud add hidden <a frame name from the list>")
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
	print('QuietHUD: nothing on screen contains "' .. text .. '" right now. Watching for 30 minutes, I will report when it shows up.')
	if not (C_Timer and C_Timer.NewTicker) then return end
	local tries = 0
	finder = C_Timer.NewTicker(1, function(ticker)
		tries = tries + 1
		local found = scanForText(text)
		if #found > 0 then
			ticker:Cancel()
			finder = nil
			reportHits(text, found)
		elseif tries >= 1800 then
			ticker:Cancel()
			finder = nil
			print('QuietHUD: stopped watching for "' .. text .. '"')
		end
	end)
end

-- Events
-- /qhud mouse: for each right-click, prints the frame that received it, what it is like, and whether the camera started
-- to turn. For finding out what takes a right-click that should turn the camera. The setting survives a reload.
local mouseRegistered = false
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
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
pcall(ev.RegisterEvent, ev, "VARIABLES_LOADED")
pcall(ev.RegisterEvent, ev, "PLAYER_STARTED_MOVING")
pcall(ev.RegisterEvent, ev, "SUPER_TRACKING_CHANGED")

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
applyMouseWatch = function()
	if DB.watchMouse and not mouseRegistered then
		mouseRegistered = pcall(ev.RegisterEvent, ev, "GLOBAL_MOUSE_DOWN")
	elseif not DB.watchMouse and mouseRegistered then
		pcall(ev.UnregisterEvent, ev, "GLOBAL_MOUSE_DOWN")
		mouseRegistered = false
	end
end
applyMouseWatch()

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
		pcall(restoreShift)
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
	elseif event == "GLOBAL_MOUSE_DOWN" then
		if DB.watchMouse and arg1 == "RightButton" then reportRightClick() end
	elseif event == "PLAYER_REGEN_DISABLED" then
		if DB.inCombat then drawn = true end
	elseif event == "PLAYER_REGEN_ENABLED" then
		combatEnd = GetTime() + (DB.linger or 4)
		run.combatWarned = false
		armEntry()
	elseif event == "PLAYER_STARTED_MOVING" then
		moveUntil = GetTime() + MOVE_LINGER
	elseif event == "SUPER_TRACKING_CHANGED" then
		-- The game re-tracks quests by itself when one makes progress. That is not a choice, so the quest key stays on the
		-- one you picked. Any other change is you clicking a quest, and the key follows it.
		if not (run.pinned and run.progressAt and GetTime() - run.progressAt < 1.5) then run.pinned = highlightedQuestID() end
	elseif kindOf[event] == "quest" then
		questUntil = GetTime() + (DB.questSeconds or 10)
		if event == "QUEST_WATCH_UPDATE" or event == "UI_INFO_MESSAGE" then run.progressAt = GetTime() end
		if (event == "QUEST_REMOVED" or event == "QUEST_TURNED_IN") and arg1 == run.pinned then run.pinned = nil end
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
BINDING_NAME_QUIETHUD_PEEK = "Hold to show the whole HUD"
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
			print(string.format("QuietHUD minimap: trigger number=%s, Minimap shown=%s, alpha=%s, walking speed=%s, moving detected by=%s, moving window left=%.1fs, zone-change window=%s, indoors=%s, in %s / %s",
				tostring(DB.trigMap), tostring(Minimap and Minimap:IsShown()), alpha("Minimap"), speedText,
				lastMoveReason, math.max(0, moveUntil - GetTime()), tostring(GetTime() < mapUntil),
				tostring(IsIndoors and IsIndoors() or false), tostring(GetZoneText()), tostring(GetSubZoneText())))
				print("QuietHUD minimap area (remembered): " .. (mapRect and string.format("%.0f,%.0f to %.0f,%.0f", mapRect[1], mapRect[2], mapRect[3], mapRect[4]) or "nothing yet")
					.. ", mouse over it now: " .. tostring(mouseInMapRect()))
		end)
		if not ok then print("QuietHUD: could not read the state (" .. tostring(err) .. ")") end
	elseif cmd == "instance" then
		local ok, line = pcall(function()
			local inside, kind = IsInInstance()
			return "IsInInstance = " .. tostring(inside) .. ", " .. tostring(kind) .. ", counts as a dungeon or raid: "
				.. tostring(inDungeonOrRaid())
		end)
		print("QuietHUD: " .. (ok and line or "could not read the instance state"))
	elseif cmd == "bars" then
		print("QuietHUD action bar frames found: " .. table.concat(discovered, ", "))
	elseif cmd == "where" then
		-- Prints the frame under the mouse and the frames that hold it. With a number, waits that many seconds first,
		-- so the mouse can be moved onto a frame after the command is typed.
		local function report()
			local frame
			if GetMouseFoci then
				local list = GetMouseFoci()
				frame = list and list[1]
			elseif GetMouseFocus then
				frame = GetMouseFocus()
			end
			if not frame then
				print("QuietHUD: nothing is under the mouse")
			else
				print("QuietHUD: under the mouse: " .. frameChain(frame) .. "  (frame names you can use are the words that are not in <angle brackets>)")
			end
		end
		local delay = tonumber(rest)
		if delay and delay > 0 and C_Timer and C_Timer.After then
			print("QuietHUD: move the mouse onto the frame now, reporting in " .. delay .. " seconds")
			C_Timer.After(delay, report)
		else
			report()
		end
	elseif cmd == "mouse" then
		DB.watchMouse = not DB.watchMouse
		applyMouseWatch()
		if DB.watchMouse and not mouseRegistered then
			DB.watchMouse = false
			print("QuietHUD: this client does not tell addons about mouse presses. Use /qhud where 6 instead and leave the mouse where the camera will not turn")
		else
			persistSoon()
			print(DB.watchMouse and "QuietHUD: watching right-clicks, and it stays on after a reload. It says nothing while the camera works; when a right-click is taken by something else it prints what. /qhud mouse again stops" or "QuietHUD: stopped watching right-clicks")
		end
	elseif cmd == "peek" then
		-- The "hold to show" key sends "down" when it is pressed and "up" when it is released. Typed without either, it toggles.
		-- It runs out after two minutes, so a key release the game never saw (focus lost) cannot leave the HUD stuck on.
		local peekNow = GetTime()
		if rest == "down" then
			peekUntil = peekNow + 120
		elseif rest == "up" then
			peekUntil = 0
		else
			peekUntil = peekNow < peekUntil and 0 or peekNow + 120
		end
	elseif cmd == "shift" then
		if rest == "on" or rest == "off" then
			DB.pixelShift = (rest == "on")
			persistSoon()
			print("QuietHUD: pixel shift is " .. (DB.pixelShift and "on" or "off, and the frames go back where they were (out of combat)"))
		elseif rest == "now" then
			shiftNow()
			print("QuietHUD: pixel shift moves on to its next position within a second")
		else
			shiftReport()
		end
	elseif cmd == "arrow" then
		navForce = not navForce
		print("QuietHUD: the nav group (the arrow) is now " .. (navForce and "kept ON until you use /qhud arrow again" or "back to its automatic behavior"))
	elseif cmd == "nav" then
		print("QuietHUD nav group: " .. (#LISTS.nav == 0 and "empty, add a frame with /qhud add nav <frame name>" or table.concat(LISTS.nav, ", ")))
		for _, name in ipairs(LISTS.nav) do
			local f = _G[name]
			if not f then
				print("  " .. name .. ": there is no frame with that name (yet)")
			else
				local rec = navHosts[f]
				local okP, parent = pcall(f.GetParent, f)
				local parentName = (okP and parent and (parent.GetName and parent:GetName() or "<unnamed>")) or "?"
				print(string.format("  %s: moved into our container=%s, parent=%s, own opacity %.2f, container opacity %s, effective opacity %.2f, shown=%s",
					name, tostring(rec ~= nil), tostring(parentName), f:GetAlpha(), rec and string.format("%.2f", rec.host:GetAlpha()) or "n/a",
					f:GetEffectiveAlpha(), tostring(f:IsShown())))
			end
		end
		if navLastError then print("QuietHUD: the last problem moving a frame into the container: " .. navLastError) end
	elseif cmd == "alpha" then
		local name, value = rest:match("^(%S+)%s+([%d%.]+)$")
		local frame = name and _G[name]
		if frame and frame.SetAlpha and tonumber(value) then
			frame:SetAlpha(tonumber(value))
			print("QuietHUD: " .. name .. " opacity set to " .. value .. " (it stays until something fades it again, or a reload)")
		else
			print("QuietHUD: usage /qhud alpha <frame name> <0 to 1>, for example /qhud alpha Minimap 0.6")
		end
	elseif cmd == "chain" then
		local frame = rest ~= "" and _G[rest] or nil
		print("QuietHUD: " .. (frame and frameChain(frame) or "usage /qhud chain <frame name>, for example /qhud chain Minimap"))
	elseif cmd == "hotkeys" then
		-- Lists hotkey text with a modifier first (those are the long ones), and keeps the lines in the trace too.
		local function say(msg)
			print(msg)
			DB.trace = DB.trace or {}
			DB.trace[#DB.trace + 1] = string.format("%.1f hotkeys: %s", GetTime(), msg)
		end
		local found = {}
		for i = 1, #BAR_DEFS do
			for j = 1, 12 do
				local name = BAR_DEFS[i].buttons .. j .. "HotKey"
				local fs = _G[name]
				if fs then
					local ok, text = pcall(fs.GetText, fs)
					if ok and type(text) == "string" and text ~= "" and not (issecretvalue and issecretvalue(text)) then
						local rec = shortened[fs]
						local original = rec and rec.orig or text
						found[#found + 1] = { name = name, original = original, text = text, width = fs:GetWidth(),
							modifier = original:find("[%-%+]") ~= nil }
					end
				end
			end
		end
		for _, set in ipairs(EXTRA_BUTTONS) do
			for j = 1, set[2] do
				local name = set[1] .. j .. "HotKey"
				local fs = _G[name]
				if fs then
					local ok, text = pcall(fs.GetText, fs)
					if ok and type(text) == "string" and text ~= "" and not (issecretvalue and issecretvalue(text)) then
						local rec = shortened[fs]
						local original = rec and rec.orig or text
						found[#found + 1] = { name = name, original = original, text = text, width = fs:GetWidth(),
							modifier = original:find("[%-%+]") ~= nil }
					end
				end
			end
		end
		table.sort(found, function(a, b)
			if a.modifier ~= b.modifier then return a.modifier end
			return a.name < b.name
		end)
		say(string.format("QuietHUD hotkeys: shortening is %s, %d button(s) with hotkey text", DB.shortHotkeys and "ON" or "OFF", #found))
		for i = 1, math.min(#found, 10) do
			local f = found[i]
			say(string.format('  %s: the game says "%s", it shows "%s", the rules give "%s", width %.0f', f.name, f.original,
				f.text, shortHotkey(f.original), f.width))
		end
		if #found == 0 then say("QuietHUD: no hotkey text found on the action bars") end	elseif cmd == "methods" then
		local name, filter = rest:match("^(%S*)%s*(.-)%s*$")
		local frame = name ~= "" and _G[name] or nil
		local meta = frame and getmetatable(frame)
		local index = meta and meta.__index
		if type(index) ~= "table" then
			print("QuietHUD: usage /qhud methods <frame name> [part of a method name], for example /qhud methods Minimap texture")
		else
			local found = {}
			for key in pairs(index) do
				if type(key) == "string" and (filter == "" or key:lower():find(filter:lower(), 1, true)) then
					found[#found + 1] = key
				end
			end
			table.sort(found)
			print("QuietHUD: " .. #found .. " method(s) of " .. name .. (filter ~= "" and (' matching "' .. filter .. '"') or "")
				.. ": " .. table.concat(found, ", "))
		end
	elseif cmd == "around" then
		-- Lists the frames and background images that sit over the same area as a frame, to find things like the
		-- background box of a chat window. Everything printed is also kept in the trace (read after a /reload).
		local function say(msg)
			print(msg)
			DB.trace = DB.trace or {}
			DB.trace[#DB.trace + 1] = string.format("%.1f around: %s", GetTime(), tostring(msg))
		end
		local target = rest ~= "" and _G[rest] or nil
		if not (target and target.GetRect) then
			print("QuietHUD: usage /qhud around <frame name>, for example /qhud around ChattynatorHyperlinkHandler")
		else
			local function rectOf(object)
				if object.GetScaledRect then return object:GetScaledRect() end
				return object:GetRect()
			end
			local L, B, W, H = rectOf(target)
			if not L then
				print("QuietHUD: that frame has no position on the screen right now")
			else
				local area = W * H
				local function overlap(l, b, w, h)
					local x = math.max(0, math.min(L + W, l + w) - math.max(L, l))
					local y = math.max(0, math.min(B + H, b + h) - math.max(B, b))
					return x * y
				end
				local found = {}
				local frame = EnumerateFrames()
				while frame do
					pcall(function()
						if (frame.IsForbidden and frame:IsForbidden()) or not frame:IsVisible() then return end
						if frame ~= target then
							local l, b, w, h = rectOf(frame)
							if l and w > 0 and h > 0 and overlap(l, b, w, h) >= 0.6 * area and w * h <= 3 * area then
								found[#found + 1] = { size = w * h, text = string.format("frame  %s  (%.0fx%.0f, strata %s, level %d, alpha %.2f)",
									frameChain(frame), w, h, tostring(frame:GetFrameStrata()), frame:GetFrameLevel(), frame:GetAlpha()) }
							end
						end
						for _, region in ipairs({ frame:GetRegions() }) do
							if region.GetObjectType and region:GetObjectType() == "Texture" and region:IsVisible() then
								local l, b, w, h = rectOf(region)
								if l and w > 0 and h > 0 and overlap(l, b, w, h) >= 0.6 * area and w * h <= 3 * area then
									local okColor, r, g, bl, a = pcall(region.GetVertexColor, region)
									found[#found + 1] = { size = w * h, text = string.format("texture on  %s  (%.0fx%.0f, layer %s, alpha %.2f, colour %s)",
										frameChain(frame), w, h, tostring(region:GetDrawLayer()), region:GetAlpha(),
										okColor and string.format("%.2f/%.2f/%.2f/%.2f", r or 0, g or 0, bl or 0, a or 0) or "?") }
								end
							end
						end
					end)
					frame = EnumerateFrames(frame)
				end
				table.sort(found, function(x, y) return math.abs(x.size - area) < math.abs(y.size - area) end)
				say(string.format("QuietHUD around %s (%.0fx%.0f): %d frame(s) or image(s) cover the same area", rest, W, H, #found))
				for i = 1, math.min(#found, 14) do say("  " .. found[i].text) end
			end
		end
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
			print("QuietHUD: usage /qhud add bars|player|hud|quest|map|chat|nav|rxp|shift|hidden [frame name] (or hover the frame first)")
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
		print("QuietHUD: /qhud (menu), toggle, peek, shift, reset, target, quest, map, chat, bars, instance, state, debug, where, hotkeys, arrow, nav, mouse, alpha <frame> <0-1>, chain <frame>, around <frame>, find <text>, methods <frame> [text], add <group> [name], remove <name>, list")
	end
end
