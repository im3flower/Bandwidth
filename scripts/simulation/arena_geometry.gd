class_name ArenaGeometry
extends RefCounted
## Collision, raycasts, and reflection helpers. This module has no input or networking knowledge.

var walls: Array[Rect2]

func _init(arena_walls: Array[Rect2] = ArenaRules.create_walls()) -> void:
	walls = arena_walls

func move_circle(position: Vector2, movement: Vector2, radius: float = ArenaRules.PLAYER_RADIUS) -> Vector2:
	var resolved_position := position
	var step_count := maxi(1, ceili(movement.length() / ArenaRules.MAX_MOVEMENT_STEP))
	var step := movement / float(step_count)
	for step_index in range(step_count):
		var next_position := resolved_position + Vector2(step.x, 0.0)
		if not overlaps_circle(next_position, radius):
			resolved_position.x = next_position.x
		next_position = resolved_position + Vector2(0.0, step.y)
		if not overlaps_circle(next_position, radius):
			resolved_position.y = next_position.y
		resolved_position.x = clampf(resolved_position.x, radius, ArenaRules.ARENA_SIZE.x - radius)
		resolved_position.y = clampf(resolved_position.y, radius, ArenaRules.ARENA_SIZE.y - radius)
		resolved_position = resolve_circle_overlap(resolved_position, radius)
	return resolved_position

func overlaps_circle(position: Vector2, radius: float = ArenaRules.PLAYER_RADIUS) -> bool:
	for wall in walls:
		if wall.grow(radius).has_point(position):
			return true
	return false

func is_valid_circle_position(position: Vector2, radius: float = ArenaRules.PLAYER_RADIUS) -> bool:
	return position.x >= radius and position.x <= ArenaRules.ARENA_SIZE.x - radius and position.y >= radius and position.y <= ArenaRules.ARENA_SIZE.y - radius and not overlaps_circle(position, radius)

func resolve_circle_overlap(position: Vector2, radius: float = ArenaRules.PLAYER_RADIUS) -> Vector2:
	var resolved_position := position
	for wall in walls:
		var expanded_wall := wall.grow(radius)
		if not expanded_wall.has_point(resolved_position):
			continue
		var distances: Array[float] = [absf(resolved_position.x - expanded_wall.position.x), absf(resolved_position.x - expanded_wall.end.x), absf(resolved_position.y - expanded_wall.position.y), absf(resolved_position.y - expanded_wall.end.y)]
		var nearest_side := 0
		for side_index in range(1, distances.size()):
			if distances[side_index] < distances[nearest_side]:
				nearest_side = side_index
		match nearest_side:
			0: resolved_position.x = expanded_wall.position.x - 0.1
			1: resolved_position.x = expanded_wall.end.x + 0.1
			2: resolved_position.y = expanded_wall.position.y - 0.1
			_: resolved_position.y = expanded_wall.end.y + 0.1
	return resolved_position

func path_blocked(start: Vector2, end: Vector2, radius: float = ArenaRules.PLAYER_RADIUS) -> bool:
	for wall in walls:
		if segment_rect_intersection(start, end, wall.grow(radius))[0]:
			return true
	return false

func build_laser_path(start: Vector2, initial_direction: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array([start])
	var current_start := start
	var direction := initial_direction.normalized()
	var ray_length := ArenaRules.ARENA_SIZE.length()
	for contact_index in range(ArenaRules.MAX_LASER_CONTACTS):
		var end := current_start + direction * ray_length
		var nearest_distance := INF
		var nearest_hit := Vector2.ZERO
		var hit_wall := Rect2()
		var hit_boundary := false
		for wall in walls:
			var hit_data := segment_rect_intersection(current_start, end, wall)
			if hit_data[0] and current_start.distance_to(hit_data[1]) < nearest_distance:
				nearest_distance = current_start.distance_to(hit_data[1])
				nearest_hit = hit_data[1]
				hit_wall = wall
		var boundary_hit := segment_arena_exit(current_start, end)
		if boundary_hit[0] and current_start.distance_to(boundary_hit[1]) < nearest_distance:
			nearest_distance = current_start.distance_to(boundary_hit[1])
			nearest_hit = boundary_hit[1]
			hit_boundary = true
		if nearest_distance == INF:
			points.append(end)
			break
		points.append(nearest_hit)
		if contact_index == ArenaRules.MAX_LASER_CONTACTS - 1:
			break
		var normal := arena_normal(nearest_hit) if hit_boundary else wall_normal(nearest_hit, hit_wall)
		direction = direction.bounce(normal)
		current_start = nearest_hit + direction * 0.5
	return points

func bounce_projectile(projectile: ArenaProjectileState) -> bool:
	if projectile.position.x < projectile.radius or projectile.position.x > ArenaRules.ARENA_SIZE.x - projectile.radius or projectile.position.y < projectile.radius or projectile.position.y > ArenaRules.ARENA_SIZE.y - projectile.radius:
		if projectile.bounces_remaining <= 0:
			return true
		projectile.bounces_remaining -= 1
		projectile.velocity = projectile.velocity.bounce(arena_normal(projectile.position))
		projectile.position = projectile.previous_position + projectile.velocity.normalized() * 2.0
		return false
	for wall in walls:
		var expanded_wall := wall.grow(projectile.radius)
		if not expanded_wall.has_point(projectile.position):
			continue
		if projectile.bounces_remaining <= 0:
			return true
		projectile.bounces_remaining -= 1
		projectile.velocity = projectile.velocity.bounce(wall_normal(projectile.position, expanded_wall))
		projectile.position = projectile.previous_position + projectile.velocity.normalized() * 2.0
		return false
	return false

func segment_arena_exit(start: Vector2, end: Vector2) -> Array:
	var direction := end - start
	var exit_time := INF
	if direction.x > 0.0:
		exit_time = minf(exit_time, (ArenaRules.ARENA_SIZE.x - start.x) / direction.x)
	elif direction.x < 0.0:
		exit_time = minf(exit_time, -start.x / direction.x)
	if direction.y > 0.0:
		exit_time = minf(exit_time, (ArenaRules.ARENA_SIZE.y - start.y) / direction.y)
	elif direction.y < 0.0:
		exit_time = minf(exit_time, -start.y / direction.y)
	return [exit_time >= 0.0 and exit_time <= 1.0, start + direction * exit_time]

func segment_rect_intersection(start: Vector2, end: Vector2, rect: Rect2) -> Array:
	var direction := end - start
	var enter_time := 0.0
	var exit_time := 1.0
	for axis in range(2):
		var origin := start[axis]
		var movement := direction[axis]
		var minimum := rect.position[axis]
		var maximum := rect.end[axis]
		if absf(movement) < 0.00001:
			if origin < minimum or origin > maximum:
				return [false, Vector2.ZERO]
			continue
		var near_time := (minimum - origin) / movement
		var far_time := (maximum - origin) / movement
		if near_time > far_time:
			var temporary := near_time
			near_time = far_time
			far_time = temporary
		enter_time = maxf(enter_time, near_time)
		exit_time = minf(exit_time, far_time)
		if enter_time > exit_time:
			return [false, Vector2.ZERO]
	return [true, start + direction * enter_time]

func arena_normal(hit: Vector2) -> Vector2:
	var distances := [hit.x, ArenaRules.ARENA_SIZE.x - hit.x, hit.y, ArenaRules.ARENA_SIZE.y - hit.y]
	var nearest_side := 0
	for side_index in range(1, distances.size()):
		if distances[side_index] < distances[nearest_side]:
			nearest_side = side_index
	match nearest_side:
		0: return Vector2.RIGHT
		1: return Vector2.LEFT
		2: return Vector2.DOWN
		_: return Vector2.UP

func wall_normal(hit: Vector2, wall: Rect2) -> Vector2:
	var distances := [absf(hit.x - wall.position.x), absf(hit.x - wall.end.x), absf(hit.y - wall.position.y), absf(hit.y - wall.end.y)]
	var closest_side := 0
	for side in range(1, distances.size()):
		if distances[side] < distances[closest_side]:
			closest_side = side
	match closest_side:
		0: return Vector2.LEFT
		1: return Vector2.RIGHT
		2: return Vector2.UP
		_: return Vector2.DOWN

func point_segment_distance(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared == 0.0:
		return point.distance_to(start)
	var progress := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * progress)
