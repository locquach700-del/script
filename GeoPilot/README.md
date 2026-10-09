# GeoPilot Auto Play v0.4.0 — Geometry Dash 2.2081 / Geode 5.10.1

## Included
- Bundled GeoPilot icon, shown as the single button inside Pause. Click it to open Control Center.
- Whole-level preflight inventory from the loaded object array: hazards, cyan safe surfaces, jump orbs, mode portals and pads. The bot builds this inventory during PlayLayer initialization, before its first Auto Play decision.
- Live route signal with the next three events: DODGE RED, LAND BLUE, TAP YELLOW/GREEN/..., MODE PORTAL, or AUTO PAD.
- Collision classification uses Geometry Dash GameObjectType::Hazard and AnimatedHazard plus known spike/saw IDs. Solid, slope and breakable surface types are shown separately in cyan.
- Jump-activated orbs are recognized by both common object IDs and GameObjectType (yellow, blue/gravity, pink, green, red, custom, spider and teleport). Dash rings are treated as contact-triggered, not as an orb jump.
- Cube-like modes may time a jump onto a reachable cyan solid block if the block top is above the player's feet and no red hazard overlaps the landing area.
- Short, speed-adaptive red-hazard lead window. The previous large fixed minimum distance is removed to reduce premature jumps.
- Live HUD and control popup expose map counts, progress, target, ETA, frame/FPS, action, mode, scan range and jump lead.

## How to use
1. Install the .geode file that matches Geometry Dash 2.2081 and Geode 5.10.1.
2. Start a level. GeoPilot pre-scans the loaded object list at PlayLayer initialization.
3. Open Pause and click the GeoPilot icon. Turn on AUTO PLAY and ORB ASSIST.
4. Keep SCAN RAYS and HUD enabled while tuning. The HUD shows map inventory, route signal and current action.
5. Set the lead window low to start (2–4 frames); raise it in faster sections only if the HUD shows that the jump is late.

## Limits
Map preflight classifies level objects and orders them by position; it does not simulate the full game engine's gravity, jump arc, trigger links, dual paths or object-specific collision polygons. Cyan safe surfaces use their object type and sprite bounds as an approximation, so platforms with custom hitboxes can still need adjustment. Auto Play has per-mode heuristics, not a guaranteed perfect route solver for every custom level, moving object, portal chain, dual section or extreme Wave/Ship corridor.

## Build and download
Open Actions → Build GeoPilot (Geode 5.10.1) for the combined artifact GeoPilot-Geode-v5.10.1-GD-2.2081.

Local SDK commands:
- geode sdk install
- geode sdk install-binaries
- geode build
