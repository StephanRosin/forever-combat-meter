# Forever Combat Meter 1.0 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A damage/healing/threat meter for WoW: Forever (C_DamageMeter + threat API) with up to 4 windows, sessions, per-spell breakdown, death recap, threat warning and chat report — in the look, menus and UI of Forever Quest Log.

**Architecture:** Port Forever Quest Log's generic framework (locales, settings, profiles, share, media, border, corners, position, options window, minimap button) under the new addon's names. On top, pure data modules (`Meter.lua` wraps C_DamageMeter and is the only place that touches secret values; `Threat.lua`; `Format.lua`) feed a UI layer (`Windows.lua` meter windows with quest-log headers and bars; `Detail.lua` tooltip, breakdown panel, death recap; `Report.lua`). Nothing is a secure frame.

**Tech Stack:** Lua 5.1, WoW: Forever 1.60.1 (Interface 16001, 12.x engine, secret values), tests with a Lua 5.1 WoW mock (`tests/run`), bash tooling.

## Global Constraints

- Spec: `docs/specs/2026-10-10-forever-combat-meter-design.md`. Mechanics reference (API facts learned from ForeverMeter and the client sources): `.superpowers/sdd/2026-10-10-plan-forever-combat-meter/mechanics.md`.
- **ForeverMeter is GPL-3: read it to understand how something works, never copy its code** (no verbatim blocks, no translated-line-by-line ports). Its path: `$HOME/Games/Battlenet/drive_c/Program Files (x86)/World of Warcraft/_classic_beta_/Interface/AddOns/ForeverMeter/`.
- Framework source to port: `~/Dokumente/ForeverQuestLog` (our own code): `Locales/*.lua`, `Locale.lua`, `Core.lua`, `Profiles.lua`, `Settings.lua`, `Share.lua`, `Media.lua`, `Position.lua`, `Corners.lua`, `Border.lua`, `Options/Style.lua`, `Options/Widgets.lua`, `Options/Window.lua`, `Options/Panel.lua`, `Options/MinimapButton.lua`, `Commands.lua` (ToggleLock idea), `Media/*.tga`, `tests/run`, `tests/wowmock.lua`, `tools/package`, `tools/release`, `install`. Remove everything quest-specific (Tracker, Data, WorldMap, Focus, quest settings, presets that name quest keys).
- Names: addon folder/TOC `ForeverCombatMeter`, title "Forever Combat Meter", `## Interface: 16001`, `## Version: 1.0.0`, SavedVariables `ForeverCombatMeterProfiles` (account), SavedVariablesPerCharacter `ForeverCombatMeterChar`, globals/frames prefixed `ForeverCombatMeter`, slash `/fcm` (and `/forevercombatmeter`), share prefix `FCM1:`.
- Languages enUS, deDE, esES, frFR, same keys in all four (tested), game language by default, dropdown in the options nav (as the quest log).
- Only values that differ from the defaults are stored (quest log's Settings behaviour).
- Secret values: only `Meter.lua` reads C_DamageMeter; it returns plain Lua tables whose numbers/strings may be secret; UI code never compares, sums, concatenates or uses them as keys; formatting goes through `Format.lua` (`%s`, `%.0f`, `%.1f`, AbbreviateLargeNumbers — never `%d`, never `..` on a possibly secret value). In combat: API order, no percent; full recompute after combat (+ ~3 s of redraws).
- No `COMBAT_LOG_EVENT_UNFILTERED`; register events through a pcall wrapper; never `hooksecurefunc` frame methods; never touch Blizzard's `DamageMeter` frame directly.
- Tests: `tests/run` (focused tests while working, the full run once before each commit). Commits end with:
  ```
  Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01PSwcrtAz5yXQ5Kj9VjMsMo
  ```
- Repo `~/Dokumente/ForeverCombatMeter`, remote `git@github.com:StephanRosin/forever-combat-meter.git`, work on branch `meter-1.0`.

## File Structure

| File | Responsibility |
|---|---|
| `ForeverCombatMeter.toc` | load order, SavedVariables, compartment funcs, icon |
| `Locales/enUS|deDE|esES|frFR.lua`, `Locale.lua` | strings, language choice (ported) |
| `Core.lua` | ns.On (pcall-guarded RegisterEvent), ns.Print, ns.AfterCombat |
| `Profiles.lua`, `Settings.lua`, `Share.lua` | ported; Settings.DEFAULTS for the meter (Task 1 lists them) |
| `Media.lua`, `Position.lua`, `Corners.lua`, `Border.lua`, `Media/*.tga` | ported look (+ statusbar textures list) |
| `Format.lua` | secret-safe number/name/time formatting |
| `Meter.lua` | C_DamageMeter wrapper: modes, sessions, sources, spells, deaths recap, availability, reset |
| `Threat.lua` | threat list and warning state |
| `Windows.lua` | meter windows: header, bars, scrolling, resize grips, lock, add/close, render loop |
| `Detail.lua` | bar tooltip (top 5), breakdown panel, death recap view |
| `Report.lua` | chat report (top N, a source's top spells) |
| `Options/Style|Widgets|Window|Panel.lua`, `Options/MinimapButton.lua` | ported options window; pages for the meter |
| `Commands.lua` | `/fcm` sub-commands |
| `install`, `tools/package`, `tools/release`, `tests/run`, `tests/wowmock.lua`, `tests/run.lua` | tooling (ported, renamed) |

---

### Task 1: Scaffold and ported framework

**Produces:** a loadable addon with no meter yet: `ns.L`, `ns.Locale`, `ns.On`, `ns.Print`, `ns.AfterCombat(key, fn)`, `ns.DB()`, `ns.AccountDB()`, `ns.ActiveProfile()`, profile functions, `ns.Settings` (Get/Set/SetMany/OnChange/Changed/TextStyle/ResetProfile/SetLocked/DEFAULTS/RANGES/TEXT_STYLES), `ns.Share`, `ns.Media` (incl. statusbar textures: the quest log's three plus any LibSharedMedia "statusbar"), `ns.Position`, `ns.Corners`, `ns.Border`, `ns.Window` (options window with an empty-ish General page and Profiles page), `ns.MinimapButton`, compartment globals `ForeverCombatMeter_OnAddonCompartmentClick/Enter/Leave`, slash `/fcm` opening the options.

**Settings.DEFAULTS** (complete for 1.0; RANGES in brackets):
```
-- general
refresh = 0.2 [0.05, 2] (step 0.05), hideBlizzard = false, minimapShow = true, minimapAngle = 200,
style = "FOREVER" ("FOREVER" | "COMPACT"),   -- user request: a compact UI like ForeverMeter as an option
-- windows: one table per window in the profile, see Task 4 (windows = { [1] = { mode = "damage", view = "current" } })
windowCount = 1 [1, 4],
-- bars
barHeight = 18 [10, 40], barSpacing = 1 [0, 10], barTexture = "Blizzard", barClassColor = true,
barColor = {0.45, 0.55, 0.75}, barBgAlpha = 25 [0, 100], showIcon = true, showRank = true,
showTotal = true, showPerSecond = true, showPercent = true, animate = true,
-- frame look (as the quest log "Default" profile)
borderStyle = "NONE", borderSize = 1 [1, 8], borderColor = {0,0,0,1}, cornerRadius = 10 [0, 12],
shadowEnabled = true, shadowSize = 9 [1, 20], shadowAlpha = 65 [0, 100],
bgMode = "SOLID", bgColor = {0.047, 0.047, 0.055}, bgAlpha = 70 [0, 100], bgTexture = "Blizzard Dialog Background Gold",
headerLine = true, fadeAlpha = 100 [0, 100],
-- text styles (Friz Quadrata like the quest log)
headerFont = "Friz Quadrata", headerSize = 14 [8, 24], headerFlag = "SHADOW", headerColor = {1, 0.82, 0.29},
nameFont = "Friz Quadrata", nameSize = 11 [8, 20], nameFlag = "SHADOW", nameColor = {1, 1, 1},
valueFont = "Arial Narrow", valueSize = 12 [8, 20], valueFlag = "SHADOW", valueColor = {1, 1, 1},
-- threat
threatWarn = true, threatWarnPct = 90 [50, 100], threatSound = true, showPets = true,
-- report
reportLines = 5 [1, 25],
```
- [ ] Copy and rename the framework files listed in Global Constraints; strip quest-specific code and keys (porting notes for the same files: `~/Dokumente/ForeverInfoPanel` went through this in Task 1–3 of its plan — its `InfoPanel/` versions show the stripped shape, but keep Forever-only APIs; no 2.5.6 guards needed).
- [ ] TOC with load order: Locales, Locale, Core, Profiles, Settings, Share, Media, Position, Corners, Border, Format, Meter, Threat, Windows, Detail, Report, Options/Style, Options/Widgets, Options/Window, Options/Panel, Options/MinimapButton, Commands (files of later tasks are added by those tasks).
- [ ] Tooling: `install` (copy the TOC's files into `_classic_beta_/Interface/AddOns/ForeverCombatMeter`), `tools/package`, `tools/release` (project ID read from the TOC; leave `X-Curse-Project-ID` out until the user gives it), `tests/run`, `tests/wowmock.lua` (the quest log's, trimmed), `tests/run.lua`.
- [ ] Tests: addon loads; four locales same keys; Settings get/set/non-default storage; profiles switch/delete; share round trip; options window opens with General and Profiles pages and the language dropdown; `/fcm` opens it; minimap button and compartment functions exist.
- [ ] Commit "Scaffold: Forever Quest Log framework for Forever Combat Meter".

### Task 2: Meter data layer and formatting

**Files:** `Format.lua`, `Meter.lua`, `tests/run.lua` (+ mock: `C_DamageMeter`, `Enum.DamageMeterType/SessionType`, `issecretvalue`, a "secret" wrapper type in the mock whose comparison/arithmetic/concatenation raise, `C_Spell.GetSpellName/GetSpellTexture`, `C_DeathRecap`, `AbbreviateLargeNumbers`).

**Produces:**
- `Meter.MODES` ordered list of `{ key, type }` for keys `damage, healing, absorbs, taken, enemytaken, avoidable, interrupts, dispels, deaths` (enemytaken/avoidable only when `Enum.DamageMeterType` has `EnemyDamageTaken` / `AvoidableDamageTaken`); `threat` is handled by Threat.lua and appended by the UI.
- `Meter.Available()` → bool, reason.
- `Meter.Sessions()` → list `{ id, name, duration }` (past fights) — name may be secret.
- `Meter.Fetch(modeKey, view)` (view = "current" | "overall" | sessionID) → `{ secret = bool, total, duration, rows = { { name, class, specIcon, total, perSecond, percent|nil, isPlayer, guid|nil, creatureID, recapID, deathTime } } }`; out of combat rows sorted by total desc with percent computed and perSecond fallback total/duration when the API gives 0; in combat (`secret`) API order, percent nil.
- `Meter.Spells(modeKey, view, row)` → `{ secret, rows = { { spellID, name, icon, total, perSecond, percentOfSource|nil, creature|nil } } }` (uses guid, or UnitGUID("player") for the own row in combat; creatureID for creatures; returns nil when the GUID is not readable).
- `Meter.Recap(recapID)` → list of last ≤6 events oldest→newest `{ time, spell, icon, source, amount, hp }` or nil.
- `Meter.Reset()`.
- `Format.Amount(v)` (k/M; safe for secrets via AbbreviateLargeNumbers or `%.0f`), `Format.PerSecond(v)`, `Format.Percent(p)`, `Format.Name(rank, name)` (no `..` on name), `Format.Duration(sec)`, `Format.IsSecret(v)`.
- [ ] Tests first: each mode maps to its enum; enemytaken/avoidable absent when the enum lacks them; sessions list; Fetch sorts and computes percent out of combat; Fetch keeps API order and no percent with secret values and raises nothing (the mock's secret type raises on any forbidden op, so this proves it); perSecond fallback; Spells for own row in combat, nil for unreadable others; Recap order and secret amounts; Format functions with plain and secret inputs.
- [ ] Implement, green, commit "Meter data layer and secret-safe formatting".

### Task 3: Threat

**Files:** `Threat.lua`, tests.
**Produces:** `Threat.List()` → `{ unavailable = bool, rows = { { name, class, unit, pct, perSecond, tanking, isPlayer } } }` for the current attackable living target over group units (raid1..N or player+party1..N, pets when `showPets`), sorted tank first, pct desc, name; secret threat → `unavailable = true` (pcall); `Threat.Reset()` on target/roster change; `Threat.CheckWarning()` → plays the sound and returns true once per target when the player's own pct ≥ `threatWarnPct` and not tanking (`threatWarn`, `threatSound` settings).
- [ ] Tests first (group composition, pets on/off, sort, tank 100 %, per-second from deltas, warning once per target and re-armed on target change, secret → unavailable). Implement, green, commit "Threat list and warning".

### Task 4: Meter windows

**Files:** `Windows.lua`, tests.
**Per-window settings** in the profile under `windows[i] = { mode, view ("current"/"overall" only persisted), point, x, y, width, rows, locked }` (defaults: mode damage, view current, point "CENTER", x 300, y 0, width 220, rows 8, locked false); window 1 always exists; `windowCount` 1..4.
**Produces:** `Windows.Create(i)`, `Windows.Refresh(i?)`, `Windows.Add()`, `Windows.Close(i)`, `Windows.SetMode(i, key)`, `Windows.SetView(i, view)`, `Windows.ToggleLock(i)`, `Windows.Frame(i)`.
- Frame = quest-log look: background/border/shadow via ApplyBackground/Border.Draw/Corners.Fit; header (height 24 + style) with gold glow and line exactly as the quest log's header (`Corners.Fit(frame.clip, frame, radius, { frame.bg, header.shine })`), title "<Mode> · <Session>" (session names may be secret → `%s` formatting), icon buttons right→left: menu (gear: opens a context menu with mode, session, new window, close window, lock, options), reset (confirm out of combat), lock (padlock, per window), session (cycles current/overall/menu of past fights), mode (menu). Mouse wheel over the header cycles the mode; over the bars scrolls.
- **Style "COMPACT"** (setting `style`, user request "kompakter als Option, so wie beim ForeverMeter"): header 18 px instead of 24 with no gold glow and no rounded corners on the header (square frame unless cornerRadius is set), title at headerSize − 3, header buttons 12 px instead of 16 and only menu + lock shown (mode/session/reset via the menu and mouse wheel), no inner padding around the bars, bars default to the compact look by applying barHeight 14 and barSpacing 0 when the user picks COMPACT in the options (a one-time SetMany, the values stay editable). "FOREVER" is the quest-log look described here. Reference looks: ForeverMeter's window and Details! (user: "oder wie bei Details!") — slim title bar with small icons, bars edge to edge with name and values drawn inside the bar, thin 1 px gaps; read ForeverMeter for sizes only (GPL).
- Bars: `rows` visible bars, height/spacing from settings, StatusBar with texture, class colour or `barColor`, background alpha; icon (spec icon or class icon), rank+name left (name style), right columns total / per second / percent per settings (value style); animated fill toward the target value when `animate` (plain numbers only; secret values set directly). Threat mode renders Threat.List rows (pct as percent, perSecond, tank marker) and shows "threat unavailable" when needed.
- Moving: drag the header while unlocked (StartMoving/StopMovingOrSizing + SetUserPlaced(false)/SetDontSavePosition, then Position.Read/Write into the window's point/x/y); resizing: grips in the bottom corners implemented by hand (OnUpdate + GetCursorPosition; this client fires no OnSizeChanged for StartSizing) changing width and rows.
- Render loop: one OnUpdate throttled by `refresh`; meter events and settings changes mark dirty; threat windows redraw every tick; after PLAYER_REGEN_ENABLED redraw every tick for 3 s; DAMAGE_METER_RESET turns numeric views back to current.
- [ ] Tests first: window 1 exists, add up to 4 and close (not 1), per-window mode/view saved, numeric view not persisted, header title text, bars count/order/texts/colours, columns switch, threat window rendering and unavailable text, secret rendering raises nothing, lock blocks drag, resize changes width/rows, render throttle, reset event. Implement, green, commit "Meter windows".

### Task 5: Tooltip, breakdown, death recap, report

**Files:** `Detail.lua`, `Report.lua`, tests.
- Tooltip on bar hover: source name, total/per second, top 5 spells (Meter.Spells) or "details out of combat" when not readable; deaths mode: time of death and the last hits (Meter.Recap).
- Click a bar: breakdown panel (same look: header with title "<Name> — <Mode>", close button; list of spells with icon, name (· creature for taken/avoidable), total, per second, percent of source), movable by its header, position saved in the profile (`detailPoint/X/Y`); right-click its title (out of combat) reports that source's top spells. Deaths mode: click shows the recap list instead.
- `Report.Window(i, n)` / `Report.Spells(source, n)`: header line + "i. name  value" lines; channel RAID / PARTY / SAY (instance only) / local print; refuse with a localized message when values are secret; use C_ChatInfo.SendChatMessage when present.
- [ ] Tests first (tooltip lines, breakdown rows and percent, creature suffix, recap order, report channel choice, secret refusal), implement, green, commit "Tooltip, breakdown, death recap and chat report".

### Task 6: Options pages, commands, Blizzard meter

**Files:** `Options/Window.lua` (pages), `Commands.lua`, `Locales/*`, tests.
- Pages (quest-log row helpers): **General** (style Forever/Compact, refresh, hide Blizzard meter, minimap button, language in the nav), **Windows** (window count, per window: mode, session, lock, width, rows; buttons new/close), **Bars** (height, spacing, texture, class colour/colour, background alpha, icon, rank, columns total/per second/percent, animate), **Appearance** (background, header line, border, corner radius, shadow, fade), **Text** (header, name, value styles), **Threat** (warning on, threshold, sound, pets), **Profiles** (as the quest log: active, save as, delete, export/import, reset).
- `hideBlizzard`: set CVar `damageMeterEnabled` to "0" when on (remember the previous value in the account DB and restore it when switched off); never touch the `DamageMeter` frame. Verify in the client source that the CVar exists in Forever (mirror `Blizzard_DamageMeter/DamageMeter.lua`).
- `/fcm`: no argument → options; `mode <key>`, `reset`, `report [n]`, `lock`, `unlock`, `toggle` (show/hide all windows), `windows <1-4>`.
- [ ] Tests first (every DEFAULTS key has a row; no raw keys in any page in all four languages; hideBlizzard sets/restores the CVar; commands), implement, green, commit "Options pages, commands, Blizzard meter switch".

### Task 6b: Corner resize arrows (user request)

- While a window is unlocked, show an arrow grip in **each of the four corners** (diagonal arrow art pointing outwards, tinted like the quest log's accent, brighter on hover). Dragging a corner grows/shrinks the window towards that corner: width and rows change, the opposite corner stays fixed on screen (store the result back into the window's point/x/y so it is kept). Locked: no grips. Same for the breakdown panel if it is resizable. Works in both styles (FOREVER, COMPACT). Replaces the two bottom grips from Task 4.
- Tests: grips shown only unlocked, four grips, each corner keeps the opposite corner fixed (position math), rows/width clamped to their ranges, saved position after the drag.

### Task 7: In-game check (controller with the user)

- [ ] `./install`; the user restarts the game (new media files need a restart, /reload is not enough) and checks with ForeverMeter disabled: windows, modes, sessions, a fight (values in combat, recompute after), tooltip, breakdown, death recap, threat warning, report, options pages, languages, profiles, Blizzard meter switch, Lua errors. Fix findings with tests.

### Task 8: Docs, CurseForge text, Vault

- [ ] `README.md`, `docs/curseforge/description.md` + logo (style of the other Forever logos), `## Version: 1.0.0`.
- [ ] Vault page `10-Projekte/WoW-Addons/ForeverCombatMeter.md` (structure, secret-value rules, pitfalls), add it to `WoW-Addons.md`; memory pointer. Release only when the user gives the CurseForge project ID and says so.
