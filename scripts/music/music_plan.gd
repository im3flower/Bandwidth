class_name MusicPlan
extends RefCounted
## A host-authored, serializable schedule for deterministic music synchronization.
## Audio bytes remain outside this contract; clients receive the same rendered segment
## or request it from the configured music service using the cue identifier.

var session_id := ""
var bpm := 130.0
var start_time_msec := 0
var revision := 0
var cues: Array[Dictionary] = []
var tempo_segments: Array[Dictionary] = []

func configure(new_session_id: String, beats_per_minute: float, start_msec: int) -> void:
	session_id = new_session_id
	bpm = beats_per_minute
	start_time_msec = start_msec
	revision = 0
	cues.clear()
	tempo_segments = [{"start_beat": 0.0, "start_time": 0.0, "bpm": bpm}]

func set_tempo_segments(segments: Array[Dictionary]) -> void:
	if not segments.is_empty():
		tempo_segments = segments.duplicate(true)

func append_cue(cue: Dictionary) -> void:
	cues.append(cue)
	revision += 1

func to_payload() -> Dictionary:
	return {
		"session_id": session_id,
		"bpm": bpm,
		"start_time_msec": start_time_msec,
		"revision": revision,
		"cues": cues.duplicate(true),
		"tempo_segments": tempo_segments.duplicate(true),
	}

static func from_payload(payload: Dictionary) -> MusicPlan:
	var plan := MusicPlan.new()
	plan.session_id = str(payload.get("session_id", ""))
	plan.bpm = float(payload.get("bpm", 130.0))
	plan.start_time_msec = int(payload.get("start_time_msec", 0))
	plan.revision = int(payload.get("revision", 0))
	for cue in payload.get("cues", []):
		if cue is Dictionary:
			plan.cues.append(cue.duplicate(true))
	for segment in payload.get("tempo_segments", []):
		if segment is Dictionary:
			plan.tempo_segments.append(segment.duplicate(true))
	if plan.tempo_segments.is_empty():
		plan.tempo_segments = [{"start_beat": 0.0, "start_time": 0.0, "bpm": plan.bpm}]
	return plan
