extends RefCounted

const Rosters = preload("res://scripts/core/rosters.gd")

# The post-battle swap. The winner takes any unprotected player from the
# loser and sends back one of the same slot type. Protected: the loser's
# franchise tag and any rookie in his draft season. Both movers arrive with
# a morale hit for the rest of the season and grow slower for good.

const MORALE_PENALTY: int = 5
const RAIDED_LOYALTY: float = 0.75

static func can_take(team: Dictionary, index: int, tag_index: int, season_number: int) -> bool:
    if index == tag_index:
        return false
    var player: Dictionary = team["players"][index]
    return int(player.get("rookie_season", -1)) != season_number

static func protection_label(team: Dictionary, index: int, tag_index: int, season_number: int) -> String:
    if index == tag_index:
        return "TAGGED"
    var player: Dictionary = team["players"][index]
    if int(player.get("rookie_season", -1)) == season_number:
        return "ROOKIE"
    return ""

static func same_slot(index_a: int, index_b: int) -> bool:
    return Rosters.SLOT_TYPES[index_a] == Rosters.SLOT_TYPES[index_b]

static func ai_take(loser: Dictionary, tag_index: int, season_number: int) -> int:
    var players: Array = loser["players"]
    var best: int = -1
    var best_overall: int = -1
    for i in range(players.size()):
        if not can_take(loser, i, tag_index, season_number):
            continue
        var overall: int = Rosters.player_overall(players[i])
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
        var overall: int = Rosters.player_overall(players[i])
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
    if int(player.get("morale", 0)) == 0:
        for key in Rosters.STAT_KEYS:
            player[key] = clampi(int(player[key]) - MORALE_PENALTY, 1, 99)
        player["morale"] = -MORALE_PENALTY
    player["origin"] = "raided"
    player["loyalty"] = RAIDED_LOYALTY

# Morale hits end at the offseason.
static func restore_morale(player: Dictionary) -> void:
    var morale: int = int(player.get("morale", 0))
    if morale == 0:
        return
    for key in Rosters.STAT_KEYS:
        player[key] = clampi(int(player[key]) - morale, 1, 99)
    player.erase("morale")
