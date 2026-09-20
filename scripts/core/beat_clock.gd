class_name BeatClock
extends Node
## Monotonic rhythm clock. The authority may be a LAN host or a dedicated server.

const MIN_BPM := 120.0
const MAX_BPM := 136.0
const MAX_BPM_STEP := 2.0
const BEATS_PER_BAR := 4.0
const MIN_BEATS_BETWEEN_CHANGES := 16.0

var bpm := 128.0
var local_calibration_seconds := 0.0
var _start_time_msec := 0
var _tempo_segments: Array[Dictionary] = []

func configure(start_time_msec: int, beats_per_minute: float, calibration_seconds: float = 0.0) -> void:
	_start_time_msec = start_time_msec
	bpm = clampf(beats_per_minute, MIN_BPM, MAX_BPM)
	local_calibration_seconds = calibration_seconds
	_tempo_segments = [{"start_beat": 0.0, "start_time": 0.0, "bpm": bpm}]

func restart_after(delay_seconds: float, beats_per_minute: float = bpm) -> void:
	configure(Time.get_ticks_msec() + roundi(delay_seconds * 1000.0), beats_per_minute)

func is_started() -> bool:
	return Time.get_ticks_msec() >= _start_time_msec

func raw_time_seconds() -> float:
	return maxf(0.0, float(Time.get_ticks_msec() - _start_time_msec) / 1000.0)

func rhythm_time_seconds() -> float:
	return maxf(0.0, raw_time_seconds() - local_calibration_seconds)

func seconds_per_beat() -> float:
	return 60.0 / current_bpm()

func beat_position() -> float:
	var rhythm_time := rhythm_time_seconds()
	var segment := _tempo_segments[0]
	for candidate in _tempo_segments:
		if rhythm_time >= float(candidate["start_time"]):
			segment = candidate
		else:
			break
	return float(segment["start_beat"]) + (rhythm_time - float(segment["start_time"])) * float(segment["bpm"]) / 60.0

func current_bpm() -> float:
	var rhythm_time := rhythm_time_seconds()
	var active_bpm := bpm
	for segment in _tempo_segments:
		if rhythm_time >= float(segment["start_time"]):
			active_bpm = float(segment["bpm"])
		else:
			break
	return active_bpm

func schedule_bpm_toward(target_bpm: float) -> Dictionary:
	var scheduled_bpm := current_bpm()
	var current_beat := beat_position()
	var last_segment: Dictionary = _tempo_segments[_tempo_segments.size() - 1]
	var last_start_beat := float(last_segment["start_beat"])
	var next_bar_beat := ceilf((current_beat + 0.001) / BEATS_PER_BAR) * BEATS_PER_BAR
	var earliest_change_beat := last_start_beat + MIN_BEATS_BETWEEN_CHANGES
	var start_beat := maxf(next_bar_beat, earliest_change_beat)
	var next_bpm := move_toward(scheduled_bpm, clampf(target_bpm, MIN_BPM, MAX_BPM), MAX_BPM_STEP)
	if is_equal_approx(next_bpm, scheduled_bpm):
		return {}
	var start_time := beat_to_rhythm_time(start_beat)
	var segment := {"start_beat": start_beat, "start_time": start_time, "bpm": next_bpm}
	_tempo_segments.append(segment)
	return segment.duplicate()

func beat_to_rhythm_time(target_beat: float) -> float:
	var segment: Dictionary = _tempo_segments[0]
	for candidate in _tempo_segments:
		if target_beat >= float(candidate["start_beat"]):
			segment = candidate
		else:
			break
	return float(segment["start_time"]) + (target_beat - float(segment["start_beat"])) * 60.0 / float(segment["bpm"])

func tempo_segments() -> Array[Dictionary]:
	return _tempo_segments.duplicate(true)

func set_tempo_segments(segments: Array[Dictionary]) -> void:
	if segments.is_empty():
		return
	_tempo_segments = segments.duplicate(true)
	bpm = float(_tempo_segments[0].get("bpm", bpm))

func quantized_beat(subdivisions_per_beat: int = 1) -> int:
	return roundi(beat_position() * float(subdivisions_per_beat))

func server_start_time_msec() -> int:
	return _start_time_msec
