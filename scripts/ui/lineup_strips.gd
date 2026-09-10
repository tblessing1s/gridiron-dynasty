extends CanvasLayer

const Rosters = preload("res://scripts/core/rosters.gd")
const PlayBook = preload("res://scripts/core/play_book.gd")
const BattleSettings = preload("res://scripts/core/battle_settings.gd")

# Roster view for both sides during the whole battle: the field is idle in
# SIM mode, so use it to keep every player's stats visible instead, with
# cards and results highlighting whoever actually decides the down.

const ROWS: int = 7
const ROW_HEIGHT: float = 48.0
const TOP_Y: float = 190.0
const STRIP_WIDTH: float = 440.0
const LEFT_X: float = 20.0
const RIGHT_X: float = 1280.0 - STRIP_WIDTH - 20.0
const STAT_KEYS: Array[String] = ["speed", "power", "skill", "awareness"]
const STAT_LABELS: Array[String] = ["S", "P", "K", "A"]
const HIGHLIGHT_COLOR: Color = Color(1.0, 0.85, 0.3, 0.24)
const IDLE_COLOR: Color = Color(1, 1, 1, 0.035)

var rows: Array = [[], []]
var teams: Array = [{}, {}]
var highlighted: Array = [[], []]

func _ready() -> void:
    layer = 95
    for side in range(2):
        var x: float = LEFT_X if side == 0 else RIGHT_X
        var side_rows: Array = []
        for i in range(ROWS):
            var bg: ColorRect = ColorRect.new()
            bg.position = Vector2(x, TOP_Y + float(i) * ROW_HEIGHT)
            bg.size = Vector2(STRIP_WIDTH, ROW_HEIGHT - 4.0)
            bg.color = IDLE_COLOR
            add_child(bg)

            var slot_label: Label = _label(Vector2(8, 4), Vector2(34, 20), 13)
            bg.add_child(slot_label)
            var name_label: Label = _label(Vector2(44, 2), Vector2(120, 22), 15)
            bg.add_child(name_label)
            var ovr_label: Label = _label(Vector2(168, 4), Vector2(54, 20), 13)
            ovr_label.modulate = Color(1, 0.85, 0.5, 0.9)
            bg.add_child(ovr_label)
            var stat_label: Label = _label(Vector2(226, 4), Vector2(206, 20), 13)
            stat_label.modulate = Color(1, 1, 1, 0.8)
            bg.add_child(stat_label)
            side_rows.append({"bg": bg, "slot": slot_label, "name": name_label, "ovr": ovr_label, "stats": stat_label})
        rows[side] = side_rows

func _label(pos: Vector2, size: Vector2, font_size: int) -> Label:
    var label: Label = Label.new()
    label.position = pos
    label.size = size
    label.add_theme_font_size_override("font_size", font_size)
    return label

func setup(home: Dictionary, away: Dictionary) -> void:
    teams = [home, away]
    highlighted = [[], []]
    visible = not BattleSettings.is_realtime(BattleSettings.mode)
    set_roles(0)

# offense_team_index is whichever side (0 or 1) currently has the ball;
# each side's row labels switch between its offensive and defensive slots.
func set_roles(offense_team_index: int) -> void:
    for side in range(2):
        _refresh_side(side, side != offense_team_index)
    _refresh_highlight()

func _refresh_side(side: int, is_defense_display: bool) -> void:
    var team: Dictionary = teams[side]
    var players: Array = team.get("players", [])
    var color: Color = team.get("color", Color.WHITE)
    var labels: Array[String] = Rosters.DEFENSE_SLOT_TYPES if is_defense_display else Rosters.SLOT_TYPES
    for i in range(ROWS):
        var row: Dictionary = rows[side][i]
        if i >= players.size():
            continue
        var player: Dictionary = players[i]
        row["slot"].text = labels[i]
        row["slot"].modulate = Color(color.lightened(0.4), 1.0)
        var ov: int = Rosters.overall(player, i)
        row["name"].text = str(player["name"])
        row["ovr"].text = "%d %s" % [ov, Rosters.grade(ov)]
        var chips: PackedStringArray = PackedStringArray()
        for k in range(STAT_KEYS.size()):
            chips.append("%s%d" % [STAT_LABELS[k], int(player[STAT_KEYS[k]])])
        row["stats"].text = "  ".join(chips)

# Which roster slots a card leans on, from the calling side's point of view.
func _card_groups(card: int, is_offense: bool) -> Dictionary:
    if is_offense:
        if card == PlayBook.Offense.DRAW or card == PlayBook.Offense.SCREEN:
            return {"mine": [1], "theirs": [1]}
        if card == PlayBook.Offense.SWEEP:
            return {"mine": [1], "theirs": [1, 2, 3]}
        return {"mine": [0, 2, 3], "theirs": [0, 2, 3]}
    if card == PlayBook.Defense.BLITZ:
        return {"mine": [4, 5, 6], "theirs": [4, 5, 6]}
    if card == PlayBook.Defense.SPY:
        return {"mine": [1], "theirs": [1]}
    return {"mine": [0, 2, 3], "theirs": [0, 2, 3]}

# team_index is the side that called this card; is_offense says whether that
# side is on offense this down.
func highlight_card(team_index: int, card: int, is_offense: bool) -> void:
    var groups: Dictionary = _card_groups(card, is_offense)
    highlighted[team_index] = groups["mine"]
    highlighted[1 - team_index] = groups["theirs"]
    _refresh_highlight()

func highlight_players(team_index: int, indices: Array) -> void:
    highlighted[team_index] = indices.duplicate()
    _refresh_highlight()

func clear_highlight() -> void:
    highlighted = [[], []]
    _refresh_highlight()

func _refresh_highlight() -> void:
    for side in range(2):
        var picked: Array = highlighted[side]
        for i in range(ROWS):
            var bg: ColorRect = rows[side][i]["bg"]
            bg.color = HIGHLIGHT_COLOR if picked.has(i) else IDLE_COLOR
