# Umbrella Soccer 1.1.3

Small release over 1.1.2: admin options to send players to spectator, and balls that stay where they are placed.

## New

- **Send everyone to spectator**, to set teams up again from scratch: first entry of the Captains section of the admin menu, with a confirmation, or `sm_soccer_spec_all`. It moves every human player on T or CT; bots stay, since the bot quota would add them back. It is refused during a match or a draft.
- **Send one player to spectator**, for example an AFK one: a player list in the same Captains section, or `sm_soccer_spec <player>`. This one also works during a match or a draft.

## Fixes

- A spawned training ball and a ball placed for a penalty now sit on the floor and stay still, like the match ball before kickoff, until someone touches them. Before, the training ball dropped from above the aim point and the penalty ball could fall or roll off the spot.

The full list is in `CHANGELOG.md`.

## Upgrading from 1.1.2

- Only the plugin, its sources and the translations changed. The cfg, models, materials and map are identical to 1.1.2, so FastDL hosts need no update.

## Assets

- `umbrella_soccer-1.1.3-server.zip`: server package for the `cstrike` folder.
- `umbrella_soccer-1.1.3-fastdl.zip`: web-host package for FastDL, identical in content to 1.1.2.

## Installation

Extract `umbrella_soccer-1.1.3-server.zip` into the server `cstrike` folder, overwriting, and change the map.

Extract `umbrella_soccer-1.1.3-fastdl.zip` into the root folder used by `sv_downloadurl`.

## Build

- Compiled with SourcePawn 1.12.0.7255, no warnings.
- SHA256 (`umbrella_soccer.smx`): `BCADA2985D641F05FF0EBF6B3BEFA1F7E30F5C5F3A17129FBAC08637CF5986E3`
