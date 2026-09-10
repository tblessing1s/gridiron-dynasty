extends RefCounted

# Builds the one-line player card used by the matchup, aftermath, and raid
# screens: slot, name, and four labeled stat bars in the team color.

const STAT_KEYS: Array[String] = ["speed", "power", "skill", "awareness"]
const STAT_LABELS: Array[String] = ["SPD", "PWR", "SKL", "AWR"]
const HEIGHT: float = 42.0
const STATS_X: float = 190.0
const STAT_SPACING: float = 84.0

const Rosters = preload("res://scripts/core/rosters.gd")

# overall_type names the player's offensive slot (QB/RB/WR/BL) for the
# slot-weighted overall shown in the header, independent of which side's
# label (e.g. "S", "CB") is on display; empty falls back to using slot.
static func build(player: Dictionary, slot: String, color: Color, width: float, dim: bool = false, overall_type: String = "") -> ColorRect:
    var row: ColorRect = ColorRect.new()
    row.color = Color(1, 1, 1, 0.03 if dim else 0.06)
    row.size = Vector2(width, HEIGHT)
    var alpha: float = 0.4 if dim else 1.0

    var slot_label: Label = _label(Vector2(10, 10), Vector2(44, 22), 14)
    slot_label.text = slot
    slot_label.modulate = Color(color.lightened(0.4), alpha)
    row.add_child(slot_label)

    var name_label: Label = _label(Vector2(56, 8), Vector2(88, 26), 17)
    name_label.text = str(player["name"])
    name_label.modulate = Color(1, 1, 1, alpha)
    row.add_child(name_label)

    var ov: int = Rosters.overall_for_type(player, overall_type if not overall_type.is_empty() else slot)
    var ovr_label: Label = _label(Vector2(147, 11), Vector2(40, 20), 13)
    ovr_label.text = "%d %s" % [ov, Rosters.grade(ov)]
    ovr_label.modulate = Color(1, 0.85, 0.5, 0.9 * alpha)
    row.add_child(ovr_label)

    for k in range(STAT_KEYS.size()):
        var stat_x: float = STATS_X + float(k) * STAT_SPACING
        var value: int = int(player[STAT_KEYS[k]])
        var stat_label: Label = _label(Vector2(stat_x, 2), Vector2(70, 18), 12)
        stat_label.text = "%s %d" % [STAT_LABELS[k], value]
        stat_label.modulate = Color(1, 1, 1, 0.75 * alpha)
        row.add_child(stat_label)

        var track: ColorRect = ColorRect.new()
        track.color = Color(0, 0, 0, 0.45)
        track.position = Vector2(stat_x, 23)
        track.size = Vector2(72, 9)
        row.add_child(track)

        var fill: ColorRect = ColorRect.new()
        fill.color = Color(color.lightened(0.2), alpha)
        fill.position = Vector2(stat_x, 23)
        fill.size = Vector2(72.0 * float(value) / 100.0, 9)
        row.add_child(fill)

    return row

static func add_chip(row: Control, text: String, x: float, tint: Color = Color(1, 1, 1, 0.85)) -> Label:
    var chip: Label = _label(Vector2(x, 11), Vector2(90, 20), 13)
    chip.text = text
    chip.modulate = tint
    row.add_child(chip)
    return chip

static func overall(player: Dictionary) -> int:
    var total: int = 0
    for key in STAT_KEYS:
        total += int(player[key])
    return int(round(float(total) / float(STAT_KEYS.size())))

static func _label(pos: Vector2, size: Vector2, font_size: int) -> Label:
    var label: Label = Label.new()
    label.position = pos
    label.size = size
    label.add_theme_font_size_override("font_size", font_size)
    return label
