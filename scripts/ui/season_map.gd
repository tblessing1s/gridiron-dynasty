extends Node2D

const SeasonScript = preload("res://scripts/core/season.gd")
const SeasonState = preload("res://scripts/core/season_state.gd")
const SaveGame = preload("res://scripts/core/save_game.gd")
const Rosters = preload("res://scripts/core/rosters.gd")
const PlayerRow = preload("res://scripts/ui/player_row.gd")

const MAP_ORIGIN: Vector2 = Vector2(30.0, 96.0)
const CELL: Vector2 = Vector2(160.0, 125.0)
const TILE_INSET: float = 5.0
const PANEL_X: float = 1010.0
const PANEL_WIDTH: float = 250.0

var season
var selected_target: int = -1
var info_target: int = -1
var attackable: Array[int] = []

var ui: CanvasLayer
var week_label: Label
var empire_label: Label
var target_label: Label
var log_label: Label
var standings_label: Label
var attack_button: Button
var rest_button: Button
var roster_panel: Control
var summary_panel: Control
var summary_title: Label
var summary_body: Label

func _ready() -> void:
    if SeasonState.season == null:
        SeasonState.season = SeasonScript.new()
    season = SeasonState.season
    if not SeasonState.battle.is_empty():
        # A battle was pending when the player left; resume it.
        get_tree().change_scene_to_file.call_deferred("res://scenes/game.tscn")
        return
    _build_ui()
    _refresh()

# ---------------------------------------------------------------- drawing

func _tile_rect(t: Dictionary) -> Rect2:
    var origin: Vector2 = MAP_ORIGIN + Vector2(float(t["column"]) * CELL.x, float(t["row"]) * CELL.y) + Vector2(TILE_INSET, TILE_INSET)
    return Rect2(origin, CELL - Vector2(TILE_INSET, TILE_INSET) * 2.0)

func _draw() -> void:
    draw_rect(Rect2(MAP_ORIGIN - Vector2(8, 8), Vector2(CELL.x * float(season.COLUMNS), CELL.y * float(season.ROWS)) + Vector2(16, 16)), Color(0.08, 0.1, 0.12, 1.0), true)
    var font: Font = ThemeDB.fallback_font
    for t in season.territories:
        var rect: Rect2 = _tile_rect(t)
        var owner: Dictionary = season.empire(int(t["owner_id"]))
        var color: Color = owner["color"]
        var is_user: bool = int(t["owner_id"]) == season.USER_EMPIRE
        draw_rect(rect, color.darkened(0.25), true)
        draw_rect(rect, Color(0, 0, 0, 0.55), false, 2.0)
        if attackable.has(int(t["id"])):
            draw_rect(rect.grow(-2.0), Color(1, 1, 1, 0.75), false, 2.0)
        if int(t["id"]) == selected_target:
            draw_rect(rect.grow(1.0), Color("ffd84d"), false, 4.0)
        elif int(t["id"]) == info_target:
            draw_rect(rect.grow(1.0), Color(1, 1, 1, 0.5), false, 3.0)
        if is_user:
            draw_rect(Rect2(rect.position, Vector2(rect.size.x, 5.0)), Color.WHITE, true)

        if bool(t["is_capital"]):
            draw_circle(rect.position + Vector2(rect.size.x - 16.0, 16.0), 7.0, Color.WHITE)
            draw_circle(rect.position + Vector2(rect.size.x - 16.0, 16.0), 4.0, color)

        draw_string(font, rect.position + Vector2(10.0, 26.0), str(t["name"]), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 32.0, 15, Color.WHITE)
        draw_string(font, rect.position + Vector2(10.0, 50.0), str(owner["short"]), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20.0, 13, Color(1, 1, 1, 0.85))
        draw_string(font, rect.position + Vector2(10.0, rect.size.y - 12.0), str(t["resource"]), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20.0, 12, Color(1, 1, 1, 0.55))

func _unhandled_input(event: InputEvent) -> void:
    if roster_panel != null and roster_panel.visible:
        return
    if summary_panel != null and summary_panel.visible:
        return
    var pressed_at: Vector2 = Vector2(-1, -1)
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        pressed_at = event.position
    elif event is InputEventScreenTouch and event.pressed:
        pressed_at = event.position
    if pressed_at.x < 0.0:
        return
    for t in season.territories:
        if _tile_rect(t).has_point(pressed_at):
            _on_tile_pressed(int(t["id"]))
            return

func _on_tile_pressed(territory_id: int) -> void:
    if attackable.has(territory_id):
        selected_target = territory_id
        info_target = -1
    else:
        selected_target = -1
        info_target = territory_id
    _refresh()

# ---------------------------------------------------------------- UI

func _build_ui() -> void:
    ui = CanvasLayer.new()
    ui.layer = 100
    add_child(ui)

    var top_bar: ColorRect = ColorRect.new()
    top_bar.color = Color(0.03, 0.04, 0.05, 0.93)
    top_bar.size = Vector2(1280, 80)
    ui.add_child(top_bar)

    var title: Label = _label(Vector2(30, 14), Vector2(400, 50), 30)
    title.text = "SEASON MAP"
    ui.add_child(title)

    week_label = _label(Vector2(440, 20), Vector2(400, 40), 24)
    week_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ui.add_child(week_label)

    empire_label = _label(Vector2(860, 14), Vector2(392, 52), 16)
    empire_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    empire_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    ui.add_child(empire_label)

    var panel: ColorRect = ColorRect.new()
    panel.color = Color(0.03, 0.04, 0.05, 0.85)
    panel.position = Vector2(PANEL_X, MAP_ORIGIN.y - 8.0)
    panel.size = Vector2(PANEL_WIDTH, 516)
    ui.add_child(panel)

    target_label = _label(Vector2(12, 12), Vector2(PANEL_WIDTH - 24.0, 190), 15)
    target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    panel.add_child(target_label)

    attack_button = _button("ATTACK", Vector2(12, 210), Vector2(PANEL_WIDTH - 24.0, 48), 18)
    attack_button.pressed.connect(_on_attack_pressed)
    panel.add_child(attack_button)

    rest_button = _button("REST THIS WEEK", Vector2(12, 266), Vector2(PANEL_WIDTH - 24.0, 44), 16)
    rest_button.pressed.connect(_on_rest_pressed)
    panel.add_child(rest_button)

    var roster_button: Button = _button("ROSTER", Vector2(12, 318), Vector2(112, 40), 15)
    roster_button.pressed.connect(func() -> void: _show_roster())
    panel.add_child(roster_button)

    var menu_button: Button = _button("MENU", Vector2(126, 318), Vector2(112, 40), 15)
    menu_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main.tscn"))
    panel.add_child(menu_button)

    standings_label = _label(Vector2(12, 370), Vector2(PANEL_WIDTH - 24.0, 140), 12)
    standings_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    standings_label.modulate = Color(1, 1, 1, 0.8)
    panel.add_child(standings_label)

    var log_bar: ColorRect = ColorRect.new()
    log_bar.color = Color(0.03, 0.04, 0.05, 0.85)
    log_bar.position = Vector2(30, 606)
    log_bar.size = Vector2(980, 106)
    ui.add_child(log_bar)

    log_label = _label(Vector2(12, 6), Vector2(956, 96), 14)
    log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    log_bar.add_child(log_label)

    roster_panel = _overlay()
    ui.add_child(roster_panel)

    summary_panel = _overlay()
    ui.add_child(summary_panel)

func _overlay() -> Control:
    var overlay: ColorRect = ColorRect.new()
    overlay.color = Color(0.03, 0.04, 0.05, 0.96)
    overlay.position = Vector2(180, 60)
    overlay.size = Vector2(920, 600)
    overlay.visible = false
    return overlay

func _show_roster() -> void:
    for child in roster_panel.get_children():
        child.queue_free()
    var team: Dictionary = season.user()
    var header: Label = _label(Vector2(24, 16), Vector2(700, 30), 20)
    header.text = "%s • roster %d • tag: %s" % [team["name"], Rosters.team_overall(team), _tag_name(team)]
    roster_panel.add_child(header)
    var players: Array = team["players"]
    for i in range(players.size()):
        var row: ColorRect = PlayerRow.build(players[i], Rosters.SLOT_TYPES[i], team["color"], 872.0, false)
        row.position = Vector2(24, 60 + float(i) * 48.0)
        roster_panel.add_child(row)
        PlayerRow.add_chip(row, "AGE %d" % int(players[i].get("age", 0)), 540.0)
        var origin: String = str(players[i].get("origin", ""))
        if int(players[i].get("rookie_season", -1)) == season.number:
            origin = "ROOKIE • protected"
        elif origin == "raided":
            origin = "raided • grows slower"
        elif origin == "original":
            origin = ""
        if not origin.is_empty():
            PlayerRow.add_chip(row, origin, 630.0, Color(1, 0.85, 0.4, 0.9))
    var close: Button = _button("CLOSE", Vector2(360, 420), Vector2(200, 48), 18)
    close.pressed.connect(func() -> void: roster_panel.visible = false)
    roster_panel.add_child(close)
    roster_panel.visible = true

func _show_summary() -> void:
    for child in summary_panel.get_children():
        child.queue_free()
    var winner: Dictionary = season.empire(season.winner_id)
    summary_title = _label(Vector2(24, 20), Vector2(872, 44), 32)
    summary_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    summary_title.text = "SEASON OVER — %s WIN THE MAP" % winner["short"]
    summary_title.modulate = Color(winner["color"].lightened(0.4), 1.0)
    summary_panel.add_child(summary_title)

    var place: int = 1
    var lines: PackedStringArray = PackedStringArray()
    for row in season.standings():
        var marker: String = "  (you)" if int(row["id"]) == season.USER_EMPIRE else ""
        var status: String = "eliminated" if bool(row["eliminated"]) else "%d territories" % int(row["territories"])
        lines.append("%d. %s — %s%s" % [place, row["short"], status, marker])
        place += 1
    summary_body = _label(Vector2(60, 80), Vector2(800, 400), 16)
    summary_body.text = "\n".join(lines)
    summary_panel.add_child(summary_body)

    var again: Button = _button("OFFSEASON", Vector2(250, 520), Vector2(200, 48), 18)
    again.pressed.connect(_on_offseason)
    summary_panel.add_child(again)
    var menu: Button = _button("MENU", Vector2(470, 520), Vector2(200, 48), 18)
    menu.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main.tscn"))
    summary_panel.add_child(menu)
    summary_panel.visible = true

func _refresh() -> void:
    var user_team: Dictionary = season.user()
    attackable.clear()
    if not season.over and not season.user_eliminated():
        attackable = season.adjacent_enemy_territories(season.USER_EMPIRE)
    if selected_target >= 0 and not attackable.has(selected_target):
        selected_target = -1

    week_label.text = "SEASON %d  •  WEEK %d of %d" % [season.number, mini(season.week, season.MAX_WEEKS), season.MAX_WEEKS]
    empire_label.text = "%s • %d territories • roster %d" % [user_team["name"], season.owned_by(season.USER_EMPIRE).size(), Rosters.team_overall(user_team)]
    target_label.text = _target_text()
    attack_button.visible = not season.user_eliminated() and not season.over
    attack_button.disabled = selected_target < 0
    attack_button.text = "ATTACK %s" % season.territory(selected_target)["name"] if selected_target >= 0 else "ATTACK"
    rest_button.text = "SIM WEEK" if season.user_eliminated() else "REST THIS WEEK"
    rest_button.visible = not season.over
    log_label.text = "\n".join(PackedStringArray(season.log)) if not season.log.is_empty() else "Pick an enemy territory next to yours (white outline) and attack, or rest to recover."

    var lines: PackedStringArray = PackedStringArray()
    for row in season.standings():
        if bool(row["eliminated"]):
            continue
        lines.append("%s %d" % [row["short"], int(row["territories"])])
    standings_label.text = "STANDINGS\n" + "  •  ".join(lines)

    if season.over:
        _show_summary()
    queue_redraw()

func _target_text() -> String:
    if selected_target >= 0:
        var t: Dictionary = season.territory(selected_target)
        var owner: Dictionary = season.empire(int(t["owner_id"]))
        var origin: int = season.attack_origin(season.USER_EMPIRE, selected_target)
        var lines: PackedStringArray = PackedStringArray()
        lines.append("%s (%s)" % [t["name"], t["resource"]])
        lines.append("Held by %s • roster %d" % [owner["short"], Rosters.team_overall(owner)])
        if bool(t["is_capital"]):
            lines.append("CAPITAL — take it and %s are eliminated." % owner["short"])
        if origin >= 0:
            if bool(season.territory(origin)["is_capital"]):
                lines.append("You attack from %s, your capital. A loss costs you the raid only." % season.territory(origin)["name"])
            else:
                lines.append("You attack from %s. Lose and they take it." % season.territory(origin)["name"])
        return "\n".join(lines)
    if info_target >= 0:
        var t: Dictionary = season.territory(info_target)
        var owner: Dictionary = season.empire(int(t["owner_id"]))
        if int(t["owner_id"]) == season.USER_EMPIRE:
            return "%s (%s)\nYours%s." % [t["name"], t["resource"], " — your capital" if bool(t["is_capital"]) else ""]
        return "%s (%s)\nHeld by %s • roster %d\nNot adjacent to your land." % [t["name"], t["resource"], owner["short"], Rosters.team_overall(owner)]
    if season.user_eliminated():
        return "You are out of the season. Sim the remaining weeks to see who wins."
    return "Tap an enemy territory with a white outline to plan an attack."

func _tag_name(team: Dictionary) -> String:
    var tag: int = int(team.get("tag_index", -1))
    if tag < 0:
        return "none yet"
    return str(team["players"][tag]["name"])

# ---------------------------------------------------------------- actions

func _on_attack_pressed() -> void:
    if selected_target < 0:
        return
    season.plan_week(selected_target)
    _launch_or_resolve()

func _on_rest_pressed() -> void:
    season.plan_week(-1)
    _launch_or_resolve()

func _launch_or_resolve() -> void:
    selected_target = -1
    info_target = -1
    if season.has_user_battle():
        SeasonState.battle = season.user_battle.duplicate()
        SaveGame.save()
        get_tree().change_scene_to_file("res://scenes/game.tscn")
        return
    season.resolve_week_without_user()
    SaveGame.save()
    _refresh()

func _on_offseason() -> void:
    SeasonState.battle = {}
    get_tree().change_scene_to_file("res://scenes/offseason.tscn")

# ---------------------------------------------------------------- helpers

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
