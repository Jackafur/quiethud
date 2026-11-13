-- QuietHUD is in several files, one topic each, loaded in the order QuietHUD.toc lists them. They share ns, the table the
-- game hands every file of an addon: a file puts what later files use on ns at its end, and takes what it uses from earlier
-- files at its top, under the same names. A value that more than one file changes lives on ns itself (ns.debugOn, ...).
-- This file: the settings and their defaults, and the element rows.
local _, ns = ...

-- The settings and their defaults. They are kept in the game's saved file for QuietHUD (QuietHUDDB, see initDB in
-- Core.lua): a setting a file does not hold yet gets its default there, so a new setting needs nothing more than a line here.
local DEFAULTS = {
	enabled = true,
	base = 0.75, -- the Global Shown
	idle = 0, -- the Global Faded
	linger = 4, -- seconds the HUD stays up after a fight
	fadeBars = true,
	fadePlayer = true,
	fadeUnits = true, -- (the "Added frames" row: frames added with /qhud add hud)
	fadeMinimap = true,
	mapFollowsHud = true,
	mapDarken = false,
	mapDarkFloor = 0, -- the darkened minimap's own Faded (0: the Global Faded)
	mapCover = 0, -- the arrow cover's opacity (0: off), Minimap.lua
	mapCoverSize = 20, -- its size
	fadeTracker = true,
	fadeChat = true,
	chatDim = true,
	chatSeconds = 8,
	chatKinds = 71,
	chatOpacity = 1,
	chatFadeSeconds = 1.5,
	-- What brings each element up: one number per element, where bit i is column i of the trigger grid (2 while moving,
	-- 3 new info, 4 mouse over, 5 hide in combat, 6 dungeon or raid, 7 combat, 8 weapon drawn, 9 a target, 10 the mouse
	-- moving; bit 1 is not used). Every row comes up in combat, while moving or with the mouse over it (74); the tracker,
	-- the chat, the minimap and RestedXP also for new info (78). The weapon is off by default.
	trigBars = 74,
	trigPlayer = 74,
	trigUnits = 74,
	trigTracker = 78,
	trigChat = 78,
	trigRxp = 78,
	trigNav = 26,
	trigMap = 78,
	rxpGuide = true,
	rxpTargets = true,
	rxpArrow = true,
	rxpShown = 0, -- (0 = Global)
	navShown = 0,
	questSeconds = 10,
	fadeBags = true,
	fadeMicro = true,
	trigBagsBar = 74,
	trigMicro = 74,
	barFade = 511, -- (Action bars page, Fade column: bits 1 to 8 the action bars; the pet bar's Fade is its Elements row)
	barMana = 0, -- Action bars page, Low mana column (one of Low health and Low mana per bar; ActionBars.lua)
	barLow = 0, -- Action bars page, Low health column: such a bar comes up while health is low (ActionBars.lua)
	barPeek = 511, -- Action bars page, Show with Alt column: that bar comes up when you show the whole HUD (ActionBars.lua woc.peekBar)
	barMouse = 0, -- Action bars page, Mouse over column: such a bar fades by itself, up only under the mouse (woc.mouseBars)
	mouseTogether = false, -- Action bars page: the mouse on one Mouse over only bar brings them all up (woc.mouseBars)
	barHotkeys = 0,
	barNames = 0,
	hideReporter = false,
	shortHotkeys = false,
	barClicks = 0, -- Action bars page, Click through column: that bar's buttons never take mouse clicks (ActionBars.lua)
	questTarget = false,
	watchMouse = false,
	pixelShift = false,
	shiftPixels = 2,
	shiftMinutes = 3,
	tooltipAlpha = 1, -- (0 = Global; solid by default: a window you read, not HUD)
	shiftBars = false,
	shiftUnits = false,
	peekAlt = false,
	peekCtrl = false,
	peekShift = false,
	peekTapAlt = false, -- a tap of Alt on its own toggles the whole HUD (the Tap boxes and the hold boxes untick each other)
	peekTapCtrl = false,
	peekTapShift = false,
	bagAlpha = 1, -- (0 = Global; solid by default, as the tooltips)
	fadeOutSeconds = 0.35,
	mouseSeconds = 3,
	notFullShows = false,
	keepDrawn = false,
	bagX = 0, bagY = 0, -- where the open bag windows were dragged to (see the bags block)
	moveBags = false, -- let QuietHUD move the open bags (Extras page)
	hideMmButtons = false, -- hide the minimap buttons of other addons
	hidePanel = false, -- hide the party panel completely
	-- Own opacity for an element (0 = follow the Global Shown). The split groups' are added with SPLIT below.
	ovBars = 0, ovPlayer = 0, ovCast = 0, ovHud = 0, ovQuest = 0, ovMap = 0, ovBagsBar = 0, ovMicro = 0,
}
-- The saved file's version. A file from before the launch build has none and is not read: everyone starts on these
-- defaults. A later change that renames or removes a setting, or changes what one means, adds a step to MIGRATIONS and
-- raises this number (see initDB in Core.lua).
local SETTINGS_VERSION = 4

-- The unit frame, aura and alert rows, the cast bar and the breath bar, and Dominos. Each has its own frames, its own row in
-- the trigger grid (Fade and triggers) and its own opacity; their settings are named after the group (fadeTarget,
-- trigTarget, ovTarget). cols is which trigger columns the row offers (5 is Hide in combat). The cast bar is shown while you
-- cast and the breath bar while a timer runs.
-- Whether the game's controller layout is on (Options, Controller, or the controller interface style): the Controller row is
-- on the Elements and Opacity pages, and counts, only then. Asked when the lists are built and when the settings window is.
local function padSetUp()
	local ok, on = pcall(function()
		return (C_GamePad and C_GamePad.IsEnabled and C_GamePad.IsEnabled())
			or (InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled())
	end)
	return ok and on and true or false
end
local SPLIT = {
	-- The pet bar (the owner, Nov 10: "put the pet actionbar in elements", "i need to hide it"): Fade and its triggers here, its
	-- Shown on the Opacity page (ovPetBar). Its frames and buttons are the Action bars page's Pet bar row (ActionBars.lua
	-- woc.applyPetBar writes them), which keeps only Hide hotkeys, Hide names and Click through for it. hover: what Mouse over
	-- looks at (Frames.lua adds WackyBars' holders). Not counted when the Opacity columns split.
	{ g = "petBar", label = "Pet bar", frames = {}, uncounted = true },
	-- The game's controller layout, a group of its own, one row per piece (the owner, Nov 12: "it should have its own row if the
	-- controller thing is turned on", then "controller should be its own main section ... seperate things indvidually"): its
	-- action bar in place of Action Bar 1, the aiming dot in the middle of the screen, and the button reminder box at the top
	-- left (LB/RB targeting, Ping, Auto-Run, and the lists shown while LB / RB are held; Blizzard_Gamepad's
	-- GamepadPersistentInputLegend, a small holder with the box you see as a child, so mouse over looks at the children: deep).
	-- All hidden by the game while no controller is set up. Each starts as a copy of the Action bars row (MIGRATIONS[4]), where
	-- they were before. when: on the pages only while a controller is set up (the game's option to enable a controller).
	{ g = "padBar", label = "Controller bar", frames = { "GamepadMainActionBarFrame" }, uncounted = true, when = padSetUp },
	-- The aiming dot has no Mouse over (cols without 4, an empty hover list): it sits where you aim, so the cursor on a player
	-- or a mob is on it, and that brought the rows up (the owner, Nov 12: "when my cursor goes over people it pops the menus up").
	{ g = "padDot", label = "Aiming dot", frames = { "GamepadReticle" }, uncounted = true, when = padSetUp,
		cols = { 7, 8, 9, 10, 2, 6, 5 }, hover = {} },
	{ g = "padLegend", label = "Button reminder", frames = { "GamepadPersistentInputLegend" }, deep = true, uncounted = true,
		when = padSetUp },
	{ g = "target", label = "Target and focus", frames = { "TargetFrame", "FocusFrame" } },
	-- PetSpellBar is BetterBlizzFrames' pet cast bar: a separate frame on the screen that would not fade with PetFrame
	-- (the name means nothing without that addon, and is skipped then).
	{ g = "pet", label = "Pet frame", frames = { "PetFrame", "PetSpellBar" } },
	{ g = "party", label = "Party and raid", frames = { "PartyFrame", "CompactRaidFrameContainer" } },
	{ g = "panel", label = "Party panel", frames = { "CompactRaidFrameManager" } },
	-- (Buffs is the group "auras": the name from when it was one "Buffs and debuffs" row)
	{ g = "auras", label = "Buffs", frames = { "BuffFrame", "TemporaryEnchantFrame", "TotemFrame" } },
	{ g = "debuffs", label = "Debuffs", frames = { "DebuffFrame" } },
	{ g = "cooldowns", label = "Cooldown trackers", frames = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer" } },
	{ g = "meter", label = "Damage meter", frames = { "DamageMeter", "NaowhForeverThreatMeter" } }, -- (Naowh's threat meter: up in a fight like a damage meter, the owner's pick Nov 5)
	-- ShardTransferImminentFrame is the game's "The world around you will refresh in 10 minutes" notice and
	-- ShardTransferImminentMinimizeButton the arrow beside it that folds it away (Blizzard_SocialToast, above the chat). Only
	-- those two: ChatAlertFrame around them also holds the friend toasts.
	{ g = "alerts", label = "Alerts", frames = { "DurabilityFrame", "LossOfControlFrame", "ExternalDefensivesFrame", "ShardTransferImminentFrame",
		"ShardTransferImminentMinimizeButton" } },
	{ g = "cast", label = "Cast bar", frames = { "PlayerCastingBarFrame", "CastingBarFrame" }, cols = { 5 }, trig = 0, noGrid = true },
	{ g = "breath", label = "Breath bar", frames = { "MirrorTimerContainer", "MirrorTimer1", "MirrorTimer2", "MirrorTimer3" }, cols = {}, trig = 0, noGrid = true },
	-- All of Dominos in one row, on the Elements and Opacity pages only while Dominos is loaded (addon). Its frames are in the
	-- Dominos block of Frames.lua. Until the row has settings of its own it follows the
	-- Action bars row (follows: Fade, triggers, Shown) and its frames stay in the Action bars, Bags bar and Menu bar lists;
	-- the first time the settings window opens with Dominos loaded, and after Reset, it copies those three and is a row of
	-- its own from then on (woc.claimDominos). Its settings have no default for that reason.
	{ g = "dominos", label = "Dominos", frames = {}, addon = "Dominos", follows = { "fadeBars", "trigBars", "ovBars" } },
	-- Naowh Forever's HUD pieces in one row, on the Elements and Opacity pages only while it is loaded (the owner runs it,
	-- 2026-11-05: "i want to mouse over a naowh thing and have all the naowh shit come up"). The XP bar and ticker, the
	-- campfire, the bag counter, the top bar with its clock, the FPS / MS readout and the Journey card,
	-- which have no names of their own (named in rebuildLists). Its frames are holders with the part you see as a child, so mouse
	-- over looks at the children too (deep). Naowh's own "Show On Mouseover" for the top bar should be off with this row
	-- fading it: both would set the bar's opacity. Its Opacity slider is not counted when the columns are split (uncounted).
	{ g = "naowh", label = "Naowh", frames = { "NaowhForeverXPBar", "NaowhForeverXPTicker", "NaowhForeverCampfire",
		"NaowhForeverBagSpace", "NaowhForeverTopBar", "QuietHUDNaowhSystem",
		"QuietHUDNaowhJourney", "QuietHUDNaowhCampBag", "NaowhForeverConsumableBar", "NaowhForeverFoodBar",
		"NaowhForeverBlessingBar", "NaowhForeverGearBar" }, addon = "NaowhForever",
		deep = true, uncounted = true, trig = 8 }, -- (the consumable bar and the food and drink buttons: his ask, Nov 6, "attatched to the other naowh stuff") -- (trig 8: Mouse over only by default, his ask)
	-- (the Blessings bar, NaowhForever_Combat/Blessings, and the Gear Sets bar, NaowhForever_Combat/GearSets: his ask, Nov 7;
	-- both are named holders on UIParent with their buttons as children, and Naowh only shows and hides them, never sets their opacity)
	-- Naowh Forever's alerts, at one see-through opacity by default (Fade unticked, Shown 0.50; the owner, 2026-11-05): Low
	-- Health, the +Combat alert, Buff Reminders, and the alert stack (Camp Nearby, Pet Missing, Restock, Talent Points,
	-- Durability, Flight Point; NaowhForeverAlerts is the stack's own holder). These show and hide themselves with their own
	-- opacity (Low Health by your health, +Combat with its own animation), so QuietHUD never sets theirs: they are moved under a
	-- host frame of QuietHUD's and the host is what fades (host, Guides.lua), the two opacities multiply. Naowh builds most of
	-- them when first needed: the CreateFrame hook (Core.lua) writes the row again then.
	{ g = "naowhAlerts", label = "Naowh alerts", frames = { "NaowhForeverLowHealth", "NaowhForeverCombatAlert",
		"NaowhForeverBuffReminders", "NaowhForeverAlerts", "NaowhForeverCampNearby", "NaowhForeverPetTracker",
		"NaowhForeverRestock", "NaowhForeverTalentPoints", "NaowhForeverDurability", "NaowhForeverFlightPoint",
		-- (Naowh's swing timer, NaowhForever_Combat/SwingTimer: it shows itself in a fight and hides after; here it gets the
		-- row's see-through opacity, the owner, 2026-11-07: "i want it to have the transparency")
		"NaowhForeverSwingTimer" },
		addon = "NaowhForever", host = true, uncounted = true, fade = false, ov = 0.5 },
	-- Naowh Forever's Flight Timer (the "In flight" card, NaowhForever_QoL/Travel/Flight.lua): its own row so it has its own
	-- Fade box and Shown slider (the owner, 2026-11-06: "can we add this to qhud as well. opacity settings", "its called flight
	-- timer"). Naowh shows and hides it with Show and Hide and never sets its opacity, so QuietHUD writes it directly (no
	-- host). Fade unticked by default: it is up for the whole flight, and in the air nothing else shows the HUD.
	{ g = "flightTimer", label = "Flight timer", frames = { "NaowhForeverFlightTimer" }, addon = "NaowhForever",
		uncounted = true, fade = false },
	-- Spy's window (the Nearby list of enemy players it saw), on the Elements and Opacity pages only while Spy is loaded (the
	-- owner runs it on a PvP realm, Nov 12: "add it to qhud tie it to something"). Fades and comes up like the other rows, and
	-- has New info, ticked by default: Spy's alarm (a new enemy, a stealthed or prowling one, a watched player or guild) brings
	-- it up for the "Stay shown after something new" seconds (the owner: "it should get new info. any time the alarm goes off
	-- it should come up"). The alarm is heard through hooks on Spy's alert functions (Events.lua hookSpy), nothing polled; info
	-- names the ns field the loop compares the time with.
	-- Spy's warning in the middle of the screen (Spy_AlertWindow) and its sound are left alone: they are the warning, and Spy
	-- flashes that box itself for a few seconds. Spy sets the window's opacity only on a zone change or from its own slider, so
	-- QuietHUD writes it directly (no host); Spy makes it after QuietHUD loads, the CreateFrame hook (Core.lua) catches it.
	{ g = "spy", label = "Spy", frames = { "Spy_MainWindow" }, addon = "Spy", uncounted = true,
		cols = { 7, 8, 9, 10, 2, 3, 4, 5, 6 }, trig = 78, info = "spyUntil" },
}
local SPLIT_BY = {}
for _, s in ipairs(SPLIT) do
	local cap = s.g:sub(1, 1):upper() .. s.g:sub(2)
	s.fadeKey, s.trigKey, s.ovKey = "fade" .. cap, "trig" .. cap, "ov" .. cap
	s.cols = s.cols or { 7, 8, 9, 10, 2, 4, 6, 5 }
	-- (every row fades; the cast bar and the breath bar come up only for a cast or a timer, the rest like the other rows)
	if not s.follows then
		DEFAULTS[s.fadeKey], DEFAULTS[s.trigKey], DEFAULTS[s.ovKey] = s.fade ~= false, s.trig or DEFAULTS.trigUnits, s.ov or 0
	end
	SPLIT_BY[s.g] = s
end
-- The trigger rows that are settings of their own (the split groups above have theirs in s.trigKey).
SPLIT.mainTrig = { "trigBars", "trigPlayer", "trigUnits", "trigTracker", "trigChat", "trigRxp", "trigNav", "trigMap",
	"trigBagsBar", "trigMicro" }
-- The rows of the Elements grid and the sliders of the Opacity page, in groups, in this order. Info is the rows with a New info
-- column. (The cast bar and the breath bar have no grid row: they only appear when they are needed, so they are only on the
-- Opacity page.)
SPLIT.groups = {
	{ "Bars", { "Action bars", "Pet bar", "Bags bar", "Menu bar", "Dominos", "Cast bar", "Breath bar" } },
	{ "Controller", { "Controller bar", "Aiming dot", "Button reminder" }, when = padSetUp },
	{ "Unit frames", { "Player frame", "Target and focus", "Pet frame", "Party and raid", "Party panel" } },
	{ "Auras and alerts", { "Buffs", "Debuffs", "Cooldown trackers", "Alerts" } },
	{ "Info", { "Objective tracker", "Chat", "Minimap" } },
	{ "Other", { "Damage meter", "Added frames", "Naowh", "Naowh alerts", "Flight timer", "Spy" } },
}

-- For the files after this one (QuietHUD.toc).
ns.DEFAULTS, ns.SETTINGS_VERSION, ns.SPLIT, ns.SPLIT_BY = DEFAULTS, SETTINGS_VERSION, SPLIT, SPLIT_BY
