# Changelog

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
