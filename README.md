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

## Border War battle test build

The current build replaces the single drive with one **Border War** battle between the Harbor Hawks and the Ironvale Forge: 7-a-side (QB, RB, two receivers, three linemen) on a 40-yard field, three possessions each, four downs with no punts or kicks, sudden death if tied. Every player has four stats (Speed, Power, Skill, Awareness) that drive route speed, pocket time, catch radius, interception radius, break-tackle odds, and pre-snap reads. The full design is in `docs/DESIGN.md`.

The main menu offers three ways to play the same battle, for testing which one feels right:

- **PLAY** — you call plays on both sides and throw the ball yourself on your passing plays. Hold the QB to snap, pull back *away* from the receiver you want (slingshot), watch the landing marker, release to throw. Runs, the run after the catch, and the whole defense play themselves; you can still drag to steer a runner if you want to.
- **WATCH** — you call every play on both sides and watch it play out. No throwing.
- **AUTO-RESOLVE** — the whole battle is simulated with the same cards and stats and you get the box score.

Offense cards: Slants, Deep Shot, Draw, Screen. Defense cards: Cover, Blitz, Spy. Draw and Screen are automatic in every mode.

Every battle opens on a **matchup screen**: both seven-man lineups with stat bars, the stakes, a home-crowd modifier (the attacker's throw scatter is +25%), a scouting line naming the weakest blocker-vs-rusher matchup and its pocket time, and a TAG button to mark one player as your franchise tag. From there you play, watch, or auto-resolve. During the battle a **border bar** under the score shows the line of scrimmage as the frontier between the two empires and moves live with the ball carrier.

The stakes line and franchise tag are display-only for now; territory capture and raids arrive with the season layer.

## Run

1. Open this folder in Godot 4.x.
2. Run the project (`F6`/`F5`, depending on editor workflow).
3. Pick a mode on the main menu.

## Deploy the browser build

The project includes a non-threaded Godot Web export and a GitHub Actions workflow that publishes it to GitHub Pages. The same workflow also creates a downloadable `gridiron-dynasty-web` artifact containing static files that can be hosted by any normal web server.

### One-time GitHub setup

1. Push the repository to GitHub with this project on the `main` branch.
2. Open **Settings → Pages** in the GitHub repository.
3. Under **Build and deployment**, set **Source** to **GitHub Actions**.
4. Push to `main`, or open the **Actions** tab and manually run **Deploy web prototype**.
5. When the workflow finishes, its deployment summary contains the public Pages URL.

Pull requests do not deploy publicly. This keeps unreviewed builds from replacing the playable version, while the manual workflow trigger makes it possible to redeploy at any time.

### Export locally

With Godot 4.3 and its matching export templates installed:

```bash
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html
```

Serve the resulting directory rather than opening `index.html` directly:

```bash
python3 -m http.server 8080 --directory build/web
```

Then visit `http://localhost:8080`. The export has browser threads disabled, so GitHub Pages and ordinary static hosts do not need custom cross-origin isolation headers.

## Controls (PLAY mode)

### Calling plays
- Tap a card at the bottom of the screen. On offense the card shows how it matches the defense's call if your QB's Awareness produced a read.

### Passing
- Press and hold the **QB** to snap and send receivers on their routes.
- Keep holding while you pull **away** from the receiver you want to hit; the ball flies opposite to the drag, like a slingshot.
- Longer pull = deeper throw. A target ring shows where the ball will land and turns red when a defender is close to that spot.
- Release to throw. The pocket timer is your Blocker's Power against their Rusher's; hold too long and you are sacked.

### Running
- Draw and Screen are automatic. So is the run after a catch.
- Touch/click and drag anywhere to take over steering; the runner keeps moving forward.
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
