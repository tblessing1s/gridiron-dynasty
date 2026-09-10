extends RefCounted

const Rosters = preload("res://scripts/core/rosters.gd")

# The post-battle swap. The winner takes any unprotected player from the
# loser and sends back one of the same slot type. Both movers arrive with a
# morale hit for the rest of the season.

const MORALE_PENALTY: int = 5

static func can_take(index: int, tag_index: int) -> bool:
    return index != tag_index

static func same_slot(index_a: int, index_b: int) -> bool:
    return Rosters.SLOT_TYPES[index_a] == Rosters.SLOT_TYPES[index_b]

static func ai_take(loser: Dictionary, tag_index: int) -> int:
    var players: Array = loser["players"]
    var best: int = -1
    var best_overall: int = -1
    for i in range(players.size()):
        if not can_take(i, tag_index):
            continue
        var overall: int = _overall(players[i])
        if overall > best_overall:
            best_overall = overall
            best = i
    return best

static func ai_send_back(winner: Dictionary, take_index: int) -> int:
    var players: Array = winner["players"]
    var worst: int = -1
    var worst_overall: int = 1000
    for i in range(players.size()):
        if not same_slot(i, take_index):
            continue
        var overall: int = _overall(players[i])
        if overall < worst_overall:
            worst_overall = overall
            worst = i
    return worst

static func apply(winner: Dictionary, loser: Dictionary, take_index: int, give_index: int) -> void:
    var winner_players: Array = winner["players"]
    var loser_players: Array = loser["players"]
    var taken: Dictionary = loser_players[take_index]
    var given: Dictionary = winner_players[give_index]
    _demoralize(taken)
    _demoralize(given)
    winner_players[give_index] = taken
    loser_players[take_index] = given

static func _demoralize(player: Dictionary) -> void:
    for key in ["speed", "power", "skill", "awareness"]:
        player[key] = clampi(int(player[key]) - MORALE_PENALTY, 1, 99)
    player["morale"] = -MORALE_PENALTY

static func _overall(player: Dictionary) -> int:
    var total: int = 0
    for key in ["speed", "power", "skill", "awareness"]:
        total += int(player[key])
    return int(round(float(total) / 4.0))
