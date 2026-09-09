# Gridiron Dynasty — Phase 1 Prototype

A Godot 4.x / GDScript vertical slice implementing the first playable offensive-drive milestone from the supplied design brief.

## Included in Phase 1

- Main menu
- Code-drawn football field and placeholder players
- Quarterback drag-to-aim / release-to-throw passing
- Projected throw path
- Two receiver routes with a pre-snap route diagram
- Four simplified defenders with coverage / ball reaction / pursuit
- Catch radius logic
- User-steerable running after the catch
- Tackling and out-of-bounds
- Downs and yards-to-go
- First downs
- Touchdown detection
- 5:00 drive clock
- Scoreboard
- Play reset and drive restart
- Original fictional matchup: the Harbor Hawks vs. the Ironvale Forge

No franchise, player-development, save, draft, coaching, or league systems are implemented yet by design.

## Run

1. Open this folder in Godot 4.x.
2. Run the project (`F6`/`F5`, depending on editor workflow).
3. Press **START DRIVE**.

## Controls

### Passing
- Press and hold the **QB** to start the play and send receivers on their routes.
- Keep holding while you drag in the direction you want to throw.
- Longer drag = deeper throw.
- The ball is not thrown until you release.

### Running after catch
- Touch/click and drag anywhere to steer.
- The runner automatically moves forward.
- Keyboard fallback: WASD / arrow keys.

## Phase 1 completion target

The prototype intentionally stops at the smallest vertical slice: launch the game, run routes, throw passes, gain yards, get first downs, and score a touchdown.

Defenders remain set until the throw, then transition from coverage to pursuit. A brief catch-protection window keeps successful completions readable and gives the player a fair moment to begin steering before tackle checks start.

## Notes

The project is intentionally asset-light. Field, players, and football are drawn in code so gameplay can be validated before investing in final pixel art.

## Android editor compatibility update

This package uses explicit script preloads/path inheritance for the Phase 1 gameplay scripts rather than depending on Godot's global `class_name` cache. This makes first-time imports in the Godot Android editor more reliable. The defender script was also simplified to avoid cross-script typed references during parsing.


## Godot warning-as-error compatibility

This revision uses explicit local variable types and the type-safe numeric helpers (`lerpf`, `minf`, `maxf`, `clampf`, `mini`, `maxi`, `clampi`) so Godot installations that treat GDScript type-inference warnings as errors can parse the Phase 1 scripts cleanly. It also removes the duplicate `GameConstants` declaration from the receiver child script.
