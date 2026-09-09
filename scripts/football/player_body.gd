extends CharacterBody2D

const GameConstants = preload("res://scripts/core/game_constants.gd")

@export var body_color: Color = Color("3a82d2")
@export var outline_color: Color = Color.WHITE
@export var label_text: String = "P"
@export var move_speed: float = 180.0

var active: bool = true

func _ready() -> void:
    collision_layer = 0
    collision_mask = 0
    queue_redraw()

func _draw() -> void:
    draw_circle(Vector2.ZERO, GameConstants.PLAYER_RADIUS + 3.0, outline_color)
    draw_circle(Vector2.ZERO, GameConstants.PLAYER_RADIUS, body_color)
    var font: Font = ThemeDB.fallback_font
    var font_size: int = 13
    var text_size: Vector2 = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
    draw_string(font, Vector2(-text_size.x * 0.5, text_size.y * 0.34), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
