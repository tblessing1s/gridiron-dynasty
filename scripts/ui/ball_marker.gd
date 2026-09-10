extends Node2D

# A small brown oval standing in for the football during a SIM replay
# (scripts/ui/play_replay.gd). Position is driven entirely by tweens.

const RADIUS: Vector2 = Vector2(9.0, 6.0)

func _ready() -> void:
    z_index = 25
    queue_redraw()

func _draw() -> void:
    draw_set_transform(Vector2.ZERO, rotation, Vector2.ONE)
    draw_circle(Vector2.ZERO, 1.0, Color("7a4a25"))
    var points: PackedVector2Array = PackedVector2Array()
    var steps: int = 16
    for i in range(steps + 1):
        var angle: float = TAU * float(i) / float(steps)
        points.append(Vector2(cos(angle) * RADIUS.x, sin(angle) * RADIUS.y))
    draw_colored_polygon(points, Color("7a4a25"))
    draw_polyline(PackedVector2Array([Vector2(-4.0, 0.0), Vector2(4.0, 0.0)]), Color(1, 1, 1, 0.85), 1.5)
