extends RefCounted

const SCREEN_SIZE: Vector2 = Vector2(1280.0, 720.0)
const FIELD_RECT: Rect2 = Rect2(40.0, 90.0, 1200.0, 600.0)
const LEFT_GOAL_X: float = 140.0
const RIGHT_GOAL_X: float = 1140.0
const FIELD_TOP: float = 100.0
const FIELD_BOTTOM: float = 680.0
const PIXELS_PER_YARD: float = 10.0
const END_ZONE_WIDTH: float = 100.0
const STARTING_LOS_X: float = LEFT_GOAL_X + 200.0
const PLAYER_RADIUS: float = 14.0
const TACKLE_RADIUS: float = 26.0
const CATCH_RADIUS: float = 34.0
const OUT_OF_BOUNDS_MARGIN: float = 12.0
