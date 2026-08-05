# Umbrella Soccer 1.0.1

Bug fix release over 1.0.0. No configuration changes required: no cvar was added and no default value changed.

## Fixes

- **Penalties**: the goal is detected automatically. It previously had to be awarded by hand with `sm_soccer_goal <ct/t>` or the penalty ended as a timeout miss, which also made the whole shootout unusable.
- **Shootout**: it now ends once the lead is unbeatable, like a real shootout. At 3-0 after three rounds the remaining two kicks are not taken. Sudden death does not end until both teams have taken the same number of kicks: previously whoever opened the sixth round won on scoring, with no reply from the other team. Bots can no longer be picked as takers.
- **Taker position**: the penalty taker now stands behind the ball, facing the goal. It used to be placed sideways across the pitch.
- **Phantom goals**: a period longer than `mp_roundtime` made the round expire on its own and handed CT a goal nobody scored. Only round ends that correspond to a goal are counted now.
- **Round points**: the ±10 for winning or losing the goal round are awarded even when the plugin cannot identify the last player to touch the ball.
- **Red card**: the sent-off player now dies reliably before being moved to spectator.
- **Stoppage time**: the trigger's internal model is precached on map start instead of mid-round.

## Cleanup

- Removed two cvars that had no effect: `sm_soccer_assist_window` and `sm_soccer_training_cannon_ball_life`. If your 1.0.0 `cfg/sourcemod/umbrella_soccer.cfg` still has them they are ignored; this package already ships without them.

## Assets

- `umbrella_soccer-1.0.1-server.zip`: server package for the `cstrike` folder.
- `umbrella_soccer-1.0.1-fastdl.zip`: web-host package for FastDL. The assets are identical to 1.0.0, so there is no need to re-upload them if they are already hosted.

## Installation

Extract `umbrella_soccer-1.0.1-server.zip` into the server `cstrike` folder, overwriting. Reload the plugin or change the map.

Extract `umbrella_soccer-1.0.1-fastdl.zip` into the root folder used by `sv_downloadurl`.

## Build

- Compiled with SourcePawn 1.12.0.7246, no warnings.
- SHA256 (`umbrella_soccer.smx`): `C64734BE28A2247051D0239B1C6B07995ADF628B4E40179ACDC5347FF9179B61`
