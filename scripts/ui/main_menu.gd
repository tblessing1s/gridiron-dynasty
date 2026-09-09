extends Control

var title_label: Label
var subtitle_label: Label
var start_button: Button
var instructions_label: Label

func _ready() -> void:
    _build_ui()

func _build_ui() -> void:
    var background: ColorRect = ColorRect.new()
    background.color = Color("14212b")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)

    var panel: PanelContainer = PanelContainer.new()
    panel.custom_minimum_size = Vector2(650, 470)
    panel.position = Vector2(315, 110)
    add_child(panel)

    var margin: MarginContainer = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 42)
    margin.add_theme_constant_override("margin_right", 42)
    margin.add_theme_constant_override("margin_top", 36)
    margin.add_theme_constant_override("margin_bottom", 36)
    panel.add_child(margin)

    var column: VBoxContainer = VBoxContainer.new()
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_theme_constant_override("separation", 18)
    margin.add_child(column)

    title_label = Label.new()
    title_label.text = "GRIDIRON DYNASTY"
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", 42)
    column.add_child(title_label)

    subtitle_label = Label.new()
    subtitle_label.text = "Phase 1 • Offensive Drive Prototype"
    subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle_label.add_theme_font_size_override("font_size", 22)
    column.add_child(subtitle_label)

    var spacer: Control = Control.new()
    spacer.custom_minimum_size = Vector2(0, 20)
    column.add_child(spacer)

    start_button = Button.new()
    start_button.text = "START DRIVE"
    start_button.custom_minimum_size = Vector2(320, 66)
    start_button.add_theme_font_size_override("font_size", 24)
    start_button.pressed.connect(_on_start_pressed)
    column.add_child(start_button)

    instructions_label = Label.new()
    instructions_label.text = "PASS: touch/click the QB, drag toward a receiver, release to throw\nRUN: drag anywhere to steer after the catch • WASD/arrow keys also work"
    instructions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    instructions_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    instructions_label.add_theme_font_size_override("font_size", 18)
    column.add_child(instructions_label)

    var goal: Label = Label.new()
    goal.text = "Goal: move the ball downfield and score a touchdown."
    goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    goal.add_theme_font_size_override("font_size", 18)
    column.add_child(goal)

func _on_start_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/game.tscn")
