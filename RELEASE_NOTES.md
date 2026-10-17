# Umbrella Soccer 1.1.0

Feature release over 1.0.1: persistent ranking, goalkeeper saves, persistent red cards, overtime in two halves, a fuller training mode and the soccer server settings applied by the plugin. It also fixes several match flow bugs found while comparing the plugin with the original soccermod.

## New

- **Ranking**: persistent stats per player, stored in SQLite by default (nothing to set up) or MySQL through `databases.cfg`. Match play and public play are ranked separately. Players use `!rank` and `!top`, also available in the `!soccer` menu.
- **Goalkeeper saves**: a player who touches the ball inside their own goalkeeper area right after an opponent touched it gets a save and 10 points. Set the two areas once per map from `!soccer` > Goalkeeper areas.
- **Red cards**: they now persist across matches, maps and reconnects until a referee removes them. The referee menu lists every stored red card, including offline players.
- **Overtime in two halves**: when a match ends tied with overtime enabled, there is a break, a first half, another break and a second half, each half starting from a round restart.
- **Training**: one training ball per admin, cannon fire rate and randomness settable from the menu, and goals that can be disabled while training.
- **Server settings**: on soccer maps the plugin applies `phys_pushscale 2000`, `mp_freezetime 0`, `mp_roundtime 9`, `mp_maxrounds 0` and `mp_limitteams 0` once when the map starts. Each value is a `sm_soccer_server_*` cvar.
- **Players per team**: optional limit during a match with `sm_soccer_max_players_per_team` (off by default).
- **Late joiners** are respawned after `sm_soccer_respawn_delay` instead of waiting for the next goal.

## Fixes

- Auto-assign (`jointeam 0`) no longer lets red-carded players or players from another draft side into a team.
- Draft sides no longer lock players out of every later match on the same map.
- A map change during a pause or break no longer leaves the next map with frozen ball physics.
- Shootout: the kick after a goal is set up after the round restarts, so the ball and players are no longer sent back to their spawns; a goal between kicks no longer counts; a penalty cannot start on top of another one.
- `sm_soccer_halftime` from the last period ends it (overtime or final whistle) instead of replaying it.
- The training ball is never mistaken for the match ball.
- Admin chat prompts expire after 30 seconds and no longer stack.
- The training cannon speed messages no longer show raw `{1:.1f}` placeholders.

The full list is in `CHANGELOG.md`.

## Upgrading from 1.0.1

- `cfg/sourcemod/umbrella_soccer.cfg` in this package has every new cvar. If you overwrite yours, re-apply any values you had changed. If you keep yours, the new cvars simply use their defaults.
- The goalkeeper areas are not shipped: set them in game once per map. They are saved to `addons/sourcemod/configs/umbrella_soccer_gk_areas.cfg`.
- The ranking database is created on the first map start. For MySQL, add a `databases.cfg` section and set `sm_soccer_ranking_driver "mysql"` before that.
- Existing red cards from 1.0.1 were only kept in memory and are not carried over.

## Assets

- `umbrella_soccer-1.1.0-server.zip`: server package for the `cstrike` folder.
- `umbrella_soccer-1.1.0-fastdl.zip`: web-host package for FastDL. The models, materials and map are identical to 1.0.1, so there is no need to re-upload them if they are already hosted.

## Installation

Extract `umbrella_soccer-1.1.0-server.zip` into the server `cstrike` folder, overwriting. Change the map so the new settings and the ranking database are set up.

Extract `umbrella_soccer-1.1.0-fastdl.zip` into the root folder used by `sv_downloadurl`.

## Build

- Compiled with SourcePawn 1.12.0.7255, no warnings.
- SHA256 (`umbrella_soccer.smx`): `D9525AF122FB895489B45412C3D0F3D0CEB605CFD9262165EE49D1F087DF4472`
