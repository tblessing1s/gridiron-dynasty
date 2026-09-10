# Gridiron Dynasty — Game Design Document

Status: draft v1. Supersedes the Phase 1 "single offensive drive" scope in the README as the long-term direction. The Phase 1 drive prototype becomes the core of the battle (section 5).

## 1. One-line pitch

Risk with football teams. Each season, rival empires attack each other's territory in short 7-a-side battles. Win and you capture the territory and raid one of their players. Lose and your season is over, but you draft high. Build a 7-player dynasty over many seasons.

## 2. Design pillars

1. **Every player matters.** Rosters are 7 deep. Losing one player is losing 15% of your team.
2. **Short battles, long stories.** A battle takes 3–5 minutes. A dynasty takes many seasons. The season is the unit of play; the career is the unit of memory.
3. **Two ways to build.** Raid to win now; draft to win later. Both must be viable, and the tension between them is the game.
4. **The map and the roster feed each other.** Territory produces the resources that grow players. Players win the battles that capture territory.
5. **Asset-light.** Everything is drawable in code. The prototype already proves this.

## 3. The season loop

```
  Offseason ──► Map (weekly attacks) ──► Battle ──► Aftermath ──► Map ...
      ▲                                                            │
      └──────────── last empire standing / week limit ─────────────┘
```

1. **Map.** 12 empires each hold a capital territory (plus outer territories they capture). Each week, every empire picks one adjacent enemy territory to attack. The player does the same; AI empires attack the player too. One battle per empire per week.
2. **Battle.** A short Border War game (section 5). The player can play it or auto-resolve it.
3. **Aftermath.** Winner captures the territory and raids one player. If the loser's capital fell, the loser is eliminated for the season.
4. **Season end.** The season ends when one empire stands, or at the week limit (default 12), in which case the largest empire wins.
5. **Offseason.** Draft, aging, contracts, training reset. Map partially resets (see 4.4).

Elimination order sets draft order: first eliminated picks first. Being knocked out early is bad for the season and good for the dynasty.

### 3.1 Two elimination variants

- **Capital model (default).** Losing a border battle costs you that territory and a player: a failed attack hands the defender the territory you attacked from, unless that was your capital, which only ever falls to a direct attack. You are eliminated only when your capital falls. Every empire has 2–3 lives once it has captured a territory or two.
- **Sudden death.** Any loss eliminates. Simpler and more brutal. Kept as an optional ruleset toggle.

Eliminated players fast-forward through the remaining weeks (results shown as a ticker) straight to the offseason, where the draft is their payoff.

## 4. The map

### 4.1 Territories

~20–30 territories, fictional regions. Each has:

- An **owner** (empire) or none.
- **Adjacency** to neighbours (attack routes).
- A **resource type** that pays out to the holder each week and in the offseason.
- An optional **battle modifier** applied when a battle is fought there.

| Resource | Weekly payout | Offseason payout | Battle modifier |
|---|---|---|---|
| Academy | +1 training point | rookie potential range +5 | — |
| Stadium | — | — | Home crowd: attacker throw accuracy −10% |
| Mines | +money | +money | — |
| Highlands | — | — | Fatigue accrues 2× (favours fresh, well-rested rosters) |
| Capital | +1 training point | draft class quality bonus | Home crowd |

### 4.2 Attacking

The player picks one adjacent enemy territory per week. Attacking is always optional; a week with no attack is a rest week (fatigue fully recovers). AI empires attack based on a simple heuristic: weakest adjacent neighbour, weighted by resource value, with a rest chance that rises with fatigue.

### 4.3 Being attacked

If an AI empire attacks the player, the player must fight (or auto-resolve). If two attacks land on the player in one week, they are resolved in order; fatigue carries between them, so a big empire with many borders is exposed. This is the Risk overextension penalty.

### 4.4 Offseason map reset

Capitals are kept. Outer territories return to neutral, except that the season winner keeps one captured territory of their choice as a permanent holding. Over several seasons the champion accumulates a real empire, and everyone else is trying to carve into it.

## 5. The battle: Border War

The battle is 7-a-side football on a short field. The line of scrimmage is the frontier between the two empires; a **border bar** across the top of the screen shows it as a tug-of-war over the contested territory.

### 5.1 Format

- Field: 40 yards plus two 10-yard end zones, portrait orientation.
- Ball starts at midfield. Attacker has the ball first.
- **3 possessions each**, alternating.
- **4 downs, no punts, no field goals.** Every 4th down is a go.
- Touchdown = 7 (automatic PAT). Turnover on downs flips the ball at the spot.
- Tie after 6 possessions → sudden death: one possession each until settled. There are no ties.
- ~20–25 plays, 3–5 minutes.

### 5.2 Stakes scaling

| Target | Format |
|---|---|
| Outer territory | 3 possessions each (default) |
| Low-value territory | 1 possession each, or auto-resolve |
| Capital assault | 5 possessions each; a season-deciding event |

### 5.3 Matchup screen

Before the battle:

- Both 7-man lineups shown, with fatigue on each player.
- Stakes printed plainly: *WIN: capture Ironvale + raid one player. LOSE: lose Harbor, raid.*
- Player can set the franchise tag (section 7.2). There is no lineup decision: all seven play.
- Territory modifiers shown as icons.

### 5.4 An offensive play

1. **Call.** Choose one of ~4 play cards: Slants, Deep Shot, Draw, Screen. The AI defence chooses its card face-down: Cover, Blitz, Spy.
2. **Read.** QB Awareness decides how much of the defence's card is revealed before the snap ("Defense is BLITZING" vs. nothing).
3. **Snap.** Press and hold the QB. Receivers run the card's routes. Existing Phase 1 behaviour.
4. **Pocket.** Blocker Power vs. Rusher Power sets pocket time (2–5 seconds). A collapsed pocket is a sack.
5. **Throw.** Pull away from the receiver you want (slingshot), watch the landing marker, release. QB Skill sets accuracy scatter; receiver Skill sets catch radius; defender Skill sets interception radius. The marker turns red when a defender is close to the landing spot.
6. **Run after catch.** Automatic. Runner Speed vs. pursuit Speed; runner Power vs. tackler Power gives a break-tackle chance. Dragging takes over steering if the player wants it.
7. Play ends on tackle, out of bounds, score, or incompletion. ~8 seconds.

**Run plays** (Draw, Screen): hold the QB, release toward the RB to hand off, steer the RB. Blocker leads. Draw beats Blitz; Draw into Cover is stuffed.

### 5.5 A defensive play

1. Choose a defensive card: Cover, Blitz, Spy. The Safety's Awareness decides whether you get a pre-snap read of the offense's look (run or pass).
2. Watch. All five defenders run the card's assignment on AI. There is no live defensive control; the call is the whole decision.

### 5.6 Involvement modes

**The game is play-calling and stats, not a live throw.** Sim — call every play, each down resolves instantly with the same card/stat math as auto-resolve — is the mode the player sees. Play and Watch (the live QB slingshot throw, receiver/defender AI) are kept in the codebase and stay parse-clean and runnable, but their menu buttons are hidden behind `BattleSettings.SHOW_REALTIME_MODES`; a save file set to one of them coerces to Sim on load.

| Mode | Offense | Defense | Shown on menu |
|---|---|---|---|
| Play | call the card, throw the ball (slingshot: pull away from the target, release) | call the card, watch | hidden |
| Watch | call the card, AI throws | call the card, watch | hidden |
| Sim | call the card, down resolves instantly with the same card/stat math as auto-resolve — no snap/pocket/throw animation | call the card, down resolves instantly | **default** |
| Auto-resolve | whole battle simulated with the same cards and stats; box score only | — | shown |

Draw, Screen, and Sweep are automatic (run-resolved) in every mode. Steering the runner is optional in Play mode. Sim keeps every down-by-down decision (cards, tagging, stakes) but removes the physics step; Auto-resolve removes per-down control entirely.

### 5.7 Play-call matrix

Six offense cards, four defense cards. Yardage multiplier:

| | Cover | Blitz | Spy | Press |
|---|---|---|---|---|
| Slants | even | good | even | bad |
| Deep Shot | bad | great | even | great |
| Draw | good | great | bad | good |
| Screen | even | good | bad | bad |
| Sweep | good | great | bad | great |
| Play Action | good | bad | great | good |

The matrix is a bias, not a lock. Stats and player input decide the play. Draw, Screen, and Sweep resolve as runs; Play Action resolves as a pass (with a higher sack chance and a play-fake) but *reads* as a run before the snap — it is meant to bait a defense that leans on its pre-snap look. Press plays tight man coverage: cheaper against short/quick routes, more exposed deep, and it tightens the real-time corners' coverage offset.

**Situational calling.** Both AI sides weight their card choice by down, distance, red zone, 4th down, the final possession of regulation while trailing, and sudden death — short yardage leans run, long yardage and the red zone lean away from the deep shot (red zone: away from it; both trailing-late and 4th-and-long lean into it), a 4th-down defense gambles more, sudden death goes conservative on both sides. Every empire also carries a fixed **coach personality** (`PlayBook.coach_tendency`, seeded from its id — nothing new to save) with a run/pass lean and a blitz/coverage lean that shades its calls further; the hand-made quick-battle rosters call evenly.

**Tiered pre-snap reads.** The QB's (or Safety's) Awareness decides how much of the other side's call is revealed before the snap, in three tiers: the exact card (chance ramping from Awareness 35 up to 60% at 95), a family-level look — RUN vs. PASS on offense, COVERAGE vs. PRESSURE on defense — at `awareness/100 × 0.9`, or nothing (`PlayBook.read_tier`). See §5.7a for how this combines with a coordinator's own read.

### 5.7a The call sheet

Every card face shows its stat matchup, not just the name: `card_edges` names the players and numbers that decide each card (`QB SKL 81 • WR SPD 78 v CB 75`, `RB 79/70 v LB 75/72`, `RUSH PWR 82 v LINE 80`, ...), and `expected_yards` collapses the resolver's whole probability tree into one number (a pick charged at −15, a sack at −6) so `suggest_offense`/`suggest_defense` can pick the mathematically best card for the situation — Deep Shot discounted in the red zone, passes discounted on short yardage.

Each side has an **OC** and a **DC** (`Rosters.ensure_coaches`, rating = team rating ±12, generated once per team and carried across seasons and saves). Whichever coordinator is on the "read" side of the ball — the OC when the player is on offense, the DC when on defense — gets a read on the other side's call: with a rating-scaled chance (`clamp(rating/100 × 0.7, 0.1, 0.7)`) he simply has the signal; otherwise he scores every card by the situational weights plus how often that side has already called it this battle, and guesses the top scorer (`PlayBook.coordinator_read`). That guess, or the QB/Safety's own exact tier-2 read when it lands, becomes the card bar's "expect X, call Y" line, alongside the fixed coach-personality read of the opponent ("pass-happy, blitzes a lot"). Every card's stat-hint line carries a ★ on the coordinator's own suggested call.

After every down, the message line is followed by a **detail line** naming the exact numbers the resolver used to reach that result — `SLANTS vs PRESS (bad ×0.60) • Bell SKL 81 • WRs SPD 84/72 vs CBs 75/71, Rowe AWR 60 • 41% to complete`, or the RB/LB and line numbers for a run, the pocket numbers for a sack, the pick chance for an interception.

### 5.8 Auto-resolve

Any battle can be auto-resolved. The resolver runs the same play-call matrix and stat comparisons without the real-time step, producing a plausible box score. Used for AI-vs-AI battles every week and for the player when they choose to skip.

### 5.9 Grid-tactics alternative

Everything from the matchup screen to the aftermath is identical if 5.4/5.5 are replaced with a turn-based grid: players move a Speed-based number of squares, contact triggers a Power roll, throws roll on Skill vs. distance and coverage. Deferred; the real-time version has the head start.

## 6. Players

### 6.1 Roster

Exactly **7 players, no bench**. All seven start and everyone plays both ways. A raid always costs a starter, and there is nowhere to hide a tired player — that is the point.

| Slot | Offense | Defense | Key stats |
|---|---|---|---|
| 1 | QB | Safety | Skill, Awareness |
| 2 | RB | Linebacker | Speed, Power |
| 3 | WR | Cornerback | Speed, Skill |
| 4 | WR | Cornerback | Speed, Skill |
| 5 | Blocker | Rusher | Power, Awareness |
| 6 | Blocker | Rusher | Power, Awareness |
| 7 | Blocker | Rusher | Power, Awareness |

Three linemen a side make the pocket a real contest: each rusher fights his own blocker, and the pocket lasts until the first one wins.

There are no injuries and no substitutions; fatigue is the only wear mechanic. A tired player plays worse, never sits. Rest weeks are the only relief.

### 6.2 Stats

Four stats, 0–99:

| Stat | Offense | Defense |
|---|---|---|
| Speed | route/run speed | pursuit, coverage closing |
| Power | pocket time (Blocker), break tackle | pass rush, tackle |
| Skill | throw accuracy (QB), catch radius | interception radius |
| Awareness | pre-snap read of the defence's card | reaction time to the throw |

Plus: **age**, hidden **potential** (ceiling per stat), one **trait** slot, **fatigue**, **origin** (drafted/raided, by whom, when), **contract** (seasons remaining).

### 6.3 Player card

Four stat bars with a potential arrow on each (revealed after a few battles), age, trait, and a history line: *Drafted S2 #1 by Hawks · Raided S4 by Forge · Deep Threat unlocked S5.*

Every row that shows a player also shows a slot-weighted **overall** (0–99) next to the name, with the same letter grade the draft's scout report uses (`Rosters.overall`/`Rosters.grade`): QB weights Skill/Awareness heaviest, RB and Blocker weight Speed/Power or Power/Awareness, WR weights Speed/Skill. The weighting is by the player's fixed offensive slot (QB/RB/WR/Blocker) regardless of which side of the ball a screen happens to be labelling him for.

### 5.7b Lineup strips

In Sim the field itself is idle between calls, so it doubles as the roster view for the whole battle: two seven-row strips (your team left, theirs right, in team colours) between the top bar and the card bar, each row showing slot, name, overall + grade, and all four stats. Selecting a card highlights the players it leans on — `LineupStrips.highlight_card`, using the same groupings `BattleSim.card_edges` names (QB + both WRs vs. both CBs + Safety for a pass-family card, the RB vs. the LB for an inside run, the RB vs. the LB and both CBs for the Sweep, the three blockers vs. three rushers for Blitz) — and after a down resolves, the players named in the result line stay highlighted until the next card is picked (`highlight_players`, called with the offense/defense indices `_resolve_sim_play` actually credited). The strips hide themselves whenever a real-time mode is active (`BattleSettings.is_realtime`), so the field stays uncluttered if `SHOW_REALTIME_MODES` is ever flipped back on.

## 7. The raid (post-battle swap)

### 7.1 Rule

The winner picks any **unprotected** player from the loser's roster and sends back a player of the **same slot**. Position-for-position keeps rosters legal and makes the choice about upgrading a slot rather than hoarding.

### 7.2 Protection

- **Rookie protection.** A drafted player cannot be taken during their first season.
- **Franchise tag.** Each empire tags one player per season; that player cannot be taken. The tag can be set any time before a battle and is locked for the season once used.
- Protection blocks being *taken*. The owner can still choose to *give* a protected player in a swap.
- Worst case: 2 protected of 7, 5 poachable. Winning always yields a real choice.

### 7.3 Raided players

- Arrive with a **morale penalty** for the rest of the season (small stat malus, e.g. −5 all stats), full strength next season.
- Grow 25% slower than drafted players for their whole career on the new team (see 8.4 Loyalty).

## 8. Progression

### 8.1 Age curve

| Age | Effect |
|---|---|
| 20–23 | Fast growth toward potential |
| 24–28 | Prime; slow growth, stable |
| 29–31 | Decline begins; Speed drops first |
| 32+ | Steep decline; retirement roll each offseason |

### 8.2 Battle XP

Stats grow from what a player actually does in battles. Catches grow Skill and Speed; pocket wins grow Power; interceptions grow Awareness. Playing a rookie over a better vet is an investment.

### 8.3 Training points

Each week the empire receives training points: 1 base, +1 per Academy held, +1 for the capital. Spend them on a player and stat: *Focus RB on Speed.* Unspent points are lost.

### 8.4 Loyalty

Drafted players grow at full rate. Raided players grow at 75%. A raided star never quite becomes what he would have been on the team that drafted him.

### 8.5 Traits

One trait slot per player, unlocked by crossing a milestone (once per player per season):

| Trait | Effect |
|---|---|
| Deep Threat | catch radius +20% on throws over 20 yards |
| Bulldozer | always breaks the first tackle from a lower-Power player |
| Film Junkie | always reveals the defence's card |
| Ironman | never fatigues |
| Mentor | rookies on the roster grow 25% faster |
| Ball Hawk | interception radius +25% |

### 8.6 Fatigue

- Fatigue accrues per battle and per play; a fatigued player has reduced Speed and Power. Only rest weeks recover it, so attacking every week wears the whole roster down.
- No injuries. Players are never unavailable; the cost of overuse is a worse player, not a missing one.

## 9. Offseason

In order:

1. **Retirements.** Players 32+ roll to retire; the roll worsens each year.
2. **Aging.** Growth or decline applied per the age curve; potential revealed for any player who has played enough.
3. **Contracts.** Every player is on a 3-season deal. Expired deals re-sign at a price scaled to rating; an empire that cannot pay loses the player to the draft pool.
4. **Draft.** One round, reverse elimination order. Class quality scales with the drafter's Academy/capital holdings. Draft slot sets the potential range: #1 pick 80–95 ceiling, #12 pick 60–80. Drafted players are protected for the coming season.
5. **Map reset.** Per 4.4.
6. **Season summary.** Standings, champion, awards (most raids, best rookie), and each player's history line updated.

## 10. Screens

1. **Main menu** — New dynasty, Continue, Settings.
2. **Map** — territories, owners, adjacency, attack selection, weekly summary ticker.
3. **Roster** — 7 player cards, training point spend, franchise tag.
4. **Matchup** — lineups, stakes, modifiers, play/auto-resolve.
5. **Battle** — field, border bar, play cards, scoreboard.
6. **Aftermath** — result, border bar fill, XP, raid picker.
7. **Draft** — draft order, class, pick.
8. **Season summary**.

Portrait, touch-first, keyboard fallback.

## 11. Data model (sketch)

```
Player
  id, name, age, slot
  speed, power, skill, awareness           # 0–99
  potential { speed, power, skill, awareness }   # hidden until revealed
  trait, fatigue
  origin { kind: drafted|raided, season, empire, pick }
  loyalty_rate                             # 1.0 drafted, 0.75 raided
  contract_seasons, morale_penalty
  history []                               # text lines

Empire
  id, name, colors, is_player
  capital_id, territories []
  roster [7 Player]
  franchise_tag_id, money, training_points
  eliminated_week

Territory
  id, name, adjacency [], resource, owner_id, modifier

Season
  number, week, empires [], territories []
  elimination_order [], attacks_this_week []

Save
  seasons [] summaries, current Season, settings
```

## 12. Build plan

Each phase is playable on its own.

- **Phase 1 (done).** Single drive: drag-to-throw, routes, defenders, downs, clock.
- **Phase 2 — Border War (in progress).** Turn the drive into the battle: 3 possessions each, 4 downs, no kicks, play cards, RB/Blocker/Rusher, stats-driven physics, three involvement modes, auto-resolve. Two hard-coded rosters, matchup screen, border bar, home-crowd modifier, aftermath with battle XP and fatigue, the raid with franchise-tag protection and the morale penalty (rosters persist for the session). Still to do: stakes scaling, balance pass.
- **Phase 3 — Season (in progress).** Done: Empire/Territory/Season model, map screen, weekly attacks, AI empire attack planning, one battle per empire per week, capital-model elimination with absorption, AI-vs-AI auto-resolve with auto-raids, tag locking, season end at last-standing or week 12, rookie protection, autosave/load of the whole dynasty (single JSON slot), territory resource effects (Academy/Capital training points, Mines money, Stadium/Capital home crowd, Highlands fatigue). Still to do: attack-origin choice when several apply.
- **Phase 4 — Dynasty (in progress).** Done: age and hidden per-stat potential, aging curve with retirement and journeyman replacements, one-round draft in reverse elimination order with scout grades and a forced same-slot cut, rookie protection for the following season, loyalty (raided players grow slower), morale clearing, map reset with everyone back, Academy/Capital holdings bump a drafted rookie's potential/stats. Still to do: contracts, traits, training points (banked but unspendable so far), history lines, the champion's kept territory.
- **Phase 5 — Polish.** Map reset rules, stakes scaling, territory modifiers, awards, balance passes on the play-call matrix and age curve.

## 13. Open questions

- Sudden death vs. capital elimination as the default (leaning capital).
- Whether the season winner keeping a territory across seasons snowballs too hard; may need a cap.
- Money: is the contract system worth the complexity, or is aging alone enough to break up super-teams?
- Whether AI empires should raid each other with the same rules (yes by default; makes the league evolve without the player).
- Number of empires (12) vs. session length target (30–60 min per season).