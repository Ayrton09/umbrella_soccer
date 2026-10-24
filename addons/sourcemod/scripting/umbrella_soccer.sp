#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

#define PLUGIN_VERSION "1.1.2"

#if !defined IN_SPEED
#define IN_SPEED (1 << 17)
#endif

#define TEAM_T 2
#define TEAM_CT 3
#define MAX_ENTITY_NAME 64
#define MAX_AUTH_ID_LENGTH 32
#define PENALTY_MAX_SHOTS 5
#define PENALTY_SHOOTER_DISTANCE 96.0
#define PENALTY_ROUND_START_DELAY 1.0
#define OVERTIME_PERIODS 2
#define CHAT_INPUT_TIMEOUT 30.0
#define TRAINING_BALL_CLIP_NAME "ball"
#define STOPPAGE_TRIGGER_MODEL "models/props/cs_office/vending_machine.mdl"
#define DRAFT_MAX_CAPTAINS 4
#define DRAFT_INPUT_NONE 0
#define DRAFT_INPUT_CAPTAINS 1
#define DRAFT_INPUT_TEAMSIZE 2
#define PRACTICE_INPUT_NONE 0
#define PRACTICE_INPUT_CANNON_POWER 1
#define PRACTICE_INPUT_CANNON_RATE 2
#define PRACTICE_INPUT_CANNON_RANDOMNESS 3
#define MATCH_INPUT_NONE 0
#define MATCH_INPUT_DURATION 1
#define REF_ACTION_NONE 0
#define REF_ACTION_YELLOW 1
#define REF_ACTION_RED 2
#define REF_ACTION_CLEAR_PLAYER 3

public Plugin myinfo =
{
	name = "Umbrella Soccer",
	author = "Ayrton09",
	description = "Umbrella Soccer for Counter-Strike: Source",
	version = PLUGIN_VERSION,
	url = ""
};

enum SoccerPosition
{
	SoccerPosition_Player = 0,
	SoccerPosition_Goalkeeper
};

ConVar gCvarEnabled;
ConVar gCvarAllowedMaps;
ConVar gCvarBallName;
ConVar gCvarTouchCooldown;
ConVar gCvarRankingPointsGoal;
ConVar gCvarRankingPointsAssist;
ConVar gCvarRankingPointsOwnGoal;
ConVar gCvarRankingPointsHit;
ConVar gCvarRankingPointsPass;
ConVar gCvarRankingPointsInterception;
ConVar gCvarRankingPointsBallLoss;
ConVar gCvarRankingPointsRoundWon;
ConVar gCvarRankingPointsRoundLost;
ConVar gCvarSprintSpeed;
ConVar gCvarStaminaDrain;
ConVar gCvarStaminaRegen;
ConVar gCvarRespawnDelay;
ConVar gCvarAutoRespawn;
ConVar gCvarShowHud;
ConVar gCvarHudUseHint;
ConVar gCvarModelCT;
ConVar gCvarModelCTGK;
ConVar gCvarModelT;
ConVar gCvarModelTGK;
ConVar gCvarGoalkeeperCooldown;
ConVar gCvarMatchPeriods;
ConVar gCvarMatchPeriodLength;
ConVar gCvarMatchBreakLength;
ConVar gCvarMatchOvertime;
ConVar gCvarMatchOvertimePercent;
ConVar gCvarMatchGoldenGoal;
ConVar gCvarPenaltyShotTime;
ConVar gCvarPenaltyShotDelay;
ConVar gCvarPenaltyTurnSound;
ConVar gCvarTrainingBallModel;
ConVar gCvarTrainingCannonFireRate;
ConVar gCvarTrainingCannonPower;
ConVar gCvarTrainingCannonRandomness;
ConVar gCvarLiveReplacementSlots;
ConVar gCvarCaptainModeDefault;
ConVar gCvarMaxPlayersPerTeam;
ConVar gCvarServerCvars;
ConVar gCvarServerPushscale;
ConVar gCvarServerFreezetime;
ConVar gCvarServerRoundtime;
ConVar gCvarServerMaxrounds;
ConVar gCvarServerLimitteams;
bool gServerCvarsApplied;

Handle gHudSync;
Handle gHudTimer;
Handle gRespawnTimer[MAXPLAYERS + 1];
Handle gPenaltyTimer;
Handle gPeriodTimer;
Handle gBreakTimer;
Handle gPeriodRestartTimer;
Handle gUnpauseTimer;
Handle gStoppageTimer;
Handle gTrainingCannonTimer;
Handle gShootoutTimer;

bool gMatchLive;
bool gPaused;
bool gUnpausing;
bool gMapAllowed;
bool gHookedEntity[2049];
int gBallEnt = -1;
int gBallRef = INVALID_ENT_REFERENCE;
int gScoreCT;
int gScoreT;
float gLastGoalTime;
int gCurrentPeriod;
int gMaxPeriods;
bool gInBreak;
bool gOvertimeActive;
bool gKickoffActive;
bool gKickoffFrozen;
bool gKickoffQueued;
bool gInitialRestartPending;
bool gRoundGoalHandled;
bool gGoalDamageRestored;
bool gRoundEnded;
bool gRestartingPeriod;
bool gStoppageActive;
bool gPhysicsFrozen;
int gKickoffTeam;
int gQueuedKickoffTeam;
int gOpeningKickoffTeam;
char gKickoffReasonPhrase[64];
char gQueuedKickoffReasonPhrase[64];
char gPendingRestartKickoffReason[64];
float gPeriodRemaining;
float gPeriodDuration;
float gPeriodElapsed;
float gMatchElapsed;
float gPendingRestartPeriodLength;
float gPeriodEndTime;
float gBreakEndTime;
int gStoppageSeconds;
int gUnpauseSecondsLeft;
int gStoppageTriggerRef = INVALID_ENT_REFERENCE;
float gBallStartPosition[3];
bool gBallStartPositionValid;
float gSavedPhysTimescale = 1.0;
float gSavedPhysPushscale = 1.0;

int gLastToucher;
int gPreviousToucher;
float gClientLastTouch[MAXPLAYERS + 1];
int gPlayerGoals[MAXPLAYERS + 1];
int gPlayerAssists[MAXPLAYERS + 1];
int gPlayerOwnGoals[MAXPLAYERS + 1];
int gPlayerPoints[MAXPLAYERS + 1];

int gYellowCards[MAXPLAYERS + 1];
bool gRedCard[MAXPLAYERS + 1];
float gStamina[MAXPLAYERS + 1];
bool gSprinting[MAXPLAYERS + 1];
int gLastArmorValue[MAXPLAYERS + 1];
float gNextGoalkeeperToggle[MAXPLAYERS + 1];
SoccerPosition gPosition[MAXPLAYERS + 1];
StringMap gRedCards;
char gRedCardsPath[PLATFORM_MAX_PATH];

bool gDraftActive;
int gDraftCaptainT;
int gDraftCaptainCT;
int gDraftCaptainCount;
int gDraftTeamSize;
int gDraftCaptains[DRAFT_MAX_CAPTAINS];
int gDraftCurrentGroup;
int gDraftPickCount;
bool gDraftPicked[MAXPLAYERS + 1];
int gDraftTeam[MAXPLAYERS + 1];
int gDraftGroup[MAXPLAYERS + 1];
int gDraftSetupInput[MAXPLAYERS + 1];
int gDraftSetupCaptainCount[MAXPLAYERS + 1];
int gDraftSelectedCaptainCount[MAXPLAYERS + 1];
int gDraftSelectedCaptains[MAXPLAYERS + 1][DRAFT_MAX_CAPTAINS];
int gPracticeInput[MAXPLAYERS + 1];
int gMatchInput[MAXPLAYERS + 1];
float gChatInputExpires[MAXPLAYERS + 1];

bool gPenaltyActive;
bool gPenaltyWaitingForKick;
bool gShootoutActive;
int gPenaltyTeam;
int gPenaltyShooter;
int gPenaltyGoalkeeper;
float gPenaltySpot[3];
// Where the current kick is taken: the stored spot, or its mirror through the
// centre spot when the stored one is at the shooting team's own goal.
float gPenaltyKickSpot[3];
bool gPenaltyKickSpotOriented;
bool gPenaltySpotValid;
int gShootoutScoreCT;
int gShootoutScoreT;
int gShootoutTakenCT;
int gShootoutTakenT;
int gShootoutNextTeam;
int gShootoutShooterIndexCT;
int gShootoutShooterIndexT;
bool gShootoutWaitingRoundStart;

int gTrainingBallRefs[MAXPLAYERS + 1];
bool gTrainingGoalsDisabled;
int gTrainingCannonBallRef = INVALID_ENT_REFERENCE;
float gTrainingCannonOrigin[3];
float gTrainingCannonTarget[3];
bool gTrainingCannonOriginSet;
bool gTrainingCannonTargetSet;
bool gTrainingCannonSet;

int gRefereeAction[MAXPLAYERS + 1];

#include "umbrella_soccer/ranking.sp"
#include "umbrella_soccer/saves.sp"

public void OnPluginStart()
{
	if (GetEngineVersion() != Engine_CSS)
	{
		SetFailState("Umbrella Soccer CSS rebuild only supports Counter-Strike: Source.");
	}

	LoadTranslations("common.phrases");
	LoadTranslations("umbrella_soccer.phrases");

	CreateConVar("umbrella_soccer_css_version", PLUGIN_VERSION, "Umbrella Soccer CS:S rebuild version.", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	gCvarEnabled = CreateConVar("sm_soccer_enabled", "1", "Enable Umbrella Soccer for Counter-Strike: Source.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	gCvarAllowedMaps = CreateConVar("sm_soccer_allowed_maps", "soccer_,ka_", "Comma-separated map names or prefixes allowed for soccer mode. Empty disables the plugin on every map.", FCVAR_NONE);
	gCvarBallName = CreateConVar("sm_soccer_ball_name", "ball", "Targetname used by the soccer ball entity.", FCVAR_NONE);
	gCvarTouchCooldown = CreateConVar("sm_soccer_touch_cooldown", "0.0", "Minimum seconds between counted ball touches for the same player. Original behavior is 0.", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	gCvarRankingPointsGoal = CreateConVar("soccer_mod_ranking_points_goal", "25", "Points received for scoring a goal. Original default: 25.", FCVAR_NOTIFY, true, -100.0, true, 100.0);
	gCvarRankingPointsAssist = CreateConVar("soccer_mod_ranking_points_assist", "15", "Points received for giving an assist. Original default: 15.", FCVAR_NOTIFY, true, -100.0, true, 100.0);
	gCvarRankingPointsOwnGoal = CreateConVar("soccer_mod_ranking_points_own_goal", "-50", "Points received for scoring an own goal. Original default: -50.", FCVAR_NOTIFY, true, -100.0, true, 100.0);
	gCvarRankingPointsHit = CreateConVar("soccer_mod_ranking_points_hit", "1", "Points received for touching the ball. Original default: 1.", FCVAR_NOTIFY, true, -100.0, true, 100.0);
	gCvarRankingPointsPass = CreateConVar("soccer_mod_ranking_points_pass", "5", "Points received for passing to a teammate. Original default: 5.", FCVAR_NOTIFY, true, -100.0, true, 100.0);
	gCvarRankingPointsInterception = CreateConVar("soccer_mod_ranking_points_interception", "3", "Points received for intercepting the ball. Original default: 3.", FCVAR_NOTIFY, true, -100.0, true, 100.0);
	gCvarRankingPointsBallLoss = CreateConVar("soccer_mod_ranking_points_ball_loss", "-3", "Points received for losing the ball. Original default: -3.", FCVAR_NOTIFY, true, -100.0, true, 100.0);
	gCvarRankingPointsRoundWon = CreateConVar("soccer_mod_ranking_points_round_won", "10", "Points received by each player on the team that won the goal round. Original default: 10.", FCVAR_NOTIFY, true, -100.0, true, 100.0);
	gCvarRankingPointsRoundLost = CreateConVar("soccer_mod_ranking_points_round_lost", "-10", "Points received by each player on the team that lost the goal round. Original default: -10.", FCVAR_NOTIFY, true, -100.0, true, 100.0);
	gCvarSprintSpeed = CreateConVar("sm_soccer_sprint_speed", "1.25", "Movement multiplier while sprinting.", FCVAR_NOTIFY, true, 1.0, true, 2.0);
	gCvarStaminaDrain = CreateConVar("sm_soccer_stamina_drain", "33.333333", "Stamina consumed per second while sprinting.", FCVAR_NOTIFY, true, 1.0, true, 200.0);
	gCvarStaminaRegen = CreateConVar("sm_soccer_stamina_regen", "8.333333", "Stamina recovered per second while not sprinting.", FCVAR_NOTIFY, true, 0.0, true, 200.0);
	gCvarRespawnDelay = CreateConVar("sm_soccer_respawn_delay", "3.0", "Respawn delay during a live soccer match.", FCVAR_NOTIFY, true, 0.0, true, 10.0);
	gCvarAutoRespawn = CreateConVar("sm_soccer_auto_respawn", "1", "Automatically respawn dead players during a live match.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	gCvarShowHud = CreateConVar("sm_soccer_show_hud", "1", "Show the soccer score HUD.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	gCvarHudUseHint = CreateConVar("sm_soccer_hud_use_hint", "1", "Use hint HUD text instead of sync HUD text.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	gCvarModelCT = CreateConVar("soccer_mod_skins_model_ct", "models/player/soccer2026/away/ct_urban.mdl", "Default CT outfield model.", FCVAR_NONE);
	gCvarModelCTGK = CreateConVar("soccer_mod_skins_model_ct_gk", "models/player/soccer2026/gkaway/ct_urban.mdl", "Default CT goalkeeper model.", FCVAR_NONE);
	gCvarModelT = CreateConVar("soccer_mod_skins_model_t", "models/player/soccer2026/home/ct_urban.mdl", "Default T outfield model.", FCVAR_NONE);
	gCvarModelTGK = CreateConVar("soccer_mod_skins_model_t_gk", "models/player/soccer2026/gkhome/ct_urban.mdl", "Default T goalkeeper model.", FCVAR_NONE);
	gCvarGoalkeeperCooldown = CreateConVar("sm_soccer_gk_cooldown", "5.0", "Seconds a player must wait before toggling goalkeeper position again.", FCVAR_NOTIFY, true, 0.0, true, 60.0);
	gCvarMatchPeriods = CreateConVar("soccer_mod_match_periods", "2", "Number of match periods.", FCVAR_NOTIFY, true, 1.0, true, 8.0);
	gCvarMatchPeriodLength = CreateConVar("soccer_mod_match_period_length", "3", "Match period length in MINUTES. Example: 3 = 3 minutes per period.", FCVAR_NOTIFY, true, 1.0, true, 60.0);
	gCvarMatchBreakLength = CreateConVar("soccer_mod_match_period_break_length", "10", "Break length between periods in SECONDS, not minutes. Example: 10 = 10 seconds.", FCVAR_NOTIFY, true, 0.0, true, 600.0);
	gCvarMatchOvertime = CreateConVar("soccer_mod_match_overtime", "1", "Play overtime when a match is tied after regulation.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	gCvarMatchOvertimePercent = CreateConVar("soccer_mod_match_overtime_percent", "25.0", "Overtime length as a percentage of total match time, rounded up to full minutes and played in two halves. Example: 2 periods of 3 minutes = 6 minutes; 25% = 1:30, rounded up to 2 minutes of overtime.", FCVAR_NOTIFY, true, 1.0, true, 100.0);
	gCvarMatchGoldenGoal = CreateConVar("soccer_mod_match_golden_goal", "0", "1 = the first goal during overtime wins; if overtime ends tied, the match remains tied. 0 = overtime is played in full.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	gCvarPenaltyShotTime = CreateConVar("sm_soccer_penalty_shot_time", "15", "Seconds the shooter has to take a penalty, and then for the ball to go in, before it counts as a miss.", FCVAR_NOTIFY, true, 3.0, true, 45.0);
	gCvarPenaltyShotDelay = CreateConVar("sm_soccer_penalty_shot_delay", "4.0", "Delay in seconds before restarting to the next penalty shot.", FCVAR_NOTIFY, true, 0.2, true, 10.0);
	gCvarPenaltyTurnSound = CreateConVar("sm_soccer_penalty_turn_sound", "buttons/blip1.wav", "Sound played to the shooter when it is their penalty turn. Empty disables.", FCVAR_NONE);
	gCvarTrainingBallModel = CreateConVar("sm_soccer_training_ball_model", "models/ayrton09/fifa_trionda_2026/trionda_2026.mdl", "Model used for spawned training balls. Empty disables training ball spawning.", FCVAR_NONE);
	gCvarTrainingCannonFireRate = CreateConVar("sm_soccer_training_cannon_fire_rate", "2.5", "Seconds between training cannon shots.", FCVAR_NOTIFY, true, 0.2, true, 30.0);
	gCvarTrainingCannonPower = CreateConVar("sm_soccer_training_cannon_power", "900.0", "Velocity applied by the training cannon.", FCVAR_NOTIFY, true, 100.0, true, 3000.0);
	gCvarTrainingCannonRandomness = CreateConVar("sm_soccer_training_cannon_randomness", "0.0", "Random velocity spread added to training cannon shots.", FCVAR_NOTIFY, true, 0.0, true, 500.0);
	gCvarLiveReplacementSlots = CreateConVar("sm_soccer_live_replacement_slots", "0", "How many non-assigned replacements can join T/CT during a live match.", FCVAR_NOTIFY, true, 0.0, true, 10.0);
	gCvarCaptainModeDefault = CreateConVar("sm_soccer_captain_mode_default", "0", "Start a captain draft automatically when valid captains are available.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	gCvarMaxPlayersPerTeam = CreateConVar("sm_soccer_max_players_per_team", "0", "Maximum players per team during a match. Extra players go to spectator. 0 disables the limit.", FCVAR_NOTIFY, true, 0.0, true, 32.0);
	gCvarServerCvars = CreateConVar("sm_soccer_server_cvars", "1", "Apply the sm_soccer_server_* settings once when an allowed map starts.", FCVAR_NONE, true, 0.0, true, 1.0);
	gCvarServerPushscale = CreateConVar("sm_soccer_server_phys_pushscale", "2000", "phys_pushscale used on soccer maps. Sets how hard knife hits push the ball.", FCVAR_NONE, true, 1.0, true, 10000.0);
	gCvarServerFreezetime = CreateConVar("sm_soccer_server_freezetime", "0", "mp_freezetime used on soccer maps, in seconds.", FCVAR_NONE, true, 0.0, true, 60.0);
	gCvarServerRoundtime = CreateConVar("sm_soccer_server_roundtime", "9", "mp_roundtime used on soccer maps, in minutes. The game caps it at its own maximum.", FCVAR_NONE, true, 1.0, true, 60.0);
	gCvarServerMaxrounds = CreateConVar("sm_soccer_server_maxrounds", "0", "mp_maxrounds used on soccer maps. Every goal is a round, so 0 (no limit) keeps goals from ending the map.", FCVAR_NONE, true, 0.0, true, 1000.0);
	gCvarServerLimitteams = CreateConVar("sm_soccer_server_limitteams", "0", "mp_limitteams used on soccer maps. 0 lets players join a team whatever the team sizes are.", FCVAR_NONE, true, 0.0, true, 30.0);
	RankingOnPluginStart();
	SavesOnPluginStart();
	TrainingOnPluginStart();
	LoadRedCards();

	RegConsoleCmd("sm_soccer", CmdSoccerMenu, "Open the Umbrella Soccer menu.");
	RegConsoleCmd("sm_gk", CmdToggleGoalkeeper, "Toggle goalkeeper position.");
	RegConsoleCmd("sm_position", CmdPosition, "Show your current soccer position.");

	RegAdminCmd("sm_socceradmin", CmdAdminMenu, ADMFLAG_GENERIC, "Open the Umbrella Soccer admin menu.");
	RegAdminCmd("sm_soccer_start", CmdStart, ADMFLAG_GENERIC, "Start a soccer match.");
	RegAdminCmd("sm_soccer_stop", CmdStop, ADMFLAG_GENERIC, "Stop the current soccer match.");
	RegAdminCmd("sm_soccer_reset", CmdReset, ADMFLAG_GENERIC, "Reset the soccer match state.");
	RegAdminCmd("sm_soccer_pause", CmdPause, ADMFLAG_GENERIC, "Pause the soccer match.");
	RegAdminCmd("sm_soccer_unpause", CmdUnpause, ADMFLAG_GENERIC, "Unpause the soccer match.");
	RegAdminCmd("sm_soccer_setball", CmdSetBall, ADMFLAG_GENERIC, "Save the current soccer ball origin as spawn.");
	RegAdminCmd("sm_soccer_score", CmdScore, ADMFLAG_GENERIC, "Set score: sm_soccer_score <ct> <t>.");
	RegAdminCmd("sm_soccer_goal", CmdGoal, ADMFLAG_GENERIC, "Force goal: sm_soccer_goal <ct/t>.");
	RegAdminCmd("sm_soccer_position", CmdAdminPosition, ADMFLAG_GENERIC, "Set player position: sm_soccer_position <target> <player/gk>.");
	RegAdminCmd("sm_soccer_halftime", CmdHalftime, ADMFLAG_GENERIC, "Force the next match period.");
	RegAdminCmd("sm_soccer_kickoff", CmdKickoff, ADMFLAG_GENERIC, "Start a manual center kick.");
	RegAdminCmd("sm_soccer_spec_all", CmdSpecAll, ADMFLAG_GENERIC, "Move every player on a team to spectator. Not during a match or a draft.");
	RegAdminCmd("sm_soccer_spec", CmdSpecPlayer, ADMFLAG_GENERIC, "Move one player to spectator: sm_soccer_spec <player>.");
	RegAdminCmd("sm_soccer_yellow", CmdYellow, ADMFLAG_GENERIC, "Give a yellow card: sm_soccer_yellow <target>.");
	RegAdminCmd("sm_soccer_red", CmdRed, ADMFLAG_GENERIC, "Give a red card: sm_soccer_red <target>.");
	RegAdminCmd("sm_soccer_captains", CmdCaptains, ADMFLAG_GENERIC, "Set draft captains: sm_soccer_captains <t captain> <ct captain>.");
	RegAdminCmd("sm_soccer_draftstart", CmdDraftStart, ADMFLAG_GENERIC, "Start a snake draft.");
	RegAdminCmd("sm_soccer_penaltyspot", CmdPenaltySpot, ADMFLAG_GENERIC, "Set the penalty spot at your aim position.");
	RegAdminCmd("sm_soccer_penalties", CmdPenalties, ADMFLAG_GENERIC, "Start one penalty: sm_soccer_penalties <ct/t> [shooter] [goalkeeper].");
	RegAdminCmd("sm_soccer_trainingball", CmdTrainingBall, ADMFLAG_GENERIC, "Spawn a training ball at your aim position.");
	RegAdminCmd("sm_soccer_cannon", CmdTrainingCannon, ADMFLAG_GENERIC, "Toggle a simple training cannon from your aim direction.");
	RegConsoleCmd("sm_pick", CmdPick, "Draft captain pick command.");
	RegConsoleCmd("sm_draft", CmdDraftMenu, "Open the draft pick menu.");
	RegConsoleCmd("sm_soccer_draftmenu", CmdDraftMenu, "Open the draft pick menu.");
	RegConsoleCmd("sm_soccer_draftshow", CmdDraftShow, "Show draft status.");

	HookEntityOutput("func_physbox", "OnAwakened", OutputBallAwakened);
	HookEntityOutput("prop_physics", "OnAwakened", OutputBallAwakened);
	HookEntityOutput("func_physbox", "OnDamaged", OutputBallDamaged);
	HookEntityOutput("prop_physics", "OnTakeDamage", OutputBallDamaged);
	HookEntityOutput("trigger_hurt", "OnStartTouch", OutputGoalTriggerStartTouch);
	HookEntityOutput("trigger_once", "OnStartTouch", OutputGoalTriggerStartTouch);
	HookEvent("round_start", EventRoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", EventRoundEnd, EventHookMode_Post);
	HookEvent("player_hurt", EventPlayerHurt, EventHookMode_Post);
	HookEvent("player_spawn", EventPlayerSpawn, EventHookMode_Post);
	HookEvent("player_death", EventPlayerDeath, EventHookMode_Post);
	HookEvent("player_team", EventPlayerTeam, EventHookMode_Post);
	AddCommandListener(CommandJoinTeam, "jointeam");
	AddCommandListener(CommandSay, "say");
	AddCommandListener(CommandSay, "say_team");

	gHudSync = CreateHudSynchronizer();
	gHudTimer = CreateTimer(1.0, TimerHud, _, TIMER_REPEAT);
	gCvarEnabled.AddChangeHook(OnEnabledChanged);
	gCvarAllowedMaps.AddChangeHook(OnAllowedMapsChanged);

	AutoExecConfig(true, "umbrella_soccer", "sourcemod");

	for (int client = 1; client <= MaxClients; client++)
	{
		ResetClientState(client);
		if (IsClientInGame(client))
		{
			HookPlayerDamage(client);
			ApplyPlayerDamageRules(client);
			ApplyStoredRedCard(client);
		}
	}
}

public void OnMapStart()
{
	gServerCvarsApplied = false;
	ClearMatchRuntimeState();
	TrainingOnMapStart();
	SavesOnMapStart();
	ApplyMapAllowedState();
}

public void OnConfigsExecuted()
{
	ApplyMapAllowedState();
	if (gMapAllowed)
	{
		ApplySoccerServerCvars();
	}
	RankingOnConfigsExecuted();
	SavesOnConfigsExecuted();
}

// Applied once per map, after server.cfg and the plugin config have run, so
// they are not reapplied every round and an admin can still change them live.
void ApplySoccerServerCvars()
{
	if (gServerCvarsApplied || !gCvarServerCvars.BoolValue)
	{
		return;
	}
	gServerCvarsApplied = true;

	SetServerCvarFrom("phys_pushscale", gCvarServerPushscale);
	SetServerCvarFrom("mp_freezetime", gCvarServerFreezetime);
	SetServerCvarFrom("mp_roundtime", gCvarServerRoundtime);
	SetServerCvarFrom("mp_maxrounds", gCvarServerMaxrounds);
	SetServerCvarFrom("mp_limitteams", gCvarServerLimitteams);
}

// Changes a game cvar without the "server cvar changed" chat notice.
void SetServerCvarFrom(const char[] name, ConVar source)
{
	ConVar target = FindConVar(name);
	if (target == null)
	{
		return;
	}

	char value[32];
	source.GetString(value, sizeof(value));
	int flags = target.Flags;
	target.Flags = flags & ~FCVAR_NOTIFY;
	target.SetString(value);
	target.Flags = flags;
}

public void OnMapEnd()
{
	KillMatchTimers();
	KillStoppageTrigger();
	StopTrainingCannon();
	for (int client = 1; client <= MaxClients; client++)
	{
		gRespawnTimer[client] = null;
	}
	ResetEntityHooks();
	ClearBallEntity();
	RankingFlushAll();
	ClearTrainingBallRefs();
	gTrainingCannonBallRef = INVALID_ENT_REFERENCE;
	gTrainingCannonOriginSet = false;
	gTrainingCannonTargetSet = false;
	gTrainingCannonSet = false;
	gPenaltyActive = false;
	gPenaltyWaitingForKick = false;
	gPenaltyShooter = 0;
	gPenaltyGoalkeeper = 0;
	gShootoutActive = false;
	gKickoffActive = false;
	gKickoffFrozen = false;
	gStoppageActive = false;
	gStoppageSeconds = 0;
	gInitialRestartPending = false;
	ClearMatchRuntimeState();
	// phys_timescale is a global cvar: leaving it at 0 would freeze the next map.
	UnfreezeSoccerPhysics();
	gMapAllowed = false;
}

public void OnAllowedMapsChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	ApplyMapAllowedState();
}

public void OnEnabledChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (gCvarEnabled.BoolValue)
	{
		ApplyMapAllowedState();
	}
	else
	{
		DisableSoccerForMap();
	}
}

public void OnPluginEnd()
{
	RemoveCommandListener(CommandJoinTeam, "jointeam");
	RemoveCommandListener(CommandSay, "say");
	RemoveCommandListener(CommandSay, "say_team");
	KillMatchTimers();
	KillStoppageTrigger();
	StopTrainingCannon();
	KillTimerSafe(gHudTimer);
	RankingFlushAll();
	gKickoffFrozen = false;
	gPaused = false;
	gInBreak = false;
	gRestartingPeriod = false;
	UnfreezeAllPlayers();
	for (int client = 1; client <= MaxClients; client++)
	{
		KillClientRespawnTimer(client);
		StopSprint(client);
		RestorePlayerDamage(client);
		UnhookPlayerDamage(client);
	}
}

public void OnClientPutInServer(int client)
{
	ResetClientState(client);
	ApplyStoredRedCard(client);
	HookPlayerDamage(client);
	RankingOnClientPutInServer(client);
}

public void OnClientAuthorized(int client, const char[] auth)
{
	ApplyStoredRedCardAuth(client, auth);
}

public void OnClientDisconnect(int client)
{
	if (gPenaltyActive)
	{
		if (client == gPenaltyShooter)
		{
			ResolvePenalty(false);
		}
		else if (client == gPenaltyGoalkeeper)
		{
			gPenaltyGoalkeeper = 0;
		}
	}

	if (gDraftActive && IsDraftCaptain(client))
	{
		CancelDraft(true);
	}
	if (client == gDraftCaptainT)
	{
		gDraftCaptainT = 0;
	}
	if (client == gDraftCaptainCT)
	{
		gDraftCaptainCT = 0;
	}
	for (int i = 0; i < DRAFT_MAX_CAPTAINS; i++)
	{
		if (gDraftCaptains[i] == client)
		{
			gDraftCaptains[i] = 0;
		}
	}
	for (int admin = 1; admin <= MaxClients; admin++)
	{
		RemoveDraftSetupCaptain(admin, client);
	}
	gDraftPicked[client] = false;
	gDraftTeam[client] = 0;
	gDraftGroup[client] = 0;
	gDraftSetupInput[client] = DRAFT_INPUT_NONE;
	gDraftSetupCaptainCount[client] = 0;
	gPracticeInput[client] = PRACTICE_INPUT_NONE;
	gMatchInput[client] = MATCH_INPUT_NONE;
	gRefereeAction[client] = REF_ACTION_NONE;
	ClearDraftCaptainSelection(client);
	KillClientRespawnTimer(client);
	StopSprint(client);
	UnhookPlayerDamage(client);
	SavesOnClientDisconnect(client);
	RemoveClientTrainingBall(client);
	RankingOnClientDisconnect(client);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (IsSoccerAvailable() && entity > 0 && entity < sizeof(gHookedEntity))
	{
		RequestFrame(FrameHookEntity, EntIndexToEntRef(entity));
	}
}

public void OnEntityDestroyed(int entity)
{
	if (entity > 0 && entity < sizeof(gHookedEntity))
	{
		gHookedEntity[entity] = false;
	}
	if (entity == gBallEnt)
	{
		ClearBallEntity();
	}

	for (int client = 1; client <= MaxClients; client++)
	{
		if (gTrainingBallRefs[client] != INVALID_ENT_REFERENCE && EntRefToEntIndex(gTrainingBallRefs[client]) == entity)
		{
			gTrainingBallRefs[client] = INVALID_ENT_REFERENCE;
		}
	}
	int cannonBall = EntRefToEntIndex(gTrainingCannonBallRef);
	if (cannonBall != INVALID_ENT_REFERENCE && entity == cannonBall)
	{
		gTrainingCannonBallRef = INVALID_ENT_REFERENCE;
	}
	int stoppageTrigger = EntRefToEntIndex(gStoppageTriggerRef);
	if (stoppageTrigger != INVALID_ENT_REFERENCE && entity == stoppageTrigger)
	{
		gStoppageTriggerRef = INVALID_ENT_REFERENCE;
	}
}

public void FrameHookEntity(any ref)
{
	int entity = EntRefToEntIndex(ref);
	if (entity != INVALID_ENT_REFERENCE && IsValidEntity(entity))
	{
		HookSoccerEntity(entity);
	}
}

public void OutputBallAwakened(const char[] output, int caller, int activator, float delay)
{
	if (!IsSoccerAvailable() || !IsBallEntity(caller))
	{
		return;
	}

	BeginPeriodClockAfterKickoff();
}

public void OutputBallDamaged(const char[] output, int caller, int activator, float delay)
{
	if (!IsSoccerAvailable() || !IsBallEntity(caller) || !IsValidClient(activator))
	{
		return;
	}

	RegisterBallTouch(activator, caller);
	RegisterPenaltyTouch(activator);
}

public void OutputGoalTriggerStartTouch(const char[] output, int caller, int activator, float delay)
{
	if (!IsSoccerAvailable())
	{
		return;
	}

	char classname[64];
	GetEntityClassname(caller, classname, sizeof(classname));
	char callerName[MAX_ENTITY_NAME];
	GetEntPropString(caller, Prop_Data, "m_iName", callerName, sizeof(callerName));
	if (StrEqual(classname, "trigger_once", false) && StrEqual(callerName, "end_stoppage_time", false))
	{
		EndStoppageTime();
		return;
	}

	if (!IsValidClient(activator) || !StrEqual(classname, "trigger_hurt", false))
	{
		return;
	}

	if (gGoalDamageRestored)
	{
		return;
	}
	gGoalDamageRestored = true;

	for (int client = 1; client <= MaxClients; client++)
	{
		RestorePlayerDamage(client);
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}

	if (!IsSoccerAvailable())
	{
		if (gSprinting[client])
		{
			StopSprint(client);
		}
		return Plugin_Continue;
	}

	bool wantsSprint = (buttons & IN_SPEED) != 0
		&& ((buttons & IN_FORWARD) != 0
			|| (buttons & IN_BACK) != 0
			|| (buttons & IN_MOVELEFT) != 0
			|| (buttons & IN_MOVERIGHT) != 0);

	UpdateSprint(client, wantsSprint);
	if ((buttons & IN_SPEED) != 0 && wantsSprint)
	{
		buttons &= ~IN_SPEED;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action EventRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!IsSoccerAvailable())
	{
		return Plugin_Continue;
	}

	gRoundEnded = false;
	gRoundGoalHandled = false;
	gGoalDamageRestored = false;
	ClearLastTouchers();
	SavesOnRoundStart();
	RankingFlushAll();
	if (gTrainingGoalsDisabled && !gMatchLive)
	{
		KillGoalTriggers();
	}
	DiscoverSoccerEntities();
	CacheBallStartPosition();
	if (gStoppageActive)
	{
		EnsureStoppageTrigger();
	}
	if (gShootoutWaitingRoundStart)
	{
		gShootoutWaitingRoundStart = false;
		if (gShootoutActive)
		{
			// Short delay so every player has respawned before the kick is set up.
			KillTimerSafe(gShootoutTimer);
			gShootoutTimer = CreateTimer(PENALTY_ROUND_START_DELAY, TimerNextShootoutPenalty, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	UpdateGameTeamScores();
	if (gKickoffQueued && gMatchLive)
	{
		int kickoffTeam = gQueuedKickoffTeam;
		char kickoffReason[64];
		strcopy(kickoffReason, sizeof(kickoffReason), gQueuedKickoffReasonPhrase);
		gKickoffQueued = false;
		gQueuedKickoffTeam = 0;
		gQueuedKickoffReasonPhrase[0] = '\0';
		StartKickoff(kickoffTeam, kickoffReason);
		return Plugin_Continue;
	}

	if (ShouldFreezePlayers())
	{
		FreezeAllPlayers();
	}
	return Plugin_Continue;
}

public Action EventRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (!IsSoccerAvailable())
	{
		return Plugin_Continue;
	}

	gRoundEnded = true;

	// Any round end between shootout kicks restarts the round, so the pending kick
	// waits for round_start, the same as after a scored penalty.
	if (gShootoutActive && !gPenaltyActive && gShootoutTimer != null)
	{
		KillTimerSafe(gShootoutTimer);
		gShootoutWaitingRoundStart = true;
	}

	int reason = event.GetInt("reason");
	if (!IsGoalRoundEndReason(reason))
	{
		if (reason != view_as<int>(CSRoundEnd_GameStart))
		{
			QueueKickoffAfterRoundTimeout();
		}
		return Plugin_Continue;
	}

	int winner = event.GetInt("winner");
	if (winner != TEAM_T && winner != TEAM_CT)
	{
		return Plugin_Continue;
	}

	// A live penalty resolves from the same round end a normal goal uses. A match
	// penalty goes through the usual checks below like any other goal.
	if (gPenaltyActive && !IsMatchPenalty())
	{
		HandleGoal(winner, true);
		return Plugin_Continue;
	}

	// Between shootout kicks the ball is not in play, so a stray goal does not count.
	if (gShootoutActive || gPaused || gInBreak || gRestartingPeriod)
	{
		return Plugin_Continue;
	}

	HandleGoal(winner, true);
	return Plugin_Continue;
}

// The round timer ran out during a match. The new round puts the ball back on
// the centre spot, so play resumes with a kickoff, announced like any other, for
// the team that did not touch the ball last, and the clock waits for it.
void QueueKickoffAfterRoundTimeout()
{
	if (!gMatchLive || gRestartingPeriod || gInBreak || gShootoutActive || gKickoffQueued)
	{
		return;
	}

	// The new round moves the ball off the spot, so a match penalty not yet
	// kicked is dropped in favour of the kickoff.
	if (IsMatchPenalty())
	{
		EndMatchPenalty(false);
	}

	StopPeriodClock();
	StopStoppageClock();

	// A kickoff nobody took yet is simply announced again.
	int team;
	char reason[64];
	if (gKickoffActive)
	{
		team = gKickoffTeam;
		strcopy(reason, sizeof(reason), gKickoffReasonPhrase);
	}
	else
	{
		int lastTeam = IsValidClient(gLastToucher) ? GetClientTeam(gLastToucher) : 0;
		team = lastTeam == TEAM_CT || lastTeam == TEAM_T ? GetOppositeTeam(lastTeam) : GetScheduledKickoffTeam();
	}
	if (reason[0] == '\0')
	{
		strcopy(reason, sizeof(reason), "KickoffReason_RoundTime");
	}
	QueueKickoff(team, reason);
}

// Rounds ended by the clock, a draw or mp_restartgame are not goals.
bool IsGoalRoundEndReason(int reason)
{
	return reason != view_as<int>(CSRoundEnd_Draw)
		&& reason != view_as<int>(CSRoundEnd_TargetSaved)
		&& reason != view_as<int>(CSRoundEnd_HostagesNotRescued)
		&& reason != view_as<int>(CSRoundEnd_TerroristsNotEscaped)
		&& reason != view_as<int>(CSRoundEnd_VIPNotEscaped)
		&& reason != view_as<int>(CSRoundEnd_GameStart);
}

public Action EventPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(client) && IsSoccerAvailable())
	{
		if (gRedCard[client] && GetClientTeam(client) >= TEAM_T)
		{
			// Covers ways onto a team that skip jointeam, such as an admin move.
			CreateTimer(0.1, TimerMoveRedCardSpectator, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}
		else if (EnforceMaxPlayersOnSpawn(client))
		{
			return Plugin_Continue;
		}
		KillClientRespawnTimer(client);
		gStamina[client] = 100.0;
		StopSprint(client);
		RequestFrame(FrameApplySpawnState, GetClientUserId(client));
	}
	return Plugin_Continue;
}

public Action EventPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (!IsSoccerAvailable())
	{
		return Plugin_Continue;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (IsValidClient(client) && IsValidClient(attacker) && IsPlayerAlive(client) && GetClientTeam(client) >= TEAM_T)
	{
		SetEntProp(client, Prop_Send, "m_iHealth", 100);
		SetEntPropFloat(client, Prop_Send, "m_flVelocityModifier", 1.0);
		UpdateArmor(client);
	}
	return Plugin_Continue;
}

public void FrameUpdateArmor(any userid)
{
	int client = GetClientOfUserId(userid);
	if (IsValidClient(client) && IsPlayerAlive(client))
	{
		ForceUpdateArmor(client);
	}
}

public void FrameApplySpawnState(any userid)
{
	int client = GetClientOfUserId(userid);
	if (IsValidClient(client) && IsPlayerAlive(client) && IsSoccerAvailable())
	{
		ApplySoccerModel(client);
		ApplyPlayerDamageRules(client);
		ApplyPlayerFreezeState(client);
		ForceUpdateArmor(client);
		UpdateClientScoreboard(client);
	}
}

public Action EventPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(client) && IsSoccerAvailable())
	{
		int userid = GetClientUserId(client);
		RequestFrame(FrameUpdateClientScoreboard, userid);
		if (gCvarAutoRespawn.BoolValue)
		{
			KillClientRespawnTimer(client);
			gRespawnTimer[client] = CreateTimer(gCvarRespawnDelay.FloatValue, TimerRespawnPlayer, userid, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	return Plugin_Continue;
}

// The game only spawns a late joiner at the next round start, which in soccer is
// the next goal, so a player who joins T or CT mid-round is respawned like a death.
public Action EventPlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if (!IsSoccerAvailable() || !gCvarAutoRespawn.BoolValue || event.GetBool("disconnect"))
	{
		return Plugin_Continue;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));
	int team = event.GetInt("team");
	if (!IsValidClient(client) || team < TEAM_T || gRedCard[client])
	{
		return Plugin_Continue;
	}

	KillClientRespawnTimer(client);
	gRespawnTimer[client] = CreateTimer(gCvarRespawnDelay.FloatValue, TimerRespawnPlayer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

public Action CommandJoinTeam(int client, const char[] command, int argc)
{
	if (!IsValidClient(client) || !IsSoccerAvailable() || argc < 1)
	{
		return Plugin_Continue;
	}

	char arg[16];
	GetCmdArg(1, arg, sizeof(arg));
	int team = ParseJoinTeamArg(arg);
	bool autoAssign = team == 0;
	if (!autoAssign && team != TEAM_T && team != TEAM_CT)
	{
		return Plugin_Continue;
	}

	// Red cards apply on and off a match until a referee removes them.
	if (gRedCard[client])
	{
		PrintToChat(client, "%t", "Team_Join_RedCard");
		return Plugin_Handled;
	}

	if (!gMatchLive)
	{
		return Plugin_Continue;
	}

	int maxPlayers = gCvarMaxPlayersPerTeam.IntValue;
	bool draftTeams = HasAssignedSoccerTeams();
	if (maxPlayers <= 0 && !draftTeams)
	{
		return Plugin_Continue;
	}

	// Auto-assign would let the game pick a side behind the checks below, so the
	// side is picked here, checked like an explicit join, and joined explicitly.
	if (autoAssign)
	{
		team = gDraftTeam[client] != 0 ? gDraftTeam[client] : GetAutoAssignTeam(client);
	}

	if (maxPlayers > 0 && GetClientTeam(client) != team && CountTeamPlayers(team, client) >= maxPlayers)
	{
		PrintToChat(client, "%t", "Team_Join_Full", maxPlayers);
		return Plugin_Handled;
	}

	if (draftTeams)
	{
		if (gDraftTeam[client] == team)
		{
			return autoAssign ? JoinAutoAssignedTeam(client, team) : Plugin_Continue;
		}

		if (gDraftTeam[client] != 0 && gDraftTeam[client] != team)
		{
			PrintToChat(client, "%t", "Team_Join_Assigned_Other");
			return Plugin_Handled;
		}

		int maxReplacements = gCvarLiveReplacementSlots.IntValue;
		if (maxReplacements <= 0 || CountLiveReplacements(team, client) >= maxReplacements)
		{
			PrintToChat(client, "%t", "Team_Join_No_Replacements");
			return Plugin_Handled;
		}
	}

	return autoAssign ? JoinAutoAssignedTeam(client, team) : Plugin_Continue;
}

// Players on a team, bots included since they take a slot too.
int CountTeamPlayers(int team, int ignoreClient)
{
	int count;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (client != ignoreClient && IsValidClient(client) && GetClientTeam(client) == team)
		{
			count++;
		}
	}
	return count;
}

// Catches players put on a full team without jointeam (admin moves, a draft
// larger than the limit, or teams already over it when the match starts). It
// runs at spawn, one player at a time, so only the extra players are moved.
bool EnforceMaxPlayersOnSpawn(int client)
{
	int maxPlayers = gCvarMaxPlayersPerTeam.IntValue;
	int team = GetClientTeam(client);
	if (!gMatchLive || maxPlayers <= 0 || team < TEAM_T || CountTeamPlayers(team, client) < maxPlayers)
	{
		return false;
	}

	ChangeClientTeam(client, 1);
	PrintToChatAll("%t", "Team_Moved_Full", client, maxPlayers);
	return true;
}

Action JoinAutoAssignedTeam(int client, int team)
{
	if (GetClientTeam(client) != team)
	{
		FakeClientCommandEx(client, "jointeam %d", team);
	}
	return Plugin_Handled;
}

public Action CommandSay(int client, const char[] command, int argc)
{
	if (!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	if (HasPendingChatInput(client)
		&& (GetGameTime() > gChatInputExpires[client] || !HasSoccerAdminAccess(client)))
	{
		ClearChatInputs(client);
		return Plugin_Continue;
	}

	if (gPracticeInput[client] != PRACTICE_INPUT_NONE)
	{
		return HandlePracticeChatInput(client);
	}

	if (gMatchInput[client] != MATCH_INPUT_NONE)
	{
		return HandleMatchChatInput(client);
	}

	if (gDraftSetupInput[client] == DRAFT_INPUT_NONE)
	{
		return Plugin_Continue;
	}

	char message[128];
	GetCmdArgString(message, sizeof(message));
	StripQuotes(message);
	TrimString(message);
	if (message[0] == '\0')
	{
		return Plugin_Handled;
	}

	if (StrEqual(message, "cancel", false) || StrEqual(message, "cancelar", false))
	{
		gDraftSetupInput[client] = DRAFT_INPUT_NONE;
		gDraftSetupCaptainCount[client] = 0;
		ClearDraftCaptainSelection(client);
		PrintToChat(client, "%t", "Draft_Custom_Cancelled");
		ShowCaptainMenu(client);
		return Plugin_Handled;
	}

	int value;
	int consumed = StringToIntEx(message, value);
	if (consumed != strlen(message))
	{
		PrintToChat(client, "%t", gDraftSetupInput[client] == DRAFT_INPUT_CAPTAINS ? "Draft_CaptainCount_Custom_Invalid" : "Draft_TeamSize_Custom_Invalid");
		return Plugin_Handled;
	}

	if (gDraftSetupInput[client] == DRAFT_INPUT_CAPTAINS)
	{
		if (value < 2 || value > DRAFT_MAX_CAPTAINS)
		{
			PrintToChat(client, "%t", "Draft_CaptainCount_Custom_Invalid");
			return Plugin_Handled;
		}

		gDraftSetupInput[client] = DRAFT_INPUT_NONE;
		gDraftSetupCaptainCount[client] = value;
		BeginDraftCaptainSelection(client);
		return Plugin_Handled;
	}

	if (value < 1 || value > 16)
	{
		PrintToChat(client, "%t", "Draft_TeamSize_Custom_Invalid");
		return Plugin_Handled;
	}

	gDraftSetupInput[client] = DRAFT_INPUT_NONE;
	StartDraftWithSelectedCaptains(client, value);
	return Plugin_Handled;
}

public Action HandlePracticeChatInput(int client)
{
	char message[128];
	GetCmdArgString(message, sizeof(message));
	StripQuotes(message);
	TrimString(message);
	if (message[0] == '\0')
	{
		return Plugin_Handled;
	}

	if (StrEqual(message, "cancel", false) || StrEqual(message, "cancelar", false))
	{
		gPracticeInput[client] = PRACTICE_INPUT_NONE;
		PrintToChat(client, "%t", "Training_Cannon_Custom_Cancelled");
		ShowPracticeMenu(client);
		return Plugin_Handled;
	}

	float min;
	float max;
	char promptPhrase[48];
	char invalidPhrase[48];
	char setPhrase[48];
	ConVar setting = GetCannonSettingInfo(gPracticeInput[client], min, max, promptPhrase, invalidPhrase, setPhrase, sizeof(promptPhrase));
	if (setting == null)
	{
		gPracticeInput[client] = PRACTICE_INPUT_NONE;
		return Plugin_Handled;
	}

	if (!CanUseTrainingCannon(client))
	{
		gPracticeInput[client] = PRACTICE_INPUT_NONE;
		ShowPracticeMenu(client);
		return Plugin_Handled;
	}

	float value;
	int consumed = StringToFloatEx(message, value);
	if (consumed != strlen(message) || value < min || value > max)
	{
		PrintToChat(client, "%t", invalidPhrase, min, max);
		return Plugin_Handled;
	}

	setting.SetFloat(value);
	gPracticeInput[client] = PRACTICE_INPUT_NONE;
	PrintToChatAll("%t", setPhrase, client, value);
	ShowPracticeMenu(client);
	return Plugin_Handled;
}

// The cannon settings typed in chat. Their range is the cvar's own bounds.
ConVar GetCannonSettingInfo(int input, float &min, float &max, char[] promptPhrase, char[] invalidPhrase, char[] setPhrase, int maxlen)
{
	ConVar setting;
	switch (input)
	{
		case PRACTICE_INPUT_CANNON_POWER:
		{
			setting = gCvarTrainingCannonPower;
			strcopy(promptPhrase, maxlen, "Training_Cannon_Power_Prompt");
			strcopy(invalidPhrase, maxlen, "Training_Cannon_Power_Invalid");
			strcopy(setPhrase, maxlen, "Training_Cannon_Power_Set");
		}
		case PRACTICE_INPUT_CANNON_RATE:
		{
			setting = gCvarTrainingCannonFireRate;
			strcopy(promptPhrase, maxlen, "Training_Cannon_Rate_Prompt");
			strcopy(invalidPhrase, maxlen, "Training_Cannon_Rate_Invalid");
			strcopy(setPhrase, maxlen, "Training_Cannon_Rate_Set");
		}
		case PRACTICE_INPUT_CANNON_RANDOMNESS:
		{
			setting = gCvarTrainingCannonRandomness;
			strcopy(promptPhrase, maxlen, "Training_Cannon_Random_Prompt");
			strcopy(invalidPhrase, maxlen, "Training_Cannon_Random_Invalid");
			strcopy(setPhrase, maxlen, "Training_Cannon_Random_Set");
		}
		default:
		{
			return null;
		}
	}

	setting.GetBounds(ConVarBound_Lower, min);
	setting.GetBounds(ConVarBound_Upper, max);
	return setting;
}

void PromptCannonSetting(int client, int input)
{
	float min;
	float max;
	char promptPhrase[48];
	char invalidPhrase[48];
	char setPhrase[48];
	ConVar setting = GetCannonSettingInfo(input, min, max, promptPhrase, invalidPhrase, setPhrase, sizeof(promptPhrase));
	BeginChatInput(client);
	gPracticeInput[client] = input;
	PrintToChat(client, "%t", promptPhrase, min, max, setting.FloatValue);
}

public Action HandleMatchChatInput(int client)
{
	char message[128];
	GetCmdArgString(message, sizeof(message));
	StripQuotes(message);
	TrimString(message);
	if (message[0] == '\0')
	{
		return Plugin_Handled;
	}

	if (StrEqual(message, "cancel", false) || StrEqual(message, "cancelar", false))
	{
		gMatchInput[client] = MATCH_INPUT_NONE;
		PrintToChat(client, "%t", "Menu_Start_Custom_Cancel");
		ShowStartDurationMenu(client);
		return Plugin_Handled;
	}

	if (gMatchInput[client] == MATCH_INPUT_DURATION)
	{
		int minutes;
		int consumed = StringToIntEx(message, minutes);
		if (consumed != strlen(message) || minutes < 1 || minutes > 60)
		{
			PrintToChat(client, "%t", "Menu_Start_Custom_Invalid");
			return Plugin_Handled;
		}

		gMatchInput[client] = MATCH_INPUT_NONE;
		StartMatchWithPeriodMinutes(client, minutes);
		return Plugin_Handled;
	}

	gMatchInput[client] = MATCH_INPUT_NONE;
	return Plugin_Handled;
}

public Action TimerRespawnPlayer(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (!IsValidClient(client))
	{
		return Plugin_Stop;
	}

	gRespawnTimer[client] = null;
	if (IsSoccerAvailable() && !gRoundEnded && !IsPlayerAlive(client) && GetClientTeam(client) >= TEAM_T)
	{
		CS_RespawnPlayer(client);
	}
	return Plugin_Stop;
}

public Action TimerHud(Handle timer)
{
	if (!gCvarShowHud.BoolValue || !IsSoccerAvailable() || !gMatchLive)
	{
		return Plugin_Continue;
	}

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client))
		{
			SetHudTextParams(0.42, 0.08, 1.1, 20, 180, 255, 180);
			char hudLine[128];
			FormatHudLine(client, hudLine, sizeof(hudLine));
			if (gCvarHudUseHint.BoolValue)
			{
				PrintHintText(client, "%s", hudLine);
			}
			else
			{
				ShowSyncHudText(client, gHudSync, "%s", hudLine);
			}
		}
	}
	return Plugin_Continue;
}

bool HasSoccerAdminAccess(int client)
{
	return CheckCommandAccess(client, "sm_socceradmin", ADMFLAG_GENERIC, false);
}

void ClearChatInputs(int client)
{
	gPracticeInput[client] = PRACTICE_INPUT_NONE;
	gMatchInput[client] = MATCH_INPUT_NONE;
	gDraftSetupInput[client] = DRAFT_INPUT_NONE;
	gChatInputExpires[client] = 0.0;
}

// Only one chat prompt can wait at a time, and it lapses so a number typed much
// later goes to chat instead of starting a match or a draft.
void BeginChatInput(int client)
{
	ClearChatInputs(client);
	gChatInputExpires[client] = GetGameTime() + CHAT_INPUT_TIMEOUT;
}

bool HasPendingChatInput(int client)
{
	return gPracticeInput[client] != PRACTICE_INPUT_NONE
		|| gMatchInput[client] != MATCH_INPUT_NONE
		|| gDraftSetupInput[client] != DRAFT_INPUT_NONE;
}

public Action CmdSoccerMenu(int client, int args)
{
	if (!IsValidClient(client) || !CheckSoccerAvailable(client))
	{
		return Plugin_Handled;
	}

	if (HasSoccerAdminAccess(client))
	{
		return CmdAdminMenu(client, args);
	}

	Menu menu = new Menu(MenuHandlerSoccer);
	char title[128];
	Format(title, sizeof(title), "%T", "Menu_Player_Clean_Title", client, gScoreCT, gScoreT);
	menu.SetTitle(title);
	AddMenuItemPhrase(menu, client, "position", "Menu_Position");
	AddMenuItemPhrase(menu, client, "rank", "Menu_Rank");
	AddMenuItemPhrase(menu, client, "top", "Menu_Top");
	menu.Display(client, 20);
	return Plugin_Handled;
}

public int MenuHandlerSoccer(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action != MenuAction_Select || !IsValidClient(client))
	{
		return 0;
	}

	if (!CheckSoccerAvailable(client))
	{
		return 0;
	}

	char info[32];
	menu.GetItem(item, info, sizeof(info));
	if (StrEqual(info, "position"))
	{
		ShowPosition(client);
	}
	else if (StrEqual(info, "rank"))
	{
		ShowClientRank(client);
	}
	else if (StrEqual(info, "top"))
	{
		ShowTopScopeMenu(client);
	}
	return 0;
}

public Action CmdAdminMenu(int client, int args)
{
	if (!IsValidClient(client) || !CheckSoccerAvailable(client))
	{
		return Plugin_Handled;
	}
	if (!HasSoccerAdminAccess(client))
	{
		return Plugin_Handled;
	}

	ShowAdminMenu(client);
	return Plugin_Handled;
}

void ShowAdminMenu(int client)
{
	Menu menu = new Menu(MenuHandlerAdmin);
	char title[128];
	Format(title, sizeof(title), "%T", "Menu_Admin_Clean_Title", client);
	menu.SetTitle(title);
	AddMenuItemPhrase(menu, client, "match", "Menu_Match");
	AddMenuItemPhrase(menu, client, "captains", "Menu_Captains");
	AddMenuItemPhrase(menu, client, "referee", "Menu_Referee");
	AddMenuItemPhrase(menu, client, "practice", "Menu_Practice");
	AddMenuItemPhrase(menu, client, "gkareas", "Menu_GkAreas");
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandlerAdmin(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action != MenuAction_Select || !IsValidClient(client))
	{
		return 0;
	}

	if (!CheckSoccerAvailable(client) || !HasSoccerAdminAccess(client))
	{
		return 0;
	}

	char info[32];
	menu.GetItem(item, info, sizeof(info));
	if (StrEqual(info, "match"))
	{
		ShowMatchMenu(client);
	}
	else if (StrEqual(info, "captains"))
	{
		ShowCaptainMenu(client);
	}
	else if (StrEqual(info, "referee"))
	{
		ShowRefereeMenu(client);
	}
	else if (StrEqual(info, "practice"))
	{
		ShowPracticeMenu(client);
	}
	else if (StrEqual(info, "gkareas"))
	{
		PrintToChat(client, "%t", "GkArea_Help");
		PrintToChat(client, "%t", "GkArea_Help_Saved");
		PrintToChat(client, "%t", "GkArea_Help_Size");
		ShowGkAreaMenu(client);
	}
	return 0;
}

void ShowSpecAllConfirmMenu(int client)
{
	Menu menu = new Menu(MenuHandlerSpecAllConfirm);
	char title[128];
	Format(title, sizeof(title), "%T", "Menu_SpecAll_Confirm_Title", client);
	menu.SetTitle(title);
	AddMenuItemPhrase(menu, client, "yes", "Menu_SpecAll_Confirm_Yes");
	AddMenuItemPhrase(menu, client, "no", "Menu_SpecAll_Confirm_No");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandlerSpecAllConfirm(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action == MenuAction_Cancel && item == MenuCancel_ExitBack && IsValidClient(client))
	{
		ShowCaptainMenu(client);
		return 0;
	}

	if (action != MenuAction_Select || !IsValidClient(client))
	{
		return 0;
	}

	if (!CheckSoccerAvailable(client) || !HasSoccerAdminAccess(client))
	{
		return 0;
	}

	char info[8];
	menu.GetItem(item, info, sizeof(info));
	if (StrEqual(info, "yes"))
	{
		MoveAllToSpectator(client);
	}
	ShowCaptainMenu(client);
	return 0;
}

public Action CmdSpecAll(int client, int args)
{
	if (!CheckSoccerAvailable(client))
	{
		return Plugin_Handled;
	}

	MoveAllToSpectator(client);
	return Plugin_Handled;
}

// Moves every human player on T or CT to spectator, to set teams up again from
// scratch. A match or a draft depends on the teams as they are, so it has to be
// stopped first. Bots are left alone: the bot quota would only add them back.
void MoveAllToSpectator(int admin)
{
	if (gMatchLive || gDraftActive)
	{
		ReplySpecAll(admin, "SpecAll_Not_Now");
		return;
	}

	int moved;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) >= TEAM_T)
		{
			ChangeClientTeam(client, 1);
			moved++;
		}
	}

	if (moved == 0)
	{
		ReplySpecAll(admin, "SpecAll_Nobody");
		return;
	}

	char adminName[MAX_NAME_LENGTH];
	GetAdminDisplayName(admin, adminName, sizeof(adminName));
	PrintToChatAll("%t", "SpecAll_Done", adminName);
}

// Lists the human players on a team; picking one moves them to spectator and
// shows the list again, so several can be moved in a row.
void ShowSpecPlayerMenu(int client)
{
	Menu menu = new Menu(MenuHandlerSpecPlayer);
	char title[128];
	Format(title, sizeof(title), "%T", "Menu_SpecPlayer_Title", client);
	menu.SetTitle(title);

	int count;
	for (int target = 1; target <= MaxClients; target++)
	{
		if (!IsClientInGame(target) || IsFakeClient(target) || GetClientTeam(target) < TEAM_T)
		{
			continue;
		}

		char info[16];
		IntToString(GetClientUserId(target), info, sizeof(info));
		char display[MAX_NAME_LENGTH + 8];
		Format(display, sizeof(display), "%N (%s)", target, GetClientTeam(target) == TEAM_CT ? "CT" : "TT");
		menu.AddItem(info, display);
		count++;
	}

	if (count == 0)
	{
		delete menu;
		PrintToChat(client, "%t", "SpecAll_Nobody");
		ShowCaptainMenu(client);
		return;
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandlerSpecPlayer(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action == MenuAction_Cancel && item == MenuCancel_ExitBack && IsValidClient(client))
	{
		ShowCaptainMenu(client);
		return 0;
	}

	if (action != MenuAction_Select || !IsValidClient(client))
	{
		return 0;
	}

	if (!CheckSoccerAvailable(client) || !HasSoccerAdminAccess(client))
	{
		return 0;
	}

	char info[16];
	menu.GetItem(item, info, sizeof(info));
	MoveClientToSpectator(client, GetClientOfUserId(StringToInt(info)));
	ShowSpecPlayerMenu(client);
	return 0;
}

public Action CmdSpecPlayer(int client, int args)
{
	if (!CheckSoccerAvailable(client))
	{
		return Plugin_Handled;
	}

	if (args < 1)
	{
		ReplyToCommand(client, "%t", "SpecPlayer_Usage");
		return Plugin_Handled;
	}

	char arg[MAX_NAME_LENGTH];
	GetCmdArg(1, arg, sizeof(arg));
	int target = FindTarget(client, arg, false, true);
	if (target != -1)
	{
		MoveClientToSpectator(client, target);
	}
	return Plugin_Handled;
}

// Moves one player to spectator, for example an AFK one. Unlike moving
// everyone, this is allowed during a match or a draft.
void MoveClientToSpectator(int admin, int target)
{
	if (target <= 0 || !IsClientInGame(target) || GetClientTeam(target) < TEAM_T)
	{
		ReplySpecAll(admin, "SpecPlayer_Not_On_Team");
		return;
	}

	char adminName[MAX_NAME_LENGTH];
	GetAdminDisplayName(admin, adminName, sizeof(adminName));
	PrintToChatAll("%t", "SpecPlayer_Done", adminName, target);
	ChangeClientTeam(target, 1);
}

void GetAdminDisplayName(int admin, char[] buffer, int maxlen)
{
	if (admin > 0 && IsClientInGame(admin))
	{
		GetClientName(admin, buffer, maxlen);
	}
	else
	{
		strcopy(buffer, maxlen, "Console");
	}
}

// The admin may come from a menu, a chat command or the server console.
void ReplySpecAll(int admin, const char[] phrase)
{
	if (admin > 0 && IsClientInGame(admin))
	{
		PrintToChat(admin, "%t", phrase);
	}
	else
	{
		PrintToServer("%T", phrase, LANG_SERVER);
	}
}

void ShowRefereeMenu(int client)
{
	Menu menu = new Menu(MenuHandlerReferee);
	char title[128];
	Format(title, sizeof(title), "%T", "Menu_Referee_Title", client);
	menu.SetTitle(title);
	AddMenuItemPhrase(menu, client, "yellow", "Menu_Card_Yellow_Give");
	AddMenuItemPhrase(menu, client, "red", "Menu_Card_Red_Give");
	AddMenuItemPhrase(menu, client, "score", "Menu_Referee_Score");
	AddMenuItemPhrase(menu, client, "clearplayer", "Menu_Cards_Clear_Player");
	AddMenuItemPhrase(menu, client, "removered", "Menu_Card_Red_Remove");
	AddMenuItemPhrase(menu, client, "clearall", "Menu_Cards_Clear_All");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandlerReferee(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action == MenuAction_Cancel && item == MenuCancel_ExitBack && IsValidClient(client))
	{
		ShowAdminMenu(client);
		return 0;
	}

	if (action != MenuAction_Select || !IsValidClient(client))
	{
		return 0;
	}

	if (!CheckSoccerAvailable(client) || !HasSoccerAdminAccess(client))
	{
		return 0;
	}

	char info[32];
	menu.GetItem(item, info, sizeof(info));
	if (StrEqual(info, "yellow"))
	{
		ShowRefereeTargetMenu(client, REF_ACTION_YELLOW);
	}
	else if (StrEqual(info, "red"))
	{
		ShowRefereeTargetMenu(client, REF_ACTION_RED);
	}
	else if (StrEqual(info, "score"))
	{
		ShowRefereeScoreMenu(client);
	}
	else if (StrEqual(info, "clearplayer"))
	{
		ShowRefereeTargetMenu(client, REF_ACTION_CLEAR_PLAYER);
	}
	else if (StrEqual(info, "removered"))
	{
		ShowRedCardListMenu(client);
	}
	else if (StrEqual(info, "clearall"))
	{
		ClearAllCards();
		ShowRefereeMenu(client);
	}
	return 0;
}

// Lists every stored red card, including players who are not connected.
void ShowRedCardListMenu(int client)
{
	StringMapSnapshot snapshot = gRedCards.Snapshot();
	if (snapshot.Length == 0)
	{
		delete snapshot;
		PrintToChat(client, "%t", "Card_Red_None");
		ShowRefereeMenu(client);
		return;
	}

	Menu menu = new Menu(MenuHandlerRedCardList);
	char title[128];
	Format(title, sizeof(title), "%T", "Menu_RedCards_Title", client);
	menu.SetTitle(title);

	char auth[MAX_AUTH_ID_LENGTH];
	char name[MAX_NAME_LENGTH];
	char display[MAX_NAME_LENGTH + MAX_AUTH_ID_LENGTH + 4];
	for (int i = 0; i < snapshot.Length; i++)
	{
		snapshot.GetKey(i, auth, sizeof(auth));
		gRedCards.GetString(auth, name, sizeof(name));
		Format(display, sizeof(display), "%s (%s)", name, auth);
		menu.AddItem(auth, display);
	}
	delete snapshot;

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandlerRedCardList(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action == MenuAction_Cancel && item == MenuCancel_ExitBack && IsValidClient(client))
	{
		ShowRefereeMenu(client);
		return 0;
	}

	if (action != MenuAction_Select || !IsValidClient(client))
	{
		return 0;
	}

	if (!CheckSoccerAvailable(client) || !HasSoccerAdminAccess(client))
	{
		return 0;
	}

	char auth[MAX_AUTH_ID_LENGTH];
	char name[MAX_NAME_LENGTH];
	menu.GetItem(item, auth, sizeof(auth));
	gRedCards.GetString(auth, name, sizeof(name));
	if (RemoveRedCardByAuth(auth))
	{
		PrintToChatAll("%t", "Card_Red_Removed", client, name);
	}
	ShowRedCardListMenu(client);
	return 0;
}

void ShowRefereeScoreMenu(int client)
{
	Menu menu = new Menu(MenuHandlerRefereeScore);
	char title[128];
	Format(title, sizeof(title), "%T", "Menu_Referee_Score_Title", client, gScoreCT, gScoreT);
	menu.SetTitle(title);
	AddMenuItemPhrase(menu, client, "addct", "Menu_Score_Add_CT");
	AddMenuItemPhrase(menu, client, "removect", "Menu_Score_Remove_CT");
	AddMenuItemPhrase(menu, client, "addt", "Menu_Score_Add_TT");
	AddMenuItemPhrase(menu, client, "removet", "Menu_Score_Remove_TT");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandlerRefereeScore(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action == MenuAction_Cancel && item == MenuCancel_ExitBack && IsValidClient(client))
	{
		ShowRefereeMenu(client);
		return 0;
	}

	if (action != MenuAction_Select || !IsValidClient(client))
	{
		return 0;
	}

	if (!CheckSoccerAvailable(client) || !HasSoccerAdminAccess(client))
	{
		return 0;
	}

	char info[32];
	menu.GetItem(item, info, sizeof(info));
	if (StrEqual(info, "addct"))
	{
		AdjustTeamScore(client, TEAM_CT, 1);
	}
	else if (StrEqual(info, "removect"))
	{
		AdjustTeamScore(client, TEAM_CT, -1);
	}
	else if (StrEqual(info, "addt"))
	{
		AdjustTeamScore(client, TEAM_T, 1);
	}
	else if (StrEqual(info, "removet"))
	{
		AdjustTeamScore(client, TEAM_T, -1);
	}

	ShowRefereeScoreMenu(client);
	return 0;
}

void ShowRefereeTargetMenu(int client, int refereeAction)
{
	gRefereeAction[client] = refereeAction;
	Menu menu = new Menu(MenuHandlerRefereeTarget);
	char title[128];
	Format(title, sizeof(title), "%T", "Menu_Referee_Target_Title", client);
	menu.SetTitle(title);

	char userid[16];
	char display[MAX_NAME_LENGTH + 64];
	char redState[16];
	int count;
	for (int target = 1; target <= MaxClients; target++)
	{
		if (!IsValidClient(target) || IsFakeClient(target))
		{
			continue;
		}

		Format(redState, sizeof(redState), "%T", gRedCard[target] ? "State_Yes" : "State_No", client);
		Format(display, sizeof(display), "%T", "Menu_Referee_Target_Display", client, target, gYellowCards[target], redState);
		IntToString(GetClientUserId(target), userid, sizeof(userid));
		menu.AddItem(userid, display);
		count++;
	}

	if (count == 0)
	{
		AddMenuItemPhrase(menu, client, "none", "Client_None");
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandlerRefereeTarget(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action == MenuAction_Cancel && item == MenuCancel_ExitBack && IsValidClient(client))
	{
		gRefereeAction[client] = REF_ACTION_NONE;
		ShowRefereeMenu(client);
		return 0;
	}

	if (action != MenuAction_Select || !IsValidClient(client))
	{
		return 0;
	}

	if (!CheckSoccerAvailable(client) || !HasSoccerAdminAccess(client))
	{
		return 0;
	}

	char info[16];
	menu.GetItem(item, info, sizeof(info));
	if (StrEqual(info, "none"))
	{
		ShowRefereeMenu(client);
		return 0;
	}

	int target = GetClientOfUserId(StringToInt(info));
	if (!IsValidClient(target))
	{
		PrintToChat(client, "%t", "Client_None");
		ShowRefereeMenu(client);
		return 0;
	}

	ApplyRefereeAction(target, gRefereeAction[client]);
	gRefereeAction[client] = REF_ACTION_NONE;
	ShowRefereeMenu(client);
	return 0;
}

void ShowPracticeMenu(int client)
{
	Menu menu = new Menu(MenuHandlerPractice);
	char title[128];
	Format(title, sizeof(title), "%T", "Menu_Practice_Title", client);
	menu.SetTitle(title);
	AddMenuItemPhrase(menu, client, "trainingball", "Menu_TrainingBall");
	AddMenuItemPhrase(menu, client, "removetrainingball", "Menu_TrainingBall_Remove");
	AddMenuItemPhrase(menu, client, "cannonpos", "Menu_TrainingCannon_Position");
	AddMenuItemPhrase(menu, client, "cannonaim", "Menu_TrainingCannon_Target");
	AddMenuItemPhrase(menu, client, "cannonpower", "Menu_TrainingCannon_Power");
	AddMenuItemPhrase(menu, client, "cannonrate", "Menu_TrainingCannon_Rate");
	AddMenuItemPhrase(menu, client, "cannonrandom", "Menu_TrainingCannon_Randomness");
	AddMenuItemPhrase(menu, client, "cannonstart", "Menu_TrainingCannon_Start");
	AddMenuItemPhrase(menu, client, "cannonstop", "Menu_TrainingCannon_Stop");
	AddMenuItemPhrase(menu, client, "goals", gTrainingGoalsDisabled ? "Menu_Training_Goals_Enable" : "Menu_Training_Goals_Disable");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandlerPractice(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action == MenuAction_Cancel && item == MenuCancel_ExitBack && IsValidClient(client))
	{
		ShowAdminMenu(client);
		return 0;
	}

	if (action != MenuAction_Select || !IsValidClient(client))
	{
		return 0;
	}

	if (!CheckSoccerAvailable(client) || !HasSoccerAdminAccess(client))
	{
		return 0;
	}

	char info[32];
	menu.GetItem(item, info, sizeof(info));
	if (StrEqual(info, "trainingball"))
	{
		SpawnTrainingBall(client);
	}
	else if (StrEqual(info, "removetrainingball"))
	{
		RemoveTrainingBall(client);
	}
	else if (StrEqual(info, "cannonpos"))
	{
		if (CanUseTrainingCannon(client))
		{
			SetTrainingCannonPosition(client);
		}
	}
	else if (StrEqual(info, "cannonaim"))
	{
		if (CanUseTrainingCannon(client))
		{
			SetTrainingCannonTarget(client);
		}
	}
	else if (StrEqual(info, "cannonpower") || StrEqual(info, "cannonrate") || StrEqual(info, "cannonrandom"))
	{
		if (!CanUseTrainingCannon(client))
		{
			ShowPracticeMenu(client);
			return 0;
		}
		int input = PRACTICE_INPUT_CANNON_POWER;
		if (StrEqual(info, "cannonrate"))
		{
			input = PRACTICE_INPUT_CANNON_RATE;
		}
		else if (StrEqual(info, "cannonrandom"))
		{
			input = PRACTICE_INPUT_CANNON_RANDOMNESS;
		}
		PromptCannonSetting(client, input);
		return 0;
	}
	else if (StrEqual(info, "goals"))
	{
		SetTrainingGoalsDisabled(client, !gTrainingGoalsDisabled);
	}
	else if (StrEqual(info, "cannonstart"))
	{
		StartTrainingCannon(client);
	}
	else if (StrEqual(info, "cannonstop"))
	{
		StopTrainingCannon();
		PrintToChat(client, "%t", "Training_Cannon_Stopped");
	}

	ShowPracticeMenu(client);
	return 0;
}

void ShowCaptainMenu(int client)
{
	Menu menu = new Menu(MenuHandlerCaptain);
	char title[128];
	Format(title, sizeof(title), "%T", "Menu_Captains_Title", client);
	menu.SetTitle(title);
	AddMenuItemPhrase(menu, client, "specall", "Menu_SpecAll");
	AddMenuItemPhrase(menu, client, "specplayer", "Menu_SpecPlayer");
	AddMenuItemPhrase(menu, client, "snake", "Menu_Draft_Snake");
	AddMenuItemPhrase(menu, client, "open", "Menu_Draft_Open");
	AddMenuItemPhrase(menu, client, "show", "Menu_Draft_Show");
	AddMenuItemPhrase(menu, client, "cancel", "Menu_Draft_Cancel");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandlerCaptain(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action == MenuAction_Cancel && item == MenuCancel_ExitBack && IsValidClient(client))
	{
		ShowAdminMenu(client);
		return 0;
	}

	if (action != MenuAction_Select || !IsValidClient(client))
	{
		return 0;
	}

	if (!CheckSoccerAvailable(client) || !HasSoccerAdminAccess(client))
	{
		return 0;
	}

	char info[32];
	menu.GetItem(item, info, sizeof(info));
	if (StrEqual(info, "specall"))
	{
		ShowSpecAllConfirmMenu(client);
	}
	else if (StrEqual(info, "specplayer"))
	{
		ShowSpecPlayerMenu(client);
	}
	else if (StrEqual(info, "snake"))
	{
		ShowDraftCaptainCountMenu(client);
	}
	else if (StrEqual(info, "open"))
	{
		ShowDraftPickMenu(client);
	}
	else if (StrEqual(info, "show"))
	{
		ShowDraftStatus(client);
		PrintDraftGroupsToClient(client);
		ShowCaptainMenu(client);
	}
	else if (StrEqual(info, "cancel"))
	{
		CancelDraft(true);
		ShowCaptainMenu(client);
	}
	return 0;
}

void ShowDraftCaptainCountMenu(int client)
{
	Menu menu = new Menu(MenuHandlerDraftCaptainCount);
	char title[128];
	Format(title, sizeof(title), "%T", "Menu_Draft_CaptainCount_Title", client);
	menu.SetTitle(title);
	AddMenuItemPhrase(menu, client, "2", "Menu_Draft_CaptainCount_2");
	AddMenuItemPhrase(menu, client, "3", "Menu_Draft_CaptainCount_3");
	AddMenuItemPhrase(menu, client, "4", "Menu_Draft_CaptainCount_4");
	AddMenuItemPhrase(menu, client, "custom", "Menu_Draft_CaptainCount_Custom");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandlerDraftCaptainCount(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action == MenuAction_Cancel && item == MenuCancel_ExitBack && IsValidClient(client))
	{
		ShowCaptainMenu(client);
		return 0;
	}

	if (action != MenuAction_Select || !IsValidClient(client))
	{
		return 0;
	}

	if (!CheckSoccerAvailable(client) || !HasSoccerAdminAccess(client))
	{
		return 0;
	}

	char info[32];
	menu.GetItem(item, info, sizeof(info));
	if (StrEqual(info, "custom"))
	{
		BeginChatInput(client);
		gDraftSetupInput[client] = DRAFT_INPUT_CAPTAINS;
		PrintToChat(client, "%t", "Draft_CaptainCount_Custom_Prompt");
		return 0;
	}

	gDraftSetupCaptainCount[client] = StringToInt(info);
	BeginDraftCaptainSelection(client);
	return 0;
}

void BeginDraftCaptainSelection(int client)
{
	ClearDraftCaptainSelection(client);
	ShowDraftCaptainSelectMenu(client);
}

void ShowDraftCaptainSelectMenu(int client)
{
	int captainCount = gDraftSetupCaptainCount[client];
	if (captainCount < 2 || captainCount > DRAFT_MAX_CAPTAINS)
	{
		PrintToChat(client, "%t", "Draft_CaptainCount_Custom_Invalid");
		ShowDraftCaptainCountMenu(client);
		return;
	}

	Menu menu = new Menu(MenuHandlerDraftCaptainSelect);
	char title[128];
	Format(title, sizeof(title), "%T", "Menu_SelectCaptains", client, captainCount);
	menu.SetTitle(title);

	char userid[16];
	char display[MAX_NAME_LENGTH + 16];
	int available;
	for (int target = 1; target <= MaxClients; target++)
	{
		if (IsDraftCaptainSelectable(client, target))
		{
			IntToString(GetClientUserId(target), userid, sizeof(userid));
			Format(display, sizeof(display), "%N", target);
			menu.AddItem(userid, display);
			available++;
		}
	}

	if (available + gDraftSelectedCaptainCount[client] < captainCount)
	{
		delete menu;
		PrintToChat(client, "%t", "Draft_Not_Enough_Captains");
		ClearDraftCaptainSelection(client);
		ShowCaptainMenu(client);
		return;
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandlerDraftCaptainSelect(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action == MenuAction_Cancel && item == MenuCancel_ExitBack && IsValidClient(client))
	{
		ClearDraftCaptainSelection(client);
		ShowDraftCaptainCountMenu(client);
		return 0;
	}

	if (action != MenuAction_Select || !IsValidClient(client))
	{
		return 0;
	}

	if (!CheckSoccerAvailable(client) || !HasSoccerAdminAccess(client))
	{
		return 0;
	}

	char info[16];
	menu.GetItem(item, info, sizeof(info));
	int target = GetClientOfUserId(StringToInt(info));
	if (!IsDraftCaptainSelectable(client, target))
	{
		PrintToChat(client, "%t", "Draft_Invalid_Captains");
		ShowDraftCaptainSelectMenu(client);
		return 0;
	}

	int selected = gDraftSelectedCaptainCount[client];
	gDraftSelectedCaptains[client][selected] = target;
	gDraftSelectedCaptainCount[client] = selected + 1;
	PrintToChat(client, "%t", "Draft_Captain_Added", target, gDraftSelectedCaptainCount[client], gDraftSetupCaptainCount[client]);

	if (gDraftSelectedCaptainCount[client] >= gDraftSetupCaptainCount[client])
	{
		ShowDraftTeamSizeMenu(client);
		return 0;
	}

	ShowDraftCaptainSelectMenu(client);
	return 0;
}

void ShowDraftTeamSizeMenu(int client)
{
	Menu menu = new Menu(MenuHandlerDraftTeamSize);
	char title[128];
	Format(title, sizeof(title), "%T", "Menu_Draft_TeamSize_Title", client, gDraftSetupCaptainCount[client]);
	menu.SetTitle(title);
	AddMenuItemPhrase(menu, client, "3", "Menu_Draft_TeamSize_3");
	AddMenuItemPhrase(menu, client, "4", "Menu_Draft_TeamSize_4");
	AddMenuItemPhrase(menu, client, "5", "Menu_Draft_TeamSize_5");
	AddMenuItemPhrase(menu, client, "6", "Menu_Draft_TeamSize_6");
	AddMenuItemPhrase(menu, client, "custom", "Menu_Draft_TeamSize_Custom");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandlerDraftTeamSize(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action == MenuAction_Cancel && item == MenuCancel_ExitBack && IsValidClient(client))
	{
		ShowDraftCaptainCountMenu(client);
		return 0;
	}

	if (action != MenuAction_Select || !IsValidClient(client))
	{
		return 0;
	}

	if (!CheckSoccerAvailable(client) || !HasSoccerAdminAccess(client))
	{
		return 0;
	}

	char info[32];
	menu.GetItem(item, info, sizeof(info));
	if (StrEqual(info, "custom"))
	{
		BeginChatInput(client);
		gDraftSetupInput[client] = DRAFT_INPUT_TEAMSIZE;
		PrintToChat(client, "%t", "Draft_TeamSize_Custom_Prompt");
		return 0;
	}

	int teamSize = StringToInt(info);
	StartDraftWithSelectedCaptains(client, teamSize);
	return 0;
}

void ShowMatchMenu(int client)
{
	Menu menu = new Menu(MenuHandlerMatch);
	char title[128];
	Format(title, sizeof(title), "%T", "Menu_Match_Title", client, gCurrentPeriod, gScoreCT, gScoreT);
	menu.SetTitle(title);
	AddMenuItemPhrase(menu, client, "start", "Menu_StartMatch");
	AddMenuItemPhrase(menu, client, "stop", "Menu_StopMatch");
	AddMenuItemPhrase(menu, client, "pause", "Menu_PauseMatch");
	AddMenuItemPhrase(menu, client, "unpause", "Menu_ResumeMatch");
	AddMenuItemPhrase(menu, client, "penalties", "Menu_Penalties");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void ShowStartDurationMenu(int client)
{
	Menu menu = new Menu(MenuHandlerStartDuration);
	char title[128];
	Format(title, sizeof(title), "%T", "Menu_Start_Title", client);
	menu.SetTitle(title);
	AddMenuItemPhrase(menu, client, "3", "Menu_Start_3");
	AddMenuItemPhrase(menu, client, "5", "Menu_Start_5");
	AddMenuItemPhrase(menu, client, "custom", "Menu_Start_Custom");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandlerStartDuration(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action == MenuAction_Cancel && item == MenuCancel_ExitBack && IsValidClient(client))
	{
		ShowMatchMenu(client);
		return 0;
	}

	if (action != MenuAction_Select || !IsValidClient(client))
	{
		return 0;
	}

	if (!CheckSoccerAvailable(client) || !HasSoccerAdminAccess(client))
	{
		return 0;
	}

	char info[32];
	menu.GetItem(item, info, sizeof(info));
	if (StrEqual(info, "custom"))
	{
		BeginChatInput(client);
		gMatchInput[client] = MATCH_INPUT_DURATION;
		PrintToChat(client, "%t", "Menu_Start_Custom_Prompt");
		return 0;
	}

	int minutes = StringToInt(info);
	StartMatchWithPeriodMinutes(client, minutes);
	return 0;
}

public int MenuHandlerMatch(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action == MenuAction_Cancel && item == MenuCancel_ExitBack && IsValidClient(client))
	{
		ShowAdminMenu(client);
		return 0;
	}

	if (action != MenuAction_Select || !IsValidClient(client))
	{
		return 0;
	}

	if (!CheckSoccerAvailable(client) || !HasSoccerAdminAccess(client))
	{
		return 0;
	}

	char info[32];
	menu.GetItem(item, info, sizeof(info));
	if (StrEqual(info, "start"))
	{
		ShowStartDurationMenu(client);
	}
	else if (StrEqual(info, "stop"))
	{
		StopMatch();
	}
	else if (StrEqual(info, "pause"))
	{
		PauseMatch();
	}
	else if (StrEqual(info, "unpause"))
	{
		UnpauseMatch();
	}
	else if (StrEqual(info, "penalties"))
	{
		ShowPenaltyMenu(client);
	}
	return 0;
}

void ShowPenaltyMenu(int client)
{
	Menu menu = new Menu(MenuHandlerPenalty);
	char title[128];
	Format(title, sizeof(title), "%T", "Menu_Penalties_Title", client);
	menu.SetTitle(title);
	AddMenuItemPhrase(menu, client, "penaltyspot", "Menu_Penalty_Spot");
	AddMenuItemPhrase(menu, client, "shootout", "Menu_Penalties_Start");
	AddMenuItemPhrase(menu, client, "penaltyct", "Menu_Penalty_CT");
	AddMenuItemPhrase(menu, client, "penaltyt", "Menu_Penalty_T");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandlerPenalty(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action == MenuAction_Cancel && item == MenuCancel_ExitBack && IsValidClient(client))
	{
		ShowMatchMenu(client);
		return 0;
	}

	if (action != MenuAction_Select || !IsValidClient(client))
	{
		return 0;
	}

	if (!CheckSoccerAvailable(client) || !HasSoccerAdminAccess(client))
	{
		return 0;
	}

	char info[32];
	menu.GetItem(item, info, sizeof(info));
	if (StrEqual(info, "penaltyspot"))
	{
		CmdPenaltySpot(client, 0);
	}
	else if (StrEqual(info, "shootout"))
	{
		StartShootout();
	}
	else if (StrEqual(info, "penaltyct"))
	{
		StartPenalty(TEAM_CT, 0, 0);
	}
	else if (StrEqual(info, "penaltyt"))
	{
		StartPenalty(TEAM_T, 0, 0);
	}
	ShowPenaltyMenu(client);
	return 0;
}

public Action CmdCaptains(int client, int args)
{
	if (!CheckSoccerAvailable(client))
	{
		return Plugin_Handled;
	}

	if (args < 2)
	{
		ReplyToCommand(client, "%t", "Cmd_Captains_Clean_Usage");
		return Plugin_Handled;
	}

	int captainT = FindCommandTarget(client, 1);
	int captainCT = FindCommandTarget(client, 2);
	if (captainT <= 0 || captainCT <= 0 || captainT == captainCT)
	{
		ReplyToCommand(client, "%t", "Draft_Invalid_Captains");
		return Plugin_Handled;
	}

	SetDraftCaptains(captainT, captainCT);
	PrintToChatAll("%t", "Draft_Captains_Set_Clean", captainT, captainCT);
	return Plugin_Handled;
}

public Action CmdDraftStart(int client, int args)
{
	if (!CheckSoccerAvailable(client))
	{
		return Plugin_Handled;
	}

	if (args >= 2)
	{
		int captainT = FindCommandTarget(client, 1);
		int captainCT = FindCommandTarget(client, 2);
		if (captainT <= 0 || captainCT <= 0 || captainT == captainCT)
		{
			ReplyToCommand(client, "%t", "Draft_Invalid_Captains");
			return Plugin_Handled;
		}
		SetDraftCaptains(captainT, captainCT);
	}

	if (!IsValidClient(gDraftCaptainT) || !IsValidClient(gDraftCaptainCT))
	{
		ReplyToCommand(client, "%t", "Cmd_DraftStart_Usage");
		return Plugin_Handled;
	}

	StartDraft();
	return Plugin_Handled;
}

public Action CmdPick(int client, int args)
{
	if (!CheckSoccerAvailable(client))
	{
		return Plugin_Handled;
	}

	if (!gDraftActive)
	{
		ReplyToCommand(client, "%t", "Draft_Not_Active");
		return Plugin_Handled;
	}

	if (!IsCurrentDraftCaptain(client))
	{
		ReplyToCommand(client, "%t", "Draft_Not_Your_Turn");
		return Plugin_Handled;
	}

	if (args < 1)
	{
		ShowDraftPickMenu(client);
		return Plugin_Handled;
	}

	int target = FindCommandTarget(client, 1);
	if (target > 0)
	{
		DraftPick(client, target);
	}
	return Plugin_Handled;
}

public Action CmdDraftMenu(int client, int args)
{
	if (IsValidClient(client) && CheckSoccerAvailable(client))
	{
		ShowDraftPickMenu(client);
	}
	return Plugin_Handled;
}

public Action CmdDraftShow(int client, int args)
{
	if (CheckSoccerAvailable(client))
	{
		ShowDraftStatus(client);
	}
	return Plugin_Handled;
}

public Action CmdPenaltySpot(int client, int args)
{
	if (!IsValidClient(client) || !CheckSoccerAvailable(client))
	{
		return Plugin_Handled;
	}

	if (!GetAimPosition(client, gPenaltySpot))
	{
		GetClientAbsOrigin(client, gPenaltySpot);
	}
	gPenaltySpotValid = true;
	ReplyToCommand(client, "%t", "Penalty_Spot_Set");
	return Plugin_Handled;
}

public Action CmdPenalties(int client, int args)
{
	if (!CheckSoccerAvailable(client))
	{
		return Plugin_Handled;
	}

	if (args < 1)
	{
		StartShootout();
		return Plugin_Handled;
	}

	char teamArg[16];
	GetCmdArg(1, teamArg, sizeof(teamArg));
	int team = ParseTeamArg(teamArg);
	if (team != TEAM_CT && team != TEAM_T)
	{
		ReplyToCommand(client, "%t", "Cmd_Penalties_Clean_Usage");
		return Plugin_Handled;
	}

	int shooter = 0;
	int goalkeeper = 0;
	if (args >= 2)
	{
		shooter = FindCommandTarget(client, 2);
		if (shooter <= 0)
		{
			return Plugin_Handled;
		}
		if (GetClientTeam(shooter) != team)
		{
			ReplyToCommand(client, "%t", "Cmd_Penalties_Clean_Usage");
			return Plugin_Handled;
		}
	}
	if (args >= 3)
	{
		goalkeeper = FindCommandTarget(client, 3);
		if (goalkeeper <= 0)
		{
			return Plugin_Handled;
		}
		if (GetClientTeam(goalkeeper) == team || GetClientTeam(goalkeeper) < TEAM_T)
		{
			ReplyToCommand(client, "%t", "Cmd_Penalties_Clean_Usage");
			return Plugin_Handled;
		}
	}

	StartPenalty(team, shooter, goalkeeper);
	return Plugin_Handled;
}

public Action CmdHalftime(int client, int args)
{
	if (CheckSoccerAvailable(client))
	{
		ForceNextPeriod();
	}
	return Plugin_Handled;
}

public Action CmdKickoff(int client, int args)
{
	if (!CheckSoccerAvailable(client))
	{
		return Plugin_Handled;
	}

	if (!gMatchLive)
	{
		ReplyToCommand(client, "%t", "Match_Not_Live");
		return Plugin_Handled;
	}

	StartKickoff(GetScheduledKickoffTeam(), "KickoffReason_Manual");
	return Plugin_Handled;
}

public Action CmdYellow(int client, int args)
{
	if (!CheckSoccerAvailable(client))
	{
		return Plugin_Handled;
	}

	int target = FindCommandTarget(client, 1);
	if (target <= 0)
	{
		ReplyToCommand(client, "%t", "Cmd_Yellow_Usage");
		return Plugin_Handled;
	}

	GiveYellowCard(target);
	return Plugin_Handled;
}

public Action CmdRed(int client, int args)
{
	if (!CheckSoccerAvailable(client))
	{
		return Plugin_Handled;
	}

	int target = FindCommandTarget(client, 1);
	if (target <= 0)
	{
		ReplyToCommand(client, "%t", "Cmd_Red_Usage");
		return Plugin_Handled;
	}

	GiveRedCard(target);
	return Plugin_Handled;
}

public Action CmdTrainingBall(int client, int args)
{
	if (IsValidClient(client) && CheckSoccerAvailable(client))
	{
		SpawnTrainingBall(client);
	}
	return Plugin_Handled;
}

public Action CmdTrainingCannon(int client, int args)
{
	if (!IsValidClient(client) || !CheckSoccerAvailable(client))
	{
		return Plugin_Handled;
	}

	if (gTrainingCannonTimer != null)
	{
		StopTrainingCannon();
		PrintToChat(client, "%t", "Training_Cannon_Stopped");
		return Plugin_Handled;
	}

	if (!CanUseTrainingCannon(client))
	{
		return Plugin_Handled;
	}

	StartTrainingCannon(client);
	return Plugin_Handled;
}

public Action CmdStart(int client, int args)
{
	if (CheckSoccerAvailable(client) && StartMatch())
	{
		ReplyToCommand(client, "%t", "Match_Started");
	}
	return Plugin_Handled;
}

public Action CmdStop(int client, int args)
{
	if (CheckSoccerAvailable(client) && StopMatch())
	{
		ReplyToCommand(client, "%t", "Match_Stopped");
	}
	return Plugin_Handled;
}

public Action CmdReset(int client, int args)
{
	if (CheckSoccerAvailable(client))
	{
		ResetMatch();
		ReplyToCommand(client, "%t", "Match_Reset");
	}
	return Plugin_Handled;
}

public Action CmdPause(int client, int args)
{
	if (CheckSoccerAvailable(client) && PauseMatch())
	{
		ReplyToCommand(client, "%t", "Match_Paused");
	}
	return Plugin_Handled;
}

public Action CmdUnpause(int client, int args)
{
	if (CheckSoccerAvailable(client))
	{
		UnpauseMatch();
	}
	return Plugin_Handled;
}

public Action CmdSetBall(int client, int args)
{
	if (!CheckSoccerAvailable(client))
	{
		return Plugin_Handled;
	}

	FindBallEntity();
	int ball = GetTrackedBallEntity();
	if (ball == -1)
	{
		ReplyToCommand(client, "%t", "Cmd_Ball_NotFound");
		return Plugin_Handled;
	}

	ReplyToCommand(client, "%t", "Cmd_BallSpawn_MapControlled");
	return Plugin_Handled;
}

public Action CmdScore(int client, int args)
{
	if (!CheckSoccerAvailable(client))
	{
		return Plugin_Handled;
	}

	if (args < 2)
	{
		ReplyToCommand(client, "%t", "Cmd_Score_Clean_Usage");
		return Plugin_Handled;
	}

	char buffer[16];
	int scoreCT;
	int scoreT;
	GetCmdArg(1, buffer, sizeof(buffer));
	if (!ParseScoreValue(buffer, scoreCT))
	{
		ReplyToCommand(client, "%t", "Cmd_Score_Clean_Usage");
		return Plugin_Handled;
	}
	GetCmdArg(2, buffer, sizeof(buffer));
	if (!ParseScoreValue(buffer, scoreT))
	{
		ReplyToCommand(client, "%t", "Cmd_Score_Clean_Usage");
		return Plugin_Handled;
	}
	gScoreCT = scoreCT;
	gScoreT = scoreT;
	UpdateGameTeamScores();
	PrintScoreDisplay();
	return Plugin_Handled;
}

public Action CmdGoal(int client, int args)
{
	if (!CheckSoccerAvailable(client))
	{
		return Plugin_Handled;
	}

	if (args < 1)
	{
		ReplyToCommand(client, "%t", "Cmd_Goal_Usage");
		return Plugin_Handled;
	}

	char team[16];
	GetCmdArg(1, team, sizeof(team));
	if (StrEqual(team, "ct", false))
	{
		HandleGoal(TEAM_CT, false);
	}
	else if (StrEqual(team, "t", false))
	{
		HandleGoal(TEAM_T, false);
	}
	else
	{
		ReplyToCommand(client, "%t", "Cmd_Goal_Usage");
	}
	return Plugin_Handled;
}

public Action CmdAdminPosition(int client, int args)
{
	if (!CheckSoccerAvailable(client))
	{
		return Plugin_Handled;
	}

	if (args < 2)
	{
		ReplyToCommand(client, "%t", "Cmd_Position_Usage");
		return Plugin_Handled;
	}

	char arg[64];
	GetCmdArg(1, arg, sizeof(arg));
	int target = FindTarget(client, arg, false, true);
	if (target <= 0)
	{
		return Plugin_Handled;
	}

	GetCmdArg(2, arg, sizeof(arg));
	SetPosition(target, ParsePosition(arg));
	char positionName[32];
	FormatPositionName(0, gPosition[target], positionName, sizeof(positionName));
	PrintToChatAll("%t", "Position_Set", target, positionName);
	return Plugin_Handled;
}

public Action CmdToggleGoalkeeper(int client, int args)
{
	if (!IsValidClient(client) || !CheckSoccerAvailable(client))
	{
		return Plugin_Handled;
	}

	float cooldown = gCvarGoalkeeperCooldown.FloatValue;
	if (cooldown > 0.0)
	{
		float now = GetGameTime();
		if (gNextGoalkeeperToggle[client] > now)
		{
			PrintToChat(client, "%t", "Skin_Cooldown", RoundToCeil(gNextGoalkeeperToggle[client] - now));
			return Plugin_Handled;
		}
		gNextGoalkeeperToggle[client] = now + cooldown;
	}

	SetPosition(client, gPosition[client] == SoccerPosition_Goalkeeper ? SoccerPosition_Player : SoccerPosition_Goalkeeper);
	ShowPosition(client);
	return Plugin_Handled;
}

public Action CmdPosition(int client, int args)
{
	if (IsValidClient(client) && CheckSoccerAvailable(client))
	{
		ShowPosition(client);
	}
	return Plugin_Handled;
}

bool StartMatchWithPeriodMinutes(int client, int minutes)
{
	if (minutes < 1 || minutes > 60)
	{
		if (IsValidClient(client))
		{
			PrintToChat(client, "%t", "Menu_Start_Custom_Invalid");
		}
		return false;
	}

	gCvarMatchPeriodLength.SetInt(minutes);
	return StartMatch();
}

bool StartMatch()
{
	if (!IsSoccerAvailable())
	{
		PrintToChatAll("%t", gMapAllowed ? "Soccer_Disabled" : "Map_Not_Allowed");
		return false;
	}

	if (gMatchLive)
	{
		PrintToChatAll("%t", "Match_Already_Live");
		return false;
	}

	StopTrainingCannon();
	// The match restarts the round, which brings the goal triggers back.
	gTrainingGoalsDisabled = false;
	gMatchLive = true;
	gPaused = false;
	gUnpausing = false;
	gUnpauseSecondsLeft = 0;
	gInBreak = false;
	gOvertimeActive = false;
	gKickoffActive = false;
	gKickoffFrozen = false;
	gKickoffQueued = false;
	gStoppageActive = false;
	gInitialRestartPending = false;
	gStoppageSeconds = 0;
	gOpeningKickoffTeam = GetRandomKickoffTeam();
	gPenaltyActive = false;
	gShootoutActive = false;
	gMaxPeriods = gCvarMatchPeriods.IntValue;
	gCurrentPeriod = 1;
	gMatchElapsed = 0.0;
	gScoreCT = 0;
	gScoreT = 0;
	gRoundGoalHandled = false;
	gRestartingPeriod = false;
	gLastGoalTime = -9999.0;
	gLastToucher = 0;
	gPreviousToucher = 0;
	ResetMatchPlayerState();
	UpdateGameTeamScores();
	StartDefaultCaptainDraft();
	DiscoverSoccerEntities();
	CacheBallStartPosition();
	gPendingRestartPeriodLength = float(gCvarMatchPeriodLength.IntValue * 60);
	gPeriodRemaining = gPendingRestartPeriodLength;
	gPeriodDuration = gPendingRestartPeriodLength;
	gPeriodElapsed = 0.0;
	gInitialRestartPending = true;
	StartKickoff(gOpeningKickoffTeam, "KickoffReason_FirstHalf");
	PrintToChatAll("%t", "Match_Started_Time", gCvarMatchPeriodLength.IntValue);
	return true;
}

bool StopMatch(bool announce = true)
{
	if (!gMatchLive)
	{
		PrintToChatAll("%t", "Match_Not_Live");
		return false;
	}

	gMatchLive = false;
	gPaused = false;
	gUnpausing = false;
	gUnpauseSecondsLeft = 0;
	gInBreak = false;
	gOvertimeActive = false;
	gKickoffActive = false;
	gKickoffFrozen = false;
	gKickoffQueued = false;
	gInitialRestartPending = false;
	gRoundGoalHandled = false;
	gRestartingPeriod = false;
	gStoppageActive = false;
	gStoppageSeconds = 0;
	gOpeningKickoffTeam = 0;
	gPenaltyActive = false;
	gPenaltyWaitingForKick = false;
	gPenaltyTeam = 0;
	gPenaltyShooter = 0;
	gPenaltyGoalkeeper = 0;
	gShootoutActive = false;
	gShootoutScoreCT = 0;
	gShootoutScoreT = 0;
	gShootoutTakenCT = 0;
	gShootoutTakenT = 0;
	gShootoutNextTeam = 0;
	gShootoutShooterIndexCT = 0;
	gShootoutShooterIndexT = 0;
	gPeriodRemaining = 0.0;
	gPeriodDuration = 0.0;
	gPeriodElapsed = 0.0;
	gMatchElapsed = 0.0;
	gPendingRestartPeriodLength = 0.0;
	gPeriodEndTime = 0.0;
	gBreakEndTime = 0.0;
	gKickoffReasonPhrase[0] = '\0';
	gPendingRestartKickoffReason[0] = '\0';
	gShootoutWaitingRoundStart = false;
	KillMatchTimers();
	KillStoppageTrigger();
	StopAllSprints();
	UnfreezeAllPlayers();
	// Draft sides only bind the match they were drafted for.
	ClearDraftTeams();
	if (announce)
	{
		PrintToChatAll("%t", "Match_Stopped");
	}
	return true;
}

void FinishMatch()
{
	if (!gMatchLive)
	{
		return;
	}

	PrintToChatAll("%t", "Final_Result", gScoreCT, gScoreT);
	int mvp = PrintMatchMVP();
	RankingOnMatchFinished(mvp);
	StopMatch(false);
	ResetFinishedMatchScoreAndRound();
}

void ResetFinishedMatchScoreAndRound()
{
	gScoreCT = 0;
	gScoreT = 0;
	gCurrentPeriod = 0;
	gMaxPeriods = 0;
	ClearLastTouchers();
	ResetMatchTabScores();
	UpdateGameTeamScores();
	ServerCommand("mp_restartgame 1");
}

void ResetMatchTabScores()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		gPlayerGoals[client] = 0;
		gPlayerAssists[client] = 0;
		gPlayerOwnGoals[client] = 0;
		gPlayerPoints[client] = 0;
		if (IsValidClient(client))
		{
			SetEntProp(client, Prop_Data, "m_iFrags", 0);
			SetEntProp(client, Prop_Data, "m_iDeaths", 0);
		}
	}
}

int PrintMatchMVP()
{
	int bestClient = 0;
	int bestPoints = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsValidClient(client))
		{
			continue;
		}

		if (gPlayerPoints[client] > bestPoints)
		{
			bestClient = client;
			bestPoints = gPlayerPoints[client];
		}
	}

	if (bestClient > 0)
	{
		PrintToChatAll("%t", "Match_MVP", bestClient, bestPoints);
	}
	else
	{
		PrintToChatAll("%t", "Match_MVP_None");
	}
	return bestClient;
}

void ResetMatch()
{
	gMatchLive = false;
	gPaused = false;
	gUnpausing = false;
	gUnpauseSecondsLeft = 0;
	gScoreCT = 0;
	gScoreT = 0;
	gRoundGoalHandled = false;
	gRestartingPeriod = false;
	gStoppageActive = false;
	gStoppageSeconds = 0;
	gLastGoalTime = -9999.0;
	gLastToucher = 0;
	gPreviousToucher = 0;
	gCurrentPeriod = 0;
	gMaxPeriods = 0;
	gInBreak = false;
	gOvertimeActive = false;
	gKickoffActive = false;
	gKickoffFrozen = false;
	gKickoffQueued = false;
	gInitialRestartPending = false;
	gOpeningKickoffTeam = 0;
	gPenaltyActive = false;
	gPenaltyWaitingForKick = false;
	gPenaltyShooter = 0;
	gPenaltyGoalkeeper = 0;
	gShootoutActive = false;
	gShootoutWaitingRoundStart = false;
	gPeriodDuration = 0.0;
	gPeriodElapsed = 0.0;
	gMatchElapsed = 0.0;
	KillMatchTimers();
	KillStoppageTrigger();
	StopAllSprints();
	UnfreezeAllPlayers();
	ResetMatchPlayerState();
	ClearDraftTeams();
	UpdateGameTeamScores();
	PrintToChatAll("%t", "Match_Reset");
}

bool PauseMatch()
{
	if (!gMatchLive)
	{
		PrintToChatAll("%t", "Match_Not_Live");
		return false;
	}
	if (gPaused || gUnpausing)
	{
		return false;
	}

	gPaused = true;
	gUnpausing = false;
	gUnpauseSecondsLeft = 0;
	KillTimerSafe(gUnpauseTimer);
	StopPeriodClock();
	StopStoppageClock();
	StopAllSprints();
	FreezeAllPlayers();
	PrintToChatAll("%t", "Match_Paused");
	return true;
}

bool UnpauseMatch()
{
	if (!gMatchLive)
	{
		PrintToChatAll("%t", "Match_Not_Live");
		return false;
	}
	if (!gPaused)
	{
		return false;
	}
	if (gUnpausing)
	{
		return false;
	}

	gUnpausing = true;
	gUnpauseSecondsLeft = 5;
	FreezeAllPlayers();
	PrintToChatAll("%t", "Resume_Announce", gUnpauseSecondsLeft);
	PrintCenterTextAll("%t", "Resume_Countdown", gUnpauseSecondsLeft);
	KillTimerSafe(gUnpauseTimer);
	gUnpauseTimer = CreateTimer(1.0, TimerUnpauseCountdown, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	return true;
}

public Action TimerUnpauseCountdown(Handle timer)
{
	if (!gMatchLive || !gPaused || !gUnpausing)
	{
		gUnpauseTimer = null;
		gUnpausing = false;
		gUnpauseSecondsLeft = 0;
		return Plugin_Stop;
	}

	gUnpauseSecondsLeft--;
	if (gUnpauseSecondsLeft <= 0)
	{
		gUnpauseTimer = null;
		gUnpausing = false;
		gUnpauseSecondsLeft = 0;
		gPaused = false;
		UnfreezeAllPlayers();
		ResumeMatchClock();
		PrintCenterTextAll("%t", "Resume_Play");
		PrintToChatAll("%t", "Match_Unpaused");
		return Plugin_Stop;
	}

	PrintCenterTextAll("%t", "Resume_Countdown", gUnpauseSecondsLeft);
	return Plugin_Continue;
}

void HandleGoal(int scoringTeam, bool waitForRoundStart)
{
	float now = GetGameTime();
	if (now - gLastGoalTime < 2.0)
	{
		return;
	}

	if (gPenaltyActive)
	{
		if (!IsMatchPenalty())
		{
			// The round winner is whoever attacks the goal the ball went into. With
			// the kick spot at the defending team's goal that is the shooting team;
			// without a known orientation any goal during the kick counts.
			gLastGoalTime = now;
			ResolvePenalty(!gPenaltyKickSpotOriented || scoringTeam == gPenaltyTeam);
			return;
		}

		// A match penalty nobody kicked yet: the goal is played as a normal one.
		EndMatchPenalty(false);
	}

	if (gRoundGoalHandled)
	{
		return;
	}
	gLastGoalTime = now;
	gRoundGoalHandled = true;
	int saveShooter = SavesOnGoal(scoringTeam);
	StopPeriodClock();
	StopStoppageClock();

	if (scoringTeam == TEAM_CT)
	{
		gScoreCT++;
	}
	else
	{
		gScoreT++;
	}
	UpdateGameTeamScores();

	int scorer = gLastToucher;
	int assist = gPreviousToucher;
	// A shot the goalkeeper only touched on its way in is the shooter's goal,
	// not an own goal; with the shooter gone it has no named scorer.
	if (saveShooter != 0)
	{
		scorer = saveShooter > 0 ? saveShooter : 0;
		assist = 0;
	}
	if (IsValidClient(scorer))
	{
		if (GetClientTeam(scorer) == scoringTeam)
		{
			AddPlayerGoalScore(scorer);
			PrintToChatAll("%t", "Goal_Scorer", scorer);

			if (IsValidClient(assist)
				&& assist != scorer
				&& GetClientTeam(assist) == scoringTeam)
			{
				AddPlayerAssistScore(assist);
				PrintToChatAll("%t", "Goal_Assist", assist);
			}
		}
		else
		{
			AddPlayerOwnGoalScore(scorer);
			PrintOwnGoal(scorer);
		}
	}
	else
	{
		PrintToChatAll("%t", "Goal_Generic");
	}

	// The team result does not depend on identifying the scorer.
	AddTeamRoundResultPoints(scoringTeam);

	PrintScoreDisplay();
	if (!gMatchLive)
	{
		return;
	}

	// gOvertimeActive is already set during the break before the first half.
	if (gOvertimeActive && gCurrentPeriod > gMaxPeriods && gCvarMatchGoldenGoal.BoolValue)
	{
		PrintToChatAll("%t", "GoldenGoal_Finished");
		FinishMatch();
		return;
	}

	// A goal in stoppage time ends the period right there, instead of waiting
	// for the kickoff to cross the halfway line.
	if (gStoppageActive)
	{
		EndStoppageTime();
		return;
	}

	int kickoffTeam = scoringTeam == TEAM_CT ? TEAM_T : TEAM_CT;
	if (waitForRoundStart)
	{
		QueueKickoff(kickoffTeam, "KickoffReason_Goal");
	}
	else
	{
		StartKickoff(kickoffTeam, "KickoffReason_Goal");
	}
}

void RegisterBallTouch(int client, int ball)
{
	if (!IsValidClient(client) || !IsPlayerAlive(client))
	{
		return;
	}
	if (!CanRegisterMatchBallTouch())
	{
		return;
	}

	if (gKickoffActive)
	{
		BeginPeriodClockAfterKickoff();
	}

	float now = GetGameTime();
	if (now - gClientLastTouch[client] < gCvarTouchCooldown.FloatValue)
	{
		return;
	}

	gClientLastTouch[client] = now;
	int previousToucher = gLastToucher;
	SavesOnBallTouch(client, ball, previousToucher);
	if (client != previousToucher)
	{
		if (IsValidClient(previousToucher))
		{
			if (GetClientTeam(previousToucher) == GetClientTeam(client))
			{
				AddPlayerPassScore(previousToucher);
			}
			else
			{
				AddPlayerInterceptionScore(client);
				AddPlayerBallLossScore(previousToucher);
			}
		}
		gPreviousToucher = previousToucher;
	}
	gLastToucher = client;
	AddPlayerHitPoint(client);
}

bool CanRegisterMatchBallTouch()
{
	if (!gMatchLive)
	{
		return true;
	}
	return !gPaused && !gInBreak && !gRestartingPeriod && !gKickoffFrozen;
}

void BeginPeriodClockAfterKickoff()
{
	if (!gMatchLive || gPaused || gInBreak || gRestartingPeriod || !gKickoffActive || gKickoffFrozen || gPenaltyActive)
	{
		return;
	}

	EndKickoff();
	if (gStoppageActive)
	{
		StartStoppageClock();
	}
	else if (gPeriodTimer == null && gPeriodRemaining > 0.0)
	{
		StartPeriodClock(gPeriodRemaining, true);
	}
}

void ClearLastTouchers()
{
	gLastToucher = 0;
	gPreviousToucher = 0;
}

void AddPlayerHitPoint(int client)
{
	RankingAddStat(client, RANK_STAT_HITS, 1);
	AddPlayerPoints(client, gCvarRankingPointsHit.IntValue);
}

void AddPlayerGoalScore(int client)
{
	if (!IsValidClient(client))
	{
		return;
	}

	gPlayerGoals[client]++;
	gPlayerPoints[client] += gCvarRankingPointsGoal.IntValue;
	RankingAddStat(client, RANK_STAT_GOALS, 1);
	RankingAddStat(client, RANK_STAT_POINTS, gCvarRankingPointsGoal.IntValue);
	UpdateClientScoreboard(client);
}

void AddPlayerAssistScore(int client)
{
	if (!IsValidClient(client))
	{
		return;
	}

	gPlayerAssists[client]++;
	gPlayerPoints[client] += gCvarRankingPointsAssist.IntValue;
	RankingAddStat(client, RANK_STAT_ASSISTS, 1);
	RankingAddStat(client, RANK_STAT_POINTS, gCvarRankingPointsAssist.IntValue);
	UpdateClientScoreboard(client);
}

void AddPlayerOwnGoalScore(int client)
{
	if (!IsValidClient(client))
	{
		return;
	}

	gPlayerOwnGoals[client]++;
	gPlayerPoints[client] += gCvarRankingPointsOwnGoal.IntValue;
	RankingAddStat(client, RANK_STAT_OWN_GOALS, 1);
	RankingAddStat(client, RANK_STAT_POINTS, gCvarRankingPointsOwnGoal.IntValue);
	UpdateClientScoreboard(client);
}

void AddPlayerPassScore(int client)
{
	RankingAddStat(client, RANK_STAT_PASSES, 1);
	AddPlayerPoints(client, gCvarRankingPointsPass.IntValue);
}

void AddPlayerInterceptionScore(int client)
{
	RankingAddStat(client, RANK_STAT_INTERCEPTIONS, 1);
	AddPlayerPoints(client, gCvarRankingPointsInterception.IntValue);
}

void AddPlayerBallLossScore(int client)
{
	RankingAddStat(client, RANK_STAT_BALL_LOSSES, 1);
	AddPlayerPoints(client, gCvarRankingPointsBallLoss.IntValue);
}

void AddPlayerPoints(int client, int points)
{
	if (!IsValidClient(client) || points == 0)
	{
		return;
	}

	gPlayerPoints[client] += points;
	RankingAddStat(client, RANK_STAT_POINTS, points);
	UpdateClientScoreboard(client);
}

void AddTeamRoundResultPoints(int scoringTeam)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsValidClient(client))
		{
			continue;
		}

		int team = GetClientTeam(client);
		if (team != TEAM_T && team != TEAM_CT)
		{
			continue;
		}

		RankingAddStat(client, team == scoringTeam ? RANK_STAT_ROUNDS_WON : RANK_STAT_ROUNDS_LOST, 1);
		AddPlayerPoints(client, team == scoringTeam ? gCvarRankingPointsRoundWon.IntValue : gCvarRankingPointsRoundLost.IntValue);
	}
}

void UpdateClientScoreboard(int client)
{
	if (IsValidClient(client))
	{
		SetEntProp(client, Prop_Data, "m_iFrags", gPlayerGoals[client]);
		SetEntProp(client, Prop_Data, "m_iDeaths", gPlayerPoints[client]);
	}
}

public void FrameUpdateClientScoreboard(any userid)
{
	int client = GetClientOfUserId(userid);
	if (IsValidClient(client))
	{
		UpdateClientScoreboard(client);
	}
}

void RegisterPenaltyTouch(int client)
{
	if (!gPenaltyActive || !gPenaltyWaitingForKick || client != gPenaltyShooter)
	{
		return;
	}

	PrintToChatAll("%t", "Penalty_Live");
	// In a match the kick puts the ball back in play: what follows is normal
	// play, scored, credited and restarted like any other goal.
	if (IsMatchPenalty())
	{
		EndMatchPenalty();
		return;
	}

	gPenaltyWaitingForKick = false;
	KillPenaltyTimer();
	gPenaltyTimer = CreateTimer(gCvarPenaltyShotTime.FloatValue, TimerPenaltyTimeout, _, TIMER_FLAG_NO_MAPCHANGE);
}

// A penalty awarded during a live match, as opposed to practice or a shootout.
bool IsMatchPenalty()
{
	return gPenaltyActive && gMatchLive && !gShootoutActive;
}

void EndMatchPenalty(bool resumeClock = true)
{
	KillPenaltyTimer();
	gPenaltyActive = false;
	gPenaltyWaitingForKick = false;
	gPenaltyShooter = 0;
	gPenaltyGoalkeeper = 0;
	if (resumeClock)
	{
		ResumeMatchClock();
	}
}

// Restarts whichever match clock was stopped, unless something else still
// holds play: a pause, a break, a restart or a kickoff (whose first touch
// starts the clock instead).
void ResumeMatchClock()
{
	if (!gMatchLive || gPaused || gUnpausing || gInBreak || gRestartingPeriod || gKickoffActive || gPenaltyActive)
	{
		return;
	}

	if (gStoppageActive)
	{
		StartStoppageClock();
	}
	else if (gPeriodTimer == null && gPeriodRemaining > 0.0)
	{
		StartPeriodClock(gPeriodRemaining, true);
	}
}

public Action TimerPenaltyTimeout(Handle timer)
{
	gPenaltyTimer = null;
	// A pause holds the kick too: the shooter gets the full time again after it.
	if (gPenaltyActive && (gPaused || gUnpausing))
	{
		gPenaltyTimer = CreateTimer(gCvarPenaltyShotTime.FloatValue, TimerPenaltyTimeout, _, TIMER_FLAG_NO_MAPCHANGE);
		return Plugin_Stop;
	}
	if (gPenaltyActive)
	{
		ResolvePenalty(false);
	}
	return Plugin_Stop;
}

void StartPeriodClock(float seconds, bool resume = false)
{
	KillTimerSafe(gPeriodTimer);
	if (!resume || gPeriodDuration <= 0.0)
	{
		gPeriodDuration = seconds;
		gPeriodElapsed = 0.0;
	}
	gPeriodRemaining = seconds;
	gPeriodEndTime = GetGameTime() + seconds;
	if (seconds > 0.0)
	{
		gPeriodTimer = CreateTimer(seconds, TimerPeriodEnd, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

void StopPeriodClock()
{
	if (gPeriodTimer != null)
	{
		gPeriodRemaining = gPeriodEndTime - GetGameTime();
		if (gPeriodRemaining < 0.0)
		{
			gPeriodRemaining = 0.0;
		}
		gPeriodElapsed = gPeriodDuration - gPeriodRemaining;
		if (gPeriodElapsed < 0.0)
		{
			gPeriodElapsed = 0.0;
		}
		KillTimerSafe(gPeriodTimer);
	}
}

public Action TimerPeriodEnd(Handle timer)
{
	gPeriodTimer = null;
	gPeriodRemaining = 0.0;
	gMatchElapsed += gPeriodDuration;
	gPeriodElapsed = 0.0;
	StartStoppageTime();
	return Plugin_Stop;
}

void StartStoppageTime()
{
	if (!gMatchLive || gStoppageActive)
	{
		return;
	}

	gStoppageActive = true;
	gStoppageSeconds = 0;
	EnsureStoppageTrigger();
	StartStoppageClock();
}

void StartStoppageClock()
{
	if (!gMatchLive || !gStoppageActive || gPaused || gInBreak || gKickoffActive || gRestartingPeriod)
	{
		return;
	}

	KillTimerSafe(gStoppageTimer);
	gStoppageTimer = CreateTimer(1.0, TimerStoppage, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

void StopStoppageClock()
{
	KillTimerSafe(gStoppageTimer);
}

public Action TimerStoppage(Handle timer)
{
	if (!gMatchLive || !gStoppageActive || gPaused || gInBreak || gKickoffActive || gRestartingPeriod)
	{
		gStoppageTimer = null;
		return Plugin_Stop;
	}

	gStoppageSeconds++;
	return Plugin_Continue;
}

void EndStoppageTime()
{
	if (!gStoppageActive)
	{
		return;
	}

	StopStoppageClock();
	KillStoppageTrigger();
	gStoppageActive = false;
	gStoppageSeconds = 0;
	FinishPeriod();
}

void FinishPeriod()
{
	if (!gMatchLive)
	{
		return;
	}

	ClearLastTouchers();
	FreezeAllPlayers();
	if (IsFinalPeriod())
	{
		if (gOvertimeActive)
		{
			FinishOvertime();
			return;
		}

		if (gScoreCT == gScoreT && gCvarMatchOvertime.BoolValue)
		{
			StartOvertime();
			return;
		}
		FinishMatch();
		return;
	}

	StartBreak();
}

// Overtime is played as two halves. Each one starts from a round restart like a
// regular period, with the usual break before the first half and between them.
void StartOvertime()
{
	gOvertimeActive = true;
	StartBreak();
}

bool IsFinalPeriod()
{
	int lastPeriod = gOvertimeActive ? gMaxPeriods + OVERTIME_PERIODS : gMaxPeriods;
	return gCurrentPeriod >= lastPeriod;
}

int GetPeriodLengthSeconds(int period)
{
	if (period > gMaxPeriods)
	{
		return GetOvertimeLengthSeconds() / OVERTIME_PERIODS;
	}
	return gCvarMatchPeriodLength.IntValue * 60;
}

void StartNextPeriod()
{
	gCurrentPeriod++;
	gStoppageActive = false;
	gStoppageSeconds = 0;
	gPendingRestartKickoffReason[0] = '\0';
	if (gOvertimeActive)
	{
		if (gCurrentPeriod == gMaxPeriods + 1)
		{
			char overtimeDuration[16];
			FormatDurationSeconds(GetOvertimeLengthSeconds(), overtimeDuration, sizeof(overtimeDuration));
			PrintToChatAll("%t", "Overtime_Start", overtimeDuration);
			if (gCvarMatchGoldenGoal.BoolValue)
			{
				PrintToChatAll("%t", "GoldenGoal_Start");
			}
		}
		strcopy(gPendingRestartKickoffReason, sizeof(gPendingRestartKickoffReason), "KickoffReason_Overtime");
	}
	else if (gCurrentPeriod == 2 && gMaxPeriods == 2)
	{
		strcopy(gPendingRestartKickoffReason, sizeof(gPendingRestartKickoffReason), "KickoffReason_SecondHalf");
	}
	else
	{
		strcopy(gPendingRestartKickoffReason, sizeof(gPendingRestartKickoffReason), "KickoffReason_NextPeriod");
	}
	gPeriodRemaining = float(GetPeriodLengthSeconds(gCurrentPeriod));
	RestartRoundBeforePeriod(gPeriodRemaining);
}

void FinishOvertime()
{
	gOvertimeActive = false;
	if (gScoreCT == gScoreT)
	{
		PrintToChatAll("%t", "Overtime_Tied");
	}
	else
	{
		PrintToChatAll("%t", "Overtime_Finished");
	}
	FinishMatch();
}

int GetOvertimeLengthSeconds()
{
	int totalMatchSeconds = gCvarMatchPeriodLength.IntValue * gCvarMatchPeriods.IntValue * 60;
	float overtimeFraction = gCvarMatchOvertimePercent.FloatValue / 100.0;
	return RoundToCeil((float(totalMatchSeconds) * overtimeFraction) / 60.0) * 60;
}

void EnsureStoppageTrigger()
{
	int existing = EntRefToEntIndex(gStoppageTriggerRef);
	if (existing != INVALID_ENT_REFERENCE && existing > MaxClients && IsValidEntity(existing))
	{
		return;
	}

	if (!gBallStartPositionValid)
	{
		CacheBallStartPosition();
	}
	if (!gBallStartPositionValid)
	{
		return;
	}

	int trigger = CreateEntityByName("trigger_once");
	if (trigger == -1)
	{
		return;
	}

	DispatchKeyValue(trigger, "targetname", "end_stoppage_time");
	DispatchKeyValue(trigger, "spawnflags", "8");
	DispatchSpawn(trigger);
	ActivateEntity(trigger);
	TeleportEntity(trigger, gBallStartPosition, NULL_VECTOR, NULL_VECTOR);

	PrecacheStoppageTriggerModel();
	SetEntityModel(trigger, STOPPAGE_TRIGGER_MODEL);

	float minbounds[3] = {-2000.0, -1.0, -10.0};
	float maxbounds[3] = {2000.0, 1.0, 5000.0};
	SetEntPropVector(trigger, Prop_Send, "m_vecMins", minbounds);
	SetEntPropVector(trigger, Prop_Send, "m_vecMaxs", maxbounds);
	SetEntProp(trigger, Prop_Send, "m_nSolidType", 2);

	int effects = GetEntProp(trigger, Prop_Send, "m_fEffects");
	effects |= 32;
	SetEntProp(trigger, Prop_Send, "m_fEffects", effects);

	gStoppageTriggerRef = EntIndexToEntRef(trigger);
}

void KillStoppageTrigger()
{
	int trigger = EntRefToEntIndex(gStoppageTriggerRef);
	if (trigger != INVALID_ENT_REFERENCE && trigger > MaxClients && IsValidEntity(trigger))
	{
		AcceptEntityInput(trigger, "Kill");
	}
	gStoppageTriggerRef = INVALID_ENT_REFERENCE;
}

void StartBreak()
{
	gInBreak = true;
	ClearLastTouchers();
	FreezeAllPlayers();
	float seconds = gCvarMatchBreakLength.FloatValue;
	gBreakEndTime = GetGameTime() + seconds;
	KillTimerSafe(gBreakTimer);
	PrintToChatAll("%t", "Break_Start", gCurrentPeriod, RoundToFloor(seconds));
	gBreakTimer = CreateTimer(seconds, TimerBreakEnd, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action TimerBreakEnd(Handle timer)
{
	gBreakTimer = null;
	gInBreak = false;
	StartNextPeriod();
	return Plugin_Stop;
}

void ForceNextPeriod()
{
	// While a restart is pending the next period is already on its way; forcing
	// again would skip one.
	if (!gMatchLive || gRestartingPeriod)
	{
		return;
	}

	bool wasInBreak = gInBreak;
	StopPeriodClock();
	KillTimerSafe(gBreakTimer);
	StopStoppageClock();
	KillStoppageTrigger();
	if (gCurrentPeriod < 1)
	{
		gCurrentPeriod = 1;
	}
	if (!wasInBreak)
	{
		gMatchElapsed += gPeriodElapsed;
	}
	gPeriodElapsed = 0.0;
	gPeriodRemaining = 0.0;
	gInBreak = false;
	gStoppageActive = false;
	gStoppageSeconds = 0;

	// From a break, go straight to the period it was waiting for. From the last
	// period, end it the way the clock would: overtime or the final whistle.
	if (!wasInBreak && IsFinalPeriod())
	{
		FinishPeriod();
		return;
	}
	StartNextPeriod();
}

void RestartRoundBeforePeriod(float periodLength)
{
	KillTimerSafe(gPeriodRestartTimer);
	gPendingRestartPeriodLength = periodLength;
	gRestartingPeriod = true;
	gKickoffActive = false;
	gKickoffFrozen = false;
	gKickoffQueued = false;
	gQueuedKickoffTeam = 0;
	gQueuedKickoffReasonPhrase[0] = '\0';
	gKickoffReasonPhrase[0] = '\0';
	ClearLastTouchers();
	FreezeAllPlayers();
	ServerCommand("mp_restartgame 1");
	gPeriodRestartTimer = CreateTimer(1.1, TimerStartRestartedPeriod, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action TimerStartRestartedPeriod(Handle timer)
{
	gPeriodRestartTimer = null;
	if (!gMatchLive || gInBreak)
	{
		gRestartingPeriod = false;
		return Plugin_Stop;
	}

	gRestartingPeriod = false;
	gKickoffActive = false;
	gKickoffFrozen = false;
	gKickoffQueued = false;
	gQueuedKickoffTeam = 0;
	gQueuedKickoffReasonPhrase[0] = '\0';
	gKickoffReasonPhrase[0] = '\0';
	ClearLastTouchers();
	gPeriodRemaining = gPendingRestartPeriodLength;
	gPeriodDuration = gPendingRestartPeriodLength;
	gPeriodElapsed = 0.0;
	gKickoffActive = true;
	gKickoffTeam = GetScheduledKickoffTeam();
	if (gPendingRestartKickoffReason[0] != '\0')
	{
		strcopy(gKickoffReasonPhrase, sizeof(gKickoffReasonPhrase), gPendingRestartKickoffReason);
		PrintKickoffStartChat(gKickoffTeam, gPendingRestartKickoffReason);
		gPendingRestartKickoffReason[0] = '\0';
	}
	UnfreezeAllPlayers();
	return Plugin_Stop;
}

void RestartRoundAfterInitialKickoff()
{
	KillTimerSafe(gPeriodRestartTimer);
	gInitialRestartPending = false;
	gRestartingPeriod = true;
	gKickoffFrozen = true;
	ServerCommand("mp_restartgame 1");
	gPeriodRestartTimer = CreateTimer(1.1, TimerStartInitialRestartedPeriod, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action TimerStartInitialRestartedPeriod(Handle timer)
{
	gPeriodRestartTimer = null;
	if (!gMatchLive || gInBreak)
	{
		gRestartingPeriod = false;
		gKickoffActive = false;
		gKickoffFrozen = false;
		return Plugin_Stop;
	}

	gRestartingPeriod = false;
	gPeriodRemaining = gPendingRestartPeriodLength;
	gPeriodDuration = gPendingRestartPeriodLength;
	gPeriodElapsed = 0.0;
	AllowKickoffTouch();
	return Plugin_Stop;
}

void QueueKickoff(int team, const char[] reasonPhrase)
{
	if (!IsSoccerAvailable() || !gMatchLive)
	{
		return;
	}

	gKickoffQueued = true;
	gKickoffActive = true;
	gKickoffFrozen = true;
	gQueuedKickoffTeam = team;
	gKickoffTeam = team;
	strcopy(gQueuedKickoffReasonPhrase, sizeof(gQueuedKickoffReasonPhrase), reasonPhrase);
	strcopy(gKickoffReasonPhrase, sizeof(gKickoffReasonPhrase), reasonPhrase);
}

void StartKickoff(int team, const char[] reasonPhrase)
{
	if (!IsSoccerAvailable() || !gMatchLive)
	{
		return;
	}

	gKickoffActive = true;
	gKickoffFrozen = true;
	gKickoffQueued = false;
	gQueuedKickoffTeam = 0;
	gQueuedKickoffReasonPhrase[0] = '\0';
	gKickoffTeam = team;
	strcopy(gKickoffReasonPhrase, sizeof(gKickoffReasonPhrase), reasonPhrase);
	FreezeAllPlayers();
	PrintKickoffStartChat(gKickoffTeam, reasonPhrase);
	AllowKickoffTouch();
}

void AllowKickoffTouch()
{
	if (gInitialRestartPending)
	{
		RestartRoundAfterInitialKickoff();
		return;
	}

	gKickoffFrozen = false;
	UnfreezeAllPlayers();
}

void EndKickoff()
{
	gKickoffActive = false;
	gKickoffFrozen = false;
	gRoundGoalHandled = false;
}

int GetScheduledKickoffTeam()
{
	if (gOpeningKickoffTeam != TEAM_CT && gOpeningKickoffTeam != TEAM_T)
	{
		gOpeningKickoffTeam = GetRandomKickoffTeam();
	}

	if ((gCurrentPeriod % 2) == 0)
	{
		return GetOppositeTeam(gOpeningKickoffTeam);
	}
	return gOpeningKickoffTeam;
}

int GetRandomKickoffTeam()
{
	return GetRandomInt(0, 1) == 0 ? TEAM_CT : TEAM_T;
}

int GetOppositeTeam(int team)
{
	return team == TEAM_CT ? TEAM_T : TEAM_CT;
}

void PrintKickoffStartChat(int team, const char[] reasonPhrase)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsValidClient(client) || IsFakeClient(client))
		{
			continue;
		}

		char reason[64];
		Format(reason, sizeof(reason), "%T", reasonPhrase, client);
		char teamName[64];
		FormatColoredKickoffTeamName(client, team, teamName, sizeof(teamName));
		char message[192];
		Format(message, sizeof(message), "%T", "Kickoff_Chat_Team", client, reason, teamName);
		SendRawChat(client, message);
	}
}

void PrintOwnGoal(int scorer)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsValidClient(client) || IsFakeClient(client))
		{
			continue;
		}

		char label[64];
		char by[24];
		char scorerName[MAX_NAME_LENGTH];
		char red[8];

		Format(label, sizeof(label), "%T", "Goal_Own_Label", client);
		Format(by, sizeof(by), "%T", "Goal_By", client);
		GetClientName(scorer, scorerName, sizeof(scorerName));
		FormatTeamColorPrefix(TEAM_T, red, sizeof(red));

		char message[192];
		Format(message, sizeof(message), "%s%s\x01 %s \x04%s", red, label, by, scorerName);
		SendRawChat(client, message);
	}
}

void PrintScoreDisplay()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsValidClient(client) || IsFakeClient(client))
		{
			continue;
		}

		char label[32];
		Format(label, sizeof(label), "%T", "Score_Label", client);

		char blue[8];
		char red[8];
		FormatTeamColorPrefix(TEAM_CT, blue, sizeof(blue));
		FormatTeamColorPrefix(TEAM_T, red, sizeof(red));

		char message[192];
		Format(message, sizeof(message), "\x04%s:\x01 %sCT %d\x01 - %s%d TT", label, blue, gScoreCT, red, gScoreT);
		SendRawChat(client, message);
	}
}

void SendRawChat(int client, const char[] message)
{
	SendChatMessage(client, 0, message);
}

void SendChatMessage(int client, int author, const char[] message)
{
	Handle sayText = StartMessageOne("SayText2", client, USERMSG_RELIABLE | USERMSG_BLOCKHOOKS);
	if (sayText == null)
	{
		return;
	}

	BfWriteByte(sayText, author);
	BfWriteByte(sayText, true);
	BfWriteString(sayText, message);
	EndMessage();
}

void ClearMatchRuntimeState()
{
	gMatchLive = false;
	gPaused = false;
	gUnpausing = false;
	gUnpauseSecondsLeft = 0;
	gInBreak = false;
	gOvertimeActive = false;
	gKickoffActive = false;
	gKickoffFrozen = false;
	gKickoffQueued = false;
	gInitialRestartPending = false;
	gOpeningKickoffTeam = 0;
	gKickoffTeam = 0;
	gQueuedKickoffTeam = 0;
	gRoundGoalHandled = false;
	gRoundEnded = false;
	gRestartingPeriod = false;
	gPenaltyActive = false;
	gPenaltyWaitingForKick = false;
	gShootoutActive = false;
	gPenaltyTeam = 0;
	gPenaltyShooter = 0;
	gPenaltyGoalkeeper = 0;
	gShootoutScoreCT = 0;
	gShootoutScoreT = 0;
	gShootoutTakenCT = 0;
	gShootoutTakenT = 0;
	gShootoutNextTeam = 0;
	gShootoutShooterIndexCT = 0;
	gShootoutShooterIndexT = 0;
	gShootoutWaitingRoundStart = false;
	gStoppageSeconds = 0;
	gBallStartPositionValid = false;
	gCurrentPeriod = 0;
	gMaxPeriods = 0;
	gScoreCT = 0;
	gScoreT = 0;
	gPeriodRemaining = 0.0;
	gPeriodDuration = 0.0;
	gPeriodElapsed = 0.0;
	gMatchElapsed = 0.0;
	gPendingRestartPeriodLength = 0.0;
	gPeriodEndTime = 0.0;
	gBreakEndTime = 0.0;
	gLastGoalTime = -9999.0;
	gKickoffReasonPhrase[0] = '\0';
	gQueuedKickoffReasonPhrase[0] = '\0';
	gPendingRestartKickoffReason[0] = '\0';
	gLastToucher = 0;
	gPreviousToucher = 0;
}

void KillMatchTimers()
{
	KillTimerSafe(gPeriodTimer);
	KillTimerSafe(gBreakTimer);
	KillTimerSafe(gPeriodRestartTimer);
	KillTimerSafe(gUnpauseTimer);
	KillTimerSafe(gStoppageTimer);
	KillTimerSafe(gShootoutTimer);
	KillPenaltyTimer();
	gUnpausing = false;
	gUnpauseSecondsLeft = 0;
}

void KillTimerSafe(Handle &timer)
{
	if (timer != null)
	{
		KillTimer(timer);
		timer = null;
	}
}

void StopTrainingCannon()
{
	KillTimerSafe(gTrainingCannonTimer);
	gTrainingCannonSet = false;
	gTrainingCannonBallRef = INVALID_ENT_REFERENCE;
}

bool IsSoccerAvailable()
{
	return gCvarEnabled.BoolValue && gMapAllowed;
}

bool CheckSoccerAvailable(int client)
{
	if (!gMapAllowed)
	{
		ReplyToCommand(client, "%t", "Map_Not_Allowed");
		return false;
	}

	if (!gCvarEnabled.BoolValue)
	{
		ReplyToCommand(client, "%t", "Soccer_Disabled");
		return false;
	}

	return true;
}

void ApplyMapAllowedState()
{
	bool wasAllowed = gMapAllowed;
	gMapAllowed = IsCurrentMapAllowed();

	if (gMapAllowed)
	{
		if (!wasAllowed)
		{
			ResetEntityHooks();
		}
		PrecacheConfiguredModels();
		DiscoverSoccerEntities();
		return;
	}

	DisableSoccerForMap();
}

bool IsCurrentMapAllowed()
{
	char currentMap[PLATFORM_MAX_PATH];
	GetCurrentMap(currentMap, sizeof(currentMap));

	char raw[512];
	gCvarAllowedMaps.GetString(raw, sizeof(raw));
	TrimString(raw);
	if (raw[0] == '\0')
	{
		return false;
	}

	char patterns[32][64];
	int count = ExplodeString(raw, ",", patterns, sizeof(patterns), sizeof(patterns[]));
	for (int i = 0; i < count; i++)
	{
		TrimString(patterns[i]);
		if (patterns[i][0] == '\0')
		{
			continue;
		}

		if (strncmp(currentMap, patterns[i], strlen(patterns[i]), false) == 0)
		{
			return true;
		}
	}
	return false;
}

void DisableSoccerForMap()
{
	KillMatchTimers();
	KillStoppageTrigger();
	StopTrainingCannon();
	StopAllSprints();
	gMatchLive = false;
	gPaused = false;
	gUnpausing = false;
	gUnpauseSecondsLeft = 0;
	gInBreak = false;
	gKickoffActive = false;
	gKickoffFrozen = false;
	gRestartingPeriod = false;
	gStoppageActive = false;
	gInitialRestartPending = false;
	gPenaltyShooter = 0;
	gPenaltyGoalkeeper = 0;
	UnfreezeAllPlayers();
	for (int client = 1; client <= MaxClients; client++)
	{
		RestorePlayerDamage(client);
	}
	ClearMatchRuntimeState();
	ResetEntityHooks();
	ClearBallEntity();
	// Once their refs are dropped leftover props would pass for the match ball.
	KillAllTrainingBalls();
	gTrainingGoalsDisabled = false;
	gTrainingCannonBallRef = INVALID_ENT_REFERENCE;
	gTrainingCannonOriginSet = false;
	gTrainingCannonTargetSet = false;
	gTrainingCannonSet = false;
	gMapAllowed = false;
}

void DiscoverSoccerEntities()
{
	if (!gMapAllowed)
	{
		return;
	}

	ClearBallEntity();
	int maxEntities = GetMaxEntities();
	for (int entity = MaxClients + 1; entity < maxEntities; entity++)
	{
		if (IsValidEntity(entity))
		{
			HookSoccerEntity(entity);
			if (gBallEnt == -1 && IsBallEntity(entity))
			{
				SetBallEntity(entity);
			}
		}
	}
}

void CacheBallStartPosition()
{
	gBallStartPositionValid = false;
	int ball = GetTrackedBallEntity();
	if (ball == -1)
	{
		FindBallEntity();
		ball = GetTrackedBallEntity();
	}

	if (ball != -1 && IsValidEntity(ball))
	{
		GetEntPropVector(ball, Prop_Send, "m_vecOrigin", gBallStartPosition);
		gBallStartPositionValid = true;
	}
}

void HookSoccerEntity(int entity)
{
	if (entity <= 0 || entity >= sizeof(gHookedEntity) || gHookedEntity[entity])
	{
		return;
	}

	if (IsBallEntity(entity))
	{
		gHookedEntity[entity] = true;
		SetBallEntity(entity);
	}
}

void ResetEntityHooks()
{
	for (int entity = 0; entity < sizeof(gHookedEntity); entity++)
	{
		gHookedEntity[entity] = false;
	}
}

bool IsBallEntity(int entity)
{
	if (!IsValidEntity(entity))
	{
		return false;
	}
	// The training ball shares the "ball" targetname so map clip brushes treat it
	// the same, but it must never be taken for the match ball.
	if (IsTrainingBall(entity))
	{
		return false;
	}
	char expected[MAX_ENTITY_NAME];
	gCvarBallName.GetString(expected, sizeof(expected));
	if (EntityTargetNameEquals(entity, expected))
	{
		return true;
	}
	return EntityTargetNameEquals(entity, "ballon");
}

bool EntityTargetNameEquals(int entity, const char[] expected)
{
	if (expected[0] == '\0')
	{
		return false;
	}

	char name[MAX_ENTITY_NAME];
	GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));
	return StrEqual(name, expected, false);
}

void ClearBallEntity()
{
	gBallEnt = -1;
	gBallRef = INVALID_ENT_REFERENCE;
}

void SetBallEntity(int entity)
{
	gBallEnt = entity;
	gBallRef = EntIndexToEntRef(entity);
}

int GetTrackedBallEntity()
{
	int entity = EntRefToEntIndex(gBallRef);
	if (entity != INVALID_ENT_REFERENCE && IsValidEntity(entity))
	{
		gBallEnt = entity;
		return entity;
	}

	ClearBallEntity();
	return -1;
}

void FindBallEntity()
{
	if (!gMapAllowed)
	{
		ClearBallEntity();
		return;
	}

	ClearBallEntity();
	int maxEntities = GetMaxEntities();
	for (int entity = MaxClients + 1; entity < maxEntities; entity++)
	{
		if (IsValidEntity(entity) && IsBallEntity(entity))
		{
			SetBallEntity(entity);
			HookSoccerEntity(entity);
			return;
		}
	}
}

void FreezeAllPlayers()
{
	FreezeSoccerPhysics();
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidClient(client) && IsPlayerAlive(client))
		{
			SetEntityMoveType(client, MOVETYPE_NONE);
		}
	}
}

void UnfreezeAllPlayers()
{
	bool keepFrozen = ShouldFreezePlayers();
	if (!keepFrozen)
	{
		UnfreezeSoccerPhysics();
	}

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidClient(client) && IsPlayerAlive(client) && !gRedCard[client])
		{
			SetEntityMoveType(client, keepFrozen ? MOVETYPE_NONE : MOVETYPE_WALK);
		}
	}
}

bool ShouldFreezePlayers()
{
	return gKickoffFrozen || gPaused || gUnpausing || gInBreak || gRestartingPeriod;
}

void FreezeSoccerPhysics()
{
	ConVar physTimescale = FindConVar("phys_timescale");
	ConVar physPushscale = FindConVar("phys_pushscale");
	if (!gPhysicsFrozen)
	{
		if (physTimescale != null)
		{
			gSavedPhysTimescale = physTimescale.FloatValue;
		}
		if (physPushscale != null)
		{
			gSavedPhysPushscale = physPushscale.FloatValue;
		}
		gPhysicsFrozen = true;
	}

	if (physTimescale != null)
	{
		physTimescale.SetFloat(0.0);
	}
	if (physPushscale != null)
	{
		physPushscale.SetFloat(1.0);
	}
}

void UnfreezeSoccerPhysics()
{
	if (!gPhysicsFrozen)
	{
		return;
	}

	ConVar physTimescale = FindConVar("phys_timescale");
	ConVar physPushscale = FindConVar("phys_pushscale");
	if (physTimescale != null)
	{
		physTimescale.SetFloat(gSavedPhysTimescale);
	}
	if (physPushscale != null)
	{
		physPushscale.SetFloat(gSavedPhysPushscale);
	}
	gPhysicsFrozen = false;
}

void ApplyPlayerFreezeState(int client)
{
	if (!IsValidClient(client) || !IsPlayerAlive(client) || gRedCard[client])
	{
		return;
	}

	SetEntityMoveType(client, ShouldFreezePlayers() ? MOVETYPE_NONE : MOVETYPE_WALK);
}

void HookPlayerDamage(int client)
{
	if (client < 1 || client > MaxClients)
	{
		return;
	}

	SDKUnhook(client, SDKHook_OnTakeDamage, HookPlayerTakeDamage);
	SDKUnhook(client, SDKHook_TraceAttack, HookPlayerTraceAttack);
	SDKHook(client, SDKHook_OnTakeDamage, HookPlayerTakeDamage);
	SDKHook(client, SDKHook_TraceAttack, HookPlayerTraceAttack);
}

void UnhookPlayerDamage(int client)
{
	if (client < 1 || client > MaxClients)
	{
		return;
	}

	SDKUnhook(client, SDKHook_OnTakeDamage, HookPlayerTakeDamage);
	SDKUnhook(client, SDKHook_TraceAttack, HookPlayerTraceAttack);
}

void ApplyPlayerDamageRules(int client)
{
	if (IsValidClient(client) && IsPlayerAlive(client) && GetClientTeam(client) >= TEAM_T)
	{
		SetEntProp(client, Prop_Send, "m_iHealth", 100);
		SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
	}
}

void RestorePlayerDamage(int client)
{
	if (IsValidClient(client) && IsPlayerAlive(client))
	{
		SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
	}
}

public Action HookPlayerTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!IsSoccerAvailable() || !IsValidClient(victim) || GetClientTeam(victim) < TEAM_T)
	{
		return Plugin_Continue;
	}

	if (IsValidClient(attacker))
	{
		damage = 0.0;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action HookPlayerTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	if (!IsSoccerAvailable() || !IsValidClient(victim) || GetClientTeam(victim) < TEAM_T)
	{
		return Plugin_Continue;
	}

	if (IsValidClient(attacker))
	{
		damage = 0.0;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

void SetDraftCaptains(int captainT, int captainCT)
{
	gDraftCaptainT = captainT;
	gDraftCaptainCT = captainCT;
	gDraftCaptainCount = 2;
	gDraftCaptains[0] = captainT;
	gDraftCaptains[1] = captainCT;
	gDraftCaptains[2] = 0;
	gDraftCaptains[3] = 0;
}

void StartDraft()
{
	StartDraftWithSettings(0, 2, 0);
}

bool StartDraftWithSettings(int requester, int captainCount, int teamSize)
{
	if (captainCount < 2 || captainCount > DRAFT_MAX_CAPTAINS)
	{
		if (IsValidClient(requester))
		{
			PrintToChat(requester, "%t", "Draft_CaptainCount_Custom_Invalid");
		}
		return false;
	}

	if (!ResolveDraftCaptains(captainCount))
	{
		if (IsValidClient(requester))
		{
			PrintToChat(requester, "%t", "Draft_Not_Enough_Captains");
		}
		return false;
	}

	ShuffleDraftCaptains();
	return BeginDraftWithCurrentCaptains(teamSize);
}

bool StartDraftWithSelectedCaptains(int requester, int teamSize)
{
	int captainCount = gDraftSetupCaptainCount[requester];
	if (captainCount < 2 || captainCount > DRAFT_MAX_CAPTAINS || gDraftSelectedCaptainCount[requester] < captainCount)
	{
		PrintToChat(requester, "%t", "Draft_Invalid_Captains");
		ShowDraftCaptainSelectMenu(requester);
		return false;
	}

	for (int i = 0; i < captainCount; i++)
	{
		int captain = gDraftSelectedCaptains[requester][i];
		if (!IsValidClient(captain) || IsFakeClient(captain))
		{
			PrintToChat(requester, "%t", "Draft_Invalid_Captains");
			BeginDraftCaptainSelection(requester);
			return false;
		}
		gDraftCaptains[i] = captain;
	}

	for (int i = captainCount; i < DRAFT_MAX_CAPTAINS; i++)
	{
		gDraftCaptains[i] = 0;
	}

	gDraftCaptainCount = captainCount;
	ShuffleDraftCaptains();
	bool started = BeginDraftWithCurrentCaptains(teamSize);
	if (started)
	{
		ClearDraftCaptainSelection(requester);
		gDraftSetupCaptainCount[requester] = 0;
	}
	return started;
}

bool BeginDraftWithCurrentCaptains(int teamSize)
{
	gDraftActive = true;
	gDraftTeamSize = teamSize;
	gDraftCurrentGroup = 1;
	gDraftPickCount = 0;

	for (int client = 1; client <= MaxClients; client++)
	{
		gDraftPicked[client] = false;
		gDraftTeam[client] = 0;
		gDraftGroup[client] = 0;
	}

	for (int i = 0; i < gDraftCaptainCount; i++)
	{
		AssignDraftGroupPlayer(gDraftCaptains[i], i + 1);
	}

	PrintToChatAll("%t", "Draft_Started_First", gDraftCaptains[0]);
	OpenNextDraftPickMenu(false);
	return true;
}

bool ResolveDraftCaptains(int captainCount)
{
	int count;
	for (int i = 0; i < DRAFT_MAX_CAPTAINS; i++)
	{
		gDraftCaptains[i] = 0;
	}

	AddDraftCaptainCandidate(gDraftCaptainT, count);
	AddDraftCaptainCandidate(gDraftCaptainCT, count);

	for (int client = 1; client <= MaxClients && count < captainCount; client++)
	{
		if (IsValidClient(client) && !IsFakeClient(client) && GetClientTeam(client) >= TEAM_T)
		{
			AddDraftCaptainCandidate(client, count);
		}
	}

	for (int client = 1; client <= MaxClients && count < captainCount; client++)
	{
		if (IsValidClient(client) && !IsFakeClient(client))
		{
			AddDraftCaptainCandidate(client, count);
		}
	}

	if (count < captainCount)
	{
		return false;
	}

	gDraftCaptainCount = captainCount;
	gDraftCaptainT = gDraftCaptains[0];
	gDraftCaptainCT = gDraftCaptains[1];
	return true;
}

void ShuffleDraftCaptains()
{
	for (int i = 0; i < gDraftCaptainCount - 1; i++)
	{
		int swapIndex = GetRandomInt(i, gDraftCaptainCount - 1);
		if (swapIndex == i)
		{
			continue;
		}

		int captain = gDraftCaptains[i];
		gDraftCaptains[i] = gDraftCaptains[swapIndex];
		gDraftCaptains[swapIndex] = captain;
	}

	gDraftCaptainT = gDraftCaptains[0];
	gDraftCaptainCT = gDraftCaptains[1];
}

bool AddDraftCaptainCandidate(int client, int &count)
{
	if (count >= DRAFT_MAX_CAPTAINS || !IsValidClient(client) || IsFakeClient(client))
	{
		return false;
	}

	for (int i = 0; i < count; i++)
	{
		if (gDraftCaptains[i] == client)
		{
			return false;
		}
	}

	gDraftCaptains[count] = client;
	count++;
	return true;
}

bool IsDraftCaptainSelectable(int admin, int target)
{
	return IsValidClient(target)
		&& !IsFakeClient(target)
		&& !IsDraftSetupCaptainSelected(admin, target);
}

bool IsDraftSetupCaptainSelected(int admin, int target)
{
	if (admin < 1 || admin > MaxClients)
	{
		return false;
	}

	for (int i = 0; i < gDraftSelectedCaptainCount[admin]; i++)
	{
		if (gDraftSelectedCaptains[admin][i] == target)
		{
			return true;
		}
	}
	return false;
}

void ClearDraftCaptainSelection(int client)
{
	if (client < 1 || client > MaxClients)
	{
		return;
	}

	gDraftSelectedCaptainCount[client] = 0;
	for (int i = 0; i < DRAFT_MAX_CAPTAINS; i++)
	{
		gDraftSelectedCaptains[client][i] = 0;
	}
}

void RemoveDraftSetupCaptain(int admin, int target)
{
	if (admin < 1 || admin > MaxClients || target <= 0)
	{
		return;
	}

	int count = gDraftSelectedCaptainCount[admin];
	for (int i = 0; i < count; i++)
	{
		if (gDraftSelectedCaptains[admin][i] != target)
		{
			continue;
		}

		for (int j = i; j < count - 1; j++)
		{
			gDraftSelectedCaptains[admin][j] = gDraftSelectedCaptains[admin][j + 1];
		}
		gDraftSelectedCaptains[admin][count - 1] = 0;
		gDraftSelectedCaptainCount[admin] = count - 1;
		return;
	}
}

void StartDefaultCaptainDraft()
{
	if (!gCvarCaptainModeDefault.BoolValue || gDraftActive)
	{
		return;
	}

	if (!IsValidClient(gDraftCaptainT) || !IsValidClient(gDraftCaptainCT))
	{
		SetDraftCaptains(FindFirstTeamClient(TEAM_T), FindFirstTeamClient(TEAM_CT));
	}

	if (IsValidClient(gDraftCaptainT) && IsValidClient(gDraftCaptainCT) && gDraftCaptainT != gDraftCaptainCT)
	{
		StartDraft();
	}
}

void AssignDraftGroupPlayer(int client, int group)
{
	if (!IsValidClient(client))
	{
		return;
	}

	gDraftPicked[client] = true;
	gDraftGroup[client] = group;
}

bool IsCurrentDraftCaptain(int client)
{
	return IsValidDraftGroup(gDraftCurrentGroup)
		&& IsValidClient(client)
		&& client == gDraftCaptains[gDraftCurrentGroup - 1];
}

void ShowDraftPickMenu(int client)
{
	if (!gDraftActive)
	{
		PrintToChat(client, "%t", "Draft_Not_Active");
		return;
	}

	if (!IsCurrentDraftCaptain(client))
	{
		char groupName[32];
		FormatDraftGroupName(client, gDraftCurrentGroup, groupName, sizeof(groupName));
		PrintToChat(client, "%t", "Draft_Current_Pick", groupName);
		return;
	}

	Menu menu = new Menu(MenuHandlerDraftPick);
	char groupName[32];
	FormatDraftGroupName(client, gDraftCurrentGroup, groupName, sizeof(groupName));
	char title[128];
	Format(title, sizeof(title), "%T", "Menu_DraftPick_Team_Title", client, groupName);
	menu.SetTitle(title);

	char userid[16];
	char display[MAX_NAME_LENGTH + 16];
	int available;
	for (int target = 1; target <= MaxClients; target++)
	{
		if (IsDraftEligible(target))
		{
			IntToString(GetClientUserId(target), userid, sizeof(userid));
			Format(display, sizeof(display), "%N", target);
			menu.AddItem(userid, display);
			available++;
		}
	}

	if (available == 0)
	{
		delete menu;
		FinishDraft();
		return;
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandlerDraftPick(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action == MenuAction_Select && IsValidClient(client))
	{
		char info[16];
		menu.GetItem(item, info, sizeof(info));
		int target = GetClientOfUserId(StringToInt(info));
		DraftPick(client, target);
	}
	return 0;
}

bool IsDraftEligible(int client)
{
	return IsValidClient(client) && !gDraftPicked[client] && !IsFakeClient(client) && !gRedCard[client];
}

void DraftPick(int captain, int target)
{
	if (!IsCurrentDraftCaptain(captain) || !IsDraftEligible(target))
	{
		PrintToChat(captain, "%t", "Draft_Invalid_Pick");
		if (IsCurrentDraftCaptain(captain))
		{
			ShowDraftPickMenu(captain);
		}
		return;
	}

	int group = gDraftCurrentGroup;
	AssignDraftGroupPlayer(target, group);
	PrintToChatAll("%t", "Draft_Player_Picked", captain, target, group);

	gDraftPickCount++;

	if (IsDraftComplete())
	{
		FinishDraft();
		return;
	}

	OpenNextDraftPickMenu(true);
}

void OpenNextDraftPickMenu(bool announce)
{
	int attempts = MaxClients + (DRAFT_MAX_CAPTAINS * 2);
	for (int i = 0; i < attempts; i++)
	{
		gDraftCurrentGroup = GetNextDraftGroup(gDraftPickCount);
		if (CanDraftGroupPick(gDraftCurrentGroup))
		{
			int nextCaptain = gDraftCaptains[gDraftCurrentGroup - 1];
			if (announce)
			{
				PrintToChatAll("%t", "Draft_Next_Pick", nextCaptain);
			}
			ShowDraftPickMenu(nextCaptain);
			return;
		}

		gDraftPickCount++;
		if (IsDraftComplete())
		{
			break;
		}
	}

	FinishDraft();
}

int GetNextDraftGroup(int pickCount)
{
	int captainCount = gDraftCaptainCount;
	if (captainCount < 2)
	{
		captainCount = 2;
	}

	int phase = pickCount % (captainCount * 2);
	if (phase < captainCount)
	{
		return phase + 1;
	}
	return (captainCount * 2) - phase;
}

bool CanDraftGroupPick(int group)
{
	return IsValidDraftGroup(group)
		&& HasDraftEligiblePlayers()
		&& (gDraftTeamSize <= 0 || CountDraftGroupPlayers(group) < gDraftTeamSize);
}

bool IsDraftComplete()
{
	if (!HasDraftEligiblePlayers())
	{
		return true;
	}

	if (gDraftTeamSize <= 0)
	{
		return false;
	}

	for (int group = 1; group <= gDraftCaptainCount; group++)
	{
		if (CountDraftGroupPlayers(group) < gDraftTeamSize)
		{
			return false;
		}
	}
	return true;
}

bool HasDraftEligiblePlayers()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsDraftEligible(client))
		{
			return true;
		}
	}
	return false;
}

bool IsValidDraftGroup(int group)
{
	return group >= 1 && group <= gDraftCaptainCount && group <= DRAFT_MAX_CAPTAINS;
}

bool IsDraftCaptain(int client)
{
	for (int i = 0; i < DRAFT_MAX_CAPTAINS; i++)
	{
		if (gDraftCaptains[i] == client)
		{
			return true;
		}
	}
	return false;
}

int CountDraftGroupPlayers(int group)
{
	int count;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (gDraftGroup[client] == group)
		{
			count++;
		}
	}
	return count;
}

void FinishDraft()
{
	if (!gDraftActive)
	{
		return;
	}

	PrintDraftGroupsToAll();
	AssignRandomDraftGroupsToTeams();
	gDraftActive = false;
	PrintToChatAll("%t", "Draft_Finished");
}

void CancelDraft(bool announce)
{
	if (!gDraftActive)
	{
		return;
	}

	gDraftActive = false;
	gDraftCurrentGroup = 0;
	gDraftPickCount = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		gDraftPicked[client] = false;
		gDraftGroup[client] = 0;
	}

	if (announce)
	{
		PrintToChatAll("%t", "Draft_Cancelled");
	}
}

void AssignRandomDraftGroupsToTeams()
{
	if (gDraftCaptainCount < 2)
	{
		return;
	}

	int groupCT = GetRandomInt(1, gDraftCaptainCount);
	int groupT = GetRandomInt(1, gDraftCaptainCount);
	while (groupT == groupCT)
	{
		groupT = GetRandomInt(1, gDraftCaptainCount);
	}

	char groupCTName[32];
	char groupTName[32];
	FormatDraftGroupName(LANG_SERVER, groupCT, groupCTName, sizeof(groupCTName));
	FormatDraftGroupName(LANG_SERVER, groupT, groupTName, sizeof(groupTName));
	PrintToChatAll("%t", "Draft_Assigned_To_Teams", groupCTName, groupTName);

	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsValidClient(client) || gDraftGroup[client] <= 0)
		{
			continue;
		}

		int team = 1;
		if (gDraftGroup[client] == groupCT)
		{
			team = TEAM_CT;
		}
		else if (gDraftGroup[client] == groupT)
		{
			team = TEAM_T;
		}

		gDraftTeam[client] = team >= TEAM_T ? team : 0;
		if (GetClientTeam(client) != team)
		{
			ChangeClientTeam(client, team);
		}
		if (team >= TEAM_T && !IsPlayerAlive(client))
		{
			CS_RespawnPlayer(client);
		}
	}
}

void PrintDraftGroupsToAll()
{
	PrintToChatAll("%t", "Draft_Groups_Title");
	for (int group = 1; group <= gDraftCaptainCount; group++)
	{
		char members[256];
		FormatDraftGroupMembers(group, members, sizeof(members));
		PrintToChatAll("%t", "Draft_Show_Group", group, members);
	}
}

void PrintDraftGroupsToClient(int client)
{
	if (!IsValidClient(client) || gDraftCaptainCount <= 0)
	{
		return;
	}

	PrintToChat(client, "%t", "Draft_Groups_Title");
	for (int group = 1; group <= gDraftCaptainCount; group++)
	{
		char members[256];
		FormatDraftGroupMembers(group, members, sizeof(members));
		PrintToChat(client, "%t", "Draft_Show_Group", group, members);
	}
}

void FormatDraftGroupMembers(int group, char[] buffer, int maxlen)
{
	buffer[0] = '\0';
	for (int client = 1; client <= MaxClients; client++)
	{
		if (gDraftGroup[client] != group || !IsValidClient(client))
		{
			continue;
		}

		char current[256];
		strcopy(current, sizeof(current), buffer);
		Format(buffer, maxlen, "%s%s%N", current, current[0] == '\0' ? "" : ", ", client);
	}

	if (buffer[0] == '\0')
	{
		Format(buffer, maxlen, "%T", "Client_None", LANG_SERVER);
	}
}

void FormatDraftGroupName(int viewer, int group, char[] buffer, int maxlen)
{
	Format(buffer, maxlen, "%T", "Draft_Group_Generic", viewer, group);
}

void ShowDraftStatus(int client)
{
	char captainT[MAX_NAME_LENGTH];
	char captainCT[MAX_NAME_LENGTH];
	FormatClientNameOrNone(client, gDraftCaptainT, captainT, sizeof(captainT));
	FormatClientNameOrNone(client, gDraftCaptainCT, captainCT, sizeof(captainCT));
	char state[32];
	Format(state, sizeof(state), "%T", gDraftActive ? "State_Active" : "State_Inactive", client);
	char nextGroup[32];
	FormatDraftGroupName(client, gDraftCurrentGroup, nextGroup, sizeof(nextGroup));
	ReplyToCommand(client, "%t", "Draft_Status_Clean", state, captainT, captainCT, nextGroup);
}

bool StartPenalty(int team, int shooter, int goalkeeper, bool fromShootout = false)
{
	if (!IsSoccerAvailable())
	{
		return false;
	}

	// A manual penalty during a shootout would take the place of the next kick.
	if (gPenaltyActive || (gShootoutActive && !fromShootout))
	{
		PrintToChatAll("%t", "Penalty_Already_Active");
		return false;
	}

	// In a match a penalty is given while the ball is in play, not after a goal,
	// in a break or around a restart, whose new round would undo the placement.
	if (gMatchLive && !fromShootout && (gRoundEnded || gKickoffQueued || gInBreak || gRestartingPeriod))
	{
		PrintToChatAll("%t", "Penalty_Not_Now");
		return false;
	}

	if (!gPenaltySpotValid)
	{
		FindBallEntity();
		int ball = GetTrackedBallEntity();
		if (ball != -1)
		{
			GetEntPropVector(ball, Prop_Send, "m_vecOrigin", gPenaltySpot);
			gPenaltySpotValid = true;
		}
	}

	if (!gPenaltySpotValid)
	{
		PrintToChatAll("%t", "Penalty_Spot_Reminder");
		return false;
	}

	if (!IsValidClient(shooter))
	{
		shooter = FindFirstTeamClient(team);
	}
	else if (GetClientTeam(shooter) != team)
	{
		PrintToChatAll("%t", "Penalty_Need_Players");
		return false;
	}
	if (!IsValidClient(goalkeeper))
	{
		goalkeeper = FindTeamGoalkeeper(team == TEAM_CT ? TEAM_T : TEAM_CT);
	}
	else if (GetClientTeam(goalkeeper) == team || GetClientTeam(goalkeeper) < TEAM_T)
	{
		goalkeeper = 0;
	}
	if (!IsValidClient(shooter))
	{
		PrintToChatAll("%t", "Penalty_Need_Players");
		return false;
	}

	gPenaltyActive = true;
	gPenaltyWaitingForKick = true;
	ClearLastSave();
	gPenaltyKickSpotOriented = GetPenaltyKickSpot(team, gPenaltyKickSpot);
	if (gMatchLive && !fromShootout)
	{
		// The penalty replaces a kickoff still waiting, and the clock waits for
		// the kick as it would for that kickoff.
		if (gKickoffActive)
		{
			EndKickoff();
		}
		StopPeriodClock();
		StopStoppageClock();
	}
	gPenaltyTeam = team;
	gPenaltyShooter = shooter;
	gPenaltyGoalkeeper = goalkeeper;

	float shooterPos[3];
	float shooterAngles[3];
	GetPenaltyShooterPlacement(shooterPos, shooterAngles);
	TeleportEntity(shooter, shooterPos, shooterAngles, NULL_VECTOR);

	if (IsValidClient(goalkeeper))
	{
		SetPosition(goalkeeper, SoccerPosition_Goalkeeper);
	}

	FindBallEntity();
	int ball = GetTrackedBallEntity();
	if (ball != -1)
	{
		PlaceBallAtRest(ball, gPenaltyKickSpot);
	}

	KillPenaltyTimer();
	gPenaltyTimer = CreateTimer(gCvarPenaltyShotTime.FloatValue, TimerPenaltyTimeout, _, TIMER_FLAG_NO_MAPCHANGE);
	char teamName[16];
	GetTeamNameServer(team, teamName, sizeof(teamName));
	if (IsValidClient(gPenaltyGoalkeeper))
	{
		PrintToChatAll("%t", "Penalty_Turn", gPenaltyShooter, gPenaltyGoalkeeper, teamName);
	}
	else
	{
		PrintToChatAll("%t", "Penalty_Turn_NoGk", gPenaltyShooter, teamName);
	}
	PlayPenaltyTurnSound(gPenaltyShooter);
	return true;
}

// One spot serves both teams: each kick is taken at the end of the goal the shooting
// team attacks, the one the other team defends. That end is found from the defending
// team's goalkeeper area, or else from where its players spawn. Returns whether the
// end could be told apart; if not, the stored spot is used as it is.
bool GetPenaltyKickSpot(int team, float spot[3])
{
	spot = gPenaltySpot;
	float defended[3];
	if (!gBallStartPositionValid || !GetTeamGoalReference(GetOppositeTeam(team), defended))
	{
		return false;
	}

	float mirrored[3];
	mirrored[0] = 2.0 * gBallStartPosition[0] - gPenaltySpot[0];
	mirrored[1] = 2.0 * gBallStartPosition[1] - gPenaltySpot[1];
	mirrored[2] = gPenaltySpot[2];
	if (GetFlatDistance(mirrored, defended) < GetFlatDistance(gPenaltySpot, defended))
	{
		spot = mirrored;
	}
	return true;
}

bool GetTeamGoalReference(int team, float point[3])
{
	int area = GetTeamGkArea(team);
	if (area != -1 && gGkAreaValid[area])
	{
		for (int axis = 0; axis < 3; axis++)
		{
			point[axis] = (gGkAreaMin[area][axis] + gGkAreaMax[area][axis]) / 2.0;
		}
		return true;
	}

	char classname[32];
	strcopy(classname, sizeof(classname), team == TEAM_CT ? "info_player_counterterrorist" : "info_player_terrorist");
	float sum[3];
	int count;
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, classname)) != -1)
	{
		float origin[3];
		GetEntPropVector(entity, Prop_Data, "m_vecOrigin", origin);
		AddVectors(sum, origin, sum);
		count++;
	}
	if (count == 0)
	{
		return false;
	}
	ScaleVector(sum, 1.0 / float(count));
	point = sum;
	return true;
}

float GetFlatDistance(const float a[3], const float b[3])
{
	float dx = a[0] - b[0];
	float dy = a[1] - b[1];
	return SquareRoot(dx * dx + dy * dy);
}

// The attacked goal is whichever end the kick spot sits on, so the direction from
// the centre of the pitch to the spot points straight at it. The shooter stands that
// far behind the ball, facing the goal. Without a usable centre we keep the old fixed
// offset so nothing breaks on maps where the ball origin was never cached.
void GetPenaltyShooterPlacement(float position[3], float angles[3])
{
	float toGoal[3];
	toGoal[0] = 0.0;
	toGoal[1] = 0.0;
	toGoal[2] = 0.0;
	if (gBallStartPositionValid)
	{
		toGoal[0] = gPenaltyKickSpot[0] - gBallStartPosition[0];
		toGoal[1] = gPenaltyKickSpot[1] - gBallStartPosition[1];
	}

	position[0] = gPenaltyKickSpot[0];
	position[1] = gPenaltyKickSpot[1];
	position[2] = gPenaltyKickSpot[2];

	if (NormalizeVector(toGoal, toGoal) <= 0.0)
	{
		position[0] -= PENALTY_SHOOTER_DISTANCE;
		angles[0] = 0.0;
		angles[1] = 0.0;
		angles[2] = 0.0;
		return;
	}

	position[0] -= toGoal[0] * PENALTY_SHOOTER_DISTANCE;
	position[1] -= toGoal[1] * PENALTY_SHOOTER_DISTANCE;
	GetVectorAngles(toGoal, angles);
}

void ResolvePenalty(bool scored)
{
	if (!gPenaltyActive)
	{
		return;
	}

	KillPenaltyTimer();
	PrintToChatAll("%t", scored ? "Penalty_Goal" : "Penalty_Miss", gPenaltyShooter);
	if (IsMatchPenalty())
	{
		EndMatchPenalty();
		return;
	}
	if (gShootoutActive)
	{
		if (gPenaltyTeam == TEAM_CT)
		{
			gShootoutTakenCT++;
			if (scored)
			{
				gShootoutScoreCT++;
			}
		}
		else
		{
			gShootoutTakenT++;
			if (scored)
			{
				gShootoutScoreT++;
			}
		}
		PrintToChatAll("%t", "Penalty_Score", gShootoutScoreCT, gShootoutScoreT);
	}
	gPenaltyActive = false;
	gPenaltyWaitingForKick = false;
	gPenaltyShooter = 0;
	gPenaltyGoalkeeper = 0;
	if (gShootoutActive)
	{
		KillTimerSafe(gShootoutTimer);
		if (gRoundEnded)
		{
			// A goal ends the round, and the restart would undo any placement made
			// before it. The next kick is set up from round_start instead.
			gShootoutWaitingRoundStart = true;
		}
		else
		{
			gShootoutTimer = CreateTimer(gCvarPenaltyShotDelay.FloatValue, TimerNextShootoutPenalty, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

void StartShootout()
{
	if (!IsSoccerAvailable())
	{
		return;
	}

	if (!IsValidClient(FindFirstTeamClient(TEAM_CT)) || !IsValidClient(FindFirstTeamClient(TEAM_T)))
	{
		PrintToChatAll("%t", "Penalty_Need_Players");
		return;
	}

	if (gPenaltyActive || gShootoutActive)
	{
		PrintToChatAll("%t", "Penalty_Already_Active");
		return;
	}

	KillPenaltyTimer();
	KillTimerSafe(gShootoutTimer);
	gShootoutWaitingRoundStart = false;
	gShootoutActive = true;
	gPenaltyActive = false;
	gShootoutScoreCT = 0;
	gShootoutScoreT = 0;
	gShootoutTakenCT = 0;
	gShootoutTakenT = 0;
	gShootoutShooterIndexCT = 0;
	gShootoutShooterIndexT = 0;
	gShootoutNextTeam = TEAM_CT;
	PrintToChatAll("%t", "Penalty_Shootout_Start");
	StartNextShootoutPenalty();
}

public Action TimerNextShootoutPenalty(Handle timer)
{
	gShootoutTimer = null;
	StartNextShootoutPenalty();
	return Plugin_Stop;
}

void StartNextShootoutPenalty()
{
	if (!gShootoutActive)
	{
		return;
	}

	if (IsShootoutDecided())
	{
		FinishShootout();
		return;
	}

	int team = gShootoutNextTeam;
	int shooter = GetNextShootoutShooter(team);
	if (!IsValidClient(shooter))
	{
		FinishShootout();
		return;
	}

	gShootoutNextTeam = team == TEAM_CT ? TEAM_T : TEAM_CT;
	// Goalkeeper 0 lets StartPenalty pick the defending side's goalkeeper.
	if (!StartPenalty(team, shooter, 0, true))
	{
		FinishShootout();
	}
}

// The shootout is over as soon as one team leads by more than the other can still
// reach with the shots it is owed. Once both teams are past the regulation five and
// level on shots taken, "owed" is zero and this reduces to a plain score comparison.
bool IsShootoutDecided()
{
	int remainingCT = GetRemainingShootoutShots(gShootoutTakenCT, gShootoutTakenT);
	int remainingT = GetRemainingShootoutShots(gShootoutTakenT, gShootoutTakenCT);

	return gShootoutScoreCT > gShootoutScoreT + remainingT
		|| gShootoutScoreT > gShootoutScoreCT + remainingCT;
}

// Shots a team still has coming: whatever is left of the regulation five, or the
// shots it owes to match the opponent during sudden death, whichever is greater.
int GetRemainingShootoutShots(int taken, int takenByOpponent)
{
	int regulation = PENALTY_MAX_SHOTS - taken;
	int owed = takenByOpponent - taken;
	int remaining = regulation > owed ? regulation : owed;
	return remaining > 0 ? remaining : 0;
}

int GetNextShootoutShooter(int team)
{
	int start = team == TEAM_CT ? gShootoutShooterIndexCT : gShootoutShooterIndexT;
	for (int pass = 0; pass < 2; pass++)
	{
		for (int client = start + 1; client <= MaxClients; client++)
		{
			if (IsValidClient(client) && !IsFakeClient(client) && GetClientTeam(client) == team && !gRedCard[client])
			{
				if (team == TEAM_CT)
				{
					gShootoutShooterIndexCT = client;
				}
				else
				{
					gShootoutShooterIndexT = client;
				}
				return client;
			}
		}
		start = 0;
	}
	return 0;
}

void FinishShootout()
{
	gShootoutActive = false;
	gShootoutWaitingRoundStart = false;
	KillTimerSafe(gShootoutTimer);
	if (gShootoutScoreCT > gShootoutScoreT)
	{
		char teamName[16];
		GetTeamNameServer(TEAM_CT, teamName, sizeof(teamName));
		PrintToChatAll("%t", "Penalty_Winner", teamName);
	}
	else if (gShootoutScoreT > gShootoutScoreCT)
	{
		char teamName[16];
		GetTeamNameServer(TEAM_T, teamName, sizeof(teamName));
		PrintToChatAll("%t", "Penalty_Winner", teamName);
	}
	else
	{
		PrintToChatAll("%t", "Penalty_No_Winner");
	}
}

void KillPenaltyTimer()
{
	if (gPenaltyTimer != null)
	{
		KillTimer(gPenaltyTimer);
		gPenaltyTimer = null;
	}
}

// Prefers whoever took the goalkeeper position with !gk over the first player found.
int FindTeamGoalkeeper(int team)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidClient(client)
			&& GetClientTeam(client) == team
			&& !IsFakeClient(client)
			&& !gRedCard[client]
			&& gPosition[client] == SoccerPosition_Goalkeeper)
		{
			return client;
		}
	}
	return FindFirstTeamClient(team);
}

int FindFirstTeamClient(int team)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidClient(client) && GetClientTeam(client) == team && !IsFakeClient(client))
		{
			return client;
		}
	}
	return 0;
}

int ParseTeamArg(const char[] value)
{
	if (StrEqual(value, "ct", false))
	{
		return TEAM_CT;
	}
	if (StrEqual(value, "t", false))
	{
		return TEAM_T;
	}
	return 0;
}

int ParseJoinTeamArg(const char[] value)
{
	int team;
	if (value[0] != '\0' && StringToIntEx(value, team) == strlen(value))
	{
		return team;
	}
	return ParseTeamArg(value);
}

int CountLiveReplacements(int team, int ignoreClient)
{
	int replacements;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (client != ignoreClient
			&& IsValidClient(client)
			&& GetClientTeam(client) == team
			&& gDraftTeam[client] == 0
			&& !IsFakeClient(client))
		{
			replacements++;
		}
	}
	return replacements;
}

// Same rule as the game's auto-assign: the smaller side, random on a tie.
int GetAutoAssignTeam(int ignoreClient)
{
	int countT;
	int countCT;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (client == ignoreClient || !IsValidClient(client))
		{
			continue;
		}

		int team = GetClientTeam(client);
		if (team == TEAM_T)
		{
			countT++;
		}
		else if (team == TEAM_CT)
		{
			countCT++;
		}
	}

	if (countT == countCT)
	{
		return GetRandomKickoffTeam();
	}
	return countT < countCT ? TEAM_T : TEAM_CT;
}

void ClearDraftTeams()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		gDraftTeam[client] = 0;
	}
}

bool HasAssignedSoccerTeams()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (gDraftTeam[client] == TEAM_T || gDraftTeam[client] == TEAM_CT)
		{
			return true;
		}
	}
	return false;
}

bool ParseScoreValue(const char[] value, int &score)
{
	if (value[0] == '\0')
	{
		return false;
	}

	int parsed;
	int consumed = StringToIntEx(value, parsed);
	if (consumed != strlen(value) || parsed < 0)
	{
		return false;
	}

	score = parsed;
	return true;
}

int FindCommandTarget(int client, int argnum)
{
	char arg[64];
	GetCmdArg(argnum, arg, sizeof(arg));
	return FindTarget(client, arg, false, true);
}

void AddMenuItemPhrase(Menu menu, int client, const char[] info, const char[] phrase)
{
	char text[96];
	Format(text, sizeof(text), "%T", phrase, client);
	menu.AddItem(info, text);
}

void UpdateGameTeamScores()
{
	CS_SetTeamScore(TEAM_T, gScoreT);
	CS_SetTeamScore(TEAM_CT, gScoreCT);
	SetTeamScore(TEAM_T, gScoreT);
	SetTeamScore(TEAM_CT, gScoreCT);
}

void FormatKickoffTeamName(int client, int team, char[] buffer, int maxlen)
{
	Format(buffer, maxlen, "%T", team == TEAM_CT ? "Team_Blue" : "Team_Red", client);
}

void FormatColoredKickoffTeamName(int client, int team, char[] buffer, int maxlen)
{
	char teamName[32];
	char color[8];
	FormatKickoffTeamName(client, team, teamName, sizeof(teamName));
	FormatTeamColorPrefix(team, color, sizeof(color));
	Format(buffer, maxlen, "%s%s\x01", color, teamName);
}

void FormatTeamColorPrefix(int team, char[] buffer, int maxlen)
{
	if (maxlen <= 0)
	{
		return;
	}

	buffer[0] = '\0';
	if (maxlen < 2)
	{
		return;
	}

	buffer[0] = 0x07;
	buffer[1] = '\0';

	if (team == TEAM_CT)
	{
		StrCat(buffer, maxlen, "4AA3FF");
	}
	else
	{
		StrCat(buffer, maxlen, "FF4A4A");
	}
}

void GetTeamNameServer(int team, char[] buffer, int maxlen)
{
	Format(buffer, maxlen, "%T", team == TEAM_CT ? "Team_CT" : "Team_T", LANG_SERVER);
}

void FormatPositionName(int client, SoccerPosition position, char[] buffer, int maxlen)
{
	Format(buffer, maxlen, "%T", position == SoccerPosition_Goalkeeper ? "Skin_Goalkeeper" : "Skin_Player", client);
}

// The HUD line as the original soccermod showed it: "CT 1 - 0 T | 03:12", led
// by what holds play when something does ("Saca CT: CT 1 - 0 T | 03:12").
void FormatHudLine(int client, char[] buffer, int maxlen)
{
	char elapsed[16];
	char time[32];
	FormatDurationSeconds(GetPeriodElapsedSeconds(), elapsed, sizeof(elapsed));
	if (gStoppageActive && !gInBreak)
	{
		char stoppage[16];
		FormatDurationSeconds(gStoppageSeconds, stoppage, sizeof(stoppage));
		Format(time, sizeof(time), "%T", "State_Stoppage", client, elapsed, stoppage);
	}
	else
	{
		strcopy(time, sizeof(time), elapsed);
	}

	char state[64];
	if (gUnpausing)
	{
		Format(state, sizeof(state), "%T", "Resume_Center", client, gUnpauseSecondsLeft);
	}
	else if (gInBreak)
	{
		Format(state, sizeof(state), "%T", "State_Break", client, RoundToCeil(gBreakEndTime - GetGameTime()));
	}
	else if (gPaused)
	{
		Format(state, sizeof(state), "%T", "State_Paused", client);
	}
	else if (gKickoffActive)
	{
		Format(state, sizeof(state), "%T", "State_Kickoff", client, gKickoffTeam == TEAM_CT ? "CT" : "T");
	}
	else if (gOvertimeActive)
	{
		Format(state, sizeof(state), "%T", "State_Overtime", client);
	}

	if (state[0] == '\0')
	{
		Format(buffer, maxlen, "%T", "Hud_Match_Line", client, gScoreCT, gScoreT, time);
	}
	else
	{
		Format(buffer, maxlen, "%T", "Hud_Match_Line_State", client, state, gScoreCT, gScoreT, time);
	}
}

int GetPeriodElapsedSeconds()
{
	float elapsed = gMatchElapsed + gPeriodElapsed;
	if (gPeriodTimer != null && !gPaused)
	{
		elapsed = gMatchElapsed + gPeriodDuration - (gPeriodEndTime - GetGameTime());
	}
	if (elapsed < 0.0)
	{
		elapsed = 0.0;
	}
	return RoundToFloor(elapsed);
}

void FormatDurationSeconds(int seconds, char[] buffer, int maxlen)
{
	if (seconds < 0)
	{
		seconds = 0;
	}

	int minutes = seconds / 60;
	int remainingSeconds = seconds % 60;
	Format(buffer, maxlen, "%02d:%02d", minutes, remainingSeconds);
}

void FormatClientNameOrNone(int viewer, int client, char[] buffer, int maxlen)
{
	if (IsValidClient(client))
	{
		Format(buffer, maxlen, "%N", client);
	}
	else
	{
		Format(buffer, maxlen, "%T", "Client_None", viewer);
	}
}

// Sets a ball down on the floor under a point and puts it to sleep, as the map
// does with the match ball before kickoff: it stays still there, without
// falling or rolling, until someone touches it.
void PlaceBallAtRest(int ball, const float point[3])
{
	float position[3];
	position = point;

	float top[3];
	float bottom[3];
	top = point;
	bottom = point;
	top[2] += 48.0;
	bottom[2] -= 256.0;
	Handle trace = TR_TraceRayFilterEx(top, bottom, MASK_SOLID, RayType_EndPoint, TraceFilterNoPlayersOrEntity, ball);
	if (TR_DidHit(trace))
	{
		float floorPoint[3];
		TR_GetEndPosition(floorPoint, trace);
		float mins[3];
		GetEntPropVector(ball, Prop_Send, "m_vecMins", mins);
		position[2] = floorPoint[2] - mins[2] + 1.0;
	}
	delete trace;

	float still[3];
	TeleportEntity(ball, position, NULL_VECTOR, still);
	AcceptEntityInput(ball, "Sleep", -1, -1, 0);
}

public bool TraceFilterNoPlayersOrEntity(int entity, int contentsMask, any ignored)
{
	return entity > MaxClients && entity != ignored;
}

bool GetAimPosition(int client, float position[3])
{
	float start[3];
	float angles[3];
	GetClientEyePosition(client, start);
	GetClientEyeAngles(client, angles);

	Handle trace = TR_TraceRayFilterEx(start, angles, MASK_SOLID, RayType_Infinite, TraceFilterNoPlayers, client);
	bool hit = TR_DidHit(trace);
	if (hit)
	{
		TR_GetEndPosition(position, trace);
	}
	delete trace;
	return hit;
}

public bool TraceFilterNoPlayers(int entity, int contentsMask, any data)
{
	return entity > MaxClients;
}

void SetPosition(int client, SoccerPosition position)
{
	gPosition[client] = position;
	ApplySoccerModel(client);
}

SoccerPosition ParsePosition(const char[] value)
{
	if (StrEqual(value, "gk", false) || StrEqual(value, "goalkeeper", false) || StrEqual(value, "arquero", false))
	{
		return SoccerPosition_Goalkeeper;
	}
	return SoccerPosition_Player;
}

void ShowPosition(int client)
{
	char positionName[32];
	FormatPositionName(client, gPosition[client], positionName, sizeof(positionName));
	PrintToChat(client, "%t", "Position_Current", positionName);
}

void UpdateSprint(int client, bool wantsSprint)
{
	float interval = GetTickInterval();
	if (gPaused)
	{
		if (gSprinting[client])
		{
			StopSprint(client);
		}
		UpdateArmor(client);
		return;
	}

	// Frozen players (break, period restart) cannot run, so they recover.
	if (GetEntityMoveType(client) == MOVETYPE_NONE)
	{
		wantsSprint = false;
	}

	if (wantsSprint && gStamina[client] > 0.0)
	{
		if (!gSprinting[client])
		{
			StartSprint(client);
		}
		gStamina[client] -= gCvarStaminaDrain.FloatValue * interval;
		if (gStamina[client] <= 0.0)
		{
			gStamina[client] = 0.0;
			StopSprint(client);
		}
	}
	else
	{
		if (gSprinting[client])
		{
			StopSprint(client);
		}
		gStamina[client] += gCvarStaminaRegen.FloatValue * interval;
		if (gStamina[client] > 100.0)
		{
			gStamina[client] = 100.0;
		}
	}
	UpdateArmor(client);
}

void StartSprint(int client)
{
	gSprinting[client] = true;
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", gCvarSprintSpeed.FloatValue);
}

void StopSprint(int client)
{
	if (IsValidClient(client))
	{
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
	}
	gSprinting[client] = false;
}

void StopAllSprints()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		StopSprint(client);
	}
}

void UpdateArmor(int client)
{
	if (IsValidClient(client))
	{
		int armor = RoundToNearest(gStamina[client]);
		int currentArmor = GetEntProp(client, Prop_Send, "m_ArmorValue");
		if (gLastArmorValue[client] != armor || currentArmor != armor)
		{
			SetClientArmor(client, armor);
		}
	}
}

void ForceUpdateArmor(int client)
{
	if (IsValidClient(client))
	{
		SetClientArmor(client, RoundToNearest(gStamina[client]));
	}
}

void SetClientArmor(int client, int armor)
{
	SetEntProp(client, Prop_Send, "m_ArmorValue", armor);
	gLastArmorValue[client] = armor;
}

void ApplyRefereeAction(int target, int refereeAction)
{
	switch (refereeAction)
	{
		case REF_ACTION_YELLOW:
		{
			GiveYellowCard(target);
		}
		case REF_ACTION_RED:
		{
			GiveRedCard(target);
		}
		case REF_ACTION_CLEAR_PLAYER:
		{
			ClearPlayerCards(target);
			PrintToChatAll("%t", "Card_Cleared_Player", target);
		}
	}
}

void AdjustTeamScore(int admin, int team, int delta)
{
	int score = team == TEAM_CT ? gScoreCT : gScoreT;
	char teamName[16];
	GetColoredScoreTeamName(team, teamName, sizeof(teamName));

	if (delta < 0 && score <= 0)
	{
		PrintToChat(admin, "%t", "Score_Already_Zero", teamName);
		return;
	}

	if (team == TEAM_CT)
	{
		gScoreCT += delta;
	}
	else
	{
		gScoreT += delta;
	}

	UpdateGameTeamScores();
	PrintScoreDisplay();
	PrintToChatAll("%t", delta > 0 ? "Score_Goal_Added" : "Score_Goal_Removed", admin, teamName, gScoreCT, gScoreT);

	char auth[MAX_AUTH_ID_LENGTH];
	if (!GetClientAuthId(admin, AuthId_Steam2, auth, sizeof(auth), true))
	{
		auth[0] = '\0';
	}
	LogMessage("%N <%s> %s a goal for %s. Score: CT %d - %d TT", admin, auth, delta > 0 ? "added" : "removed", team == TEAM_CT ? "CT" : "TT", gScoreCT, gScoreT);
}

void GetColoredScoreTeamName(int team, char[] buffer, int maxlen)
{
	char color[16];
	FormatTeamColorPrefix(team, color, sizeof(color));
	Format(buffer, maxlen, "%s%s\x01", color, team == TEAM_CT ? "CT" : "TT");
}

void GiveYellowCard(int client)
{
	if (!IsValidClient(client))
	{
		return;
	}

	gYellowCards[client]++;
	PrintToChatAll("%t", "Card_Yellow", client, gYellowCards[client]);
	if (gYellowCards[client] >= 2)
	{
		GiveRedCard(client);
	}
}

void GiveRedCard(int client)
{
	if (!IsValidClient(client))
	{
		return;
	}

	RememberRedCardAuth(client);
	gRedCard[client] = true;
	StopSprint(client);
	PrintToChatAll("%t", "Card_Red", client);
	if (IsPlayerAlive(client))
	{
		RestorePlayerDamage(client);
		ForcePlayerSuicide(client, false);
	}
	ChangeClientTeam(client, 1);
}

void ClearPlayerCards(int target)
{
	gYellowCards[target] = 0;
	gRedCard[target] = false;
	RemoveRedCardAuth(target);
}

void ClearAllCards()
{
	ClearRedCardAuths();
	for (int client = 1; client <= MaxClients; client++)
	{
		gYellowCards[client] = 0;
		gRedCard[client] = false;
	}
	PrintToChatAll("%t", "Card_Cleared_All");
}

// Red cards outlive the match, the map and reconnects, as in the original
// soccermod, until a referee removes them. Stored as auth -> player name.
void LoadRedCards()
{
	gRedCards = new StringMap();
	BuildPath(Path_SM, gRedCardsPath, sizeof(gRedCardsPath), "data/umbrella_soccer_red_cards.txt");

	KeyValues kv = new KeyValues("RedCards");
	kv.SetEscapeSequences(true);
	if (kv.ImportFromFile(gRedCardsPath) && kv.GotoFirstSubKey())
	{
		char auth[MAX_AUTH_ID_LENGTH];
		char name[MAX_NAME_LENGTH];
		do
		{
			kv.GetSectionName(auth, sizeof(auth));
			kv.GetString("name", name, sizeof(name));
			gRedCards.SetString(auth, name);
		}
		while (kv.GotoNextKey());
	}
	delete kv;
}

void SaveRedCards()
{
	KeyValues kv = new KeyValues("RedCards");
	kv.SetEscapeSequences(true);
	StringMapSnapshot snapshot = gRedCards.Snapshot();
	char auth[MAX_AUTH_ID_LENGTH];
	char name[MAX_NAME_LENGTH];
	for (int i = 0; i < snapshot.Length; i++)
	{
		snapshot.GetKey(i, auth, sizeof(auth));
		gRedCards.GetString(auth, name, sizeof(name));
		kv.JumpToKey(auth, true);
		kv.SetString("name", name);
		kv.GoBack();
	}
	delete snapshot;
	kv.ExportToFile(gRedCardsPath);
	delete kv;
}

// Bots all report "BOT" and LAN players "STEAM_ID_LAN", so only real Steam
// IDs are stored; anything else would red-card everyone sharing that ID.
bool IsPersonalAuth(const char[] auth)
{
	return strncmp(auth, "STEAM_", 6) == 0 && !StrEqual(auth, "STEAM_ID_LAN") && !StrEqual(auth, "STEAM_ID_PENDING");
}

void RememberRedCardAuth(int client)
{
	char auth[MAX_AUTH_ID_LENGTH];
	if (IsFakeClient(client) || !GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth), true) || !IsPersonalAuth(auth))
	{
		return;
	}

	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	gRedCards.SetString(auth, name);
	SaveRedCards();
}

bool IsRedCardAuth(const char[] auth)
{
	return IsPersonalAuth(auth) && gRedCards.ContainsKey(auth);
}

void RemoveRedCardAuth(int client)
{
	char auth[MAX_AUTH_ID_LENGTH];
	if (GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth), true))
	{
		RemoveRedCardByAuth(auth);
	}
}

// Also lifts the card from a player who is online with that auth.
bool RemoveRedCardByAuth(const char[] auth)
{
	if (!gRedCards.Remove(auth))
	{
		return false;
	}
	SaveRedCards();

	char clientAuth[MAX_AUTH_ID_LENGTH];
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidClient(client)
			&& GetClientAuthId(client, AuthId_Steam2, clientAuth, sizeof(clientAuth), true)
			&& StrEqual(clientAuth, auth, false))
		{
			gRedCard[client] = false;
			gYellowCards[client] = 0;
		}
	}
	return true;
}

void ApplyStoredRedCard(int client)
{
	char auth[MAX_AUTH_ID_LENGTH];
	if (GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth), true))
	{
		ApplyStoredRedCardAuth(client, auth);
	}
}

void ApplyStoredRedCardAuth(int client, const char[] auth)
{
	if (!IsValidClient(client) || !IsRedCardAuth(auth))
	{
		return;
	}

	gRedCard[client] = true;
	CreateTimer(0.2, TimerMoveRedCardSpectator, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action TimerMoveRedCardSpectator(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (IsValidClient(client) && gRedCard[client] && GetClientTeam(client) >= TEAM_T)
	{
		PrintToChat(client, "%t", "Team_Join_RedCard");
		if (IsPlayerAlive(client))
		{
			RestorePlayerDamage(client);
			ForcePlayerSuicide(client, false);
		}
		ChangeClientTeam(client, 1);
	}
	return Plugin_Stop;
}

void ClearRedCardAuths()
{
	gRedCards.Clear();
	SaveRedCards();
}

void ResetMatchPlayerState()
{
	// Red cards are kept: they last until a referee removes them.
	for (int client = 1; client <= MaxClients; client++)
	{
		gYellowCards[client] = 0;
		gClientLastTouch[client] = 0.0;
		gPlayerGoals[client] = 0;
		gPlayerAssists[client] = 0;
		gPlayerOwnGoals[client] = 0;
		gPlayerPoints[client] = 0;
		gStamina[client] = 100.0;
		gLastArmorValue[client] = -1;
		if (IsValidClient(client))
		{
			SetEntProp(client, Prop_Data, "m_iFrags", 0);
			UpdateClientScoreboard(client);
		}
	}
}

void ResetClientState(int client)
{
	gYellowCards[client] = 0;
	gRedCard[client] = false;
	gClientLastTouch[client] = 0.0;
	gPlayerGoals[client] = 0;
	gPlayerAssists[client] = 0;
	gPlayerOwnGoals[client] = 0;
	gPlayerPoints[client] = 0;
	gStamina[client] = 100.0;
	gLastArmorValue[client] = -1;
	gSprinting[client] = false;
	gNextGoalkeeperToggle[client] = 0.0;
	gPosition[client] = SoccerPosition_Player;
	gDraftPicked[client] = false;
	gDraftTeam[client] = 0;
	gDraftGroup[client] = 0;
	gDraftSetupInput[client] = DRAFT_INPUT_NONE;
	gDraftSetupCaptainCount[client] = 0;
	gPracticeInput[client] = PRACTICE_INPUT_NONE;
	gMatchInput[client] = MATCH_INPUT_NONE;
	gChatInputExpires[client] = 0.0;
	ClearDraftCaptainSelection(client);
	gRespawnTimer[client] = null;
	gRefereeAction[client] = REF_ACTION_NONE;
}

void KillClientRespawnTimer(int client)
{
	if (gRespawnTimer[client] != null)
	{
		KillTimer(gRespawnTimer[client]);
		gRespawnTimer[client] = null;
	}
}

void ApplySoccerModel(int client)
{
	if (!IsValidClient(client) || !IsPlayerAlive(client))
	{
		return;
	}

	char model[PLATFORM_MAX_PATH];
	int team = GetClientTeam(client);
	if (team == TEAM_CT)
	{
		if (gPosition[client] == SoccerPosition_Goalkeeper)
		{
			gCvarModelCTGK.GetString(model, sizeof(model));
		}
		else
		{
			gCvarModelCT.GetString(model, sizeof(model));
		}
	}
	else if (team == TEAM_T)
	{
		if (gPosition[client] == SoccerPosition_Goalkeeper)
		{
			gCvarModelTGK.GetString(model, sizeof(model));
		}
		else
		{
			gCvarModelT.GetString(model, sizeof(model));
		}
	}

	if (PrepareModelPath(model))
	{
		SetEntityModel(client, model);
		DispatchKeyValue(client, "skin", "0");
	}
}

void PrecacheConfiguredModels()
{
	PrecacheModelFromConVar(gCvarModelCT);
	PrecacheModelFromConVar(gCvarModelCTGK);
	PrecacheModelFromConVar(gCvarModelT);
	PrecacheModelFromConVar(gCvarModelTGK);
	PrecacheModelFromConVar(gCvarTrainingBallModel);
	PrecacheSoundFromConVar(gCvarPenaltyTurnSound);
	PrecacheStoppageTriggerModel();
}

// Only used to give the stoppage trigger a bounding box. Precached at map start
// so the trigger never forces a late precache mid-round.
void PrecacheStoppageTriggerModel()
{
	if (!IsModelPrecached(STOPPAGE_TRIGGER_MODEL))
	{
		PrecacheModel(STOPPAGE_TRIGGER_MODEL, true);
	}
}

void PrecacheModelFromConVar(ConVar cvar)
{
	char model[PLATFORM_MAX_PATH];
	cvar.GetString(model, sizeof(model));
	AddModelDownloads(model);
	PrepareModelPath(model);
}

void AddModelDownloads(const char[] model)
{
	if (model[0] == '\0')
	{
		return;
	}

	char base[PLATFORM_MAX_PATH];
	strcopy(base, sizeof(base), model);
	ReplaceString(base, sizeof(base), "\\", "/");

	int dot = FindCharInString(base, '.', true);
	if (dot == -1)
	{
		return;
	}
	base[dot] = '\0';

	static const char modelExtensions[][] =
	{
		".mdl",
		".vvd",
		".dx80.vtx",
		".dx90.vtx",
		".sw.vtx",
		".phy"
	};

	char path[PLATFORM_MAX_PATH];
	for (int i = 0; i < sizeof(modelExtensions); i++)
	{
		Format(path, sizeof(path), "%s%s", base, modelExtensions[i]);
		AddDownloadIfExists(path);
	}

	char modelDir[PLATFORM_MAX_PATH];
	strcopy(modelDir, sizeof(modelDir), base);
	int slash = FindCharInString(modelDir, '/', true);
	if (slash == -1)
	{
		return;
	}
	modelDir[slash] = '\0';

	AddMaterialDownloads(modelDir, "skin_foot_a2");
	AddMaterialDownloads(modelDir, "trionda_2026");
	AddMaterialDownloads(modelDir, "trionda_2026_base");
	AddMaterialDownloads(modelDir, "trionda_2026_normal");
	AddMaterialDownloads(modelDir, "trionda_2026_blender");
	AddMaterialDownloads(modelDir, "trionda_2026_blender_base");
	AddMaterialDownloads(modelDir, "trionda_2026_blender_normal");
}

void AddMaterialDownloads(const char[] modelDir, const char[] materialName)
{
	char path[PLATFORM_MAX_PATH];
	Format(path, sizeof(path), "materials/%s/%s.vmt", modelDir, materialName);
	AddDownloadIfExists(path);
	Format(path, sizeof(path), "materials/%s/%s.vtf", modelDir, materialName);
	AddDownloadIfExists(path);
}

void AddDownloadIfExists(const char[] path)
{
	if (path[0] != '\0' && FileExists(path, true))
	{
		AddFileToDownloadsTable(path);
	}
}

bool PrepareModelPath(const char[] model)
{
	if (model[0] == '\0' || !FileExists(model, true))
	{
		return false;
	}

	if (!IsModelPrecached(model))
	{
		return PrecacheModel(model, true) != 0;
	}
	return true;
}

void PrecacheSoundFromConVar(ConVar cvar)
{
	char sound[PLATFORM_MAX_PATH];
	cvar.GetString(sound, sizeof(sound));
	PrepareSoundPath(sound);
}

bool PrepareSoundPath(const char[] sound)
{
	if (sound[0] == '\0')
	{
		return false;
	}

	char fullPath[PLATFORM_MAX_PATH];
	Format(fullPath, sizeof(fullPath), "sound/%s", sound);
	if (!FileExists(fullPath, true))
	{
		return false;
	}

	return PrecacheSound(sound, true);
}

void PlayPenaltyTurnSound(int client)
{
	if (!IsValidClient(client))
	{
		return;
	}

	char sound[PLATFORM_MAX_PATH];
	gCvarPenaltyTurnSound.GetString(sound, sizeof(sound));
	if (PrepareSoundPath(sound))
	{
		EmitSoundToClient(client, sound);
	}
}

bool GetPreparedTrainingBallModel(char[] model, int maxlen)
{
	gCvarTrainingBallModel.GetString(model, maxlen);
	return PrepareModelPath(model);
}

bool IsValidClient(int client)
{
	return client >= 1 && client <= MaxClients && IsClientInGame(client);
}

// Every admin has a ball of their own, as in the original soccermod.
void ClearTrainingBallRefs()
{
	for (int client = 0; client <= MAXPLAYERS; client++)
	{
		gTrainingBallRefs[client] = INVALID_ENT_REFERENCE;
	}
}

int GetClientTrainingBall(int client)
{
	int entity = EntRefToEntIndex(gTrainingBallRefs[client]);
	if (entity != INVALID_ENT_REFERENCE && entity > MaxClients && IsValidEntity(entity))
	{
		return entity;
	}
	gTrainingBallRefs[client] = INVALID_ENT_REFERENCE;
	return -1;
}

bool IsTrainingBall(int entity)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (gTrainingBallRefs[client] != INVALID_ENT_REFERENCE && EntRefToEntIndex(gTrainingBallRefs[client]) == entity)
		{
			return true;
		}
	}
	return false;
}

void RemoveClientTrainingBall(int client)
{
	int entity = GetClientTrainingBall(client);
	if (entity == -1)
	{
		return;
	}

	if (EntRefToEntIndex(gTrainingCannonBallRef) == entity)
	{
		gTrainingCannonBallRef = INVALID_ENT_REFERENCE;
	}
	AcceptEntityInput(entity, "Kill", -1, -1, 0);
	gTrainingBallRefs[client] = INVALID_ENT_REFERENCE;
}

void KillAllTrainingBalls()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		RemoveClientTrainingBall(client);
	}
	ClearTrainingBallRefs();
}

void SpawnTrainingBall(int client)
{
	if (!IsSoccerAvailable())
	{
		return;
	}

	RemoveClientTrainingBall(client);

	float origin[3];
	if (!GetAimPosition(client, origin))
	{
		GetClientAbsOrigin(client, origin);
	}
	float aimed[3];
	aimed = origin;
	origin[2] += 24.0;

	char model[PLATFORM_MAX_PATH];
	if (!GetPreparedTrainingBallModel(model, sizeof(model)))
	{
		PrintToChat(client, "%t", "Training_Ball_Create_Failed");
		return;
	}

	int entity = CreateEntityByName("prop_physics");
	if (entity == -1)
	{
		PrintToChat(client, "%t", "Training_Ball_Create_Failed");
		return;
	}

	// Soccer maps commonly filter func_clip_vphysics by targetname "ball".
	DispatchKeyValue(entity, "targetname", TRAINING_BALL_CLIP_NAME);
	DispatchKeyValue(entity, "model", model);
	DispatchKeyValueVector(entity, "origin", origin);
	// Start asleep, like the match ball: it stays where it is put until touched.
	DispatchKeyValue(entity, "spawnflags", "1");
	if (!DispatchSpawn(entity))
	{
		AcceptEntityInput(entity, "Kill", -1, -1, 0);
		PrintToChat(client, "%t", "Training_Ball_Create_Failed");
		return;
	}
	PlaceBallAtRest(entity, aimed);
	gTrainingBallRefs[client] = EntIndexToEntRef(entity);
	PrintToChat(client, "%t", "Training_Ball_Spawned");
}

void RemoveTrainingBall(int client)
{
	if (GetClientTrainingBall(client) == -1)
	{
		PrintToChat(client, "%t", "Training_Ball_NotFound");
		return;
	}

	RemoveClientTrainingBall(client);
	PrintToChat(client, "%t", "Training_Ball_Removed");
}

void TrainingOnPluginStart()
{
	ClearTrainingBallRefs();
	gTrainingGoalsDisabled = false;
}

void TrainingOnMapStart()
{
	ClearTrainingBallRefs();
	gTrainingGoalsDisabled = false;
}

// Training without goals, as in the original soccermod: the map's goal triggers
// are removed, again on every round start, until the goals are enabled again,
// which restarts the round so the map spawns them back.
void SetTrainingGoalsDisabled(int client, bool disabled)
{
	if (gMatchLive)
	{
		PrintToChat(client, "%t", "Training_Goals_Match_Live");
		return;
	}
	if (disabled == gTrainingGoalsDisabled)
	{
		return;
	}

	gTrainingGoalsDisabled = disabled;
	if (disabled)
	{
		KillGoalTriggers();
		PrintToChatAll("%t", "Training_Goals_Disabled", client);
	}
	else
	{
		ServerCommand("mp_restartgame 1");
		PrintToChatAll("%t", "Training_Goals_Enabled", client);
	}
}

void KillGoalTriggers()
{
	int entity = -1;
	char name[MAX_ENTITY_NAME];
	while ((entity = FindEntityByClassname(entity, "trigger_once")) != -1)
	{
		GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));
		if (!StrEqual(name, "end_stoppage_time", false))
		{
			AcceptEntityInput(entity, "Kill");
		}
	}
}

void SetTrainingCannonPosition(int client)
{
	if (!GetAimPosition(client, gTrainingCannonOrigin))
	{
		GetClientEyePosition(client, gTrainingCannonOrigin);
	}
	gTrainingCannonOrigin[2] += 15.0;
	gTrainingCannonOriginSet = true;
	PrintToChatAll("%t", "Training_Cannon_Position_Set", client);
}

void SetTrainingCannonTarget(int client)
{
	SetTrainingCannonTargetFromClient(client);
	PrintToChatAll("%t", "Training_Cannon_Target_Set", client);
}

void SetTrainingCannonTargetFromClient(int client)
{
	if (!GetAimPosition(client, gTrainingCannonTarget))
	{
		float start[3];
		float angles[3];
		float direction[3];
		GetClientEyePosition(client, start);
		GetClientEyeAngles(client, angles);
		GetAngleVectors(angles, direction, NULL_VECTOR, NULL_VECTOR);
		ScaleVector(direction, 1024.0);
		AddVectors(start, direction, gTrainingCannonTarget);
	}
	gTrainingCannonTargetSet = true;
}

bool StartTrainingCannon(int client)
{
	if (!IsSoccerAvailable())
	{
		return false;
	}
	if (!CanUseTrainingCannon(client))
	{
		return false;
	}

	if (!gTrainingCannonOriginSet)
	{
		GetClientEyePosition(client, gTrainingCannonOrigin);
		gTrainingCannonOriginSet = true;
	}
	if (!gTrainingCannonTargetSet)
	{
		SetTrainingCannonTargetFromClient(client);
	}

	int ball = GetClientTrainingBall(client);
	if (ball == -1)
	{
		ball = GetTrainingCannonBallEntity();
	}
	if (ball == -1)
	{
		PrintToChat(client, "%t", "Training_Cannon_No_Ball");
		return false;
	}

	gTrainingCannonBallRef = EntIndexToEntRef(ball);
	gTrainingCannonSet = true;
	KillTimerSafe(gTrainingCannonTimer);
	gTrainingCannonTimer = CreateTimer(0.1, TimerTrainingCannon, _, TIMER_FLAG_NO_MAPCHANGE);
	PrintToChat(client, "%t", "Training_Cannon_Started");
	return true;
}

bool CanUseTrainingCannon(int client)
{
	if (gMatchLive)
	{
		if (IsValidClient(client))
		{
			PrintToChat(client, "%t", "Training_Cannon_Match_Live");
		}
		return false;
	}
	return true;
}

int GetTrainingCannonBallEntity()
{
	int entity = EntRefToEntIndex(gTrainingCannonBallRef);
	if (entity != INVALID_ENT_REFERENCE && entity > MaxClients && IsValidEntity(entity))
	{
		return entity;
	}

	if (gMatchLive)
	{
		return -1;
	}

	FindBallEntity();
	entity = GetTrackedBallEntity();
	if (entity != -1)
	{
		return entity;
	}
	return -1;
}

public Action TimerTrainingCannon(Handle timer)
{
	gTrainingCannonTimer = null;
	if (!gTrainingCannonSet || !IsSoccerAvailable())
	{
		return Plugin_Stop;
	}

	int ball = GetTrainingCannonBallEntity();
	if (ball == -1)
	{
		gTrainingCannonSet = false;
		return Plugin_Stop;
	}

	float velocity[3];
	MakeVectorFromPoints(gTrainingCannonOrigin, gTrainingCannonTarget, velocity);
	if (NormalizeVector(velocity, velocity) <= 0.0)
	{
		// No direction to fire in: stop cleanly so the toggle starts it again.
		gTrainingCannonSet = false;
		return Plugin_Stop;
	}

	float randomness = gCvarTrainingCannonRandomness.FloatValue;
	if (randomness > 0.0)
	{
		velocity[0] += GetRandomFloat(-randomness, randomness) / 1000.0;
		velocity[1] += GetRandomFloat(-randomness, randomness) / 1000.0;
		velocity[2] += GetRandomFloat(-randomness, randomness) / 1000.0;
		NormalizeVector(velocity, velocity);
	}

	ScaleVector(velocity, gCvarTrainingCannonPower.FloatValue);
	TeleportEntity(ball, gTrainingCannonOrigin, NULL_VECTOR, velocity);
	AcceptEntityInput(ball, "EnableMotion", -1, -1, 0);
	AcceptEntityInput(ball, "Wake", -1, -1, 0);
	HookSoccerEntity(ball);

	if (gTrainingCannonSet)
	{
		gTrainingCannonTimer = CreateTimer(gCvarTrainingCannonFireRate.FloatValue, TimerTrainingCannon, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Stop;
}

public Action TimerKillEntity(Handle timer, any ref)
{
	int entity = EntRefToEntIndex(ref);
	if (entity != INVALID_ENT_REFERENCE && IsValidEntity(entity))
	{
		AcceptEntityInput(entity, "Kill", -1, -1, 0);
	}
	return Plugin_Stop;
}
