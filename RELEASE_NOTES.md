# Umbrella Soccer 1.1.1

Fix release over 1.1.0, from match testing: saves are counted on the spot, goalkeeper areas take one click to set, penalties work in shootouts and during matches, every kickoff is announced, and the HUD reads like the original soccermod's again.

## Saves

- A save ("Salvada" in Spanish) is counted and announced on the touch itself, for the goalkeeper or any defender who touches the ball inside their own goalkeeper area right after an opponent. Before, it waited for the next touch or a goal.
- If the ball still goes in before anyone else touches it, the save is quietly taken back and the goal goes to the shooter instead of an own goal.
- A save is worth 5 points by default instead of 10, on top of the interception and hit points the same touch already earns.

## Goalkeeper areas

- One menu choice per goal: stand in the middle of the goal line and pick **Mark CT area** or **Mark TT area** in `!soccer` > Goalkeeper areas. The area is built in front of the goal, saved at once and outlined on the floor.
- Its size is `sm_soccer_gk_area_width` (640) by `sm_soccer_gk_area_depth` (224). Areas saved with 1.1.0 keep working.

## Penalties

- Shootouts: each kick is taken towards the goal the shooting team attacks. Before, every kick used the same goal, so one of the two teams could never score.
- During a match the clock stops until the kick, and the kick puts the ball back in play: a goal counts on the scoreboard, is credited to the scorer and is followed by a kickoff. A penalty can only be given while the ball is in play.
- The ball is placed on the spot standing still.

## Kickoffs and HUD

- The second half, and any later period, announces which team kicks off.
- When the round timer runs out during a match, play restarts with an announced kickoff and the clock waits for it, instead of the ball going back to the centre with the clock running.
- The HUD is laid out like the original soccermod's: `CT 1 - 0 T | 03:12`, with what holds play in front of it (`Saca CT: ...`, `Pausado: ...`). A pause shows as a pause even while a kickoff is waiting.

## Other

- Players with a red card can no longer be picked in a draft.

The full list is in `CHANGELOG.md`.

## Upgrading from 1.1.0

- Only the plugin, its sources, the translations and the cfg changed. The models, materials and map are identical to 1.1.0, so FastDL hosts need no update.
- If you keep your `cfg/sourcemod/umbrella_soccer.cfg`, it still sets `soccer_mod_ranking_points_save "10"`: change it to `5` for the new balance. The two new area cvars use their defaults.

## Assets

- `umbrella_soccer-1.1.1-server.zip`: server package for the `cstrike` folder.
- `umbrella_soccer-1.1.1-fastdl.zip`: web-host package for FastDL, identical in content to 1.1.0.

## Installation

Extract `umbrella_soccer-1.1.1-server.zip` into the server `cstrike` folder, overwriting, and change the map.

Extract `umbrella_soccer-1.1.1-fastdl.zip` into the root folder used by `sv_downloadurl`.

## Build

- Compiled with SourcePawn 1.12.0.7255, no warnings.
- SHA256 (`umbrella_soccer.smx`): `58B78EB584BE9510B79AC5FE2CC45AEB83B872476BE8D3185EF6CE386A026D63`
