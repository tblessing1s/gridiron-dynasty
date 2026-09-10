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

After the battle, an **aftermath screen** shows the result, the border bar filled to the winner's color, the possession log, the XP each player earned from what they actually did (catches and completions grow Skill, yardage grows Speed, tackles, pocket wins and sacks grow Power, interceptions and touchdowns grow Awareness; capped at +2 per stat per battle), and your team's fatigue. Then the **raid**: if you won, tap any unprotected Forge player to take him and pick one of yours at the same slot to send back; if you lost, the Forge take your best unprotected player and you watch. Both movers arrive with a -5 morale hit to every stat. The franchise tag you set on the matchup screen is the one player they cannot take. Roster changes and XP carry into the next battle for as long as the game scene is open; going back to the main menu resets both teams.

## Season map

**NEW SEASON** from the main menu opens the map: twelve empires on a 6×4 grid of territories, two each to start (a capital and one outer territory). Each week you tap an adjacent enemy territory (white outline) and **ATTACK**, or **REST**. AI empires plan their own attacks the same week; each empire fights at most one battle per week. Your battle plays in whichever mode you chose on the menu; every AI-vs-AI battle is auto-resolved with the same simulator.

- Win an attack: the territory is yours. If it was their capital, they are eliminated and you absorb everything they held.
- Lose an attack: the defender takes the territory you attacked from — unless that was your capital, which only falls to a direct attack. Lose your capital and you are out.
- Every battle ends in a raid, AI ones included. Your franchise tag locks for the season the first time you set it; AI empires tag their best player.
- XP and raids persist across the season; **CONTINUE SEASON** on the menu resumes it, including a battle you left mid-way.
- The season ends when one empire is left or after week 12; the largest empire wins. If you are eliminated you can sim the remaining weeks.

### Territory resources

Every territory has a resource, and it now does something:

- **Academy** and **Capital** each pay the holder 1 training point per week (shown next to your empire's name on the map, alongside your banked money). Nothing spends training points yet — that lands with the traits/training-points feature.
- **Mines** pay money instead, same weekly cadence. Nothing spends money yet either — that's for the future contract system.
- **Stadium** and **Capital** territories give the defender a home crowd: the attacker's throws scatter wider (live battles) or complete less often (auto-resolve) in the battle fought there. The matchup screen only shows the "Home crowd" chip when it applies.
- **Highlands** territories double how fast fatigue bars fill in the battle fought there (shown on the aftermath screen), rewarding a rested roster.

## Offseason and draft

When a season ends, **OFFSEASON** runs three steps:

1. **Aging.** Every player gets a year older. Under 24 they grow fast toward a hidden per-stat potential; 24–28 they creep up; 29–31 they decline (Speed first); 32+ they decline hard and roll to retire. Retirees are replaced by a journeyman free agent at the same slot. Morale hits from raids clear here.
2. **Draft.** One round, first eliminated picks first, the champion picks last. An 18-rookie class with a scout grade (A+ to D, slightly noisy) instead of visible potential. Every pick must replace one of your players at the rookie's slot — the roster stays at seven — so drafting is also a cut. AI empires pick for ceiling and cut their weakest at that slot. Your rookie cannot be raided for the whole coming season. Drafting with an Academy in your holdings widens the rookie's hidden potential; drafting with more than one Capital (from eliminating rivals) sharpens their actual stats too, capped at that potential.
3. **New map.** Everyone returns to their capital and outer territory, eliminated empires included; rosters carry over; tags reset (banked training points and money reset too — there's no way to spend them yet, so nothing carries).

Players also carry an origin: raided players grow slower for good (each XP point is kept three times in four), so raiding builds win-now teams and drafting builds long-term ones. XP never lifts a stat above its potential.

## Saving

The dynasty autosaves to `user://dynasty.json` after every week, battle result, raid, draft pick, and new season — one save slot, no manual saving. The main menu loads it on startup and offers CONTINUE SEASON or CONTINUE OFFSEASON; a battle you left mid-way resumes at its matchup screen. NEW DYNASTY replaces the save. Quick battles are never saved. A save from a different version of the game is ignored rather than loaded.

Territory resources now pay training points/money and apply battle modifiers (see above); there are no contracts yet, and nothing spends the training points or money.

## Run

1. Open this folder in Godot 4.x.
2. Run the project (`F6`/`F5`, depending on editor workflow).
3. Pick how you play battles (PLAY / WATCH / AUTO), then **NEW SEASON** or **QUICK BATTLE**.

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
