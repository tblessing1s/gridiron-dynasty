extends RefCounted

const Rosters = preload("res://scripts/core/rosters.gd")
const RaidRules = preload("res://scripts/core/raid_rules.gd")
const SeasonScript = preload("res://scripts/core/season.gd")
const SaveGame = preload("res://scripts/core/save_game.gd")

# The offseason, in order: morale clears, everyone ages (growth toward
# potential, decline past thirty, retirement rolls), then a one-round
# draft in reverse elimination order where each pick displaces a player
# at the same slot, then a fresh map with the same rosters.

const CLASS_SIZE: int = 18
const RETIREMENT_AGE: int = 32

var previous
var next_number: int = 2
var order: Array[int] = []
var draft_class: Array = []
var picks: Array = []
var aging: Dictionary = {}
var league_retirements: int = 0
var pick_cursor: int = 0
var rng: RandomNumberGenerator

# fresh=false builds an empty shell for restore().
func _init(season, fresh: bool = true) -> void:
    previous = season
    rng = season.rng
    next_number = int(season.number) + 1
    if fresh:
        _run_aging()
        _build_order()
        _build_class()

# ---------------------------------------------------------------- persistence

func to_dict() -> Dictionary:
    var aging_data: Dictionary = {}
    for key in aging.keys():
        aging_data[str(key)] = aging[key]
    return {
        "next_number": next_number,
        "order": Array(order),
        "draft_class": draft_class.duplicate(true),
        "picks": picks.duplicate(true),
        "aging": aging_data,
        "league_retirements": league_retirements,
        "pick_cursor": pick_cursor,
    }

func restore(data: Dictionary) -> void:
    next_number = int(data.get("next_number", next_number))
    order = SaveGame.int_array(data.get("order", []))
    draft_class = SaveGame.normalize_players(data.get("draft_class", []))
    picks.clear()
    for pick in data.get("picks", []):
        var copy: Dictionary = pick
        copy["pick"] = int(copy["pick"])
        copy["empire_id"] = int(copy["empire_id"])
        copy["rookie"] = SaveGame.normalize_player(copy["rookie"])
        picks.append(copy)
    aging.clear()
    var aging_data: Dictionary = data.get("aging", {})
    for key in aging_data.keys():
        var reports: Array = []
        for report in aging_data[key]:
            var copy: Dictionary = report
            copy["age"] = int(copy.get("age", 0))
            copy["retired"] = bool(copy.get("retired", false))
            copy["changes"] = SaveGame.int_dict(copy.get("changes", {}))
            reports.append(copy)
        aging[int(key)] = reports
    league_retirements = int(data.get("league_retirements", 0))
    pick_cursor = int(data.get("pick_cursor", 0))

# ---------------------------------------------------------------- aging

func _run_aging() -> void:
    for e in previous.empires:
        var reports: Array = []
        var players: Array = e["players"]
        for i in range(players.size()):
            var player: Dictionary = players[i]
            Rosters.ensure_career(player, rng)
            RaidRules.restore_morale(player)
            var report: Dictionary = _age_player(player)
            if bool(report["retired"]):
                league_retirements += 1
                var replacement: Dictionary = Rosters.generate_journeyman(Rosters.SLOT_TYPES[i], rng)
                players[i] = replacement
                report["replacement"] = replacement["name"]
            reports.append(report)
        aging[int(e["id"])] = reports

func _age_player(player: Dictionary) -> Dictionary:
    var age: int = int(player["age"]) + 1
    player["age"] = age
    var changes: Dictionary = {}
    var potential: Dictionary = player["potential"]
    for key in Rosters.STAT_KEYS:
        var value: int = int(player[key])
        var delta: int = 0
        if age <= 23:
            delta = rng.randi_range(2, 5)
        elif age <= 28:
            delta = rng.randi_range(0, 2)
        elif age <= 31:
            delta = -rng.randi_range(2, 4) if key == "speed" else -rng.randi_range(0, 2)
        else:
            delta = -rng.randi_range(4, 6) if key == "speed" else -rng.randi_range(2, 4)
        var new_value: int = value + delta
        if delta > 0:
            new_value = mini(new_value, maxi(int(potential[key]), value))
        new_value = clampi(new_value, 1, 99)
        if new_value != value:
            changes[key] = new_value - value
            player[key] = new_value
    var retired: bool = false
    if age >= RETIREMENT_AGE:
        var chance: float = 0.25 + float(age - RETIREMENT_AGE) * 0.2
        retired = rng.randf() < chance
    return {"name": player["name"], "age": age, "changes": changes, "retired": retired, "replacement": ""}

# ---------------------------------------------------------------- draft

func _build_order() -> void:
    order.clear()
    for id in previous.elimination_order:
        order.append(int(id))
    var survivors: Array = []
    for row in previous.standings():
        if not bool(row["eliminated"]):
            survivors.append(row)
    survivors.reverse()
    for row in survivors:
        order.append(int(row["id"]))

func _build_class() -> void:
    draft_class.clear()
    for i in range(CLASS_SIZE):
        var low: int = int(round(lerpf(84.0, 58.0, float(i) / float(CLASS_SIZE - 1))))
        var slot_type: String = _random_slot_type()
        draft_class.append(Rosters.generate_rookie(slot_type, low, low + 10, rng))

func _random_slot_type() -> String:
    var total: int = 0
    for weight in Rosters.ROOKIE_SLOT_WEIGHTS:
        total += weight
    var roll: int = rng.randi_range(1, total)
    var accumulated: int = 0
    for i in range(Rosters.ROOKIE_SLOT_TYPES.size()):
        accumulated += Rosters.ROOKIE_SLOT_WEIGHTS[i]
        if roll <= accumulated:
            return Rosters.ROOKIE_SLOT_TYPES[i]
    return "BL"

func draft_done() -> bool:
    return pick_cursor >= order.size()

func current_pick_empire() -> int:
    if draft_done():
        return -1
    return order[pick_cursor]

func is_user_pick() -> bool:
    return current_pick_empire() == previous.USER_EMPIRE

func run_ai_picks_until_user() -> void:
    while not draft_done() and not is_user_pick():
        _ai_pick()

func run_remaining_ai_picks() -> void:
    while not draft_done():
        if is_user_pick():
            _ai_pick()
        else:
            _ai_pick()

func eligible_cuts(empire_id: int, rookie: Dictionary) -> Array[int]:
    var cuts: Array[int] = []
    var slot_type: String = str(rookie["slot_type"])
    for i in range(Rosters.SLOT_TYPES.size()):
        if Rosters.SLOT_TYPES[i] == slot_type:
            cuts.append(i)
    return cuts

func user_pick(rookie_index: int, cut_index: int) -> void:
    if not is_user_pick():
        return
    _apply_pick(previous.USER_EMPIRE, rookie_index, cut_index)

func _ai_pick() -> void:
    var empire_id: int = current_pick_empire()
    var team: Dictionary = previous.empire(empire_id)
    var best_index: int = 0
    var best_score: float = -INF
    for i in range(draft_class.size()):
        var rookie: Dictionary = draft_class[i]
        var cuts: Array[int] = eligible_cuts(empire_id, rookie)
        var worst_current: int = 100
        for cut in cuts:
            worst_current = mini(worst_current, Rosters.player_overall(team["players"][cut]))
        var score: float = float(Rosters.potential_average(rookie)) * 0.6 + float(Rosters.player_overall(rookie)) * 0.4 - float(worst_current) * 0.3
        if score > best_score:
            best_score = score
            best_index = i
    var chosen: Dictionary = draft_class[best_index]
    var cut_index: int = -1
    var cut_overall: int = 1000
    for cut in eligible_cuts(empire_id, chosen):
        var overall: int = Rosters.player_overall(team["players"][cut])
        if overall < cut_overall:
            cut_overall = overall
            cut_index = cut
    _apply_pick(empire_id, best_index, cut_index)

func _apply_pick(empire_id: int, rookie_index: int, cut_index: int) -> void:
    var team: Dictionary = previous.empire(empire_id)
    var rookie: Dictionary = draft_class.pop_at(rookie_index)
    rookie["rookie_season"] = next_number
    var cut: Dictionary = team["players"][cut_index]
    team["players"][cut_index] = rookie
    picks.append({"pick": picks.size() + 1, "empire_id": empire_id, "rookie": rookie, "cut_name": cut["name"], "slot": Rosters.SLOT_TYPES[cut_index]})
    pick_cursor += 1

# ---------------------------------------------------------------- next season

func build_next_season():
    var season = SeasonScript.new()
    season.reset_for_new_season(previous.empires, next_number, previous.winner_id)
    return season
