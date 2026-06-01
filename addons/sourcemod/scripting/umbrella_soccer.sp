#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

#define PLUGIN_VERSION "1.0.0"

#if !defined IN_SPEED
#define IN_SPEED (1 << 17)
#endif

#define TEAM_T 2
#define TEAM_CT 3
#define MAX_ENTITY_NAME 64
#define MAX_AUTH_ID_LENGTH 32
#define PENALTY_MAX_SHOTS 5
#define TRAINING_BALL_CLIP_NAME "ball"
#define DRAFT_MAX_CAPTAINS 4
#define DRAFT_INPUT_NONE 0
#define DRAFT_INPUT_CAPTAINS 1
#define DRAFT_INPUT_TEAMSIZE 2
#define PRACTICE_INPUT_NONE 0
#define PRACTICE_INPUT_CANNON_POWER 1
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
char gRedCardAuths[MAXPLAYERS + 1][MAX_AUTH_ID_LENGTH];
int gRedCardAuthCount;

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

bool gPenaltyActive;
bool gPenaltyWaitingForKick;
bool gShootoutActive;
int gPenaltyTeam;
int gPenaltyShooter;
int gPenaltyGoalkeeper;
float gPenaltySpot[3];
bool gPenaltySpotValid;
int gShootoutScoreCT;
int gShootoutScoreT;
int gShootoutTakenCT;
int gShootoutTakenT;
int gShootoutNextTeam;
int gShootoutShooterIndexCT;
int gShootoutShooterIndexT;

int gTrainingBallRef = INVALID_ENT_REFERENCE;
int gTrainingCannonBallRef = INVALID_ENT_REFERENCE;
float gTrainingCannonOrigin[3];
float gTrainingCannonTarget[3];
bool gTrainingCannonOriginSet;
bool gTrainingCannonTargetSet;
bool gTrainingCannonSet;

int gRefereeAction[MAXPLAYERS + 1];

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
	CreateConVar("sm_soccer_assist_window", "0.0", "Compatibility cvar. Assists follow the original plugin: previous same-team ball hitter.", FCVAR_NOTIFY, true, 0.0, true, 30.0);
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
	gCvarMatchBreakLength = CreateConVar("soccer_mod_match_period_break_length", "10", "Break length between periods in SECONDS. Example: 10 = 10 seconds.", FCVAR_NOTIFY, true, 0.0, true, 600.0);
	gCvarMatchOvertime = CreateConVar("soccer_mod_match_overtime", "1", "Play overtime when a match is tied after regulation.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	gCvarMatchOvertimePercent = CreateConVar("soccer_mod_match_overtime_percent", "25.0", "Overtime length as a percentage of total match time, rounded up to full minutes.", FCVAR_NOTIFY, true, 1.0, true, 100.0);
	gCvarMatchGoldenGoal = CreateConVar("soccer_mod_match_golden_goal", "0", "If enabled, the first goal during overtime wins. If overtime ends tied, the match remains tied.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	gCvarPenaltyShotTime = CreateConVar("sm_soccer_penalty_shot_time", "15", "Seconds allowed after a penalty kick starts.", FCVAR_NOTIFY, true, 3.0, true, 45.0);
	gCvarPenaltyShotDelay = CreateConVar("sm_soccer_penalty_shot_delay", "4.0", "Delay in seconds before restarting to the next penalty shot.", FCVAR_NOTIFY, true, 0.2, true, 10.0);
	gCvarPenaltyTurnSound = CreateConVar("sm_soccer_penalty_turn_sound", "buttons/blip1.wav", "Sound played to the shooter when it is their penalty turn. Empty disables.", FCVAR_NONE);
	gCvarTrainingBallModel = CreateConVar("sm_soccer_training_ball_model", "models/ayrton09/fifa_trionda_2026/trionda_2026.mdl", "Model used for spawned training balls. Empty disables training ball spawning.", FCVAR_NONE);
	CreateConVar("sm_soccer_training_cannon_ball_life", "20.0", "Compatibility cvar kept for older configs. The cannon reuses an existing ball.", FCVAR_NOTIFY, true, 1.0, true, 120.0);
	gCvarTrainingCannonFireRate = CreateConVar("sm_soccer_training_cannon_fire_rate", "2.5", "Seconds between training cannon shots.", FCVAR_NOTIFY, true, 0.2, true, 30.0);
	gCvarTrainingCannonPower = CreateConVar("sm_soccer_training_cannon_power", "900.0", "Velocity applied by the training cannon.", FCVAR_NOTIFY, true, 100.0, true, 3000.0);
	gCvarTrainingCannonRandomness = CreateConVar("sm_soccer_training_cannon_randomness", "0.0", "Random velocity spread added to training cannon shots.", FCVAR_NOTIFY, true, 0.0, true, 500.0);
	gCvarLiveReplacementSlots = CreateConVar("sm_soccer_live_replacement_slots", "0", "How many non-assigned replacements can join T/CT during a live match.", FCVAR_NOTIFY, true, 0.0, true, 10.0);
	gCvarCaptainModeDefault = CreateConVar("sm_soccer_captain_mode_default", "0", "Start a captain draft automatically when valid captains are available.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

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
		}
	}
}

public void OnMapStart()
{
	ClearMatchRuntimeState();
	ApplyMapAllowedState();
}

public void OnConfigsExecuted()
{
	ApplyMapAllowedState();
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
	gTrainingBallRef = INVALID_ENT_REFERENCE;
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

	int trainingBall = EntRefToEntIndex(gTrainingBallRef);
	if (trainingBall != INVALID_ENT_REFERENCE && entity == trainingBall)
	{
		gTrainingBallRef = INVALID_ENT_REFERENCE;
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

	RegisterBallTouch(activator);
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
	ClearLastTouchers();
	DiscoverSoccerEntities();
	CacheBallStartPosition();
	if (gStoppageActive)
	{
		EnsureStoppageTrigger();
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
	if (gPaused || gInBreak || gRestartingPeriod || gPenaltyActive)
	{
		return Plugin_Continue;
	}

	int winner = event.GetInt("winner");
	if (winner == TEAM_T || winner == TEAM_CT)
	{
		HandleGoal(winner, true);
	}
	return Plugin_Continue;
}

public Action EventPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(client) && IsSoccerAvailable())
	{
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

public Action CommandJoinTeam(int client, const char[] command, int argc)
{
	if (!IsValidClient(client) || !IsSoccerAvailable() || !gMatchLive || argc < 1)
	{
		return Plugin_Continue;
	}

	char arg[16];
	GetCmdArg(1, arg, sizeof(arg));
	int team = ParseJoinTeamArg(arg);
	if (team != TEAM_T && team != TEAM_CT)
	{
		return Plugin_Continue;
	}

	if (gRedCard[client])
	{
		PrintToChat(client, "%t", "Team_Join_RedCard");
		return Plugin_Handled;
	}

	if (!HasAssignedSoccerTeams())
	{
		return Plugin_Continue;
	}

	if (gDraftTeam[client] == team)
	{
		return Plugin_Continue;
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

	return Plugin_Continue;
}

public Action CommandSay(int client, const char[] command, int argc)
{
	if (!IsValidClient(client))
	{
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

	if (gPracticeInput[client] == PRACTICE_INPUT_CANNON_POWER)
	{
		if (!CanUseTrainingCannon(client))
		{
			gPracticeInput[client] = PRACTICE_INPUT_NONE;
			ShowPracticeMenu(client);
			return Plugin_Handled;
		}

		float value;
		int consumed = StringToFloatEx(message, value);
		if (consumed != strlen(message) || value < 100.0 || value > 3000.0)
		{
			PrintToChat(client, "%t", "Training_Cannon_Power_Invalid", 100.0, 3000.0);
			return Plugin_Handled;
		}

		gCvarTrainingCannonPower.SetFloat(value);
		gPracticeInput[client] = PRACTICE_INPUT_NONE;
		PrintToChatAll("%t", "Training_Cannon_Power_Set", client, value);
		ShowPracticeMenu(client);
		return Plugin_Handled;
	}

	gPracticeInput[client] = PRACTICE_INPUT_NONE;
	return Plugin_Handled;
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
			char state[64];
			FormatMatchState(client, state, sizeof(state));
			SetHudTextParams(0.42, 0.08, 1.1, 20, 180, 255, 180);
			char hudLine[128];
			Format(hudLine, sizeof(hudLine), "%T", "Hud_Match_Line", client, gScoreCT, gScoreT, state);
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
	return 0;
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
	else if (StrEqual(info, "clearall"))
	{
		ClearAllCards();
		ShowRefereeMenu(client);
	}
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
	AddMenuItemPhrase(menu, client, "cannonstart", "Menu_TrainingCannon_Start");
	AddMenuItemPhrase(menu, client, "cannonstop", "Menu_TrainingCannon_Stop");
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
	else if (StrEqual(info, "cannonpower"))
	{
		if (!CanUseTrainingCannon(client))
		{
			ShowPracticeMenu(client);
			return 0;
		}
		gPracticeInput[client] = PRACTICE_INPUT_CANNON_POWER;
		PrintToChat(client, "%t", "Training_Cannon_Power_Prompt", 100.0, 3000.0, gCvarTrainingCannonPower.FloatValue);
		return 0;
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
	if (StrEqual(info, "snake"))
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
		gPracticeInput[client] = PRACTICE_INPUT_NONE;
		gDraftSetupInput[client] = DRAFT_INPUT_NONE;
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
	KillMatchTimers();
	KillStoppageTrigger();
	StopAllSprints();
	UnfreezeAllPlayers();
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
	PrintMatchMVP();
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

void PrintMatchMVP()
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
	gPeriodDuration = 0.0;
	gPeriodElapsed = 0.0;
	gMatchElapsed = 0.0;
	KillMatchTimers();
	KillStoppageTrigger();
	StopAllSprints();
	UnfreezeAllPlayers();
	ResetMatchPlayerState();
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
		if (gStoppageActive && !gKickoffActive)
		{
			StartStoppageClock();
		}
		else if (gMatchLive && gPeriodRemaining > 0.0 && !gKickoffActive)
		{
			StartPeriodClock(gPeriodRemaining, true);
		}
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
		gLastGoalTime = now;
		ResolvePenalty(scoringTeam == gPenaltyTeam);
		return;
	}

	if (gRoundGoalHandled)
	{
		return;
	}
	gLastGoalTime = now;
	gRoundGoalHandled = true;
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
	if (IsValidClient(scorer))
	{
		if (GetClientTeam(scorer) == scoringTeam)
		{
			AddPlayerGoalScore(scorer);
			PrintToChatAll("%t", "Goal_Scorer", scorer);

			int assist = gPreviousToucher;
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

		AddTeamRoundResultPoints(scoringTeam);
	}
	else
	{
		PrintToChatAll("%t", "Goal_Generic");
	}

	PrintScoreDisplay();
	if (!gMatchLive)
	{
		return;
	}

	if (gOvertimeActive && gCvarMatchGoldenGoal.BoolValue)
	{
		PrintToChatAll("%t", "GoldenGoal_Finished");
		FinishMatch();
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

void RegisterBallTouch(int client)
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
	if (!gMatchLive || gPaused || gInBreak || gRestartingPeriod || !gKickoffActive || gKickoffFrozen)
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
	UpdateClientScoreboard(client);
}

void AddPlayerPassScore(int client)
{
	AddPlayerPoints(client, gCvarRankingPointsPass.IntValue);
}

void AddPlayerInterceptionScore(int client)
{
	AddPlayerPoints(client, gCvarRankingPointsInterception.IntValue);
}

void AddPlayerBallLossScore(int client)
{
	AddPlayerPoints(client, gCvarRankingPointsBallLoss.IntValue);
}

void AddPlayerPoints(int client, int points)
{
	if (!IsValidClient(client) || points == 0)
	{
		return;
	}

	gPlayerPoints[client] += points;
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

	gPenaltyWaitingForKick = false;
	KillPenaltyTimer();
	gPenaltyTimer = CreateTimer(gCvarPenaltyShotTime.FloatValue, TimerPenaltyTimeout, _, TIMER_FLAG_NO_MAPCHANGE);
	PrintToChatAll("%t", "Penalty_Live");
}

public Action TimerPenaltyTimeout(Handle timer)
{
	gPenaltyTimer = null;
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
	if (gOvertimeActive)
	{
		FinishOvertime();
		return;
	}

	if (gCurrentPeriod >= gMaxPeriods)
	{
		if (gScoreCT == gScoreT)
		{
			if (gCvarMatchOvertime.BoolValue)
			{
				StartOvertime();
				return;
			}
		}
		FinishMatch();
		return;
	}

	StartBreak();
}

void StartOvertime()
{
	gOvertimeActive = true;
	gCurrentPeriod = gMaxPeriods + 1;

	int overtimeSeconds = GetOvertimeLengthSeconds();
	char overtimeDuration[16];
	FormatDurationSeconds(overtimeSeconds, overtimeDuration, sizeof(overtimeDuration));
	PrintToChatAll("%t", "Overtime_Start", overtimeDuration);
	if (gCvarMatchGoldenGoal.BoolValue)
	{
		PrintToChatAll("%t", "GoldenGoal_Start");
	}
	gPeriodRemaining = float(overtimeSeconds);
	gPeriodDuration = float(overtimeSeconds);
	gPeriodElapsed = 0.0;
	StartKickoff(GetScheduledKickoffTeam(), "KickoffReason_Overtime");
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

	char model[] = "models/props/cs_office/vending_machine.mdl";
	if (!IsModelPrecached(model))
	{
		PrecacheModel(model);
	}
	SetEntityModel(trigger, model);

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
	gCurrentPeriod++;
	gStoppageActive = false;
	gStoppageSeconds = 0;
	gPeriodRemaining = float(gCvarMatchPeriodLength.IntValue * 60);
	RestartRoundBeforePeriod(gPeriodRemaining);
	return Plugin_Stop;
}

void ForceNextPeriod()
{
	if (!gMatchLive)
	{
		return;
	}

	StopPeriodClock();
	KillTimerSafe(gBreakTimer);
	StopStoppageClock();
	KillStoppageTrigger();
	if (gCurrentPeriod < 1)
	{
		gCurrentPeriod = 1;
	}
	if (gCurrentPeriod < gMaxPeriods)
	{
		gCurrentPeriod++;
	}
	gMatchElapsed += gPeriodElapsed;
	gPeriodElapsed = 0.0;
	gInBreak = false;
	gStoppageActive = false;
	gStoppageSeconds = 0;
	RestartRoundBeforePeriod(float(gCvarMatchPeriodLength.IntValue * 60));
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
	gTrainingBallRef = INVALID_ENT_REFERENCE;
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
	return IsValidClient(client) && !gDraftPicked[client] && !IsFakeClient(client);
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

void StartPenalty(int team, int shooter, int goalkeeper)
{
	if (!IsSoccerAvailable())
	{
		return;
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
		return;
	}

	if (!IsValidClient(shooter))
	{
		shooter = FindFirstTeamClient(team);
	}
	else if (GetClientTeam(shooter) != team)
	{
		PrintToChatAll("%t", "Penalty_Need_Players");
		return;
	}
	if (!IsValidClient(goalkeeper))
	{
		goalkeeper = FindFirstTeamClient(team == TEAM_CT ? TEAM_T : TEAM_CT);
	}
	else if (GetClientTeam(goalkeeper) == team || GetClientTeam(goalkeeper) < TEAM_T)
	{
		goalkeeper = 0;
	}
	if (!IsValidClient(shooter))
	{
		PrintToChatAll("%t", "Penalty_Need_Players");
		return;
	}

	gPenaltyActive = true;
	gPenaltyWaitingForKick = true;
	gPenaltyTeam = team;
	gPenaltyShooter = shooter;
	gPenaltyGoalkeeper = goalkeeper;

	float shooterPos[3];
	shooterPos[0] = gPenaltySpot[0] - 96.0;
	shooterPos[1] = gPenaltySpot[1];
	shooterPos[2] = gPenaltySpot[2];
	TeleportEntity(shooter, shooterPos, NULL_VECTOR, NULL_VECTOR);

	if (IsValidClient(goalkeeper))
	{
		SetPosition(goalkeeper, SoccerPosition_Goalkeeper);
	}

	FindBallEntity();
	int ball = GetTrackedBallEntity();
	if (ball != -1)
	{
		TeleportEntity(ball, gPenaltySpot, NULL_VECTOR, NULL_VECTOR);
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
}

void ResolvePenalty(bool scored)
{
	if (!gPenaltyActive)
	{
		return;
	}

	KillPenaltyTimer();
	PrintToChatAll("%t", scored ? "Penalty_Goal" : "Penalty_Miss", gPenaltyShooter);
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
		CreateTimer(gCvarPenaltyShotDelay.FloatValue, TimerNextShootoutPenalty, _, TIMER_FLAG_NO_MAPCHANGE);
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

	KillPenaltyTimer();
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
	StartNextShootoutPenalty();
	return Plugin_Stop;
}

void StartNextShootoutPenalty()
{
	if (!gShootoutActive)
	{
		return;
	}

	if (gShootoutTakenCT >= PENALTY_MAX_SHOTS && gShootoutTakenT >= PENALTY_MAX_SHOTS && gShootoutScoreCT != gShootoutScoreT)
	{
		FinishShootout();
		return;
	}

	int team = gShootoutNextTeam;
	int shooter = GetNextShootoutShooter(team);
	int goalkeeper = FindFirstTeamClient(team == TEAM_CT ? TEAM_T : TEAM_CT);
	if (!IsValidClient(shooter))
	{
		FinishShootout();
		return;
	}

	gShootoutNextTeam = team == TEAM_CT ? TEAM_T : TEAM_CT;
	StartPenalty(team, shooter, goalkeeper);
}

int GetNextShootoutShooter(int team)
{
	int start = team == TEAM_CT ? gShootoutShooterIndexCT : gShootoutShooterIndexT;
	for (int pass = 0; pass < 2; pass++)
	{
		for (int client = start + 1; client <= MaxClients; client++)
		{
			if (IsValidClient(client) && GetClientTeam(client) == team && !gRedCard[client])
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

void FormatMatchState(int client, char[] buffer, int maxlen)
{
	if (!gMatchLive)
	{
		Format(buffer, maxlen, "%T", "State_Stopped", client);
	}
	else if (gUnpausing)
	{
		Format(buffer, maxlen, "%T", "Resume_Center", client, gUnpauseSecondsLeft);
	}
	else if (gInBreak)
	{
		Format(buffer, maxlen, "%T", "State_Break", client, RoundToCeil(gBreakEndTime - GetGameTime()));
	}
	else if (gKickoffActive)
	{
		char teamName[16];
		char elapsed[16];
		FormatKickoffTeamName(client, gKickoffTeam, teamName, sizeof(teamName));
		FormatDurationSeconds(GetPeriodElapsedSeconds(), elapsed, sizeof(elapsed));
		Format(buffer, maxlen, "%T", "State_Kickoff", client, teamName, elapsed);
	}
	else if (gPaused)
	{
		Format(buffer, maxlen, "%T", "State_Paused", client);
	}
	else if (gStoppageActive)
	{
		char elapsed[16];
		char stoppage[16];
		FormatDurationSeconds(GetPeriodElapsedSeconds(), elapsed, sizeof(elapsed));
		FormatDurationSeconds(gStoppageSeconds, stoppage, sizeof(stoppage));
		Format(buffer, maxlen, "%T", "State_Stoppage", client, elapsed, stoppage);
	}
	else if (gOvertimeActive)
	{
		char elapsed[16];
		FormatDurationSeconds(GetPeriodElapsedSeconds(), elapsed, sizeof(elapsed));
		Format(buffer, maxlen, "%T", "State_Overtime", client, elapsed);
	}
	else
	{
		char elapsed[16];
		FormatDurationSeconds(GetPeriodElapsedSeconds(), elapsed, sizeof(elapsed));
		Format(buffer, maxlen, "%T", "State_Live", client, gCurrentPeriod, elapsed);
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

void RememberRedCardAuth(int client)
{
	char auth[MAX_AUTH_ID_LENGTH];
	if (!GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth), true) || auth[0] == '\0' || IsRedCardAuth(auth))
	{
		return;
	}

	if (gRedCardAuthCount < sizeof(gRedCardAuths))
	{
		strcopy(gRedCardAuths[gRedCardAuthCount], sizeof(gRedCardAuths[]), auth);
		gRedCardAuthCount++;
	}
}

bool IsRedCardAuth(const char[] auth)
{
	for (int i = 0; i < gRedCardAuthCount; i++)
	{
		if (StrEqual(gRedCardAuths[i], auth, false))
		{
			return true;
		}
	}
	return false;
}

void RemoveRedCardAuth(int client)
{
	char auth[MAX_AUTH_ID_LENGTH];
	if (!GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth), true) || auth[0] == '\0')
	{
		return;
	}

	for (int i = 0; i < gRedCardAuthCount; i++)
	{
		if (!StrEqual(gRedCardAuths[i], auth, false))
		{
			continue;
		}

		for (int j = i; j < gRedCardAuthCount - 1; j++)
		{
			strcopy(gRedCardAuths[j], sizeof(gRedCardAuths[]), gRedCardAuths[j + 1]);
		}
		gRedCardAuthCount--;
		gRedCardAuths[gRedCardAuthCount][0] = '\0';
		return;
	}
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
	if (!gMatchLive || !IsValidClient(client) || !IsRedCardAuth(auth))
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
	for (int i = 0; i < gRedCardAuthCount; i++)
	{
		gRedCardAuths[i][0] = '\0';
	}
	gRedCardAuthCount = 0;
}

void ResetMatchPlayerState()
{
	ClearRedCardAuths();
	for (int client = 1; client <= MaxClients; client++)
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

void SpawnTrainingBall(int client)
{
	if (!IsSoccerAvailable())
	{
		return;
	}

	int previous = EntRefToEntIndex(gTrainingBallRef);
	if (previous != INVALID_ENT_REFERENCE && previous > MaxClients && IsValidEntity(previous))
	{
		AcceptEntityInput(previous, "Kill", -1, -1, 0);
	}
	gTrainingBallRef = INVALID_ENT_REFERENCE;

	float origin[3];
	if (!GetAimPosition(client, origin))
	{
		GetClientAbsOrigin(client, origin);
	}
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
	if (!DispatchSpawn(entity))
	{
		AcceptEntityInput(entity, "Kill", -1, -1, 0);
		PrintToChat(client, "%t", "Training_Ball_Create_Failed");
		return;
	}
	gTrainingBallRef = EntIndexToEntRef(entity);
	gTrainingCannonBallRef = gTrainingBallRef;
	PrintToChat(client, "%t", "Training_Ball_Spawned");
}

void RemoveTrainingBall(int client)
{
	int entity = EntRefToEntIndex(gTrainingBallRef);
	if (entity == INVALID_ENT_REFERENCE || entity <= MaxClients || !IsValidEntity(entity))
	{
		gTrainingBallRef = INVALID_ENT_REFERENCE;
		PrintToChat(client, "%t", "Training_Ball_NotFound");
		return;
	}

	AcceptEntityInput(entity, "Kill", -1, -1, 0);
	gTrainingBallRef = INVALID_ENT_REFERENCE;
	if (EntRefToEntIndex(gTrainingCannonBallRef) == entity)
	{
		gTrainingCannonBallRef = INVALID_ENT_REFERENCE;
	}
	PrintToChat(client, "%t", "Training_Ball_Removed");
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

	int ball = GetTrainingCannonBallEntity();
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

	entity = EntRefToEntIndex(gTrainingBallRef);
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
