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
