extends RefCounted

# Holds the battle mode chosen on the main menu. Accessed through preload so
# it never depends on the autoload or global class caches.

enum Mode { AUTO_RESOLVE, WATCH, PLAY, SIM }

static var mode: int = Mode.SIM

static func mode_name(value: int) -> String:
    if value == Mode.AUTO_RESOLVE:
        return "AUTO-RESOLVE"
    if value == Mode.WATCH:
        return "WATCH"
    if value == Mode.SIM:
        return "SIM"
    return "PLAY"
