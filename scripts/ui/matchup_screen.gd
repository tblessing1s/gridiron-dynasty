extends CanvasLayer

const Rosters = preload("res://scripts/core/rosters.gd")
const BattleSettings = preload("res://scripts/core/battle_settings.gd")

signal play_requested
signal auto_requested
signal menu_requested
signal tag_changed(index: int)

const STAT_KEYS: Array[String] = ["speed", "power", "skill", "awareness"]
const STAT_LABELS: Array[String] = ["SPD", "PWR", "SKL", "AWR"]
const OFFENSE_SLOTS: Array[String] = ["QB", "RB", "WR", "WR", "BL", "BL", "BL"]
const DEFENSE_SLOTS: Array[String] = ["S", "LB", "CB", "CB", "X", "X", "X"]
const ROW_HEIGHT: float = 46.0
const COLUMN_WIDTH: float = 596.0
const LINEUP_TOP: float = 236.0

var tag_index: int = -1
var tag_buttons: Array = []
var root: Control

func _ready() -> void:
    layer = 110

func setup(home: Dictionary, away: Dictionary, mode: int, home_crowd_penalty: float) -> void:
    if root != null:
        root.queue_free()
    tag_buttons.clear()

    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root)

    var background: ColorRect = ColorRect.new()
    background.color = Color(0.05, 0.07, 0.09, 0.97)
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(background)

    var title: Label = _label(Vector2(0, 18), Vector2(1280, 44), 34)
    title.text = "BORDER WAR"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root.add_child(title)

    var subtitle: RichTextLabel = RichTextLabel.new()
    subtitle.bbcode_enabled = true
    subtitle.fit_content = true
    subtitle.scroll_active = false
    subtitle.position = Vector2(0, 62)
    subtitle.size = Vector2(1280, 36)
    subtitle.add_theme_font_size_override("normal_font_size", 22)
    subtitle.text = "[center][color=#%s]%s[/color] attack [color=#%s]%s[/color][/center]" % [_hex(home["color"]), home["name"], _hex(away["color"]), away["name"]]
    root.add_child(subtitle)

    var stakes: Label = _label(Vector2(140, 104), Vector2(1000, 30), 18)
    stakes.text = "WIN: capture their territory and raid one %s player      LOSE: lose your border territory and get raided" % away["short"]
    stakes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stakes.modulate = Color(1, 1, 1, 0.85)
    root.add_child(stakes)

    var chips: HBoxContainer = HBoxContainer.new()
    chips.position = Vector2(0, 146)
    chips.size = Vector2(1280, 40)
    chips.alignment = BoxContainer.ALIGNMENT_CENTER
    chips.add_theme_constant_override("separation", 24)
    root.add_child(chips)
    chips.add_child(_chip("Home crowd: %s throw scatter +%d%%" % [home["short"], int(round((home_crowd_penalty - 1.0) * 100.0))]))
    chips.add_child(_chip(_weak_spot_text(home, away)))

    _add_column(40.0, "YOUR SEVEN", home, OFFENSE_SLOTS, true)
    _add_column(644.0, "%s SEVEN" % away["short"], away, DEFENSE_SLOTS, false)

    var hint: Label = _label(Vector2(40, LINEUP_TOP + 7.0 * ROW_HEIGHT + 4.0), Vector2(596, 24), 14)
    hint.text = "TAG one player: they cannot be raided this season."
    hint.modulate = Color(1, 1, 1, 0.6)
    root.add_child(hint)

    var buttons: HBoxContainer = HBoxContainer.new()
    buttons.position = Vector2(0, 640)
    buttons.size = Vector2(1280, 60)
    buttons.alignment = BoxContainer.ALIGNMENT_CENTER
    buttons.add_theme_constant_override("separation", 20)
    root.add_child(buttons)

    var primary: Button = _button(BattleSettings.mode_name(mode) + " BATTLE" if mode != BattleSettings.Mode.AUTO_RESOLVE else "AUTO-RESOLVE", Vector2(300, 60), 22)
    if mode == BattleSettings.Mode.AUTO_RESOLVE:
        primary.pressed.connect(func() -> void: auto_requested.emit())
    else:
        primary.pressed.connect(func() -> void: play_requested.emit())
    buttons.add_child(primary)

    if mode != BattleSettings.Mode.AUTO_RESOLVE:
        var auto: Button = _button("AUTO-RESOLVE", Vector2(220, 60), 18)
        auto.pressed.connect(func() -> void: auto_requested.emit())
        buttons.add_child(auto)

    var menu: Button = _button("MENU", Vector2(140, 60), 18)
    menu.pressed.connect(func() -> void: menu_requested.emit())
    buttons.add_child(menu)

    _refresh_tag_buttons()

func _add_column(x: float, header_text: String, team: Dictionary, slots: Array[String], tag_enabled: bool) -> void:
    var color: Color = team["color"]
    var header: Label = _label(Vector2(x, LINEUP_TOP - 30.0), Vector2(COLUMN_WIDTH, 26), 16)
    header.text = header_text
    header.modulate = color.lightened(0.35)
    root.add_child(header)

    var players: Array = team["players"]
    for i in range(players.size()):
        _add_row(x, LINEUP_TOP + float(i) * ROW_HEIGHT, i, players[i], slots[i], color, tag_enabled)

func _add_row(x: float, y: float, index: int, player: Dictionary, slot: String, color: Color, tag_enabled: bool) -> void:
    var row: ColorRect = ColorRect.new()
    row.color = Color(1, 1, 1, 0.06)
    row.position = Vector2(x, y)
    row.size = Vector2(COLUMN_WIDTH, ROW_HEIGHT - 4.0)
    root.add_child(row)

    var slot_label: Label = _label(Vector2(10, 11), Vector2(44, 22), 14)
    slot_label.text = slot
    slot_label.modulate = color.lightened(0.4)
    row.add_child(slot_label)

    var name_label: Label = _label(Vector2(56, 9), Vector2(130, 26), 17)
    name_label.text = str(player["name"])
    row.add_child(name_label)

    for k in range(STAT_KEYS.size()):
        var stat_x: float = 190.0 + float(k) * 84.0
        var value: int = int(player[STAT_KEYS[k]])
        var stat_label: Label = _label(Vector2(stat_x, 3), Vector2(60, 18), 12)
        stat_label.text = "%s %d" % [STAT_LABELS[k], value]
        stat_label.modulate = Color(1, 1, 1, 0.75)
        row.add_child(stat_label)

        var track: ColorRect = ColorRect.new()
        track.color = Color(0, 0, 0, 0.45)
        track.position = Vector2(stat_x, 24)
        track.size = Vector2(72, 9)
        row.add_child(track)

        var fill: ColorRect = ColorRect.new()
        fill.color = color.lightened(0.2)
        fill.position = Vector2(stat_x, 24)
        fill.size = Vector2(72.0 * float(value) / 100.0, 9)
        row.add_child(fill)

    if tag_enabled:
        var tag: Button = _button("TAG", Vector2(64, 30), 13)
        tag.position = Vector2(COLUMN_WIDTH - 72.0, 6)
        tag.pressed.connect(_on_tag_pressed.bind(index))
        row.add_child(tag)
        tag_buttons.append(tag)

func _on_tag_pressed(index: int) -> void:
    tag_index = -1 if tag_index == index else index
    _refresh_tag_buttons()
    tag_changed.emit(tag_index)

func _refresh_tag_buttons() -> void:
    for i in range(tag_buttons.size()):
        var button: Button = tag_buttons[i]
        button.text = "TAGGED" if i == tag_index else "TAG"

func _weak_spot_text(home: Dictionary, away: Dictionary) -> String:
    var home_players: Array = home["players"]
    var away_players: Array = away["players"]
    var worst: float = INF
    var text: String = ""
    for i in range(Rosters.LINE_SIZE):
        var blocker: Dictionary = home_players[Rosters.LINE_START + i]
        var rusher: Dictionary = away_players[Rosters.LINE_START + i]
        var pocket: float = Rosters.pocket_seconds(int(blocker["power"]), int(rusher["power"]))
        if pocket < worst:
            worst = pocket
            text = "Weak spot: %s (%d) vs %s (%d) - %.1fs pocket" % [blocker["name"], int(blocker["power"]), rusher["name"], int(rusher["power"]), pocket]
    return text

func _chip(text: String) -> PanelContainer:
    var panel: PanelContainer = PanelContainer.new()
    var label: Label = Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", 15)
    panel.add_child(label)
    return panel

func _label(pos: Vector2, size: Vector2, font_size: int) -> Label:
    var label: Label = Label.new()
    label.position = pos
    label.size = size
    label.add_theme_font_size_override("font_size", font_size)
    return label

func _button(text: String, size: Vector2, font_size: int) -> Button:
    var button: Button = Button.new()
    button.text = text
    button.custom_minimum_size = size
    button.size = size
    button.add_theme_font_size_override("font_size", font_size)
    return button

func _hex(color: Color) -> String:
    return color.to_html(false)
