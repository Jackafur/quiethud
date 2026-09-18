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
	player = { "PlayerFrame" },
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

local function isMoving()
	local speed = GetUnitSpeed("player")
	if issecretvalue and issecretvalue(speed) then return false end
	return (speed or 0) > 0
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
			if edit or (g == "chat" and not DB.chatDim) then peak = 1 end
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
		Minimap:SetShown(wantMinimap)
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
	{ title = "Extras", items = {
		{ "slider", "chatSeconds", "Chat stays after a message (seconds)", 2, 30, 1, "%.0f" },
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
		tab:SetSize(80, 22)
		tab:SetPoint("TOPLEFT", 12 + (i - 1) * 86, -36)
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

local function tooltipMentions(unit, needles)
	local ok, found = pcall(function()
		local data = C_TooltipInfo.GetUnit(unit)
		if not data or not data.lines then return false end
		for _, line in ipairs(data.lines) do
			local text = line.leftText
			if type(text) == "string" then
				for _, needle in ipairs(needles) do
					if text:find(needle, 1, true) then return true end
				end
			end
		end
		return false
	end)
	return ok and found
end

local function isQuestUnit(unit, names, needles)
	local n = UnitName(unit)
	if n and names[singular(n)] then return true end
	if C_TooltipInfo and C_TooltipInfo.GetUnit then
		return #needles > 0 and tooltipMentions(unit, needles) and true or false
	end
	-- Only clients without the tooltip API fall back to the game's looser "related to a quest" flag.
	if C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest then
		local ok, related = pcall(C_QuestLog.UnitIsRelatedToActiveQuest, unit)
		return ok and related and true or false
	end
	return false
end

-- Looks through the visible enemy nameplates for a quest mob before any Tab is pressed, so nothing is targeted
-- or marked when there is none. Returns true or false, or nil when there are no nameplates to look at (for
-- example when enemy nameplates are turned off), in which case the caller just runs the Tab chain.
local function questMobNearby(names, needles)
	if not (C_NamePlate and C_NamePlate.GetNamePlates) then return nil end
	local ok, plates = pcall(C_NamePlate.GetNamePlates)
	if not ok or type(plates) ~= "table" or #plates == 0 then return nil end
	for _, plate in ipairs(plates) do
		local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
		if unit then
			local okUnit, mob = pcall(function()
				if not UnitCanAttack("player", unit) or UnitIsDead(unit) then return false end
				if UnitIsTapDenied and UnitIsTapDenied(unit) then return false end
				return isQuestUnit(unit, names, needles)
			end)
			if okUnit and mob then return true end
		end
	end
	return false
end

-- Quest-mob targeting works like Tab, restricted to quest mobs. Addons cannot change the target, and the
-- unit IDs of nameplates cannot be targeted by commands, so a key press clicks a secure button that presses
-- Tab (/targetenemy) and then clicks a chain of secure step buttons. The PreClick of each step checks the new
-- target and either finishes with the skull or sets the macro for one more Tab step, all within one key press.
local STEP_MAX = 16

-- A macro's /click sends an up click by default, but a secure button only acts on the phase that matches the
-- ActionButtonUseKeyDown setting. Sending both a down and an up click makes it work either way.
local function clickStep(n)
	return "/click QuietHUDStep" .. n .. " LeftButton 1\n/click QuietHUDStep" .. n .. " LeftButton 0"
end

local function dbgLine(msg)
	if not debugOn then return nil end
	return '/run print("QuietHUD: ' .. msg .. '")'
end

local function joinLines(...)
	local t = {}
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if v and v ~= "" then t[#t + 1] = v end
	end
	return table.concat(t, "\n")
end

local run = { active = false, depth = 0, startGUID = nil, names = {}, needles = {}, found = nil }

local function targetIsQuestMob()
	if not UnitExists("target") or not UnitCanAttack("player", "target") or UnitIsDead("target") then
		return false
	end
	if UnitIsTapDenied and UnitIsTapDenied("target") then return false end
	return isQuestUnit("target", run.names, run.needles)
end

for i = 1, STEP_MAX do
	local step = CreateFrame("Button", "QuietHUDStep" .. i, UIParent, "SecureActionButtonTemplate")
	step:SetAttribute("type", "macro")
	step:SetAttribute("macrotext", "")
	step:RegisterForClicks("AnyDown", "AnyUp")
	step:SetScript("PreClick", function(self, _, down)
		if not run.active or InCombatLockdown() then return end
		run.depth = i
		local ok, quest = pcall(targetIsQuestMob)
		local okGuid, guid = pcall(UnitGUID, "target")
		local backAtStart = okGuid and guid ~= nil and guid == run.startGUID
		if debugOn then
			print(string.format("QuietHUD step %d (%s click): target=%s quest=%s", i, down and "down" or "up",
				tostring(UnitName("target")), tostring(ok and quest)))
		end
		local text
		if ok and quest then
			run.found = UnitName("target") or "?"
			run.active = false
			text = joinLines(dbgLine("step " .. i .. " macro ran (found)"))
		elseif i >= STEP_MAX or backAtStart or not UnitExists("target") then
			run.active = false
			text = joinLines("/cleartarget", dbgLine("step " .. i .. " macro ran (gave up)"))
		else
			text = joinLines("/targetenemy", clickStep(i + 1), dbgLine("step " .. i .. " macro ran (tab)"))
		end
		self:SetAttribute("macrotext", text)
	end)
end

local targetButton = CreateFrame("Button", "QuietHUDTargetButton", UIParent, "SecureActionButtonTemplate")
targetButton:SetAttribute("type", "macro")
targetButton:SetAttribute("macrotext", "")
targetButton:RegisterForClicks("AnyDown", "AnyUp")

-- The game locks addon changes to secure buttons during combat, so the button is kept armed with a plain Tab
-- and the skull (when the feature is on). Out of combat every press replaces it with the smart quest chain.
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
	local ok, names, needles = pcall(questNames, highlightedQuestID())
	if not ok then
		self:SetAttribute("macrotext", "")
		print("QuietHUD: could not read your quests just now")
		return
	end
	if questMobNearby(names, needles) == false then
		self:SetAttribute("macrotext", "")
		print("QuietHUD: no quest mob found among the nearby enemies")
		return
	end
	run.active, run.depth, run.found = true, 0, nil
	run.names, run.needles = names, needles
	local okGuid, guid = pcall(UnitGUID, "target")
	run.startGUID = okGuid and guid or nil
	self:SetAttribute("macrotext", joinLines("/targetenemy", clickStep(1), "/tm 0", "/tm " .. SKULL,
		debugOn and '/run print("QuietHUD: entry macro finished, mark on target is "..tostring(GetRaidTargetIndex("target")))' or nil))
end)

targetButton:SetScript("PostClick", function(self, _, down)
	if not InCombatLockdown() then
		for i = 1, STEP_MAX do
			local s = _G["QuietHUDStep" .. i]
			if s then s:SetAttribute("macrotext", "") end
		end
		armEntry()
	end
	if isActionClick(down) and run.depth > 0 then
		if run.found then
			print(string.format("QuietHUD: quest mob %s (after %d Tab step%s)", run.found, run.depth,
				run.depth == 1 and "" or "s"))
		else
			print("QuietHUD: no quest mob found among the nearby enemies")
		end
	end
	if debugOn and isActionClick(down) and C_Timer and C_Timer.After then
		C_Timer.After(0.3, function()
			print("QuietHUD: raid mark on the target is " .. tostring(GetRaidTargetIndex("target")))
		end)
	end
	run.active = false
	run.depth = 0
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

-- Events
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
pcall(ev.RegisterEvent, ev, "VARIABLES_LOADED")
local kindOf = {}
for _, e in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "QUEST_WATCH_UPDATE", "UI_INFO_MESSAGE" }) do
	kindOf[e] = "quest"
end
for _, e in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }) do
	kindOf[e] = "map"
end
for _, e in ipairs({
	"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_WHISPER",
	"CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM", "CHAT_MSG_PARTY",
	"CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
	"CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
	"CHAT_MSG_CHANNEL", "CHAT_MSG_SYSTEM", "CHAT_MSG_LOOT", "CHAT_MSG_MONEY", "CHAT_MSG_COMBAT_XP_GAIN",
	"CHAT_MSG_COMBAT_FACTION_CHANGE", "CHAT_MSG_SKILL", "CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL",
	"CHAT_MSG_MONSTER_EMOTE", "CHAT_MSG_MONSTER_WHISPER", "CHAT_MSG_AFK", "CHAT_MSG_DND",
	"CHAT_MSG_ACHIEVEMENT", "CHAT_MSG_GUILD_ACHIEVEMENT",
}) do
	kindOf[e] = "chat"
end
for e in pairs(kindOf) do pcall(ev.RegisterEvent, ev, e) end

ev:SetScript("OnEvent", function(_, event, arg1)
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
	elseif kindOf[event] == "quest" then
		questUntil = GetTime() + (DB.questSeconds or 10)
	elseif kindOf[event] == "map" then
		mapUntil = GetTime() + (DB.questSeconds or 10)
	elseif kindOf[event] == "chat" then
		bumpChat()
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
		print("QuietHUD debug " .. (debugOn and "on" or "off") .. ", ToggleSheath hooked: " .. tostring(hooked)
			.. ", sheath key: " .. tostring((GetBindingKey("TOGGLESHEATH"))) .. ", HUD drawn state: " .. tostring(drawn))
	elseif cmd == "state" then
		local ok, err = pcall(function()
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
	elseif cmd == "add" then
		local group = rest:lower()
		local name = frameUnderMouse()
		local valid = false
		for _, g in ipairs(EXTRA_GROUPS) do
			if g == group then valid = true end
		end
		if not valid then
			print("QuietHUD: usage /qhud add bars|player|hud|quest|map|hidden (hover the frame first)")
		elseif not name then
			print("QuietHUD: no named frame under the mouse")
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
		print("QuietHUD: /qhud (menu), toggle, reset, target, quest, map, chat, bars, instance, state, debug, where, add <group>, remove <name>, list")
	end
end
