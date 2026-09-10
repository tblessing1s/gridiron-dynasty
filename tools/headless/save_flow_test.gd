extends SceneTree

# Scene-flow harness for autosave: start a dynasty from the menu, attack,
# then simulate an app restart (clear in-memory state) and confirm the
# menu loads the save and resumes the pending battle.

const BattleSettings = preload("res://scripts/core/battle_settings.gd")
const SeasonState = preload("res://scripts/core/season_state.gd")
const SaveGame = preload("res://scripts/core/save_game.gd")

var frames: int = 0
var last_scene: String = ""
var phase: int = 0

func _initialize() -> void:
    SaveGame.delete()
    BattleSettings.mode = BattleSettings.Mode.AUTO_RESOLVE
    change_scene_to_file("res://scenes/main.tscn")

func _physics_process(_delta: float) -> bool:
    frames += 1
    if frames > 3000:
        print("TIMEOUT phase ", phase, " scene ", last_scene)
        return true
    var scene: Node = current_scene
    if scene == null:
        return false
    if scene.name != last_scene:
        last_scene = scene.name
        print("[%4d] phase %d scene: %s" % [frames, phase, scene.name])

    if scene.name == "MainMenu":
        if frames < 5:
            return false
        if phase == 0:
            print("   save exists before new dynasty: ", SaveGame.exists())
            scene._on_new_season()
            phase = 1
        elif phase == 2:
            print("   after 'restart': season in memory=", SeasonState.has_season(), " battle pending=", not SeasonState.battle.is_empty(), " summary='", SaveGame.summary(), "'")
            assert(SeasonState.has_season())
            assert(not SeasonState.battle.is_empty())
            scene._on_continue_season()
            phase = 3
        return false

    if scene.name == "SeasonMap":
        if phase == 1:
            var season = SeasonState.season
            var targets: Array[int] = season.adjacent_enemy_territories(0)
            scene._on_tile_pressed(targets[0])
            scene._on_attack_pressed()
            return false
        return false

    if scene.name == "FootballGame":
        if phase == 1:
            print("   battle pending and saved: ", SaveGame.exists(), " summary='", SaveGame.summary(), "'")
            # Simulate the app being closed and reopened.
            SeasonState.clear()
            phase = 2
            change_scene_to_file("res://scenes/main.tscn")
            return false
        if phase == 3:
            print("   resumed battle: season_mode=", scene.season_mode, " opponent=", scene.teams[1]["short"], " matchup visible=", scene.matchup_screen.visible)
            assert(scene.season_mode)
            scene.matchup_screen.auto_requested.emit()
            phase = 4
            return false
        if phase == 4 and scene.aftermath_screen.visible:
            print("   aftermath after resume: week now ", SeasonState.season.week, " saved summary='", SaveGame.summary(), "'")
            assert(SeasonState.season.week == 2)
            SaveGame.delete()
            print("AUTOSAVE FLOW OK")
            return true
    return false
