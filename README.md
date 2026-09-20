# Bandwidth

A Godot 4 rhythm-combat prototype, currently playable against AI and being prepared for authoritative LAN multiplayer.

Open `project.godot` in Godot 4 and run the project.

## Architecture direction

The current WAV is a local development fallback. Gameplay timing now uses a monotonic `BeatClock`, not the audio playback position, so it can be synchronized to a LAN host or headless server.

The completed game is intended to use **Magenta Realtime** to generate reactive music from player actions. The host/server will own the match clock and the generated `MusicPlan`; every client will schedule the same generated segments or cues on that shared timeline. Local device latency may change presentation but never changes combat timing judgement.

See [`docs/architecture.md`](docs/architecture.md) for authority boundaries, the music synchronization contract, network messages, and the staged migration plan.

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
- Press left click on one beat and release on the next: charged laser
- `Space`, `G`, or `Shift`: dash
- `R`: restart after a round
- `H`: host a LAN match, or join the existing local room when port `27877` is already occupied
- `J`: join `LAN_JOIN_ADDRESS` (`127.0.0.1` by default)
- `[` / `]`: move beat timing 10 ms earlier/later
- `\`: reset beat timing buffer

At 130 BPM, attacks closest to the beat are faster and stronger. Attacks far from the beat remain possible but are weak. Repeated off-beat inputs add fatigue; max fatigue causes one second of overheat. A normal shot slows movement by 10%; charging the 30-damage laser slows it by 20%. Both recover smoothly over one beat after the action. While charging, laser aim turns toward the mouse at a limited speed. Lasers travel until their fourth wall or arena-boundary contact, then disappear. The AI uses wall-aware waypoints and slow, periodically updated auto-aim with small random error; without direct sight, it scans for a two-bounce wall shot that can reach the player. The BGM begins at beat 64 and stops when a round ends; `R` schedules the next round. Use the beat buffer controls while listening to the BGM to align the centre pulse with its first downbeat.
