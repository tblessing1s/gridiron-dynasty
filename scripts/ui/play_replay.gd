extends Node2D

const GameConstants = preload("res://scripts/core/game_constants.gd")
const BattleSettings = preload("res://scripts/core/battle_settings.gd")
const PlayBook = preload("res://scripts/core/play_book.gd")
const Rosters = preload("res://scripts/core/rosters.gd")
const PlayerBodyScript = preload("res://scripts/football/player_body.gd")
const BallMarkerScript = preload("res://scripts/ui/ball_marker.gd")

# A scripted replay of a SIM down: the stat math in BattleSim._resolve_play
# has already decided everything (yards, who touched the ball, who made the
# stop), and this just tweens the same labelled-dot markers the real-time
# field would use through a canned sequence that matches that result. There
# is no physics here and nothing that can disagree with the numbers — see
# DESIGN.md §5.9.

signal finished

const CENTER_Y: float = (GameConstants.FIELD_TOP + GameConstants.FIELD_BOTTOM) * 0.5

var offense_markers: Array = []
var defense_markers: Array = []
var ball_marker
var home_team: Dictionary = {}
var away_team: Dictionary = {}
var _tween: Tween

func _ready() -> void:
    z_index = 20
    for i in range(7):
        var offense_marker = PlayerBodyScript.new()
        add_child(offense_marker)
        offense_markers.append(offense_marker)
        var defense_marker = PlayerBodyScript.new()
        add_child(defense_marker)
        defense_markers.append(defense_marker)
    ball_marker = BallMarkerScript.new()
    ball_marker.visible = false
    add_child(ball_marker)
    visible = false

func setup(_field_view: Node2D, home: Dictionary, away: Dictionary) -> void:
    home_team = home
    away_team = away

# Plays back one resolved down. `result` is the dictionary BattleSim
# returned (yards/result/turnover/detail plus the structural fields added
# for this replay); `offense_is_home` is true when teams[0] (home) is the
# side on offense this down.
func play(result: Dictionary, line_of_scrimmage_yard: int, offense_is_home: bool) -> void:
    var offense_team: Dictionary = home_team if offense_is_home else away_team
    var defense_team: Dictionary = away_team if offense_is_home else home_team
    _color_markers(offense_team, defense_team)
    visible = true
    ball_marker.visible = false
    ball_marker.scale = Vector2.ONE

    var los_x: float = GameConstants.LEFT_GOAL_X + float(line_of_scrimmage_yard) * GameConstants.PIXELS_PER_YARD
    var offense_card: int = int(result.get("offense_card", PlayBook.Offense.SLANTS))
    var defense_card: int = int(result.get("defense_card", PlayBook.Defense.COVER))
    var offense_positions: Array = _offense_formation(offense_card, los_x)
    var defense_positions: Array = _defense_formation(defense_card, los_x)

    var result_kind: String = str(result.get("result", ""))
    var yards: int = int(result.get("yards", 0))
    var turnover: bool = bool(result.get("turnover", false))
    var touchdown: bool = not turnover and result_kind != "INTERCEPTED" and los_x + float(yards) * GameConstants.PIXELS_PER_YARD >= GameConstants.RIGHT_GOAL_X

    _tween = create_tween()
    _tween.set_speed_scale(maxf(BattleSettings.replay_speed, 0.1))
    _snap_in(offense_positions, defense_positions)

    match result_kind:
        "SACK":
            _sequence_sack(result, los_x)
        "INTERCEPTED":
            _sequence_interception(result, los_x)
        "PASS":
            _sequence_pass_complete(result, los_x, offense_card, touchdown)
        "INCOMPLETE":
            _sequence_pass_incomplete(result, los_x, offense_card)
        "RUN":
            _sequence_run(result, los_x, offense_card, touchdown)
        _:
            pass

    await _tween.finished
    visible = false
    finished.emit()

# Jumps the active tween straight to its end state; safe to call with no
# replay running.
func skip() -> void:
    if _tween != null and _tween.is_valid():
        _tween.custom_step(999.0)

func set_speed(multiplier: float) -> void:
    BattleSettings.replay_speed = maxf(multiplier, 0.1)
    if _tween != null and _tween.is_valid():
        _tween.set_speed_scale(BattleSettings.replay_speed)

func _unhandled_input(event: InputEvent) -> void:
    if _tween == null or not _tween.is_valid():
        return
    if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed) or (event is InputEventKey and event.pressed):
        skip()

# ---------------------------------------------------------------- setup helpers

func _color_markers(offense_team: Dictionary, defense_team: Dictionary) -> void:
    var offense_players: Array = offense_team.get("players", [])
    var defense_players: Array = defense_team.get("players", [])
    var offense_color: Color = offense_team.get("color", Color.WHITE)
    var defense_color: Color = defense_team.get("color", Color.WHITE)
    for i in range(7):
        offense_markers[i].set_team_color(offense_color)
        offense_markers[i].label_text = Rosters.SLOT_TYPES[i]
        if i < offense_players.size():
            offense_markers[i].apply_stats(offense_players[i])
        defense_markers[i].set_team_color(defense_color)
        defense_markers[i].label_text = Rosters.DEFENSE_SLOT_TYPES[i]
        if i < defense_players.size():
            defense_markers[i].apply_stats(defense_players[i])

func _line_offset_y(index: int) -> float:
    return (float(index) - float(Rosters.LINE_SIZE - 1) * 0.5) * 46.0

# Pre-snap look for each offense card: QB, RB, two WRs, three blockers.
func _offense_formation(card: int, los: float) -> Array:
    var rb_pos: Vector2 = Vector2(los - 100.0, CENTER_Y + 40.0)
    var wr1_y: float = 245.0
    var wr2_y: float = 540.0
    match card:
        PlayBook.Offense.DRAW, PlayBook.Offense.SWEEP:
            rb_pos = Vector2(los - 80.0, CENTER_Y + 15.0)
        PlayBook.Offense.SCREEN:
            rb_pos = Vector2(los - 40.0, CENTER_Y + 130.0)
        PlayBook.Offense.DEEP_SHOT, PlayBook.Offense.PLAY_ACTION:
            wr1_y = 200.0
            wr2_y = 580.0
        PlayBook.Offense.SLANTS:
            wr1_y = 300.0
            wr2_y = 480.0
    var positions: Array = [Vector2(los - 55.0, CENTER_Y), rb_pos, Vector2(los - 4.0, wr1_y), Vector2(los - 4.0, wr2_y)]
    for i in range(Rosters.LINE_SIZE):
        positions.append(Vector2(los - 22.0, CENTER_Y + _line_offset_y(i)))
    return positions

# Pre-snap look for each defense card: Safety, LB, two CBs, three rushers.
func _defense_formation(card: int, los: float) -> Array:
    var lb_pos: Vector2 = Vector2(los + 95.0, CENTER_Y)
    var cb1_pos: Vector2 = Vector2(los + 55.0, 245.0)
    var cb2_pos: Vector2 = Vector2(los + 55.0, 540.0)
    var rush_x: float = los + 22.0
    match card:
        PlayBook.Defense.PRESS:
            cb1_pos = Vector2(los + 12.0, 245.0)
            cb2_pos = Vector2(los + 12.0, 540.0)
        PlayBook.Defense.SPY:
            lb_pos = Vector2(los + 60.0, CENTER_Y + 30.0)
        PlayBook.Defense.BLITZ:
            rush_x = los + 10.0
    var positions: Array = [Vector2(los + 170.0, CENTER_Y), lb_pos, cb1_pos, cb2_pos]
    for i in range(Rosters.LINE_SIZE):
        positions.append(Vector2(rush_x, CENTER_Y + _line_offset_y(i)))
    return positions

# ---------------------------------------------------------------- sequences

func _snap_in(offense_positions: Array, defense_positions: Array) -> void:
    for i in range(7):
        offense_markers[i].position = offense_positions[i]
        offense_markers[i].scale = Vector2(0.55, 0.55)
        defense_markers[i].position = defense_positions[i]
        defense_markers[i].scale = Vector2(0.55, 0.55)
    _tween.set_parallel(true)
    for i in range(7):
        _tween.tween_property(offense_markers[i], "scale", Vector2.ONE, 0.4)
        _tween.tween_property(defense_markers[i], "scale", Vector2.ONE, 0.4)
    _tween.set_parallel(false)
    _tween.tween_interval(0.05)

# The ball's flight is bowed sideways (screen "up") by `height` px, the same
# trick football_game._update_projected_arc uses for the aim-line preview —
# there is no third dimension on this field, so a lateral bow reads as arc.
func _arc_move(node: Node2D, from_pos: Vector2, to_pos: Vector2, duration: float, height: float) -> void:
    _tween.tween_method(func(t: float): node.position = from_pos.lerp(to_pos, t) - Vector2(0.0, sin(t * PI) * height), 0.0, 1.0, duration)

func _sequence_sack(result: Dictionary, los_x: float) -> void:
    var qb = offense_markers[0]
    var tackler_index: int = clampi(int(result.get("tackler", 4)), 4, 6)
    var rusher = defense_markers[tackler_index]
    var pocket: float = float(result.get("pocket_seconds", 1.0))
    var yards: int = int(result.get("yards", -5))
    var sack_pos: Vector2 = Vector2(los_x + float(yards) * GameConstants.PIXELS_PER_YARD, qb.position.y)
    _tween.set_parallel(true)
    _tween.tween_property(qb, "position", sack_pos, pocket)
    _tween.tween_property(rusher, "position", sack_pos + Vector2(8.0, 0.0), pocket)
    _tween.set_parallel(false)
    _tween.tween_interval(0.2)

func _sequence_interception(result: Dictionary, los_x: float) -> void:
    var target_index: int = clampi(int(result.get("target", 2)), 2, 3)
    var target = offense_markers[target_index]
    var interceptor_index: int = clampi(int(result.get("interceptor", 0)), 0, 3)
    var interceptor = defense_markers[interceptor_index]
    var qb = offense_markers[0]
    var air_yards: int = int(result.get("air_yards", 10))
    var catch_pos: Vector2 = Vector2(los_x + float(air_yards) * GameConstants.PIXELS_PER_YARD, target.position.y)

    ball_marker.visible = true
    ball_marker.position = qb.position
    _tween.set_parallel(true)
    _tween.tween_property(target, "position", catch_pos + Vector2(6.0, 0.0), 0.9)
    _tween.tween_property(interceptor, "position", catch_pos, 0.9)
    _arc_move(ball_marker, ball_marker.position, catch_pos, 0.9, 35.0)
    _tween.set_parallel(false)

    var return_pos: Vector2 = catch_pos - Vector2(3.0 * GameConstants.PIXELS_PER_YARD, 0.0)
    _tween.set_parallel(true)
    _tween.tween_property(interceptor, "position", return_pos, 0.5)
    _tween.tween_property(ball_marker, "position", return_pos, 0.5)
    _tween.set_parallel(false)

func _sequence_pass_complete(result: Dictionary, los_x: float, offense_card: int, touchdown: bool) -> void:
    var target_index: int = clampi(int(result.get("target", 2)), 1, 3)
    var target = offense_markers[target_index]
    var tackler_index: int = clampi(int(result.get("tackler", target_index)), 0, 3)
    var tackler = defense_markers[tackler_index]
    var qb = offense_markers[0]
    var pocket: float = float(result.get("pocket_seconds", 1.2))
    var air_yards: int = int(result.get("air_yards", 5))
    var run_after: int = int(result.get("run_after", 0))
    var route_y: float = target.position.y
    var catch_pos: Vector2 = Vector2(los_x + float(air_yards) * GameConstants.PIXELS_PER_YARD, route_y)
    var final_x: float = GameConstants.RIGHT_GOAL_X if touchdown else catch_pos.x + float(run_after) * GameConstants.PIXELS_PER_YARD

    ball_marker.visible = true
    ball_marker.position = qb.position
    _tween.tween_property(qb, "position", qb.position - Vector2(14.0, 0.0), pocket * 0.6)
    _tween.set_parallel(true)
    _tween.tween_property(target, "position", catch_pos, pocket * 0.6 + 0.2)
    var arc_height: float = 55.0 if offense_card == PlayBook.Offense.DEEP_SHOT else 22.0
    _arc_move(ball_marker, ball_marker.position, catch_pos, pocket * 0.6 + 0.2, arc_height)
    _tween.set_parallel(false)

    _tween.set_parallel(true)
    _tween.tween_property(target, "position", Vector2(final_x, route_y), 0.7)
    _tween.tween_property(tackler, "position", Vector2(final_x, route_y), 0.75)
    _tween.tween_property(ball_marker, "position", Vector2(final_x, route_y), 0.7)
    _tween.set_parallel(false)

    if touchdown:
        _tween.tween_property(target, "scale", Vector2(1.4, 1.4), 0.3)
        _tween.tween_property(target, "scale", Vector2.ONE, 0.2)

func _sequence_pass_incomplete(result: Dictionary, los_x: float, offense_card: int) -> void:
    var target_index: int = clampi(int(result.get("target", 2)), 1, 3)
    var target = offense_markers[target_index]
    var tackler_index: int = clampi(int(result.get("tackler", target_index)), 0, 3)
    var tackler = defense_markers[tackler_index]
    var qb = offense_markers[0]
    var pocket: float = float(result.get("pocket_seconds", 1.2))
    var air_yards: int = int(result.get("air_yards", 8))
    var route_y: float = target.position.y
    var land_pos: Vector2 = Vector2(los_x + float(air_yards) * GameConstants.PIXELS_PER_YARD + 20.0, route_y)

    ball_marker.visible = true
    ball_marker.position = qb.position
    _tween.tween_property(qb, "position", qb.position - Vector2(14.0, 0.0), pocket * 0.6)
    _tween.set_parallel(true)
    _tween.tween_property(target, "position", land_pos - Vector2(15.0, 0.0), pocket * 0.6 + 0.2)
    _tween.tween_property(tackler, "position", land_pos - Vector2(20.0, 0.0), pocket * 0.6 + 0.2)
    var arc_height: float = 55.0 if offense_card == PlayBook.Offense.DEEP_SHOT else 22.0
    _arc_move(ball_marker, ball_marker.position, land_pos, pocket * 0.6 + 0.2, arc_height)
    _tween.set_parallel(false)
    _tween.tween_property(target, "position", land_pos - Vector2(25.0, 0.0), 0.4)

func _sequence_run(result: Dictionary, los_x: float, offense_card: int, touchdown: bool) -> void:
    var rb = offense_markers[1]
    var qb = offense_markers[0]
    var tackler_index: int = clampi(int(result.get("tackler", 1)), 0, 3)
    var tackler = defense_markers[tackler_index]
    var yards: int = int(result.get("yards", 0))
    var hole: String = str(result.get("hole", "inside"))
    var final_x: float = GameConstants.RIGHT_GOAL_X if touchdown else los_x + float(yards) * GameConstants.PIXELS_PER_YARD

    if offense_card == PlayBook.Offense.SCREEN:
        var air_yards: int = int(result.get("air_yards", 2))
        var catch_pos: Vector2 = Vector2(los_x + float(air_yards) * GameConstants.PIXELS_PER_YARD, rb.position.y)
        ball_marker.visible = true
        ball_marker.position = qb.position
        _tween.set_parallel(true)
        _tween.tween_property(rb, "position", catch_pos, 0.35)
        _arc_move(ball_marker, ball_marker.position, catch_pos, 0.35, 14.0)
        _tween.set_parallel(false)
    else:
        _tween.tween_property(rb, "position", Vector2(qb.position.x + 10.0, qb.position.y + 6.0), 0.3)

    var hole_y: float = CENTER_Y if hole == "inside" else CENTER_Y + 130.0
    _tween.set_parallel(true)
    _tween.tween_property(rb, "position", Vector2(los_x + 20.0, hole_y), 0.4)
    _tween.tween_property(tackler, "position", Vector2(los_x + 20.0, hole_y), 0.5)
    _tween.set_parallel(false)

    _tween.set_parallel(true)
    _tween.tween_property(rb, "position", Vector2(final_x, hole_y), 0.7)
    _tween.tween_property(tackler, "position", Vector2(final_x, hole_y), 0.75)
    _tween.set_parallel(false)

    if touchdown:
        _tween.tween_property(rb, "scale", Vector2(1.4, 1.4), 0.3)
        _tween.tween_property(rb, "scale", Vector2.ONE, 0.2)
