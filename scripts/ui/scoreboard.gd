extends CanvasLayer

signal back_to_menu_requested
signal restart_requested
signal card_selected(index: int)

const DOWN_NAMES: Array[String] = ["", "1ST", "2ND", "3RD", "4TH"]
const CARD_WIDTH: float = 250.0
const CARD_HEIGHT: float = 62.0
const CARD_GAP: float = 16.0
const MAX_CARDS: int = 4

var score_label: Label
var situation_label: Label
var possession_label: Label
var message_label: Label
var mode_label: Label
var read_label: Label
var card_bar: ColorRect
var card_buttons: Array = []
var overlay: ColorRect
var overlay_title: Label
var overlay_detail: Label
var restart_button: Button
var menu_button: Button

func _ready() -> void:
    layer = 100
    _build_ui()

func _build_ui() -> void:
    var top_bar: ColorRect = ColorRect.new()
    top_bar.color = Color(0.03, 0.04, 0.05, 0.93)
    top_bar.position = Vector2(0, 0)
    top_bar.size = Vector2(1280, 80)
    add_child(top_bar)

    score_label = _make_label(Vector2(28, 17), Vector2(400, 48), 20)
    add_child(score_label)

    situation_label = _make_label(Vector2(440, 17), Vector2(410, 48), 24)
    situation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(situation_label)

    possession_label = _make_label(Vector2(860, 17), Vector2(392, 48), 20)
    possession_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    add_child(possession_label)

    message_label = _make_label(Vector2(240, 92), Vector2(800, 42), 21)
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(message_label)

    mode_label = _make_label(Vector2(1000, 132), Vector2(260, 30), 16)
    mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    mode_label.modulate = Color(1, 1, 1, 0.7)
    add_child(mode_label)

    card_bar = ColorRect.new()
    card_bar.color = Color(0.03, 0.04, 0.05, 0.9)
    card_bar.position = Vector2(0, 590)
    card_bar.size = Vector2(1280, 130)
    card_bar.visible = false
    add_child(card_bar)

    read_label = _make_label(Vector2(0, 8), Vector2(1280, 30), 18)
    read_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    card_bar.add_child(read_label)

    for i in range(MAX_CARDS):
        var button: Button = Button.new()
        button.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
        button.add_theme_font_size_override("font_size", 18)
        button.pressed.connect(_on_card_pressed.bind(i))
        card_bar.add_child(button)
        card_buttons.append(button)

    overlay = ColorRect.new()
    overlay.color = Color(0.02, 0.03, 0.04, 0.92)
    overlay.position = Vector2(240, 120)
    overlay.size = Vector2(800, 480)
    overlay.visible = false
    add_child(overlay)

    overlay_title = _make_label(Vector2(40, 30), Vector2(720, 70), 38)
    overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    overlay.add_child(overlay_title)

    overlay_detail = _make_label(Vector2(60, 110), Vector2(680, 270), 19)
    overlay_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    overlay_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    overlay.add_child(overlay_detail)

    restart_button = Button.new()
    restart_button.text = "PLAY AGAIN"
    restart_button.position = Vector2(170, 400)
    restart_button.size = Vector2(220, 56)
    restart_button.add_theme_font_size_override("font_size", 20)
    restart_button.pressed.connect(func() -> void: restart_requested.emit())
    overlay.add_child(restart_button)

    menu_button = Button.new()
    menu_button.text = "MAIN MENU"
    menu_button.position = Vector2(410, 400)
    menu_button.size = Vector2(220, 56)
    menu_button.add_theme_font_size_override("font_size", 20)
    menu_button.pressed.connect(func() -> void: back_to_menu_requested.emit())
    overlay.add_child(menu_button)

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

func set_mode_text(text: String) -> void:
    mode_label.text = text

func set_message(text: String) -> void:
    message_label.text = text

func set_read(text: String) -> void:
    read_label.text = text

func show_cards(names: Array, hints: Array) -> void:
    var count: int = mini(names.size(), MAX_CARDS)
    var total_width: float = float(count) * CARD_WIDTH + float(count - 1) * CARD_GAP
    var start_x: float = (1280.0 - total_width) * 0.5
    for i in range(MAX_CARDS):
        var button: Button = card_buttons[i]
        if i < count:
            button.text = "%s\n%s" % [names[i], hints[i]]
            button.position = Vector2(start_x + float(i) * (CARD_WIDTH + CARD_GAP), 48)
            button.visible = true
        else:
            button.visible = false
    card_bar.visible = true

func hide_cards() -> void:
    card_bar.visible = false

func show_result(title: String, detail: String) -> void:
    overlay_title.text = title
    overlay_detail.text = detail
    overlay.visible = true

func hide_result() -> void:
    overlay.visible = false
