extends RefCounted

const Rosters = preload("res://scripts/core/rosters.gd")
const BattleSim = preload("res://scripts/core/battle_sim.gd")
const RaidRules = preload("res://scripts/core/raid_rules.gd")
const SaveGame = preload("res://scripts/core/save_game.gd")

# One season of Border War: twelve empires on a 6x4 grid of territories,
# two each to start. Each week every empire may attack one adjacent enemy
# territory. Win and you take it (or the loser's whole empire if it was
# their capital); lose an attack and the defender takes the territory you
# attacked from, unless that was your capital, which only ever falls to a
# direct attack. Last empire standing wins, or the largest at the week cap.

const MAX_WEEKS: int = 12
const EMPIRE_COUNT: int = 12
const COLUMNS: int = 6
const ROWS: int = 4
const USER_EMPIRE: int = 0
const AI_REST_CHANCE: float = 0.25

# Territory resource effects (design doc section 4.1). Academy and Capital
# territories each pay training points weekly; Mines pay money. Stadium and
# Capital territories grant the defender a home-crowd edge in the battle
# fought there; Highlands double how fast fatigue bars fill in that battle.
const TRAINING_POINTS_PER_ACADEMY: int = 1
const TRAINING_POINTS_PER_CAPITAL: int = 1
const MONEY_PER_MINE: int = 4
const HIGHLANDS_FATIGUE_MULTIPLIER: float = 2.0

const EMPIRE_NAMES: Array = [
    ["HARBOR HAWKS", "HAWKS", "2f77c7"],
    ["IRONVALE FORGE", "FORGE", "c2622a"],
    ["ASHFORD WOLVES", "WOLVES", "3a9d5d"],
    ["BRIGHTWATER TIDE", "TIDE", "8e44ad"],
    ["COALRIDGE MINERS", "MINERS", "d4a017"],
    ["DUSKMOOR RAVENS", "RAVENS", "c0392b"],
    ["EMBERFALL STAGS", "STAGS", "16a085"],
    ["FROSTGATE BEARS", "BEARS", "e67e22"],
    ["GLASSMERE HERONS", "HERONS", "7f8c8d"],
    ["HIGHSPIRE KNIGHTS", "KNIGHTS", "2c3e50"],
    ["KETTLE BAY OTTERS", "OTTERS", "b5651d"],
    ["MARROW HILLS BOARS", "BOARS", "d63384"],
]

const CAPITAL_NAMES: Array[String] = ["Harbor Point", "Ironvale", "Ashford", "Brightwater", "Coalridge", "Duskmoor", "Emberfall", "Frostgate", "Glassmere", "Highspire", "Kettle Bay", "Marrow Hills"]
const OUTER_NAMES: Array[String] = ["Gull Rock", "Slag Fields", "Thornwood", "Reedmarsh", "Black Seam", "Fog Hollow", "Cinder Flats", "Icewall", "Mirror Lake", "Steeple Down", "Oyster Shoals", "Boar Run"]
const RESOURCES: Array[String] = ["Academy", "Stadium", "Mines", "Highlands"]

var empires: Array = []
var territories: Array = []
var week: int = 1
var elimination_order: Array[int] = []
var log: Array[String] = []
var planned_battles: Array = []
var user_battle: Dictionary = {}
var over: bool = false
var winner_id: int = -1
var number: int = 1
var previous_champion: int = -1
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
    rng.randomize()
    _build_empires([])
    _build_territories()

# A new season on a fresh map, keeping every empire's roster from the
# season before. Eliminated empires come back; tags reset.
func reset_for_new_season(previous_empires: Array, next_number: int, champion: int) -> void:
    number = next_number
    previous_champion = champion
    week = 1
    over = false
    winner_id = -1
    elimination_order.clear()
    log.clear()
    planned_battles.clear()
    user_battle = {}
    var rosters: Array = []
    for e in previous_empires:
        rosters.append(e["players"])
    _build_empires(rosters)
    _build_territories()

func _build_empires(existing_rosters: Array) -> void:
    empires.clear()
    for i in range(EMPIRE_COUNT):
        var entry: Array = EMPIRE_NAMES[i]
        var players: Array
        if i < existing_rosters.size():
            players = existing_rosters[i]
        elif i == 0:
            players = Rosters.hawks()["players"]
        elif i == 1:
            players = Rosters.forge()["players"]
        else:
            players = Rosters.generate_players(rng.randi_range(54, 72), rng)
        for player in players:
            Rosters.ensure_career(player, rng)
        empires.append({
            "id": i,
            "name": entry[0],
            "short": entry[1],
            "color": Color(entry[2]),
            "players": players,
            "capital_id": -1,
            "eliminated": false,
            "tag_index": -1,
            "is_user": i == USER_EMPIRE,
            "training_points": 0,
            "money": 0,
        })

func _build_territories() -> void:
    territories.clear()
    for row in range(ROWS):
        for column in range(COLUMNS):
            var id: int = row * COLUMNS + column
            var owner: int = row * (COLUMNS / 2) + column / 2
            # Alternate which side of each pair holds the capital so capitals
            # never sit directly above or below an enemy capital.
            var is_capital: bool = (column % 2 == 0) == (row % 2 == 0)
            var territory_name: String = CAPITAL_NAMES[owner] if is_capital else OUTER_NAMES[owner]
            var adjacency: Array[int] = []
            if column > 0:
                adjacency.append(id - 1)
            if column < COLUMNS - 1:
                adjacency.append(id + 1)
            if row > 0:
                adjacency.append(id - COLUMNS)
            if row < ROWS - 1:
                adjacency.append(id + COLUMNS)
            territories.append({
                "id": id,
                "name": territory_name,
                "column": column,
                "row": row,
                "owner_id": owner,
                "is_capital": is_capital,
                "resource": "Capital" if is_capital else RESOURCES[(owner + row) % RESOURCES.size()],
                "adjacency": adjacency,
            })
            if is_capital:
                empires[owner]["capital_id"] = id

# ---------------------------------------------------------------- persistence

func to_dict() -> Dictionary:
    var empire_data: Array = []
    for e in empires:
        var copy: Dictionary = e.duplicate(true)
        copy["color"] = (e["color"] as Color).to_html(false)
        empire_data.append(copy)
    return {
        "number": number,
        "week": week,
        "over": over,
        "winner_id": winner_id,
        "previous_champion": previous_champion,
        "elimination_order": Array(elimination_order),
        "log": Array(log),
        "planned_battles": planned_battles.duplicate(true),
        "user_battle": user_battle.duplicate(true),
        "empires": empire_data,
        "territories": territories.duplicate(true),
    }

func restore(data: Dictionary) -> void:
    number = int(data.get("number", 1))
    week = int(data.get("week", 1))
    over = bool(data.get("over", false))
    winner_id = int(data.get("winner_id", -1))
    previous_champion = int(data.get("previous_champion", -1))
    elimination_order = SaveGame.int_array(data.get("elimination_order", []))
    log.clear()
    for line in data.get("log", []):
        log.append(str(line))
    planned_battles.clear()
    for battle in data.get("planned_battles", []):
        planned_battles.append(SaveGame.int_dict(battle))
    user_battle = SaveGame.int_dict(data.get("user_battle", {}))

    empires.clear()
    for e in data.get("empires", []):
        var copy: Dictionary = e
        copy["id"] = int(copy["id"])
        copy["capital_id"] = int(copy["capital_id"])
        copy["tag_index"] = int(copy.get("tag_index", -1))
        copy["eliminated"] = bool(copy.get("eliminated", false))
        copy["is_user"] = bool(copy.get("is_user", false))
        copy["training_points"] = int(copy.get("training_points", 0))
        copy["money"] = int(copy.get("money", 0))
        copy["color"] = Color(str(copy["color"]))
        copy["players"] = SaveGame.normalize_players(copy.get("players", []))
        empires.append(copy)

    territories.clear()
    for t in data.get("territories", []):
        var copy: Dictionary = t
        for key in ["id", "column", "row", "owner_id"]:
            copy[key] = int(copy[key])
        copy["is_capital"] = bool(copy.get("is_capital", false))
        copy["adjacency"] = SaveGame.int_array(copy.get("adjacency", []))
        territories.append(copy)

# ---------------------------------------------------------------- queries

func empire(id: int) -> Dictionary:
    return empires[id]

func territory(id: int) -> Dictionary:
    return territories[id]

func user() -> Dictionary:
    return empires[USER_EMPIRE]

func user_eliminated() -> bool:
    return bool(empires[USER_EMPIRE]["eliminated"])

func owned_by(empire_id: int) -> Array[int]:
    var owned: Array[int] = []
    for t in territories:
        if int(t["owner_id"]) == empire_id:
            owned.append(int(t["id"]))
    return owned

func adjacent_enemy_territories(empire_id: int) -> Array[int]:
    var targets: Array[int] = []
    for t_id in owned_by(empire_id):
        for adjacent_id in territories[t_id]["adjacency"]:
            if int(territories[adjacent_id]["owner_id"]) != empire_id and not targets.has(adjacent_id):
                targets.append(adjacent_id)
    return targets

func can_attack(empire_id: int, territory_id: int) -> bool:
    return adjacent_enemy_territories(empire_id).has(territory_id)

func resource_count(empire_id: int, resource: String) -> int:
    var count: int = 0
    for t in territories:
        if int(t["owner_id"]) == empire_id and str(t["resource"]) == resource:
            count += 1
    return count

# Stadium and Capital territories give the defender a home crowd: the
# attacker's throws scatter wider in the battle fought there.
func home_crowd_at(territory_id: int) -> bool:
    var resource: String = str(territories[territory_id]["resource"])
    return resource == "Stadium" or resource == "Capital"

# Highlands territories favour fresh rosters: fatigue bars fill twice as
# fast in the battle fought there.
func fatigue_multiplier_at(territory_id: int) -> float:
    return HIGHLANDS_FATIGUE_MULTIPLIER if str(territories[territory_id]["resource"]) == "Highlands" else 1.0

# The territory an attacker fights from: a non-capital neighbour of the
# target if one exists, otherwise the capital itself.
func attack_origin(attacker_id: int, target_id: int) -> int:
    var origin: int = -1
    for adjacent_id in territories[target_id]["adjacency"]:
        if int(territories[adjacent_id]["owner_id"]) != attacker_id:
            continue
        if not bool(territories[adjacent_id]["is_capital"]):
            return adjacent_id
        origin = adjacent_id
    return origin

func alive_empires() -> Array[int]:
    var alive: Array[int] = []
    for e in empires:
        if not bool(e["eliminated"]):
            alive.append(int(e["id"]))
    return alive

func standings() -> Array:
    var rows: Array = []
    for e in empires:
        rows.append({"id": int(e["id"]), "short": e["short"], "color": e["color"], "territories": owned_by(int(e["id"])).size(), "eliminated": bool(e["eliminated"]), "overall": Rosters.team_overall(e)})
    rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        if bool(a["eliminated"]) != bool(b["eliminated"]):
            return not bool(a["eliminated"])
        if int(a["territories"]) != int(b["territories"]):
            return int(a["territories"]) > int(b["territories"])
        return int(a["overall"]) > int(b["overall"]))
    return rows

func has_user_battle() -> bool:
    return not user_battle.is_empty()

# ---------------------------------------------------------------- weekly loop

func plan_week(user_target: int) -> void:
    planned_battles.clear()
    user_battle = {}
    log.clear()
    var engaged: Dictionary = {}

    if not user_eliminated() and user_target >= 0 and can_attack(USER_EMPIRE, user_target):
        var defender: int = int(territories[user_target]["owner_id"])
        user_battle = _battle(USER_EMPIRE, defender, user_target)
        engaged[USER_EMPIRE] = true
        engaged[defender] = true

    for e in empires:
        var attacker: int = int(e["id"])
        if attacker == USER_EMPIRE or bool(e["eliminated"]) or engaged.has(attacker):
            continue
        if rng.randf() < AI_REST_CHANCE:
            continue
        var target: int = _ai_pick_target(attacker, engaged)
        if target < 0:
            continue
        var defender: int = int(territories[target]["owner_id"])
        var battle: Dictionary = _battle(attacker, defender, target)
        engaged[attacker] = true
        engaged[defender] = true
        if defender == USER_EMPIRE:
            user_battle = battle
        else:
            planned_battles.append(battle)

func complete_user_battle(user_won: bool) -> void:
    if user_battle.is_empty():
        return
    var attacker: int = int(user_battle["attacker"])
    var defender: int = int(user_battle["defender"])
    var user_is_attacker: bool = attacker == USER_EMPIRE
    var winner: int = USER_EMPIRE if user_won else (defender if user_is_attacker else attacker)
    _apply_result(user_battle, winner, "")
    user_battle = {}
    _resolve_ai_battles()
    _advance_week()

func resolve_week_without_user() -> void:
    user_battle = {}
    _resolve_ai_battles()
    _advance_week()

func _battle(attacker: int, defender: int, target: int) -> Dictionary:
    return {"attacker": attacker, "defender": defender, "territory": target, "origin": attack_origin(attacker, target)}

func _ai_pick_target(attacker: int, engaged: Dictionary) -> int:
    var targets: Array[int] = adjacent_enemy_territories(attacker)
    var my_overall: int = Rosters.team_overall(empires[attacker])
    var candidates: Array[int] = []
    var weights: Array[int] = []
    for target in targets:
        var owner: int = int(territories[target]["owner_id"])
        if engaged.has(owner):
            continue
        var weight: int = 100 + (my_overall - Rosters.team_overall(empires[owner])) * 3
        if bool(territories[target]["is_capital"]):
            weight += 30
        candidates.append(target)
        weights.append(maxi(weight, 10))
    if candidates.is_empty():
        return -1
    var total: int = 0
    for w in weights:
        total += w
    var roll: int = rng.randi_range(1, total)
    var accumulated: int = 0
    for i in range(candidates.size()):
        accumulated += weights[i]
        if roll <= accumulated:
            return candidates[i]
    return candidates[candidates.size() - 1]

func _resolve_ai_battles() -> void:
    for battle in planned_battles:
        var attacker: int = int(battle["attacker"])
        var target: int = int(battle["territory"])
        var defender: int = int(territories[target]["owner_id"])
        if bool(empires[attacker]["eliminated"]) or defender == attacker or bool(empires[defender]["eliminated"]):
            continue
        battle["defender"] = defender
        battle["origin"] = attack_origin(attacker, target)
        if int(battle["origin"]) < 0:
            continue
        var result: Dictionary = BattleSim.resolve(empires[attacker], empires[defender], rng, home_crowd_at(target))
        var attacker_won: bool = int(result["home_score"]) > int(result["away_score"])
        var winner: int = attacker if attacker_won else defender
        _apply_result(battle, winner, "%d–%d" % [result["home_score"], result["away_score"]])
        _ai_raid(winner, attacker if winner == defender else defender)
    planned_battles.clear()

func _apply_result(battle: Dictionary, winner: int, score_text: String) -> void:
    var attacker: int = int(battle["attacker"])
    var defender: int = int(battle["defender"])
    var target: int = int(battle["territory"])
    var origin: int = int(battle["origin"])
    var score: String = " (%s)" % score_text if not score_text.is_empty() else ""
    if winner == attacker:
        log.append("%s took %s from %s%s" % [empires[attacker]["short"], territories[target]["name"], empires[defender]["short"], score])
        _capture(target, attacker)
    else:
        if origin >= 0 and not bool(territories[origin]["is_capital"]):
            log.append("%s held %s and took %s from %s%s" % [empires[defender]["short"], territories[target]["name"], territories[origin]["name"], empires[attacker]["short"], score])
            _capture(origin, defender)
        else:
            log.append("%s held %s against %s%s" % [empires[defender]["short"], territories[target]["name"], empires[attacker]["short"], score])

func _capture(territory_id: int, new_owner: int) -> void:
    var old_owner: int = int(territories[territory_id]["owner_id"])
    if old_owner == new_owner:
        return
    territories[territory_id]["owner_id"] = new_owner
    if territory_id == int(empires[old_owner]["capital_id"]):
        _eliminate(old_owner, new_owner)

func _eliminate(loser: int, winner: int) -> void:
    empires[loser]["eliminated"] = true
    elimination_order.append(loser)
    var absorbed: int = 0
    for t in territories:
        if int(t["owner_id"]) == loser:
            t["owner_id"] = winner
            absorbed += 1
    log.append("%s ELIMINATED — %s absorb %d more territor%s" % [empires[loser]["short"], empires[winner]["short"], absorbed, "y" if absorbed == 1 else "ies"])

func _ai_raid(winner: int, loser: int) -> void:
    var winner_team: Dictionary = empires[winner]
    var loser_team: Dictionary = empires[loser]
    var loser_tag: int = int(loser_team["tag_index"])
    if loser_tag < 0:
        loser_tag = Rosters.best_player_index(loser_team)
    var take: int = RaidRules.ai_take(loser_team, loser_tag, number)
    if take < 0:
        return
    var give: int = RaidRules.ai_send_back(winner_team, take)
    if give < 0:
        return
    var taken_name: String = str(loser_team["players"][take]["name"])
    RaidRules.apply(winner_team, loser_team, take, give)
    log.append("%s raided %s from %s" % [winner_team["short"], taken_name, loser_team["short"]])

func _pay_resources() -> void:
    for id in alive_empires():
        var e: Dictionary = empires[id]
        var academies: int = resource_count(id, "Academy")
        var capitals: int = resource_count(id, "Capital")
        var mines: int = resource_count(id, "Mines")
        e["training_points"] = int(e["training_points"]) + academies * TRAINING_POINTS_PER_ACADEMY + capitals * TRAINING_POINTS_PER_CAPITAL
        e["money"] = int(e["money"]) + mines * MONEY_PER_MINE

func _advance_week() -> void:
    _pay_resources()
    week += 1
    var alive: Array[int] = alive_empires()
    if alive.size() <= 1 or week > MAX_WEEKS:
        over = true
        var table: Array = standings()
        winner_id = int(table[0]["id"])
        log.append("SEASON OVER — %s win the map" % empires[winner_id]["short"])
