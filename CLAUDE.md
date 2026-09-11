# Gridiron Dynasty — working notes for Claude

Godot 4.3 / GDScript. "Risk with football teams": twelve empires on a territory map, each week you attack a neighbour in a short 7-a-side **Border War** battle, win to take land and raid a player, lose your capital and you're out. Between seasons: aging, a draft, a fresh map. The full design is `docs/DESIGN.md`; the player-facing state of the build is `README.md`. Read both before changing gameplay.

## Branch and workflow

- Work on branch `claude/gameplay-ideas-kn5bbo` (all prior work is there). Commit with clear messages; push with `git push -u origin <branch>`.
- No editor is available in the remote session. **Verify with the headless harnesses** (below) before claiming anything works. Visual layout has never been checked by eye — say so when you touch UI.

## Verification

`tools/headless/run.sh --download` fetches Godot 4.3 into `.godot-bin/` (gitignored), parse-checks every script, and runs every harness. Individual pieces:

```bash
GODOT=.godot-bin/Godot_v4.3-stable_linux.x86_64
$GODOT --headless --path . --check-only -s scripts/core/season.gd          # parse one script
$GODOT --headless --path . -s res://tools/headless/season_test.gd          # logic harness
$GODOT --headless --path . --fixed-fps 60 -s res://tools/headless/battle_test.gd -- 1 1   # mode, battles
```

Harnesses (all `extends SceneTree`, driven from `_physics_process`, call the same handlers the UI does):

| file | covers |
|---|---|
| `season_test.gd` | five simulated seasons, invariants every week |
| `offseason_test.gd` | three seasons chained through aging + draft |
| `save_test.gd` | save/load round-trips (deep-equal), corrupt file |
| `battle_test.gd` | quick battle → aftermath → raid, args: mode (0 auto,1 watch,2 play) battles |
| `season_flow_test.gd` | menu → map → battle → map for N weeks, args: mode weeks |
| `offseason_flow_test.gd` | finished season → offseason scene → draft pick → season 2 map |
| `save_flow_test.gd` | autosave, simulated restart, resume pending battle |

Add a harness when you add a system; extend the nearest one when you change rules.

## Code conventions (these matter — earlier sessions hit each one)

- **Preload, never `class_name` or autoloads.** Every cross-script reference is `const X = preload("res://...")`. Shared state lives in `static var`s on preloaded scripts (`battle_settings.gd`, `season_state.gd`). Autoloads broke `--check-only` and the Android editor.
- Explicit types everywhere; `lerpf/minf/maxf/clampf/mini/maxi/clampi`; every code path returns (bounded `while` loops, not `while true`). Node references may stay untyped (`var qb`).
- 4-space indentation. No comments that restate the code; short "why" comments only.
- Player/team/territory data are plain `Dictionary`s passed by reference — mutate in place, never copy, or raids/XP silently stop persisting.
- Numbers survive JSON as floats and dict keys as strings: anything new that is saved needs a line in `save_game.gd` / `season.restore()` / `offseason.restore()`.
- Both teams attack left→right on screen; the away team's yardage is mirrored for the border bar (`_frontier_fraction`).

## Map of the code

```
scenes/          main (menu) · map (season) · game (battle) · offseason
scripts/core/
  game_constants  field geometry (40-yard field, 25 px/yard)
  battle_settings mode: PLAY / WATCH / AUTO_RESOLVE (static)
  rosters         hand-made Hawks/Forge + generators, stat→physics mappings, careers
  play_book       cards (Slants/Deep/Draw/Screen vs Cover/Blitz/Spy), matchup table, AI calls
  battle_sim      auto-resolve of a whole battle from cards + stats
  battle_xp       per-battle stat gains (capped, potential-limited, loyalty)
  raid_rules      post-battle swap, protections (tag, rookie), morale
  season          empires, territories, weekly loop, AI attacks, elimination
  offseason       aging/retirement, draft order, class, picks, next season
  season_state    static holder: season, pending battle, offseason
  save_game       JSON slot in user://, normalizers
scripts/football/ the live battle: football_game (orchestrator), quarterback (slingshot aim),
                  receiver (routes, RB, AI steer), blocker, defender_ai (roles), football, field_view
scripts/ui/       scoreboard (HUD + cards + border_bar), matchup, aftermath, raid, season_map,
                  offseason_screen, main_menu, player_row (shared card)
tools/headless/   harnesses + run.sh
```

## Where things stand

Done: battle in three modes, 7-a-side with stats, cards on both sides, aftermath XP, raids, season map with AI empires and elimination, offseason with aging + draft + rookie protection, autosave/load.

Done since: territory resource effects — Academy/Capital pay weekly training points, Mines pay money (banked on each empire, shown on the map; nothing spends them yet), Stadium/Capital grant the defender a home-crowd edge (wider attacker throw scatter live, lower completion in auto-resolve), Highlands double fatigue-bar accrual in the battle fought there, and Academy/Capital holdings bump a just-drafted rookie's potential/stats in the offseason.

Done since: a fourth battle mode, **SIM** — call every play on both sides like WATCH, but each down resolves instantly via `BattleSim.resolve_single_play` (same card/stat math as auto-resolve) instead of the real-time snap/pocket/throw sequence, with a plausible player credited per down so battle XP still accrues (`football_game._resolve_sim_play`). Added because the real-time engine (QB drag-throw, receiver/defender AI) wasn't reliable enough to play through; SIM sidesteps it entirely while keeping the down-by-down, card-calling feel. Also fixed a real bug found while testing this: `RaidRules.can_take` compared a quick battle's `season_number` sentinel (-1) against a player's default `rookie_season` (also -1), so every player misread as a protected rookie — nobody could be raided in Quick Battle, and losing there soft-locked the raid screen (AI auto-take found no legal target). Fixed by treating `season_number < 0` as "no rookie protection" outright.

Done since: **SIM is now the default battle mode** (`BattleSettings.mode` defaults to `Mode.SIM`, was `Mode.PLAY`), since it's the reliable way to play a battle end to end. Also retimed the AI QB's throw decision (`football_game._ai_throw_decision`): it used to hard-block any throw until `Rosters.decision_seconds(awareness)` (0.9–1.7s) had elapsed, so a receiver who broke open early on a Slant or won deep just sat there while the QB waited out the clock. It now evaluates every frame and can release early — at `ai_decision_seconds * 0.4`, once separation clears the new `Rosters.early_throw_separation(awareness)` threshold (45–75px, sharper QBs trust a tighter window) — before falling back to the original on-time (`ai_decision_seconds`, >50px) and desperate (pressured or well overdue) checks. Verified live in the exported Web build: a Slant now gets thrown around 0.7–1.0s into the route once the WR clears his man, instead of always waiting past a second.

Done since: the direction changed to **play-calling and stats, not a live throw**. SIM is now the only selectable mode alongside AUTO-RESOLVE on the menu — PLAY/WATCH are still in the codebase and stay parse-clean, but hidden behind `BattleSettings.SHOW_REALTIME_MODES` (a save left on one of them coerces to SIM on load). The play book grew from 4 offense/3 defense cards to **6×4**: Slants, Deep Shot, Draw, Screen, Sweep, Play Action vs. Cover, Blitz, Spy, Press. Both AI sides now call situationally (down/distance, red zone, 4th down, final drive while trailing, sudden death) shaded by a fixed per-empire coach personality (`PlayBook.coach_tendency`, seeded from empire id, nothing new saved), and pre-snap reads are tiered (exact card / family look / nothing) off Awareness.

Done since: **the call sheet.** Every team has an OC and a DC (`Rosters.ensure_coaches`, carried across seasons and saves); whichever coordinator is reading the other side produces a "expect X, call Y" line with its own certainty, alongside the QB/Safety's own Awareness-tier read and situation tags, and the opponent's fixed personality. Every card face shows the stat matchup that decides it (`BattleSim.card_edges`) with a star on the mathematically best call (`BattleSim.expected_yards`/`suggest_offense`/`suggest_defense`), and every down leaves behind a one-line breakdown of exactly what happened (`BattleSim._resolve_play`'s `detail`).

Done since: **player stats visible throughout the battle.** A slot-weighted overall + letter grade (`Rosters.overall`/`Rosters.grade`) now shows next to every player's name everywhere a roster row appears (matchup, raid, offseason, season map). In SIM, the field — otherwise idle — hosts two **lineup strips** (`scripts/ui/lineup_strips.gd`), one per side, showing all seven players' stats at once; the card you call and then the down's result highlight whoever actually decided it. Verified headless (all seven harnesses) and visually in the exported Web build via headless Chromium: main menu, matchup, both offense- and defense-calling steps, a resolved down, aftermath, raid, and the season map's roster overlay.

Done since: **watching the play.** SIM's stat math still decides a down first (`BattleSim._resolve_play`, unchanged); the result dictionary it returns grew load-bearing structural fields — `offense_card`, `defense_card`, `ball_carrier`, `target`, `tackler`, `interceptor`, `air_yards`/`run_after`, `hole`, `pocket_seconds`, `completion_chance`/`sack_chance`/`pick_chance` — so a scripted tween replay (`scripts/ui/play_replay.gd`, `BattleSettings.replay` default on) and `football_game`'s XP crediting both read the *same* choices (which WR, which tackler, which rusher sacked) instead of each re-rolling their own; the message/detail lines don't reveal the outcome until the replay's `finished` fires or it's skipped. The replay is tweens over labelled-dot markers (reusing `player_body.gd`'s drawing) on the existing field view, not a route through `scripts/football/`'s live-physics actors. A speed picker (1×/1.5×/2×) and the toggle itself live on the main menu (SIM only) and a scoreboard button mid-battle; both save with the mode. Headless harnesses default `replay = false` (a down still resolves synchronously in the tick it's called); `run.sh` also runs one `battle_test` pass with replay forced on that steps frames and asserts every down reaches `finished` within a bounded timeout. Verified headless (all eight harness runs) and visually in the exported Web build via headless Chromium: the main menu's toggle/speed row, an offense CALLING step mid-replay (markers in formation, ball mid-flight), a defense CALLING step, and post-down highlights for completions, incompletions, and runs on both sides of the ball. Not specifically captured on screen: a sack, an interception, and a touchdown flourish (all exercised by the same code path, just lower-probability draws), and the in-battle REPLAY button's click response and true 1×-real-time pacing — headless Chromium's render loop ran the whole animation faster than real time in every capture, so exact wall-clock pacing is unconfirmed even though the tween mechanics visibly interpolate correctly frame to frame.

Open (see `docs/DESIGN.md` §12–13): attack-origin choice when several apply, contracts, traits, training points *spend* UI, the champion's kept territory, balance passes (red-zone throws score too easily; Blitz is strong; ~4–5 empires alive at week 12), and a look at the offseason/draft screen specifically (not yet screenshotted with the new overall column).
