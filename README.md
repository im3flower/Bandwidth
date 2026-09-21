# Bandwidth

A Godot 4 rhythm-combat prototype, currently playable against AI and being prepared for authoritative LAN multiplayer.

Open `project.godot` in Godot 4 and run the project.

## Architecture direction

The project has no fallback WAV. Gameplay timing uses a monotonic, host-synchronized `BeatClock`, not audio playback position, so Magenta RT can replace the soundtrack without changing combat timing.

The completed game is intended to use **Magenta Realtime** to generate reactive music from player actions. The host/server will own the match clock and the generated `MusicPlan`; every client will schedule the same generated segments or cues on that shared timeline. Local device latency may change presentation but never changes combat timing judgement.

See [`docs/architecture.md`](docs/architecture.md) for authority boundaries, the music synchronization contract, network messages, and the staged migration plan.

## Gameplay-design branch systems

This branch adds an authoritative gameplay-to-music cue layer while keeping Magenta RT external:

- **Style contest:** the P1/P2 style bar smoothly follows relative health.
- **Chord laser:** press during any part of a beat to begin a one-beat charge; release in the tight next-downbeat window to emit a quality-scaled chord cue.
- **Central control zone:** hold the central ring alone to receive gradual healing and a drum-density cue.
- **Melody ammunition:** collect the purple note pickup, then make Good/Perfect shots to emit its three-note phrase.
- **Chaos core:** collect the gold pickup for a temporary, bounded rise in generation temperature.
- **Perfect resonance:** two players landing Perfect attacks in the same beat temporarily balance styles and emit a shared chord.

`MusicPlan` now contains the host-authored cues and is replicated in LAN snapshots. The actual Magenta RT adapter, its API request format, authentication, audio generation, caching, and distribution are intentionally not implemented in Godot. See [`docs/magenta-rt-bridge.md`](docs/magenta-rt-bridge.md) for the exact cue-to-Magenta input mapping and prompt templates.

The host uses a bounded tempo director with visible states: **STABLE** is 128 BPM, **MOMENTUM** (one player controls the center) targets 134 BPM, **PRESSURE** (the average health loss reaches 30%) targets 140 BPM, and **CLASH** (the center is contested) targets 146 BPM. It evaluates once per bar, schedules only at a future bar boundary, and changes at most 6 BPM per step within 80–180 BPM. Any two scheduled BPM changes are at least ten real-time seconds apart, so players have time to lock into the firing rhythm. The HUD shows the active state and target; Magenta receives this host-authored schedule and does not alter it. `Esc` → **Music latency calibration** plays a built-in 120 BPM click track; after four count-in clicks, tap twelve beats with `F`, `Enter`, `Space`, or left click. The game robustly averages the signed timing error and stores the result as local presentation latency, so negative offsets are valid.

Until the Magenta bridge is connected, a built-in 4/4 metronome fills the soundtrack: it begins at the same first beat as the `BeatClock`, the first beat of each bar is accented, and every click follows the active BPM segment, including BPM changes.

## LAN test (up to four game processes)

The default AI count is `0`. A room supports one host and up to three remote players (four human players total). Godot may prevent opening the same project twice in the editor, so use exported builds or separate Godot processes for additional local clients. LAN snapshots run at 60 Hz, movement is predicted locally, and shot/dash/laser transitions use reliable action messages; the host remains authoritative for hits and damage. Each accepted lobby join resets the shared five-second countdown for every player. LAN AI is simulated by the host and included in the same snapshots; AI is capped at `4 - human players` and is replaced by a joining human before a match begins.

1. Run the project once from Godot and press `H` to host UDP port `27877`.
2. Launch up to three additional game processes. On the same computer, press `H` in each; because the local port is already occupied, each automatically joins `127.0.0.1` instead of showing error 20. `J` remains an explicit join shortcut.
3. After the final client connects, wait for the synchronized five-second countdown, then every assigned player can move and fight. The cyan status line near the bottom reports the room state.

For a quick editor-only alternative, start the first instance from Godot, then launch a second instance from a terminal using the installed Godot executable with the same project path. If the editor still blocks it, use the exported build method above.

For two to four computers on the same network, replace `LAN_JOIN_ADDRESS` in each client build with the host computer's LAN IPv4 address, allow inbound UDP `27877` in the host's Windows Firewall, then use `H` on the host and `J` on every client. Players joining after combat starts wait for the next round; a player disconnecting during combat forfeits that round.

- `WASD`: move in eight directions
- Mouse: aim
- Left click (short press) or `F`: fire
- Press left click at any point during a beat and release on the next downbeat: charged laser
- `Space`, `G`, or `Shift`: dash
- `R`: restart after a round
- `H`: host a LAN match, or join the existing local room when port `27877` is already occupied
- `J`: join `LAN_JOIN_ADDRESS` (`127.0.0.1` by default)
- `[` / `]`: move beat timing 10 ms earlier/later
- `\`: reset beat timing buffer

The match starts at 128 BPM and the current BPM appears in the top HUD. Attacks closest to the beat are faster and stronger; off-beat attacks remain possible but weak. Repeated off-beat inputs add fatigue; max fatigue causes one second of overheat. A normal shot slows movement by 10%; charging the 30-damage laser slows it by 20%. Both recover smoothly over one beat after the action. While charging, laser aim turns toward the mouse at a limited speed. Lasers travel until their fourth wall or arena-boundary contact, then disappear. The AI uses wall-aware waypoints and slow, periodically updated auto-aim with small random error; without direct sight, it scans for a two-bounce wall shot that can reach the player. Bottom control hints disappear when the countdown finishes and return after the round. Use the calibration tool first; `[` / `]` remain available for 10 ms manual refinements and `\` resets the local offset.
