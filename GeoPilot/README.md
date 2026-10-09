# GeoPilot Auto Play v0.3.0 (Experimental)

**Target:** Geometry Dash 2.2081 + Geode 5.10.1.

## What's new in v0.3.0
- Single GeoPilot logo button in the Pause menu. Click it to open a separate Control Center popup.
- The popup contains Auto Play, Orb Assist, Scan Rays, HUD, mode override, jump lead frames and scan range.
- Bundled GeoPilot logo resource used by the Pause button and settings panel.
- Recognizes common jump-activated orbs by object ID: yellow, blue, pink, green, black, red, toggle, spider and teleport.
- Orb approach tap and orb contact tap are separate actions; the HUD reports which orb is being tracked.
- Spike timing no longer uses an 82px minimum lead. It uses measured per-frame closing speed and a shorter 2–10 frame lead window.
- The HUD reports recognized orb count and the current timing action.

## Use
1. Install the generated `.geode` for Geometry Dash 2.2081 / Geode 5.10.1.
2. Start a level and open Pause (Esc on desktop; pause control on touch devices).
3. Click the single GeoPilot logo. The Control Center opens.
4. Enable **AUTO PLAY**, leave **ORB ASSIST** on to test orb input, and tune **LEAD** / **SCAN RANGE** from that panel.
5. Watch Scan Rays and the HUD. Use practice mode while tuning; if a level's speed changes, adjust the lead window.

## Controller model and limits
- Pulse modes use a speed-adaptive contact threshold for common spikes/saws.
- Ship and Wave use a separate hold/release heuristic.
- Platformer mode keeps Right pressed and jumps at recognized hazards.
- Orb assist recognizes common jump-activated orb IDs and checks horizontal and vertical hitbox gaps before tapping. High orbs may receive a separate approach jump before the contact tap.
- Mode detection reads PlayerObject state for Cube, Ship, Ball, UFO, Wave, Robot, Spider, Swing and Platformer, with a manual override in the Control Center.
- This remains a heuristic controller, not a complete engine-level simulation. It can miss custom hazards, moving obstacles, speed/gravity portals, dual routes, pads/orbs with unusual paths and precise Wave/Ship corridors. Every Geometry Dash level cannot be guaranteed to finish automatically.

## Build / download
Open **Actions → Build GeoPilot (Geode 5.10.1)** and download artifact **GeoPilot-Geode-v5.10.1-GD-2.2081** after a successful run. The artifact contains separate native builds for Windows x64, macOS, iOS, Android 32-bit and Android 64-bit, combined into one multi-platform `.geode` package.

Local SDK build:
- `geode sdk install`
- `geode sdk install-binaries`
- `geode build`
