class_name ArenaRules
extends RefCounted
## Shared, presentation-free arena tuning and geometry.

const ARENA_SIZE := Vector2(2857.14, 1942.86)
const MAX_HEALTH := 100
const PLAYER_RADIUS := 40.0
const SPEED_MULTIPLIER := 1.5
const MOVE_SPEED := 465.0 * SPEED_MULTIPLIER
const DASH_SPEED := 1245.0 * SPEED_MULTIPLIER
const DASH_DURATION := 0.20
const MAX_MOVEMENT_STEP := 20.0
const MOVE_ACCELERATION := 10.0
const MOVE_GLIDE_DECELERATION := 6.0
const PROJECTILE_BOUNCES := 3
const MAX_LASER_CONTACTS := 4

static func create_walls() -> Array[Rect2]:
	return [
		Rect2(700, 330, 70, 360),
		Rect2(2087, 330, 70, 360),
		Rect2(700, 1253, 70, 360),
		Rect2(2087, 1253, 70, 360),
		Rect2(330, 760, 280, 65),
		Rect2(2247, 760, 280, 65),
		Rect2(1050, 470, 65, 300),
		Rect2(1742, 1173, 65, 300),
		Rect2(1742, 470, 65, 300),
		Rect2(1050, 1173, 65, 300),
		Rect2(1288, 851, 280, 240),
		Rect2(1120, 300, 300, 55),
		Rect2(1437, 1588, 300, 55),
	]
