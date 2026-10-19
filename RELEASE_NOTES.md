# Umbrella Soccer 1.1.2

Small release over 1.1.1: four more languages, an English-only config file, and stoppage time that ends on a goal.

## Match flow

- A goal in stoppage time ends the period right there: the break, overtime or the final whistle follows at once. Before, play went on with a kickoff and the period only ended when that kickoff crossed the halfway line.

## Languages

- Added Russian, Simplified Chinese, Italian and Japanese for every message, menu and HUD line, on top of English, Spanish, Portuguese, French and German. They use the stock SourceMod language codes (`ru`, `chi`, `it`, `jp`), so a player whose game is in one of them sees the plugin in it with no setup.
- The goalkeeper areas help is sent as three short chat lines, so no language gets cut off at the chat limit.

## Configuration

- Every cvar description in `cfg/sourcemod/umbrella_soccer.cfg` is now in English and identical to the plugin's own. A few were in Spanish and others no longer matched the code.

The full list is in `CHANGELOG.md`.

## Upgrading from 1.1.1

- Only the plugin, its sources, the translations and the cfg changed. The models, materials and map are identical to 1.1.1, so FastDL hosts need no update.
- The cfg in this package only has new descriptions: no cvar was added or changed. If you keep yours, nothing needs to change.

## Assets

- `umbrella_soccer-1.1.2-server.zip`: server package for the `cstrike` folder.
- `umbrella_soccer-1.1.2-fastdl.zip`: web-host package for FastDL, identical in content to 1.1.1.

## Installation

Extract `umbrella_soccer-1.1.2-server.zip` into the server `cstrike` folder, overwriting, and change the map.

Extract `umbrella_soccer-1.1.2-fastdl.zip` into the root folder used by `sv_downloadurl`.

## Build

- Compiled with SourcePawn 1.12.0.7255, no warnings.
- SHA256 (`umbrella_soccer.smx`): `574958D32BC0186F6ACC6D084A34F024E4F4B08AD301ED7A62C904B7D132D2B1`
