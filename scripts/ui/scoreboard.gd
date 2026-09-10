extends CanvasLayer

const BorderBarScript = preload("res://scripts/ui/border_bar.gd")

signal card_selected(index: int)

const DOWN_NAMES: Array[String] = ["", "1ST", "2ND", "3RD", "4TH"]
const CARD_WIDTH: float = 198.0
const CARD_HEIGHT: float = 84.0
const CARD_GAP: float = 10.0
const MAX_CARDS: int = 6
const CARD_BAR_HEIGHT: float = 160.0

var score_label: Label
var situation_label: Label
var possession_label: Label
var message_label: Label
var detail_label: Label
var mode_label: Label
var border_bar
var read_label: Label
var coach_label: Label
var card_bar: ColorRect
var card_buttons: Array = []

func _ready() -> void:
    layer = 100
    _build_ui()

func _build_ui() -> void:
    var top_bar: ColorRect = ColorRect.new()
    top_bar.color = Color(0.03, 0.04, 0.05, 0.93)
    top_bar.position = Vector2(0, 0)
    top_bar.size = Vector2(1280, 108)
    add_child(top_bar)

    score_label = _make_label(Vector2(28, 10), Vector2(400, 40), 20)
    add_child(score_label)

    situation_label = _make_label(Vector2(440, 8), Vector2(410, 40), 24)
    situation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(situation_label)

    possession_label = _make_label(Vector2(860, 10), Vector2(392, 40), 20)
    possession_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    add_child(possession_label)

    border_bar = BorderBarScript.new()
    border_bar.position = Vector2(140, 62)
    border_bar.size = Vector2(1000, 24)
    add_child(border_bar)

    message_label = _make_label(Vector2(240, 116), Vector2(800, 30), 20)
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(message_label)

    detail_label = _make_label(Vector2(140, 150), Vector2(1000, 30), 14)
    detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail_label.modulate = Color(1, 1, 1, 0.7)
    add_child(detail_label)

    mode_label = _make_label(Vector2(1000, 150), Vector2(260, 30), 16)
    mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    mode_label.modulate = Color(1, 1, 1, 0.7)
    add_child(mode_label)

    var card_bar_y: float = 720.0 - CARD_BAR_HEIGHT
    card_bar = ColorRect.new()
    card_bar.color = Color(0.03, 0.04, 0.05, 0.9)
    card_bar.position = Vector2(0, card_bar_y)
    card_bar.size = Vector2(1280, CARD_BAR_HEIGHT)
    card_bar.visible = false
    add_child(card_bar)

    read_label = _make_label(Vector2(0, 4), Vector2(1280, 24), 16)
    read_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    card_bar.add_child(read_label)

    coach_label = _make_label(Vector2(0, 26), Vector2(1280, 22), 14)
    coach_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coach_label.modulate = Color(0.95, 0.78, 0.45, 0.95)
    card_bar.add_child(coach_label)

    for i in range(MAX_CARDS):
        var button: Button = Button.new()
        button.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
        button.add_theme_font_size_override("font_size", 12)
        button.clip_text = true
        button.pressed.connect(_on_card_pressed.bind(i))
        card_bar.add_child(button)
        card_buttons.append(button)

func _make_label(pos: Vector2, size: Vector2, font_size: int) -> Label:
    var label: Label = Label.new()
    label.position = pos
    label.size = size
    label.add_theme_font_size_override("font_size", font_size)
    return label

func _on_card_pressed(index: int) -> void:
    card_selected.emit(index)

func update_score(home_score: int, away_score: int, home_name: String, away_name: String) -> void:
    score_label.text = "%s %d   %s %d" % [home_name, home_score, away_name, away_score]

func update_situation(down: int, yards_to_go: int, ball_yard: int) -> void:
    var down_index: int = clampi(down, 1, 4)
    var down_text: String = DOWN_NAMES[down_index]
    var display_yards: int = maxi(yards_to_go, 1)
    var display_ball: int = clampi(ball_yard, 0, 100)
    situation_label.text = "%s & %d   •   BALL ON %d" % [down_text, display_yards, display_ball]

func update_possession(text: String) -> void:
    possession_label.text = text

func setup_border(home: Dictionary, away: Dictionary) -> void:
    border_bar.setup(home, away)

func update_border(fraction: float) -> void:
    border_bar.set_fraction(fraction)

func set_mode_text(text: String) -> void:
    mode_label.text = text

func set_message(text: String) -> void:
    message_label.text = text

func set_detail(text: String) -> void:
    detail_label.text = text

func set_read(text: String) -> void:
    read_label.text = text

func set_coach(text: String) -> void:
    coach_label.text = text

# texts: one fully-built multi-line string per card (name, matchup line,
# stat hint), already assembled by football_game.
func show_cards(texts: Array) -> void:
    var count: int = mini(texts.size(), MAX_CARDS)
    var total_width: float = float(count) * CARD_WIDTH + float(count - 1) * CARD_GAP
    var start_x: float = (1280.0 - total_width) * 0.5
    for i in range(MAX_CARDS):
        var button: Button = card_buttons[i]
        if i < count:
            button.text = str(texts[i])
            button.position = Vector2(start_x + float(i) * (CARD_WIDTH + CARD_GAP), 52)
            button.visible = true
        else:
            button.visible = false
    card_bar.visible = true

func hide_cards() -> void:
    card_bar.visible = false
