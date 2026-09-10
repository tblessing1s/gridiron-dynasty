extends Control

const BattleSettings = preload("res://scripts/core/battle_settings.gd")

var title_label: Label
var subtitle_label: Label

func _ready() -> void:
    _build_ui()

func _build_ui() -> void:
    var background: ColorRect = ColorRect.new()
    background.color = Color("14212b")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)

    var panel: PanelContainer = PanelContainer.new()
    panel.custom_minimum_size = Vector2(760, 560)
    panel.position = Vector2(260, 70)
    add_child(panel)

    var margin: MarginContainer = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 42)
    margin.add_theme_constant_override("margin_right", 42)
    margin.add_theme_constant_override("margin_top", 30)
    margin.add_theme_constant_override("margin_bottom", 30)
    panel.add_child(margin)

    var column: VBoxContainer = VBoxContainer.new()
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_theme_constant_override("separation", 14)
    margin.add_child(column)

    title_label = Label.new()
    title_label.text = "GRIDIRON DYNASTY"
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", 42)
    column.add_child(title_label)

    subtitle_label = Label.new()
    subtitle_label.text = "BORDER WAR  •  HARBOR HAWKS attack IRONVALE FORGE"
    subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle_label.add_theme_font_size_override("font_size", 20)
    column.add_child(subtitle_label)

    var rules: Label = Label.new()
    rules.text = "5-a-side • 3 possessions each • 4 downs, no kicks • sudden death if tied"
    rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    rules.add_theme_font_size_override("font_size", 16)
    rules.modulate = Color(1, 1, 1, 0.75)
    column.add_child(rules)

    var spacer: Control = Control.new()
    spacer.custom_minimum_size = Vector2(0, 10)
    column.add_child(spacer)

    _add_mode_button(column, "PLAY", "Call plays, throw the ball yourself. Pull back from the QB to aim, release to throw. Runs and defense play out on their own.", BattleSettings.Mode.PLAY)
    _add_mode_button(column, "WATCH", "Call every play on both sides, then watch it play out. No throwing.", BattleSettings.Mode.WATCH)
    _add_mode_button(column, "AUTO-RESOLVE", "Skip the field. The whole battle is simulated with the same rules and you get the box score.", BattleSettings.Mode.AUTO_RESOLVE)

func _add_mode_button(column: VBoxContainer, title: String, description: String, mode: int) -> void:
    var row: HBoxContainer = HBoxContainer.new()
    row.add_theme_constant_override("separation", 18)
    column.add_child(row)

    var button: Button = Button.new()
    button.text = title
    button.custom_minimum_size = Vector2(220, 64)
    button.add_theme_font_size_override("font_size", 22)
    button.pressed.connect(_on_mode_pressed.bind(mode))
    row.add_child(button)

    var label: Label = Label.new()
    label.text = description
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 16)
    row.add_child(label)

func _on_mode_pressed(mode: int) -> void:
    BattleSettings.mode = mode
    get_tree().change_scene_to_file("res://scenes/game.tscn")
