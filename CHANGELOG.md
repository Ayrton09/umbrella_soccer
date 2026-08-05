# Changelog

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
