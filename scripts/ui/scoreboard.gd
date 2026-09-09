extends CanvasLayer

signal back_to_menu_requested
signal restart_drive_requested

const DOWN_NAMES: Array[String] = ["", "1ST", "2ND", "3RD", "4TH"]

var score_label: Label
var situation_label: Label
var clock_label: Label
var message_label: Label
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

    score_label = _make_label(Vector2(28, 17), Vector2(310, 48), 26)
    score_label.text = "HOME 0   AWAY 0"
    add_child(score_label)

    situation_label = _make_label(Vector2(430, 17), Vector2(420, 48), 24)
    situation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(situation_label)

    clock_label = _make_label(Vector2(960, 17), Vector2(290, 48), 26)
    clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    add_child(clock_label)

    message_label = _make_label(Vector2(340, 92), Vector2(600, 42), 21)
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_label.text = "Touch the QB and drag to aim."
    add_child(message_label)

    overlay = ColorRect.new()
    overlay.color = Color(0.02, 0.03, 0.04, 0.90)
    overlay.position = Vector2(290, 170)
    overlay.size = Vector2(700, 380)
    overlay.visible = false
    add_child(overlay)

    overlay_title = _make_label(Vector2(40, 45), Vector2(620, 70), 38)
    overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    overlay.add_child(overlay_title)

    overlay_detail = _make_label(Vector2(60, 130), Vector2(580, 80), 22)
    overlay_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    overlay_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    overlay.add_child(overlay_detail)

    restart_button = Button.new()
    restart_button.text = "RESTART DRIVE"
    restart_button.position = Vector2(100, 250)
    restart_button.size = Vector2(230, 64)
    restart_button.add_theme_font_size_override("font_size", 20)
    restart_button.pressed.connect(func(): restart_drive_requested.emit())
    overlay.add_child(restart_button)

    menu_button = Button.new()
    menu_button.text = "MAIN MENU"
    menu_button.position = Vector2(370, 250)
    menu_button.size = Vector2(230, 64)
    menu_button.add_theme_font_size_override("font_size", 20)
    menu_button.pressed.connect(func(): back_to_menu_requested.emit())
    overlay.add_child(menu_button)

func _make_label(pos: Vector2, size: Vector2, font_size: int) -> Label:
    var label: Label = Label.new()
    label.position = pos
    label.size = size
    label.add_theme_font_size_override("font_size", font_size)
    return label

func update_score(home_score: int, away_score: int) -> void:
    score_label.text = "HOME %d   AWAY %d" % [home_score, away_score]

func update_situation(down: int, yards_to_go: int, ball_yard: int) -> void:
    var down_index: int = clampi(down, 1, 4)
    var down_text: String = DOWN_NAMES[down_index]
    var display_yards: int = maxi(yards_to_go, 1)
    var display_ball: int = clampi(ball_yard, 0, 100)
    situation_label.text = "%s & %d   •   BALL ON %d" % [down_text, display_yards, display_ball]

func update_clock(seconds_left: float) -> void:
    var total: int = maxi(int(ceil(seconds_left)), 0)
    var minutes: int = int(total / 60)
    var seconds: int = total % 60
    clock_label.text = "%d:%02d" % [minutes, seconds]

func set_message(text: String) -> void:
    message_label.text = text

func show_drive_result(title: String, detail: String) -> void:
    overlay_title.text = title
    overlay_detail.text = detail
    overlay.visible = true

func hide_drive_result() -> void:
    overlay.visible = false
