# Changelog

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
