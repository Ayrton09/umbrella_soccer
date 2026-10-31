<div align="center">

# ⚽ Umbrella Soccer

**A complete soccer mode for Counter-Strike: Source, built on SourceMod.**

[![Release](https://img.shields.io/github/v/release/Ayrton09/umbrella_soccer?label=release&color=2ea44f)](https://github.com/Ayrton09/umbrella_soccer/releases/latest)
[![Build](https://github.com/Ayrton09/umbrella_soccer/actions/workflows/build.yml/badge.svg)](https://github.com/Ayrton09/umbrella_soccer/actions/workflows/build.yml)
![Game](https://img.shields.io/badge/game-CS%3A%20Source-orange)
![SourceMod](https://img.shields.io/badge/SourceMod-1.12-blue)
[![License](https://img.shields.io/badge/license-GPLv3-lightgrey)](LICENSE)

[Download](https://github.com/Ayrton09/umbrella_soccer/releases/latest) · [Installation](#installation) · [Commands](#commands) · [Configuration](#configuration) · [Changelog](CHANGELOG.md)

</div>

---

## Features

| | |
| --- | --- |
| 🏟️ **Matches** | Selectable match length, halftime break, stoppage time, kickoffs, pause with countdown, live score HUD. |
| ⏱️ **Overtime** | Two overtime halves when a match ends tied, each starting from a restart. Optional golden goal. |
| 🥅 **Goals** | Goal, assist and own-goal announcements, with the last touches tracked to credit the right players. |
| 🧤 **Goalkeepers** | `!gk` toggles the goalkeeper kit. Saves are counted inside per-map goalkeeper areas. |
| 🏆 **Ranking** | Persistent stats in SQLite or MySQL, with separate match and public rankings, `!rank` and `!top`. |
| 🎯 **Penalties** | Shootouts that start by themselves after a tied overtime: captains line up their kickers, a TV-style board on the HUD, a referee whistle, and goals called by the plugin without killing anyone. Single penalties too. |
| 🟨 **Referee** | Yellow and red cards, score adjustments. Red cards last across maps until a referee removes them. |
| 👥 **Captains** | Snake draft with 2 to 4 captains and pick menus. Optional limit of players per team. |
| 🏃 **Sprint** | Stamina sprint on the walk key, shown as armor. |
| 🛠️ **Training** | A training ball per admin, a training cannon (power, fire rate, randomness) and goals that can be disabled. |
| 🌍 **Languages** | English, Spanish, Portuguese, French, German, Russian, Simplified Chinese, Italian and Japanese. Each player sees the plugin in their game language. |

## Requirements

- A Counter-Strike: Source dedicated server.
- SourceMod 1.12 (latest stable).

## Installation

Download both packages from the [latest release](https://github.com/Ayrton09/umbrella_soccer/releases/latest).

**Server**

1. Extract `umbrella_soccer-<version>-server.zip` into the server's `cstrike` folder.
2. Change the map (or restart the server).
3. Type `!soccer` in game to open the menu.

The server package contains:

```text
addons/sourcemod/plugins/umbrella_soccer.smx
addons/sourcemod/scripting/umbrella_soccer.sp
addons/sourcemod/scripting/umbrella_soccer/ranking.sp
addons/sourcemod/scripting/umbrella_soccer/saves.sp
addons/sourcemod/scripting/umbrella_soccer/shootout.sp
addons/sourcemod/translations/umbrella_soccer.phrases.txt
cfg/sourcemod/umbrella_soccer.cfg
sound/umbrella_soccer/...
models/...
materials/...
maps/ka_soccer_world_cup_2026.bsp
```

**FastDL**

1. Extract `umbrella_soccer-<version>-fastdl.zip` into the root folder used by your `sv_downloadurl`.
2. Check that the web host serves the folders directly:

```text
maps/ka_soccer_world_cup_2026.bsp.bz2
materials/...
models/...
```

Do not serve the FastDL zip itself; it only makes uploading easier.

## Commands

**Players**

| Command | Description |
| --- | --- |
| `!soccer` | Open the menu (the admin menu for admins). |
| `!gk` | Toggle the goalkeeper position. |
| `!position` | Show your current position. |
| `!rank` | Show your match and public ranking. |
| `!top` | Show the top 10. |
| `!pick` / `!draft` | Pick a player when you are a draft captain. |
| `!kickers` | Captains: line up the penalty shootout kickers (reopens the menu). |

**Admins** (generic admin flag)

Most of the administration is done from the `!soccer` menu. The same actions are available as commands:

| Command | Description |
| --- | --- |
| `sm_soccer_start` / `sm_soccer_stop` | Start or stop a match. |
| `sm_soccer_pause` / `sm_soccer_unpause` | Pause or resume the match. |
| `sm_soccer_reset` | Reset the match state. |
| `sm_soccer_halftime` | Move on to the next period. |
| `sm_soccer_kickoff` | Restart play with a kickoff. |
| `sm_soccer_spec_all` | Move every player on a team to spectator (not during a match or a draft). Also in the admin menu, under Captains. |
| `sm_soccer_spec <player>` | Move one player to spectator, also during a match. Also in the admin menu, under Captains, as a player list. |
| `sm_soccer_score <ct> <t>` | Set the score. |
| `sm_soccer_goal <ct/t>` | Award a goal. |
| `sm_soccer_yellow <target>` / `sm_soccer_red <target>` | Show a card. |
| `sm_soccer_position <target> <player/gk>` | Set a player's position. |
| `sm_soccer_captains <t> <ct>` / `sm_soccer_draftstart` | Set captains and start a draft. |
| `sm_soccer_penaltyspot` | Set the penalty spot where you aim (saved per map). |
| `sm_soccer_penalties [kickers]` | Start a penalty shootout, with that many kickers per team. |
| `sm_soccer_penalties <ct/t> [shooter] [goalkeeper]` | Start a single penalty. |
| `sm_soccer_trainingball` / `sm_soccer_cannon` | Spawn a training ball or toggle the cannon. |

## Configuration

All settings live in `cfg/sourcemod/umbrella_soccer.cfg`. The most useful ones:

**General**

| Cvar | Default | Description |
| --- | ---: | --- |
| `sm_soccer_enabled` | `1` | Enables the plugin. |
| `sm_soccer_allowed_maps` | `soccer_,ka_` | Map names or prefixes where soccer mode runs. |
| `sm_soccer_max_players_per_team` | `0` | Max players per team during a match. `0` = no limit. |
| `sm_soccer_live_replacement_slots` | `0` | Players outside the draft who may join a team mid-match. |

**Match**

| Cvar | Default | Description |
| --- | ---: | --- |
| `soccer_mod_match_period_length` | `3` | Period length, in minutes. |
| `soccer_mod_match_periods` | `2` | Number of periods. |
| `soccer_mod_match_period_break_length` | `10` | Break between periods, in seconds. |
| `soccer_mod_match_overtime` | `1` | Play overtime when the match ends tied. |
| `soccer_mod_match_overtime_percent` | `25.0` | Total overtime length as a percentage of the match, split in two halves. |
| `soccer_mod_match_golden_goal` | `0` | The first overtime goal wins. |

**Penalties**

| Cvar | Default | Description |
| --- | ---: | --- |
| `sm_soccer_penalty_shot_time` | `20` | Seconds to take a penalty. |
| `sm_soccer_penalty_warning_time` | `10` | Seconds left when the whistle blows again to hurry the kicker. `0` = off. |
| `sm_soccer_penalty_result_time` | `5` | Seconds after the kick for the ball to go in. |
| `sm_soccer_shootout_kickers` | `5` | Kickers per team when the shootout starts by itself or no number is given. |
| `sm_soccer_shootout_after_overtime` | `1` | Start a shootout by itself when overtime ends tied. |
| `sm_soccer_shootout_order_time` | `120` | Seconds to line up the kickers before the rest is filled in automatically. `0` = wait. |
| `sm_soccer_penalty_whistle` | `umbrella_soccer/whistle_short.wav` | Whistle for each kick and for the warning. Empty = off. |
| `sm_soccer_shootout_end_whistle` | `umbrella_soccer/whistle_long.wav` | Whistle when the shootout ends. Empty = off. |

**Server settings** (applied once when a soccer map starts)

| Cvar | Default | Description |
| --- | ---: | --- |
| `sm_soccer_server_cvars` | `1` | Apply the settings below. |
| `sm_soccer_server_phys_pushscale` | `2000` | Ball kick force. |
| `sm_soccer_server_freezetime` | `0` | `mp_freezetime`. |
| `sm_soccer_server_roundtime` | `9` | `mp_roundtime`, capped by the game. |
| `sm_soccer_server_maxrounds` | `0` | `mp_maxrounds`. `0` so goals never end the map. |
| `sm_soccer_server_limitteams` | `0` | `mp_limitteams`. `0` avoids "team is full". |

**Ranking and saves**

| Cvar | Default | Description |
| --- | ---: | --- |
| `sm_soccer_ranking` | `1` | Enables the ranking. |
| `sm_soccer_ranking_driver` | `sqlite` | `sqlite` or `mysql`. |
| `sm_soccer_ranking_database` | `umbrella_soccer` | SQLite file name, or the `databases.cfg` section for MySQL. |
| `sm_soccer_ranking_public` | `1` | Also rank play outside matches, separately. |
| `sm_soccer_saves` | `1` | Count saves inside the goalkeeper areas. |
| `sm_soccer_gk_area_width` | `640` | Width of a goalkeeper area marked from the menu. |
| `sm_soccer_gk_area_depth` | `224` | Depth of a goalkeeper area marked from the menu. |
| `soccer_mod_ranking_points_*` | | Points for goals, assists, saves, passes and more. |

## Ranking

The ranking works out of the box with a local SQLite file, `addons/sourcemod/data/sqlite/umbrella_soccer.sq3`.

To use MySQL, add a section to `addons/sourcemod/configs/databases.cfg`:

```text
"umbrella_soccer"
{
    "driver"    "mysql"
    "host"      "127.0.0.1"
    "database"  "soccer"
    "user"      "soccer"
    "pass"      "password"
}
```

Then set it in `cfg/sourcemod/umbrella_soccer.cfg` and change the map:

```text
sm_soccer_ranking_driver "mysql"
sm_soccer_ranking_database "umbrella_soccer"
```

## Goalkeeper areas

A save is counted, and announced, the moment a player, goalkeeper or defender, touches the ball inside their own goalkeeper area right after an opponent touched it. If the ball still goes in before anyone else touches it, the save is quietly taken back and the goal goes to the shooter instead of an own goal.

The areas also tell the plugin which end each team defends, so a penalty is always taken towards the goal the shooting team attacks.

The areas are set once per map:

1. Stand in the middle of the CT goal, on the goal line.
2. Open `!soccer` > **Goalkeeper areas** and choose **Mark CT area**. The area is built in front of the goal, saved and outlined on the floor for 10 seconds.
3. Do the same in the TT goal with **Mark TT area**.

Mark an area again to replace it, and use **Show areas** to see both. Their size is `sm_soccer_gk_area_width` (640) by `sm_soccer_gk_area_depth` (224). They are stored in `addons/sourcemod/configs/umbrella_soccer_gk_areas.cfg`.

## Penalty shootout

A shootout starts by itself when overtime ends tied, or from `!soccer` > Match > Penalties, where you also choose how many kickers each team has.

1. Each team's captain gets a menu to pick its kickers in order (`!kickers` opens it again). A team without a captain is lined up by an admin, and the penalty menu can fill in any order still open. Nothing is kicked until both orders are set, or until `sm_soccer_shootout_order_time` (2 minutes) runs out and the rest is filled in automatically.
2. The order is shown in chat, a coin toss picks who kicks first, and the kicks start 5 seconds later.
3. Everyone waits frozen at the waiting spot. The kicker is placed behind the ball and the defending goalkeeper on the goal line. A whistle opens each kick, and blows again with 10 seconds left. After the kick the kicker stays still, so there are no rebounds.
4. The HUD shows each team's kicks: `O` goal, `X` miss, `-` still to come. After the set kicks it goes to sudden death, and the winner is announced with the final whistle.

Goals do not kill anyone during penalties: the plugin sees the ball go in and calls it. On maps whose goals are not made with a ball trigger, the goal works as usual instead.

Before a shootout, mark from the penalties menu, once per map:

- **The penalty spot**: aim at it in front of either goal; the other goal uses the same spot mirrored. Without it, kicks are taken about 11 m in front of each goal, worked out from the goalkeeper areas.
- **Where players wait**: stand there. Without it they wait at the centre spot.

**Show the marks** draws both. They are stored in `addons/sourcemod/configs/umbrella_soccer_penalty_spots.cfg`.

## Included assets

| Asset | Path |
| --- | --- |
| Official map | `maps/ka_soccer_world_cup_2026.bsp` |
| Ball | `models/ayrton09/fifa_trionda_2026/trionda_2026.mdl` |
| Home kit | `models/player/soccer2026/home/ct_urban.mdl` |
| Away kit | `models/player/soccer2026/away/ct_urban.mdl` |
| Home goalkeeper | `models/player/soccer2026/gkhome/ct_urban.mdl` |
| Away goalkeeper | `models/player/soccer2026/gkaway/ct_urban.mdl` |
| Referee whistles | `sound/umbrella_soccer/whistle_short.wav`, `sound/umbrella_soccer/whistle_long.wav` |

## Notes

- Store or skin plugins can override the soccer kits. If players keep their store skin, disable that skin system on soccer maps.

## License

Released under the [GNU General Public License v3.0](LICENSE).
