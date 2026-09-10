extends CanvasLayer

const PlayerRow = preload("res://scripts/ui/player_row.gd")
const BattleXp = preload("res://scripts/core/battle_xp.gd")
const Rosters = preload("res://scripts/core/rosters.gd")
const BorderBarScript = preload("res://scripts/ui/border_bar.gd")

signal raid_requested
signal menu_requested

const STAT_SHORT: Dictionary = {"speed": "SPD", "power": "PWR", "skill": "SKL", "awareness": "AWR"}

var root: Control

func _ready() -> void:
    layer = 110

# xp_report: Array of {team, index, gains} entries, already applied.
func setup(home: Dictionary, away: Dictionary, scores: Array, user_won: bool, log: Array, xp_report: Array, user_stats: Array, auto_resolved: bool) -> void:
    if root != null:
        root.queue_free()
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root)

    var background: ColorRect = ColorRect.new()
    background.color = Color(0.05, 0.07, 0.09, 0.97)
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(background)

    var winner: Dictionary = home if user_won else away
    var winner_score: int = int(scores[0]) if user_won else int(scores[1])
    var loser_score: int = int(scores[1]) if user_won else int(scores[0])

    var title: Label = _label(Vector2(0, 14), Vector2(1280, 46), 36)
    title.text = "%s WIN %d – %d" % [winner["short"], winner_score, loser_score]
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root.add_child(title)

    var subtitle: Label = _label(Vector2(0, 58), Vector2(1280, 26), 18)
    subtitle.text = "Territory captured" if user_won else "Border territory lost"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.modulate = Color(winner["color"].lightened(0.35), 1.0)
    root.add_child(subtitle)

    var bar = BorderBarScript.new()
    bar.position = Vector2(140, 92)
    bar.size = Vector2(1000, 22)
    bar.setup(home, away)
    bar.set_fraction(1.0 if user_won else 0.0)
    root.add_child(bar)

    var log_header: Label = _label(Vector2(60, 132), Vector2(520, 24), 15)
    log_header.text = "POSSESSIONS"
    log_header.modulate = Color(1, 1, 1, 0.6)
    root.add_child(log_header)

    var log_label: Label = _label(Vector2(60, 158), Vector2(520, 340), 15)
    log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    log_label.text = "\n".join(PackedStringArray(log))
    root.add_child(log_label)

    var xp_header: Label = _label(Vector2(640, 132), Vector2(580, 24), 15)
    xp_header.text = "PLAYER XP"
    xp_header.modulate = Color(1, 1, 1, 0.6)
    root.add_child(xp_header)

    var y: float = 158.0
    if auto_resolved:
        var note: Label = _label(Vector2(640, y), Vector2(580, 24), 15)
        note.text = "Auto-resolved battles earn no XP."
        note.modulate = Color(1, 1, 1, 0.7)
        root.add_child(note)
        y += 30.0
    elif xp_report.is_empty():
        var note: Label = _label(Vector2(640, y), Vector2(580, 24), 15)
        note.text = "No stat gains this battle."
        note.modulate = Color(1, 1, 1, 0.7)
        root.add_child(note)
        y += 30.0
    else:
        for entry in xp_report:
            if y > 470.0:
                break
            var team: Dictionary = home if int(entry["team"]) == 0 else away
            var index: int = int(entry["index"])
            var player: Dictionary = team["players"][index]
            var line: Label = _label(Vector2(640, y), Vector2(580, 24), 15)
            var chips: PackedStringArray = PackedStringArray()
            var gains: Dictionary = entry["gains"]
            for key in gains.keys():
                chips.append("+%d %s" % [int(gains[key]), STAT_SHORT[key]])
            line.text = "%s  %s %s    %s" % [team["short"], Rosters.SLOT_TYPES[index], player["name"], "   ".join(chips)]
            line.modulate = Color(team["color"].lightened(0.45), 1.0)
            root.add_child(line)
            y += 26.0

    var fatigue_header: Label = _label(Vector2(640, 500), Vector2(580, 24), 15)
    fatigue_header.text = "%s FATIGUE" % home["short"]
    fatigue_header.modulate = Color(1, 1, 1, 0.6)
    root.add_child(fatigue_header)

    var home_players: Array = home["players"]
    for i in range(home_players.size()):
        var column: int = i % 4
        var row_index: int = i / 4
        var x: float = 640.0 + float(column) * 145.0
        var fy: float = 526.0 + float(row_index) * 30.0
        var name_label: Label = _label(Vector2(x, fy), Vector2(90, 20), 13)
        name_label.text = str(home_players[i]["name"])
        root.add_child(name_label)
        var bars: int = BattleXp.fatigue_bars(user_stats[i]) if i < user_stats.size() else 0
        for b in range(BattleXp.MAX_FATIGUE_BARS):
            var segment: ColorRect = ColorRect.new()
            segment.position = Vector2(x + 82.0 + float(b) * 12.0, fy + 5.0)
            segment.size = Vector2(9, 10)
            segment.color = Color("e0b04a") if b < bars else Color(1, 1, 1, 0.15)
            root.add_child(segment)

    var buttons: HBoxContainer = HBoxContainer.new()
    buttons.position = Vector2(0, 640)
    buttons.size = Vector2(1280, 60)
    buttons.alignment = BoxContainer.ALIGNMENT_CENTER
    buttons.add_theme_constant_override("separation", 20)
    root.add_child(buttons)

    var raid: Button = _button("RAID THE %s" % away["short"] if user_won else "THE %s RAID YOU" % away["short"], Vector2(340, 60), 22)
    raid.pressed.connect(func() -> void: raid_requested.emit())
    buttons.add_child(raid)

    var menu: Button = _button("MENU", Vector2(140, 60), 18)
    menu.pressed.connect(func() -> void: menu_requested.emit())
    buttons.add_child(menu)

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
    button.add_theme_font_size_override("font_size", font_size)
    return button
