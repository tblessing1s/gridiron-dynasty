extends RefCounted

# Holds the battle mode chosen on the main menu. Accessed through preload so
# it never depends on the autoload or global class caches.

enum Mode { AUTO_RESOLVE, WATCH, PLAY, SIM }

static var mode: int = Mode.SIM

# SIM resolves a down instantly with stat math; when this is on, the field
# plays a short canned animation of that already-decided result before the
# outcome is revealed (scripts/ui/play_replay.gd). Never used in AUTO-RESOLVE
# or for AI-vs-AI battles, which never enter the battle scene at all.
static var replay: bool = true
static var replay_speed: float = 1.0

# The game is play-calling and stats, not a live throw: PLAY/WATCH (the
# real-time QB slingshot, receiver/defender AI) are kept in the codebase and
# stay parse-clean and runnable, but hidden from the menu. Flip this back on
# to bring their buttons back.
const SHOW_REALTIME_MODES: bool = false

static func is_realtime(value: int) -> bool:
    return value == Mode.PLAY or value == Mode.WATCH

static func is_selectable(value: int) -> bool:
    if SHOW_REALTIME_MODES:
        return true
    return not is_realtime(value)

static func mode_name(value: int) -> String:
    if value == Mode.AUTO_RESOLVE:
        return "AUTO-RESOLVE"
    if value == Mode.WATCH:
        return "WATCH"
    if value == Mode.SIM:
        return "SIM"
    return "PLAY"
