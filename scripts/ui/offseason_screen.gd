extends Control

const SeasonState = preload("res://scripts/core/season_state.gd")
const SaveGame = preload("res://scripts/core/save_game.gd")
const OffseasonScript = preload("res://scripts/core/offseason.gd")
const Rosters = preload("res://scripts/core/rosters.gd")
const PlayerRow = preload("res://scripts/ui/player_row.gd")

const STAT_SHORT: Dictionary = {"speed": "SPD", "power": "PWR", "skill": "SKL", "awareness": "AWR"}

enum Step { AGING, DRAFT, DONE }

var offseason
var step: int = Step.AGING
var page: Control
var chosen_rookie: int = -1
var chosen_cut: int = -1
var rookie_overlays: Array = []
var cut_overlays: Array = []
var confirm_button: Button
var summary_label: Label

func _ready() -> void:
    if SeasonState.offseason == null:
        if SeasonState.season == null or not SeasonState.season.over:
            get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
            return
        SeasonState.offseason = OffseasonScript.new(SeasonState.season)
        SaveGame.save()
    offseason = SeasonState.offseason
    var background: ColorRect = ColorRect.new()
    background.color = Color(0.05, 0.07, 0.09, 1.0)
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)
    _show_step()

func _show_step() -> void:
    if page != null:
        page.queue_free()
    page = Control.new()
    page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(page)

    var title: Label = _label(Vector2(0, 14), Vector2(1280, 44), 32)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var champion: Dictionary = offseason.previous.empire(offseason.previous.winner_id)
    title.text = "OFFSEASON  •  season %d won by the %s  •  season %d ahead" % [offseason.previous.number, champion["short"], offseason.next_number]
    page.add_child(title)

    var steps: Label = _label(Vector2(0, 56), Vector2(1280, 24), 15)
    steps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    steps.modulate = Color(1, 1, 1, 0.6)
    steps.text = "1 AGING  →  2 DRAFT  →  3 NEW MAP" if step == Step.AGING else ("1 aging  →  2 DRAFT  →  3 new map" if step == Step.DRAFT else "1 aging  →  2 draft  →  3 NEW MAP")
    page.add_child(steps)

    if step == Step.AGING:
        _build_aging()
    elif step == Step.DRAFT:
        _build_draft()
    else:
        _build_done()

# ---------------------------------------------------------------- aging

func _build_aging() -> void:
    var team: Dictionary = offseason.previous.user()
    var reports: Array = offseason.aging[offseason.previous.USER_EMPIRE]
    var header: Label = _label(Vector2(60, 92), Vector2(1160, 26), 16)
    header.text = "YOUR SEVEN, ONE YEAR OLDER  •  morale hits cleared  •  %d retirements across the league" % offseason.league_retirements
    header.modulate = Color(1, 1, 1, 0.7)
    page.add_child(header)

    var players: Array = team["players"]
    for i in range(players.size()):
        var report: Dictionary = reports[i]
        var retired: bool = bool(report["retired"])
        var row: ColorRect = PlayerRow.build(players[i], Rosters.SLOT_TYPES[i], team["color"], 1160.0, false)
        row.position = Vector2(60, 124 + float(i) * 50.0)
        page.add_child(row)
        PlayerRow.add_chip(row, "AGE %d" % int(players[i]["age"]), 540.0)
        if retired:
            PlayerRow.add_chip(row, "%s RETIRED at %d  →  %s signs" % [report["name"], int(report["age"]), report["replacement"]], 630.0, Color(1, 0.85, 0.4, 0.95))
        else:
            var changes: Dictionary = report["changes"]
            var chips: PackedStringArray = PackedStringArray()
            for key in changes.keys():
                chips.append("%+d %s" % [int(changes[key]), STAT_SHORT[key]])
            var text: String = "   ".join(chips) if not chips.is_empty() else "no change"
            var tint: Color = Color(0.6, 1.0, 0.6, 0.95) if _net(changes) > 0 else (Color(1.0, 0.6, 0.6, 0.95) if _net(changes) < 0 else Color(1, 1, 1, 0.6))
            PlayerRow.add_chip(row, text, 630.0, tint)

    var next: Button = _button("TO THE DRAFT", Vector2(490, 560), Vector2(300, 56), 22)
    next.pressed.connect(func() -> void:
        step = Step.DRAFT
        offseason.run_ai_picks_until_user()
        _show_step())
    page.add_child(next)

func _net(changes: Dictionary) -> int:
    var total: int = 0
    for key in changes.keys():
        total += int(changes[key])
    return total

# ---------------------------------------------------------------- draft

func _build_draft() -> void:
    chosen_rookie = -1
    chosen_cut = -1
    rookie_overlays.clear()
    cut_overlays.clear()
    var user_id: int = offseason.previous.USER_EMPIRE

    var order_header: Label = _label(Vector2(40, 92), Vector2(380, 24), 15)
    order_header.text = "DRAFT ORDER  •  first out picks first"
    order_header.modulate = Color(1, 1, 1, 0.7)
    page.add_child(order_header)

    var lines: PackedStringArray = PackedStringArray()
    for i in range(offseason.order.size()):
        var empire_id: int = offseason.order[i]
        var short: String = str(offseason.previous.empire(empire_id)["short"])
        var marker: String = " (you)" if empire_id == user_id else ""
        if i < offseason.picks.size():
            var pick: Dictionary = offseason.picks[i]
            lines.append("%2d. %s%s — %s (%s %s), cuts %s" % [i + 1, short, marker, pick["rookie"]["name"], pick["rookie"]["slot_type"], pick["rookie"]["grade"], pick["cut_name"]])
        elif i == offseason.pick_cursor:
            lines.append("%2d. %s%s — ON THE CLOCK" % [i + 1, short, marker])
        else:
            lines.append("%2d. %s%s" % [i + 1, short, marker])
    var order_label: Label = _label(Vector2(40, 118), Vector2(400, 480), 13)
    order_label.text = "\n".join(lines)
    page.add_child(order_label)

    var class_header: Label = _label(Vector2(460, 92), Vector2(780, 24), 15)
    class_header.modulate = Color(1, 1, 1, 0.7)
    page.add_child(class_header)

    if offseason.draft_done():
        class_header.text = "DRAFT COMPLETE"
        var next: Button = _button("NEW MAP", Vector2(720, 560), Vector2(260, 56), 22)
        next.pressed.connect(func() -> void:
            step = Step.DONE
            _show_step())
        page.add_child(next)
        return

    class_header.text = "YOU ARE ON THE CLOCK  •  tap a rookie, then choose who he replaces at that slot"
    var rows_shown: int = mini(offseason.draft_class.size(), 9)
    for i in range(rows_shown):
        var rookie: Dictionary = offseason.draft_class[i]
        var row: ColorRect = PlayerRow.build(rookie, str(rookie["slot_type"]), Color("d4a017"), 780.0, false)
        row.position = Vector2(460, 118 + float(i) * 46.0)
        page.add_child(row)
        PlayerRow.add_chip(row, "AGE %d" % int(rookie["age"]), 540.0)
        PlayerRow.add_chip(row, "SCOUT %s" % rookie["grade"], 640.0, Color(1, 0.85, 0.4, 0.95))
        rookie_overlays.append(_overlay(row))
        var button: Button = _row_button(row)
        button.pressed.connect(_on_rookie_pressed.bind(i))

    summary_label = _label(Vector2(460, 540), Vector2(780, 24), 16)
    summary_label.text = "Pick a rookie."
    page.add_child(summary_label)

    confirm_button = _button("CONFIRM PICK", Vector2(720, 580), Vector2(260, 52), 20)
    confirm_button.disabled = true
    confirm_button.pressed.connect(_on_confirm_pick)
    page.add_child(confirm_button)

func _on_rookie_pressed(index: int) -> void:
    chosen_rookie = index
    chosen_cut = -1
    for i in range(rookie_overlays.size()):
        rookie_overlays[i].visible = i == index
    _build_cut_panel()

func _build_cut_panel() -> void:
    for overlay in cut_overlays:
        if is_instance_valid(overlay) and overlay.get_parent() != null:
            overlay.get_parent().queue_free()
    cut_overlays.clear()
    var rookie: Dictionary = offseason.draft_class[chosen_rookie]
    var team: Dictionary = offseason.previous.user()
    var cuts: Array[int] = offseason.eligible_cuts(offseason.previous.USER_EMPIRE, rookie)
    var y: float = 118.0 + 9.0 * 46.0 + 4.0
    var header: Label = _label(Vector2(460, y - 24.0), Vector2(780, 22), 14)
    header.text = "%s replaces one of your %ss:" % [rookie["name"], rookie["slot_type"]]
    header.modulate = Color(1, 1, 1, 0.7)
    page.add_child(header)
    cut_overlays.append(_overlay(header))
    for k in range(cuts.size()):
        var index: int = cuts[k]
        var row: ColorRect = PlayerRow.build(team["players"][index], Rosters.SLOT_TYPES[index], team["color"], 250.0, false)
        row.position = Vector2(460 + float(k) * 262.0, y)
        row.size = Vector2(250.0, PlayerRow.HEIGHT)
        page.add_child(row)
        PlayerRow.add_chip(row, "AGE %d" % int(team["players"][index]["age"]), 150.0)
        cut_overlays.append(_overlay(row))
        var button: Button = _row_button(row)
        button.pressed.connect(_on_cut_pressed.bind(index, k + 1))
    summary_label.text = "Taking %s (%s, scout %s). Now choose who goes." % [rookie["name"], rookie["slot_type"], rookie["grade"]]
    confirm_button.disabled = true

func _on_cut_pressed(index: int, overlay_slot: int) -> void:
    chosen_cut = index
    for i in range(1, cut_overlays.size()):
        cut_overlays[i].visible = i == overlay_slot
    var team: Dictionary = offseason.previous.user()
    summary_label.text = "Take %s, release %s." % [offseason.draft_class[chosen_rookie]["name"], team["players"][index]["name"]]
    confirm_button.disabled = false

func _on_confirm_pick() -> void:
    if chosen_rookie < 0 or chosen_cut < 0:
        return
    offseason.user_pick(chosen_rookie, chosen_cut)
    offseason.run_remaining_ai_picks()
    SaveGame.save()
    _show_step()

# ---------------------------------------------------------------- done

func _build_done() -> void:
    var team: Dictionary = offseason.previous.user()
    var rookie_name: String = "no pick"
    for pick in offseason.picks:
        if int(pick["empire_id"]) == offseason.previous.USER_EMPIRE:
            rookie_name = "%s (%s, scout %s) — protected from raids all season" % [pick["rookie"]["name"], pick["rookie"]["slot_type"], pick["rookie"]["grade"]]
    var body: Label = _label(Vector2(140, 110), Vector2(1000, 300), 18)
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.text = "Season %d starts on a fresh map. Every empire is back at its capital and outer territory, eliminated ones included. Rosters carry over: XP earned, raids made, and the draft.\n\nYour rookie: %s.\nYour roster now averages %d. Franchise tags reset; set yours on the first matchup screen.\n\nStill to come: territory resources, contracts, save/load." % [offseason.next_number, rookie_name, Rosters.team_overall(team)]
    page.add_child(body)

    var start: Button = _button("START SEASON %d" % offseason.next_number, Vector2(490, 560), Vector2(300, 56), 22)
    start.pressed.connect(_on_start_season)
    page.add_child(start)

func _on_start_season() -> void:
    SeasonState.season = offseason.build_next_season()
    SeasonState.offseason = null
    SeasonState.battle = {}
    SaveGame.save()
    get_tree().change_scene_to_file("res://scenes/map.tscn")

# ---------------------------------------------------------------- helpers

func _overlay(row: Control) -> ColorRect:
    var overlay: ColorRect = ColorRect.new()
    overlay.color = Color(1, 1, 1, 0.16)
    overlay.size = row.size
    overlay.visible = false
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(overlay)
    return overlay

func _row_button(row: Control) -> Button:
    var button: Button = Button.new()
    button.flat = true
    button.size = row.size
    button.focus_mode = Control.FOCUS_NONE
    row.add_child(button)
    return button

func _label(pos: Vector2, size: Vector2, font_size: int) -> Label:
    var label: Label = Label.new()
    label.position = pos
    label.size = size
    label.add_theme_font_size_override("font_size", font_size)
    return label

func _button(text: String, pos: Vector2, size: Vector2, font_size: int) -> Button:
    var button: Button = Button.new()
    button.text = text
    button.position = pos
    button.size = size
    button.add_theme_font_size_override("font_size", font_size)
    return button
