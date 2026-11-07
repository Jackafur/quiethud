-- The frames QuietHUD fades, by group, and the other fixed lists: the action bars, the order the groups are written in, the
-- kinds of chat message.
local _, ns = ...
local SPLIT, SPLIT_BY = ns.SPLIT, ns.SPLIT_BY

local FADE = 0.35
local MOVE_LINGER = 1.5
local SKULL = 8

local DEFAULT_LISTS = {
	bars = { "StatusTrackingBarManager", "StanceBar", "PetActionBar", "PossessActionBar", "MultiCastActionBarFrame" },
	player = { "PlayerFrame" },
	hud = { "QuietHUDWarlockHud", "QuietHUDWarlockMulti", "WarlockHudMultiTargetWindow" }, -- Warlock HUD (woc.watchWarlockHud), and frames you add with /qhud add hud
	quest = { "ObjectiveTrackerFrame", "Questie_BaseFrame" }, -- Questie hides the game's tracker and shows its own
	map = { "MinimapCluster" },
	micro = { "MicroMenuContainer" }, -- (Dominos' menu bar and bag bar: see the Dominos block below)
	bags = { "BagsBar" },
	reporter = { "PTR_IssueReporter", "PTR_IssueReporterButton", "PTR_IssueReporterFrame" },
	hidden = {},
	-- /qhud add mouseover: each frame fades by itself and comes up only while the mouse is on it (woc.mouseOnly).
	mouseover = {},
	chat = {},
	nav = {},
	rxp = {},
	shift = { "MinimapCluster", "ObjectiveTrackerFrame" },
}
local ALL_LISTS = { "bars", "player", "hud", "quest", "map", "micro", "bags", "reporter", "hidden", "chat", "nav", "rxp", "shift", "mouseover" }
for _, s in ipairs(SPLIT) do DEFAULT_LISTS[s.g] = s.frames; ALL_LISTS[#ALL_LISTS + 1] = s.g end
-- Action Bars 1 to 8: the frame(s) of each bar and the prefix of its button names. ForeverClassicUIBar is ClassicUI Forever's
-- gryphon band (the stone band and gryphons, with the micro menu and bags that addon draws on it), which goes with Action
-- Bar 1 like the old MainMenuBar did.
local BAR_DEFS = {
	{ frames = { "MainActionBar", "MainMenuBar", "ForeverClassicUIBar" }, buttons = "ActionButton" },
	{ frames = { "MultiBarBottomLeft" }, buttons = "MultiBarBottomLeftButton" },
	{ frames = { "MultiBarBottomRight" }, buttons = "MultiBarBottomRightButton" },
	{ frames = { "MultiBarRight" }, buttons = "MultiBarRightButton" },
	{ frames = { "MultiBarLeft" }, buttons = "MultiBarLeftButton" },
	{ frames = { "MultiBar5" }, buttons = "MultiBar5Button" },
	{ frames = { "MultiBar6" }, buttons = "MultiBar6Button" },
	{ frames = { "MultiBar7" }, buttons = "MultiBar7Button" },
}
-- Buttons outside the eight action bars, with their count and their bar (a frame of the bars list): the pet bar, the stance
-- bar, the possess bar and the shaman totem bar. They show a hotkey too.
local EXTRA_BUTTONS = { { "PetActionButton", 10, { "PetActionBar" } }, { "StanceButton", 10, { "StanceBar" } },
	{ "PossessButton", 2, { "PossessActionBar" } }, { "MultiCastActionButton", 12, { "MultiCastActionBarFrame" } } }
local KNOWN_BAR_FRAMES = {}
for i, def in ipairs(BAR_DEFS) do
	DEFAULT_LISTS["bar" .. i] = def.frames
	ALL_LISTS[#ALL_LISTS + 1] = "bar" .. i
	for _, name in ipairs(def.frames) do KNOWN_BAR_FRAMES[name] = true end
end
local EXTRA_GROUPS = { "bars", "player", "hud", "quest", "map", "hidden", "chat", "nav", "rxp", "shift", "mouseover" }
local FADE_ORDER = { "bars", "player", "hud", "quest", "map", "chat", "nav", "rxp", "bags", "micro" }
for _, s in ipairs(SPLIT) do FADE_ORDER[#FADE_ORDER + 1] = s.g end
local HIDE_TOGGLES = { { "reporter", "hideReporter" } }
-- The lists faded through host frames of QuietHUD's, never by setting the frames' own opacity (see Guides.lua): the nav group
-- and the split rows marked host (Naowh's alerts).
local HOSTED = { nav = true }
for _, s in ipairs(SPLIT) do if s.host then HOSTED[s.g] = true end end
-- The order the main loop writes the lists in. A frame in two lists (/qhud add hidden PlayerFrame) belongs to the later one,
-- hidden last of all. A list is written only when its value changes, so such a frame is skipped in every list but its owner
-- (rebuildLists fills woc.owner from this).
local WRITE_ORDER = {}
for _, g in ipairs(FADE_ORDER) do
	WRITE_ORDER[#WRITE_ORDER + 1] = g
	if g == "bars" then
		for i = 1, #BAR_DEFS do WRITE_ORDER[#WRITE_ORDER + 1] = "bar" .. i end
	end
end
for _, pair in ipairs(HIDE_TOGGLES) do WRITE_ORDER[#WRITE_ORDER + 1] = pair[1] end
WRITE_ORDER[#WRITE_ORDER + 1] = "mouseover"
WRITE_ORDER[#WRITE_ORDER + 1] = "hidden"
-- The cast bar fades itself out after a cast: it lowers its own opacity a little each frame and hides itself at 0. Setting its
-- opacity again on every tick would undo that, and the finished bar would stay on screen. So it only gets the group's opacity
-- while a cast is in progress (the game sets it to full when a cast starts); before and after, the game is left alone.
-- The breath, fatigue and feign death timers (the "mirror timers") are treated the same way: they are part of the player row,
-- get its opacity while a timer is running, and a running timer shows the row (see update in Loop.lua).
local SELF_FADING = { PlayerCastingBarFrame = "cast", CastingBarFrame = "cast", MirrorTimerContainer = "mirror",
	MirrorTimer1 = "mirror", MirrorTimer2 = "mirror", MirrorTimer3 = "mirror" }
-- The frames that count for "mouse over" on the Action bars row. The flyouts (the totem bar's column of totems and the arrow
-- that opens it, and Blizzard's spell flyout) open outside their bar, so they count too while they are shown, or the bars
-- would fade the moment the mouse moves up into them. Buttons another addon moved out of their bar are added in rebuildLists.
local ACTION_BARS = {
	"MainActionBar", "MainMenuBar", "ForeverClassicUIBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight",
	"MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7", "MultiBar8", "StanceBar", "PetActionBar", "MultiCastActionBarFrame",
	"MultiCastFlyoutFrame", "MultiCastFlyoutFrameOpenButton", "SpellFlyout",
}
-- Dominos puts the action buttons into bars of its own, named DominosFrame1 to DominosFrame14, with its pet, stance
-- ("class") and possess bars beside them (names from Dominos' frame.lua and bars folder), and has a bag bar and a menu bar.
-- They are one Dominos row (SPLIT). Until that row has a setting of its own they are in the other rows (parts): the bars
-- with the Action bars row (and its mouse over), the bag bar with Bags bar, the menu with Menu bar; then all in the
-- Dominos group (all), and any of them under the mouse shows the row (hover). Dominos tucks the
-- game's own bars under a hidden frame, so those stay out of sight. The names mean nothing without Dominos.
do
	local d = SPLIT_BY.dominos
	local bars = { "DominosFramepet", "DominosFrameclass", "DominosFramepossess" }
	for i = 1, 14 do bars[#bars + 1] = "DominosFrame" .. i end
	d.parts, d.barHover = { bars = {}, bags = { "DominosFramebags" }, micro = { "DominosFramemenu" } }, bars
	d.hoverAll = { "DominosFramebags", "DominosFramemenu" } -- (d.hover while the row has its own settings, see rebuildLists)
	for _, n in ipairs(bars) do
		table.insert(d.parts.bars, n)
		table.insert(d.hoverAll, n)
	end
	-- Its XP bar (Dominos_Progress, ids "exp" and "artifact" in its main.lua): like the game's own XP bar
	-- (StatusTrackingBarManager), not counted for mouse over.
	table.insert(d.parts.bars, "DominosFrameexp")
	table.insert(d.parts.bars, "DominosFrameartifact")
	d.all = {}
	for _, g in ipairs({ "bars", "bags", "micro" }) do
		for _, n in ipairs(d.parts[g]) do d.all[#d.all + 1] = n end
	end
end
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

-- For the files after this one (QuietHUD.toc).
ns.FADE, ns.MOVE_LINGER, ns.SKULL, ns.DEFAULT_LISTS, ns.ALL_LISTS = FADE, MOVE_LINGER, SKULL, DEFAULT_LISTS, ALL_LISTS
ns.BAR_DEFS, ns.EXTRA_BUTTONS, ns.KNOWN_BAR_FRAMES = BAR_DEFS, EXTRA_BUTTONS, KNOWN_BAR_FRAMES
ns.EXTRA_GROUPS, ns.FADE_ORDER, ns.HIDE_TOGGLES, ns.WRITE_ORDER = EXTRA_GROUPS, FADE_ORDER, HIDE_TOGGLES, WRITE_ORDER
ns.HOSTED = HOSTED
ns.SELF_FADING, ns.ACTION_BARS, ns.CHAT_EXTRAS, ns.CHAT_KINDS = SELF_FADING, ACTION_BARS, CHAT_EXTRAS, CHAT_KINDS
ns.chatKindOf = chatKindOf
