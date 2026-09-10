extends Control

const BattleSettings = preload("res://scripts/core/battle_settings.gd")
const SeasonState = preload("res://scripts/core/season_state.gd")
const SeasonScript = preload("res://scripts/core/season.gd")
const SaveGame = preload("res://scripts/core/save_game.gd")

var mode_buttons: Array = []

func _ready() -> void:
    if not SeasonState.has_season() and SaveGame.exists():
        SaveGame.load_dynasty()
    _build_ui()

func _build_ui() -> void:
    var background: ColorRect = ColorRect.new()
    background.color = Color("14212b")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)

    var panel: PanelContainer = PanelContainer.new()
    panel.custom_minimum_size = Vector2(760, 600)
    panel.position = Vector2(260, 50)
    add_child(panel)

    var margin: MarginContainer = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 42)
    margin.add_theme_constant_override("margin_right", 42)
    margin.add_theme_constant_override("margin_top", 28)
    margin.add_theme_constant_override("margin_bottom", 28)
    panel.add_child(margin)

    var column: VBoxContainer = VBoxContainer.new()
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_theme_constant_override("separation", 14)
    margin.add_child(column)

    var title: Label = Label.new()
    title.text = "GRIDIRON DYNASTY"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 42)
    column.add_child(title)

    var rules: Label = Label.new()
    rules.text = "Twelve empires, one map. Attack a neighbour each week, win the Border War, take their land and raid a player.\n7-a-side • 3 possessions each • 4 downs, no kicks • sudden death if tied"
    rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    rules.add_theme_font_size_override("font_size", 16)
    rules.modulate = Color(1, 1, 1, 0.75)
    column.add_child(rules)

    var mode_header: Label = Label.new()
    mode_header.text = "HOW YOU PLAY BATTLES"
    mode_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mode_header.add_theme_font_size_override("font_size", 14)
    mode_header.modulate = Color(1, 1, 1, 0.6)
    column.add_child(mode_header)

    var mode_row: HBoxContainer = HBoxContainer.new()
    mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
    mode_row.add_theme_constant_override("separation", 12)
    column.add_child(mode_row)
    _add_mode_button(mode_row, "PLAY", "throw it yourself", BattleSettings.Mode.PLAY)
    _add_mode_button(mode_row, "WATCH", "call plays, watch", BattleSettings.Mode.WATCH)
    _add_mode_button(mode_row, "AUTO", "box score only", BattleSettings.Mode.AUTO_RESOLVE)

    var spacer: Control = Control.new()
    spacer.custom_minimum_size = Vector2(0, 6)
    column.add_child(spacer)

    if SeasonState.offseason != null or (SeasonState.has_season() and SeasonState.season.over):
        _add_action(column, "CONTINUE OFFSEASON", "Finish aging and the draft, then start season %d." % (SeasonState.season.number + 1), _on_continue_offseason)
    elif SeasonState.has_season():
        var week: int = SeasonState.season.week
        _add_action(column, "CONTINUE SEASON", "Season %d, week %d of %d. Pick up where you left off." % [SeasonState.season.number, mini(week, SeasonScript.MAX_WEEKS), SeasonScript.MAX_WEEKS], _on_continue_season)
    var new_hint: String = "Start a fresh map with fresh rosters."
    if SeasonState.has_season():
        new_hint += " Replaces the saved dynasty."
    _add_action(column, "NEW DYNASTY", new_hint, _on_new_season)
    _add_action(column, "QUICK BATTLE", "One Border War, Hawks vs Forge, no map.", _on_quick_battle)

    var save_note: Label = Label.new()
    save_note.text = "The dynasty autosaves after every week, battle, raid, and draft pick."
    save_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    save_note.add_theme_font_size_override("font_size", 13)
    save_note.modulate = Color(1, 1, 1, 0.5)
    column.add_child(save_note)

    _refresh_mode_buttons()

func _add_mode_button(row: HBoxContainer, title: String, hint: String, mode: int) -> void:
    var button: Button = Button.new()
    button.text = "%s\n%s" % [title, hint]
    button.custom_minimum_size = Vector2(200, 60)
    button.add_theme_font_size_override("font_size", 16)
    button.toggle_mode = true
    button.pressed.connect(_on_mode_pressed.bind(mode))
    row.add_child(button)
    mode_buttons.append({"button": button, "mode": mode})

func _add_action(column: VBoxContainer, title: String, description: String, handler: Callable) -> void:
    var row: HBoxContainer = HBoxContainer.new()
    row.add_theme_constant_override("separation", 18)
    column.add_child(row)

    var button: Button = Button.new()
    button.text = title
    button.custom_minimum_size = Vector2(240, 56)
    button.add_theme_font_size_override("font_size", 20)
    button.pressed.connect(handler)
    row.add_child(button)

    var label: Label = Label.new()
    label.text = description
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 15)
    row.add_child(label)

func _on_mode_pressed(mode: int) -> void:
    BattleSettings.mode = mode
    _refresh_mode_buttons()

func _refresh_mode_buttons() -> void:
    for entry in mode_buttons:
        var button: Button = entry["button"]
        button.button_pressed = int(entry["mode"]) == BattleSettings.mode

func _on_continue_season() -> void:
    get_tree().change_scene_to_file("res://scenes/map.tscn")

func _on_new_season() -> void:
    SaveGame.delete()
    SeasonState.season = SeasonScript.new()
    SeasonState.battle = {}
    SeasonState.offseason = null
    SaveGame.save()
    get_tree().change_scene_to_file("res://scenes/map.tscn")

func _on_continue_offseason() -> void:
    get_tree().change_scene_to_file("res://scenes/offseason.tscn")

func _on_quick_battle() -> void:
    SeasonState.battle = {}
    get_tree().change_scene_to_file("res://scenes/game.tscn")
