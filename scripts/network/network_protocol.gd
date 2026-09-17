class_name NetworkProtocol
extends RefCounted
## Versioned payload keys shared by future ENet host/client implementations.

const VERSION := 1
const DEFAULT_PORT := 27877
const MAX_PLAYERS := 4
const SNAPSHOT_RATE_HZ := 60

const MESSAGE_HELLO := "hello"
const MESSAGE_INPUT := "input"
const MESSAGE_MATCH_CONFIG := "match_config"
const MESSAGE_MUSIC_PLAN := "music_plan"
const MESSAGE_SNAPSHOT := "snapshot"
const MESSAGE_EVENT := "event"

static func envelope(message_type: String, body: Dictionary) -> Dictionary:
	return {
		"version": VERSION,
		"type": message_type,
		"body": body,
	}

static func is_supported(message: Dictionary) -> bool:
	return int(message.get("version", -1)) == VERSION and not str(message.get("type", "")).is_empty()

static func make_input(sequence: int, movement: Vector2, facing: Vector2, buttons: Dictionary) -> Dictionary:
	return envelope(MESSAGE_INPUT, {
		"sequence": sequence,
		"movement": movement.limit_length(1.0),
		"facing": facing.normalized() if facing.length_squared() > 0.0 else Vector2.RIGHT,
		"buttons": buttons,
	})
