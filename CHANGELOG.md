# Changelog

## 1.1.4

- The minimap can fade without going blank in interiors. Two things blanked it: hiding the minimap and showing it
  again, and being partly transparent while the game redraws the map of a building interior. Now a faded-out
  minimap is shrunk to almost nothing instead of hidden (which also takes the player and quest arrows, which ignore
  opacity), and indoors the map stays fully opaque and is dimmed with a dark layer instead (which also dims the
  arrows). Outdoors it uses real transparency. "Use the HUD opacity on the minimap" (Elements page, off by default)
  makes it follow "Opacity when active", and "Darken it instead of fading it" uses the dark layer everywhere.
- New option on the Bars page, "Shorten hotkey text" (also covers the pet, stance and possess bars): Num Pad 1 shows N1, Mouse Button 4 shows M4, Ctrl plus Num Pad 1
  shows cN1, Shift plus 1 shows s1, and so on, so long key names stop showing as "NUM...". Off by default; turning it off restores the original text.
- Shortened hotkey text also widens the text slot to the width of the button, so it is not cut off with "...".
  New `/qhud hotkeys` shows what the game gives for a few buttons and what the rules make of it.
- New `/qhud methods <frame> [text]` command that lists what a frame offers, for working out what can be changed.

## 1.1.3

- New Chat page: choose which kinds of message bring the chat up (whispers, party/raid/instance, guild, say/yell/
  emotes, channels, loot and XP, system messages, NPC speech). The defaults are quieter: only whispers, group
  chat, guild chat and system messages. Before, every kind including channel chatter and loot woke it. The
  "chat stays" slider moved here from Extras. `/qhud debug` now prints the event that woke the chat.
- The player cast bar now fades with the player frame.
- "Only while I am moving" now detects movement two ways (walking speed, and whether your position changed), so
  it no longer depends on the game reporting your speed. `/qhud state` also saves what it prints to the trace
  file and says how movement was detected.
- The minimap is now fully solid when it is shown, instead of taking the HUD opacity. In cities and interiors
  the map could come up blank at partial opacity. A short log of the minimap's decisions is also kept and saved
  with the settings, so a minimap that does not show can be diagnosed afterwards.
- New `/qhud find <text>` finds the frame showing some text, and `/qhud add <group> <frame name>` adds a frame by
  name, so a notice can be hidden without hovering it.

## 1.1.2

- Quest targeting reworked. The game lets an addon change the target only once per key press, so the old idea
  of pressing Tab repeatedly until a quest mob turned up could not work, and it kept stopping on mobs that were
  not quest mobs and skull-marking them. The key now reads the enemy nameplates, picks the nearest quest mob
  and targets it by name, with the skull. It never targets a mob that is not a quest mob. The limit is that a
  pack of identically named mobs is always entered at its nearest one: kill it and press again for the next.
- With enemy nameplates off the key now says so and does nothing, instead of pressing Tab blindly.
- `/qhud debug` for the quest key now prints the quest it is using, the words it looks for, every nameplate and
  why each counted or not, and what it decided, and it keeps this in the addon's saved-variables file (written
  on `/reload`) so a report can include it.

## 1.1.1

- Quest targeting now checks the nearby enemy nameplates for a quest mob before it presses Tab. If there is
  none it does nothing, instead of targeting and skull-marking a mob that is not a quest mob.

## 1.1.0

Known limits: the dungeon and raid option has not been tested inside an actual instance yet, and quest-mob
targeting is still a work in progress.

- New option "Always show in dungeons and raids" (Show when page, off by default). The settings window is
  one row taller to fit it.
- The two opacity sliders no longer conflict: idle can not go above the shown opacity, and dragging one past
  the other carries the other along. The idle slider now goes up to 1.00 instead of stopping at 0.50.
- The opacity sliders are now labeled "Opacity when active" and "Opacity when idle", and the README says they
  apply to everything that fades.
- New `/qhud state` command that prints whether the HUD is active or idle, what triggered it, and the real
  opacity of a few frames.
- Quest targeting with no quest highlighted now checks every quest in your log the same precise way as a
  highlighted one, instead of using the game's looser "related to a quest" flag, which could stop on mobs that
  are not quest mobs.
- New `/qhud instance` command that prints what the game reports about your instance.
- The two overlapping minimap checkboxes are now one labeled row with a button that cycles four modes: follows
  the HUD, only while moving, always shown, and a new "always on, dimmed" mode with its own opacity slider.

## 1.0.1

- The quest-mob targeting key now works in combat. The game locks addon changes to secure buttons in
  combat, so there it falls back to a plain Tab plus the skull marker, without the quest check.
  Out of combat it behaves as before.

## 1.0.0

First release, for the Forever (Classic+ beta) client, build 1.60.1.

- Fades the HUD when idle and brings it back on combat, weapon drawn, a target, mouse over, chat
  activity, quest progress, zone changes and movement. Every element and trigger is a toggle.
- Settings menu with four pages (Show when, Elements, Bars, Extras), idle opacity, per-action-bar
  fade, hotkey text and macro name hiding, and a reset button.
- Settings persist on the Forever beta by also storing them in an account-wide macro, working around
  the client not reading saved variables back.
- Experimental quest-mob targeting key: presses Tab until it lands on a mob your highlighted quest
  needs, then puts the skull on it.
