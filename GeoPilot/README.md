# GeoPilot Auto Play (Experimental)

**Target:** Geometry Dash 2.2081 + Geode v5.10.1.

GeoPilot is an early native Geode mod prototype. It exposes options in Geode's in-game mod settings and uses object-ID/position heuristics to react to a limited set of common hazards. It is not a complete physics solver and is not a validated completion bot.

## Settings
- **Enable Auto Play:** off by default.
- **Game Mode:** Auto or manual mode override.
- **Reaction Distance:** how early the heuristic reacts.
- **Debug Log:** occasional controller decisions.

The current controller taps for Cube/Ball/UFO/Robot/Spider/Swing/Platformer and uses a basic hold/release heuristic for Ship/Wave. Portals, gravity/speed triggers, orbs and pads, dual mode, moving hazards, custom objects, and complex Ship/Wave corridors require a more complete physics/pathfinding model.

## Download the .geode
Open the repository's **Actions** tab, select **Build GeoPilot (Geode 5.10.1)**, and download artifact **GeoPilot-Geode-v5.10.1-GD-2.2081** after all platform jobs succeed. Extract the artifact ZIP to get the multi-platform `.geode` package.

The package contains separate native builds for Windows x64, macOS, iOS, Android 32-bit, and Android 64-bit. It is not one native binary that runs unchanged on every operating system.

## Local build
Install the Geode CLI and matching SDK, then run:

```sh
geode sdk install
geode sdk install-binaries
geode build
```

## Status
GitHub Actions performs the build; source in this branch is not a precompiled binary. In-game performance and level completion have not yet been verified. The heuristic will fail on many levels.

Build workflow is also present on the default branch to allow manual runs. The workflow checks out the `geopilot-build` branch for sources.
