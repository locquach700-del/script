# GeoPilot Auto Play v0.4.8 — Geometry Dash 2.2081 / Geode 5.10.1

## Included
- Root-level `logo.png` is included for Geode's mod-list icon; `resources/geopilot-logo.png` powers the Pause shortcut and Control Center.
- Whole-level preflight inventory from the loaded object array: hazards, cyan safe surfaces, jump orbs, mode portals and pads. The bot builds this inventory during PlayLayer initialization, before its first Auto Play decision.
- Live route signal with the next three events: DODGE RED, LAND BLUE, TAP YELLOW/GREEN/..., MODE PORTAL, or AUTO PAD.
- Collision classification uses Geometry Dash GameObjectType::Hazard and AnimatedHazard plus known spike/saw IDs. Solid, slope and breakable surface types are shown separately in cyan.
- Jump-activated orbs are recognized by both common object IDs and GameObjectType (yellow, blue/gravity, pink, green, red, custom, spider and teleport). Dash rings are treated as contact-triggered, not as an orb jump.
- Cube jumps only for recognized spikes ahead in its standing lane, while grounded. Cyan blocks are visualized but never trigger Cube jumps; hazards overhead are ignored.
- Spawn guard releases stale input and pauses new decisions briefly after respawn; dense scans reuse bounded candidate lists instead of sorting every block every frame.
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


## v0.4.2 — reliability and learning update
- Cube hazard decisions only use recognized spike IDs ahead of the player and within the standing lane. Hazards fully above the player's head remain visible in the scan, but they do not trigger a Cube jump.
- Cube no longer jumps just to climb cyan safe blocks; explicit Orb Assist remains a separate behavior.
- Passed targets are filtered out of normal jump decisions, reducing repeated inputs around dense object groups.
- The mod logo is loaded from either supported resource path; the Pause button is moved away from the game's top-right Settings control.
- Control Center enlarged and re-spaced. Its status includes level attempts, deaths, and the last failure action.
- Persistent learning records death counts and the last target/action per level. When a retry reaches a matching target near the recorded failure distance, the bot can add up to two frames of extra lead. This is a heuristic, not a full physics simulator.
- Added the root `logo.png` used by Geode's in-game mod listing.

Use Practice Mode when first testing a level. Custom hitboxes, unusual spike IDs, gravity flips, and tightly scripted orb sequences can still require manual adjustment.


## v0.4.3 — expanded interaction catalog
- Distinguishes jump-activated Drop/Black Orbs from contact-activated Dash Rings and Gravity Dash Rings. Dash rings are reported in the route plan but do not cause a jump press just to activate them.
- Recognizes the five standard speed portal IDs (slow, normal, fast, faster, fastest), reports them in preflight, and keeps recomputing closing speed live after the transition.
- Preflight now reports mode portals, speed portals, dash rings, pads, jump orbs, hazards, and safe surfaces as distinct groups.
- This inventory focuses on objects that affect movement, collision, or input. Color/move/toggle/area triggers and arbitrary custom hitboxes can alter a scene in ways static classification cannot fully simulate.


## v0.4.4 — repeat-death safety and spike database corrections
- Corrects the known spike IDs: object 205 is a safe small slab, while 206 is the invisible half spike. Adds small ice spikes, colored small spikes, known black spike hazards and their sloped variants.
- Cube continues to react only to known spike IDs that are in front and in its standing vertical lane; a red object above the Cube does not trigger a jump.
- Tracks the last failure's target ID and horizontal distance per level. After three consecutive deaths at a matching target and distance, Auto Play safely switches itself off to stop an endless same-failure loop; the UI shows the learned death streak.
- Keeps the v0.4.3 Drop/Black Orb, contact Dash Ring, Gravity Dash Ring and speed-portal catalog.


## v0.4.5 — variable Robot jump input
- Robot jumps now hold the input briefly when the predicted obstacle/platform is tall, instead of being forced into a one-frame tap every time. Orb activations remain taps; an elevated-orb approach can use a controlled short hold.
- Hold duration is capped and is still a heuristic, so difficult Robot timings should be tested in Practice Mode.


## v0.4.6 — wider map inventory
- Preflight counts modifier/enter-effect objects as dynamic triggers, plus user coins, secret coins, and collectibles.
- These categories appear in map totals but are deliberately not inserted into the jump-action queue, because a level may contain many non-navigation triggers.
- This detects categories; it does not simulate every move/toggle/spawn/camera/keyframe trigger or every custom collision setup.


## v0.4.7 — dense-level performance
- Uses partial sorting to select only the eight closest objects for scan-ray drawing; it no longer fully sorts every nearby decorative object each frame.
- Selects the closest hazard/orb/surface with linear minimum searches rather than sorting all candidates.
- Adds a forward route cursor to avoid rescanning passed events from the beginning of the entire level every frame.
- Chooses the nearest eligible cyan step surface explicitly, so removing surface sorting does not change target selection.


## v0.4.8 — dense scenes, Cube gating, icon and UI fixes
- Reuses scan vectors and caps actionable hazard, orb, step and visual candidates so dense object fields cannot grow per-frame scan arrays without bound.
- Cube no longer jumps at cyan blocks or arbitrary hazards: only known spike IDs in the standing lane may trigger, and the player must be grounded. A spike above the head is ignored.
- After a death, releases held buttons and observes a short spawn grace period to avoid instant jump/respawn loops.
- Captures the actual hazard collider when the game reports a death; persistent learning tracks repeated failures by hazard or map-progress section and can stop Auto Play after three repeated failures.
- Adds the required root-level `logo.png` for the Geode listing, moves the Pause shortcut away from the game's Settings control, prevents duplicate buttons, and enlarges/re-aligns Control Center controls.

The object inventory is broad but not a complete physics engine: arbitrary triggers, custom hitboxes, dual paths and rapidly changing speed/gravity can still require testing. Start in Practice Mode and verify the target/action HUD before relying on Auto Play.
