# Kickoff prompt for a new session

Paste this as the first message. `CLAUDE.md` is read automatically and carries the conventions and test commands, so the prompt only needs to set direction.

---

I'm continuing work on Gridiron Dynasty, a Godot 4.3 / GDScript game: Risk with football teams. Read `CLAUDE.md`, `README.md`, and `docs/DESIGN.md` first.

Work on whichever branch this session is assigned. There is no editor in this environment: verify changes with `tools/headless/run.sh --download` (or the individual harnesses it lists) before saying anything works. For anything visual, export the Web build and drive it with a headless Chromium (see "Verifying UI" below) — don't guess from code, and say plainly when something hasn't been checked that way.

State of the build:

- **Battle.** 7-a-side, stats-driven, 3 possessions each (5 for a capital assault), 4 downs, no kicks, sudden death if tied. Four play cards a side (Slants/Deep Shot/Draw/Screen vs Cover/Blitz/Spy) with a matchup table, a pre-snap read chance from Awareness, and a matchup screen with lineups, stakes, a home-crowd chip, and franchise tagging.
- **Four battle modes, SIM is now the default:** PLAY (you throw it yourself), WATCH (call plays, watch real-time), **SIM** (call plays, each down resolves instantly via `BattleSim.resolve_single_play` — same card/stat math as auto-resolve, no snap/pocket/throw animation, still credits a plausible player per down so XP accrues), AUTO-RESOLVE (whole battle, box score only, no XP). SIM became the default because the real-time engine wasn't reliable enough to carry a whole battle — see "Known issues" below for what's still rough about it.
- **Season map.** Twelve empires on a 6×4 grid, capital-model elimination with absorption, AI empires plan their own attacks, AI-vs-AI battles auto-resolve with auto-raids, season ends at last-standing or week 12.
- **Territory resource effects** (design §4.1): Academy/Capital pay weekly training points, Mines pay money — both banked per empire and shown on the map, but nothing spends them yet. Stadium/Capital give the defender a home-crowd edge (wider attacker throw scatter live, lower completion in SIM/auto-resolve). Highlands doubles fatigue-bar accrual in the battle fought there. Academy/Capital holdings also widen a just-drafted rookie's potential/stats.
- **Offseason.** Aging curve with retirement and journeyman replacement, one-round draft in reverse elimination order with scout grades and a forced same-slot cut, rookie protection for the following season, loyalty (raided players grow 25% slower).
- **Autosave/load.** Single JSON slot, written after every week/battle/raid/pick, resumes a mid-battle if you left one.
- All of the above pass their headless harnesses across all four battle modes.

What I want next: `<fill in — for example "a balance pass: red-zone throws score too easily and Blitz is too strong", "attack-origin choice when several apply", "training points spend UI", "contracts", or "go through every screen in an exported build and fix what looks wrong">`

Working style: build the thing, run the harnesses, commit and push with a descriptive message, then give me a short summary of what changed, what was verified, and what wasn't.

---

## Notes for the next session

### Verifying UI (no editor available)

The only way found so far to actually see the game, rather than guess from code:

1. Fetch export templates once per environment (large, ~1GB): `curl -sSL -o /tmp/templates.tpz https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz`, unzip, move the contents of `templates/` into `~/.local/share/godot/export_templates/4.3.stable/`.
2. Export: `$GODOT --headless --path . --export-release "Web" build/web/index.html` (uses `export_presets.cfg`, already checked in).
3. Serve it: `python3 -m http.server 8080 --directory build/web`.
4. Drive it with a headless Chromium via Playwright (`chromium-cli` was not installed in this environment; a small Node REPL driver using the global `playwright` package at `/opt/node22/lib/node_modules/playwright` and the Chromium binary under `/opt/pw-browsers/` worked fine — launch with `--no-sandbox`, no special GPU flags needed).
5. **It's a single `<canvas>`** — there is no DOM to select against. Drive it by pixel coordinate (`page.mouse.click(x, y)`) against the map/menu/matchup layout constants in the relevant `scripts/ui/*.gd` file, and confirm visually with `page.screenshot()`. Read the screenshot back — don't assume a click landed.

This is how the SIM mode UI, the default-mode change, and the AI QB throw-timing fix were all confirmed working this session; it's worth reusing rather than rediscovering.

### The merge-then-new-PR pattern

PRs on this repo get merged quickly, often before a session that just pushed to its branch is done working. If you push follow-up commits and then find your branch's PR already shows `merged`, **don't** push more commits onto that history as-is:

```bash
git fetch origin master
git merge origin/master -m "Merge master (PR #N) into branch, keeping <your commit> on top"
git push -u origin <branch>
```

This is non-destructive (no rebase/force-push) and keeps whatever you added on top of the now-merged history. Then open a fresh PR — the merged one can't be reused. This has come up in essentially every session so far; expect it.

### Known issues / rough edges

- **The real-time engine (PLAY/WATCH) is the reason SIM exists and defaults on.** The AI QB's throw timing was retuned this session (it now releases early once a receiver is clearly open, scaled by Awareness, instead of always waiting out `decision_seconds`) but the rest of the live physics — pocket collapse, defender AI, catch/tackle radii — hasn't had the same scrutiny. If PLAY/WATCH still feel off, that's the next place to look, or lean further into SIM as the primary way to play.
- **Fixed this session:** `RaidRules.can_take` used to compare Quick Battle's `season_number` sentinel (`-1`) against a player's default `rookie_season` (also `-1`), so every player misread as protected — nobody could be raided outside a season, and losing a Quick Battle soft-locked the raid screen. Fixed by treating `season_number < 0` as "no rookie protection." If you touch raid/rookie-protection logic again, watch for the same off-by-sentinel trap.
- Training points and money are banked but have no spend/consumer yet (see Phase 4 in `docs/DESIGN.md` §12).

### Design decisions already made (don't relitigate unless asked)

Roster is exactly 7 with no bench; no injuries, fatigue only (and fatigue itself is currently just a per-battle display, not a persistent stat-reducing mechanic); the QB throw is the only live control, defense is call-then-watch; run plays are automatic; a failed attack from your capital costs only the raid; the draft pick must displace a same-slot player; capital-model elimination is the default ruleset (sudden death was considered, not built).

### Known balance data from headless runs

Possessions score a touchdown roughly 40–50% of the time; interceptions are common in PLAY mode when a harness throws blindly; sacks are rare because the AI usually throws before the pocket collapses; with SIM/auto-resolve, typical seasons end with 2–7 empires still alive at week 12 depending on RNG.

### Harness reminder

They drive the real scenes by calling handlers (`_on_card_selected`, `_on_tile_pressed`, `_on_take_pressed`, ...). If you rename a handler, update the harness that uses it. Add a harness when you add a system; extend the nearest one when you change rules.
