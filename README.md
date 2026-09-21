# QuietHUD

A World of Warcraft Forever addon (for the Classic+ beta client) that fades the HUD out when idle, to protect
OLED panels. Interface 16001, no dependencies. Every element and every trigger is
optional, and nothing is hidden unless you turn it on.

## What it does

Open the settings with `/qhud`. There are six pages.

**Show when** (what brings the HUD back)
- Master on/off switch, opacity when active (something woke the HUD), and opacity when idle (nothing is
  going on, 0 hides it completely). Both apply to everything that fades, not just one element.
- Show in combat, while your weapon is drawn, or while you have a target. These three decide when the HUD is "awake".
- How long the HUD stays after combat. Together these decide when the HUD is "awake", one of the things that
  can bring each element up (see Elements).

**Elements** (what fades, and what brings each one back)
- A grid with a row for the action bars, player frame, enemy, party and other frames and buffs, objective tracker,
  chat, minimap, bags bar and menu bar. Each row has a Fade box, then one box per thing that can bring that element
  up: Awake (combat, a drawn weapon or a target, from the Show when page), While moving, Mouse over and Dungeon or
  raid (while you are inside one), and Hide in combat, which beats the rest. The tracker, chat and minimap also have New
  info (quest progress for the tracker, new messages for chat, a zone change for the minimap).
- Mouse over is optional for every element. For "only on mouse over", leave just that one box ticked in the row.
  The defaults are what each element did before the grid existed. The durability icon and the loss of control alert follow the Enemy, party, buffs row. An element with only Fade ticked sits at the idle
  opacity all the time, so with idle at 0 it stays hidden, which is a way to keep the bags bar or the menu bar off.
- The minimap has no mode button any more. Awake makes it follow the HUD, While moving shows it only while you
  move, an unticked Fade never fades it, and "Minimap opacity when idle" above 0 keeps it faintly visible. Chat can
  either stay fully opaque or use the HUD opacity.

**Bars** (per action bar, Action Bars 1 to 8)
- Whether each bar fades (while Fade is ticked for Action bars on the Elements page, the master switch), and whether to hide its hotkey text or its macro names.
- Optionally shorten the hotkey text on all bars, and on the pet, stance and possess bars: Num Pad 1 shows N1, Mouse Button 4 shows M4, Ctrl plus Num Pad 1 shows cN1, Shift plus 1
  shows s1, and so on, so long key names no longer show as "NUM...". Turning it off puts the original text back.

**Chat**
- How long chat stays after a message, and which kinds of message bring it up: whispers, party/raid/instance
  chat, guild chat, say/yell/emotes from players, channels such as General and Trade, loot/money/XP/reputation,
  system messages, and NPC speech. By default only whispers, group chat, guild chat and system messages do, so
  channel chatter, loot and nearby players do not keep waking it. `/qhud debug` prints the event that woke it.

**Extras**
- How long new quest progress keeps the tracker up, and a zone change keeps the minimap up. (After you stop moving, the "While moving" boxes hold for a fixed 1.5 seconds.)
- A checkbox to hide the beta Issue Reporter. (The bags bar and the menu bar are rows of the Elements grid.)
- A tooltip opacity slider (the whole tooltip, text included), and an experimental pixel shift (below).
- The quest-mob targeting key (experimental), off by default.
- Reset to defaults.

Chat comes back on a new message, when you press Enter, or when the mouse is over it. The objective
tracker comes back briefly after quest progress. The minimap comes back for a few seconds after a zone
change.

## Why you might want each option

**Hide hotkey text (Bars page).** Action buttons print the key bound to them in their corner. If you play
with an MMO mouse whose side buttons are bound to number-pad keys, that text reads `NUM...` on every
slot, which is noise and not information. A tidy way around it: give each macro a short name like
`n1`, `n2`, `n3`, turn on "Hide hotkeys" for that bar, and the label you see is your own name for the
slot instead of the key. Use "Hide names" if you would rather hide the macro names and keep the
hotkeys. Each of the 8 bars is separate, so you can hide it only where it bothers you.

**Fade a bar, or leave it out.** A bar you want to see at all times, such as a small utility bar, can
have "Fade" unticked on the Bars page while the rest still fade.

**Opacity when idle.** Zero hides an element completely. A small value like 0.2 leaves a faint ghost of
it, which is handy if you sometimes need to find a button without waking the whole HUD. Idle can never be
brighter than the "active" opacity, so if you drag one slider past the other, the other one moves with it.

**Show while my weapon is drawn.** WoW cannot tell an addon whether your weapon is out, so this follows
your Toggle Sheath key. Draw your weapon to bring the HUD up, sheathe it to send it away.

**Show while I have a target.** For people who want the HUD whenever they are interacting with something,
whether or not it is a fight.

**Dungeons and raids.** Every row of the Elements grid has a Dungeon or raid box. Tick one and that element stays shown while you are inside a dungeon or raid
instance (any instance except battlegrounds and arenas), and fades again when you leave. If it does not seem to
work, run `/qhud instance` inside the instance and report what it prints.

**Minimap.** Its row in the Elements grid works like any other. Awake makes it follow the HUD. While moving fades it
out when you stand still and brings it back when you move, which suits a minimap that is only really useful while
travelling, and New info brings it back for a few seconds after a zone change. Untick Fade to never fade it, and set
"Minimap opacity when idle" above 0 to keep it faintly visible. The minimap can be made transparent, with catches. The
game draws a blank map in building interiors if the minimap is hidden and shown again, or is partly transparent while
it redraws the interior. So a faded-out minimap is shrunk to almost nothing instead of hidden, and indoors the map
stays fully opaque and is dimmed with a dark layer instead (which also dims the player and quest arrows, which ignore
transparency). Outdoors it uses real transparency. By default it stays fully solid while showing; tick "Minimap: use
the HUD opacity when shown, not solid" to make it follow "Opacity when active". "Minimap: darken it instead of
fading it" uses the dark layer everywhere, not just indoors.
**Chat uses the HUD opacity.** By default chat is fully opaque when it appears, so it stays readable.
Tick this if you want it dimmed to the same level as everything else.

**Bags bar, menu bar, Issue Reporter.** These sit on screen permanently and burn in fastest. The bags bar and the menu
bar are rows of the Elements grid: tick Fade and leave the other boxes empty to keep one hidden (at idle opacity 0), or
tick Awake and Mouse over to have it appear when needed. Hiding them does not disable them: their keybinds still work.

**Pixel shift (Extras page, experimental, off by default).** OLED panels can burn in from shapes that stay in one place. With this on, the minimap and the objective tracker (plus any frame you add with `/qhud add shift <frame name>`, and two checkboxes for the action bars, bags and menu bar and for the player, target and party frames) move a couple of pixels every few minutes, around a small circle, so the wear is spread out. You choose the distance (1 to 4 pixels) and the minutes between moves. It never changes a saved position: a frame is put back exactly where it was when you turn the option off, when Edit Mode opens and when you log out, and nothing is moved during combat. The action bars and unit frames are protected, so they only move when you are out of combat: in a long fight they stay where they are, and the shift benefits you across fights, not within one. A frame that is anchored to another shifted frame moves with it instead of being shifted twice. If another addon or the game moves a frame while it is shifted, the shift steps aside and takes the new position as the normal one. `/qhud shift` shows what it is doing and `/qhud shift off` puts everything back at once.

## Quest-mob targeting (experimental)

A key that works like Tab, but only through the mobs your quest needs. **It is experimental**: it depends on how
the beta reports quest and tooltip data. It is off by default, and bug reports are welcome. Here is how to use it.

1. **Turn it on.** Open `/qhud`, go to the **Extras** page, and tick "Enable quest-mob targeting key".
2. **Bind a key.** Esc, Options, Keybindings, AddOns, QuietHUD, "Target highlighted quest mob". (In a
   macro, `/click QuietHUDTargetButton` does the same.)
3. **Turn on enemy nameplates.** The key reads the nameplates of the enemies around you to find quest mobs. With
   nameplates off it can still reach a "kill X" objective by name (see below), but not item-drop quests.
4. **Select the quest.** In the objective tracker, click the quest you are working on so it is the
   highlighted (tracked) quest. Its icon gets a glow, and the key then only looks for mobs that quest needs.
   This works for both "kill X" and item-drop quests. The key stays on the quest you picked, even when the game tracks a different one by itself after quest progress, until you click another quest or the quest is done. If no quest is tracked, the key tries every quest in your log, but that is less tested, so clicking the quest is the reliable way. With `/qhud debug` on, each press says which quest it used.
5. **Stand near the mobs and press the key.** It targets a quest mob and puts the skull on it. Press it again and it goes to the next one, nearest first, then round again, the way Tab does. It never targets a mob that is not a quest mob.

What counts as a quest mob: for "kill X" objectives, mobs with that name. For objectives such as "collect
X", mobs whose tooltip mentions the quest or the item. It skips mobs that another player has already tagged.

How it targets: the game does not let an addon target a nameplate directly (the attempt ends with your own character targeted), and a name cannot tell identical mobs apart. So the key looks at the enemies with a nameplate around you and picks one of two ways (with `/qhud debug` on, each press says which).

- **Only quest mobs are around.** If two or more quest mobs have a nameplate and no other attackable enemy does, the press is the game's own Tab. Tab then only has quest mobs to choose from, and it steps through identical ones too, so a pack of the same mob is a row of stops.
- **Other enemies are mixed in.** The key targets a quest mob by name, so it can skip the others, but a name always goes to the nearest mob with that name. It steps between different kinds of quest mob, for example a boar, then a nightsaber, then a boar again, and skips the identical ones. To reach a second mob of the same kind, move so it is the nearest, or use Tab or click it.

Range: the key only sees mobs that have a nameplate, and how far nameplates show is a game setting (the
`nameplateMaxDistance` setting), which is often shorter than what Tab or `/target` reach. When no quest mob is on a
nameplate, a "kill X" objective is targeted by name, which reaches as far as `/target` does. It cannot do that for
item-drop quests, because it does not know which mobs drop the item.

In combat the game locks addon changes to the key, so the key uses what it prepared before the fight. If every enemy near you was a quest mob it is a plain Tab. Otherwise it targets the nearest quest mob it had seen (or the quest's first kill objective) by name with the skull, and it cannot step to other kinds until combat ends. If it knew of no quest mob it is a plain Tab plus the skull.
Troubleshooting: "no quest mob found among the nearby enemies" means none of the enemies with a nameplate
matches the highlighted quest. Check that the right quest is highlighted and that you are close enough for
the nameplates to show. The message "quest targeting is off" means the Extras checkbox is not ticked.
`/qhud debug` prints what the key sees and decides, and saves it so a bug report can include it (type
`/reload` afterwards and look in the addon's saved-variables file).

## Commands

| Command | What it does |
| --- | --- |
| `/qhud` | Open the settings menu |
| `/qhud toggle` | Flip the "weapon drawn" state by hand |
| `/qhud peek` | Show the whole HUD for two minutes, or until you use it again. The "Hold to show the whole HUD" key uses `peek down` and `peek up` |
| `/qhud shift [on\|off\|now]` | Pixel shift (experimental): show what it is doing, turn it on or off, or move to its next position now. Off puts every frame back where it was |
| `/qhud reset` | Reset all settings to defaults |
| `/qhud quest`, `/qhud map`, `/qhud chat` | Show that element for a few seconds |
| `/qhud bars` | List the action bar frames the addon found |
| `/qhud state` | Print whether the HUD is currently active or idle, what triggered it, and the real opacity of a few frames |
| `/qhud instance` | Print what the game says about your instance, and whether the HUD is being held on |
| `/qhud where [seconds]` | Print the frame under the mouse and the frames that hold it. With a number of seconds it waits first, so you can move the mouse onto a frame |
| `/qhud mouse` | Watches your right-clicks and prints which frame took one that should have turned the camera, with details about that frame. It says nothing while the camera works. It stays on after a reload until you type it again |
| `/qhud arrow` | Keep the nav group (the arrow) visible until you use it again. Handy as a macro |
| `/qhud hotkeys` | Show the hotkey text of a few action buttons: what the game gives, what is shown, and what the shortening rules make of it |
| `/qhud methods <frame> [text]` | List the functions a frame offers, optionally only those whose name contains some text. For finding out what can be changed on a frame |
| `/qhud find <text>` | Find which frame is showing some text, e.g. a notice you want to hide. If it is not on screen it keeps watching for 30 minutes |
| `/qhud add bars\|player\|hud\|quest\|map\|chat\|nav\|shift\|hidden [frame name]` | Put a frame into a group (saved). Without a name it uses the frame under the mouse |
| `/qhud remove <name>`, `/qhud list` | Take a frame you added back out, or list them |
| `/qhud debug` | Toggle debug output for the sheath detection and quest targeting |

The `nav` group is for a direction arrow or similar, for example a quest guide's waypoint arrow. Its row of the trigger grid (on the RXP tab) chooses when it
shows: while you move, when the HUD is awake, on mouse over, and whether it hides in combat. It is faded otherwise. `/qhud nav` says whether a frame is hooked up. Frames in it are faded through a container of ours, so a frame that
sets its own opacity to show and hide itself does not fight with the fade.

**RXP** (only useful with the RestedXP guide addon installed)
- Fade its guide window, its active targets and active items windows (one checkbox for both) and its waypoint arrow.
  No commands needed.
- Two sliders set how solid the guide, targets and items windows are when shown and when idle (0 hides them completely, a
  small value leaves them faintly visible), and the arrow has its own pair.
- A row of trigger columns for the guide, targets and items together, and one for the arrow, the same as on the Elements
  page. Mouse over counts the whole guide window, not only its bottom bar.

The `chat` group is for other chat frames that should fade with the chat, such as the window or background of a chat
replacement addon: find the frame with `/qhud find <text from a chat message>`, then `/qhud add chat <frame name>`.

`/qhud add` is for frames the addon does not know about, such as a frame from another addon: hover
over it and run the command with the group you want it to fade with (or `hidden` to always hide it).

Keybinds: Esc, Options, Keybindings, AddOns, QuietHUD. You can bind "Show/hide HUD", "Hold to show the whole
HUD" (hold it to see everything at once, let go and it fades again), and, if you turn the feature on, "Target highlighted
quest mob". If you would rather not use a key binding, the Extras page has three checkboxes that show the whole HUD while
you hold Alt, Ctrl or Shift.

## Notes and limits

- WoW does not expose whether your weapon is sheathed, so the addon follows the Toggle Sheath key and
  assumes the weapon is drawn when combat starts. If it drifts, use `/qhud toggle`.
- Hidden frames still work with their keybinds.
- Quest-mob targeting is experimental. When other enemies are mixed in with the quest mobs it steps between kinds of quest mob but not between identical ones, and in combat it can only use what it prepared before the fight.

## Settings on the Forever beta

The Forever beta (build 1.60.1.69913) writes saved variables at logout but never reads them back, so
an addon's settings would reset every launch. QuietHUD keeps its normal saved variable, which starts
working as soon as Blizzard fixes this, and also stores its settings in an account-wide macro named
`QuietHUD data`, which the client does save and reload. Please leave that macro alone. Both
`QuietHUD.toc` and `QuietHUD_Camelot.toc` are shipped, because the client looks for the `_Camelot`
manifest.

## Install

Run `.\install.ps1`, or copy the `QuietHUD` folder into
`World of Warcraft\_classic_beta_\Interface\AddOns\` yourself, then fully restart the client (it only
reads addon manifests at startup).

## About this addon

QuietHUD was built with AI assistance (Claude Code) and tested in game by the author. It has only been
tested on one setup so far, so expect some rough edges. Bug reports are welcome on GitHub:
https://github.com/Jackafur/quiethud/issues

## License

MIT, see `LICENSE`.
