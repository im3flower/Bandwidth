extends Node2D

const DISPLAY_SIZE := Vector2(2000, 1360)
const WORLD_RENDER_SCALE := 0.70
const ARENA_SIZE := ArenaRules.ARENA_SIZE
const BPM := 128.0
const LAN_JOIN_ADDRESS := "192.168.1.158" # Replace with the host's LAN IPv4 address for a second computer.
const DEFAULT_LAN_START_LEAD_SECONDS := 5.0
const SOLO_START_LEAD_SECONDS := 5.0
const MAX_ENTITIES := 4
const PERFECT_WINDOW := 0.018
const GOOD_WINDOW := 0.045
const WEAK_WINDOW := 0.080
const LASER_CHARGE_START_WINDOW := 0.050
const LASER_RELEASE_EARLY_WINDOW := 0.200
const LASER_RELEASE_LATE_WINDOW := 0.120
const LASER_MIN_HOLD_TIME := 0.200
const LASER_DISSIPATE_TIME := 0.220
const MAX_HEALTH := ArenaRules.MAX_HEALTH
const PLAYER_RADIUS := ArenaRules.PLAYER_RADIUS
const SPEED_MULTIPLIER := ArenaRules.SPEED_MULTIPLIER
const MAX_MOVEMENT_STEP := ArenaRules.MAX_MOVEMENT_STEP
const LASER_DAMAGE := 30
const LASER_AIM_TURN_SPEED := 2.4
const AI_AIM_TURN_SPEED := 1.55
const AI_AIM_UPDATE_INTERVAL := 0.30
const AI_FIRE_CHANCE := 0.58
const AI_TIMING_JITTER := 0.145
const AI_LASER_CHANCE := 0.12
const AI_FIRE_RANGE := 1240.0
const AI_BOUNCE_FIRE_CHANCE := 0.25
const AI_BOUNCE_AIM_ERROR := 0.24
const BEAT_OFFSET_STEP := 0.010
const MAX_BEAT_OFFSET := 0.500
const CAPTURE_RADIUS := 475.0
const CAPTURE_HEAL_PER_SECOND := 5.0
const CAPTURE_ACTIVATION_SECONDS := 0.65
const CHAOS_DURATION_SECONDS := 8.0
const CHAOS_TEMPERATURE_BONUS := 0.22
const PICKUP_RESPAWN_SECONDS := 9.0
const RESONANCE_DURATION_SECONDS := 2.5
const RESONANCE_COOLDOWN_SECONDS := 4.0
const TEMPO_EVALUATION_BEATS := 16
const CALIBRATION_BPM := 120.0
const CALIBRATION_BEAT_SECONDS := 60.0 / CALIBRATION_BPM
const CALIBRATION_COUNT_IN_BEATS := 4
const CALIBRATION_REQUIRED_TAPS := 12
const CALIBRATION_MAX_ERROR_SECONDS := 0.220
const CALIBRATION_MIN_VALID_TAPS := 7
const CALIBRATION_AUDIO_LEAD_SECONDS := 1.0

const BACKGROUND := Color("161921")
const GRID := Color("272b37")
const TEXT := Color("e9ecf2")

var players: Array[ArenaPlayerState] = []
var projectiles: Array[ArenaProjectileState] = []
var geometry := ArenaGeometry.new()
var walls: Array[Rect2] = geometry.walls
var lan_spawn_positions: Array[Vector2] = []
var elapsed := 0.0
var beat_offset_seconds := 0.0
var winner := -1
var font: Font
var bot_count := 0
var lan_start_lead_seconds := DEFAULT_LAN_START_LEAD_SECONDS
var movement_keys: Array[Key] = [KEY_W, KEY_S, KEY_A, KEY_D]
var movement_secondary_keys: Array[Key] = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]
var attack_key: Key = KEY_F
var attack_secondary_key: Key = KEY_ENTER
var dash_key: Key = KEY_SPACE
var dash_secondary_key: Key = KEY_SHIFT
var settings_open := false
var settings_selection := 0
var waiting_for_keybind := false
var ai_last_attack_beats: Array[int] = []
var ai_scheduled_shot_times: Array[float] = []
var ai_scheduled_lasers: Array[bool] = []
var ai_next_path_updates: Array[float] = []
var ai_waypoints: Array[Vector2] = []
var ai_next_aim_updates: Array[float] = []
var ai_target_facings: Array[Vector2] = []
var ai_aim_errors: Array[float] = []
var charging_laser := false
var charge_started_at := 0.0
var charge_started_on_beat := false
var charge_release_beat := -1
var laser_points := PackedVector2Array()
var laser_flash_time := 0.0
var laser_tint := Color.WHITE
var laser_damage := LASER_DAMAGE
var laser_width := 18.0
var laser_brightness := 1.0
var lan_mode := false
var lan_is_host := false
var lan_status := "Solo — press H to host or J to join localhost"
var player_owners: Array[int] = []
var peer_inputs: Dictionary = {}
var input_sequence := 0
var last_input_sequence: Dictionary = {}
var queued_shot := false
var queued_dash := false
var queued_laser_pressed := false
var queued_laser_released := false
var snapshot_elapsed := 0.0
var match_start_server_msec := 0
var server_clock_offset_msec := 0.0
var pending_time_pings: Dictionary = {}
var last_ping_msec := 0
var network_charge_states: Dictionary = {}
var network_action_queues: Dictionary = {}
var music_plan := MusicPlan.new()
var style_weights: Array[float] = [0.5, 0.5]
var capture_owner := -1
var capture_hold_time := 0.0
var capture_contested := false
var capture_heal_remainders: Dictionary = {}
var pickups: Array[Dictionary] = []
var player_melody_ammo: Dictionary = {}
var player_chaos_until: Dictionary = {}
var perfect_attack_beats: Dictionary = {}
var resonance_until := 0.0
var resonance_cooldown_until := 0.0
var music_temperature := 0.70
var last_tempo_evaluation := -1
var calibration_active := false
var calibration_start_msec := 0
var calibration_taps: Array[float] = []
var calibration_last_beat := -1
var calibration_result := "No calibration recorded"
var calibration_audio_player: AudioStreamPlayer
var calibration_audio_playback: AudioStreamGeneratorPlayback
var calibration_audio_frames_written := 0
var last_attack_feedback := ""
var last_attack_feedback_until := 0.0
@onready var beat_clock: BeatClock = $BeatClock

func _ready() -> void:
	font = ThemeDB.fallback_font
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	setup_calibration_audio()
	reset_game()
	queue_redraw()

func reset_game() -> void:
	elapsed = -SOLO_START_LEAD_SECONDS
	beat_clock.restart_after(SOLO_START_LEAD_SECONDS, BPM)
	winner = -1
	ai_last_attack_beats.clear()
	ai_scheduled_shot_times.clear()
	ai_scheduled_lasers.clear()
	ai_next_path_updates.clear()
	ai_waypoints.clear()
	ai_next_aim_updates.clear()
	ai_target_facings.clear()
	ai_aim_errors.clear()
	charging_laser = false
	charge_started_on_beat = false
	charge_release_beat = -1
	laser_flash_time = 0.0
	laser_tint = Color.WHITE
	laser_damage = LASER_DAMAGE
	laser_width = 18.0
	laser_brightness = 1.0
	laser_points.clear()
	projectiles.clear()
	players.clear()
	reset_music_gameplay_state()
	var spawn_positions: Array[Vector2] = get_spawn_positions()
	var player_spawn := spawn_positions[0]
	players.append(ArenaPlayerState.new(0, player_spawn, Color("57b0ff"), (ARENA_SIZE / 2.0 - player_spawn).normalized()))
	var bot_colors: Array[Color] = [Color("ff7882"), Color("f7ae4f"), Color("b78cff")]
	var solo_ai_count := clampi(bot_count, 0, MAX_ENTITIES - 1)
	for bot_index in range(solo_ai_count):
		var bot_spawn := spawn_positions[bot_index + 1]
		players.append(ArenaPlayerState.new(bot_index + 1, bot_spawn, bot_colors[bot_index], (ARENA_SIZE / 2.0 - bot_spawn).normalized()))
		initialize_ai_state()

func reset_music_gameplay_state() -> void:
	music_plan.configure("bandwidth-%d" % Time.get_ticks_msec(), BPM, beat_clock.server_start_time_msec())
	style_weights = [0.5, 0.5]
	capture_owner = -1
	capture_hold_time = 0.0
	capture_contested = false
	capture_heal_remainders.clear()
	pickups = [
		{"kind": "melody", "position": ARENA_SIZE / 2.0 + Vector2(-310.0, 0.0), "active": true, "respawn_at": 0.0},
		{"kind": "chaos", "position": ARENA_SIZE / 2.0 + Vector2(310.0, 0.0), "active": true, "respawn_at": 0.0},
	]
	player_melody_ammo.clear()
	player_chaos_until.clear()
	perfect_attack_beats.clear()
	resonance_until = 0.0
	resonance_cooldown_until = 0.0
	music_temperature = 0.70
	last_tempo_evaluation = -1

func get_spawn_positions() -> Array[Vector2]:
	var margin := 260.0
	var top_left := Vector2(margin, margin)
	var top_right := Vector2(ARENA_SIZE.x - margin, margin)
	var bottom_left := Vector2(margin, ARENA_SIZE.y - margin)
	var bottom_right := Vector2(ARENA_SIZE.x - margin, ARENA_SIZE.y - margin)
	if randf() < 0.5:
		return [top_left, bottom_right, top_right, bottom_left]
	return [top_right, bottom_left, top_left, bottom_right]

func initialize_ai_state() -> void:
	ai_last_attack_beats.append(-1)
	ai_scheduled_shot_times.append(-1.0)
	ai_scheduled_lasers.append(false)
	ai_next_path_updates.append(0.0)
	ai_waypoints.append(Vector2.ZERO)
	ai_next_aim_updates.append(0.0)
	ai_target_facings.append(Vector2.LEFT)
	ai_aim_errors.append(0.0)

func _process(delta: float) -> void:
	if calibration_active:
		feed_calibration_audio()
	elapsed += delta
	if lan_mode:
		update_lan_game(delta)
	else:
		update_solo_game(delta)
	queue_redraw()

func update_solo_game(delta: float) -> void:
	laser_flash_time = maxf(0.0, laser_flash_time - delta)
	if winner == -1 and elapsed >= 0.0 and not settings_open and not calibration_active:
		if players[0].health > 0:
			var player_direction := get_direction()
			if charging_laser:
				players[0].apply_slow(0.20, beat_clock.seconds_per_beat())
			var mouse_direction := get_global_mouse_position() / WORLD_RENDER_SCALE - players[0].position
			if mouse_direction.length_squared() > 0.0:
				var mouse_facing := mouse_direction.normalized()
				if charging_laser:
					var turn_amount := clampf(players[0].facing.angle_to(mouse_facing), -LASER_AIM_TURN_SPEED * delta, LASER_AIM_TURN_SPEED * delta)
					players[0].facing = players[0].facing.rotated(turn_amount)
				else:
					players[0].facing = mouse_facing
			players[0].tick(delta, player_direction, geometry)
		for bot_index in range(1, players.size()):
			update_ai(delta, bot_index)
		update_projectiles(delta)
		update_music_gameplay(delta)

func update_lan_game(delta: float) -> void:
	if not lan_is_host:
		update_client_clock_sync()
		return
	if match_start_server_msec == 0:
		return
	if Time.get_ticks_msec() < match_start_server_msec:
		return
	laser_flash_time = maxf(0.0, laser_flash_time - delta)
	peer_inputs[1] = build_local_input()
	if winner == -1 and is_match_combat_active():
		for player_index in range(players.size()):
			var owner_peer_id := player_owners[player_index] if player_index < player_owners.size() else 0
			if owner_peer_id > 0:
				update_network_player(delta, player_index, peer_inputs.get(owner_peer_id, {}))
			elif owner_peer_id < 0:
				update_ai(delta, player_index)
		update_projectiles(delta)
		update_music_gameplay(delta)
	snapshot_elapsed += delta
	if snapshot_elapsed >= 1.0 / float(NetworkProtocol.SNAPSHOT_RATE_HZ):
		snapshot_elapsed = 0.0
		broadcast_snapshot.rpc(make_snapshot())

func is_match_combat_active() -> bool:
	if lan_mode:
		if lan_is_host:
			return match_start_server_msec != 0 and Time.get_ticks_msec() >= match_start_server_msec
		return match_start_server_msec != 0 and Time.get_ticks_msec() >= server_to_local_msec(match_start_server_msec)
	return elapsed >= 0.0

func is_combat_started() -> bool:
	if lan_mode:
		if match_start_server_msec == 0:
			return false
		var local_start_msec := match_start_server_msec if lan_is_host else server_to_local_msec(match_start_server_msec)
		return Time.get_ticks_msec() >= local_start_msec
	return elapsed >= 0.0

func host_lan_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(NetworkProtocol.DEFAULT_PORT, NetworkProtocol.MAX_PLAYERS - 1)
	if result == ERR_ALREADY_IN_USE:
		join_lan_game(LAN_JOIN_ADDRESS)
		return
	if result != OK:
		lan_status = "Unable to host UDP %d (error %d)" % [NetworkProtocol.DEFAULT_PORT, result]
		return
	multiplayer.multiplayer_peer = peer
	lan_mode = true
	lan_is_host = true
	setup_lan_match()
	lan_status = "Hosting UDP %d — waiting for players (1/%d)" % [NetworkProtocol.DEFAULT_PORT, MAX_ENTITIES]

func join_lan_game(address: String = LAN_JOIN_ADDRESS) -> void:
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(address, NetworkProtocol.DEFAULT_PORT)
	if result != OK:
		lan_status = "Unable to join %s (error %d)" % [address, result]
		return
	multiplayer.multiplayer_peer = peer
	lan_mode = true
	lan_is_host = false
	lan_status = "Connecting to %s:%d" % [address, NetworkProtocol.DEFAULT_PORT]

func setup_lan_match(human_owners: Array[int] = [1]) -> void:
	reset_game()
	projectiles.clear()
	players.clear()
	ai_last_attack_beats.clear()
	ai_scheduled_shot_times.clear()
	ai_scheduled_lasers.clear()
	ai_next_path_updates.clear()
	ai_waypoints.clear()
	ai_next_aim_updates.clear()
	ai_target_facings.clear()
	ai_aim_errors.clear()
	lan_spawn_positions = get_spawn_positions()
	player_owners = human_owners.duplicate()
	for human_index in range(player_owners.size()):
		players.append(create_lan_player(human_index, lan_spawn_positions))
	var lan_ai_count := clampi(bot_count, 0, MAX_ENTITIES - player_owners.size())
	for ai_index in range(lan_ai_count):
		var player_index := players.size()
		players.append(create_lan_player(player_index, lan_spawn_positions))
		player_owners.append(-1)
	rebuild_lan_ai_state()
	peer_inputs = {1: {}}
	last_input_sequence.clear()
	network_action_queues.clear()
	network_charge_states.clear()
	for peer_id in player_owners:
		if peer_id > 1:
			peer_inputs[peer_id] = {}
			network_action_queues[peer_id] = []
	match_start_server_msec = 0

func create_lan_player(player_index: int, spawn_positions: Array[Vector2]) -> ArenaPlayerState:
	var player_colors: Array[Color] = [Color("57b0ff"), Color("ff7882"), Color("f7ae4f"), Color("b78cff")]
	var spawn_position := spawn_positions[player_index]
	return ArenaPlayerState.new(player_index, spawn_position, player_colors[player_index], (ARENA_SIZE / 2.0 - spawn_position).normalized())

func rebuild_lan_ai_state() -> void:
	ai_last_attack_beats.clear()
	ai_scheduled_shot_times.clear()
	ai_scheduled_lasers.clear()
	ai_next_path_updates.clear()
	ai_waypoints.clear()
	ai_next_aim_updates.clear()
	ai_target_facings.clear()
	ai_aim_errors.clear()
	for owner_peer_id in player_owners:
		if owner_peer_id < 0:
			initialize_ai_state()

func _on_peer_connected(peer_id: int) -> void:
	if not lan_is_host:
		return
	if peer_id == 1 or player_owners.has(peer_id):
		return
	if match_start_server_msec != 0 and Time.get_ticks_msec() >= match_start_server_msec:
		lan_status = "P%d connected — next round (match already running)" % peer_id
		return
	var open_slot := player_owners.find(-1)
	if open_slot >= 0:
		player_owners[open_slot] = peer_id
		players[open_slot].tint = get_lan_player_color(open_slot)
	elif player_owners.find(0) >= 0:
		open_slot = player_owners.find(0)
		player_owners[open_slot] = peer_id
		players[open_slot] = create_lan_player(open_slot, lan_spawn_positions)
	elif players.size() < MAX_ENTITIES:
		open_slot = players.size()
		players.append(create_lan_player(open_slot, lan_spawn_positions))
		player_owners.append(peer_id)
	else:
		lan_status = "Room full — P%d could not join" % peer_id
		return
	peer_inputs[peer_id] = {}
	network_action_queues[peer_id] = []
	last_input_sequence.erase(peer_id)
	network_charge_states.erase(peer_id)
	rebuild_lan_ai_state()
	start_lan_match()

func get_lan_player_color(player_index: int) -> Color:
	var player_colors: Array[Color] = [Color("57b0ff"), Color("ff7882"), Color("f7ae4f"), Color("b78cff")]
	return player_colors[player_index]

func start_lan_match() -> void:
	match_start_server_msec = Time.get_ticks_msec() + roundi(lan_start_lead_seconds * 1000.0)
	beat_clock.configure(match_start_server_msec, BPM)
	music_plan.configure("bandwidth-%d" % Time.get_ticks_msec(), BPM, match_start_server_msec)
	lan_status = "Match starts in %.1f seconds — %d/%d players" % [lan_start_lead_seconds, get_human_player_count(), MAX_ENTITIES]
	for peer_id in player_owners:
		if peer_id > 1:
			match_config.rpc_id(peer_id, match_start_server_msec, BPM, player_owners, player_owners.find(peer_id), bot_count, lan_start_lead_seconds)
	broadcast_snapshot.rpc(make_snapshot())

func restart_lan_match() -> void:
	if not lan_is_host:
		return
	var human_owners: Array[int] = []
	for peer_id in player_owners:
		if peer_id > 0:
			human_owners.append(peer_id)
	setup_lan_match(human_owners)
	if human_owners.size() > 1:
		start_lan_match()
	else:
		lan_status = "Hosting UDP %d — waiting for players (1/%d)" % [NetworkProtocol.DEFAULT_PORT, MAX_ENTITIES]

func get_human_player_count() -> int:
	var human_count := 0
	for peer_id in player_owners:
		if peer_id > 0:
			human_count += 1
	return human_count

func _on_peer_disconnected(peer_id: int) -> void:
	if not lan_is_host:
		return
	var player_slot := player_owners.find(peer_id)
	if player_slot >= 0:
		peer_inputs.erase(peer_id)
		network_action_queues.erase(peer_id)
		network_charge_states.erase(peer_id)
		if match_start_server_msec != 0 and Time.get_ticks_msec() >= match_start_server_msec:
			players[player_slot].health = 0
			players[player_slot].flash = 0.18
			player_owners[player_slot] = 0
			check_match_winner()
			lan_status = "P%d disconnected and forfeited" % peer_id
		else:
			var remaining_humans: Array[int] = []
			for owner_peer_id in player_owners:
				if owner_peer_id > 0 and owner_peer_id != peer_id:
					remaining_humans.append(owner_peer_id)
			setup_lan_match(remaining_humans)
			if remaining_humans.size() > 1:
				start_lan_match()
			else:
				lan_status = "Player disconnected — waiting for players"

func _on_connected_to_server() -> void:
	lan_status = "Connected — synchronizing host clock"

func _on_connection_failed() -> void:
	lan_status = "Connection failed"
	lan_mode = false

func _on_server_disconnected() -> void:
	lan_status = "Host disconnected"
	lan_mode = false

func update_client_clock_sync() -> void:
	var now := Time.get_ticks_msec()
	if now - last_ping_msec >= 1000:
		last_ping_msec = now
		pending_time_pings[now] = now
		time_ping.rpc_id(1, now)
	if match_start_server_msec != 0:
		var input := build_local_input()
		predict_local_player(input, get_process_delta_time())
		submit_input.rpc(input)

func send_network_action(action: String) -> void:
	if not lan_mode:
		return
	if lan_is_host:
		queue_network_action(1, action)
		return
	if multiplayer.multiplayer_peer != null and multiplayer.get_unique_id() != 1:
		submit_action.rpc_id(1, action)

func request_lan_restart() -> void:
	if not lan_mode:
		return
	if lan_is_host:
		restart_lan_match()
	elif multiplayer.multiplayer_peer != null:
		submit_action.rpc_id(1, "restart")

func queue_network_action(peer_id: int, action: String) -> void:
	var actions: Array = network_action_queues.get(peer_id, [])
	actions.append(action)
	network_action_queues[peer_id] = actions

func consume_network_actions(peer_id: int) -> Array:
	var actions: Array = network_action_queues.get(peer_id, [])
	network_action_queues[peer_id] = []
	return actions

func server_to_local_msec(server_msec: int) -> int:
	return server_msec - roundi(server_clock_offset_msec)

func network_time_msec() -> int:
	if lan_mode and not lan_is_host:
		return Time.get_ticks_msec() + roundi(server_clock_offset_msec)
	return Time.get_ticks_msec()

func build_local_input() -> Dictionary:
	var facing := Vector2.RIGHT
	if players.size() > 0:
		var local_slot := player_owners.find(multiplayer.get_unique_id())
		if local_slot >= 0:
			facing = get_global_mouse_position() / WORLD_RENDER_SCALE - players[local_slot].position
	input_sequence += 1
	var controls_enabled := not settings_open and not calibration_active
	var input := NetworkProtocol.make_input(input_sequence, get_direction() if controls_enabled else Vector2.ZERO, facing, {
		"shot_pressed": queued_shot if controls_enabled else false,
		"dash_pressed": queued_dash if controls_enabled else false,
		"laser_pressed": queued_laser_pressed if controls_enabled else false,
		"laser_released": queued_laser_released if controls_enabled else false,
		"laser_held": Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and controls_enabled,
	})
	queued_shot = false
	queued_dash = false
	queued_laser_pressed = false
	queued_laser_released = false
	var body: Dictionary = input.body
	var buttons: Dictionary = body.get("buttons", {})
	for button_name in buttons:
		body[button_name] = buttons[button_name]
	body.erase("buttons")
	return body

func predict_local_player(input: Dictionary, delta: float) -> void:
	if not lan_mode or lan_is_host or not is_match_combat_active():
		return
	var local_slot := player_owners.find(multiplayer.get_unique_id())
	if local_slot < 0 or local_slot >= players.size():
		return
	var player := players[local_slot]
	if player.health <= 0:
		return
	var facing: Vector2 = input.get("facing", player.facing)
	if facing.length_squared() > 0.0:
		player.facing = facing.normalized()
	player.tick(delta, input.get("movement", Vector2.ZERO).limit_length(1.0), geometry)
	if bool(input.get("dash_pressed", false)):
		player.dash()

@rpc("any_peer", "reliable")
func time_ping(client_send_msec: int) -> void:
	if lan_is_host:
		time_pong.rpc_id(multiplayer.get_remote_sender_id(), client_send_msec, Time.get_ticks_msec())

@rpc("authority", "reliable")
func time_pong(client_send_msec: int, server_now_msec: int) -> void:
	var sent_msec: int = pending_time_pings.get(client_send_msec, client_send_msec)
	pending_time_pings.erase(client_send_msec)
	var midpoint := (sent_msec + Time.get_ticks_msec()) * 0.5
	server_clock_offset_msec = lerpf(server_clock_offset_msec, float(server_now_msec) - midpoint, 0.35)

@rpc("authority", "reliable")
func match_config(server_start_msec: int, bpm: float, owners: Array[int], local_player_slot: int, host_bot_count: int, host_start_lead_seconds: float) -> void:
	match_start_server_msec = server_start_msec
	player_owners = owners.duplicate()
	bot_count = host_bot_count
	lan_start_lead_seconds = host_start_lead_seconds
	network_charge_states.clear()
	beat_clock.configure(server_to_local_msec(server_start_msec), bpm)
	var assigned_slot := player_owners.find(multiplayer.get_unique_id())
	if assigned_slot < 0:
		lan_status = "Connected as spectator — room is full"
		return
	lan_status = "Joined P%d — match starts in %.1f seconds" % [assigned_slot + 1, lan_start_lead_seconds]

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func submit_input(input: Dictionary) -> void:
	if not lan_is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not player_owners.has(sender):
		return
	var sequence := int(input.get("sequence", -1))
	if sequence <= int(last_input_sequence.get(sender, -1)):
		return
	last_input_sequence[sender] = sequence
	peer_inputs[sender] = input

@rpc("any_peer", "call_remote", "reliable", 0)
func submit_action(action: String) -> void:
	if not lan_is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	if player_owners.has(sender):
		if action == "restart":
			restart_lan_match()
		else:
			queue_network_action(sender, action)

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func broadcast_snapshot(snapshot: Dictionary) -> void:
	if lan_is_host:
		return
	winner = int(snapshot.get("winner", -1))
	bot_count = int(snapshot.get("host_bot_count", bot_count))
	lan_start_lead_seconds = float(snapshot.get("lan_start_lead_seconds", lan_start_lead_seconds))
	laser_points = snapshot.get("laser_points", PackedVector2Array())
	laser_flash_time = float(snapshot.get("laser_flash_time", 0.0))
	laser_tint = snapshot.get("laser_tint", Color.WHITE)
	laser_damage = int(snapshot.get("laser_damage", LASER_DAMAGE))
	laser_width = float(snapshot.get("laser_width", 18.0))
	laser_brightness = float(snapshot.get("laser_brightness", 1.0))
	player_owners = snapshot.get("owners", [])
	network_charge_states = snapshot.get("charge_states", {})
	style_weights = snapshot.get("style_weights", style_weights)
	capture_owner = int(snapshot.get("capture_owner", -1))
	capture_hold_time = float(snapshot.get("capture_hold_time", 0.0))
	capture_contested = bool(snapshot.get("capture_contested", false))
	pickups = snapshot.get("pickups", [])
	player_melody_ammo = snapshot.get("player_melody_ammo", {})
	player_chaos_until = snapshot.get("player_chaos_until", {})
	resonance_until = float(snapshot.get("resonance_until", 0.0))
	music_temperature = float(snapshot.get("music_temperature", 0.70))
	var tempo_segments: Array[Dictionary] = snapshot.get("tempo_segments", [])
	if not tempo_segments.is_empty():
		beat_clock.set_tempo_segments(tempo_segments)
	var music_plan_payload: Dictionary = snapshot.get("music_plan", {})
	if not music_plan_payload.is_empty():
		music_plan = MusicPlan.from_payload(music_plan_payload)
	players.clear()
	for player_data in snapshot.get("players", []):
		players.append(ArenaPlayerState.from_snapshot(player_data))
	projectiles.clear()
	for projectile_data in snapshot.get("projectiles", []):
		projectiles.append(ArenaProjectileState.from_snapshot(projectile_data))

func make_snapshot() -> Dictionary:
	var player_states: Array[Dictionary] = []
	for player in players:
		player_states.append(player.to_snapshot())
	var projectile_states: Array[Dictionary] = []
	for projectile in projectiles:
		projectile_states.append(projectile.to_snapshot())
	return {
		"winner": winner,
		"owners": player_owners,
		"players": player_states,
		"projectiles": projectile_states,
		"laser_points": laser_points,
		"laser_flash_time": laser_flash_time,
		"laser_tint": laser_tint,
		"laser_damage": laser_damage,
		"laser_width": laser_width,
		"laser_brightness": laser_brightness,
		"charge_states": network_charge_states,
		"host_bot_count": bot_count,
		"lan_start_lead_seconds": lan_start_lead_seconds,
		"match_start_server_msec": match_start_server_msec,
		"style_weights": style_weights,
		"capture_owner": capture_owner,
		"capture_hold_time": capture_hold_time,
		"capture_contested": capture_contested,
		"pickups": pickups,
		"player_melody_ammo": player_melody_ammo,
		"player_chaos_until": player_chaos_until,
		"resonance_until": resonance_until,
		"music_temperature": music_temperature,
		"tempo_segments": beat_clock.tempo_segments(),
		"music_plan": music_plan.to_payload(),
	}

func can_author_music_cues() -> bool:
	return not lan_mode or lan_is_host

func append_music_cue(cue_type: String, details: Dictionary = {}) -> void:
	if not can_author_music_cues():
		return
	var cue := details.duplicate(true)
	cue["id"] = "%s-%d" % [cue_type, music_plan.revision + 1]
	cue["type"] = cue_type
	if not cue.has("start_beat"):
		cue["start_beat"] = calibrated_beat_position()
	cue["tempo_bpm"] = beat_clock.current_bpm()
	cue["temperature"] = music_temperature
	music_plan.bpm = beat_clock.current_bpm()
	music_plan.append_cue(cue)

func update_music_gameplay(delta: float) -> void:
	update_capture_zone(delta)
	update_pickups()
	update_style_weights(delta)
	update_chaos_temperature(delta)
	update_tempo_director()

func update_tempo_director() -> void:
	if not can_author_music_cues():
		return
	var phrase_index := floori(calibrated_beat_position() / float(TEMPO_EVALUATION_BEATS))
	if phrase_index == last_tempo_evaluation:
		return
	last_tempo_evaluation = phrase_index
	var health_fraction := 1.0
	if not players.is_empty():
		var total_health := 0.0
		for player in players:
			total_health += float(player.health) / float(MAX_HEALTH)
		health_fraction = total_health / float(players.size())
	var target_bpm := BPM + (1.0 - health_fraction) * 5.0
	if capture_owner >= 0:
		target_bpm += 1.0
	if capture_contested:
		target_bpm += 1.0
	if music_temperature > 0.80:
		target_bpm += 1.0
	var tempo_segment := beat_clock.schedule_bpm_toward(target_bpm)
	if not tempo_segment.is_empty():
		append_music_cue("tempo_change", {"start_beat": float(tempo_segment["start_beat"]), "tempo_bpm": float(tempo_segment["bpm"]), "reason": "match_tension"})

func update_capture_zone(delta: float) -> void:
	var occupants: Array[int] = []
	for player in players:
		if player.health > 0 and player.position.distance_to(ARENA_SIZE / 2.0) <= CAPTURE_RADIUS:
			occupants.append(player.index)
	capture_contested = occupants.size() > 1
	if occupants.size() == 1:
		var candidate_owner := occupants[0]
		if capture_owner == candidate_owner:
			capture_hold_time += delta
		else:
			capture_owner = candidate_owner
			capture_hold_time = 0.0
			append_music_cue("capture_started", {"owner": capture_owner, "drum_density": 0.55})
		if capture_hold_time >= CAPTURE_ACTIVATION_SECONDS and capture_owner < players.size():
			var owner := players[capture_owner]
			var carry := float(capture_heal_remainders.get(capture_owner, 0.0)) + CAPTURE_HEAL_PER_SECOND * delta
			var whole_heal := floori(carry)
			capture_heal_remainders[capture_owner] = carry - float(whole_heal)
			if whole_heal > 0:
				owner.health = mini(MAX_HEALTH, owner.health + whole_heal)
	elif occupants.is_empty():
		capture_owner = -1
		capture_hold_time = 0.0
		capture_heal_remainders.clear()

func update_pickups() -> void:
	for pickup in pickups:
		if not bool(pickup.get("active", false)):
			if elapsed >= float(pickup.get("respawn_at", 0.0)):
				pickup["active"] = true
				append_music_cue("pickup_spawned", {"pickup": str(pickup.get("kind", ""))})
			continue
		var pickup_position: Vector2 = pickup.get("position", Vector2.ZERO)
		for player in players:
			if player.health > 0 and player.position.distance_to(pickup_position) <= PLAYER_RADIUS + 28.0:
				collect_pickup(player, pickup)
				break

func collect_pickup(player: ArenaPlayerState, pickup: Dictionary) -> void:
	var kind := str(pickup.get("kind", ""))
	pickup["active"] = false
	pickup["respawn_at"] = elapsed + PICKUP_RESPAWN_SECONDS
	if kind == "melody":
		player_melody_ammo[player.index] = PackedInt32Array([60, 63, 67]) if player.index == 0 else PackedInt32Array([62, 65, 69])
		append_music_cue("melody_loaded", {"player": player.index, "notes": player_melody_ammo[player.index]})
	elif kind == "chaos":
		player_chaos_until[player.index] = elapsed + CHAOS_DURATION_SECONDS
		append_music_cue("chaos_started", {"player": player.index, "duration_beats": CHAOS_DURATION_SECONDS / beat_clock.seconds_per_beat()})

func update_style_weights(delta: float) -> void:
	if players.size() < 2:
		return
	var p1_health := maxf(0.0, float(players[0].health))
	var p2_health := maxf(0.0, float(players[1].health))
	var total_health := p1_health + p2_health
	var target_p1 := 0.5 if total_health <= 0.0 else p1_health / total_health
	if elapsed < resonance_until:
		target_p1 = 0.5
	style_weights[0] = lerpf(style_weights[0], target_p1, clampf(delta * 2.2, 0.0, 1.0))
	style_weights[1] = 1.0 - style_weights[0]

func update_chaos_temperature(delta: float) -> void:
	var target_temperature := 0.70
	for player_index in player_chaos_until:
		if elapsed < float(player_chaos_until[player_index]):
			target_temperature += CHAOS_TEMPERATURE_BONUS
	music_temperature = lerpf(music_temperature, clampf(target_temperature, 0.55, 0.95), clampf(delta * 2.0, 0.0, 1.0))

func register_perfect_attack(player: ArenaPlayerState) -> void:
	var current_beat := beat_number()
	perfect_attack_beats[player.index] = current_beat
	if elapsed < resonance_cooldown_until:
		return
	for other_player_index in perfect_attack_beats:
		if int(other_player_index) != player.index and int(perfect_attack_beats[other_player_index]) == current_beat:
			resonance_until = elapsed + RESONANCE_DURATION_SECONDS
			resonance_cooldown_until = elapsed + RESONANCE_COOLDOWN_SECONDS
			append_music_cue("resonance", {"players": [player.index, int(other_player_index)], "midi_notes": PackedInt32Array([60, 63, 67, 70]), "duration_beats": 2.0})
			return

func consume_melody_note(player: ArenaPlayerState) -> void:
	if not player_melody_ammo.has(player.index):
		return
	var notes: PackedInt32Array = player_melody_ammo[player.index]
	if notes.is_empty():
		return
	var note := notes[0]
	notes.remove_at(0)
	player_melody_ammo[player.index] = notes
	append_music_cue("melody_note", {"player": player.index, "midi_notes": PackedInt32Array([note]), "velocity": 100, "duration_beats": 0.45})
	if notes.is_empty():
		append_music_cue("melody_phrase_complete", {"player": player.index, "midi_notes": PackedInt32Array([note + 7]), "duration_beats": 0.8})

func update_network_player(delta: float, player_index: int, input: Dictionary) -> void:
	var player := players[player_index]
	if player.health <= 0:
		return
	var direction: Vector2 = input.get("movement", Vector2.ZERO)
	var facing: Vector2 = input.get("facing", player.facing)
	var owner_peer_id := player_owners[player_index]
	var charge_state: Dictionary = network_charge_states.get(owner_peer_id, {})
	if facing.length_squared() > 0.0:
		player.facing = facing.normalized()
	if bool(input.get("laser_held", false)):
		player.apply_slow(0.20, beat_clock.seconds_per_beat())
	player.tick(delta, direction.limit_length(1.0), geometry)
	for action in consume_network_actions(owner_peer_id):
		match action:
			"dash":
				player.dash()
			"shot":
				attack(player)
			"laser_pressed":
				charge_state["started_on_beat"] = is_within_laser_charge_window(LASER_CHARGE_START_WINDOW)
				charge_state["started_at_msec"] = network_time_msec()
				charge_state["release_beat"] = laser_charge_beat_number() + 1
				if bool(charge_state["started_on_beat"]):
					append_music_cue("laser_charge_root", {"player": player.index, "midi_notes": PackedInt32Array([48 + player.index * 2]), "velocity": 78, "duration_beats": 1.0})
			"laser_released":
				if bool(charge_state.get("started_on_beat", false)) and is_valid_network_laser_release(charge_state):
					fire_laser(player, network_laser_timing_quality(charge_state))
				else:
					append_music_cue("laser_charge_cancelled", {"player": player.index})
					attack(player)
				charge_state.clear()
			"laser_cancelled":
				charge_state.clear()
	network_charge_states[owner_peer_id] = charge_state

func is_valid_network_laser_release(input: Dictionary) -> bool:
	var release_offset := (calibrated_beat_position() - float(input.get("release_beat", -1))) * beat_clock.seconds_per_beat()
	var held_seconds := float(network_time_msec() - int(input.get("started_at_msec", network_time_msec()))) / 1000.0
	return held_seconds >= LASER_MIN_HOLD_TIME and release_offset >= -LASER_RELEASE_EARLY_WINDOW and release_offset <= LASER_RELEASE_LATE_WINDOW

func network_laser_timing_quality(input: Dictionary) -> float:
	var release_offset := (calibrated_beat_position() - float(input.get("release_beat", -1))) * beat_clock.seconds_per_beat()
	var tolerance := LASER_RELEASE_EARLY_WINDOW if release_offset < 0.0 else LASER_RELEASE_LATE_WINDOW
	return clampf(1.0 - absf(release_offset) / tolerance, 0.0, 1.0)

func get_direction() -> Vector2:
	var moving_left := Input.is_key_pressed(movement_keys[2]) or Input.is_key_pressed(movement_secondary_keys[2])
	var moving_right := Input.is_key_pressed(movement_keys[3]) or Input.is_key_pressed(movement_secondary_keys[3])
	var moving_up := Input.is_key_pressed(movement_keys[0]) or Input.is_key_pressed(movement_secondary_keys[0])
	var moving_down := Input.is_key_pressed(movement_keys[1]) or Input.is_key_pressed(movement_secondary_keys[1])
	return Vector2(
		float(moving_right) - float(moving_left),
		float(moving_down) - float(moving_up)
	).limit_length(1.0)

func beat_time() -> float:
	return calibrated_beat_position() * beat_clock.seconds_per_beat()

func calibrated_beat_position() -> float:
	return beat_clock.beat_position() - beat_offset_seconds / beat_clock.seconds_per_beat()

func beat_number() -> int:
	return roundi(calibrated_beat_position() * 2.0)

func laser_charge_beat_number() -> int:
	return roundi(calibrated_beat_position())

func is_within_laser_charge_window(window: float) -> bool:
	var beat_phase := posmod(calibrated_beat_position(), 1.0)
	var distance := minf(beat_phase, 1.0 - beat_phase) * beat_clock.seconds_per_beat()
	return distance <= window

func is_valid_laser_release() -> bool:
	var release_offset := (calibrated_beat_position() - float(charge_release_beat)) * beat_clock.seconds_per_beat()
	var held_long_enough := elapsed - charge_started_at >= LASER_MIN_HOLD_TIME
	return held_long_enough and release_offset >= -LASER_RELEASE_EARLY_WINDOW and release_offset <= LASER_RELEASE_LATE_WINDOW

func laser_timing_quality() -> float:
	var release_offset := (calibrated_beat_position() - float(charge_release_beat)) * beat_clock.seconds_per_beat()
	var tolerance: float = LASER_RELEASE_EARLY_WINDOW if release_offset < 0.0 else LASER_RELEASE_LATE_WINDOW
	return clampf(1.0 - absf(release_offset) / tolerance, 0.0, 1.0)

func setup_calibration_audio() -> void:
	calibration_audio_player = AudioStreamPlayer.new()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 48000.0
	generator.buffer_length = 0.35
	calibration_audio_player.stream = generator
	calibration_audio_player.volume_db = -8.0
	add_child(calibration_audio_player)

func start_calibration() -> void:
	calibration_active = true
	settings_open = false
	waiting_for_keybind = false
	calibration_taps.clear()
	calibration_last_beat = -1
	calibration_audio_frames_written = 0
	calibration_start_msec = Time.get_ticks_msec() + roundi(CALIBRATION_AUDIO_LEAD_SECONDS * 1000.0)
	calibration_audio_player.play()
	calibration_audio_playback = calibration_audio_player.get_stream_playback()
	calibration_result = "Listening: wait four clicks, then tap F / Enter / Space on the beat"

func stop_calibration(cancelled: bool = false) -> void:
	calibration_active = false
	calibration_audio_player.stop()
	calibration_audio_playback = null
	if cancelled:
		calibration_result = "Calibration cancelled — previous offset kept"
	settings_open = true
	settings_selection = 12
	if not lan_mode:
		reset_game()

func feed_calibration_audio() -> void:
	if calibration_audio_playback == null:
		return
	var available := calibration_audio_playback.get_frames_available()
	for frame_index in range(available):
		var generated_time := float(calibration_audio_frames_written) / 48000.0 - CALIBRATION_AUDIO_LEAD_SECONDS
		var amplitude := 0.0
		if generated_time >= 0.0:
			var beat_phase := fmod(generated_time, CALIBRATION_BEAT_SECONDS)
			if beat_phase < 0.038:
				var envelope := 1.0 - beat_phase / 0.038
				var click_frequency := 1040.0 if is_zero_approx(beat_phase) else 780.0
				amplitude = sin(TAU * click_frequency * generated_time) * envelope * 0.34
		calibration_audio_playback.push_frame(Vector2(amplitude, amplitude))
		calibration_audio_frames_written += 1

func register_calibration_tap() -> void:
	if not calibration_active:
		return
	var sample_time := float(Time.get_ticks_msec() - calibration_start_msec) / 1000.0
	if sample_time < 0.0:
		return
	var nearest_beat := roundi(sample_time / CALIBRATION_BEAT_SECONDS)
	if nearest_beat < CALIBRATION_COUNT_IN_BEATS or nearest_beat == calibration_last_beat:
		return
	calibration_last_beat = nearest_beat
	var error := sample_time - float(nearest_beat) * CALIBRATION_BEAT_SECONDS
	if absf(error) > CALIBRATION_MAX_ERROR_SECONDS:
		calibration_result = "Tap was too far from the beat — keep following the clicks"
		return
	calibration_taps.append(error)
	calibration_result = "Calibration: %d / %d valid taps · latest %+.0f ms" % [calibration_taps.size(), CALIBRATION_REQUIRED_TAPS, error * 1000.0]
	if calibration_taps.size() >= CALIBRATION_REQUIRED_TAPS:
		finish_calibration()

func finish_calibration() -> void:
	var offset := robust_calibration_offset()
	beat_offset_seconds = clampf(offset, -MAX_BEAT_OFFSET, MAX_BEAT_OFFSET)
	calibration_result = "Calibration saved: %+.0f ms from %d stable taps" % [beat_offset_seconds * 1000.0, calibration_taps.size()]
	stop_calibration()

func robust_calibration_offset() -> float:
	var sorted_samples: Array[float] = []
	sorted_samples.append_array(calibration_taps)
	sorted_samples.sort()
	var median := sorted_samples[sorted_samples.size() / 2]
	var deviations: Array[float] = []
	for sample in sorted_samples:
		deviations.append(absf(sample - median))
	deviations.sort()
	var median_deviation := deviations[deviations.size() / 2]
	var acceptance := maxf(0.018, median_deviation * 2.5)
	var total := 0.0
	var accepted_count := 0
	for sample in sorted_samples:
		if absf(sample - median) <= acceptance:
			total += sample
			accepted_count += 1
	if accepted_count < CALIBRATION_MIN_VALID_TAPS:
		return median
	return total / float(accepted_count)

func _unhandled_input(event: InputEvent) -> void:
	if calibration_active:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				stop_calibration(true)
			elif event.keycode == KEY_F or event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
				register_calibration_tap()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			register_calibration_tap()
		return
	if event is InputEventMouseButton:
		if settings_open:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				handle_settings_mouse_click(event.position)
			return
		if event.button_index != MOUSE_BUTTON_LEFT or winner != -1:
			return
		if lan_mode:
			if event.pressed:
				send_network_action("laser_pressed")
			else:
				send_network_action("laser_released")
			return
		if elapsed < 0.0 or players[0].health <= 0:
			return
		if event.pressed:
			charge_started_on_beat = is_within_laser_charge_window(LASER_CHARGE_START_WINDOW)
			charging_laser = charge_started_on_beat
			charge_started_at = elapsed
			charge_release_beat = laser_charge_beat_number() + 1
			if charge_started_on_beat:
				append_music_cue("laser_charge_root", {"player": 0, "midi_notes": PackedInt32Array([48]), "velocity": 78, "duration_beats": 1.0})
		else:
			charging_laser = false
			if charge_started_on_beat and is_valid_laser_release():
				fire_laser(players[0], laser_timing_quality())
			else:
				if charge_started_on_beat:
					append_music_cue("laser_charge_cancelled", {"player": 0})
				attack(players[0])
			charge_started_on_beat = false
			charge_release_beat = -1
		return
	if event is InputEventKey and not event.pressed:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		settings_open = not settings_open
		waiting_for_keybind = false
		if settings_open:
			disable_local_gameplay_for_settings()
		return
	if settings_open:
		handle_settings_input(event.keycode)
		return
	if event.keycode == KEY_H and not lan_mode:
		host_lan_game()
		return
	if event.keycode == KEY_J and not lan_mode:
		join_lan_game()
		return
	if event.keycode == KEY_R:
		if lan_mode:
			request_lan_restart()
		else:
			reset_game()
		return
	if event.keycode == KEY_BRACKETLEFT:
		beat_offset_seconds = maxf(-MAX_BEAT_OFFSET, beat_offset_seconds - BEAT_OFFSET_STEP)
		return
	if event.keycode == KEY_BRACKETRIGHT:
		beat_offset_seconds = minf(MAX_BEAT_OFFSET, beat_offset_seconds + BEAT_OFFSET_STEP)
		return
	if event.keycode == KEY_BACKSLASH:
		beat_offset_seconds = 0.0
		return
	if winner != -1:
		return
	if lan_mode:
		if event.keycode == attack_key or event.keycode == attack_secondary_key:
			send_network_action("shot")
		elif event.keycode == dash_key or event.keycode == dash_secondary_key:
			send_network_action("dash")
		return
	if elapsed < 0.0 or winner != -1:
		return
	if event.keycode == attack_key or event.keycode == attack_secondary_key:
		attack(players[0])
	elif event.keycode == dash_key or event.keycode == dash_secondary_key:
		players[0].dash()

func handle_settings_input(keycode: Key) -> void:
	if waiting_for_keybind:
		if keycode == KEY_ESCAPE:
			waiting_for_keybind = false
			return
		if settings_selection < 8:
			var movement_index: int = int(settings_selection / 2)
			if posmod(settings_selection, 2) == 0:
				movement_keys[movement_index] = keycode
			else:
				movement_secondary_keys[movement_index] = keycode
		elif settings_selection == 8:
			attack_key = keycode
		elif settings_selection == 9:
			attack_secondary_key = keycode
		elif settings_selection == 10:
			dash_key = keycode
		elif settings_selection == 11:
			dash_secondary_key = keycode
		waiting_for_keybind = false
		return
	if keycode == KEY_UP:
		settings_selection = posmod(settings_selection - 1, 14)
	elif keycode == KEY_DOWN:
		settings_selection = posmod(settings_selection + 1, 14)
	elif keycode == KEY_ENTER and settings_selection < 12:
		waiting_for_keybind = true
	elif settings_selection == 12 and keycode == KEY_ENTER:
		start_calibration()
	elif settings_selection == 13 and (keycode == KEY_LEFT or keycode == KEY_RIGHT):
		adjust_selected_setting(-1 if keycode == KEY_LEFT else 1)

func handle_settings_mouse_click(mouse_position: Vector2) -> void:
	var clicked_row := get_settings_row_at(mouse_position)
	if clicked_row < 0:
		return
	settings_selection = clicked_row
	waiting_for_keybind = false
	if clicked_row == 12:
		start_calibration()
	elif clicked_row == 13 and mouse_position.x >= 1090.0:
		adjust_selected_setting(-1 if mouse_position.x < 1260.0 else 1)

func get_settings_row_at(mouse_position: Vector2) -> int:
	if mouse_position.x < 550.0 or mouse_position.x > 1450.0 or mouse_position.y < 220.0 or mouse_position.y >= 1088.0:
		return -1
	return clampi(floori((mouse_position.y - 220.0) / 62.0), 0, 13)

func adjust_selected_setting(direction: int, allow_repeat: bool = false) -> void:
	if settings_selection == 13:
		if lan_mode:
			adjust_lan_bot_count(direction)
			return
		bot_count = clampi(bot_count + direction, 0, 3)
		reset_game()

func adjust_lan_bot_count(direction: int) -> void:
	if not lan_is_host:
		lan_status = "Host controls room settings"
		return
	var updated_bot_count := clampi(bot_count + direction, 0, MAX_ENTITIES - 1)
	if updated_bot_count == bot_count:
		return
	bot_count = updated_bot_count
	restart_lan_match()

func disable_local_gameplay_for_settings() -> void:
	queued_shot = false
	queued_dash = false
	queued_laser_pressed = false
	queued_laser_released = false
	charging_laser = false
	charge_started_on_beat = false
	charge_release_beat = -1
	var local_player_index := 0
	if lan_mode:
		local_player_index = player_owners.find(multiplayer.get_unique_id())
	if local_player_index >= 0 and local_player_index < players.size():
		players[local_player_index].movement_velocity = Vector2.ZERO
		players[local_player_index].dash_time = 0.0
	if lan_mode:
		send_network_action("laser_cancelled")

func update_ai(delta: float, bot_index: int) -> void:
	var bot := players[bot_index]
	if bot.health <= 0:
		return
	var target := find_ai_target(bot)
	var offset := target.position - bot.position
	var distance := offset.length()
	var has_direct_sight := not path_blocked(bot.position, target.position)
	var has_open_fire_lane := has_direct_sight and is_ai_in_open_fire_lane(bot.position)
	var state_index := get_ai_state_index(bot_index)
	if elapsed >= ai_next_aim_updates[state_index]:
		ai_target_facings[state_index] = find_ai_aim_direction(bot.position, target.position, has_direct_sight)
		ai_aim_errors[state_index] = randf_range(-0.22, 0.22) if has_direct_sight else randf_range(-AI_BOUNCE_AIM_ERROR, AI_BOUNCE_AIM_ERROR)
		ai_next_aim_updates[state_index] = elapsed + AI_AIM_UPDATE_INTERVAL
	var desired_aim := ai_target_facings[state_index].rotated(ai_aim_errors[state_index])
	var aim_turn := clampf(bot.facing.angle_to(desired_aim), -AI_AIM_TURN_SPEED * delta, AI_AIM_TURN_SPEED * delta)
	bot.facing = bot.facing.rotated(aim_turn)
	if elapsed >= ai_next_path_updates[state_index] or ai_waypoints[state_index].distance_to(bot.position) < 48.0:
		var attack_position := find_ai_attack_position(bot.position, target.position)
		ai_waypoints[state_index] = find_ai_waypoint(bot.position, attack_position)
		ai_next_path_updates[state_index] = elapsed + 0.55
	var direction := find_ai_steering_direction(bot, ai_waypoints[state_index])
	bot.tick(delta, direction, geometry)
	var current_beat := floori(calibrated_beat_position() * 2.0)
	if current_beat != ai_last_attack_beats[state_index] and ai_scheduled_shot_times[state_index] < 0.0:
		ai_last_attack_beats[state_index] = current_beat
		ai_scheduled_shot_times[state_index] = -1.0
		ai_scheduled_lasers[state_index] = false
		var fire_chance := 1.0 if has_open_fire_lane else (AI_FIRE_CHANCE if has_direct_sight else AI_BOUNCE_FIRE_CHANCE)
		if distance < AI_FIRE_RANGE and randf() < fire_chance:
			ai_scheduled_shot_times[state_index] = float(current_beat + 1) * 0.5 + randf_range(-AI_TIMING_JITTER, AI_TIMING_JITTER) / beat_clock.seconds_per_beat()
			ai_scheduled_lasers[state_index] = has_direct_sight and distance > 480.0 and randf() < AI_LASER_CHANCE
	if ai_scheduled_shot_times[state_index] >= 0.0 and calibrated_beat_position() >= ai_scheduled_shot_times[state_index]:
		if distance < AI_FIRE_RANGE:
			if ai_scheduled_lasers[state_index]:
				fire_laser(bot)
			else:
				attack(bot)
		ai_scheduled_shot_times[state_index] = -1.0
		ai_scheduled_lasers[state_index] = false
	if distance < 310.0 and bot.dash_cooldown <= 0.0:
		bot.dash()

func get_ai_state_index(bot_index: int) -> int:
	if not lan_mode:
		return bot_index - 1
	var state_index := 0
	for player_index in range(bot_index):
		if player_index < player_owners.size() and player_owners[player_index] < 0:
			state_index += 1
	return state_index

func find_ai_target(bot: ArenaPlayerState) -> ArenaPlayerState:
	var target := players[0]
	var closest_distance := INF
	for candidate in players:
		if candidate.index == bot.index or candidate.health <= 0:
			continue
		var distance := bot.position.distance_to(candidate.position)
		if distance < closest_distance:
			closest_distance = distance
			target = candidate
	return target

func find_ai_attack_position(start: Vector2, target: Vector2) -> Vector2:
	var current_distance := start.distance_to(target)
	if current_distance >= 480.0 and current_distance <= 960.0 and not path_blocked(start, target):
		return start
	var best_position := Vector2.ZERO
	var best_cost := INF
	for distance_index in range(3):
		var candidate_distance: float = 540.0 + 160.0 * float(distance_index)
		for sample_index in range(16):
			var angle: float = TAU * float(sample_index) / 16.0
			var candidate: Vector2 = target + Vector2.RIGHT.rotated(angle) * candidate_distance
			if not is_valid_ai_position(candidate) or path_blocked(candidate, target):
				continue
			var route_cost: float = start.distance_to(candidate)
			if path_blocked(start, candidate):
				route_cost += 520.0
			var angle_bonus: float = absf(sin(angle)) * 40.0
			var cost: float = route_cost - angle_bonus
			if cost < best_cost:
				best_cost = cost
				best_position = candidate
	if best_cost < INF:
		return best_position
	return find_ai_flank_position(start, target)

func find_ai_flank_position(start: Vector2, target: Vector2) -> Vector2:
	var best_position := target
	var best_cost := INF
	for wall in walls:
		var clearance := 100.0
		var corners: Array[Vector2] = [
			wall.position + Vector2(-clearance, -clearance),
			wall.position + Vector2(wall.size.x + clearance, -clearance),
			wall.position + Vector2(-clearance, wall.size.y + clearance),
			wall.end + Vector2(clearance, clearance),
		]
		for corner in corners:
			if not is_valid_ai_position(corner) or path_blocked(start, corner):
				continue
			var cost: float = start.distance_to(corner) + corner.distance_to(target) * 0.65
			if cost < best_cost:
				best_cost = cost
				best_position = corner
	return best_position

func find_ai_steering_direction(bot: ArenaPlayerState, goal: Vector2) -> Vector2:
	var to_goal := goal - bot.position
	if to_goal.length_squared() < 1.0:
		to_goal = players[0].position - bot.position
	if to_goal.length_squared() < 1.0:
		return Vector2.ZERO
	var base_direction := to_goal.normalized()
	var best_direction := Vector2.ZERO
	var best_score := -INF
	for turn_index in range(-4, 5):
		var candidate := base_direction.rotated(float(turn_index) * 0.35)
		if not can_ai_step(bot, candidate):
			continue
		var score := candidate.dot(base_direction) + randf_range(-0.03, 0.03)
		if score > best_score:
			best_score = score
			best_direction = candidate
	if best_direction.length_squared() > 0.0:
		return best_direction
	return find_ai_escape_direction(bot, base_direction)

func can_ai_step(bot: ArenaPlayerState, direction: Vector2) -> bool:
	for probe_index in range(3):
		var probe_distance: float = 24.0 + 24.0 * float(probe_index * probe_index)
		if geometry.overlaps_circle(bot.position + direction * probe_distance):
			return false
	return true

func find_ai_escape_direction(bot: ArenaPlayerState, preferred_direction: Vector2) -> Vector2:
	var best_direction := Vector2.ZERO
	var best_score := -INF
	for turn_index in range(16):
		var candidate := Vector2.RIGHT.rotated(TAU * float(turn_index) / 16.0)
		if not can_ai_step(bot, candidate):
			continue
		var score := candidate.dot(preferred_direction)
		if score > best_score:
			best_score = score
			best_direction = candidate
	return best_direction

func is_valid_ai_position(point: Vector2) -> bool:
	if point.x < PLAYER_RADIUS or point.x > ARENA_SIZE.x - PLAYER_RADIUS or point.y < PLAYER_RADIUS or point.y > ARENA_SIZE.y - PLAYER_RADIUS:
		return false
	for wall in walls:
		if wall.grow(PLAYER_RADIUS).has_point(point):
			return false
	return true

func is_ai_in_open_fire_lane(position: Vector2) -> bool:
	var open_clearance := PLAYER_RADIUS + 120.0
	if position.x < open_clearance or position.x > ARENA_SIZE.x - open_clearance or position.y < open_clearance or position.y > ARENA_SIZE.y - open_clearance:
		return false
	for wall in walls:
		if wall.grow(open_clearance).has_point(position):
			return false
	return true

func find_ai_aim_direction(start: Vector2, target: Vector2, has_direct_sight: bool) -> Vector2:
	var direct_direction := (target - start).normalized()
	if has_direct_sight:
		return direct_direction
	var best_direction := direct_direction
	var best_distance := INF
	for sample_index in range(72):
		var angle := TAU * float(sample_index) / 72.0
		var candidate_direction := Vector2.RIGHT.rotated(angle)
		var path := geometry.build_laser_path(start, candidate_direction)
		for segment_index in range(path.size() - 1):
			var distance_to_path := geometry.point_segment_distance(target, path[segment_index], path[segment_index + 1])
			if distance_to_path < best_distance:
				best_distance = distance_to_path
				best_direction = candidate_direction
	return best_direction

func find_ai_waypoint(start: Vector2, goal: Vector2) -> Vector2:
	if not path_blocked(start, goal):
		return goal
	var best_waypoint := goal
	var best_cost := INF
	for wall in walls:
		var clearance := 92.0
		var corners: Array[Vector2] = [
			wall.position + Vector2(-clearance, -clearance),
			wall.position + Vector2(wall.size.x + clearance, -clearance),
			wall.position + Vector2(-clearance, wall.size.y + clearance),
			wall.end + Vector2(clearance, clearance),
		]
		for corner in corners:
			if corner.x < PLAYER_RADIUS or corner.x > ARENA_SIZE.x - PLAYER_RADIUS or corner.y < PLAYER_RADIUS or corner.y > ARENA_SIZE.y - PLAYER_RADIUS:
				continue
			if not path_blocked(start, corner):
				var cost := start.distance_to(corner) + corner.distance_to(goal)
				if cost < best_cost:
					best_cost = cost
					best_waypoint = corner
	return best_waypoint

func path_blocked(start: Vector2, end: Vector2) -> bool:
	return geometry.path_blocked(start, end)

func start_countdown_number() -> int:
	if lan_mode:
		if match_start_server_msec == 0:
			return 0
		var local_start_msec := match_start_server_msec if lan_is_host else server_to_local_msec(match_start_server_msec)
		return maxi(0, ceili(float(local_start_msec - Time.get_ticks_msec()) / 1000.0))
	return maxi(0, ceili(-elapsed))

func timing_grade() -> Array:
	var nearest_half_beat := roundi(calibrated_beat_position() * 2.0) * 0.5
	var distance := absf(calibrated_beat_position() - nearest_half_beat) * beat_clock.seconds_per_beat()
	if distance <= PERFECT_WINDOW:
		return ["perfect", 22]
	if distance <= GOOD_WINDOW:
		return ["good", 17]
	if distance <= WEAK_WINDOW:
		return ["weak", 10]
	return ["off", 4]

func attack(player: ArenaPlayerState) -> void:
	if player.health <= 0 or player.attack_cooldown > 0.0 or player.overheat > 0.0:
		return
	var grade_data := timing_grade()
	var grade: String = grade_data[0]
	var base_damage: int = grade_data[1]
	var beat := beat_number()
	var repeated_same_beat := beat == player.recent_beat
	var rapid := elapsed - player.last_attack_time < 0.13
	var penalty := 0.0
	if grade == "weak" or grade == "off":
		penalty += 1.3
	if repeated_same_beat:
		penalty += 2.0
	if rapid:
		penalty += 1.2
	player.fatigue = minf(10.0, player.fatigue + penalty)
	player.recent_beat = beat
	player.last_attack_time = elapsed
	var fatigue_scale := 1.0 if player.fatigue < 7.0 else 0.55
	var damage := maxi(1, roundi(base_damage * fatigue_scale))
	last_attack_feedback = "%s  %d DMG" % [grade.to_upper(), damage]
	last_attack_feedback_until = elapsed + 0.55
	var speed: float
	var radius: float
	var brightness: float
	match grade:
		"perfect":
			speed = 1472.0 * SPEED_MULTIPLIER
			radius = 22.0
			brightness = 1.0
		"good":
			speed = 1312.0 * SPEED_MULTIPLIER
			radius = 20.0
			brightness = 0.80
		"weak":
			speed = 1058.0 * SPEED_MULTIPLIER
			radius = 18.0
			brightness = 0.57
		_:
			speed = 886.0 * SPEED_MULTIPLIER
			radius = 16.0
			brightness = 0.37
	player.attack_cooldown = 0.10 if grade == "perfect" or grade == "good" else 0.16
	player.apply_slow(0.10, beat_clock.seconds_per_beat())
	var color := player.tint.darkened(1.0 - brightness)
	projectiles.append(ArenaProjectileState.new(player.position + player.facing * (44.0 + radius), player.facing * speed, player.index, damage, radius, color))
	if grade == "perfect":
		register_perfect_attack(player)
	if grade == "perfect" or grade == "good":
		consume_melody_note(player)
	if player.fatigue >= 10.0:
		player.overheat = 1.0
		player.fatigue = 6.0

func fire_laser(player: ArenaPlayerState, timing_quality: float = 0.72) -> void:
	if player.health <= 0 or player.overheat > 0.0 or player.attack_cooldown > 0.0:
		return
	laser_points = geometry.build_laser_path(player.position + player.facing * PLAYER_RADIUS, player.facing)
	laser_flash_time = 0.14
	laser_tint = player.tint
	laser_damage = roundi(4.0 + 36.0 * timing_quality)
	laser_width = 10.0 + 12.0 * timing_quality
	laser_brightness = 0.40 + 0.60 * timing_quality
	var root_note := 48 + player.index * 2
	var chord_notes := PackedInt32Array([root_note, root_note + 3, root_note + 7])
	if timing_quality >= 0.92:
		chord_notes.append(root_note + 10)
	append_music_cue("laser_chord", {"player": player.index, "midi_notes": chord_notes, "velocity": roundi(70.0 + timing_quality * 55.0), "duration_beats": 1.25, "quality": timing_quality})
	player.attack_cooldown = 0.45
	player.fatigue = maxf(0.0, player.fatigue - 1.5)
	for target in players:
		if target.index == player.index or target.health <= 0:
			continue
		for segment_index in range(laser_points.size() - 1):
			if geometry.point_segment_distance(target.position, laser_points[segment_index], laser_points[segment_index + 1]) <= PLAYER_RADIUS + 16.0:
				target.health = maxi(0, target.health - laser_damage)
				target.flash = 0.18
				target.position = geometry.move_circle(target.position, (laser_points[segment_index + 1] - laser_points[segment_index]).normalized() * 56.0)
				if target.health <= 0:
					check_match_winner()
				break

func update_projectiles(delta: float) -> void:
	var remaining: Array[ArenaProjectileState] = []
	for projectile in projectiles:
		var step_count := maxi(1, ceili(projectile.velocity.length() * delta / MAX_MOVEMENT_STEP))
		var hit := false
		for step_index in range(step_count):
			projectile.tick(delta / float(step_count))
			if geometry.bounce_projectile(projectile):
				hit = true
				break
			for player in players:
				if player.index == projectile.owner or player.health <= 0:
					continue
				if projectile.position.distance_to(player.position) < projectile.radius + PLAYER_RADIUS:
					player.health = maxi(0, player.health - projectile.damage)
					player.flash = 0.12
					var push := (player.position - projectile.position).normalized()
					player.position = geometry.move_circle(player.position, push * 36.0)
					hit = true
					if player.health <= 0:
						check_match_winner()
					break
			if hit:
				break
		if not hit:
			remaining.append(projectile)
	projectiles = remaining

func check_match_winner() -> void:
	var survivor_index := -1
	var survivor_count := 0
	for player in players:
		if player.health > 0:
			survivor_index = player.index
			survivor_count += 1
	if survivor_count == 1:
		winner = survivor_index

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * WORLD_RENDER_SCALE)
	draw_rect(Rect2(Vector2.ZERO, ARENA_SIZE), BACKGROUND)
	for x in range(0, int(ARENA_SIZE.x) + 1, 100):
		draw_line(Vector2(x, 0), Vector2(x, ARENA_SIZE.y), GRID, 1.0)
	for y in range(0, int(ARENA_SIZE.y) + 1, 100):
		draw_line(Vector2(0, y), Vector2(ARENA_SIZE.x, y), GRID, 1.0)
	draw_rect(Rect2(Vector2(6, 6), ARENA_SIZE - Vector2(12, 12)), Color("a8b3c7"), false, 8.0)
	for wall in walls:
		draw_rect(wall, Color("596171"), true)
		draw_rect(wall, Color("9ca5b5"), false, 4.0)
	var capture_color := Color("4b5366") if capture_owner < 0 or capture_owner >= players.size() else players[capture_owner].tint
	if capture_contested:
		capture_color = Color("f7ae4f")
	draw_circle(ARENA_SIZE / 2.0, CAPTURE_RADIUS, Color(capture_color, 0.12))
	draw_arc(ARENA_SIZE / 2.0, CAPTURE_RADIUS, 0.0, TAU, 48, Color(capture_color, 0.85), 5.0)
	for pickup in pickups:
		if not bool(pickup.get("active", false)):
			continue
		var pickup_position: Vector2 = pickup.get("position", Vector2.ZERO)
		var pickup_kind := str(pickup.get("kind", ""))
		var pickup_color := Color("d58cff") if pickup_kind == "melody" else Color("f7ae4f")
		draw_circle(pickup_position, 27.0, Color(pickup_color, 0.20))
		draw_circle(pickup_position, 17.0, pickup_color)
		draw_string(font, pickup_position + Vector2(-20.0, 8.0), "♪" if pickup_kind == "melody" else "?", HORIZONTAL_ALIGNMENT_CENTER, 40, 28, BACKGROUND)
	for player in players:
		if player.health <= 0:
			var corpse_color := player.tint.darkened(0.78)
			draw_circle(player.position, PLAYER_RADIUS, corpse_color)
			draw_arc(player.position, PLAYER_RADIUS, 0.0, TAU, 32, Color(corpse_color.lightened(0.22), 0.55), 3.0)
	var full_beat_phase := posmod(calibrated_beat_position(), 1.0)
	var pulse_window := 0.13 / beat_clock.seconds_per_beat()
	var pulse := maxf(0.0, 1.0 - full_beat_phase / pulse_window) if full_beat_phase < pulse_window else 0.0
	draw_arc(ARENA_SIZE / 2.0, 140.0 + pulse * 76.0, 0.0, TAU, 64, Color("414654"), 4.0)
	draw_arc(ARENA_SIZE / 2.0, 140.0, 0.0, TAU, 64, Color("2d313e"), 2.0)
	for projectile in projectiles:
		draw_circle(projectile.position, projectile.radius, projectile.tint)
		draw_arc(projectile.position, projectile.radius, 0.0, TAU, 24, TEXT, 1.0)
	if laser_flash_time > 0.0 and laser_points.size() >= 2:
		var laser_alpha := laser_flash_time / 0.14
		for segment_index in range(laser_points.size() - 1):
			draw_line(laser_points[segment_index], laser_points[segment_index + 1], Color(laser_tint.darkened(1.0 - laser_brightness), laser_alpha), laser_width)
			draw_line(laser_points[segment_index], laser_points[segment_index + 1], Color(laser_tint.lightened(0.35 * laser_brightness), laser_alpha), laser_width * 0.24)
	for player in players:
		if player.health <= 0:
			continue
		var display_color := Color.WHITE if player.flash > 0.0 else player.tint
		if player.dash_time > 0.0:
			draw_circle(player.position - player.dash_direction * 56.0, 30.0, Color(player.tint, 0.28))
		draw_circle(player.position, PLAYER_RADIUS, display_color)
		draw_arc(player.position, PLAYER_RADIUS, 0.0, TAU, 32, TEXT, 4.0)
		draw_line(player.position, player.position + player.facing * 28.0, BACKGROUND, 6.0)
		var visual_attack_phase: float = calibrated_beat_position() * 2.0
		var beat_fill: float = 0.5 - 0.5 * cos(PI * visual_attack_phase)
		var beat_bar := Rect2(player.position + Vector2(-58.0, -88.0), Vector2(116.0, 12.0))
		var beat_glow: float = pow(absf(cos(PI * visual_attack_phase)), 6.0)
		var beat_color := player.tint.darkened(0.12).lerp(player.tint.lightened(0.35), beat_glow)
		var beat_marker_x: float = beat_bar.position.x + 12.0 + 92.0 * beat_fill
		var beat_marker := Rect2(beat_marker_x - 10.0, beat_bar.position.y + 2.0, 20.0, 8.0)
		draw_rect(beat_bar, Color("252a35"), true)
		draw_rect(beat_bar, TEXT, false, 2.0)
		draw_rect(beat_marker, beat_color, true)
		draw_rect(beat_marker, Color("f5f7fb").lerp(beat_color, 0.45), false, 1.0)
		var fatigue_color := Color("f7ae4f") if player.fatigue < 7.0 else Color("f66060")
		draw_arc(player.position, 56.0, -PI / 2.0, -PI / 2.0 + TAU * player.fatigue / 10.0, 32, fatigue_color, 6.0)
		var charge_is_active := player.index == 0 and charging_laser
		var visual_release_beat := charge_release_beat
		if lan_mode and player.index < player_owners.size():
			var network_charge_state: Dictionary = network_charge_states.get(player_owners[player.index], {})
			charge_is_active = bool(network_charge_state.get("started_on_beat", false))
			visual_release_beat = int(network_charge_state.get("release_beat", -1))
		if charge_is_active:
			var charge_ratio: float = clampf(calibrated_beat_position() - float(visual_release_beat - 1), 0.0, 1.0)
			var dissipate_ratio: float = clampf((calibrated_beat_position() - float(visual_release_beat)) * beat_clock.seconds_per_beat() / LASER_DISSIPATE_TIME, 0.0, 1.0)
			var charge_alpha: float = (0.35 + charge_ratio * 0.65) * (1.0 - dissipate_ratio)
			var charge_color := player.tint.lightened(0.28) if charge_ratio >= 1.0 else Color("b7c4d5")
			var side: Vector2 = Vector2(-player.facing.y, player.facing.x)
			for lane_index in range(3):
				var lane: float = float(lane_index - 1)
				var spread: float = lane * 96.0 * (1.0 - charge_ratio + dissipate_ratio)
				var line_start: Vector2 = player.position + player.facing * 250.0 + side * spread
				var line_end: Vector2 = player.position + player.facing * 60.0 + side * spread * 0.15
				draw_line(line_start, line_end, Color(charge_color, charge_alpha), (4.0 + charge_ratio * 4.0) * (1.0 - dissipate_ratio * 0.45))
			draw_circle(player.position, 10.0 + charge_ratio * 14.0, Color(charge_color, 0.28 * (1.0 - dissipate_ratio)))
		if player.overheat > 0.0:
			draw_string(font, player.position + Vector2(-76, -84), "OVERHEAT", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("f66060"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var style_bar := Rect2(650.0, 18.0, 700.0, 22.0)
	draw_rect(style_bar, Color("ff7882"), true)
	draw_rect(Rect2(style_bar.position, Vector2(style_bar.size.x * style_weights[0], style_bar.size.y)), Color("57b0ff"), true)
	draw_rect(style_bar, TEXT, false, 2.0)
	draw_string(font, Vector2(760.0, 62.0), "STYLE  P1 %.0f%%  /  P2 %.0f%%" % [style_weights[0] * 100.0, style_weights[1] * 100.0], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, TEXT)
	var capture_label := "CENTER: contested" if capture_contested else ("CENTER: P%d healing" % (capture_owner + 1) if capture_owner >= 0 and capture_hold_time >= CAPTURE_ACTIVATION_SECONDS else "CENTER: neutral")
	draw_string(font, Vector2(760.0, 88.0), "%s · BPM %.1f · temperature %.2f" % [capture_label, beat_clock.current_bpm(), music_temperature], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("bec3cf"))
	if capture_owner >= 0 and not capture_contested and capture_hold_time >= CAPTURE_ACTIVATION_SECONDS:
		draw_string(font, Vector2(0, 126), "CENTER CONTROL · P%d +%.0f HP/s" % [capture_owner + 1, CAPTURE_HEAL_PER_SECOND], HORIZONTAL_ALIGNMENT_CENTER, int(DISPLAY_SIZE.x), 24, Color("8ee6bc"))
	if elapsed < last_attack_feedback_until:
		var feedback_color := Color("72dbff") if last_attack_feedback.begins_with("PERFECT") else (Color("8ee6bc") if last_attack_feedback.begins_with("GOOD") else (Color("f7ae4f") if last_attack_feedback.begins_with("WEAK") else Color("f66060")))
		draw_string(font, Vector2(0, 1170), last_attack_feedback, HORIZONTAL_ALIGNMENT_CENTER, int(DISPLAY_SIZE.x), 32, feedback_color)
	for player in players:
		var x := 60.0 + 480.0 * float(player.index)
		draw_string(font, Vector2(x, 56), "P%d  %d / %d" % [player.index + 1, player.health, MAX_HEALTH], HORIZONTAL_ALIGNMENT_LEFT, -1, 36, TEXT)
		draw_rect(Rect2(x, 76, 380, 28), Color("303540"), true)
		draw_rect(Rect2(x + 4.0, 80, 372.0 * float(player.health) / MAX_HEALTH, 20), player.tint, true)
		draw_rect(Rect2(x, 76, 380, 28), TEXT, false, 2.0)
		draw_string(font, Vector2(x, 144), "fatigue %.1f / 10" % player.fatigue, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("bec3cf"))
	if not is_combat_started() or winner != -1:
		draw_string(font, Vector2(300, 1212), lan_status, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("72dbff"))
		draw_string(font, Vector2(300, 1260), "Music latency: %+.0f ms · [ / ] manually adjust · \\ reset" % (beat_offset_seconds * 1000.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("bec3cf"))
		draw_string(font, Vector2(300, 1308), "Mouse: aim / charge laser · %s / %s: shot · %s / %s: dash · Esc: settings" % [OS.get_keycode_string(attack_key), OS.get_keycode_string(attack_secondary_key), OS.get_keycode_string(dash_key), OS.get_keycode_string(dash_secondary_key)], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("bec3cf"))
	var countdown := start_countdown_number()
	if countdown > 0 and not settings_open:
		draw_string(font, Vector2(0, 640), str(countdown), HORIZONTAL_ALIGNMENT_CENTER, int(DISPLAY_SIZE.x), 144, Color("72dbff"))
	if winner != -1:
		draw_string(font, Vector2(0, ARENA_SIZE.y / 2.0), "PLAYER %d WINS — press R to restart" % (winner + 1), HORIZONTAL_ALIGNMENT_CENTER, int(ARENA_SIZE.x), 42, TEXT)
	if settings_open:
		draw_settings_panel()
	if calibration_active:
		draw_calibration_overlay()

func draw_calibration_overlay() -> void:
	draw_rect(Rect2(0, 0, DISPLAY_SIZE.x, DISPLAY_SIZE.y), Color(0.03, 0.04, 0.07, 0.94), true)
	var sample_time := float(Time.get_ticks_msec() - calibration_start_msec) / 1000.0
	var beat_index := maxi(0, floori(sample_time / CALIBRATION_BEAT_SECONDS))
	var beat_phase := posmod(sample_time, CALIBRATION_BEAT_SECONDS) / CALIBRATION_BEAT_SECONDS
	var pulse := 1.0 - beat_phase
	var pulse_color := Color("72dbff").lerp(Color("f3f7ff"), pulse)
	draw_circle(DISPLAY_SIZE / 2.0, 90.0 + pulse * 110.0, Color(pulse_color, 0.18))
	draw_circle(DISPLAY_SIZE / 2.0, 48.0 + pulse * 30.0, pulse_color)
	draw_string(font, Vector2(0, 370), "MUSIC LATENCY CALIBRATION · 120 BPM", HORIZONTAL_ALIGNMENT_CENTER, int(DISPLAY_SIZE.x), 42, TEXT)
	var instruction := "Listen: %d / %d" % [beat_index + 1, CALIBRATION_COUNT_IN_BEATS] if beat_index < CALIBRATION_COUNT_IN_BEATS else "Tap F / Enter / Space / Left Click on each click"
	draw_string(font, Vector2(0, 450), instruction, HORIZONTAL_ALIGNMENT_CENTER, int(DISPLAY_SIZE.x), 32, Color("bec3cf"))
	draw_string(font, Vector2(0, 510), "%d / %d valid taps" % [calibration_taps.size(), CALIBRATION_REQUIRED_TAPS], HORIZONTAL_ALIGNMENT_CENTER, int(DISPLAY_SIZE.x), 38, pulse_color)
	draw_string(font, Vector2(0, 580), calibration_result, HORIZONTAL_ALIGNMENT_CENTER, int(DISPLAY_SIZE.x), 28, TEXT)
	draw_string(font, Vector2(0, 1160), "Esc: cancel · signed result accounts for your audio/display path", HORIZONTAL_ALIGNMENT_CENTER, int(DISPLAY_SIZE.x), 24, Color("bec3cf"))

func draw_settings_panel() -> void:
	draw_rect(Rect2(500, 110, 1000, 1140), Color(0.05, 0.06, 0.09, 0.96), true)
	draw_rect(Rect2(500, 110, 1000, 1140), Color("a8b3c7"), false, 4.0)
	draw_string(font, Vector2(580, 180), "SETTINGS", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, TEXT)
	var labels: Array[String] = ["Move up — Primary", "Move up — Secondary", "Move down — Primary", "Move down — Secondary", "Move left — Primary", "Move left — Secondary", "Move right — Primary", "Move right — Secondary", "Normal shot — Primary", "Normal shot — Secondary", "Dash — Primary", "Dash — Secondary", "Music latency calibration", "AI opponents — Host only" if lan_mode else "AI opponents"]
	for row in range(14):
		var y: float = 260.0 + 62.0 * float(row)
		var selected := row == settings_selection
		var locked_shared_setting := lan_mode and not lan_is_host and row == 13
		var color := Color("657282") if locked_shared_setting else (Color("72dbff") if selected else TEXT)
		var value := ""
		if row < 8:
			var movement_index: int = int(row / 2)
			value = OS.get_keycode_string(movement_keys[movement_index] if posmod(row, 2) == 0 else movement_secondary_keys[movement_index])
		elif row == 8:
			value = OS.get_keycode_string(attack_key)
		elif row == 9:
			value = OS.get_keycode_string(attack_secondary_key)
		elif row == 10:
			value = OS.get_keycode_string(dash_key)
		elif row == 11:
			value = OS.get_keycode_string(dash_secondary_key)
		elif row == 12:
			value = "RUN · current %+.0f ms" % (beat_offset_seconds * 1000.0)
		else:
			value = "%d" % bot_count
		if selected:
			draw_rect(Rect2(550, y - 43.0, 900, 52), Color("243448"), true)
			draw_rect(Rect2(550, y - 43.0, 900, 52), Color("72dbff"), false, 2.0)
		draw_string(font, Vector2(610, y), ("> " if selected else "  ") + labels[row], HORIZONTAL_ALIGNMENT_LEFT, -1, 32, color)
		if row == 12:
			var calibration_rect := Rect2(1090, y - 40.0, 340, 42)
			draw_rect(calibration_rect, Color("31506b") if selected else Color("2b3442"), true)
			draw_rect(calibration_rect, color, false, 2.0)
			draw_string(font, Vector2(1138, y - 8.0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, color)
		elif row == 13:
			var minus_rect := Rect2(1090, y - 40.0, 70, 42)
			var plus_rect := Rect2(1360, y - 40.0, 70, 42)
			var button_color := Color("202934") if locked_shared_setting else (Color("31506b") if selected else Color("2b3442"))
			draw_rect(minus_rect, button_color, true)
			draw_rect(plus_rect, button_color, true)
			draw_rect(minus_rect, color, false, 2.0)
			draw_rect(plus_rect, color, false, 2.0)
			draw_string(font, Vector2(1114, y - 8.0), "−", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, color)
			draw_string(font, Vector2(1380, y - 8.0), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, color)
			draw_string(font, Vector2(1190, y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, color)
		else:
			draw_string(font, Vector2(1120, y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, color)
	var help := "Press a key to bind" if waiting_for_keybind else "Calibration: Enter/click Run · AI: Click −/+ or Left/Right · Esc: close"
	if lan_mode:
		help = "Calibration is local · AI is shared: host changes restart and sync the room" if lan_is_host else "Calibration is local · only the host can change AI"
	draw_string(font, Vector2(580, 1200), help, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("bec3cf"))
