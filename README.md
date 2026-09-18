# QuietHUD

A World of Warcraft addon that fades the HUD out when idle, to protect OLED panels. Built for the
Forever (Classic+ beta) client, interface 16001, no dependencies. Every element and every trigger is
optional, and nothing is hidden unless you turn it on.

## What it does

Open the settings with `/qhud`. There are four pages.

**Show when** (what brings the HUD back)
- Master on/off switch, opacity when active (something woke the HUD), and opacity when idle (nothing is
  going on, 0 hides it completely). Both apply to everything that fades, not just one element.
- Show in combat, while your weapon is drawn, while you have a target, or always in dungeons and raids.
- Show the action bars on mouse over, and how long the HUD stays after combat.

**Elements** (what fades, each one optional)
- Action bars, player frame, target/party/raid frames and buffs, minimap, objective tracker, chat.
- The minimap has its own row with a button that cycles four modes: follows the HUD (fades with everything
  else), only while you are moving, always shown, or always on but dimmed. Chat can either stay fully opaque
  or use the HUD opacity.

**Bars** (per action bar, Action Bars 1 to 8)
- Whether each bar fades, and whether to hide its hotkey text or its macro names.

**Extras**
- How long chat and the tracker/minimap stay after new activity.
- Optional hiding of the bags bar, the menu bar and the beta Issue Reporter.
- The quest-mob targeting key (work in progress), off by default.
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

**Always show in dungeons and raids.** Inside a dungeon or raid instance (any instance except battlegrounds
and arenas) the HUD stays fully shown, including the minimap even if it is set to show only while moving,
and fades again when you leave. Chat still follows its own rules. If it does not seem to work, run
`/qhud instance` inside the instance and report what it prints.

**Minimap mode.** Click the button on the Elements page to cycle. "Follows the HUD" treats the minimap like
every other element. "Only while I am moving" fades it out the moment you stand still and brings it back when
you move or change zone, which suits a minimap that is only really useful while travelling. "Always shown"
never fades it. "Always on, dimmed" keeps it faintly visible at its own opacity (a slider appears when you pick
this mode) and brightens it when you move or the rest of the HUD wakes up.

**Chat uses the HUD opacity.** By default chat is fully opaque when it appears, so it stays readable.
Tick this if you want it dimmed to the same level as everything else.

**Hide bags, menu bar, Issue Reporter.** These sit on screen permanently and burn in fastest. Hiding them
does not disable them: their keybinds still work.

## Quest-mob targeting (work in progress)

A key that targets a mob your quest needs and puts the skull marker on it. **It is a work in progress**: it
depends on how the beta reports quest and tooltip data, and it cannot do everything a Tab key can (see below).
It is off by default, and bug reports are welcome. Here is how to use it.

1. **Turn it on.** Open `/qhud`, go to the **Extras** page, and tick "Enable quest-mob targeting key".
2. **Bind a key.** Esc, Options, Keybindings, AddOns, QuietHUD, "Target highlighted quest mob". (In a
   macro, `/click QuietHUDTargetButton` does the same.)
3. **Turn on enemy nameplates.** The key reads the nameplates of the enemies around you to find quest mobs.
   With nameplates off it tells you so and does nothing. If no nearby enemy is a quest mob it also does
   nothing: no target change and no skull.
4. **Select the quest.** In the objective tracker, click the quest you are working on so it is the
   highlighted (tracked) quest. Its icon gets a glow, and the key then only looks for mobs that quest needs.
   This works for both "kill X" and item-drop quests. If no quest is highlighted, the key tries every quest in
   your log, but that is less tested, so clicking the quest is the reliable way.
5. **Stand near the mobs and press the key.** It targets the nearest mob the quest needs and puts the skull on
   it. It never targets a mob that is not a quest mob. Press it again and it moves to a different kind of
   quest mob if there is one.

What counts as a quest mob: for "kill X" objectives, mobs with that name. For objectives such as "collect
X", mobs whose tooltip mentions the quest or the item. It skips mobs that another player has already tagged.

What it cannot do: pick one mob out of several that share the same name. It targets by name, so with a pack
of identical mobs it goes to the nearest one. Kill it and press again for the next. This is a limit of the
game, which lets an addon change the target only once per key press, so it cannot press Tab repeatedly until
it reaches a quest mob. Pressing Tab yourself has the same problem, because it cycles through every enemy.

In combat the key still works, but as a plain Tab plus the skull marker. The game locks addon changes to
secure buttons during combat, so the addon cannot look at the mobs and pick a quest mob there. It goes back
to the full quest-aware behavior as soon as combat ends.

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
| `/qhud reset` | Reset all settings to defaults |
| `/qhud quest`, `/qhud map`, `/qhud chat` | Show that element for a few seconds |
| `/qhud bars` | List the action bar frames the addon found |
| `/qhud state` | Print whether the HUD is currently active or idle, what triggered it, and the real opacity of a few frames |
| `/qhud instance` | Print what the game says about your instance, and whether the HUD is being held on |
| `/qhud where` | Print the name of the frame under the mouse |
| `/qhud add bars\|player\|hud\|quest\|map\|hidden` | Put the frame under the mouse into a group (saved) |
| `/qhud remove <name>`, `/qhud list` | Take a frame you added back out, or list them |
| `/qhud debug` | Toggle debug output for the sheath detection and quest targeting |

`/qhud add` is for frames the addon does not know about, such as a frame from another addon: hover
over it and run the command with the group you want it to fade with (or `hidden` to always hide it).

Keybinds: Esc, Options, Keybindings, AddOns, QuietHUD. You can bind "Show/hide HUD" and, if you turn
the feature on, "Target highlighted quest mob".

## Notes and limits

- WoW does not expose whether your weapon is sheathed, so the addon follows the Toggle Sheath key and
  assumes the weapon is drawn when combat starts. If it drifts, use `/qhud toggle`.
- Hidden frames still work with their keybinds.
- Quest-mob targeting is a work in progress, and in combat it is only a plain Tab plus the skull.

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
