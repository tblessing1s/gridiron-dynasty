extends Node2D

var contested: bool = false

func _ready() -> void:
    z_index = 25
    visible = false

func show_at(pos: Vector2, is_contested: bool) -> void:
    global_position = pos
    contested = is_contested
    visible = true
    queue_redraw()

func hide_marker() -> void:
    visible = false

func _draw() -> void:
    var color: Color = Color("ff6b4a") if contested else Color("ffe06b")
    draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 32, color, 3.0)
    draw_circle(Vector2.ZERO, 4.0, color)
    draw_line(Vector2(-32.0, 0.0), Vector2(-14.0, 0.0), color, 2.0)
    draw_line(Vector2(14.0, 0.0), Vector2(32.0, 0.0), color, 2.0)
    draw_line(Vector2(0.0, -32.0), Vector2(0.0, -14.0), color, 2.0)
    draw_line(Vector2(0.0, 14.0), Vector2(0.0, 32.0), color, 2.0)
