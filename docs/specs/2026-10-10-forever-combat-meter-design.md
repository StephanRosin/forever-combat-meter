# Forever Combat Meter 1.0 — Design

Date: 2026-10-10 · Status: approved in conversation. In short: **a damage/healing/threat meter for WoW: Forever, written
from scratch, with ForeverMeter's functions (in two stages) and the look, menus and UI of Forever Quest Log and
InfoPanel 1.6.**

## 1. Facts

- WoW: Forever (Interface 16001) forbids COMBAT_LOG_EVENT_UNFILTERED to addons. The data source is Blizzard's
  server-side meter `C_DamageMeter`:
  - `GetCombatSessionFromType(sessionType, type)` / `GetCombatSessionFromID(sessionID, type)` →
    `{ combatSources = { { sourceGUID*, sourceCreatureID, name*, classFilename, specIconID, totalAmount,
    amountPerSecond, isLocalPlayer, … } }, maxAmount, totalAmount, durationSeconds }`
  - `GetCombatSessionSourceFromType/FromID(…, type, sourceGUID, sourceCreatureID)` →
    `{ combatSpells = {…}, maxAmount, totalAmount }`
  - `GetAvailableCombatSessions()` → `{ { sessionID, name, durationSeconds } }`, `GetSessionDurationSeconds(type)`,
    `IsDamageMeterAvailable()`, `ResetAllCombatSessions()`
  - events `DAMAGE_METER_COMBAT_SESSION_UPDATED(type, sessionID)`, `DAMAGE_METER_CURRENT_SESSION_UPDATED`,
    `DAMAGE_METER_RESET`; enums in `DamageMeterConstantsDocumentation.lua`.
  - (*) ConditionalSecret: in combat names, amounts and GUIDs are "secret values" — they can be displayed, but not
    compared, summed or used as table keys.
- Threat: `UnitDetailedThreatSituation`.
- ForeverMeter (installed, GPL-3.0) shows what works. It is **reference only**: read it to learn how something works,
  never copy its code (the GPL would then apply to this addon).
- Look, options window, settings, profiles, export/import, Media/Border/Corners/Position, locale handling: as
  Forever Quest Log and InfoPanel 1.6.0 — ported.

## 2. Decisions

1. **Own addon** "Forever Combat Meter", repo `~/Dokumente/ForeverCombatMeter` → `git@github.com:StephanRosin/forever-combat-meter.git`,
   command `/fcm`, Interface 16001, four languages (enUS, deDE, esES, frFR; default the game language; dropdown in the
   options window), CurseForge later (project created by the user).
2. **Look and UI** from Forever Quest Log / InfoPanel 1.6: the same ported modules (Settings with DEFAULTS/RANGES and
   only non-default values stored, Profiles, Share, Media, Border, Corners, Position, Locale, Options Style/Widgets/
   Window/Panel, minimap button and addon compartment entry). Each meter window has the quest log's header (gold glow,
   rounded corners via `Corners.Fit`, line): left the mode and session, right small icon buttons — mode, session,
   reset, lock, menu (gear opens the options).
2a. **Compact style as an option** (user request): a "Kompakt" style like ForeverMeter — slim header without glow,
   fewer header buttons, no padding, slimmer bars; the quest-log look stays the default.
3. **Bars**: class colour (or a fixed colour, setting), spec icon (class icon when the client gives none), rank and
   name, columns total / per second / percent (each switchable), bar texture (media list incl. LibSharedMedia), height,
   spacing, background; animated fill. Text styles via the quest log's text style rows (name, values).
4. **Modes**: damage, healing, absorbs, damage taken, interrupts, dispels, deaths, threat; enemy damage taken and
   avoidable damage taken only when the client's enum knows them.
5. **Sessions**: current fight, overall, and every fight `GetAvailableCombatSessions` lists.
6. **Windows**: up to 4, each with its own mode, session, position, size (resize grips) and lock; window 1 always
   exists; add/close from the menu. Per-window settings live in the profile.
7. **Details**: hovering a bar shows that source's top 5 spells; a click opens a breakdown panel (spell icon, total,
   per second, percent of the source) in the same look, movable; for deaths the last hits of the death recap.
8. **Threat**: list of the current target's threat (`UnitDetailedThreatSituation` for group members/pets), warning
   (screen flash text + optional sound) above an adjustable threshold.
9. **Chat report**: top N of a window to raid/party/say (context), and from the breakdown a player's top spells.
10. **Combat and secret values**: in combat bars are shown in the API's order with the values as given (no sorting,
    no sums, no percent from secret values; percent only where computable or out of combat); after combat
    (`PLAYER_REGEN_ENABLED`) everything is recomputed. The meter frames are not protected; no secure templates.
11. **Blizzard's own meter window** is left alone; if it can be hidden without touching Blizzard code, an option
    ("Hide Blizzard's meter") — to be checked in the client source.
12. **Refresh**: on the meter events plus a throttle (default 0.2 s, setting).

## 3. Later (1.1)

Snapping windows together, comparing two players, "copy as text", test mode, auto show (combat/group) and auto reset
(new instance/group), key bindings.

## 4. Tests

Lua 5.1 mock of C_DamageMeter (sessions, sources, spells, secret values in combat), modes and sessions, ordering
out of combat vs. API order in combat, percent/per-second formatting, windows (add/close, per-window settings),
breakdown and tooltip content, death recap, threat list and warning threshold, report text, options pages (every
setting has a row, no raw locale keys in all four languages), profiles/export/import.
