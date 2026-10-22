# QuietHUD

<img src="assets/icon.png" width="128" alt="QuietHUD">

A WoW Forever addon that fades the HUD out when you're idle. I made it to save my OLEDs from burn-in, and I also
just don't like a ton of stuff on the screen all the time. Interface 16001, no dependencies. Every element and every trigger is
optional, and nothing is hidden unless you turn it on.

## What it does

Open the settings with `/qhud`, or from the game's options: Esc, Options, AddOns, QuietHUD, "Open QuietHUD settings". It opens on the Elements page, and there are seven pages. Hover a column heading or an element's name to see what it means.

**Elements** (what fades, and what shows each one)
- A grid with a row for each element, in groups. Bars: the action bars (with the stance, pet, totem and XP bars), bags bar and menu bar, plus Dominos while it's loaded. Unit frames: player frame, target and focus, pet frame, party and raid, and the party panel (the side panel that pops out of the arrow tab, with the party markers and Leave Party). Auras and alerts: buffs, debuffs, cooldown trackers and alerts (the durability icon, the loss of control alert, external defensives and the "world will refresh" notice). Info: objective tracker, chat and minimap. Other: damage meter and frames you added. While RestedXP is loaded, its windows get a group at the end.
- Each row has a Fade box, then one box per thing that can show that element: Show in combat, Hide in combat, Moving, Target, Mouse move (while you move the mouse or turn the camera with it), Mouse over, Dungeon or raid (while you're inside one), Weapon drawn, and New info (quest progress for the tracker, new messages for chat, a zone change for the minimap).
- Show in combat and Hide in combat sit together. Ticking one unticks the other. Hide in combat takes the element away completely in a fight, whatever else is ticked and whatever the Faded opacity is. With both empty, the fight doesn't matter.
- Mouse over is optional for every element. For "only on mouse over", leave just that one box ticked in the row. An element with only Fade ticked sits at the Faded opacity all the time, so with Faded at 0 it stays hidden, which is a way to keep the bags bar or the menu bar off.
- On a fresh install everything fades, and comes up in combat, while you move and on mouse over (the tracker, chat and minimap also for New info).
- The cast bar and the breath bar (the underwater timer, which also shows fatigue and feign death) aren't in the grid. They appear by themselves when needed: casting shows the cast bar and a running timer shows the breath bar, even when everything else is faded, so they only have an opacity.
- The minimap's row works like the others. Moving shows it only while you move, an unticked Fade never fades it, and its own Faded slider above 0 keeps it faintly visible.
- An element with Fade unticked is never faded. It stays at its own opacity from the Opacity page, or fully solid when that is Global. So to keep something at 0.5 all the time, untick its Fade and set its own opacity to 0.5.

**Show when** (the settings that go with the Elements columns, under headings named like them)
- Show in combat: how long things stay shown after a fight (up to 3 minutes).
- Weapon drawn: keep my weapon drawn after spells, chests and crafting (off by default, see below).
- Mouse move: how many seconds things stay after the mouse stops.
- New info: how long quest progress or a new zone keeps the tracker, the minimap and RestedXP up (up to 3 minutes). The chat has its own time on the Chat page.
- Player frame: show the player frame while health or power is changing (off by default). Only the player frame comes up, and it fades a few seconds after the last change (3, or 8 for mana), so once you're topped off.
- Fading out: how long elements take to fade out (the chat has its own time on the Chat page).
- Show the whole HUD on demand: while you hold Alt, Ctrl or Shift, or with a key you bind (Esc, Options, Keybindings, AddOns, QuietHUD).

**Opacity** (how solid each thing is)
- Global: one value for Shown and one for Faded (0 hides it completely and reads Hidden). Every element follows Global unless it has its own: under "Shown per element" there's a slider for each element, in two columns and the same groups as the Elements page, where Global (the far left of the slider) follows the global value and any number uses that instead.
- The open bag windows and tooltips, the minimap's own Faded value with a box to darken it instead of making it see-through (see Minimap below), and while RestedXP is loaded, a Shown and Faded pair for its windows and one for its arrow.
- Chat, the minimap, the open bag windows and tooltips are solid until you change them.

**Action bars** (per action bar, Action Bars 1 to 8)
- Whether each bar fades (while Fade is ticked for Action bars on the Elements page, the master switch), and whether to hide its hotkey text or its macro names.
- Optionally shorten the hotkey text on all bars, and on the pet, stance, possess and totem bars: Num Pad 1 shows N1, Mouse Button 4 shows M4, Ctrl plus Num Pad 1 shows cN1, Shift plus 1 shows s1, and so on, so long key names no longer show as "NUM...". Turning it off puts the original text back.

**Chat**
- How long chat stays after a message, the fade out time, and which kinds of message bring it up: whispers, party/raid/instance chat, guild chat, say/yell/emotes from players, channels such as General and Trade, loot/money/XP/reputation, system messages, and NPC speech. By default only whispers, group chat, guild chat and system messages do, so channel chatter, loot and nearby players don't keep waking it. `/qhud debug` prints the event that woke it. Chat's opacity is on the Opacity page.

**Extras**
- Always hidden: the beta Issue Reporter button, the minimap buttons that other addons add, and the party panel. The minimap buttons include the loose ones that sit on the screen and never fade with the minimap; the game's own minimap controls and map pins are left alone, and unticking it shows the buttons again (`/qhud minimapbuttons list` says which ones it hid). The party panel is only made invisible, its arrow tab still works; its row on the Elements page is for fading it instead.
- Open bags (off by default): drag an open bag by its title bar or an empty part of it to move all the open bags together, and where you put them is remembered. The default UI doesn't let you move them. They always stay on the screen. The Reset position button (or `/qhud bags reset`) puts them back. If BlizzMove is installed, QuietHUD leaves the bags to it.
- An experimental pixel shift (below).
- The quest-mob targeting key (experimental), off by default.

**About**
- Who made QuietHUD (and who tested it), links to the website, the CurseForge page and GitHub, ready to copy, the addons it works with, and what to do when something doesn't fade.

At the bottom of every page: Enable QuietHUD (the master switch), Show the whole HUD, and Reset to defaults, which asks first (click it again within five seconds).

Chat comes back on a new message, when you press Enter, or when the mouse is over it. The objective tracker comes back briefly after quest progress. The minimap comes back for a few seconds after a zone change.
## Why you might want each option

**Hide hotkey text (Action bars page).** Action buttons print the key bound to them in their corner. If you play
with an MMO mouse whose side buttons are bound to number-pad keys, that text reads `NUM...` on every
slot, which is noise and not information. A tidy way around it: give each macro a short name like
`n1`, `n2`, `n3`, turn on "Hide hotkeys" for that bar, and the label you see is your own name for the
slot instead of the key. Use "Hide names" if you'd rather hide the macro names and keep the
hotkeys. Each of the 8 bars is separate, so you can hide it only where it bothers you.

**Fade a bar, or leave it out.** A bar you want to see at all times, such as a small utility bar, can
have "Fade" unticked on the Action bars page while the rest still fade.

**Faded opacity.** Zero hides an element completely. A small value like 0.2 leaves a faint ghost of
it, which is handy if you sometimes need to find a button without bringing up the whole HUD. Faded can never be
brighter than Shown, so if you drag one slider past the other, the other one moves with it.

**Weapon drawn.** Draw your weapon (or your wand) to bring things up, sheathe it to send them
away. QuietHUD asks the game whether a weapon is out, so it stays right through fights and the wand.

**Keep my weapon drawn after spells, chests and crafting** (off by default). Out of combat the game puts
your weapon away by itself when you buff, open a chest, pick a lock, craft or loot, and the HUD drops with
it. With this ticked, QuietHUD draws the weapon again as soon as the cast is over, so the HUD stays up. You'll
see your character draw it again. The sheath key still puts it away and hides the HUD. The weapon is
left alone while you're mounted, swimming, dead, on a flight path or in a fight.

**Target.** For people who want the HUD whenever they're interacting with something,
whether or not it's a fight.

**Show the player frame while health or power is changing.** For seeing how far along you are while you eat,
drink or wait on energy between fights, without waking the rest of the HUD. The game doesn't let addons read
your health or power, so QuietHUD goes by them changing: the frame stays while they move and for a few seconds after (3, or 8 for mana, which waits a moment after a cast before it comes back).

**Dungeons and raids.** Every row of the Elements grid has a Dungeon or raid box. Tick one and that element stays shown while you're inside a dungeon or raid
instance (any instance except battlegrounds and arenas), and fades again when you leave. If it doesn't seem to
work, run `/qhud instance` inside the instance and report what it prints.

**Minimap.** Its row in the Elements grid works like any other. Moving fades it
out when you stand still and brings it back when you move, which suits a minimap that's only really useful while
travelling, and New info brings it back for a few seconds after a zone change. Untick Fade to never fade it (it then
stays at its own opacity), and set its Faded slider (Minimap, on the Opacity page) above 0 to keep it faintly visible. By default it's solid while
shown; on the Opacity page, Global makes it follow the global Shown value and any number gives it its own. Below full
opacity the minimap is see-through everywhere. The game draws a blank map in buildings and cities when the minimap
frame is partly transparent, and when it's hidden and shown again, so QuietHUD keeps the frame solid and makes the
map see-through with its round mask instead (the ring, buttons and map pins follow it), and a faded-out minimap is
shrunk to almost nothing rather than hidden. The game's own icons on the map (the player arrow, quest, tracking and
party icons) stay solid, because the game doesn't let addons change their opacity; they only go away when the
minimap fades out completely. "Darken the minimap instead of making it see-through" (on the Opacity page) dims the map with a dark layer instead, which
dims those icons too, but the map isn't see-through. Use whichever you prefer. A square minimap (Leatrix Plus has
that option) works the same way with square masks, and gets a square dark layer. A minimap of another shape keeps its
own mask: it uses real transparency outdoors and the dark layer in buildings and cities.

**A note on the minimap.** Finding a good way to fade the minimap has been an ongoing source of frustration. The game
blanks the map in buildings and cities when it's partly transparent, the player arrow and the quest icons ignore
transparency altogether, and I went back and forth for a long time on whether to just darken it instead. What's
described above is what's in place now. I'll keep looking for better solutions.

**Chat opacity.** By default chat is fully opaque when it appears, so it stays readable.
On the Opacity page, set the Chat slider to Global to dim it to the same level as everything else.

**Bags bar, menu bar, Issue Reporter.** These sit on screen permanently and burn in fastest. The bags bar and the menu
bar are rows of the Elements grid and fade by default, and the beta Issue Reporter button fades with the Menu bar row. Leave only Fade ticked to
keep one hidden (at Faded 0), or untick Fade to keep it solid. Hiding them doesn't disable them: their keybinds
still work.

**Pixel shift (Extras page, experimental, off by default).** OLED panels can burn in from shapes that stay in one place. With this on, the minimap and the objective tracker (plus any frame you add with `/qhud add shift <frame name>`, and two checkboxes for the action bars, bags and menu bar and for the player, target and party frames) move a couple of pixels every few minutes, around a small circle, so the wear is spread out. You choose the distance (1 to 4 pixels) and the minutes between moves. It never changes a saved position: a frame is put back exactly where it was when you turn the option off, when Edit Mode opens and when you log out, and nothing is moved during combat. The action bars and unit frames are protected, so they only move when you're out of combat: in a long fight they stay where they are, and the shift benefits you across fights, not within one. A frame that's anchored to another shifted frame moves with it instead of being shifted twice. If another addon or the game moves a frame while it's shifted, the shift steps aside and takes the new position as the normal one, and an addon that puts a frame straight back every time (ClassicUI Forever does that with the action bars) isn't fought: after three such moves the frame is left alone until the option is turned on again. `/qhud shift` shows what it's doing and `/qhud shift off` puts everything back at once.

## Quest-mob targeting (experimental)

A key that works like Tab, but only through the mobs your quest needs. **It's experimental**: it depends on how
the beta reports quest and tooltip data. It's off by default, and bug reports are welcome. Here's how to use it.

1. **Turn it on.** Open `/qhud`, go to the **Extras** page, and tick "Enable quest-mob targeting key".
2. **Bind a key.** Esc, Options, Keybindings, AddOns, QuietHUD, "Target highlighted quest mob". (In a
   macro, `/click QuietHUDTargetButton` does the same.)
3. **Turn on enemy nameplates.** The key reads the nameplates of the enemies around you to find quest mobs. With
   nameplates off it can still reach a "kill X" objective by name (see below), but not item-drop quests.
4. **Select the quest.** In the objective tracker, click the quest you're working on so it's the
   highlighted (tracked) quest. Its icon gets a glow, and the key then only looks for mobs that quest needs.
   This works for both "kill X" and item-drop quests. The key stays on the quest you picked, even when the game tracks a different one by itself after quest progress, until you click another quest or the quest is done. If no quest is tracked, the key tries every quest in your log, but that's less tested, so clicking the quest is the reliable way. With `/qhud debug` on, each press says which quest it used.
5. **Stand near the mobs and press the key.** It targets a quest mob and puts the skull on it. Press it again and it goes to the next one, nearest first, then round again, the way Tab does. It never targets a mob that isn't a quest mob.

What counts as a quest mob: for "kill X" objectives, mobs with that name. For objectives such as "collect
X", mobs whose tooltip mentions the quest or the item. It skips mobs that another player has already tagged.

How it targets: the game doesn't let an addon target a nameplate directly (the attempt ends with your own character targeted), and a name can't tell identical mobs apart. So the key looks at the enemies with a nameplate around you and picks one of two ways (with `/qhud debug` on, each press says which).

- **Only quest mobs are around.** If two or more quest mobs have a nameplate and no other attackable enemy does, the press is the game's own Tab. Tab then only has quest mobs to choose from, and it steps through identical ones too, so a pack of the same mob is a row of stops.
- **Other enemies are mixed in.** The key targets a quest mob by name, so it can skip the others, but a name always goes to the nearest mob with that name. It steps between different kinds of quest mob, for example a boar, then a nightsaber, then a boar again, and skips the identical ones. To reach a second mob of the same kind, move so it's the nearest, or use Tab or click it.

Range: the key only sees mobs that have a nameplate, and how far nameplates show is a game setting (the
`nameplateMaxDistance` setting), which is often shorter than what Tab or `/target` reach. When no quest mob is on a
nameplate, a "kill X" objective is targeted by name, which reaches as far as `/target` does. It can't do that for
item-drop quests, because it doesn't know which mobs drop the item.

In combat the game locks addon changes to the key, so the key uses what it prepared before the fight. If every enemy near you was a quest mob it's a plain Tab. Otherwise it targets the nearest quest mob it had seen (or the quest's first kill objective) by name with the skull, and it can't step to other kinds until combat ends. If it knew of no quest mob it's a plain Tab plus the skull.
Troubleshooting: "no quest mob found among the nearby enemies" means none of the enemies with a nameplate
matches the highlighted quest. Check that the right quest is highlighted and that you're close enough for
the nameplates to show. The message "quest targeting is off" means the Extras checkbox isn't ticked.
`/qhud debug` prints what the key sees and decides, and saves it so a bug report can include it (type
`/reload` afterwards and look in the addon's saved-variables file).

## Commands

| Command | What it does |
| --- | --- |
| `/qhud` | Open the settings menu |
| `/qhud toggle` | Flip the "weapon drawn" state by hand, until you next draw or sheathe |
| `/qhud peek` | Show the whole HUD for two minutes, or until you use it again. The "Hold to show the whole HUD" key uses `peek down` and `peek up` |
| `/qhud shift [on\|off\|now]` | Pixel shift (experimental): show what it's doing, turn it on or off, or move to its next position now. Off puts every frame back where it was |
| `/qhud reset` | Reset all settings to defaults |
| `/qhud quest`, `/qhud map`, `/qhud chat` | Show that element for a few seconds |
| `/qhud bars` | List the action bar frames the addon found |
| `/qhud state` | Print whether the HUD is currently active or idle, what triggered it, and the real opacity of a few frames |
| `/qhud instance` | Print what the game says about your instance, and whether the HUD is being held on |
| `/qhud where [seconds]` | Print the frame under the mouse and the frames that hold it. With a number of seconds it waits first, so you can move the mouse onto a frame |
| `/qhud mouse` | Watches your right-clicks and prints which frame took one that should have turned the camera, with details about that frame. It says nothing while the camera works. It stays on after a reload until you type it again |
| `/qhud arrow` | Keep the nav group (the arrow) visible until you use it again. Handy as a macro |
| `/qhud hotkeys` | Show the hotkey text of a few action buttons: what the game gives, what's shown, and what the shortening rules make of it |
| `/qhud methods <frame> [text]` | List the functions a frame offers, optionally only those whose name contains some text. For finding out what can be changed on a frame |
| `/qhud find <text>` | Find which frame is showing some text, e.g. a notice you want to hide. If it isn't on screen it keeps watching for 30 minutes |
| `/qhud add bars\|player\|hud\|quest\|map\|chat\|nav\|shift\|hidden [frame name]` | Put a frame into a group (saved). Without a name it uses the frame under the mouse |
| `/qhud remove <name>`, `/qhud list` | Take a frame you added back out, or list them |
| `/qhud bags [reset]` | Show how far the open bags were moved, or put them back where the game puts them at full opacity |
| `/qhud minimapbuttons [on\|off\|list]` | Hide or show the minimap buttons other addons add (the Extras checkbox), or list the ones it's hiding |
| `/qhud hidepanel [on\|off]` | Hide or show the party panel completely (the Extras checkbox) |
| `/qhud debug` | Toggle debug output for the sheath detection and quest targeting |

The `nav` group is for a direction arrow or similar, for example a quest guide's waypoint arrow. Its row on the Elements page (Arrow, in the RestedXP group, while RestedXP is loaded) chooses when it
shows, like any other row. It's faded otherwise. `/qhud nav` says whether a frame is hooked up. Frames in it are faded through a container of ours, so a frame that
sets its own opacity to show and hide itself doesn't fight with the fade.

The `chat` group is for other chat frames that should fade with the chat, such as the window or background of a chat
replacement addon: find the frame with `/qhud find <text from a chat message>`, then `/qhud add chat <frame name>`.

`/qhud add` is for frames the addon doesn't know about, such as a frame from another addon: hover
over it and run the command with the group you want it to fade with (or `hidden` to always hide it). `/qhud add hud`
puts it on the Added frames row.

Keybinds: Esc, Options, Keybindings, AddOns, QuietHUD. You can bind "Toggle Weapon drawn" (the same as `/qhud toggle`), "Hold to show the whole
HUD" (hold it to see everything at once, let go and it fades again), and, if you turn the feature on, "Target highlighted
quest mob". If you'd rather not use a key binding, the Show when page has three checkboxes that show the whole HUD while
you hold Alt, Ctrl or Shift.

## Works with other addons

QuietHUD only changes opacity, and hides what you ask it to hide, so it sits next to unit frame and nameplate addons such as BetterBlizzFrames, BetterBlizzPlates and HealthBarColor. It fades frames by name. A frame from another addon that doesn't fade with the rest (one that ignores its parent's opacity, or one the addon keeps on the screen by itself) can be put into a group with `/qhud add`.

- **Dominos:** while it's loaded there's a Dominos row on the Elements page and a Dominos slider on the Opacity page. It covers Dominos' action bars, its pet, stance and possess bars, its XP bar, its bag bar and its menu. It starts as a copy of your Action bars row the first time you open the settings, and after that the two are separate. I'd leave Dominos' own fade off so the two don't fight.
- **RestedXP:** while it's loaded its guide window, targets and items windows and waypoint arrow are rows on the Elements page (each with its own Fade box), with their own Shown and Faded sliders on the Opacity page. Mouse over counts the whole guide window, not only its bottom bar.
- **ClassicUI Forever:** with its classic bar on, its gryphon band (with the micro menu and bags it draws on the band) fades with Action Bar 1, the action buttons it moves onto the band fade with their bars and come up when you point at them, and its chat scroll arrows and the blinking "to the bottom" arrow fade with the chat. The Bags bar and Menu bar rows have nothing left to do then.
- **Questie:** its quest tracker (Questie hides the game's tracker and shows its own) fades with the Objective tracker row, and its minimap icons fade with the minimap.
- **Chattynator:** its chat window fades with the chat and comes back when you point at it, nothing to add by hand.
- **BetterBlizzFrames:** its pet cast bar fades with the pet frame.
- **Animated Blizzard Portraits:** the 3D portraits it draws on the unit frames (and on RestedXP's target buttons) fade with the frame they sit in. The game doesn't pass a frame's opacity on to a 3D model, so QuietHUD sets the model's own opacity to match.
- **Leatrix Plus:** its square minimap fades, see Minimap above.
- **EllesmereUI:** it's a full UI with its own fading for its bars, so QuietHUD leaves those alone, and it doesn't bring back the game's bars that EllesmereUI hides. It also moves the minimap somewhere QuietHUD's minimap fade doesn't reach (the arrow and its mail button stay), so for its minimap use EllesmereUI's own visibility setting and untick Fade on QuietHUD's Minimap row.

In general, buttons that another addon moves out of their bar are faded by name, so they follow the Action bars page like the rest, and the checkbox on the Extras page hides the minimap buttons other addons add.

## Notes and limits

- Hidden frames still work with their keybinds.
- Quest-mob targeting is experimental. When other enemies are mixed in with the quest mobs it steps between kinds of quest mob but not between identical ones, and in combat it can only use what it prepared before the fight.

## Settings on the Forever beta

Until build 1.60.1.70338 the Forever beta wrote saved variables at logout but never read them back, so
an addon's settings reset every launch. QuietHUD therefore also stores its settings in small
account-wide macros, `QuietHUD data` (and `QuietHUD data 2` when there are many), `QuietHUD bags`,
`QuietHUD opacity`, `QuietHUD groups` and `QuietHUD frames` (the frames you added with `/qhud add`).
Since build 70338 the game reads the saved variables again, and QuietHUD goes by them. The macros are
still written as a backup, out of combat, a moment after a change and at logout, and they're what
QuietHUD falls back on if the saved variables don't load. Please leave them alone. Both
`QuietHUD.toc` and `QuietHUD_Camelot.toc` are shipped, because the client looks for the `_Camelot`
manifest.

## Install

Run `.\install.ps1`, or copy the `QuietHUD` folder into
`World of Warcraft\_classic_beta_\Interface\AddOns\` yourself, including the `masks` folder inside it, then fully
restart the client (it only reads addon manifests and new image files at startup).

## About this addon

I built QuietHUD with Claude Code (AI) and I test it in game myself as I play. It's only been tested
on my setup so far, so expect some rough edges. Bug reports are welcome on GitHub:
https://github.com/Jackafur/quiethud/issues

Made by Jackafur: https://jackafur.com

## License

MIT, see `LICENSE`.
