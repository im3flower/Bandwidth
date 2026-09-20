# Magenta RT Bridge Contract

`main.gd` implements authoritative gameplay and appends future-safe cue dictionaries to `MusicPlan`. It deliberately does **not** connect to Magenta Realtime, synthesize audio, or let model latency affect combat. A host-only bridge consumes the plan, renders ahead, and distributes identical audio/segments to clients.

## Bridge inputs

Every request should include the stable match context below. Values are authored by the host:

```json
{
  "session_id": "bandwidth-...",
  "revision": 12,
  "start_beat": 48.0,
  "tempo_bpm": 128.0,
  "tempo_segments": [{"start_beat": 16.0, "start_time": 7.5, "bpm": 130.0}],
  "key": "C minor",
  "style_weights": {"player_1": 0.62, "player_2": 0.38},
  "temperature": 0.70,
  "cue": {"type": "..."}
}
```

The bridge must map player styles to the actual Magenta style conditioning representation. It must not claim that a numeric weight equals an audio volume ratio. `tempo_bpm` is required on every cue; `tempo_segments` is the host's authoritative upcoming tempo schedule. It changes only on bar boundaries, no more often than every 16 beats, and by at most 2 BPM, so the bridge must schedule its generated audio to the same changes rather than smoothing it independently.

## Cue mapping

| Gameplay event | `MusicPlan` cue | Required bridge input |
| --- | --- | --- |
| Style contest | host snapshot `style_weights` | Blend the two style embeddings/conditioning weights smoothly over several generation frames. Re-evaluate on each plan revision rather than every rendered frame. |
| Chord laser | `laser_charge_root`, `laser_chord`, `laser_charge_cancelled` | `laser_charge_root` starts and sustains the supplied root MIDI note. `laser_chord` expands it using `midi_notes`, `velocity`, `start_beat`, and `duration_beats`; use quality only for voicing/energy, not combat. `laser_charge_cancelled` must release the root immediately. |
| Central control | `capture_started` | Increase drum conditioning/activity from `drum_density` gradually. The bridge chooses valid drum-condition syntax for the installed Magenta RT version. |
| Melody ammunition | `melody_loaded`, `melody_note`, `melody_phrase_complete` | Only `melody_note` and phrase-complete need note scheduling: send their ordered `midi_notes`, velocity, start beat, and duration. Do not wait for projectile impact. |
| Chaos core | `chaos_started` plus snapshot `temperature` | Smoothly move sampling temperature toward the bounded host value (currently 0.55–0.95); restore it when the host snapshot falls back. Never treat temperature as volume or BPM. |
| Perfect resonance | `resonance` | Temporarily use 50:50 style conditioning while emitting the supplied chord `midi_notes` for `duration_beats`. The host already enforces cooldown and timing. |
| Tempo director | `tempo_change` plus `tempo_segments` | Apply `tempo_bpm` at `start_beat`, retaining the prior BPM until that exact boundary. Do not create independent tempo ramps or react faster than the host schedule. |

## Required bridge prompt / request text

When the Magenta adapter needs a text prompt, build it from stable match data, for example:

> Instrumental competitive arena music in C minor at **128 BPM**. Blend Hip-hop (62%) with R&B (38%). Keep a steady, readable combat pulse. Apply the scheduled MIDI events and drum conditioning. At beat 16, change to **130 BPM** exactly; do not add other tempo or meter changes.

For a cue-specific addition, append one concise clause:

- **Laser:** “At beat 48, sustain MIDI notes 48, 51, 55, 58 for 1.25 beats as a strong harmonic accent.”
- **Capture:** “Gradually make the drum pattern more active while the central zone remains controlled.”
- **Melody:** “At beat 51.5, play MIDI note 63 for 0.45 beats as the next note of a short motif.”
- **Chaos:** “For the next 8 seconds, increase variation moderately while preserving key, tempo, and pulse.”
- **Resonance:** “For the next 2 beats, balance both styles equally and play MIDI notes 60, 63, 67, 70.”
- **Tempo:** “At beat 16, change the tempo from 128 BPM to 130 BPM on the bar boundary; keep the pulse stable until then.”

The actual API message format, supported conditioning fields, model version, endpoint, authentication, and generated-audio transport remain bridge responsibilities. Validate them against the installed Magenta RT API; they are intentionally not guessed in GDScript.

## Delivery rules

1. Generate and cache audio ahead of its `start_beat`; if it is late, schedule the next safe bar instead.
2. Distribute one host-rendered result (or an explicitly deterministic shared result) to all clients.
3. Keep gameplay timing on `BeatClock`; never delay or alter damage because an audio request is slow.
4. Release every sustained MIDI note on cancellation, match end, disconnect, and bridge restart.
