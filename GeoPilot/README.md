# GeoPilot Auto Play v0.2.0 (Experimental)

**Target:** Geometry Dash 2.2081 + Geode 5.10.1.

## What's new
- Scanner fan and rays drawn while playing.
- Rays/boxes highlight recognized spike and saw object IDs; blue rays also show scanned objects.
- Live HUD: detected mode, frame counter, FPS, delta time, scan counts, target ID, estimated distance, ETA in update frames and current bot action.
- Current mode auto-detected from PlayerObject state; manual override remains in Geode settings.
- Pause-menu controls: AUTO PLAY, SCAN RAYS, HUD, and JUMP LEAD frame cycle.
- Timing uses per-frame closing-distance measurements where available, with velocity/delta-time fallback.

## Pause menu
Pause Geometry Dash (Esc on desktop, the pause control on touch platforms). The GeoPilot controls appear at the upper right. Use:
- **AUTO PLAY** to turn the controller on/off.
- **SCAN RAYS** to toggle ray and hazard-box rendering.
- **HUD** to toggle live diagnostic text.
- **JUMP LEAD** to cycle the number of frames before predicted contact.

The Geode mod settings also expose scan distance, manual mode override, and debug logs.

## Important limits
This is still a heuristic controller, not a full physics engine. It recognizes a maintained list of common spike/saw IDs and can miss custom hazards, solid-block sides, moving objects, orbs/pads, portals, dual-player routing, gravity/speed triggers, and complex Ship/Wave corridors. Timing estimates are based on observed closing distance and can be noisy during speed changes or camera/portal transitions. Mode detection is automatic, but successful completion of every level is not guaranteed. Test in practice mode first and adjust JUMP LEAD and scan distance.

## Build / download
Open Actions and choose Build GeoPilot (Geode 5.10.1), then download artifact GeoPilot-Geode-v5.10.1-GD-2.2081 after a successful run. The artifact contains separate native builds for Windows x64, macOS, iOS, Android32 and Android64, combined into a multi-platform .geode package.

Local SDK build:
- geode sdk install
- geode sdk install-binaries
- geode build
