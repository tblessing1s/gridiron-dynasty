extends RefCounted

# Holds the battle mode chosen on the main menu. Accessed through preload so
# it never depends on the autoload or global class caches.

enum Mode { AUTO_RESOLVE, WATCH, PLAY }

static var mode: int = Mode.PLAY

static func mode_name(value: int) -> String:
    if value == Mode.AUTO_RESOLVE:
        return "AUTO-RESOLVE"
    if value == Mode.WATCH:
        return "WATCH"
    return "PLAY"
