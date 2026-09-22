# River Bound — Igris Complete Integration

This is a standalone Godot 4.7.1 project containing the complete River Bound environment/combat integration tested on 2026-08-14. It is a teammate-review build, separate from the earlier combat prototype and the original environment project.

## Run

1. Open this folder's `project.godot` in Godot 4.7.1 Standard.
2. Allow Godot to finish importing assets.
3. Press Play.

Main entry scene: `res://scenes/river_bound_main.tscn`

Renderer: GL Compatibility

## Controls

- WASD or arrow keys: move
- Mouse: aim
- Left mouse button or Space: shoot
- R: restart the encounter

## Included gameplay

- Teammate environment with authored boundaries and collisions
- Current temporary player and Quaternius assault rifle
- Projectile collision with monsters and collidable environment objects
- Previous working monster animation set
- Three monsters at scene start
- Three additional monsters after 10 seconds
- Hard cap of six spawned monsters
- Player/monster damage, hit reactions, death, audio, and restart

## Exact file map

| System | Primary file |
|---|---|
| Main entry point | `scenes/river_bound_main.tscn` |
| Integrated environment scene | `environment/RiverBoundEnvironment.tscn` |
| Encounter and wave control | `scripts/environment_combat_controller.gd` |
| Player scene | `scenes/player.tscn` |
| Player behavior | `scripts/player.gd` |
| Rifle scene | `scenes/gun.tscn` |
| Projectile scene | `scenes/projectile.tscn` |
| Projectile behavior | `scripts/projectile.gd` |
| Monster scene | `scenes/enemy.tscn` |
| Monster behavior | `scripts/enemy.gd` |
| Runtime audio | `assets/audio/` |
| Audio provenance | `assets/audio/PROVENANCE.md` |
| Focused smoke tests | `tests/` |

Imported FBX, GLTF, GLB, texture, and animation filenames were intentionally preserved to avoid breaking Godot resource references.

## Known cautions

- Monsters use direct pursuit; there is no navigation mesh. Dense obstacles can cause pathing problems.
- River markers are not used for these waves because they are below/outside the playable surface.
- Some decorative environment objects are visual-only and have no collision.
- The current player is temporary and should not be manually re-rigged during the jam.
- The original unsuccessful Blender monster correction is not included.
- Review `docs/ASSET_SOURCES.md` before merging or distributing the project.

## Generated files

The `.godot/` import cache is intentionally excluded. Godot recreates it when the project is opened.
