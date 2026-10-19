# Changelog

## 1.1.2

### Match flow
- A goal in stoppage time ends the period right there: break, overtime or final whistle. Before, play went on with a kickoff and the period only ended when that kickoff crossed the halfway line.

### Languages
- Added Russian (`ru`), Simplified Chinese (`chi`), Italian (`it`) and Japanese (`jp`) for every message, menu and HUD line, on top of English, Spanish, Portuguese, French and German. They use the stock SourceMod language codes, so a player whose game is in one of them sees the plugin in it.
- The goalkeeper areas help is sent as three short chat lines instead of one, since a long line could be cut off at the chat limit (the French one already was).

### Configuration
- Every cvar description in `cfg/sourcemod/umbrella_soccer.cfg` is now in English and identical to the plugin's own: a few were in Spanish and others no longer matched the code. The overtime and golden goal descriptions carry the examples the Spanish ones had.

Compiled with SourcePawn 1.12.0.7255, no warnings.
Plugin SHA256: `574958D32BC0186F6ACC6D084A34F024E4F4B08AD301ED7A62C904B7D132D2B1`

## 1.1.1

### Saves
- Saves are announced as "Salvada" ("Saved by" in English): they count for anyone, goalkeeper or defender, who touches the ball inside their own goalkeeper area right after an opponent.
- A save is counted and announced on that touch itself, instead of waiting for the next touch or a goal. If the ball still goes in before anyone else touches it, the save and its points are quietly taken back.
- That goal is the shooter's, not an own goal by the player who touched it last.
- `soccer_mod_ranking_points_save` defaults to 5 instead of 10. The same touch already earns the interception and hit points, so a save is worth 9 in all: more than a pass, less than an assist.
- Goalkeeper areas are marked with one menu choice each: stand in the middle of the goal and pick its team. The area is built in front of the goal, towards the centre spot, saved at once and outlined on the floor. Its size is set by `sm_soccer_gk_area_width` (640) and `sm_soccer_gk_area_depth` (224). Areas saved before keep working.

### Kickoffs
- The second half, and any later period, announces which team kicks off. Only the first half and overtime did.
- When the round timer runs out during a match, the new round starts with an announced kickoff for the team that did not touch the ball last, and the match clock waits for it. Before, the ball went back to the centre spot with no kickoff and the clock running.

### Penalties
- Each penalty is taken at the end of the goal the shooting team attacks: the stored spot is mirrored through the centre spot when it sits at the shooter's own goal. That end is found from the defending team's goalkeeper area, or else from its spawn points. Before, every kick used the same goal, so in a shootout one of the two teams could never score.
- A penalty during a match stops the clock until the kick. The kick puts the ball back in play: a goal counts on the scoreboard, is credited to whoever scored it and leads to a kickoff, like any other goal. A penalty not kicked in time is a miss and play resumes.
- The ball is placed on the spot standing still.
- A match penalty can only be given while the ball is in play: not after a goal, in a break or around a restart. One given while a kickoff waits replaces it. A pause also holds the time to take the kick, and when the round timer runs out before the kick, the restart's kickoff takes its place.

### Other fixes
- The HUD reads like the original soccermod's: `CT 1 - 0 T | 03:12`, with what holds play in front when something does (`Kick off CT: CT 1 - 0 T | 00:00`, `Paused: ...`, `Break 10s: ...`, `Overtime: ...` in English). A pause shows as a pause, also while a kickoff is waiting.
- Players with a red card can no longer be picked in a draft.

Compiled with SourcePawn 1.12.0.7255, no warnings.
Plugin SHA256: `58B78EB584BE9510B79AC5FE2CC45AEB83B872476BE8D3185EF6CE386A026D63`

## 1.1.0

### New
- Soccer server settings applied once when a soccer map starts, after the server and plugin configs: `phys_pushscale 2000` (ball kick force), `mp_freezetime 0`, `mp_roundtime 9`, `mp_maxrounds 0` and `mp_limitteams 0`. Each one is a `sm_soccer_server_*` cvar, and `sm_soccer_server_cvars 0` turns them all off.
- Persistent ranking, in SQLite by default (`data/sqlite/umbrella_soccer.sq3`) or MySQL through `databases.cfg` (`sm_soccer_ranking_driver`, `sm_soccer_ranking_database`). Match play and public play are ranked separately (`sm_soccer_ranking_public`). It records points, goals, assists, own goals, hits, passes, interceptions, ball losses, saves, rounds won and lost, matches and MVPs; the MVP gets `soccer_mod_ranking_points_motm` (50). `!rank` and `!top`, also in the player `!soccer` menu.
- Goalkeeper saves: touching the ball inside your own goalkeeper area right after an opponent touched it is a save, confirmed by the next touch from another player or a goal at the other end, and dropped if your team concedes before that (`soccer_mod_ranking_points_save`, 10). Penalties and shootouts do not count. The areas are set per map from the new admin menu entry and stored in `configs/umbrella_soccer_gk_areas.cfg`, which the plugin creates on the first save and the release does not ship, so updates never overwrite it.
- Red cards persist across matches, maps and reconnects in `data/umbrella_soccer_red_cards.txt` until a referee removes them, and block joining a team outside matches too. Only real Steam IDs are stored, so a card given to a bot or on a LAN server never spreads to everyone sharing that ID. The referee menu lists every stored red card, including offline players, to remove one.
- Training: every admin has a training ball of their own, the cannon fires the ball of whoever starts it, its fire rate and randomness can be set from the menu, and the goals can be disabled and enabled again.
- Optional limit of players per team during a match, as in the original soccermod: `sm_soccer_max_players_per_team` (0, off by default). A join to a full team is refused, auto-assign included, and players put on a full team any other way (admin move, a bigger draft, teams already over it at kickoff) are moved to spectator when they spawn.
- A player who joins T or CT mid-round is respawned after `sm_soccer_respawn_delay` instead of waiting for the next goal.

### Teams and cards
- `jointeam 0` (auto-assign) no longer bypasses red cards or draft sides. The listener picks the side itself (the drafted one, or the smaller team) and replays it as an explicit `jointeam`, so the usual checks apply.
- Draft sides (`gDraftTeam`) are cleared when the match stops, finishes or is reset. They used to stay for the rest of the map, so every later match locked out players who were not in that draft.

### Match flow
- Overtime is played as two halves. Each half lasts half of `soccer_mod_match_overtime_percent`, starts from a round restart like a regular period, and the normal break is played before the first half and between both halves. Golden goal still ends the match on the first overtime goal (not on a manual goal during the break before it).
- `sm_soccer_halftime` from the last period now ends that period as the clock would (overtime or final whistle) instead of replaying it. From a break it starts the pending period right away. It is ignored while a period restart is already pending, where it used to skip a period.
- `phys_timescale` is restored on map end. A map change during a pause or break left the next soccer map with frozen physics.

### Penalties
- When a shootout kick ends the round (a scored penalty, or any round end before the next kick), the next kick is set up 1 second after `round_start`. The fixed `sm_soccer_penalty_shot_delay` timer could fire before the round restart, which then moved the ball and players back to their spawns.
- A goal between shootout kicks no longer counts as a match goal.
- The shootout timer is tracked and killed on stop and finish, so a stale timer can no longer start an extra kick.
- A penalty or shootout cannot be started while another one is running, including between shootout kicks (`Penalty_Already_Active`).
- When no goalkeeper is given, penalties use whoever took the goalkeeper position with `!gk`, falling back to the first player of the team.

### Other
- Admin chat prompts (custom duration, cannon power, draft sizes) expire after 30 seconds, replace each other instead of stacking, and are dropped if the admin loses access.
- The training ball is never taken for the match ball, even though it keeps the `ball` targetname for map clip brushes. Disabling soccer on the map now removes it.
- Stamina recovers instead of draining while a player cannot move (break, period restart).
- The training cannon resets its state when origin and target are the same point.
- Removed 134 unused translation phrases.
- The training cannon speed messages showed `{1:.1f}` literally: phrase text now uses `{1}` and leaves the number format to `#format`.
- Added a GitHub Actions build that compiles the plugin with SourceMod 1.12.
- README rewritten without the cover image.

Compiled with SourcePawn 1.12.0.7255, no warnings.
Plugin SHA256: `D9525AF122FB895489B45412C3D0F3D0CEB605CFD9262165EE49D1F087DF4472`

## 1.0.1

### Penalties
- Penalty goals are detected automatically again. `EventRoundEnd` returned early while `gPenaltyActive`, so the penalty branch of `HandleGoal` was only reachable through a manual `sm_soccer_goal` and every penalty ended as a timeout miss. This also made the shootout unusable.
- `IsShootoutDecided` replaces the old shootout end check. The shootout now ends as soon as one team leads by more than the other can recover with the kicks it has left (3-0 after three rounds closes without taking the remaining two), and sudden death does not end until both teams have taken the same number of kicks. Both were missing before: all five kicks were always taken, and in the sixth round whoever kicked first won on scoring without a reply.
- The taker is placed behind the ball, facing the goal. The direction comes from `gBallStartPosition` (pitch centre) towards the penalty spot, which is the end being attacked, so the goals do not need to be named entities. Previously a fixed `-96.0` offset on X left the taker sideways on pitches laid out along Y. Without a cached centre the old offset is kept.
- Bots can no longer be picked as shootout takers (`GetNextShootoutShooter` now excludes `IsFakeClient`).

### Goals and round end
- Round end reasons that are not goals are ignored (`Draw`, `TargetSaved`, `HostagesNotRescued`, `TerroristsNotEscaped`, `VIPNotEscaped`, `GameStart`). Previously any round end with a winner counted as a goal, so a period longer than `mp_roundtime` expired on its own and handed CT a free goal.
- Round result points (`soccer_mod_ranking_points_round_won`/`_lost`) are awarded even when the last toucher cannot be identified. They used to sit inside the `if (IsValidClient(scorer))` block.
- The `trigger_hurt` damage restore runs once per goal (`gGoalDamageRestored` guard, reset on `round_start`), matching the original soccermod `goalScored`. Same behaviour, without the redundant loop.

### Other
- Red card: `GiveRedCard` restores damage before `ForcePlayerSuicide`, as `TimerMoveRedCardSpectator` already did. With `m_takedamage` at 0 the suicide could fail to apply.
- Stoppage time: the model that gives the trigger its bounding box is precached on map start instead of mid-round.
- Cleanup: removed two dead cvars with no effect (`sm_soccer_assist_window`, `sm_soccer_training_cannon_ball_life`).

Compiled with SourcePawn 1.12.0.7246, no warnings.
Plugin SHA256: `C64734BE28A2247051D0239B1C6B07995ADF628B4E40179ACDC5347FF9179B61`

## 1.0.0

- Initial release of the Umbrella Soccer rebuild for Counter-Strike: Source.
