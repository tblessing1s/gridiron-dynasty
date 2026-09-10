extends "res://scripts/football/player_body.gd"

var hold_position: Vector2 = Vector2.ZERO
var lead_target = null
var block_speed: float = 170.0

func _ready() -> void:
    label_text = "BL"
    super()

func _on_stats_applied() -> void:
    block_speed = lerpf(130.0, 190.0, float(stat("speed")) / 100.0)

func reset_for_play(pos: Vector2) -> void:
    global_position = pos
    hold_position = pos
    lead_target = null
    velocity = Vector2.ZERO

func lead_for(carrier) -> void:
    lead_target = carrier

func _physics_process(_delta: float) -> void:
    var target: Vector2 = hold_position
    if lead_target != null and is_instance_valid(lead_target):
        target = lead_target.global_position + Vector2(38.0, 0.0)
        target.x = maxf(target.x, global_position.x - 10.0)
    var difference: Vector2 = target - global_position
    if difference.length() > 4.0:
        velocity = difference.normalized() * block_speed
        move_and_slide()
    else:
        velocity = Vector2.ZERO
