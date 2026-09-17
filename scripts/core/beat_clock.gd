class_name BeatClock
extends Node
## Monotonic rhythm clock. The authority may be a LAN host or a dedicated server.

var bpm := 130.0
var local_calibration_seconds := 0.0
var _start_time_msec := 0

func configure(start_time_msec: int, beats_per_minute: float, calibration_seconds: float = 0.0) -> void:
	_start_time_msec = start_time_msec
	bpm = beats_per_minute
	local_calibration_seconds = calibration_seconds

func restart_after(delay_seconds: float, beats_per_minute: float = bpm) -> void:
	configure(Time.get_ticks_msec() + roundi(delay_seconds * 1000.0), beats_per_minute)

func is_started() -> bool:
	return Time.get_ticks_msec() >= _start_time_msec

func raw_time_seconds() -> float:
	return maxf(0.0, float(Time.get_ticks_msec() - _start_time_msec) / 1000.0)

func rhythm_time_seconds() -> float:
	return maxf(0.0, raw_time_seconds() - local_calibration_seconds)

func seconds_per_beat() -> float:
	return 60.0 / bpm

func beat_position() -> float:
	return rhythm_time_seconds() / seconds_per_beat()

func quantized_beat(subdivisions_per_beat: int = 1) -> int:
	return roundi(beat_position() * float(subdivisions_per_beat))

func server_start_time_msec() -> int:
	return _start_time_msec
