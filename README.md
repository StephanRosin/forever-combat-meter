# Forever Combat Meter

A damage, healing and threat meter for **WoW: Forever** (Interface 16001), in the
look of the other Forever addons. It reads the client's own server-side meter
(`C_DamageMeter`, `C_DeathRecap`), so its numbers match the game's and nothing
depends on the combat log, which this client keeps from addons.

English, Deutsch, Español, Français.

## Install

Download the zip from CurseForge and unpack it into
`<WoW>/_classic_beta_/Interface/AddOns/`, or install from this repository:

```sh
./install "<WoW>/_classic_beta_/Interface/AddOns"
```

Then `/reload` or restart the game.

## Use

`/fcm` opens the options. Further commands:

| Command | Does |
| --- | --- |
| `/fcm mode [window] <mode>` | damage, healing, absorbs, taken, enemytaken, avoidable, interrupts, dispels, deaths, threat |
| `/fcm windows <1-4>` | opens or closes windows |
| `/fcm report [n] [channel] [name]` | sends window 1's top n to the chat; channel: auto, say, party, raid, instance, guild, whisper (remembered) |
| `/fcm reset` | clears all fights (asks first; not in combat) |
| `/fcm toggle` | hides or shows all windows |
| `/fcm lock` / `unlock` | locks or unlocks all windows |

## Features

- **Modes**: damage, healing, absorbs, damage taken, interrupts, dispels, deaths
  (plus enemy and avoidable damage taken where the client has them) and threat
  on the current target. Right-click a window title for the mode menu, or use
  the mouse wheel over it.
- **Sessions**: current fight, overall and every earlier fight the client keeps.
- **Up to four windows**, each with its own mode, session, position, size, scale,
  lock and bar colour. Corner arrows resize while unlocked.
- **Two looks**: Forever (the Forever Quest Log header) and Compact (slim, bars
  edge to edge).
- **Details**: hover a bar for the top five spells, click it for the breakdown
  panel with every spell; in deaths mode the death recap.
- **Threat warning**: a centred warning and an optional sound when you pass your
  threshold without holding the target; once per target and fight.
- **Chat report** of a window's ranking or a player's spells to say, party, raid,
  instance, guild or a whisper (the gear menu's Report submenu; the last choice
  is remembered); refused in combat, when the values are secret.
- **Profiles** shared across characters, export and import as text, optionally
  hiding Blizzard's own damage meter.

### Secret values

In combat the client hands addons secret names and amounts. The meter shows them
as they come (the client allows them in `SetText`, status bar values and a few
`string.format` conversions) and sorts, computes percentages and fills in the
details once combat ends. Code that touches such a value must check
`issecretvalue` before any comparison, including `== nil`; `tests/run` contains
a lint for that.

## Development

| Path | Purpose |
| --- | --- |
| `tests/run` | the test suite, Lua 5.1 against a client mock (`tests/wowmock.lua`) |
| `./install <AddOns folder>` | copies exactly the TOC's files and `Media/*.tga` |
| `tools/package` | builds `dist/ForeverCombatMeter-<version>.zip` |
| `tools/release <release\|beta\|alpha> "<changelog>"` | runs the tests, packages and uploads to CurseForge (token from `$CURSEFORGE_TOKEN` or `~/.config/curseforge-token`) |
| `tools/make_icons.py` | regenerates the header icons and `Media/MinimapIcon.tga` |

Bump `## Version` in the TOC before a release.

## License note

Forever Combat Meter is written from scratch. It contains no code from
ForeverMeter or other meter addons.
