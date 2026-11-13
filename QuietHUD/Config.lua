-- The settings window (/qhud): its pages, the trigger grid, the sliders and boxes, and QuietHUD's page in the game's AddOns
-- options.
local ADDON, ns = ...
local DEFAULTS, SPLIT, SPLIT_BY = ns.DEFAULTS, ns.SPLIT, ns.SPLIT_BY
local BAR_DEFS, CHAT_KINDS = ns.BAR_DEFS, ns.CHAT_KINDS
local DB, gFade, gTrig, woc, wakeLoop, rebuildLists = ns.DB, ns.gFade, ns.gTrig, ns.woc, ns.wakeLoop, ns.rebuildLists
local settingChanged = ns.settingChanged
local barBit = ns.barBit
local T = ns.T
local resetBagPosition = ns.resetBagPosition

-- The settings window's layout. width is the least it is (it grows when the tabs need more room); the grid is the trigger grid
-- (the Fade column, the first trigger column and the distance between columns); the columns are the two columns of sliders on
-- the Opacity page (where the right one starts, and the width of a name and of a slider).
local WIN = { width = 720, gridFade = 156, gridFirst = 206, gridPitch = 56, gridPairPitch = 56, gridGap = 10, col2 = 330, labelW = 128,
	sliderW = 108 }

-- Hover help: what each trigger column means (by its bit, and the Fade column), and what each element is (by its name, the
-- same on the Elements grid and the Opacity page).
local HELP = {
	cols = {
		fade = "Ticked: it fades when nothing shows it. Unticked: it never fades and stays at its opacity from the Opacity page (fully solid on Global).",
		[7] = "Shown in a fight, and for a few seconds after (how long is set on the Show when page). Ticking it unticks Hide in combat.",
		[5] = "Gone completely in a fight, whatever else is ticked and whatever the Faded opacity is. Leaving Show in combat empty is not the same: then moving or mouse over can still show it mid-fight. Ticking it unticks Show in combat.",
		[8] = "Shown while your weapon or your wand is drawn, so the sheath key works as a switch for it.",
		[9] = "Shown while you have a target.",
		[10] = "Shown while you move the mouse or turn the camera with it, and for a few seconds after (how long is set on the Show when page).",
		[2] = "Shown while you move, and for a moment after you stop.",
		[3] = "Shown for a while when there is something new: quest progress for the tracker and RestedXP, a chat message for the chat, a new zone for the minimap. How long is set on the Show when page (the Chat page for the chat).",
		[4] = "Shown while your mouse is over it. For mouse over only, leave just this box ticked.",
		[6] = "Shown while you are inside a dungeon or a raid.",
	},
	rows = {
		["Controller bar"] = "The controller's action bar, in place of Action Bar 1. The Controller rows are only listed while a controller is enabled in the game's options (reload after switching it on). Each started as a copy of the Action bars row.",
		["Aiming dot"] = "The dot in the middle of the screen in controller mode.",
		["Button reminder"] = "The box at the top left in controller mode: LB/RB targeting, Ping, Auto-Run, and the lists it shows while you hold LB or RB.",
		["Pet bar"] = "The pet bar, also its buttons on a WackyBars bar. Untick every box after Fade to keep it faded; with the Global Faded at 0 it is hidden (tick its Click through on the Action bars page, or a click there still presses a pet button).",
		["Action bars"] = "Action Bars 1 to 8, plus the stance, totem and XP bars. Which bars fade is picked on the Action bars page. With Dominos loaded, Dominos hides the game's bars and its own are on the Dominos row: this row then only has what Dominos leaves, like the totem bar.",
		["Dominos"] = "Dominos' bars in one row: its action bars, pet, stance and possess bars, XP bar, bag bar and menu. It starts as a copy of the Action bars row; after that the two are separate. Best with Dominos' own fade off, so the two don't fight.",
		["Bags bar"] = "The row of bag buttons. With Dominos loaded, Dominos hides it and its own bag bar is on the Dominos row.",
		["Menu bar"] = "The row of small menu buttons (character, spellbook, talents and so on). With Dominos loaded, Dominos hides it and its own menu is on the Dominos row: this row then only has the beta Issue Reporter button.",
		["Cast bar"] = "Your cast bar. It shows by itself while you cast, so it only has an opacity.",
		["Breath bar"] = "The breath, fatigue and feign death timer. It shows by itself while it runs, so it only has an opacity.",
		["Player frame"] = "Your own frame: portrait, health and power.",
		["Target and focus"] = "The target frame and the focus frame.",
		["Pet frame"] = "Your pet's frame, and its cast bar if BetterBlizzFrames adds one.",
		["Party and raid"] = "The party frames and the raid frames.",
		["Party panel"] = "The side panel that pops out of the arrow tab on the left of the screen (Party 1/1, markers, Leave Party). The Extras page can hide it completely.",
		["Buffs"] = "Your buffs, weapon enchants and totem timers.",
		["Debuffs"] = "Your debuffs. To keep them on the screen while your buffs fade, untick Fade for Debuffs on the Elements page.",
		["Cooldown trackers"] = "The game's cooldown manager: the essential and utility cooldowns, and the tracked buff icons and bars.",
		["Alerts"] = "The durability icon, the loss of control alert, external defensives and the game's \"world will refresh\" notice.",
		["Objective tracker"] = "The quest and objective tracker (Questie's tracker too).",
		["Chat"] = "The chat windows. Which messages show the chat is set on the Chat page. Typing always shows it.",
		["Minimap"] = "The minimap and the buttons around it.",
		["Damage meter"] = "The game's own damage meter.",
		["Added frames"] = "Frames you added yourself with /qhud add hud. Empty unless you did that.",
		["Spy"] = "Spy's window, the list of enemy players near you. New info: it comes up when Spy's alarm goes off. Spy's warning in the middle of the screen is never faded.",
		["Guide windows"] = "The RestedXP guide window and its targets and items windows.",
		["Arrow"] = "The RestedXP waypoint arrow.",
		["Guide window"] = "The RestedXP guide window.",
		["Targets, items"] = "The RestedXP targets and items windows. They come up with the guide window: its boxes on the row above count for them too.",
	},
}

-- The settings window's pages, in tab order (Elements first; Show when holds what goes with the Elements columns, under
-- headings named like them). An item with addon is only shown while that addon is loaded (RestedXP's section on Opacity).
-- The Show the whole HUD boxes on the Show when page: hold (left) or tap (right), one way at a time.
local PEEK = {
	holdKeys = { "peekAlt", "peekCtrl", "peekShift" },
	tapKeys = { "peekTapAlt", "peekTapCtrl", "peekTapShift" },
	holdHelp = "The whole HUD shows while you hold the key, and fades when you let go. Ticking it unticks the Tap boxes.",
	tapHelp = "Tap the key on its own and the whole HUD shows until you tap it again. Using it with another key or a click (Alt+1, Alt+click) does nothing to the HUD, so your keybinds work as normal. Ticking it unticks the While I hold boxes.",
}
local PAGES = {
	{ title = "Elements", items = {
		{ "grid", "elements" },
		{ "note", "Fade: it fades when nothing shows it. Any other ticked box shows it while that is true. Hover a heading or a name for more. The cast and breath bars are on the Opacity page." },
	} },
	{ title = "Show when", items = {
		{ "note", "What shows each element is ticked on the Elements page. These go with its columns of the same name." },
		-- (first on the page: the setting people look for most; the owner's yes, Nov 10)
		{ "heading", "Show the whole HUD on demand" },
		-- Hold on the left, Tap on the right: one way at a time, so ticking a box on one side unticks the other side's three.
		{ "check", "peekAlt", "While I hold Alt", PEEK.holdHelp, untick = PEEK.tapKeys,
			right = { "peekTapAlt", "Tap Alt to toggle", PEEK.tapHelp, untick = PEEK.holdKeys } },
		{ "check", "peekCtrl", "While I hold Ctrl", PEEK.holdHelp, untick = PEEK.tapKeys,
			right = { "peekTapCtrl", "Tap Ctrl to toggle", PEEK.tapHelp, untick = PEEK.holdKeys } },
		{ "check", "peekShift", "While I hold Shift", PEEK.holdHelp, untick = PEEK.tapKeys,
			right = { "peekTapShift", "Tap Shift to toggle", PEEK.tapHelp, untick = PEEK.holdKeys } },
		{ "note", "Or bind a key: Esc, Options, Keybindings, AddOns, QuietHUD (one to hold, one to toggle)." },
		{ "heading", "Show in combat" },
		{ "slider", "linger", "Stay shown after combat (seconds)", 0, 180, 1, "%.0f", nil, nil, "How long an element stays shown after a fight ends.", 420 },
		{ "heading", "Weapon drawn" },
		{ "check", "keepDrawn", "Keep my weapon drawn after spells, chests and crafting", "When the game puts your weapon away by itself (a buff, a chest, a lock, crafting, looting), QuietHUD draws it again as soon as the cast is over, so the HUD stays shown. You will see your character draw the weapon again. Pressing the sheath key still puts it away, and then Weapon drawn stops showing the HUD. Not while mounted, swimming, dead, on a flight path or in a fight." },
		{ "heading", "Mouse move" },
		{ "slider", "mouseSeconds", "Stay shown after the mouse stops (seconds)", 1, 60, 1, "%.0f", nil, nil, "How long an element stays shown after you stop moving the cursor, turning the camera or moving a controller stick.", 420 },
		{ "heading", "New info" },
		{ "slider", "questSeconds", "Stay shown after quest progress or a new zone (seconds)", 3, 180, 1, "%.0f", nil, nil, "How long the tracker, the minimap, RestedXP and Spy's window (after its alarm) stay shown after something new. The chat has its own on the Chat page.", 420 },
		{ "heading", "Player frame" },
		{ "check", "notFullShows", "Show the player frame while health or power is changing", "Shows the player frame only, while your health or your power bar goes up or down and for a few seconds after (3, or 8 for mana, which waits a moment before it comes back). In practice: until you are topped off. The game does not let addons read your health or power, so QuietHUD goes by them changing. Hide in combat on the Player frame row still wins in a fight." },
		{ "heading", "Fading out" },
		{ "slider", "fadeOutSeconds", "Fade out animation (seconds)", 0.1, 5, 0.05, "%.2f", nil, nil, "How long an element takes to fade out, whatever showed it. The chat has its own on the Chat page.", 420 },
	} },
	{ title = "Opacity", items = {
		{ "heading", "Global" },
		{ "slider", "base", "Shown", 0.1, 1, 0.05, "%.2f", nil, true, "How solid an element is while it is shown. Every element set to Global uses this, except one with Fade unticked on the Elements page: on Global that one is fully solid." },
		-- (the one Faded: every element fades to it)
		{ "slider", "idle", "Faded", 0, 1, 0.05, "%.2f", "Hidden", true, "How solid every element is while it is faded. 0 hides them completely. For an element that should stay at one level all the time, untick its Fade on the Elements page and set its value under Shown per element." },
		{ "heading", "Shown per element" },
		-- (a slider for every element goes here, in two columns: see below)
		{ "heading", "Windows" },
		{ "slider", "bagAlpha", "Open bag windows", 0, 1, 0.05, "%.2f", "Global", true, "Your open bags. To move them around, see Open bags on the Extras page." },
		{ "slider", "tooltipAlpha", "Tooltips", 0, 1, 0.05, "%.2f", "Global", true, "The game's tooltips, like this one." },
		-- (its Shown is the Minimap row under Shown per element)
		{ "heading", "Minimap" },
		{ "check", "mapDarken", "Darken the minimap instead of making it see-through", "Unticked (default): as the minimap fades it turns see-through. The little icons on it (your arrow, quest and party icons) stay bright, because the game does not let addons fade them.\nTicked: as the minimap fades it turns darker instead, and the icons darken with it." },
		{ "slider", "mapDarkFloor", "Darkened map's Faded", 0, 0.9, 0.05, "%.2f", "Global", true, "With Darken the minimap ticked: how bright the map stays while it is faded, so it does not turn into a black hole on the screen. Global (default): as dark as the Global Faded.\nOnly the map and the icons on it. The ring and buttons around it fade to the Global Faded. With the Global Faded at 0 the minimap still goes away when faded." },
		{ "slider", "mapCover", "Arrow cover", 0, 1, 0.05, "%.2f", "Off", true, "A small dark circle over the middle of the minimap while it is faded, to take the edge off your bright arrow (the game does not let addons fade the arrow itself). This sets how dark the circle is. Off (default): no circle." },
		{ "slider", "mapCoverSize", "Arrow cover size", 8, 48, 1, "%d", nil, true, "How big the circle is, to fit over your arrow." },
		{ "note", "Everything starts on Global. Hover a name for more." },
	} },
	{ title = "Action bars", items = {
		{ "bargrid" },
		{ "check", "mouseTogether", "Show Mouse over only bars together", "Ticked: the mouse on any bar with Mouse over only ticked shows every Mouse over only bar, not just that one. They fade back together when the mouse leaves.\nUnticked (default): each one comes up by itself." },
		{ "check", "shortHotkeys", "Shorten hotkey text (Num Pad 1 shows N1)" },
		-- (short lines at the bottom, one thought each: the owner, Nov 10, "just one long ass paragraph. make it simple")
		{ "note", "Hover a heading to see what it does." },
		{ "note", "These only count while Action bars has Fade ticked on the Elements page." },
		{ "note", "To hide a bar for good: untick it in /wbars (WackyBars), or in the game's Options, Action Bars." },
	} },
	{ title = "Chat", items = {
		-- (the boxes below are the chat's New info)
		{ "note", "These count while New info is ticked for the Chat on the Elements page." },
		{ "slider", "chatSeconds", "Chat stays shown after a message (seconds)", 2, 30, 1, "%.0f" },
		{ "slider", "chatFadeSeconds", "Chat fade out animation (seconds)", 0.3, 5, 0.1, "%.1f" },
		{ "kinds" },
	} },
	{ title = "Extras", items = {
		-- (first on the page: one of QuietHUD's two main jobs, the OLED panel; the owner's yes, Nov 10)
		{ "heading", "Pixel shift (OLED, experimental)" },
		{ "check", "pixelShift", "Move the minimap, tracker, chat and addon frames a little every few minutes", "The waypoint arrow is RestedXP's arrow or Naowh's navigator, when you use them. With a controller, the dot in the middle of the screen moves too. Distance and minutes below are for everything that moves." },
		{ "check", "shiftBars", "Also the action bars, bags and menu bar" },
		{ "check", "shiftUnits", "Also the player, target and party frames" },
		{ "slider", "shiftPixels", "Distance (pixels)", 1, 15, 1, "%.0f" },
		{ "slider", "shiftMinutes", "Minutes between moves", 1, 10, 1, "%.0f" },
		{ "heading", "Always hidden" },
		{ "check", "hideReporter", "Hide the beta Issue Reporter button" },
		{ "check", "hideMmButtons", "Hide other addons' minimap buttons" },
		{ "check", "hidePanel", "Hide the party panel (Party 1/1, markers, Leave Party)" },
		{ "heading", "Open bags" },
		{ "check", "moveBags", "Let me drag my open bags around" },
		{ "button", "Reset position", "bagPosition", "Puts your open bags back where the game places them." },
		{ "note", "Drag any open bag by its title bar; they move together. With BlizzMove, BlizzMove moves them." },
		{ "heading", "Quest-mob key (experimental)" },
		{ "check", "questTarget", "Enable quest-mob targeting key" },
		{ "note","Works like Tab, but only through the mobs your highlighted quest needs: each press goes to the next one. Needs enemy nameplates on (a kill objective can still be reached by name without). After ticking this, bind the key: Esc, Options, Keybindings, AddOns, QuietHUD, \"Target highlighted quest mob\"." },
	} },
	{ title = "About", items = {
		{ "about" },
		{ "heading", "Works with" },
		{ "note", "Dominos, Questie, RestedXP, Chattynator, ClassicUI Forever, BetterBlizzFrames, Animated Blizzard Portraits, Leatrix Plus and BlizzMove. QuietHUD handles their frames by itself." },
		{ "heading", "Something does not fade?" },
		{ "note", "Hover it and type /qhud add hud. It then fades with the Added frames row on the Elements page." },
	} },
}

-- The Opacity page has a slider for every element that can have its own opacity, in the groups of the Elements grid, in two
-- columns: the groups fill the left column until it holds about half of the sliders.
do
	local keyOf = { ["Objective tracker"] = "ovQuest", ["Chat"] = "chatOwn", ["Minimap"] = "mapOwn", ["Action bars"] = "ovBars",
		["Player frame"] = "ovPlayer", ["Bags bar"] = "ovBagsBar", ["Menu bar"] = "ovMicro", ["Added frames"] = "ovHud",
		["Guide windows"] = "rxpShown", ["Arrow"] = "navShown" }
	local addonOf = { ["Guide windows"] = "RXPGuides", ["Arrow"] = "RXPGuides" }
	local whenOf = {}
	for _, s in ipairs(SPLIT) do keyOf[s.label], addonOf[s.label], whenOf[s.label] = s.ovKey, s.addon, s.when end
	-- RestedXP's two come last, as its rows do on the Elements page, and only while it is loaded.
	local groups = {}
	for _, group in ipairs(SPLIT.groups) do groups[#groups + 1] = group end
	groups[#groups + 1] = { "RestedXP", { "Guide windows", "Arrow" }, addon = "RXPGuides" }
	local total, count, left, right = 0, 0, {}, {}
	-- The Shown bars: dragging one shows the whole HUD for a few seconds (see makeSlider). Not the Global Faded, whose look is
	-- the faded one.
	woc.previewKeys = { base = true }
	for _, key in pairs(keyOf) do woc.previewKeys[key] = true end
	-- (a row marked uncounted, Naowh's, does not move the split: the columns stay as they were with or without it)
	local uncounted = {}
	for _, s in ipairs(SPLIT) do uncounted[s.label] = s.uncounted end
	for _, group in ipairs(groups) do
		for _, label in ipairs(group[2]) do
			if not uncounted[label] then total = total + 1 end
		end
	end
	for _, group in ipairs(groups) do
		local column = count < total / 2 and left or right
		column[#column + 1] = { "group", group[1], addon = group.addon, when = group.when }
		for _, label in ipairs(group[2]) do
			-- (an addon's slider, Dominos', is left out while it is not loaded, as the page items are)
			column[#column + 1] = { "slider", keyOf[label], label, 0, 1, 0.05, "%.2f", "Global", "column", HELP.rows[label],
				addon = addonOf[label], when = whenOf[label] }
			if not uncounted[label] then count = count + 1 end
		end
	end
	for _, page in ipairs(PAGES) do
		for i, item in ipairs(page.items) do
			if item[1] == "heading" and item[2] == "Shown per element" then -- (the heading's text: rename both together)
				table.insert(page.items, i + 1, { "columns", left = left, right = right })
				break
			end
		end
	end
end
local config
local pages, tabs, controls = {}, {}, {}

local function syncControls()
	for _, fn in ipairs(controls) do fn() end
end

-- The settings window. Its helpers live in this block; the two that Commands.lua uses are declared here and set inside.
local resetDefaults, toggleConfig
do
	-- Hover help: a tooltip for a label, a heading or a control. Over text, a frame of its own catches the mouse; it only takes the
	-- mouse movement (as the game's cooldown viewer does), so a click or a drag there still reaches the window under it.
	local function addHelp(parent, region, title, text)
		if not text then return end
		local target = region
		if region.IsObjectType and region:IsObjectType("FontString") then
			target = CreateFrame("Frame", nil, parent)
			target:SetAllPoints(region)
			if target.SetMouseMotionEnabled and target.SetMouseClickEnabled then
				target:SetMouseClickEnabled(false)
				target:SetMouseMotionEnabled(true)
			else
				target:EnableMouse(true)
			end
		end
		target:HookScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(title, 1, 1, 1)
			GameTooltip:AddLine(type(text) == "function" and text() or text, 1, 0.82, 0, true) -- (a function: worked out now)
			GameTooltip:Show()
		end)
		target:HookScript("OnLeave", function() GameTooltip:Hide() end)
		return target
	end

	-- x: from the left (12 when not given); untick: setting keys that go off when this box is ticked (a pair that says
	-- opposite things, as the hold and tap boxes).
	local function makeCheck(parent, y, label, key, help, x, untick)
		local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
		check:SetPoint("TOPLEFT", x or 12, y)
		check:SetScript("OnClick", function(self)
			DB[key] = not DB[key]
			self:SetChecked(DB[key] and true or false)
			if DB[key] and untick then
				for _, k in ipairs(untick) do DB[k] = false end
			end
			-- (every box: the controls that depend on it follow, like the Action bars page's "Show with ..." column)
			for _, refresh in ipairs(controls) do refresh() end
			settingChanged()
			rebuildLists()
			if ns.armEntry then ns.armEntry() end
		end)
		local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		text:SetPoint("LEFT", check, "RIGHT", 4, 0)
		text:SetText(label)
		addHelp(parent, check, label, help)
		addHelp(parent, text, label, help)
		controls[#controls + 1] = function() check:SetChecked(DB[key] and true or false) end
		controls[#controls]()
		return check, text
	end

	-- A slider that stands for more than one stored setting. The chat opacity is "Global" (chatDim) or a number (chatOpacity):
	-- two settings, one control.
	local VIRTUAL = {
		chatOwn = {
			get = function() return DB.chatDim and 0 or (DB.chatOpacity or 1) end,
			set = function(v)
				if v <= 0 then
					DB.chatDim = true
				else
					DB.chatDim, DB.chatOpacity = false, math.max(v, 0.1)
				end
			end,
		},
		-- The minimap's Shown: Global (mapFollowsHud, the default) or a number (ovMap).
		mapOwn = {
			get = function() return DB.mapFollowsHud and 0 or ((DB.ovMap or 0) > 0 and DB.ovMap or 1) end,
			set = function(v)
				if v <= 0 then
					DB.mapFollowsHud, DB.ovMap = true, 0
				else
					DB.mapFollowsHud, DB.ovMap = false, math.max(v, 0.1)
				end
			end,
		},
	}
	-- A row that follows another until it has a setting of its own (Dominos): its Shown slider shows the followed one's.
	for _, s in ipairs(SPLIT) do
		if s.follows then
			VIRTUAL[s.ovKey] = {
				get = function()
					local v = DB[s.ovKey]
					if v == nil then v = DB[s.follows[3]] end
					return v or 0
				end,
				set = function(v) DB[s.ovKey] = v end,
				follows = true, -- (while DB[s.ovKey] is nil it shows the followed row's value)
			}
		end
	end

	-- compact puts the label to the left of the slider on one short row (the Opacity page), instead of above it. compact "column" is
	-- a narrower row in one of the two columns of the Opacity page (x is where the column starts): the name is white and indented
	-- under its group heading, like the rows of the Elements grid. help is the tooltip of the name.
	local function makeSlider(parent, y, label, key, minV, maxV, stepV, fmt, zeroText, compact, x, help, width)
		x = x or 0
		local column = compact == "column"
		local title = parent:CreateFontString(nil, "OVERLAY", column and "GameFontHighlight" or "GameFontNormal")
		title:SetPoint("TOPLEFT", (column and 24 or 16) + x, compact and (y - 1) or y)
		if compact then
			title:SetWidth(column and WIN.labelW or 200)
			title:SetJustifyH("LEFT")
			title:SetWordWrap(false)
		end
		title:SetText(label)
		addHelp(parent, title, label, help)
		local s = CreateFrame("Slider", nil, parent)
		if column then
			s:SetPoint("TOPLEFT", 24 + x + WIN.labelW + 6, y - 1)
			s:SetSize(WIN.sliderW, 16)
		elseif compact then
			s:SetPoint("TOPLEFT", 232, y - 1)
			s:SetSize(200, 16)
		else
			s:SetPoint("TOPLEFT", 16, y - 22)
			s:SetSize(width or 220, 16) -- (a long range gets a wider bar, so one second is more than a pixel)
		end
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
			-- The mouse can drift off the thin bar while you drag, so the check is generous: 80 units above, below and to the sides.
			local okOver, over = pcall(self.IsMouseOver, self, 80, -80, -80, 80)
			local dragging = IsMouseButtonDown and IsMouseButtonDown("LeftButton") and (over or (not okOver and self:IsMouseOver()))
			if not dragging then return end
			val = math.floor(val / stepV + 0.5) * stepV
			-- An element's own Shown stops at the Global Faded: below it the element would never fade (the lower one wins).
			-- Global, at the far left, is always allowed.
			-- Only for a row that fades: with Fade unticked its bar is a fixed level, and any level is fine.
			local snapped = false
			local fades = woc.fadeFlags()
			if key ~= "base" and woc.previewKeys and woc.previewKeys[key] and fades[woc.groupOfKey[key]]
				and val > 0 and val < (DB.idle or 0) - 0.001 then
				val, snapped = DB.idle, true
			end
			if VIRTUAL[key] then VIRTUAL[key].set(val) else DB[key] = val end
			readout:SetText((zeroText and val == 0) and zeroText or string.format(fmt, val))
			-- (a Shown bar shows the HUD while it is dragged and 3 seconds after, so the change can be seen: standing still with
			-- the window open, most of the HUD is faded)
			if woc.previewKeys and woc.previewKeys[key] then
				ns.peekUntil = math.max(ns.peekUntil, GetTime() + 3)
				ns.previewUntil = ns.peekUntil -- (every bar, a Show with one too: the one being set is seen)
				wakeLoop()
			end
			-- Idle can never be brighter than shown: dragging one past the other carries the other with it.
			local carried = snapped
			if key == "idle" and val > (DB.base or 0) + 0.001 then
				DB.base, carried = val, true
			elseif key == "base" and val < (DB.idle or 0) - 0.001 then
				DB.idle, carried = val, true
			end
			-- (and the Global Faded raised past an element's own Shown carries that one up with it)
			if key == "idle" and woc.previewKeys then
				for k in pairs(woc.previewKeys) do
					-- (not a row that still follows another, Dominos': pulling it would split it off)
					if k ~= "base" and fades[woc.groupOfKey[k]] and not (VIRTUAL[k] and VIRTUAL[k].follows and DB[k] == nil) then
						local v = VIRTUAL[k] and VIRTUAL[k].get() or DB[k]
						if type(v) == "number" and v > 0 and v < val - 0.001 then
							if VIRTUAL[k] then VIRTUAL[k].set(val) else DB[k] = val end
							carried = true
						end
					end
				end
			end
			settingChanged()
			if carried then syncControls() end
		end)
		controls[#controls + 1] = function()
			local v = VIRTUAL[key] and VIRTUAL[key].get() or DB[key]
			if v == nil then v = minV end
			s:SetValue(v)
			readout:SetText((zeroText and v == 0) and zeroText or string.format(fmt, v))
		end
		controls[#controls]()
	end

	local CELL = 24 -- the size of a tick box in the grids (the Action bars page and the Elements page look the same)

	-- What a grid box shows and starts from: the setting, or for a row with none of its own that follows another (Dominos,
	-- until it copies Action bars) what it follows, as gTrig and gFade do. A click then saves the row's own.
	local effective
	do
		local splitOf = {}
		for _, s in ipairs(SPLIT) do splitOf[s.trigKey], splitOf[s.fadeKey] = s, s end
		effective = function(key)
			local s = splitOf[key]
			if not s then return DB[key] end
			if key == s.trigKey then return gTrig(s) end
			return gFade(s)
		end
	end

	-- pair: a mask whose bit for this row is cleared when this box is ticked (Low health and Low mana: one per bar).
	local function makeMaskCheck(parent, x, y, key, index, pair)
		local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
		check:SetSize(CELL, CELL)
		check:SetPoint("TOPLEFT", x, y)
		check:SetScript("OnClick", function(self)
			local mask = effective(key) or 0
			local weight = 2 ^ (index - 1)
			if barBit(mask, index) then
				mask = mask - weight
			else
				mask = mask + weight
				if pair and barBit(DB[pair], index) then DB[pair] = DB[pair] - weight end
			end
			DB[key] = mask
			self:SetChecked(barBit(mask, index))
			settingChanged()
			syncControls() -- (the rows that follow this one show the change too)
		end)
		controls[#controls + 1] = function() check:SetChecked(barBit(effective(key), index)) end
		controls[#controls]()
		return check
	end

	-- The list of what brings the chat up, one checkbox per category in CHAT_KINDS.
	local function makeChatKinds(parent, y)
		local heading = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		heading:SetPoint("TOPLEFT", 16, y)
		heading:SetText("Messages that bring the chat up")
		for i, kind in ipairs(CHAT_KINDS) do
			local check = makeMaskCheck(parent, 12, y - 14 - (i - 1) * 22, "chatKinds", i)
			local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			text:SetPoint("LEFT", check, "RIGHT", 4, 0)
			text:SetText(kind[1])
		end
	end

	local function makeBarGrid(parent, y)
		-- Laid out like the Elements grid (the owner, Nov 10: "the text is too close together"): Fade where Elements has it,
		-- the rest at the same pitch, two-line headings centred over their boxes, a hover text on each. In three groups with
		-- a small gap between them, like the Elements grid's (the owner's yes, Nov 10): when the bar is shown, what is printed
		-- on it, clicks. "Show with ..." only shows while the Show when page has a way to show the whole HUD (a box ticked or a
		-- key bound) and is named after it ("Show with Alt", "Show with F5"); the columns after it close up while it is gone.
		-- (Before the grouping: wow-addon-rollback\2026-11-10_z4_quiethud-audit-fixed-before-layout\QuietHUD\Config.lua.)
		local pitch = 64
		-- (before cols: the Show with help reads peekWaysText; declared after it, that was an always-nil global. Patch check Nov 12)
		local peekHeader, peekHover, peekBoxes, peekWaysText = nil, nil, {}, nil
		local cols = {
			{ "Fade", "barFade", help = "Ticked: this bar fades with the action bars. Unticked: it stays as it is." },
			{ "Mouse over\nonly", "barMouse", help = "This bar fades by itself and is shown only while the mouse is on it, not with the rest." },
			{ "Low\nhealth", "barLow", pair = "barMana", help = "Shown while your health is below Naowh's Low Health threshold (35% without Naowh). One of Low health and Low mana per bar." },
			{ "Low\nmana", "barMana", pair = "barLow", help = "Shown while your mana is below 35%. One of Low health and Low mana per bar." },
			{ "Show with", "barPeek", peek = true, help = function()
				return "Ticked (default): this bar is shown when you show the whole HUD. Unticked: that leaves it as it is."
					.. (peekWaysText and ("\nYours: " .. peekWaysText .. " (Show when page, Keybindings).") or "")
			end },
			{ "Hide\nhotkeys", "barHotkeys", gap = true, pet = true, help = "Hides the key printed in the corner of each button." },
			{ "Hide\nnames", "barNames", pet = true, help = "Hides the macro names printed on the buttons." },
			{ "Click\nthrough", "barClicks", gap = true, pet = true, help = "This bar's buttons never take mouse clicks, shown or not; clicks go to whatever is behind them. Its keys still work." },
		}
		-- Where each column goes, with "Show with" there or not.
		local function place(withPeek)
			local x
			for n, c in ipairs(cols) do
				if not x then
					x = WIN.gridFade
				elseif not (c.peek and not withPeek) then
					x = (n == 2) and WIN.gridFirst or (x + pitch + (c.gap and WIN.gridGap or 0))
				end
				c.x = x
			end
		end
		place(true)
		for _, c in ipairs(cols) do
			local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			header:SetPoint("TOP", parent, "TOPLEFT", c.x + CELL / 2, y)
			header:SetWidth(pitch)
			header:SetJustifyH("CENTER")
			if header.SetMaxLines then pcall(header.SetMaxLines, header, 2) end -- (never more than two lines over the boxes)
			header:SetText(c[1])
			local hover = addHelp(parent, header, (c[1]:gsub("\n", " ")), c.help)
			c.header, c.boxes = header, {}
			if c.peek then peekHeader, peekHover = header, hover end
		end
		local placedWithPeek = true
		local function movePlaced(withPeek)
			if placedWithPeek == withPeek then return end
			placedWithPeek = withPeek
			place(withPeek)
			for _, c in ipairs(cols) do
				c.header:ClearAllPoints()
				c.header:SetPoint("TOP", parent, "TOPLEFT", c.x + CELL / 2, y)
				for _, b in ipairs(c.boxes) do
					b:ClearAllPoints()
					b:SetPoint("TOPLEFT", c.x, b.qhRowY)
				end
			end
		end
		-- The row names. With WackyBars showing (the owner's own bars; the holders in Frames.lua) the game's eight bars are
		-- tucked away, so a row is named after the WackyBars bars on it, and a row with none keeps its game name in grey (the
		-- owner, 2026-11-10: "it uses the wbar naming conventions if wbars is installed and vanilla actionbars ... if only
		-- vanilla"). Worked out each time the window is shown or a setting changes.
		local labels = {}
		local rowY = y - 30
		for i = 1, #BAR_DEFS do
			local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			label:SetPoint("TOPLEFT", 16, rowY - 5)
			label:SetWidth(WIN.gridFade - 24) -- (two WackyBars names on one row use the small font, so they stay on one line)
			label:SetJustifyH("LEFT")
			label:SetText(BAR_DEFS[i].label or ("Action Bar " .. i))
			labels[i] = label
			for _, c in ipairs(cols) do
				-- (the pet bar fades and shows by its Elements row: here only what is printed on it and its clicks)
				if i ~= ns.PET_BAR or c.pet then
					local box = makeMaskCheck(parent, c.x, rowY, c[2], i, c.pair)
					box.qhRowY = rowY
					c.boxes[#c.boxes + 1] = box
					if c.peek then peekBoxes[#peekBoxes + 1] = box end
				end
			end
			rowY = rowY - 24
		end
		local WB_NAMES = { Plain = "Keyboard", Shift = "Shift keyboard", Ctrl = "Ctrl keyboard", Alt = "Alt keyboard",
			MousePlain = "Mouse", MouseShift = "Shift mouse", MouseCtrl = "Ctrl mouse", MouseAlt = "Alt mouse", MouseHyper = "Hypershift" }
		controls[#controls + 1] = function()
			local names, any = {}, false
			for i = 1, #BAR_DEFS do
				names[i] = {}
				-- (the pet bar keeps its name: its holders hold the game's pet buttons, wherever WackyBars put them)
				for _, hn in ipairs(BAR_DEFS[i].label and {} or ns.WB_HOLDERS[i]) do
					local h = _G[hn]
					local bar = h and h.GetParent and h:GetParent()
					if h and type(h.qhudButtons) == "table" and #h.qhudButtons > 0 and bar and bar:IsShown() then
						local id = hn:match("^WackyBarsHold(.-)%d+$")
						names[i][#names[i] + 1] = WB_NAMES[id] or id
						any = true
					end
				end
			end
			-- "Show with ...": what the Show when page has set to show the whole HUD, in plain words (his "whats with the +1
			-- thing", Nov 10): one way by name, two as "A or B", more as "your keys"; a bound key reads "key" in the heading (its
			-- name can be long) and by name in the hover text.
			local mods, keys = {}, {}
			for _, m in ipairs({ { "Alt", "peekAlt", "peekTapAlt" }, { "Ctrl", "peekCtrl", "peekTapCtrl" },
				{ "Shift", "peekShift", "peekTapShift" } }) do
				if DB[m[2]] then mods[#mods + 1] = "hold " .. m[1] elseif DB[m[3]] then mods[#mods + 1] = "tap " .. m[1] end
			end
			for _, b in ipairs({ "QUIETHUD_PEEK", "QUIETHUD_PEEKTOGGLE" }) do
				local key = GetBindingKey and GetBindingKey(b)
				if key and key ~= "" then keys[#keys + 1] = (GetBindingText and GetBindingText(key)) or key end
			end
			local items = {}
			for _, m in ipairs(mods) do items[#items + 1] = m:match("%u%l+$") end
			if #keys > 0 then items[#items + 1] = "key" end
			local on = #items > 0
			local all = {}
			for _, m in ipairs(mods) do all[#all + 1] = m end
			for _, k in ipairs(keys) do all[#all + 1] = k end
			peekWaysText = on and table.concat(all, ", ") or nil
			if peekHeader then
				peekHeader:SetShown(on)
				if peekHover then peekHover:SetShown(on) end -- (its hover text goes with it)
				local word = #items == 1 and items[1] or #items == 2 and (items[1] .. " or " .. items[2]) or "your keys"
				peekHeader:SetText("Show with\n" .. word)
			end
			for _, box in ipairs(peekBoxes) do box:SetShown(on) end
			movePlaced(on) -- (the columns after it close up while it is gone)
			for i, label in ipairs(labels) do
				local own = BAR_DEFS[i].label or ("Action Bar " .. i)
				if any and #names[i] > 0 then
					label:SetFontObject(#names[i] > 1 and "GameFontHighlightSmall" or "GameFontHighlight")
					-- (at most two names, else the first and how many more, so a row never wraps into the next one)
					local n = names[i]
					label:SetText(#n > 2 and (n[1] .. " and " .. (#n - 1) .. " more") or table.concat(n, ", "))
				elseif any and not BAR_DEFS[i].label then
					label:SetFontObject("GameFontDisable") -- (tucked away by WackyBars: its boxes change nothing you see)
					label:SetText(own)
				else
					label:SetFontObject("GameFontHighlight")
					label:SetText(own)
				end
			end
		end
		controls[#controls]()
	end

	-- The trigger grid: a row per element, a column per thing that can bring it up. Each cell is one bit of the row's
	-- number, like the bar grid, and only the cells that mean something for that element are drawn. The columns are
	-- ordered so that no row has a gap: the ones every element has come first, new info last. Show in combat (bit 7, comes
	-- up in a fight) and Hide in combat (bit 5: gone in a fight, whatever else is ticked; red = true, the one box that takes
	-- an element away) are a pair (pair = "combat": barred off together, two-line headings like the rest). The two untick
	-- each other; neither leaves the fight to the other boxes. They sit next to Fade, a small gap after them (gapAfter), then
	-- the rest, the defaults first (Moving), the Weapon drawn column (off by default) near the end.
	local TRIGGER_COLS = {
		gapAfter = 2,
		{ "Show in\ncombat", 7, pair = "combat" }, { "Hide in\ncombat", 5, pair = "combat", red = true },
		{ "Moving", 2 }, { "Target", 9 }, { "Mouse\nmove", 10 }, { "Mouse\nover", 4 },
		{ "Dungeon\nor raid", 6 }, { "Weapon\ndrawn", 8 }, { "New\ninfo", 3 },
	}
	local COL_AT = {}
	for position, col in ipairs(TRIGGER_COLS) do
		COL_AT[col[2]] = position
	end
	local GRIDS = {
		elements = {
			fade = true,
			rows = {
				{ "Action bars", "fadeBars", "trigBars", { 7, 8, 9, 10, 2, 4, 6, 5 } },
				{ "Player frame", "fadePlayer", "trigPlayer", { 7, 8, 9, 10, 2, 4, 6, 5 } },
				-- (frames added with /qhud add hud; the unit frames, auras and alerts have rows of their own, SPLIT)
				{ "Added frames", "fadeUnits", "trigUnits", { 7, 8, 9, 10, 2, 4, 6, 5 } },
				{ "Objective tracker", "fadeTracker", "trigTracker", { 7, 8, 9, 10, 2, 3, 4, 5, 6 } },
				{ "Chat", "fadeChat", "trigChat", { 7, 8, 9, 10, 2, 3, 4, 5, 6 } },
				{ "Minimap", "fadeMinimap", "trigMap", { 7, 8, 9, 10, 2, 3, 4, 5, 6 } },
				{ "Bags bar", "fadeBags", "trigBagsBar", { 7, 8, 9, 10, 2, 4, 6, 5 } },
				{ "Menu bar", "fadeMicro", "trigMicro", { 7, 8, 9, 10, 2, 4, 6, 5 } },
			},
		},
	}
	-- RestedXP's rows, a group at the end of the Elements grid while RestedXP is loaded. Its three fade switches are the Fade
	-- boxes. The targets and items
	-- windows come up with the guide window (one setting, trigRxp), so their row has only its Fade box.
	GRIDS.elements.extra = { addon = "RXPGuides", heading = "RestedXP", rows = {
		{ "Guide window", "rxpGuide", "trigRxp", { 7, 8, 9, 10, 2, 3, 4, 5, 6 } },
		{ "Targets, items", "rxpTargets", "trigRxp", {} },
		{ "Arrow", "rxpArrow", "trigNav", { 7, 8, 9, 10, 2, 4, 5, 6 } },
	} }

	-- The rows of the Elements grid, in the groups of SPLIT.groups, each group under its heading ({ heading = name }). The cast bar
	-- and the breath bar have no row: they only appear when they are needed (see update in Loop.lua), so Fade and the triggers mean
	-- nothing for them. They keep their opacity setting on the Opacity page.
	do
		local byLabel, used, rows = {}, {}, {}
		for _, r in ipairs(GRIDS.elements.rows) do byLabel[r[1]] = r end
		for _, s in ipairs(SPLIT) do
			if not s.noGrid then byLabel[s.label] = { s.label, s.fadeKey, s.trigKey, s.cols, addon = s.addon, when = s.when } end
		end
		for _, group in ipairs(SPLIT.groups) do
			local first = true
			for _, label in ipairs(group[2]) do
				if byLabel[label] then
					if first then rows[#rows + 1], first = { heading = group[1], when = group.when }, false end
					rows[#rows + 1], used[label] = byLabel[label], true
				end
			end
		end
		-- (a row that is in no group still gets a place, at the end)
		for label, row in pairs(byLabel) do
			if not used[label] then rows[#rows + 1] = row end
		end
		GRIDS.elements.rows = rows
	end

	-- The heading of a group of rows (the Elements grid) or of sliders (the Opacity page): gold, with the names under it in white.
	local function makeGroupHeading(parent, x, y, text)
		local h = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		h:SetPoint("TOPLEFT", x, y - 2)
		h:SetText(text)
	end
	local function makeFadeCell(parent, x, y, key)
		local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
		check:SetSize(CELL, CELL)
		check:SetPoint("TOPLEFT", x, y)
		check:SetScript("OnClick", function(self)
			DB[key] = not effective(key)
			self:SetChecked(DB[key] and true or false)
			settingChanged()
			-- RestedXP's Fade boxes say which of its windows are in the rxp and nav lists, so the lists are built again (the
			-- other rows' Fade is read on every update).
			if key == "rxpGuide" or key == "rxpTargets" or key == "rxpArrow" then rebuildLists() end
			syncControls() -- (the rows that follow this one show the change too)
		end)
		controls[#controls + 1] = function() check:SetChecked(effective(key) and true or false) end
		controls[#controls]()
	end

	-- Returns the height it took. Rows under a group heading are indented, and every second row has a faint band behind it, so a
	-- row is easy to follow across the columns. The count runs through the whole grid, so the bands stay even across the
	-- headings. Hovering a column heading or a name shows what it means.
	local function makeTriggerGrid(parent, y, grid)
		local fadeX, firstX, pitch = WIN.gridFade, WIN.gridFirst, WIN.gridPitch
		-- Where each column starts. Fade and the Combat pair sit together; the rest start a small gap after the pair (gapAfter).
		-- (gridPairPitch is the normal pitch: in a narrower pair "Show in" no longer fits its heading, and the grid gets an empty
		-- strip at its right. The bars mark the pair.)
		local X = {}
		for position, col in ipairs(TRIGGER_COLS) do
			local prev = TRIGGER_COLS[position - 1]
			X[position] = not prev and firstX or X[position - 1] + ((col.pair and col.pair == prev.pair) and WIN.gridPairPitch or pitch)
				+ (position - 1 == (TRIGGER_COLS.gapAfter or 1) and WIN.gridGap or 0)
		end
		local function colX(position) return X[position] end
		-- (the stripes reach the end of the last heading, which is wider than its box: ending at the box, they looked cut off)
		local bandRight = colX(#TRIGGER_COLS) + 16 + pitch / 2 + 2
		local function header(x, text, help, red, title, width)
			local h = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			h:SetPoint("TOP", parent, "TOPLEFT", x + 16, y)
			h:SetWidth(width or WIN.gridPitch)
			h:SetJustifyH("CENTER")
			h:SetText(text)
			if red then h:SetTextColor(1, 0.3, 0.3) end
			addHelp(parent, h, title or (text:gsub("\n", " ")), help)
		end
		if grid.fade then header(fadeX, "Fade", HELP.cols.fade) end
		-- (every heading is gridPitch wide, the pair's too, so "Show in" and "Hide in" fit on a line; spans remembers where each
		-- pair starts and ends, for its bars)
		local spans = {}
		for position, col in ipairs(TRIGGER_COLS) do
			header(colX(position), col[1], HELP.cols[col[2]], col.red)
			if col.pair then
				local span = spans[col.pair] or { first = position }
				span.last, spans[col.pair] = position, span
			end
		end
		-- An addon's own rows (grid.extra) go at the end under its name, only while it is loaded. (A client that cannot say
		-- gets them, as the pages' addon items do.)
		-- A row of its own for an addon (row.addon, Dominos in the Bars group) is left out the same way.
		local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
		local function loaded(addon)
			if not (addon and isLoaded) then return true end
			local ok, yes = pcall(isLoaded, addon)
			return not ok or yes and true or false
		end
		local rows = {}
		for _, row in ipairs(grid.rows) do
			if loaded(row.addon) and not (row.when and not row.when()) then rows[#rows + 1] = row end
		end
		local extra = grid.extra
		if extra and loaded(extra.addon) then
			rows[#rows + 1] = { heading = extra.heading }
			for _, row in ipairs(extra.rows) do rows[#rows + 1] = row end
		end
		local labelX = (rows[1] and rows[1].heading) and 24 or 16
		local rowY, band = y - 30, 0
		for n, row in ipairs(rows) do
			if row.heading then
				if n > 1 then rowY = rowY - 4 end
				makeGroupHeading(parent, 16, rowY, row.heading)
				rowY = rowY - 18
			else
				band = band + 1
				if band % 2 == 0 then
					local stripe = parent:CreateTexture(nil, "BACKGROUND")
					stripe:SetColorTexture(1, 1, 1, 0.05)
					stripe:SetPoint("TOPLEFT", 10, rowY)
					stripe:SetSize(bandRight - 10, CELL)
				end
				local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
				label:SetPoint("TOPLEFT", labelX, rowY - 6)
				label:SetText(row[1])
				addHelp(parent, label, row[1], HELP.rows[row[1]])
				if row[2] then makeFadeCell(parent, fadeX, rowY, row[2]) end
				local made = {}
				for _, i in ipairs(row[4]) do
					made[i] = makeMaskCheck(parent, colX(COL_AT[i]), rowY, row[3], i)
				end
				-- Show in combat and Hide in combat say opposite things about a fight: ticking one unticks the other on this row, so
				-- a row never gets both (one that has both anyway is gone in the fight, then shown for the after-combat linger).
				for on, off in pairs({ [T.FIGHT] = T.COMBAT, [T.COMBAT] = T.FIGHT }) do
					if made[on] and made[off] then
						made[on]:HookScript("OnClick", function(self)
							if self:GetChecked() and barBit(effective(row[3]), off) then
								DB[row[3]] = effective(row[3]) - 2 ^ (off - 1)
								made[off]:SetChecked(false)
								settingChanged()
								-- (again, now both bits are right: the click's own redraw came before this, and the rows that
								-- follow this one would show both boxes until the next redraw)
								syncControls()
							end
						end)
					end
				end
				rowY = rowY - 24
			end
		end
		-- A pair is barred off: a thin line on each side, from the top of its heading to the last row, halfway between its
		-- boxes and the next ones, so its heading and its two boxes read as one setting. Both as wide as one unit rounded to
		-- whole screen pixels (at least one; two on a 1440 tall screen), on whole pixels, with the game's PixelUtil: one plain
		-- unit is part of a pixel at most scales, and the two bars came out one and two pixels wide. Set again every time the
		-- page shows, because fitting the window to a short screen changes its scale.
		local bars = {}
		local function placeBars()
			for _, b in ipairs(bars) do
				b.bar:ClearAllPoints()
				if PixelUtil and PixelUtil.SetWidth and PixelUtil.SetPoint then
					PixelUtil.SetWidth(b.bar, 1, 1)
					PixelUtil.SetPoint(b.bar, "TOPLEFT", parent, "TOPLEFT", b.x, y + 2)
				else
					b.bar:SetWidth(1)
					b.bar:SetPoint("TOPLEFT", b.x, y + 2)
				end
			end
		end
		for _, span in pairs(spans) do
			for _, x in ipairs({ colX(span.first) - 13, colX(span.last) + CELL + 21 }) do
				local bar = parent:CreateTexture(nil, "ARTWORK")
				bar:SetColorTexture(1, 1, 1, 0.18)
				bar:SetHeight(y + 2 - rowY)
				bars[#bars + 1] = { bar = bar, x = x }
			end
		end
		placeBars()
		parent:HookScript("OnShow", placeBars)
		return y - rowY + 6
	end

	-- The About page: who made it (with the cat), and the links. The game cannot open a web page, so each link is a box to click
	-- and copy from with Ctrl+C; typing in it changes nothing. Returns the height it took. No donation link: Blizzard's add-on
	-- policy (rule 5) keeps requests for donations to the website and the download page, out of the game.
	local ABOUT_LINKS = {
		{ "Website", "https://jackafur.com" },
		{ "CurseForge", "https://www.curseforge.com/wow/addons/quiethud" },
		{ "GitHub", "https://github.com/Jackafur/quiethud" },
	}
	local function makeAbout(parent, y, titleText)
		local cat = parent:CreateTexture(nil, "ARTWORK")
		cat:SetSize(64, 64)
		cat:SetPoint("TOPLEFT", 24, y - 2)
		cat:SetTexture("Interface\\AddOns\\QuietHUD\\cat")
		local name = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		name:SetPoint("TOPLEFT", 100, y - 10)
		name:SetText(titleText)
		local what = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		what:SetPoint("TOPLEFT", 100, y - 32)
		what:SetText("Fades the HUD out when you are not doing anything, to protect OLED screens.")
		local by = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		by:SetPoint("TOPLEFT", 100, y - 50)
		by:SetText("Made by Jackafur. Tested by Vada.")
		local rowY = y - 84
		makeGroupHeading(parent, 16, rowY, "Links")
		local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		hint:SetPoint("TOPLEFT", 16, rowY - 22)
		hint:SetTextColor(0.75, 0.75, 0.75)
		hint:SetText("Click a link, then press Ctrl+C to copy it. Found a bug? Tell me on CurseForge or GitHub.")
		rowY = rowY - 42
		for _, link in ipairs(ABOUT_LINKS) do
			local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			label:SetPoint("TOPLEFT", 24, rowY - 4)
			label:SetText(link[1])
			local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
			box:SetSize(360, 20)
			box:SetPoint("TOPLEFT", 120, rowY)
			box:SetAutoFocus(false)
			local url = link[2]
			box:SetText(url)
			box:SetCursorPosition(0)
			box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
			box:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)
			box:SetScript("OnTextChanged", function(self, userInput)
				if userInput then
					self:SetText(url)
					self:HighlightText()
				end
			end)
			box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
			box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
			rowY = rowY - 26
		end
		return y - rowY + 6
	end

	-- A section heading. Returns the height it took.
	local function makeHeading(parent, y, text)
		local heading = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
		heading:SetPoint("TOPLEFT", 16, y - 2)
		heading:SetText(text)
		return 22
	end

	-- A button at the right end of the row above it (top is where its top edge goes): the Extras page's Reset position, after the
	-- open bags box. (A short slider row ends with its readout at about 485, so a button fits after one too.)
	local BUTTONS = {
		bagPosition = function()
			if not resetBagPosition then return end
			resetBagPosition()
			print("QuietHUD: the open bags are back where the game places them")
		end,
	}
	local function makeButton(parent, top, text, action, help)
		local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
		button:SetSize(110, 22)
		button:SetPoint("TOPLEFT", 506, top)
		button:SetText(text)
		button:SetScript("OnClick", BUTTONS[action])
		addHelp(parent, button, text, help)
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
			if not config.numTabs and tabs[i].SetEnabled then tabs[i]:SetEnabled(i ~= index) end
		end
		-- The game's own tabs draw the page you are on as the open tab (the plain buttons of the fallback window grey it out).
		if config.numTabs then PanelTemplates_SetTab(config, index) end
		-- A setting can change on another page or by a slash command, so what a page shows is refreshed when you switch to it.
		syncControls()
	end

	resetDefaults = function()
		-- (the spot the open bags were moved to stays saved)
		for k, v in pairs(DEFAULTS) do
			if k ~= "bagX" and k ~= "bagY" then DB[k] = v end
		end
		-- (the Dominos row copies the reset Action bars row again, while Dominos is loaded)
		local d = SPLIT_BY.dominos
		DB[d.fadeKey], DB[d.trigKey], DB[d.ovKey] = nil, nil, nil
		if not woc.off.dominos then woc.claimDominos() end
		settingChanged()
		rebuildLists()
		syncControls()
		if ns.armEntry then ns.armEntry() end
	end

	-- Taller than the screen (at UI scale 1.0 the screen is 768 tall), the window is scaled down to fit, so the buttons at the
	-- bottom can always be reached.
	local function fitConfig()
		local screen, h = UIParent:GetHeight(), config:GetHeight()
		local scale = 1
		if screen and screen > 0 and h > screen - 16 then scale = (screen - 16) / h end
		config:SetScale(scale)
	end

	local function buildConfig()
		-- (the Dominos row's one-time copy of Action bars, only while Dominos is loaded: see woc.claimDominos)
		if not (woc.off and woc.off.dominos) then woc.claimDominos() end
		-- The game's own window (the one the macro window uses): title bar, close button, our icon in the portrait, an inset for
		-- the pages and a bar for the buttons. If it is ever missing, the plain dark window from before is used.
		local okFramed, framedWindow = pcall(CreateFrame, "Frame", "QuietHUDConfig", UIParent, "ButtonFrameTemplate")
		local framed = okFramed and framedWindow and framedWindow.SetTitle and type(framedWindow.Inset) == "table"
		if okFramed and framedWindow and not framed then framedWindow:Hide() end
		config = framed and framedWindow or CreateFrame("Frame", "QuietHUDConfig", UIParent)
		config:SetSize(520, 790)
		config:SetPoint("CENTER")
		config:SetFrameStrata("DIALOG")
		config:SetClampedToScreen(true)
		config:SetMovable(true)
		config:EnableMouse(true)
		config:RegisterForDrag("LeftButton")
		config:SetScript("OnDragStart", config.StartMoving)
		config:SetScript("OnDragStop", config.StopMovingOrSizing)
		-- Esc closes it, like the game's own windows.
		if UISpecialFrames then table.insert(UISpecialFrames, "QuietHUDConfig") end
		local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
		local okV, version = pcall(getMeta, ADDON, "Version")
		local titleText = "QuietHUD" .. ((okV and type(version) == "string" and version ~= "") and (" " .. version) or "")
		if framed then
			config:SetTitle(titleText)
			if config.SetPortraitToAsset then config:SetPortraitToAsset("Interface\\AddOns\\QuietHUD\\icon") end
		else
			local bg = config:CreateTexture(nil, "BACKGROUND")
			bg:SetAllPoints()
			bg:SetColorTexture(0.05, 0.05, 0.05, 0.92)
			local title = config:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
			title:SetPoint("TOP", 0, -10)
			title:SetText(titleText)
			local close = CreateFrame("Button", nil, config, "UIPanelCloseButton")
			close:SetPoint("TOPRIGHT", 2, 2)
		end

		-- The tallest page sets the window's height. A page sits between the tabs (pageTop from the top) and the buttons
		-- (pageBottom from the bottom); the notes are only measured here, with the game's own font.
		local pageTop, pageBottom = framed and 62 or 68, framed and 30 or 44
		local tabX, tallest = 12, 0
		-- An item for another addon is left out while that addon is not loaded (when the game cannot say, it is shown).
		local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
		local function wanted(item)
			if item.when and not item.when() then return false end -- (the Controller row's slider, without a controller)
			if not (item.addon and isLoaded) then return true end
			local ok, loaded = pcall(isLoaded, item.addon)
			return not ok or loaded and true or false
		end
		for i, page in ipairs(PAGES) do
			local frame = CreateFrame("Frame", nil, config)
			frame:SetPoint("TOPLEFT", 0, -pageTop)
			frame:SetPoint("BOTTOMRIGHT", 0, pageBottom)
			local y = -4
			local items = {}
			for _, item in ipairs(page.items) do
				if wanted(item) then items[#items + 1] = item end
			end
			for idx, item in ipairs(items) do
				-- The item before this one; a button sits on the row before it, so for spacing the item before the button counts.
				local before = items[idx - 1]
				if before and before[1] == "button" then before = items[idx - 2] end
				local prevKind = before and before[1]
				if item[1] == "check" then
					-- A box right under a slider gets some room, so a click meant for the slider does not land on the box.
					if prevKind == "slider" and not before[9] then y = y - 10 end
					makeCheck(frame, y, item[3], item[2], item[4], nil, item.untick)
					local r = item.right -- (a second box on the same row, in the right column)
					if r then makeCheck(frame, y, r[2], r[1], r[3], WIN.col2, r.untick) end
					y = y - 26
				elseif item[1] == "kinds" then
					makeChatKinds(frame, y)
					y = y - (18 + #CHAT_KINDS * 22)
				elseif item[1] == "bargrid" then
					makeBarGrid(frame, y)
					y = y - 252 -- (two-line headings, nine rows, the pet bar the last)
				elseif item[1] == "grid" then
					if prevKind == "columns" then y = y - 8 end -- (room between the last slider row and the column headings)
					y = y - makeTriggerGrid(frame, y, GRIDS[item[2]])
				elseif item[1] == "note" then
					if prevKind == "check" then y = y - 4 end
					y = y - makeNote(frame, y, item[2])
				elseif item[1] == "heading" then
					if idx > 1 then y = y - 10 end
					y = y - makeHeading(frame, y, item[2])
				elseif item[1] == "columns" then
					-- Two columns of sliders under group headings (the Opacity page, RestedXP's opacity); the page goes on under
					-- the longer one. Under a row of boxes they get some room, like a slider does.
					if prevKind == "check" then y = y - 10 end
					local lowest = y
					for c, list in ipairs({ item.left, item.right }) do
						local x, cy = c == 1 and 0 or WIN.col2 - 16, y
						for n, entry in ipairs(list) do
							if entry[1] == "group" then
								if wanted(entry) then -- (an addon's group, RestedXP's, only while it is loaded)
									if n > 1 then cy = cy - 6 end
									makeGroupHeading(frame, 16 + x, cy, entry[2])
									cy = cy - 18
								end
							elseif wanted(entry) then
								makeSlider(frame, cy, entry[3], entry[2], entry[4], entry[5], entry[6], entry[7], entry[8], entry[9], x, entry[10])
								cy = cy - 22
							end
						end
						lowest = math.min(lowest, cy)
					end
					y = lowest
				elseif item[1] == "about" then
					y = y - makeAbout(frame, y, titleText)
				elseif item[1] == "button" then
					-- On the row above: a check row is 26 tall with a 32 tall box, a short slider row 22 with a 16 tall bar.
					makeButton(frame, prevKind == "check" and (y + 21) or (y + 24), item[2], item[3], item[4])
				else
					if prevKind == "check" then y = y - 6 end
					makeSlider(frame, y, item[3], item[2], item[4], item[5], item[6], item[7], item[8], item[9], nil, item[10], item[11])
					y = y - (item[9] and 22 or 46)
				end
			end
			pages[i] = frame
			tallest = math.max(tallest, -y)
			local tab
			if framed then
				-- The game's top tabs size themselves to their text and sit on the inset, after the portrait (as in the macro window).
				tab = CreateFrame("Button", nil, config, "PanelTopTabButtonTemplate")
				if i == 1 then tab:SetPoint("TOPLEFT", 51, -28) end
			else
				tab = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
				local tabWidth = math.max(44, math.floor(#page.title * 6.4 + 18))
				tab:SetSize(tabWidth, 22)
				tab:SetPoint("TOPLEFT", tabX, -36)
				tabX = tabX + tabWidth + 4
			end
			tab:SetText(page.title)
			if framed and PanelTemplates_TabResize then PanelTemplates_TabResize(tab, 0) end
			tab:SetScript("OnClick", function() showPage(i) end)
			tabs[i] = tab
		end
		-- The window is as wide as the tabs need (each tab is at least as wide as its art, so they can need more than WIN.width),
		-- and as tall as the tallest page.
		local tabsRight = tabX
		if framed and PanelTemplates_SetNumTabs then
			config.Tabs = tabs
			PanelTemplates_SetNumTabs(config, #tabs) -- anchors each tab to the one before it, 3 apart
			tabsRight = 51 + 3 * (#tabs - 1) + 7 -- the first tab's place, the gaps, and the last tab's art past its edge
			for _, tab in ipairs(tabs) do tabsRight = tabsRight + tab:GetWidth() end
		end
		config:SetSize(math.max(WIN.width, math.ceil(tabsRight + 10)), pageTop + tallest + pageBottom + 6)

		-- The buttons sit in the window's button bar (framed) or above the bottom edge (plain).
		local buttonH, buttonY, buttonX = framed and 22 or 24, framed and 4 or 14, framed and 4 or 16
		local now = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
		now:SetSize(150, buttonH)
		now:SetPoint("BOTTOMLEFT", buttonX, buttonY)
		now:SetText("Show the whole HUD")
		-- Shows the whole HUD (the same as /qhud peek); pressing it again puts things back to normal. It also ends by itself
		-- after two minutes.
		now:SetScript("OnClick", function()
			local t = GetTime()
			ns.peekUntil = t < ns.peekUntil and 0 or t + 120
			wakeLoop()
			print("QuietHUD: " .. (ns.peekUntil > 0 and "the whole HUD is shown (press again to go back to normal)" or "back to normal"))
		end)
		local reset = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
		reset:SetSize(150, buttonH)
		reset:SetPoint("BOTTOMRIGHT", framed and -6 or -16, buttonY)
		reset:SetText("Reset to defaults")
		-- It asks first: the first click only arms it, and a second click within five seconds resets everything.
		local armedUntil = 0
		reset:SetScript("OnClick", function(self)
			local t = GetTime()
			if t < armedUntil then
				armedUntil = 0
				self:SetText("Reset to defaults")
				resetDefaults()
				return
			end
			armedUntil = t + 5
			self:SetText("Click again to reset")
			C_Timer.After(5, function()
				if GetTime() >= armedUntil then self:SetText("Reset to defaults") end
			end)
		end)
		-- The master switch sits between the two buttons, so it can be reached from every page. The box and its name are
		-- centered together.
		local enable, enableText = makeCheck(config, 0, "Enable QuietHUD", "enabled",
			"Unticked, QuietHUD stops fading and hiding things, and the whole HUD shows as the game draws it.")
		enable:SetSize(26, 26)
		enable:ClearAllPoints()
		local enableW = 26 + 4 + math.ceil(enableText:GetStringWidth() or 100)
		enable:SetPoint("BOTTOMLEFT", config, "BOTTOM", -math.floor(enableW / 2), buttonY - 2)

		config:SetScript("OnShow", function()
			fitConfig()
			syncControls()
		end)
		fitConfig()
		showPage(1)
		config:Hide()
	end

	-- A key bound or changed while the window is open: what depends on it follows (the Show with column).
	ns.refreshConfig = function()
		if config and config:IsShown() then syncControls() end
	end

	toggleConfig = function()
		if not config then buildConfig() end
		config:SetShown(not config:IsShown())
	end

	-- The game's own list of addons (Esc, Options, AddOns): QuietHUD has a page there with one button, which opens this window
	-- on top of the game's options. The window itself is not put inside the game's panel: it is taller and has its own tabs.
	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		pcall(function()
			local page = CreateFrame("Frame")
			page:Hide()
			local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
			title:SetPoint("TOPLEFT", 16, -16)
			title:SetText("QuietHUD")
			local text = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
			text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
			text:SetWidth(560)
			text:SetJustifyH("LEFT")
			text:SetText("QuietHUD has its own settings window. Typing /qhud in chat opens it too.")
			local open = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
			open:SetSize(200, 24)
			open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -14)
			open:SetText("Open QuietHUD settings")
			open:SetScript("OnClick", function()
				if not config then buildConfig() end
				config:Show()
				config:Raise()
			end)
			local category = Settings.RegisterCanvasLayoutCategory(page, "QuietHUD")
			Settings.RegisterAddOnCategory(category)
		end)
	end
end

-- For the files after this one (QuietHUD.toc).
ns.syncControls, ns.resetDefaults, ns.toggleConfig = syncControls, resetDefaults, toggleConfig
