# Rhythm Arena Architecture

## Goal

Evolve the Godot 4 prototype into a LAN multiplayer rhythm arena game where the host authoritatively resolves combat and produces one shared, reactive musical timeline. The production music source is planned to be Magenta Realtime; its integration must not own gameplay time.

## Authority boundaries

| Concern | Authority | Clients |
| --- | --- | --- |
| Match lifecycle, spawn, bots, collision, damage, winner | Host/server | Render received state |
| Player input | Owning client submits intent | Never submits positions or damage |
| Beat clock and timing grade | Host/server monotonic clock | Synchronizes clock and optionally calibrates local audio output |
| Reactive music decisions | Host/server | Receives the same `MusicPlan` and rendered audio/cue stream |
| Local audio device latency | Each client | Applies presentation-only calibration; does not alter server judgement |

## Runtime layers

1. **Presentation**: `main.gd`, scene UI, drawing, local input capture, and audio output.
2. **Simulation primitives**: `scripts/simulation/arena_rules.gd` owns shared arena tuning and walls; `arena_geometry.gd` owns collision, raycasts, and reflection; `player_state.gd` and `projectile_state.gd` own mutable, snapshot-ready entity state.
3. **Simulation**: a future `GameSimulation` will own those primitives, AI, combat resolution, and deterministic match state.
4. **Rhythm**: `BeatClock` owns server-aligned time and exposes beat/subdivision positions. It never reads audio playback position.
5. **Networking**: future `LanSession` owns ENet peers, player ownership, RPC routing, snapshots, and connection lifecycle. Its payload vocabulary lives in `NetworkProtocol`.
6. **Music**: `MusicPlan` is an ordered, versioned schedule of host-authored music cues. A future `MusicDirector` plays cues locally and requests or receives rendered audio. A Magenta adapter converts gameplay events into generation requests and emits future-safe cues.

## Music synchronization contract

The host creates a match with a `start_time_msec` sufficiently in the future (currently 5 seconds). It broadcasts one `MusicPlan` containing the starting BPM, seed/session ID, start time, and cues whose start points are expressed in beats. `BeatClock` also serializes a tempo-segment schedule: changes are bar-quantized, at least 16 beats apart, limited to 2 BPM each, and clamped to 120–136 BPM. Combat remains independent and begins at the match timestamp.

A cue should contain only stable data such as:

- `id`, `revision`, `start_beat`, `duration_beats`
- `tempo_bpm`, `key`, `style`, `seed`
- `source` metadata, e.g. a cached segment ID or stream sequence number
- an optional action summary that caused the transition

The generator must render ahead of playback. Late generated audio is scheduled only on a future bar boundary; it never retimes the active beat clock. All clients consume the same rendered result or identical seed/model/version combination. Sending raw player actions directly to independent client generators is not acceptable because outputs can diverge.

## LAN protocol phases

1. Client connects through ENet and sends `hello` with supported protocol version.
2. Host assigns up to four human player slots and sends reliable `match_config` plus the current `music_plan` and authoritative owner roster.
3. Client estimates server time, prepares audio, and waits for the shared start timestamp.
4. Client sends sequenced input at a fixed rate. Host validates and simulates it.
5. Host sends snapshots at 60 Hz and reliable discrete events for joins, round transitions, and music-plan revisions.

## Incremental implementation order

1. Complete this foundation: external beat clock and data contracts. **Done.**
2. Extract reusable entity state and arena geometry from `main.gd`. **Done** in `scripts/simulation/`; snapshot field names remain stable.
3. Extract a headless-safe `GameSimulation` that owns combat, AI, players, projectiles, and match state. Keep its clock as an injected dependency.
4. Move ENet lifecycle and RPC handlers into a scene child named `LanSession`; host and clients must use the same node path for Godot high-level RPCs.
5. Add client interpolation and per-player input ownership.
6. Add `MusicDirector` consuming `MusicPlan`, its tempo segments, and a generated-audio stream.
7. Build a Magenta service adapter, specify stream/cached-segment delivery, and add host-only generation requests.
8. Export a headless server after host mode is stable.

## Current limitation

The project has no Magenta Realtime runtime, model version, endpoint, audio transport, or licensing/deployment configuration yet. Those choices are intentionally not guessed in Godot code. The next implementation decision is whether generation runs in a separate local Python service or an external service reachable by the host.
