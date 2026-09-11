# Kickoff prompt for a new session

Paste this as the first message. `CLAUDE.md` is read automatically and carries the conventions and test commands, so the prompt only needs to set direction.

---

I'm continuing work on Gridiron Dynasty, a Godot 4.3 / GDScript game: Risk with football teams. Read `CLAUDE.md`, `README.md`, and `docs/DESIGN.md` first.

Everything so far is on branch `claude/gameplay-ideas-kn5bbo` — keep working there. There is no editor in this environment: verify changes with `tools/headless/run.sh --download` (or the individual harnesses it lists) before saying anything works, and tell me plainly when something is untested visually.

State of the build: the battle (three modes), the season map with AI empires and elimination, raids, the offseason with aging and a draft, and autosave/load are all built and pass their harnesses. Nothing has been looked at in the editor yet.

What I want next: <fill in — for example "the territory resource effects from DESIGN.md §4.1", "a balance pass on the battle: red-zone throws score too easily and Blitz is too strong", or "fix layout problems I found on the draft screen: ...">

Working style: build the thing, run the harnesses, commit and push with a descriptive message, then give me a short summary of what changed, what was verified, and what wasn't.

---

## Notes for the next session

- The harnesses drive the real scenes by calling handlers (`_on_card_selected`, `_on_tile_pressed`, `_on_take_pressed`, ...). If you rename a handler, update the harness that uses it.
- Design decisions already made (don't relitigate unless asked): roster is exactly 7 with no bench; no injuries, fatigue only; the QB throw is the only live control, defense is call-then-watch; run plays are automatic; a failed attack from your capital costs only the raid; the draft pick must displace a same-slot player.
- Known balance data from headless runs: possessions score a touchdown roughly 40–50% of the time, interceptions are common in PLAY mode when the harness throws blindly, sacks almost never happen because the AI throws before the pocket collapses.

## The direction changed: play-calling and stats, not a live throw

SIM is now the only selectable battle mode alongside AUTO-RESOLVE. PLAY and WATCH (the live QB slingshot, receiver/defender AI in `scripts/football/`) are still fully in the codebase and stay parse-clean/runnable — `tools/headless/run.sh` still runs one WATCH battle (`battle_test 1 1`) specifically to prove that — but their menu buttons are gone behind `BattleSettings.SHOW_REALTIME_MODES: bool = false`. Don't invest further in the real-time engine unless asked; the SIM path (`BattleSim.resolve_single_play` called from `football_game._resolve_sim_play`) is the one that matters now.

## The call sheet: balance knobs

- `PlayBook.coordinator_read`'s certain-chance is `clamp(rating/100 × 0.7, 0.1, 0.7)` — the `0.7` is the ceiling and the main knob if coordinators feel too psychic or too useless; it stacks *independently* with the QB/Safety's own Awareness tier-2 read (`PlayBook.read_tier`, ramping 35→95 Awareness to a 60% ceiling) — either one landing is enough to hand the player the exact card (`football_game._offer_cards`'s `exact` flag is `tier == 2 or coord.certain`), so a high-Awareness QB behind a sharp OC reads the defense almost every down. If that's too strong, drop one side's ceiling rather than both — they're meant to be complementary signals (mechanical skill vs. coaching), not the same knob twice.
- `BattleSim.expected_yards` is the resolver's whole play, collapsed to one number without dice (a pick costs −15, a sack −6); `suggest_offense`/`suggest_defense` just maximize/minimize it, so any future rebalance of `_resolve_play`'s math (completion rates, run means, the matchup table) automatically reflects in which card gets the ★.

## Part C: what was checked visually, what was trimmed

Exported the Web build (`--export-release "Web"`, templates fetched from the 4.3-stable GitHub release) and drove it with headless Chromium via Playwright (screenshots, not a live session — no manual click-testing beyond what the script did). Checked: the main menu (PLAY/WATCH correctly absent, SIM shown as "call the plays"), the matchup screen (overall + grade next to every name, no overlap with the TAG button/chip), a SIM offense-calling step with all six cards + the read/coach lines + the lineup strips, the same on defense (four cards, and the strips' slot labels correctly flip S/LB/CB/X ↔ QB/RB/WR/BL when the ball changes hands), a resolved down (message + detail line + post-down highlight), the aftermath screen, the raid screen, the season map, and the season map's roster overlay. All read cleanly at 1280×720.

Two real bugs the first render caught and this session fixed:
1. The real-time player sprites (QB/WR/CB/etc. circles) were still being positioned and drawn on top of the lineup strips in SIM, since `_assign_teams`/`_prepare_play` build the real-time formation regardless of mode. Fixed by hiding `qb`/`running_back`/`receivers`/`blockers`/`defenders` whenever `BattleSettings.is_realtime(mode)` is false; the field background itself stays visible as a backdrop.
2. The ★ marker on a card's suggested play, and the six-card row's stat-hint line, didn't fit: ★ isn't in Godot's default bundled font (rendered as a tofu box) and the hint text at 14pt overflowed each 198px-wide `Button` into its neighbour since `clip_text` was false, visually merging adjacent cards' text. Fixed by swapping ★ for a plain `*`, shortening every `BattleSim.card_edges` hint string (dropped the `SPD`/`SKL`/`PWR`/`AWR` unit words, e.g. `QB SKL 81 • WR SPD 78 v CB 75` → `QB81 WR78 v CB75`), dropping the card font to 12pt, and turning `clip_text` on as a safety net for anything still too long.

Not checked visually: the offseason/draft screen and the in-battle roster-picker row (`offseason_screen.gd`) with the new overall column — they go through the same `PlayerRow.build` that's now confirmed working in four other contexts (matchup, raid, season map overlay, and the lineup strips' own separate row-builder), so it's very likely fine, but genuinely unverified. No other layout debt found at 1280×720; narrower viewports (phone-width, if this is ever played in a resized browser tab) haven't been checked at all — the whole UI assumes the fixed 1280×720 canvas it's always assumed.

## Watching the play (Part D): what was checked, what wasn't, and one honest caveat

`BattleSettings.replay` defaults to `true`. The result dictionary `BattleSim._resolve_play` returns grew several structural fields (`ball_carrier`, `target`, `tackler`, `interceptor`, `air_yards`/`run_after`, `hole`, `pocket_seconds`, the three chance floats, plus the two card indices) — these are now **load-bearing** for three consumers that all read the same source instead of re-rolling: the replay (`scripts/ui/play_replay.gd`), `football_game._resolve_sim_play`'s XP crediting, and the lineup strips' post-down highlight. Anyone touching `_resolve_play`'s branches needs to keep filling these in via the `_finish()` helper or the replay/XP/highlight will silently go stale relative to the detail string.

Checked headless: all eight `run.sh` passes green, including a new `battle_test 3 1 1` run with replay forced on that steps frames through several full battles and asserts every down reaches the replay's `finished` signal within a 10-second-of-frames bound, then that the detail line, lineup rows, and a highlight are all populated afterward. `season_flow_test`/other harnesses keep `replay = false` so the existing synchronous-down assumption they were written against still holds.

Checked visually (exported Web build, headless Chromium via Playwright, screenshots only — no manual play): the main menu's new "WATCH THE PLAY: ON/OFF" toggle and 1×/1.5×/2× speed row (shown only when SIM is selected, matching the mode-button pattern); the in-battle scoreboard's compact `REPLAY: 1.0x` button in the top bar (doesn't collide with the score/situation/possession labels or the border bar); an offense CALLING step mid-replay with the fourteen markers in a plausible pre-snap-through-route formation and the ball marker visibly mid-flight between frames (confirmed real tween interpolation, not a teleport, by diffing consecutive screenshots); a defense CALLING step (four cards, slot labels correctly flipped to S/LB/CB/CB/X/X/X); and post-down highlights for a completion, an incompletion, and a run, on both the offense and defense side of the ball across several possessions (including the DC's read line, the coach personality line, and 4th-down/red-zone situation tags all still populated).

Not confirmed visually: a sack, an interception, and a touchdown flourish specifically — same code path as the above (`_sequence_sack`/`_sequence_interception`/the touchdown branches in `_sequence_pass_complete`/`_sequence_run`), just lower-probability draws that didn't come up in the downs captured this session. Also not confirmed: the in-battle REPLAY button's click response (toggling off / cycling speed mid-battle) and clicking/tapping the field to skip mid-replay — the skip path (`Tween.custom_step(999.0)`) is standard Godot 4 API and was reviewed carefully, but wasn't exercised through an actual click in the exported build. One genuine environment caveat: headless Chromium's render loop finished every captured replay well under one real second of Node-side wall-clock time regardless of the 1× setting, even though the markers visibly interpolate correctly between frames — this looks like a headless-rendering-loop artifact (no real vsync/tab-visibility throttling under Playwright automation) rather than a bug in the tween durations, but true 1×-real-time pacing in a normal, focused browser tab was not directly confirmed.

Simplification made for scope: the spec's "both cards flip face-up on the scoreboard at the snap" was dropped — the scoreboard already hides the card bar before the replay starts, and adding a world-space caption would have meant either fighting the CanvasLayer/world z-order (see below) or a second small UI surface for one line of text. The "Watch the play…" message on the scoreboard's message line stands in for it. One layout curiosity, not a bug: the replay's world-space markers render *in front of* the CanvasLayer lineup strips wherever they spatially overlap (screenshots show a marker cleanly on top of strip text rather than tinted by the strip's translucent row background) — visually fine (it keeps the live play legible), but if the strips are ever changed to a higher `CanvasLayer.layer` expecting to draw over the world, verify this doesn't flip.
