extends CanvasLayer

const Rosters = preload("res://scripts/core/rosters.gd")
const BattleSettings = preload("res://scripts/core/battle_settings.gd")
const PlayerRow = preload("res://scripts/ui/player_row.gd")

signal play_requested
signal auto_requested
signal menu_requested
signal tag_changed(index: int)

const ROW_STEP: float = 46.0
const COLUMN_WIDTH: float = 596.0
const LINEUP_TOP: float = 236.0

var tag_index: int = -1
var tag_buttons: Array = []
var root: Control

func _ready() -> void:
    layer = 110

# context: territory (String), origin (String), user_is_attacker (bool),
# target_is_capital (bool), origin_is_capital (bool).
func setup(home: Dictionary, away: Dictionary, mode: int, home_crowd_penalty: float, away_tag_index: int, context: Dictionary, locked_tag_index: int) -> void:
    if root != null:
        root.queue_free()
    tag_buttons.clear()
    tag_index = locked_tag_index
    var user_is_attacker: bool = bool(context.get("user_is_attacker", true))
    var territory: String = str(context.get("territory", "their territory"))
    var origin: String = str(context.get("origin", "your border territory"))

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
    var attacker: Dictionary = home if user_is_attacker else away
    var defender: Dictionary = away if user_is_attacker else home
    subtitle.text = "[center][color=#%s]%s[/color] attack [color=#%s]%s[/color] at %s[/center]" % [attacker["color"].to_html(false), attacker["name"], defender["color"].to_html(false), defender["name"], territory]
    root.add_child(subtitle)

    var stakes: Label = _label(Vector2(100, 104), Vector2(1080, 30), 18)
    var capital_warning: String = ""
    if user_is_attacker:
        if bool(context.get("target_is_capital", false)):
            capital_warning = " — their capital, they are eliminated"
        if bool(context.get("origin_is_capital", false)):
            stakes.text = "WIN: capture %s%s and raid one %s player      LOSE: get raided (your capital holds)" % [territory, capital_warning, away["short"]]
        else:
            stakes.text = "WIN: capture %s%s and raid one %s player      LOSE: lose %s and get raided" % [territory, capital_warning, away["short"], origin]
    else:
        if bool(context.get("target_is_capital", false)):
            capital_warning = " — YOUR CAPITAL, you are eliminated"
        stakes.text = "WIN: hold %s, take %s and raid one %s player      LOSE: lose %s%s and get raided" % [territory, origin, away["short"], territory, capital_warning]
    stakes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stakes.modulate = Color(1, 1, 1, 0.85)
    root.add_child(stakes)

    var chips: HBoxContainer = HBoxContainer.new()
    chips.position = Vector2(0, 146)
    chips.size = Vector2(1280, 40)
    chips.alignment = BoxContainer.ALIGNMENT_CENTER
    chips.add_theme_constant_override("separation", 24)
    root.add_child(chips)
    if home_crowd_penalty > 1.0:
        chips.add_child(_chip("Home crowd: %s throw scatter +%d%%" % [attacker["short"], int(round((home_crowd_penalty - 1.0) * 100.0))]))
    chips.add_child(_chip(_weak_spot_text(home, away)))

    _add_column(40.0, "YOUR SEVEN", home, Rosters.SLOT_TYPES, locked_tag_index < 0, locked_tag_index)
    _add_column(644.0, "%s SEVEN" % away["short"], away, Rosters.DEFENSE_SLOT_TYPES, false, away_tag_index)

    var hint: Label = _label(Vector2(40, LINEUP_TOP + 7.0 * ROW_STEP + 4.0), Vector2(596, 24), 14)
    hint.text = "Franchise tag is locked for the season." if locked_tag_index >= 0 else "TAG one player: they cannot be raided if you lose. It locks for the season."
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

func _add_column(x: float, header_text: String, team: Dictionary, slots: Array[String], tag_enabled: bool, tagged_index: int) -> void:
    var color: Color = team["color"]
    var header: Label = _label(Vector2(x, LINEUP_TOP - 30.0), Vector2(COLUMN_WIDTH, 26), 16)
    header.text = header_text
    header.modulate = color.lightened(0.35)
    root.add_child(header)

    var players: Array = team["players"]
    for i in range(players.size()):
        var row: ColorRect = PlayerRow.build(players[i], slots[i], color, COLUMN_WIDTH, false)
        row.position = Vector2(x, LINEUP_TOP + float(i) * ROW_STEP)
        root.add_child(row)
        if tag_enabled:
            var tag: Button = _button("TAG", Vector2(64, 30), 13)
            tag.position = Vector2(COLUMN_WIDTH - 72.0, 6)
            tag.pressed.connect(_on_tag_pressed.bind(i))
            row.add_child(tag)
            tag_buttons.append(tag)
        elif i == tagged_index:
            PlayerRow.add_chip(row, "TAGGED", COLUMN_WIDTH - 70.0, Color(1, 0.85, 0.4, 0.9))

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
