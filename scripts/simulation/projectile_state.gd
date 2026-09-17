class_name ArenaProjectileState
extends RefCounted
## Mutable projectile data shared by host simulation and client presentation.

var position: Vector2
var velocity: Vector2
var owner: int
var damage: int
var radius: float
var tint: Color
var bounces_remaining := ArenaRules.PROJECTILE_BOUNCES
var previous_position: Vector2

func _init(start: Vector2, movement: Vector2, owner_id: int, hit_damage: int, size: float, color: Color) -> void:
	position = start
	velocity = movement
	previous_position = start
	owner = owner_id
	damage = hit_damage
	radius = size
	tint = color

func tick(delta: float) -> void:
	previous_position = position
	position += velocity * delta

func to_snapshot() -> Dictionary:
	return {"position": position, "velocity": velocity, "owner": owner, "damage": damage, "radius": radius, "tint": tint, "bounces": bounces_remaining}

static func from_snapshot(data: Dictionary) -> ArenaProjectileState:
	var projectile := ArenaProjectileState.new(data["position"], data["velocity"], int(data["owner"]), int(data["damage"]), float(data["radius"]), data["tint"])
	projectile.bounces_remaining = int(data["bounces"])
	return projectile
