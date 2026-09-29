# Changelog

## 1.3.2

Works with ClassicUI Forever's classic bar. Your settings carry over.

### Changed

- **The bags bar and the menu bar fade by default**, like the rest of the HUD. They sit on screen all the time and burn in fastest, and new users did not realize those two rows were off. They come back with Awake and Mouse over, the same as the action bars. If you had never changed those two rows, they start fading after this update; to keep one solid, untick Fade on its row on the Elements page.

### Fixed

- **Action buttons that another addon moves out of their bar** (ClassicUI Forever puts every button into a holder of its own) fade with the bars now, and pointing at them brings the bars up. Before, the buttons stayed solid while the HUD faded, or came up faded after a target change while everything else woke, because that addon copies the bar's opacity into its holder only when it lays the bar out again. While QuietHUD fades their bar, those buttons ignore the holder's copy; they follow their parent again when they are back in their bar or when the bar is not faded.
- **ClassicUI Forever's gryphon bar** (the stone band and gryphons, with the micro menu and bags it draws on them) fades with Action Bar 1, like the old MainMenuBar did, and counts for mouse over. Its micro menu and bags follow the Action bars row, not the Bags bar and Menu bar rows, because that addon draws both on the band.
- **Chat scroll arrows restyled by another addon** (ClassicUI Forever's) stayed solid while the chat faded, because their pictures ignore the chat window's opacity. Pictures that do are faded on their own now.
- **The pixel shift no longer fights an addon that puts a frame straight back** (ClassicUI Forever lays its bar out again whenever the game's bar frames move, so the bags jumped once a second). After three such moves the frame is left alone until the option is turned on again, and `/qhud shift` says so.

## 1.3.1

Mostly for shamans. Your settings carry over.

### Added

- **The shaman totem bar** (the bar with the totem buttons) fades with the action bars now. It follows the Action bars row on the Elements page, like the stance and pet bars, counts for mouse over (its column of totems that opens above it too, so the bars stay up while you pick a totem; Blizzard's spell flyouts on the action bars count the same way), moves with the bars' pixel shift, and gets the shorter hotkey text. The small totem timers next to the player frame already faded with Buffs and debuffs.

### Fixed

- **A Lua error from the totem bar** (a Blizzard bug, worked around): when the totem bar comes up before the shaman has trained Call of the Elements and Totemic Recall (level 20), for example when it is turned on in Edit Mode on a new shaman, Blizzard leaves those two buttons visible without a spell, and pointing at one throws an error. While such a button has no spell it now ignores the mouse, and it works normally once the spell is learned. This is a temporary workaround until Blizzard fixes it.

## 1.3.0

Your settings carry over. This version adds a `masks` folder with image files, so restart the game fully once after updating (a `/reload` does not pick up new files).

A word on the minimap first. Finding a good way to fade it has been an ongoing source of frustration. The game draws a blank map in buildings and cities whenever the minimap is partly transparent, and the map breaks the same way if it is hidden and shown again. On top of that, the player arrow and the quest icons the game draws on the map ignore transparency completely, and I went back and forth for a long time on whether to just darken the whole thing instead. I'll keep looking for better solutions. What is in place now: the map fades with real transparency everywhere, the game's own icons stay solid until the minimap has faded out completely, and if you would rather have everything dimmed together, the darken checkbox is still there. The details are below, along with the other changes.

### Changed

- **The minimap fades with real transparency everywhere**, in buildings and cities too, where it used to be dimmed with a dark layer. The game draws a blank map in cities and buildings when the minimap frame is partly transparent, so QuietHUD no longer fades that frame at all. The map fades through its round mask instead (QuietHUD brings mask images with the opacity built in, in 5% steps), and the ring, buttons, zone name, clock and map pins fade with it. This also fixes a blank minimap in cities such as Stormwind, whose streets count as outdoors. The game's own icons on the map (the player arrow, quest, tracking and party icons) stay solid, because the game does not let addons change their opacity; they go away when the minimap fades out completely. The "darken" checkbox, now called "Minimap: darken instead of see-through", dims them with the map, but the map is not see-through; a note on the Elements page explains the choice. A square minimap (Leatrix Plus has that option) gets the same see-through fade with square masks, and a square dark layer when darkened. A minimap of another shape keeps its own mask and fades the old way.

### Added

- **A fixed opacity without fading.** An element with Fade unticked on the Elements page now stays at its own opacity from the Opacity page, so to keep something at 0.5 all the time, untick its Fade and set its own opacity to 0.5. With its opacity on Global it stays fully solid, as before. If you had unticked Fade for something that has an opacity of its own, it now sits at that opacity instead of fully solid.
- **`/qhud fakeinstance [on|off]`**, a test switch. QuietHUD acts as if you were inside a dungeon or raid, so the "Dungeon or raid" column on the Elements page can be tried without entering one. It only changes what QuietHUD believes, it is not saved, and a `/reload` ends it. `/qhud instance` says when it is on.

### Fixed

- **RestedXP's targets window flickered** when you changed target while it was faded. RestedXP sets it to full opacity each time it redraws the list, and QuietHUD only put its own opacity back a frame later. It now puts it back at once.
- **Tooltips could flash at full opacity** when you moved the mouse quickly from one thing to the next. The game puts a tooltip back to full opacity when it gets new content while already shown, and QuietHUD only caught a tooltip being shown for the first time. It now puts its opacity back at once in that case too.

## 1.2.2

Fixes. Your settings carry over, and nothing changes unless you use the addon or option named below.

### Fixed

- **Frames you added with `/qhud add` were forgotten.** They were stored in the main settings macro, which holds only 255 characters. Once your settings had grown enough that one more frame did not fit, every added frame was dropped at the next reload (a chat window that had been added to the chat group faded until then, and then stopped). They now have a macro of their own, `QuietHUD frames`, and what you had added carries over by itself. If there are ever too many to fit, QuietHUD says so and keeps the ones that fit.
- **Show/hide HUD now** (settings window) did nothing unless the weapon-sheath option was on. It now shows the whole HUD, the same as `/qhud peek`, and pressing it again puts things back.

### Changed

- **Chattynator's chat window** is part of the chat group by itself now, with no `/qhud add` needed. Its container frame has no size of its own (the window is a child of it), so "mouse over" for the chat now also looks at the children of the frames in the chat group. That also means a chat window you added by hand comes back when you point at it. Nothing changes without that addon.

### Good to know

The frames you add with `/qhud add` are kept in a fifth small macro, `QuietHUD frames`, next to `QuietHUD data`, `QuietHUD bags`, `QuietHUD opacity` and `QuietHUD groups`. Please leave it alone with the others.

## 1.2.1

Small additions. Your settings carry over, and nothing changes until you use the new options, except that the party panel now fades with the rest of the HUD.

### New

- **Party panel row.** The side panel that pops out of the arrow tab on the left (Party 1/1, the markers, Leave Party) now has its own row on the Elements and Opacity pages, so it fades like the other elements. It starts with the values of the old Enemy, party, buffs row.
- **Hide the party panel.** An Extras checkbox (and `/qhud hidepanel [on|off]`) that hides the panel completely. It is only made invisible, its arrow tab still works.
- **Hide other addons' minimap buttons.** An Extras checkbox (and `/qhud minimapbuttons [on|off|list]`) that hides the round buttons other addons put around the minimap, including the loose ones that sit on the screen and never fade with the minimap. The game's own minimap controls and the map pins are left alone, untick it to show the buttons again, and `list` says which ones it hid. It is off by default.

### Changed

- BetterBlizzFrames' pet cast bar is a separate frame on the screen, so it did not fade with the pet frame. It is now part of the Pet frame row. Nothing changes without that addon.
- The README says how settings are saved on the Forever beta (the four `QuietHUD` macros) and which addons QuietHUD works next to.

### Good to know

The two new checkboxes are kept in the small `QuietHUD groups` macro, next to the ones from 1.2.0. Please leave those macros alone.
## 1.2.0

A bigger update: the settings are reorganized, and there is a lot more control over how solid each part of the HUD is. Your settings carry over, and the new rows start with the values of the old Enemy, party, buffs row, so nothing changes until you change it.

### New

- **Opacity page.** One global value for when the HUD is active and one for when it is idle. Every element follows the global value unless it has its own: a row for each element, where Global (the far left) follows the global value and a number uses that instead. Chat, the minimap, open bags and tooltips are solid until you change them.
- **The Enemy, party, buffs row is split** into Target and focus, Pet frame, Party and raid, Buffs and debuffs, Cooldown trackers, Damage meter and Alerts (durability, loss of control, external defensives). Each has its own Fade box, triggers and opacity.
- **Cast bar and breath bar** have their own opacity. Casting shows the cast bar, and a running breath, fatigue or feign death timer shows the breath bar, even when the HUD is idle. A finished cast bar no longer gets stuck on screen.
- **Open bags can be moved and dimmed.** Drag any open bag by its title bar or an empty part of it and all the open bags move together. Where you put them is remembered, and `/qhud bags reset` puts them back.
- **Show when** now holds everything about when the HUD appears, including the hold Alt, Ctrl or Shift options for showing the whole HUD.

### Changed

- The Elements grid rows are ordered so the ones with the most columns are together, and the tick boxes are one size on every page.
- The settings window is wider and taller.
- Chat's and the minimap's opacity checkboxes are folded into their rows on the Opacity page, so nothing is set in two places.

### Fixed

- Sliders stopped following the mouse when it drifted off the thin bar during a drag.
- Tooltips flashing at full opacity when an addon re-shows them many times a second.

### Good to know

The new settings are kept in small macros named `QuietHUD bags`, `QuietHUD opacity` and `QuietHUD groups`, next to `QuietHUD data`. Please leave them alone.

## 1.1.6

- The quest key (experimental, off by default) now works more like Tab, but only through quest mobs. When every enemy with a nameplate around you is a quest mob, the press is the game's own Tab, which only has quest mobs to choose from and steps through identical ones too. When other enemies are mixed in, it goes to the next kind of quest mob by name and puts the skull on it, so those enemies are skipped. The game does not let an addon target a nameplate directly and a name cannot tell identical mobs apart, so in that mixed case a pack of the same mob counts as one stop. In combat the key uses what it prepared before the fight: a plain Tab if only quest mobs were near, otherwise the nearest quest mob by name.
- Fixed the right mouse button failing to turn the camera near RestedXP's minimap pins. Fading the minimap shrinks it to almost nothing, and an addon that measures text on it during that time (RestedXP's step pins) ended up with a frame as big as the screen that took the mouse when the minimap came back. Frames on the minimap that are far bigger than the minimap are now cut back to a small size when it comes back, so their tooltips still work.
- Fixed the tooltip opacity setting making tooltips flash at full opacity when an addon re-shows them many times a second (RestedXP's map pin tooltips did). The opacity is now applied the moment a tooltip is shown, and a tooltip the game is fading out is left alone.
- The quest key stays on the quest you picked. The game re-tracks quests by itself when one makes progress (a kill, a loot), which used to send the key to a different quest's mobs. Now a change that comes right after quest progress is ignored, and clicking a quest yourself still switches the key. The quest is dropped once it is complete or gone from the log. With debug mode on, every press names the quest the key is working from. Outside debug mode the key stays quiet and only says why when a press does nothing, at most once every 3 seconds.
- When no quest mob is on a nameplate, a "kill X" objective is now targeted by name, which reaches as far as /target does, even with enemy nameplates off or the mob too far for one. Item-drop quests still need a nameplate.

## 1.1.5

- New trigger grid on the Elements page. The action bars, player frame, enemy, party and other frames, objective tracker
  and chat each get a row of columns: Fade, Awake (combat, a drawn weapon or a target), While moving, Mouse over,
  Dungeon or raid, Hide in combat, which beats the rest, and for some rows New info (quest progress for the
  tracker, new messages for chat, a zone change for the minimap). Mouse over is now optional for every element, and "only on mouse over" is just leaving that one box ticked.
  This replaces "Show action bars on mouse over" (Show when page) and the loose arrow and tracker mouse over boxes.
  The defaults are what each element did before, and the old action bars setting carries over. The player and unit
  frames can now come back on mouse over too, and the chat can also show while awake or moving, or hide in combat
  (typing always brings it up).
- The minimap is a row of the Elements grid, and the mode button is gone. Awake makes it follow the HUD, While moving shows
  it only while you move, an unticked Fade never fades it, and the new slider "Minimap opacity when idle" replaces the
  dimmed mode. New info brings it back after a zone change (it always did, and the Extras slider sets how long), and
  Hide in combat and Dungeon or raid work on it like on every other row. Your old mode carries over.
- The "Always show in dungeons and raids" option on the Show when page is gone. Dungeon or raid is a column of the
  grid for every element, so it is a choice per element and no longer part of "awake". If you had the old
  option on, it carries over to those boxes.
- The bags bar and the menu bar are rows of the Elements grid instead of "always hide" checkboxes. Tick Fade and leave
  the other boxes empty to keep one hidden, or tick Awake and Mouse over to have it appear when needed. If you had one
  hidden it carries over that way.
- New RXP tab for the RestedXP addon: tick to fade its guide window, its targets and active items windows and its waypoint arrow, no
  `/qhud add` needed. Two sliders set the opacity of the guide and targets when shown (default 0.70) and when idle
  (default 0, hidden), and the arrow has its own pair (default 0.60 and 0). The guide and targets, and the arrow, each
  get a row of the same trigger columns.
- New experimental pixel shift (Extras page, off by default): the minimap and the objective tracker, and any frame added with
  `/qhud add shift <frame name>` or the two checkboxes for the action bars, bags and menu bar and for the player, target and party
  frames, move a couple of pixels every few minutes to spread wear on an OLED panel. Saved positions are
  never changed, everything is put back exactly when it is turned off, when Edit Mode opens and at logout, and nothing moves in
  combat. `/qhud shift` shows its state.
- New tooltip opacity slider (Extras page). It fades the whole tooltip, text included.
- The durability icon, the loss of control alert and External Defensives follow the Enemy, party, buffs row.
- New key binding "Hold to show the whole HUD" (Esc, Options, Keybindings, AddOns, QuietHUD): hold it and everything shows, even
  what is set to hide in combat, and it fades again when you let go. `/qhud peek` does the same for a macro (it toggles).
- New Extras options that show the whole HUD while you hold Alt, Ctrl or Shift, for when a key binding is not wanted or possible.
- New `/qhud mouse` command: watches your right-clicks and prints which frame took one that should have turned the camera, with
  details about that frame. It stays on after a reload and says nothing while the camera works.
- Fixed: mouse over on the RestedXP guide only worked over the small bar at its bottom. Mouse over now counts the
  whole window, not only the frame's own rectangle.
- Fixed: a frame that leaves a fade group (unticking a box, `/qhud remove`) now gets its full opacity back. Before
  it stayed faded.
- Fixed: frames added with `/qhud add` were forgotten after a reload once the settings grew. The settings are stored
  in a macro limited to 255 characters, and storing every setting left no room for the frames, so they were dropped.
  Only settings that differ from their default are stored now. If you had added frames, add them again once.
- New `nav` group for `/qhud add`, for a direction arrow such as a quest guide's waypoint arrow. Its row of the
  trigger grid (RXP tab) chooses when it shows. `/qhud arrow` keeps it visible until used again, for a macro. The
  frame is faded through a container of ours, so a frame that sets its own opacity to show and hide itself does not
  fight with the fade.
- Frames added to the quest group (`/qhud add quest <frame name>`) now also come back when you hover them, like the
  objective tracker does. Handy for a quest guide window.
- New slider "Chat fade out animation" (Chat page, default 1.5 seconds) for how long the chat, including the window or
  background of a chat addon in the chat group, takes to fade out. The rest of the HUD keeps its fade speed.
- "Chat uses the HUD opacity when active" moved to the Chat page, next to the other chat settings, and "Fade chat" is
  a column of the Elements grid. New slider "Chat opacity when active" sets the chat's own opacity when it is not
  using the HUD's.
- New `chat` group for `/qhud add`: frames added to it fade together with the chat, for example the window or the
  background of a chat replacement addon. Find the frame with `/qhud find <text from a chat message>`.
- The quest key's "no enemy nameplates" message now shows once per session instead of on every key press.

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
