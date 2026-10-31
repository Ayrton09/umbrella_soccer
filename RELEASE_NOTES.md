# Umbrella Soccer 1.2.0

A real penalty shootout, a new stadium and a new ball.

## New

- **Penalty shootout.** It starts by itself when overtime ends tied, or from the penalties menu with 3, 5 or up to 20 kickers per team. Each captain lines up their kickers from a menu (`!kickers`), a coin toss picks who starts, and sudden death goes on through the rest of the team as in a real shootout.
- Everyone else waits frozen at a waiting spot marked per map. The kicker is placed behind the ball and the goalkeeper on the goal line, and the kicker is held still after the kick, so there are no rebounds.
- A board like the TV graphic on the HUD: the score, each team's kicks, who is kicking and the time left.
- Referee whistles shipped with the plugin open each kick, warn the kicker with 10 seconds left and end the shootout. A kick has 20 seconds.
- Goals do not kill anyone during penalties: the plugin sees the ball go in and calls the goal.
- **New map `ka_soccer_maradona_v1`**, the Estadio Diego Armando Maradona in La Plata, at night. The pitch, goals and boundaries are the same as `ka_soccer_world_cup_2026`, so it plays the same.
- **The Argentum ball** ships next to the Trionda. The Maradona map uses it as its ball, and either one can be the training ball through `sm_soccer_training_ball_model`.

The full list is in `CHANGELOG.md`.

## Upgrading from 1.1.3

- The plugin, its sources, the translations and the cfg changed. The cfg has new shootout settings, and the time to take a penalty went from 15 to 20 seconds. If you edited your `cfg/sourcemod/umbrella_soccer.cfg`, keep a copy before overwriting and copy your values back.
- New files: the referee whistles (`sound/umbrella_soccer/`), the Maradona map and the Argentum ball. FastDL hosts need the new FastDL package uploaded.
- Mark the goalkeeper areas on `ka_soccer_maradona_v1` once from the menu, as on any new map. They fall on the same coordinates as on the 2026 map.
- Penalty and waiting spots are saved per map in `addons/sourcemod/configs/umbrella_soccer_penalty_spots.cfg`. Without a marked penalty spot, kicks are taken about 11 m in front of each goal.

## Assets

- `umbrella_soccer-1.2.0-server.zip`: server package for the `cstrike` folder.
- `umbrella_soccer-1.2.0-fastdl.zip`: web-host package for FastDL.

## Installation

Extract `umbrella_soccer-1.2.0-server.zip` into the server `cstrike` folder, overwriting, and change the map.

Extract `umbrella_soccer-1.2.0-fastdl.zip` into the root folder used by `sv_downloadurl`.

## Build

- Compiled with SourcePawn 1.12.0.7255, no warnings.
- SHA256 (`umbrella_soccer.smx`): `67780589E2544C1AFFF4E282D09086896C6367B5FFEE8DAC7F177766646DC165`
