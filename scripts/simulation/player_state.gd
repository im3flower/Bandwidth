class_name ArenaPlayerState
extends RefCounted
## Mutable player state. Input, timing judgment, networking, and rendering remain outside this class.

var index: int
var position: Vector2
var tint: Color
var facing: Vector2
var health := ArenaRules.MAX_HEALTH
var fatigue := 0.0
var attack_cooldown := 0.0
var dash_cooldown := 0.0
var dash_time := 0.0
var dash_direction := Vector2.RIGHT
var movement_velocity := Vector2.ZERO
var slow_amount := 0.0
var slow_recovery_time := 0.0
var overheat := 0.0
var recent_beat := -1
var last_attack_time := -999.0
var flash := 0.0

func _init(player_index: int, start: Vector2, color: Color, start_facing: Vector2) -> void:
	index = player_index
	position = start
	tint = color
	facing = start_facing

func tick(delta: float, direction: Vector2, geometry: ArenaGeometry) -> void:
	if health <= 0:
		dash_time = 0.0
		movement_velocity = Vector2.ZERO
		return
	var target_velocity := direction * ArenaRules.MOVE_SPEED * (1.0 - slow_amount)
	var velocity_lerp: float = ArenaRules.MOVE_ACCELERATION if direction.length_squared() > 0.0 else ArenaRules.MOVE_GLIDE_DECELERATION
	movement_velocity = movement_velocity.lerp(target_velocity, clampf(velocity_lerp * delta, 0.0, 1.0))
	if direction.length_squared() == 0.0 and movement_velocity.length() < 3.0:
		movement_velocity = Vector2.ZERO
	var movement := movement_velocity * delta
	if dash_time > 0.0:
		movement = dash_direction * ArenaRules.DASH_SPEED * delta
	position = geometry.move_circle(position, movement)
	fatigue = maxf(0.0, fatigue - 0.62 * delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	dash_time = maxf(0.0, dash_time - delta)
	if slow_recovery_time > 0.0:
		slow_recovery_time = maxf(0.0, slow_recovery_time - delta)
		slow_amount = slow_amount * slow_recovery_time / (slow_recovery_time + delta)
	overheat = maxf(0.0, overheat - delta)
	flash = maxf(0.0, flash - delta)

func dash() -> void:
	if health <= 0 or dash_cooldown > 0.0 or dash_time > 0.0:
		return
	dash_direction = movement_velocity.normalized() if movement_velocity.length() >= 40.0 else facing
	dash_time = ArenaRules.DASH_DURATION if fatigue < 7.0 else ArenaRules.DASH_DURATION * 0.65
	dash_cooldown = 0.7

func apply_slow(amount: float, beat_seconds: float) -> void:
	slow_amount = maxf(slow_amount, amount)
	slow_recovery_time = beat_seconds

func to_snapshot() -> Dictionary:
	return {"index": index, "position": position, "tint": tint, "facing": facing, "health": health, "fatigue": fatigue, "dash_time": dash_time, "flash": flash}

static func from_snapshot(data: Dictionary) -> ArenaPlayerState:
	var player := ArenaPlayerState.new(int(data["index"]), data["position"], data["tint"], data["facing"])
	player.health = int(data["health"])
	player.fatigue = float(data["fatigue"])
	player.dash_time = float(data["dash_time"])
	player.flash = float(data["flash"])
	return player
