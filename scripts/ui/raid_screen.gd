extends CanvasLayer

const PlayerRow = preload("res://scripts/ui/player_row.gd")
const Rosters = preload("res://scripts/core/rosters.gd")
const RaidRules = preload("res://scripts/core/raid_rules.gd")

signal raid_confirmed(take_index: int, give_index: int)
signal play_again_requested
signal menu_requested

const COLUMN_WIDTH: float = 580.0
const ROWS_TOP: float = 100.0

var root: Control
var winner: Dictionary
var loser: Dictionary
var loser_tag: int = -1
var user_is_winner: bool = true
var take_index: int = -1
var give_index: int = -1
var take_overlays: Array = []
var give_overlays: Array = []
var give_rows: Array = []
var summary_label: Label
var confirm_button: Button
var buttons: HBoxContainer
var applied: bool = false
var continue_text: String = "PLAY AGAIN"
var season_number: int = -1

func _ready() -> void:
    layer = 110

func setup(winner_team: Dictionary, loser_team: Dictionary, loser_tag_index: int, user_won: bool, after_text: String, current_season: int) -> void:
    winner = winner_team
    loser = loser_team
    loser_tag = loser_tag_index
    user_is_winner = user_won
    continue_text = after_text
    season_number = current_season
    take_index = -1
    give_index = -1
    applied = false
    take_overlays.clear()
    give_overlays.clear()
    give_rows.clear()

    if root != null:
        root.queue_free()
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root)

    var background: ColorRect = ColorRect.new()
    background.color = Color(0.05, 0.07, 0.09, 0.97)
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(background)

    var title: Label = _label(Vector2(0, 16), Vector2(1280, 40), 30)
    title.text = "YOU WON • TAKE ONE %s PLAYER" % loser["short"] if user_is_winner else "THE %s RAID YOU" % winner["short"]
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root.add_child(title)

    var take_header: Label = _label(Vector2(40, ROWS_TOP - 28.0), Vector2(COLUMN_WIDTH, 24), 15)
    take_header.text = "%s ROSTER • tap to take" % loser["short"] if user_is_winner else "THEY TAKE FROM YOU"
    take_header.modulate = Color(loser["color"].lightened(0.4), 1.0)
    root.add_child(take_header)

    var give_header: Label = _label(Vector2(660, ROWS_TOP - 28.0), Vector2(COLUMN_WIDTH, 24), 15)
    give_header.text = "SEND BACK • same slot" if user_is_winner else "THEY SEND YOU"
    give_header.modulate = Color(winner["color"].lightened(0.4), 1.0)
    root.add_child(give_header)

    var loser_players: Array = loser["players"]
    for i in range(loser_players.size()):
        var protected: bool = not RaidRules.can_take(loser, i, loser_tag, season_number)
        var row: ColorRect = PlayerRow.build(loser_players[i], Rosters.SLOT_TYPES[i], loser["color"], COLUMN_WIDTH, protected)
        row.position = Vector2(40, ROWS_TOP + float(i) * (PlayerRow.HEIGHT + 4.0))
        root.add_child(row)
        if protected:
            PlayerRow.add_chip(row, RaidRules.protection_label(loser, i, loser_tag, season_number), COLUMN_WIDTH - 70.0, Color(1, 0.85, 0.4, 0.9))
        var overlay: ColorRect = _overlay(row)
        take_overlays.append(overlay)
        if user_is_winner and not protected:
            var button: Button = _row_button(row)
            button.pressed.connect(_on_take_pressed.bind(i))

    var winner_players: Array = winner["players"]
    for i in range(winner_players.size()):
        var row: ColorRect = PlayerRow.build(winner_players[i], Rosters.SLOT_TYPES[i], winner["color"], COLUMN_WIDTH, false)
        row.position = Vector2(660, ROWS_TOP + float(i) * (PlayerRow.HEIGHT + 4.0))
        root.add_child(row)
        give_rows.append(row)
        var overlay: ColorRect = _overlay(row)
        give_overlays.append(overlay)
        if user_is_winner:
            var button: Button = _row_button(row)
            button.pressed.connect(_on_give_pressed.bind(i))

    summary_label = _label(Vector2(40, 436), Vector2(1200, 26), 18)
    summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root.add_child(summary_label)

    var note: Label = _label(Vector2(140, 468), Vector2(1000, 48), 14)
    note.text = "Both players arrive with a morale hit (-%d to every stat until the offseason) and grow slower from now on. The franchise tag and first-season rookies cannot be taken." % RaidRules.MORALE_PENALTY
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    note.modulate = Color(1, 1, 1, 0.6)
    root.add_child(note)

    buttons = HBoxContainer.new()
    buttons.position = Vector2(0, 640)
    buttons.size = Vector2(1280, 60)
    buttons.alignment = BoxContainer.ALIGNMENT_CENTER
    buttons.add_theme_constant_override("separation", 20)
    root.add_child(buttons)

    confirm_button = _button("CONFIRM RAID" if user_is_winner else "CONTINUE", Vector2(300, 60), 22)
    confirm_button.pressed.connect(_on_confirm_pressed)
    buttons.add_child(confirm_button)

    var menu: Button = _button("MENU", Vector2(140, 60), 18)
    menu.pressed.connect(func() -> void: menu_requested.emit())
    buttons.add_child(menu)

    if not user_is_winner:
        take_index = RaidRules.ai_take(loser, loser_tag, season_number)
        give_index = RaidRules.ai_send_back(winner, take_index)
    _refresh()

func _on_take_pressed(index: int) -> void:
    if applied:
        return
    take_index = index
    if give_index >= 0 and not RaidRules.same_slot(take_index, give_index):
        give_index = -1
    _refresh()

func _on_give_pressed(index: int) -> void:
    if applied or take_index < 0 or not RaidRules.same_slot(take_index, index):
        return
    give_index = index
    _refresh()

func _on_confirm_pressed() -> void:
    if applied:
        return
    if take_index < 0 or give_index < 0:
        return
    applied = true
    raid_confirmed.emit(take_index, give_index)
    var taken: Dictionary = winner["players"][give_index]
    var given: Dictionary = loser["players"][take_index]
    if user_is_winner:
        summary_label.text = "%s joins the %s. %s heads to the %s." % [taken["name"], winner["short"], given["name"], loser["short"]]
    else:
        summary_label.text = "%s is gone. %s arrives in his place." % [taken["name"], given["name"]]
    confirm_button.visible = false
    var again: Button = _button(continue_text, Vector2(300, 60), 22)
    again.pressed.connect(func() -> void: play_again_requested.emit())
    buttons.add_child(again)
    buttons.move_child(again, 0)

func _refresh() -> void:
    for i in range(take_overlays.size()):
        var overlay: ColorRect = take_overlays[i]
        overlay.visible = i == take_index
    for i in range(give_overlays.size()):
        var overlay: ColorRect = give_overlays[i]
        overlay.visible = i == give_index
        var eligible: bool = take_index >= 0 and RaidRules.same_slot(take_index, i)
        var row: ColorRect = give_rows[i]
        row.modulate = Color(1, 1, 1, 1.0 if eligible or take_index < 0 else 0.35)

    var ready_to_confirm: bool = take_index >= 0 and give_index >= 0
    confirm_button.disabled = not ready_to_confirm
    if applied:
        return
    if take_index < 0:
        summary_label.text = "Pick a player to take."
    elif give_index < 0:
        summary_label.text = "Taking %s (%s). Now pick who goes back: a %s." % [loser["players"][take_index]["name"], Rosters.SLOT_TYPES[take_index], Rosters.SLOT_TYPES[take_index]]
    elif user_is_winner:
        summary_label.text = "Take %s, send back %s." % [loser["players"][take_index]["name"], winner["players"][give_index]["name"]]
    else:
        summary_label.text = "They take %s and send you %s." % [loser["players"][take_index]["name"], winner["players"][give_index]["name"]]

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

func _button(text: String, size: Vector2, font_size: int) -> Button:
    var button: Button = Button.new()
    button.text = text
    button.custom_minimum_size = size
    button.add_theme_font_size_override("font_size", font_size)
    return button
