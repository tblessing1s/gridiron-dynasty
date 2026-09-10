extends RefCounted

# Static holder so the season survives scene changes between the map and
# the battle. `battle` is the user's pending interactive battle, if any.

static var season = null
static var battle: Dictionary = {}

static func has_season() -> bool:
    return season != null

static func clear() -> void:
    season = null
    battle = {}
