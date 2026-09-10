extends RefCounted

const SeasonState = preload("res://scripts/core/season_state.gd")
const SeasonScript = preload("res://scripts/core/season.gd")
const OffseasonScript = preload("res://scripts/core/offseason.gd")
const BattleSettings = preload("res://scripts/core/battle_settings.gd")
const Rosters = preload("res://scripts/core/rosters.gd")

# One JSON file holds the whole dynasty: the season, a battle left pending,
# an offseason in progress, and the battle mode. JSON turns every number
# into a float and every dictionary key into a string, so loading walks
# the known shapes and puts the ints back.

const SAVE_PATH: String = "user://dynasty.json"
const VERSION: int = 1

static func exists() -> bool:
    return FileAccess.file_exists(SAVE_PATH)

static func delete() -> void:
    if exists():
        DirAccess.remove_absolute(SAVE_PATH)

static func save() -> bool:
    if SeasonState.season == null:
        return false
    var data: Dictionary = {
        "version": VERSION,
        "mode": BattleSettings.mode,
        "replay": BattleSettings.replay,
        "replay_speed": BattleSettings.replay_speed,
        "season": SeasonState.season.to_dict(),
        "battle": SeasonState.battle.duplicate(true),
        "offseason": SeasonState.offseason.to_dict() if SeasonState.offseason != null else null,
    }
    var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        push_warning("Could not write %s: %s" % [SAVE_PATH, error_string(FileAccess.get_open_error())])
        return false
    file.store_string(JSON.stringify(data))
    file.close()
    return true

static func load_dynasty() -> bool:
    if not exists():
        return false
    var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return false
    var text: String = file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(text)
    if not (parsed is Dictionary):
        push_warning("Save file is not readable; ignoring it.")
        return false
    var data: Dictionary = parsed
    if int(data.get("version", 0)) != VERSION or not data.has("season"):
        push_warning("Save file is from another version; ignoring it.")
        return false

    var season = SeasonScript.new()
    season.restore(data["season"])
    SeasonState.season = season
    SeasonState.battle = int_dict(data.get("battle", {}))
    SeasonState.offseason = null
    var offseason_data: Variant = data.get("offseason")
    if offseason_data is Dictionary:
        var offseason = OffseasonScript.new(season, false)
        offseason.restore(offseason_data)
        SeasonState.offseason = offseason
    BattleSettings.mode = int(data.get("mode", BattleSettings.mode))
    BattleSettings.replay = bool(data.get("replay", BattleSettings.replay))
    BattleSettings.replay_speed = float(data.get("replay_speed", BattleSettings.replay_speed))
    return true

# Short description for the menu: "Season 2, week 5" / "Season 1 offseason".
static func summary() -> String:
    if not exists():
        return ""
    var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return ""
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if not (parsed is Dictionary) or not parsed.has("season"):
        return ""
    var season_data: Dictionary = parsed["season"]
    var number: int = int(season_data.get("number", 1))
    if parsed.get("offseason") is Dictionary or bool(season_data.get("over", false)):
        return "Season %d offseason" % number
    return "Season %d, week %d" % [number, int(season_data.get("week", 1))]

# ---------------------------------------------------------------- normalizers

static func int_array(value: Variant) -> Array[int]:
    var result: Array[int] = []
    if value is Array:
        for item in value:
            result.append(int(item))
    return result

static func int_dict(value: Variant) -> Dictionary:
    var result: Dictionary = {}
    if value is Dictionary:
        for key in value.keys():
            result[key] = int(value[key])
    return result

static func normalize_player(player: Dictionary) -> Dictionary:
    for key in Rosters.STAT_KEYS:
        player[key] = int(player.get(key, 50))
    if player.has("age"):
        player["age"] = int(player["age"])
    if player.has("potential") and player["potential"] is Dictionary:
        var potential: Dictionary = player["potential"]
        for key in potential.keys():
            potential[key] = int(potential[key])
    for key in ["rookie_season", "morale"]:
        if player.has(key):
            player[key] = int(player[key])
    if player.has("loyalty"):
        player["loyalty"] = float(player["loyalty"])
    return player

static func normalize_players(players: Variant) -> Array:
    var result: Array = []
    if players is Array:
        for player in players:
            if player is Dictionary:
                result.append(normalize_player(player))
    return result
