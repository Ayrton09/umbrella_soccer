// Penalty shootout.
//
// It starts by itself when overtime ends tied, or from the admin menu. Each
// team's captain lines up its kickers from a menu (an admin does it for a team
// without a captain), and nothing is kicked until both orders are set. Then the
// order is shown in chat, a coin toss picks who kicks first and the kicks start
// five seconds later. Everyone else waits frozen at a spot marked from the menu
// (the centre spot by default); the kicker is placed behind the ball and the
// defending goalkeeper on the goal line. The HUD shows each team's goals and
// misses like a TV graphic.
//
// The map's goal triggers would kill the team that concedes and restart the
// round. While penalties are being taken they are held back: the plugin itself
// sees the ball reach the goal and calls the goal, and a kick that is not in
// within sm_soccer_penalty_result_time is a miss.

#define SHOOTOUT_MAX_KICKERS 20
#define SHOOTOUT_MAX_SLOTS 64
#define SHOOTOUT_HUD_SLOTS 10
#define SHOOTOUT_START_DELAY 5.0
#define SHOOTOUT_AFTER_OVERTIME_DELAY 2.0
#define SHOOTOUT_REMINDER_INTERVAL 20.0
#define SHOOTOUT_BOARD_TIME 12.0
#define SHOOTOUT_END_HOLD_TIME 8.0
#define SHOOTOUT_RESTART_DELAY 5.0
#define PENALTY_GOAL_HOLD_TIME 3.0
// About 11 m from the goal line at the official map's scale.
#define PENALTY_DEFAULT_SPOT_DISTANCE 312.0
#define SHOOTOUT_RESULT_GOAL 1
#define SHOOTOUT_RESULT_MISS 2

ConVar gCvarShootoutKickers;
ConVar gCvarShootoutAfterOvertime;
ConVar gCvarShootoutOrderTime;
ConVar gCvarPenaltyWarningTime;
ConVar gCvarPenaltyResultTime;
ConVar gCvarPenaltyWhistle;
ConVar gCvarShootoutEndWhistle;

char gPenaltySpotsPath[PLATFORM_MAX_PATH];
float gShootoutWaitSpot[3];
bool gShootoutWaitSpotValid;

// Kicks each team takes before sudden death.
int gShootoutKickers;
// The captains are lining up their kickers; nothing is kicked yet.
bool gShootoutChoosing;
// The countdown between the orders being set and the first kick.
bool gShootoutStarting;
float gShootoutStartTime;
// Per team (index 0 TT, 1 CT): who lines up the kickers, as a userid (0 means
// an admin does), and the kicking order, also as userids.
int gShootoutChooser[2];
int gShootoutOrder[2][MAXPLAYERS + 1];
int gShootoutOrderCount[2];
int gShootoutOrderNext[2];
bool gShootoutOrderDone[2];
int gShootoutResult[2][SHOOTOUT_MAX_SLOTS];
// Players the shootout froze at the waiting spot.
bool gShootoutWaiting[MAXPLAYERS + 1];
int gShootoutWinner;
float gShootoutBoardUntil;
Handle gShootoutReminderTimer;
Handle gShootoutOrderTimer;
Handle gShootoutRestartTimer;
// The kicker of the last kick, held still until the result (userid).
int gShootoutFrozenShooter;

Handle gPenaltyWarningTimer;
float gPenaltyDeadline;
float gPenaltyGoalHoldUntil;

void ShootoutOnPluginStart()
{
	gCvarShootoutKickers = CreateConVar("sm_soccer_shootout_kickers", "5", "Kickers per team in a penalty shootout before sudden death, when the shootout starts by itself or no number is given.", FCVAR_NOTIFY, true, 1.0, true, float(SHOOTOUT_MAX_KICKERS));
	gCvarShootoutAfterOvertime = CreateConVar("sm_soccer_shootout_after_overtime", "1", "Start a penalty shootout by itself when overtime ends tied.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	gCvarShootoutOrderTime = CreateConVar("sm_soccer_shootout_order_time", "120", "Seconds the captains have to line up their kickers before the rest of the order is filled in automatically. 0 waits for them.", FCVAR_NOTIFY, true, 0.0, true, 600.0);
	gCvarPenaltyWarningTime = CreateConVar("sm_soccer_penalty_warning_time", "10", "Seconds left to take a penalty when the whistle blows again to hurry the shooter. 0 disables.", FCVAR_NOTIFY, true, 0.0, true, 60.0);
	gCvarPenaltyResultTime = CreateConVar("sm_soccer_penalty_result_time", "5", "Seconds after the kick for the ball to go in before a shootout or practice penalty counts as a miss.", FCVAR_NOTIFY, true, 1.0, true, 30.0);
	gCvarPenaltyWhistle = CreateConVar("sm_soccer_penalty_whistle", "umbrella_soccer/whistle_short.wav", "Whistle played to everyone when a penalty can be taken and again when the shooter is running out of time. Empty disables.", FCVAR_NONE);
	gCvarShootoutEndWhistle = CreateConVar("sm_soccer_shootout_end_whistle", "umbrella_soccer/whistle_long.wav", "Whistle played to everyone when a penalty shootout ends. Empty disables.", FCVAR_NONE);
	BuildPath(Path_SM, gPenaltySpotsPath, sizeof(gPenaltySpotsPath), "configs/umbrella_soccer_penalty_spots.cfg");
	RegConsoleCmd("sm_kickers", CmdKickers, "Captains: line up the penalty shootout kickers.");
}

void ShootoutOnMapStart()
{
	EndShootoutState();
	gPenaltyGoalHoldUntil = 0.0;
	LoadPenaltySpots();
}

void ShootoutPrecacheSounds()
{
	PrecacheSoundFromConVar(gCvarPenaltyWhistle);
	PrecacheSoundFromConVar(gCvarShootoutEndWhistle);
}

void ShootoutOnClientDisconnect(int client)
{
	gShootoutWaiting[client] = false;
	if (!gShootoutChoosing)
	{
		return;
	}

	int userid = GetClientUserId(client);
	for (int index = 0; index < 2; index++)
	{
		if (gShootoutChooser[index] == userid)
		{
			gShootoutChooser[index] = 0;
		}
	}
}

void ShootoutOnPlayerSpawn(int client)
{
	gShootoutWaiting[client] = false;
}

// Called once a respawned player's spawn state is applied: during the kicks
// they join the others at the waiting spot instead of running onto a kick.
void ShootoutOnSpawnApplied(int client)
{
	if (!gShootoutActive || gShootoutChoosing || client == gPenaltyShooter || client == gPenaltyGoalkeeper
		|| GetClientTeam(client) < TEAM_T || !IsPlayerAlive(client))
	{
		return;
	}

	float spot[3];
	if (GetShootoutWaitSpot(spot))
	{
		TeleportToWaitingSlot(client, spot);
	}
	SetEntityMoveType(client, MOVETYPE_NONE);
	gShootoutWaiting[client] = true;
}

int ShootoutIndex(int team)
{
	return team == TEAM_CT ? 1 : 0;
}

void PlayShootoutSound(ConVar cvar)
{
	char sound[PLATFORM_MAX_PATH];
	cvar.GetString(sound, sizeof(sound));
	if (PrepareSoundPath(sound))
	{
		EmitSoundToAll(sound);
	}
}

void PlayPenaltyWhistle()
{
	PlayShootoutSound(gCvarPenaltyWhistle);
}

// Replies to whoever started an action: a player in chat, or the server console.
void ReplyShootout(int admin, const char[] phrase)
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

bool IsShootoutEligible(int client, int team)
{
	return IsValidClient(client)
		&& !IsFakeClient(client)
		&& GetClientTeam(client) == team
		&& !gRedCard[client];
}

int CountShootoutEligible(int team)
{
	int count;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsShootoutEligible(client, team))
		{
			count++;
		}
	}
	return count;
}

bool IsInShootoutOrder(int team, int client)
{
	int index = ShootoutIndex(team);
	int userid = GetClientUserId(client);
	for (int i = 0; i < gShootoutOrderCount[index]; i++)
	{
		if (gShootoutOrder[index][i] == userid)
		{
			return true;
		}
	}
	return false;
}

// How many kickers a team lines up: the chosen number, or everyone on the team
// when it has fewer players than that.
int GetShootoutOrderTarget(int team)
{
	int index = ShootoutIndex(team);
	int available = gShootoutOrderCount[index];
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsShootoutEligible(client, team) && !IsInShootoutOrder(team, client))
		{
			available++;
		}
	}
	return available < gShootoutKickers ? available : gShootoutKickers;
}

// The draft captain who ended up on the team, if any.
int GetShootoutCaptain(int team)
{
	for (int i = 0; i < DRAFT_MAX_CAPTAINS; i++)
	{
		int captain = gDraftCaptains[i];
		if (IsShootoutEligible(captain, team))
		{
			return captain;
		}
	}
	return 0;
}

bool HasShootoutChooser(int team)
{
	int chooser = GetClientOfUserId(gShootoutChooser[ShootoutIndex(team)]);
	return chooser > 0 && IsClientInGame(chooser);
}

bool IsShootoutChooser(int client, int team)
{
	int userid = gShootoutChooser[ShootoutIndex(team)];
	return userid != 0 && GetClientOfUserId(userid) == client;
}

bool CanChooseShootoutOrder(int client, int team)
{
	return gShootoutChoosing
		&& (team == TEAM_CT || team == TEAM_T)
		&& !gShootoutOrderDone[ShootoutIndex(team)]
		&& (IsShootoutChooser(client, team) || HasSoccerAdminAccess(client));
}

// The pending team a client lines up next: their own first. An admin is only
// sent to a team nobody else lines up, unless they ask with !kickers.
int GetShootoutTeamToChooseFor(int client, bool includeTaken)
{
	int own = GetClientTeam(client);
	int teams[2];
	teams[0] = own == TEAM_T ? TEAM_T : TEAM_CT;
	teams[1] = teams[0] == TEAM_CT ? TEAM_T : TEAM_CT;
	for (int i = 0; i < 2; i++)
	{
		int team = teams[i];
		if (CanChooseShootoutOrder(client, team)
			&& (includeTaken || IsShootoutChooser(client, team) || !HasShootoutChooser(team)))
		{
			return team;
		}
	}
	return 0;
}

bool StartShootoutSetup(int admin, int kickers)
{
	if (!IsSoccerAvailable())
	{
		return false;
	}

	if (gMatchLive)
	{
		ReplyShootout(admin, "Shootout_Match_Live");
		return false;
	}

	if (gPenaltyActive || gShootoutActive)
	{
		ReplyShootout(admin, "Penalty_Already_Active");
		return false;
	}

	if (CountShootoutEligible(TEAM_CT) == 0 || CountShootoutEligible(TEAM_T) == 0)
	{
		PrintToChatAll("%t", "Penalty_Need_Players");
		return false;
	}

	// Training without goals removed the goal triggers; the restart brings them
	// back, so goals can be seen again.
	if (gTrainingGoalsDisabled)
	{
		gTrainingGoalsDisabled = false;
		ServerCommand("mp_restartgame 1");
	}

	EndShootoutState();
	StopTrainingCannon();
	gShootoutActive = true;
	gShootoutChoosing = true;
	if (kickers < 1)
	{
		kickers = 1;
	}
	gShootoutKickers = kickers > SHOOTOUT_MAX_KICKERS ? SHOOTOUT_MAX_KICKERS : kickers;
	PrintToChatAll("%t", "Shootout_Setup_Start", gShootoutKickers);

	// Each team is lined up by its captain; without one, by the admin who
	// started the shootout, or else by an admin on the server.
	int starter = admin > 0 && IsClientInGame(admin) && !IsFakeClient(admin) ? admin : 0;
	for (int team = TEAM_T; team <= TEAM_CT; team++)
	{
		char label[16];
		GetTeamNameServer(team, label, sizeof(label));
		int chooser = GetShootoutCaptain(team);
		if (chooser == 0)
		{
			chooser = starter > 0 ? starter : FindShootoutAdmin(team);
			if (chooser > 0)
			{
				PrintToChatAll("%t", "Shootout_Order_NoCaptain", label);
			}
		}
		gShootoutChooser[ShootoutIndex(team)] = chooser > 0 ? GetClientUserId(chooser) : 0;
		if (chooser > 0)
		{
			PrintToChat(chooser, "%t", "Shootout_Order_Prompt", label);
		}
	}

	// A team nobody can line up gets its order filled in right away.
	for (int team = TEAM_T; team <= TEAM_CT && gShootoutChoosing; team++)
	{
		if (gShootoutChooser[ShootoutIndex(team)] == 0)
		{
			AutoCompleteShootoutOrder(team);
		}
	}
	if (!gShootoutChoosing)
	{
		return true;
	}

	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || IsFakeClient(client))
		{
			continue;
		}

		int team = GetShootoutTeamToChooseFor(client, false);
		if (team != 0 && IsShootoutChooser(client, team))
		{
			ShowShootoutOrderMenu(client, team);
		}
	}

	KillTimerSafe(gShootoutReminderTimer);
	gShootoutReminderTimer = CreateTimer(SHOOTOUT_REMINDER_INTERVAL, TimerShootoutReminder, _, TIMER_FLAG_NO_MAPCHANGE);
	KillTimerSafe(gShootoutOrderTimer);
	float orderTime = gCvarShootoutOrderTime.FloatValue;
	if (orderTime > 0.0)
	{
		gShootoutOrderTimer = CreateTimer(orderTime, TimerShootoutOrderTimeout, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	return true;
}

// An admin to line up a team without a captain: one on that team first.
int FindShootoutAdmin(int team)
{
	int fallback = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || IsFakeClient(client) || !HasSoccerAdminAccess(client))
		{
			continue;
		}
		if (GetClientTeam(client) == team)
		{
			return client;
		}
		if (fallback == 0)
		{
			fallback = client;
		}
	}
	return fallback;
}

// Re-armed after each run while the orders are being set.
public Action TimerShootoutReminder(Handle timer)
{
	gShootoutReminderTimer = null;
	if (!gShootoutChoosing)
	{
		return Plugin_Stop;
	}

	// An order is complete once nobody is left to pick, for example after the
	// players still unpicked left.
	for (int team = TEAM_T; team <= TEAM_CT && gShootoutChoosing; team++)
	{
		int index = ShootoutIndex(team);
		if (!gShootoutOrderDone[index] && gShootoutOrderCount[index] >= GetShootoutOrderTarget(team))
		{
			FinishShootoutOrder(team, false);
		}
	}
	if (!gShootoutChoosing)
	{
		return Plugin_Stop;
	}

	for (int team = TEAM_T; team <= TEAM_CT; team++)
	{
		if (gShootoutOrderDone[ShootoutIndex(team)])
		{
			continue;
		}

		char label[16];
		GetTeamNameServer(team, label, sizeof(label));
		int chooser = GetClientOfUserId(gShootoutChooser[ShootoutIndex(team)]);
		if (chooser <= 0 || !IsClientInGame(chooser))
		{
			// Whoever was lining up the team left: another admin takes over.
			chooser = FindShootoutAdmin(team);
			gShootoutChooser[ShootoutIndex(team)] = chooser > 0 ? GetClientUserId(chooser) : 0;
			if (chooser <= 0)
			{
				AutoCompleteShootoutOrder(team);
				if (!gShootoutChoosing)
				{
					return Plugin_Stop;
				}
				continue;
			}
			PrintToChatAll("%t", "Shootout_Order_NoCaptain", label);
			ShowShootoutOrderMenu(chooser, team);
		}
		PrintToChat(chooser, "%t", "Shootout_Order_Prompt", label);
	}
	gShootoutReminderTimer = CreateTimer(SHOOTOUT_REMINDER_INTERVAL, TimerShootoutReminder, _, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Stop;
}

public Action TimerShootoutOrderTimeout(Handle timer)
{
	gShootoutOrderTimer = null;
	if (gShootoutChoosing)
	{
		PrintToChatAll("%t", "Shootout_Order_Timeout");
		CompleteShootoutOrders();
	}
	return Plugin_Stop;
}

public Action TimerShootoutAfterOvertime(Handle timer)
{
	if (IsSoccerAvailable() && !gMatchLive && !gShootoutActive && !gPenaltyActive)
	{
		StartShootoutSetup(0, gCvarShootoutKickers.IntValue);
	}
	return Plugin_Stop;
}

void ShowShootoutKickersMenu(int client)
{
	Menu menu = new Menu(MenuHandlerShootoutKickers);
	char title[128];
	Format(title, sizeof(title), "%T", "Menu_Shootout_Kickers_Title", client);
	menu.SetTitle(title);
	AddShootoutKickersItem(menu, client, 3);
	AddShootoutKickersItem(menu, client, 5);
	AddMenuItemPhrase(menu, client, "custom", "Menu_Shootout_Kickers_Custom");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void AddShootoutKickersItem(Menu menu, int client, int kickers)
{
	char info[8];
	IntToString(kickers, info, sizeof(info));
	char text[96];
	Format(text, sizeof(text), "%T", "Menu_Shootout_Kickers_Count", client, kickers);
	menu.AddItem(info, text);
}

public int MenuHandlerShootoutKickers(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action == MenuAction_Cancel && item == MenuCancel_ExitBack && IsValidClient(client))
	{
		ShowPenaltyMenu(client);
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
	if (StrEqual(info, "custom"))
	{
		BeginChatInput(client);
		gMatchInput[client] = MATCH_INPUT_SHOOTOUT_KICKERS;
		PrintToChat(client, "%t", "Shootout_Kickers_Prompt", SHOOTOUT_MAX_KICKERS);
		return 0;
	}

	if (!StartShootoutSetup(client, StringToInt(info)))
	{
		ShowPenaltyMenu(client);
	}
	return 0;
}

// The custom number of kickers typed in chat.
void HandleShootoutKickersInput(int client, const char[] message)
{
	int kickers;
	int consumed = StringToIntEx(message, kickers);
	if (consumed != strlen(message) || kickers < 1 || kickers > SHOOTOUT_MAX_KICKERS)
	{
		PrintToChat(client, "%t", "Shootout_Kickers_Invalid", SHOOTOUT_MAX_KICKERS);
		return;
	}

	gMatchInput[client] = MATCH_INPUT_NONE;
	if (!StartShootoutSetup(client, kickers))
	{
		ShowPenaltyMenu(client);
	}
}

void ShowShootoutOrderMenu(int client, int team)
{
	if (!CanChooseShootoutOrder(client, team))
	{
		return;
	}

	int index = ShootoutIndex(team);
	Menu menu = new Menu(MenuHandlerShootoutOrder);
	char label[16];
	GetTeamNameServer(team, label, sizeof(label));
	char title[192];
	Format(title, sizeof(title), "%T", "Menu_Shootout_Order_Title", client, label, gShootoutOrderCount[index] + 1, GetShootoutOrderTarget(team));
	menu.SetTitle(title);

	char info[32];
	Format(info, sizeof(info), "%d:auto", team);
	char text[96];
	Format(text, sizeof(text), "%T", "Menu_Shootout_Order_Auto", client);
	menu.AddItem(info, text);

	for (int target = 1; target <= MaxClients; target++)
	{
		if (!IsShootoutEligible(target, team) || IsInShootoutOrder(team, target))
		{
			continue;
		}

		Format(info, sizeof(info), "%d:%d", team, GetClientUserId(target));
		char name[MAX_NAME_LENGTH];
		GetClientName(target, name, sizeof(name));
		menu.AddItem(info, name);
	}

	// No way out but picking: a closed menu comes back with !kickers.
	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandlerShootoutOrder(Menu menu, MenuAction action, int client, int item)
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

	char info[32];
	menu.GetItem(item, info, sizeof(info));
	int colon = FindCharInString(info, ':');
	if (colon == -1)
	{
		return 0;
	}

	int team = StringToInt(info);
	if (!CanChooseShootoutOrder(client, team))
	{
		return 0;
	}

	if (StrEqual(info[colon + 1], "auto"))
	{
		AutoCompleteShootoutOrder(team);
	}
	else
	{
		int kicker = GetClientOfUserId(StringToInt(info[colon + 1]));
		if (IsShootoutEligible(kicker, team) && !IsInShootoutOrder(team, kicker))
		{
			AddShootoutKicker(team, kicker);
		}
		if (!gShootoutOrderDone[ShootoutIndex(team)] && gShootoutOrderCount[ShootoutIndex(team)] >= GetShootoutOrderTarget(team))
		{
			FinishShootoutOrder(team, false);
		}
	}

	if (!gShootoutChoosing)
	{
		return 0;
	}

	int next = CanChooseShootoutOrder(client, team) ? team : GetShootoutTeamToChooseFor(client, false);
	if (next != 0)
	{
		ShowShootoutOrderMenu(client, next);
	}
	return 0;
}

public Action CmdKickers(int client, int args)
{
	if (!IsValidClient(client) || !CheckSoccerAvailable(client))
	{
		return Plugin_Handled;
	}

	if (!gShootoutChoosing)
	{
		PrintToChat(client, "%t", "Shootout_Kickers_Not_Choosing");
		return Plugin_Handled;
	}

	int team = GetShootoutTeamToChooseFor(client, true);
	if (team == 0)
	{
		PrintToChat(client, "%t", "Shootout_Kickers_Not_Yours");
		return Plugin_Handled;
	}

	ShowShootoutOrderMenu(client, team);
	return Plugin_Handled;
}

void AddShootoutKicker(int team, int client)
{
	int index = ShootoutIndex(team);
	if (gShootoutOrderCount[index] >= sizeof(gShootoutOrder[]))
	{
		return;
	}

	gShootoutOrder[index][gShootoutOrderCount[index]] = GetClientUserId(client);
	gShootoutOrderCount[index]++;
	char label[16];
	GetTeamNameServer(team, label, sizeof(label));
	PrintToChatAll("%t", "Shootout_Order_Pick", label, gShootoutOrderCount[index], client);
}

void AutoCompleteShootoutOrder(int team)
{
	int index = ShootoutIndex(team);
	int target = GetShootoutOrderTarget(team);
	for (int client = 1; client <= MaxClients && gShootoutOrderCount[index] < target; client++)
	{
		if (IsShootoutEligible(client, team) && !IsInShootoutOrder(team, client))
		{
			gShootoutOrder[index][gShootoutOrderCount[index]] = GetClientUserId(client);
			gShootoutOrderCount[index]++;
		}
	}
	FinishShootoutOrder(team, true);
}

// Fills in every order still open and starts the kicks.
void CompleteShootoutOrders()
{
	for (int team = TEAM_T; team <= TEAM_CT && gShootoutChoosing; team++)
	{
		if (!gShootoutOrderDone[ShootoutIndex(team)])
		{
			AutoCompleteShootoutOrder(team);
		}
	}
}

void FinishShootoutOrder(int team, bool automatic)
{
	int index = ShootoutIndex(team);
	if (gShootoutOrderDone[index])
	{
		return;
	}

	gShootoutOrderDone[index] = true;
	char label[16];
	GetTeamNameServer(team, label, sizeof(label));
	PrintToChatAll("%t", automatic ? "Shootout_Order_Auto_Done" : "Shootout_Order_Done", label);
	if (gShootoutOrderDone[0] && gShootoutOrderDone[1])
	{
		BeginShootoutKicks();
	}
}

void BeginShootoutKicks()
{
	gShootoutChoosing = false;
	KillTimerSafe(gShootoutReminderTimer);
	KillTimerSafe(gShootoutOrderTimer);
	if (gShootoutOrderCount[0] == 0 || gShootoutOrderCount[1] == 0)
	{
		PrintToChatAll("%t", "Penalty_Need_Players");
		EndShootoutState();
		return;
	}

	PrintShootoutOrder(TEAM_CT);
	PrintShootoutOrder(TEAM_T);

	gShootoutNextTeam = GetRandomInt(0, 1) == 0 ? TEAM_CT : TEAM_T;
	char label[16];
	GetTeamNameServer(gShootoutNextTeam, label, sizeof(label));
	PrintToChatAll("%t", "Shootout_Coin_Toss", label);
	PrintToChatAll("%t", "Shootout_Starting", RoundToFloor(SHOOTOUT_START_DELAY));

	gShootoutStarting = true;
	gShootoutStartTime = GetGameTime() + SHOOTOUT_START_DELAY;
	ArrangeShootoutPlayers(0, 0);
	KillTimerSafe(gShootoutTimer);
	gShootoutTimer = CreateTimer(SHOOTOUT_START_DELAY, TimerNextShootoutPenalty, _, TIMER_FLAG_NO_MAPCHANGE);
}

void PrintShootoutOrder(int team)
{
	int index = ShootoutIndex(team);
	char label[16];
	GetTeamNameServer(team, label, sizeof(label));
	char list[192];
	for (int i = 0; i < gShootoutOrderCount[index]; i++)
	{
		int client = GetClientOfUserId(gShootoutOrder[index][i]);
		if (client <= 0 || !IsClientInGame(client))
		{
			continue;
		}

		char entry[MAX_NAME_LENGTH + 8];
		Format(entry, sizeof(entry), "%d. %N", i + 1, client);
		// A long order goes over several chat lines.
		if (list[0] != '\0' && strlen(list) + strlen(entry) + 2 > 150)
		{
			PrintToChatAll("%t", "Shootout_Order_Line", label, list);
			list[0] = '\0';
		}
		if (list[0] != '\0')
		{
			StrCat(list, sizeof(list), "  ");
		}
		StrCat(list, sizeof(list), entry);
	}
	if (list[0] != '\0')
	{
		PrintToChatAll("%t", "Shootout_Order_Line", label, list);
	}
}

void StartNextShootoutPenalty()
{
	if (!gShootoutActive || gShootoutChoosing)
	{
		return;
	}

	gShootoutStarting = false;
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

	int defending = GetOppositeTeam(team);
	int goalkeeper = FindTeamGoalkeeper(defending);
	gShootoutNextTeam = defending;
	ArrangeShootoutPlayers(shooter, goalkeeper);
	if (!StartPenalty(team, shooter, goalkeeper, true))
	{
		FinishShootout();
		return;
	}
	PlaceShootoutGoalkeeper(goalkeeper, defending);
}

int GetNextShootoutShooter(int team)
{
	int index = ShootoutIndex(team);
	for (int attempt = 0; attempt < 2 * (MAXPLAYERS + 1); attempt++)
	{
		if (gShootoutOrderNext[index] >= gShootoutOrderCount[index])
		{
			// Everyone in the order has kicked: whoever on the team has not kicked
			// yet goes next, then the order starts over, as in a real shootout.
			ExtendShootoutOrder(team);
			if (gShootoutOrderNext[index] >= gShootoutOrderCount[index])
			{
				gShootoutOrderNext[index] = 0;
			}
			if (gShootoutOrderCount[index] == 0)
			{
				return 0;
			}
		}

		int client = GetClientOfUserId(gShootoutOrder[index][gShootoutOrderNext[index]]);
		gShootoutOrderNext[index]++;
		if (IsShootoutEligible(client, team))
		{
			return client;
		}
	}
	return 0;
}

void ExtendShootoutOrder(int team)
{
	int index = ShootoutIndex(team);
	int other = GetOppositeTeam(team);
	for (int client = 1; client <= MaxClients && gShootoutOrderCount[index] < sizeof(gShootoutOrder[]); client++)
	{
		if (IsShootoutEligible(client, team) && !IsInShootoutOrder(team, client) && !IsInShootoutOrder(other, client))
		{
			gShootoutOrder[index][gShootoutOrderCount[index]] = GetClientUserId(client);
			gShootoutOrderCount[index]++;
		}
	}
}

// Everyone but the kicker and the defending goalkeeper waits frozen at the
// waiting spot, so nobody gets in the way of a kick.
void ArrangeShootoutPlayers(int shooter, int goalkeeper)
{
	gShootoutFrozenShooter = 0;
	float spot[3];
	bool haveSpot = GetShootoutWaitSpot(spot);
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || !IsPlayerAlive(client) || GetClientTeam(client) < TEAM_T)
		{
			continue;
		}

		if (client == shooter || client == goalkeeper)
		{
			gShootoutWaiting[client] = false;
			SetEntityMoveType(client, MOVETYPE_WALK);
			continue;
		}

		if (gShootoutWaiting[client])
		{
			continue;
		}

		if (haveSpot)
		{
			TeleportToWaitingSlot(client, spot);
		}
		SetEntityMoveType(client, MOVETYPE_NONE);
		gShootoutWaiting[client] = true;
	}
}

void ReleaseShootoutPlayers()
{
	int frozen = GetClientOfUserId(gShootoutFrozenShooter);
	gShootoutFrozenShooter = 0;
	if (frozen > 0 && IsClientInGame(frozen) && IsPlayerAlive(frozen) && !gRedCard[frozen])
	{
		SetEntityMoveType(frozen, MOVETYPE_WALK);
	}

	for (int client = 1; client <= MaxClients; client++)
	{
		if (!gShootoutWaiting[client])
		{
			continue;
		}

		gShootoutWaiting[client] = false;
		if (IsClientInGame(client) && IsPlayerAlive(client) && !gRedCard[client])
		{
			SetEntityMoveType(client, MOVETYPE_WALK);
		}
	}
}

// A kick is taken once: the kicker stays still until the result, so a save or
// a ball off the post cannot be knocked in again.
void FreezeShootoutShooter(int client)
{
	if (!IsValidClient(client) || !IsPlayerAlive(client))
	{
		return;
	}

	SetEntityMoveType(client, MOVETYPE_NONE);
	gShootoutFrozenShooter = GetClientUserId(client);
}

// A kick cut short by a round restart (the round timer, an admin) is taken
// again by the same kicker once the new round starts.
void VoidShootoutKick()
{
	if (!gShootoutActive || !gPenaltyActive)
	{
		return;
	}

	int index = ShootoutIndex(gPenaltyTeam);
	if (gShootoutOrderNext[index] > 0)
	{
		gShootoutOrderNext[index]--;
	}
	gShootoutNextTeam = gPenaltyTeam;
	KillPenaltyTimer();
	gPenaltyActive = false;
	gPenaltyWaitingForKick = false;
	gPenaltyShooter = 0;
	gPenaltyGoalkeeper = 0;
	gShootoutFrozenShooter = 0;
}

// The marked waiting spot, or the centre spot.
bool GetShootoutWaitSpot(float spot[3])
{
	if (gShootoutWaitSpotValid)
	{
		spot = gShootoutWaitSpot;
		return true;
	}
	if (gBallStartPositionValid)
	{
		spot = gBallStartPosition;
		return true;
	}
	return false;
}

// Places a player in the first free spot on rings around the centre, so the
// players waiting there never end up inside each other.
void TeleportToWaitingSlot(int client, const float center[3])
{
	float still[3];
	float slot[3];
	for (int ring = 0; ring <= 6; ring++)
	{
		int count = ring == 0 ? 1 : ring * 6;
		float radius = 44.0 * float(ring);
		for (int i = 0; i < count; i++)
		{
			float angle = 2.0 * FLOAT_PI * float(i) / float(count);
			float candidate[3];
			candidate[0] = center[0] + radius * Cosine(angle);
			candidate[1] = center[1] + radius * Sine(angle);
			candidate[2] = center[2];
			if (FindStandingSpot(candidate, client, slot))
			{
				TeleportEntity(client, slot, NULL_VECTOR, still);
				return;
			}
		}
	}
	TeleportEntity(client, center, NULL_VECTOR, still);
}

// The floor under a point, if a player fits standing there.
bool FindStandingSpot(const float around[3], int client, float result[3])
{
	float top[3];
	float bottom[3];
	top = around;
	bottom = around;
	top[2] += 64.0;
	bottom[2] -= 256.0;
	Handle trace = TR_TraceRayFilterEx(top, bottom, MASK_PLAYERSOLID_BRUSHONLY, RayType_EndPoint, TraceFilterFloor, client);
	bool hit = TR_DidHit(trace);
	if (hit)
	{
		TR_GetEndPosition(result, trace);
	}
	delete trace;
	// Not down a level, behind a wall or under the stands.
	if (!hit || around[2] - result[2] > 160.0)
	{
		return false;
	}

	result[2] += 2.0;
	float mins[3] = {-16.0, -16.0, 0.0};
	float maxs[3] = {16.0, 16.0, 72.0};
	trace = TR_TraceHullFilterEx(result, result, mins, maxs, MASK_PLAYERSOLID, TraceFilterNotSelf, client);
	bool blocked = TR_DidHit(trace);
	delete trace;
	return !blocked;
}

public bool TraceFilterNotSelf(int entity, int contentsMask, any self)
{
	return entity != self;
}

// The floor under a spot: the world and fixed brushes, not players or balls.
public bool TraceFilterFloor(int entity, int contentsMask, any self)
{
	if (entity >= 1 && entity <= MaxClients)
	{
		return false;
	}
	if (entity > MaxClients && IsValidEntity(entity))
	{
		char classname[32];
		GetEntityClassname(entity, classname, sizeof(classname));
		if (StrContains(classname, "prop_physics") == 0 || StrEqual(classname, "func_physbox"))
		{
			return false;
		}
	}
	return true;
}

// The defending goalkeeper starts on the goal line, facing the pitch. The goal
// line is found from the goalkeeper area, which is marked standing on it.
void PlaceShootoutGoalkeeper(int goalkeeper, int team)
{
	if (!IsValidClient(goalkeeper) || !IsPlayerAlive(goalkeeper))
	{
		return;
	}

	float point[3];
	float angles[3];
	if (!GetGoalLinePoint(team, point, angles) && !GetGoalLineFromKickSpot(point, angles))
	{
		return;
	}

	float spot[3];
	float still[3];
	if (!FindStandingSpot(point, goalkeeper, spot))
	{
		spot = point;
	}
	TeleportEntity(goalkeeper, spot, angles, still);
	SetEntityMoveType(goalkeeper, MOVETYPE_WALK);
	gShootoutWaiting[goalkeeper] = false;
}

// The middle of a team's goal line and the way the pitch lies from it.
bool GetGoalLinePoint(int team, float point[3], float angles[3])
{
	return GetGoalLineFromArea(team, point, angles) || GetGoalLineFromTrigger(team, point, angles);
}

void SetFacingPitch(int depthAxis, float direction, float angles[3])
{
	angles[0] = 0.0;
	angles[2] = 0.0;
	if (depthAxis == 0)
	{
		angles[1] = direction > 0.0 ? 0.0 : 180.0;
	}
	else
	{
		angles[1] = direction > 0.0 ? 90.0 : 270.0;
	}
}

// The goal ball trigger sits on the goal line, between the posts.
bool GetGoalLineFromTrigger(int team, float point[3], float angles[3])
{
	if (!gBallStartPositionValid)
	{
		return false;
	}

	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "trigger_once")) != -1)
	{
		if (!IsBallGoalTrigger(entity) || GetGoalTriggerTeam(entity) != team)
		{
			continue;
		}

		float center[3];
		GetGoalTriggerCenter(entity, center);
		float toPitchX = gBallStartPosition[0] - center[0];
		float toPitchY = gBallStartPosition[1] - center[1];
		int depthAxis = FloatAbs(toPitchX) >= FloatAbs(toPitchY) ? 0 : 1;
		float direction = (depthAxis == 0 ? toPitchX : toPitchY) >= 0.0 ? 1.0 : -1.0;
		point = center;
		point[depthAxis] += direction * 40.0;
		SetFacingPitch(depthAxis, direction, angles);
		return true;
	}
	return false;
}

// Last resort for the goalkeeper: straight behind the kick spot, as far from it
// as a penalty spot is from its goal.
bool GetGoalLineFromKickSpot(float point[3], float angles[3])
{
	if (!gBallStartPositionValid)
	{
		return false;
	}

	float direction[3];
	direction[0] = gPenaltyKickSpot[0] - gBallStartPosition[0];
	direction[1] = gPenaltyKickSpot[1] - gBallStartPosition[1];
	if (NormalizeVector(direction, direction) <= 0.0)
	{
		return false;
	}

	point = gPenaltyKickSpot;
	point[0] += direction[0] * PENALTY_DEFAULT_SPOT_DISTANCE;
	point[1] += direction[1] * PENALTY_DEFAULT_SPOT_DISTANCE;
	angles[0] = 0.0;
	angles[1] = RadToDeg(ArcTangent2(-direction[1], -direction[0]));
	angles[2] = 0.0;
	return true;
}

bool GetGoalLineFromArea(int team, float point[3], float angles[3])
{
	int area = GetTeamGkArea(team);
	if (area == -1 || !gGkAreaValid[area] || !gBallStartPositionValid)
	{
		return false;
	}

	float center[3];
	for (int axis = 0; axis < 3; axis++)
	{
		center[axis] = (gGkAreaMin[area][axis] + gGkAreaMax[area][axis]) / 2.0;
	}

	float toPitchX = gBallStartPosition[0] - center[0];
	float toPitchY = gBallStartPosition[1] - center[1];
	int depthAxis = FloatAbs(toPitchX) >= FloatAbs(toPitchY) ? 0 : 1;
	int widthAxis = 1 - depthAxis;
	float direction = (depthAxis == 0 ? toPitchX : toPitchY) >= 0.0 ? 1.0 : -1.0;
	float goalEdge = direction > 0.0 ? gGkAreaMin[area][depthAxis] : gGkAreaMax[area][depthAxis];

	point[depthAxis] = goalEdge + direction * GK_AREA_BEHIND;
	point[widthAxis] = center[widthAxis];
	point[2] = gGkAreaMin[area][2] + GK_AREA_FLOOR_MARGIN;
	SetFacingPitch(depthAxis, direction, angles);
	return true;
}

// Without a marked penalty spot, the spot in front of the goal a team defends,
// from its goalkeeper area.
bool GetDefaultPenaltySpot(int defendingTeam, float spot[3])
{
	float point[3];
	float angles[3];
	if (!GetGoalLinePoint(defendingTeam, point, angles))
	{
		return false;
	}

	spot = point;
	spot[0] += Cosine(DegToRad(angles[1])) * PENALTY_DEFAULT_SPOT_DISTANCE;
	spot[1] += Sine(DegToRad(angles[1])) * PENALTY_DEFAULT_SPOT_DISTANCE;
	return true;
}

bool HasDefaultPenaltySpots()
{
	float spot[3];
	return GetDefaultPenaltySpot(TEAM_CT, spot) && GetDefaultPenaltySpot(TEAM_T, spot);
}

// The time to take a penalty, with the warning whistle near its end.
void StartPenaltyKickClock()
{
	KillPenaltyTimer();
	float shotTime = gCvarPenaltyShotTime.FloatValue;
	gPenaltyDeadline = GetGameTime() + shotTime;
	gPenaltyTimer = CreateTimer(shotTime, TimerPenaltyTimeout, _, TIMER_FLAG_NO_MAPCHANGE);
	float warning = gCvarPenaltyWarningTime.FloatValue;
	if (warning > 0.0 && warning < shotTime)
	{
		gPenaltyWarningTimer = CreateTimer(shotTime - warning, TimerPenaltyWarning, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

// After the kick: the time for the ball to go in.
void StartPenaltyResultClock()
{
	KillPenaltyTimer();
	float resultTime = gCvarPenaltyResultTime.FloatValue;
	gPenaltyDeadline = GetGameTime() + resultTime;
	gPenaltyTimer = CreateTimer(resultTime, TimerPenaltyTimeout, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action TimerPenaltyWarning(Handle timer)
{
	gPenaltyWarningTimer = null;
	if (!gPenaltyActive || !gPenaltyWaitingForKick || gPaused || gUnpausing || !IsValidClient(gPenaltyShooter))
	{
		return Plugin_Stop;
	}

	int seconds = RoundToCeil(gPenaltyDeadline - GetGameTime());
	PlayPenaltyWhistle();
	PrintCenterText(gPenaltyShooter, "%t", "Penalty_Hurry", seconds);
	PrintToChat(gPenaltyShooter, "%t", "Penalty_Hurry", seconds);
	return Plugin_Stop;
}

void RecordShootoutResult(int team, int kick, bool scored)
{
	if (kick >= 0 && kick < SHOOTOUT_MAX_SLOTS)
	{
		gShootoutResult[ShootoutIndex(team)][kick] = scored ? SHOOTOUT_RESULT_GOAL : SHOOTOUT_RESULT_MISS;
	}
}

void FinishShootout()
{
	int winner = 0;
	if (gShootoutScoreCT > gShootoutScoreT)
	{
		winner = TEAM_CT;
	}
	else if (gShootoutScoreT > gShootoutScoreCT)
	{
		winner = TEAM_T;
	}

	if (winner != 0)
	{
		char label[16];
		GetTeamNameServer(winner, label, sizeof(label));
		int winnerScore = winner == TEAM_CT ? gShootoutScoreCT : gShootoutScoreT;
		int loserScore = winner == TEAM_CT ? gShootoutScoreT : gShootoutScoreCT;
		PrintToChatAll("%t", "Penalty_Winner", label, winnerScore, loserScore);
		PrintCenterTextAll("%t", "Shootout_Winner_Center", label);
	}
	else
	{
		PrintToChatAll("%t", "Penalty_No_Winner");
	}
	PlayShootoutSound(gCvarShootoutEndWhistle);

	ReleaseShootoutPlayers();
	gShootoutWinner = winner;
	gShootoutBoardUntil = GetGameTime() + SHOOTOUT_BOARD_TIME;
	gShootoutActive = false;
	gShootoutChoosing = false;
	gShootoutStarting = false;
	gShootoutWaitingRoundStart = false;
	KillTimerSafe(gShootoutTimer);
	KillTimerSafe(gShootoutReminderTimer);
	KillTimerSafe(gShootoutOrderTimer);
	// The last ball may still roll into a goal: goals stay harmless until a
	// fresh round puts it back in the middle.
	gPenaltyGoalHoldUntil = GetGameTime() + SHOOTOUT_END_HOLD_TIME;
	KillTimerSafe(gShootoutRestartTimer);
	gShootoutRestartTimer = CreateTimer(SHOOTOUT_RESTART_DELAY, TimerShootoutRestart, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action TimerShootoutRestart(Handle timer)
{
	gShootoutRestartTimer = null;
	if (!gMatchLive && !gShootoutActive && !gPenaltyActive)
	{
		ServerCommand("mp_restartgame 1");
	}
	return Plugin_Stop;
}

void CancelShootout(int admin)
{
	if (!gShootoutActive)
	{
		ReplyShootout(admin, "Shootout_Not_Active");
		return;
	}

	EndShootoutState();
	char adminName[MAX_NAME_LENGTH];
	GetAdminDisplayName(admin, adminName, sizeof(adminName));
	PrintToChatAll("%t", "Shootout_Cancelled", adminName);
}

// Clears every trace of a shootout, including a kick in progress.
void EndShootoutState()
{
	ReleaseShootoutPlayers();
	if (gShootoutActive && gPenaltyActive)
	{
		KillPenaltyTimer();
		gPenaltyActive = false;
		gPenaltyWaitingForKick = false;
		gPenaltyShooter = 0;
		gPenaltyGoalkeeper = 0;
	}

	KillTimerSafe(gShootoutTimer);
	KillTimerSafe(gShootoutReminderTimer);
	KillTimerSafe(gShootoutOrderTimer);
	KillTimerSafe(gShootoutRestartTimer);
	gShootoutActive = false;
	gShootoutChoosing = false;
	gShootoutStarting = false;
	gShootoutWaitingRoundStart = false;
	gShootoutKickers = 0;
	gShootoutScoreCT = 0;
	gShootoutScoreT = 0;
	gShootoutTakenCT = 0;
	gShootoutTakenT = 0;
	gShootoutNextTeam = 0;
	gShootoutWinner = 0;
	gShootoutBoardUntil = 0.0;
	gPenaltyGoalHoldUntil = 0.0;
	for (int index = 0; index < 2; index++)
	{
		gShootoutChooser[index] = 0;
		gShootoutOrderCount[index] = 0;
		gShootoutOrderNext[index] = 0;
		gShootoutOrderDone[index] = false;
		for (int kick = 0; kick < SHOOTOUT_MAX_SLOTS; kick++)
		{
			gShootoutResult[index][kick] = 0;
		}
	}
}

// Goal detection without the map's goal triggers killing anyone.
//
// The ball goal triggers are the trigger_once entities that fire for physics
// objects; they enable the trigger_hurt that kills the conceding team. Their
// touch is held back while penalties are taken, and turned into the result.
void HookShootoutGoalTriggers()
{
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "trigger_once")) != -1)
	{
		if (!IsBallGoalTrigger(entity))
		{
			continue;
		}

		SDKUnhook(entity, SDKHook_StartTouch, HookGoalTriggerTouch);
		SDKUnhook(entity, SDKHook_Touch, HookGoalTriggerTouch);
		SDKHook(entity, SDKHook_StartTouch, HookGoalTriggerTouch);
		SDKHook(entity, SDKHook_Touch, HookGoalTriggerTouch);
	}
}

bool IsBallGoalTrigger(int entity)
{
	char name[MAX_ENTITY_NAME];
	GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));
	if (StrEqual(name, "end_stoppage_time", false))
	{
		return false;
	}
	// Spawnflag 8: fires for physics objects, which is the ball.
	return (GetEntProp(entity, Prop_Data, "m_spawnflags") & 8) != 0;
}

bool ShouldHoldGoalTriggers()
{
	return gShootoutActive
		|| (gPenaltyActive && !gMatchLive)
		|| GetGameTime() < gPenaltyGoalHoldUntil;
}

public Action HookGoalTriggerTouch(int trigger, int other)
{
	bool matchBall = IsBallEntity(other);
	if (!ShouldHoldGoalTriggers() || (!matchBall && !IsTrainingBall(other)))
	{
		return Plugin_Continue;
	}

	if (matchBall && gPenaltyActive && !gPenaltyWaitingForKick && !IsMatchPenalty())
	{
		int conceding = GetGoalTriggerTeam(trigger);
		bool scored = conceding == 0 || GetOppositeTeam(conceding) == gPenaltyTeam;
		gPenaltyGoalHoldUntil = GetGameTime() + PENALTY_GOAL_HOLD_TIME;
		ResolvePenalty(scored);
	}
	return Plugin_Handled;
}

void GetGoalTriggerCenter(int trigger, float center[3])
{
	float origin[3];
	float mins[3];
	float maxs[3];
	GetEntPropVector(trigger, Prop_Send, "m_vecOrigin", origin);
	GetEntPropVector(trigger, Prop_Send, "m_vecMins", mins);
	GetEntPropVector(trigger, Prop_Send, "m_vecMaxs", maxs);
	for (int axis = 0; axis < 3; axis++)
	{
		center[axis] = origin[axis] + (mins[axis] + maxs[axis]) / 2.0;
	}
}

// The team whose goal a trigger sits in: the nearer team goal reference.
int GetGoalTriggerTeam(int trigger)
{
	float center[3];
	GetGoalTriggerCenter(trigger, center);

	float goalCT[3];
	float goalT[3];
	if (!GetTeamGoalReference(TEAM_CT, goalCT) || !GetTeamGoalReference(TEAM_T, goalT))
	{
		return 0;
	}
	return GetVectorDistance(center, goalCT) <= GetVectorDistance(center, goalT) ? TEAM_CT : TEAM_T;
}

// The penalty spot and the waiting spot are kept per map.
void LoadPenaltySpots()
{
	gPenaltySpotValid = false;
	gShootoutWaitSpotValid = false;

	char map[PLATFORM_MAX_PATH];
	GetCurrentMap(map, sizeof(map));
	KeyValues kv = new KeyValues("PenaltySpots");
	if (kv.ImportFromFile(gPenaltySpotsPath) && kv.JumpToKey(map))
	{
		gPenaltySpotValid = ReadSpot(kv, "penalty_spot", gPenaltySpot);
		gShootoutWaitSpotValid = ReadSpot(kv, "players_spot", gShootoutWaitSpot);
	}
	delete kv;
}

bool ReadSpot(KeyValues kv, const char[] key, float spot[3])
{
	char value[64];
	kv.GetString(key, value, sizeof(value));
	if (value[0] == '\0')
	{
		return false;
	}
	kv.GetVector(key, spot);
	return true;
}

bool SavePenaltySpots()
{
	char map[PLATFORM_MAX_PATH];
	GetCurrentMap(map, sizeof(map));
	KeyValues kv = new KeyValues("PenaltySpots");
	kv.ImportFromFile(gPenaltySpotsPath);
	kv.JumpToKey(map, true);
	if (gPenaltySpotValid)
	{
		kv.SetVector("penalty_spot", gPenaltySpot);
	}
	if (gShootoutWaitSpotValid)
	{
		kv.SetVector("players_spot", gShootoutWaitSpot);
	}
	kv.Rewind();
	bool saved = kv.ExportToFile(gPenaltySpotsPath);
	delete kv;
	return saved;
}

void SetShootoutWaitSpot(int client)
{
	if (!IsPlayerAlive(client))
	{
		PrintToChat(client, "%t", "Penalty_WaitSpot_Need_Alive");
		return;
	}

	GetClientAbsOrigin(client, gShootoutWaitSpot);
	gShootoutWaitSpotValid = true;
	SavePenaltySpots();
	PrintToChat(client, "%t", "Penalty_WaitSpot_Set");
	DrawPenaltyMarks(client);
}

// Shows the admin the penalty spot at both ends (yellow) and where players
// wait (green), for SHOOTOUT_MARK_TIME seconds.
void DrawPenaltyMarks(int client)
{
	if (gBeamSprite == -1)
	{
		return;
	}

	int yellow[4] = {255, 220, 0, 255};
	int green[4] = {60, 220, 90, 255};
	bool drew;
	if (gPenaltySpotValid)
	{
		DrawSpotMark(client, gPenaltySpot, 12.0, yellow);
		if (gBallStartPositionValid)
		{
			float mirrored[3];
			mirrored[0] = 2.0 * gBallStartPosition[0] - gPenaltySpot[0];
			mirrored[1] = 2.0 * gBallStartPosition[1] - gPenaltySpot[1];
			mirrored[2] = gPenaltySpot[2];
			DrawSpotMark(client, mirrored, 12.0, yellow);
		}
		drew = true;
	}
	else
	{
		// Not marked: show where the kicks will be taken from the goalkeeper areas.
		for (int team = TEAM_T; team <= TEAM_CT; team++)
		{
			float spot[3];
			if (GetDefaultPenaltySpot(team, spot))
			{
				DrawSpotMark(client, spot, 12.0, yellow);
				drew = true;
			}
		}
	}

	float wait[3];
	if (GetShootoutWaitSpot(wait))
	{
		DrawSpotMark(client, wait, 64.0, green);
		drew = true;
	}

	if (!drew)
	{
		PrintToChat(client, "%t", "Penalty_Marks_None");
	}
}

void DrawSpotMark(int client, const float point[3], float halfSize, const int color[4])
{
	float mins[3];
	float maxs[3];
	mins[0] = point[0] - halfSize;
	mins[1] = point[1] - halfSize;
	mins[2] = point[2] - GK_AREA_FLOOR_MARGIN;
	maxs[0] = point[0] + halfSize;
	maxs[1] = point[1] + halfSize;
	maxs[2] = point[2] + 72.0;
	DrawBox(client, mins, maxs, color);

	float top[3];
	top = point;
	top[2] += 72.0;
	DrawBeam(client, point, top, color);
}

bool IsShootoutBoardVisible()
{
	return gShootoutActive || GetGameTime() < gShootoutBoardUntil;
}

// The HUD during a shootout: the score, each team's kicks (O goal, X miss,
// - still to come) and what is going on.
void FormatShootoutBoard(int client, char[] buffer, int maxlen)
{
	char title[64];
	Format(title, sizeof(title), "%T", "Hud_Shootout_Title", client, gShootoutScoreCT, gShootoutScoreT);
	char rowCT[64];
	char rowT[64];
	FormatShootoutRow(TEAM_CT, "CT", rowCT, sizeof(rowCT));
	FormatShootoutRow(TEAM_T, "T ", rowT, sizeof(rowT));

	char status[128];
	if (gShootoutChoosing)
	{
		Format(status, sizeof(status), "%T", "Hud_Shootout_Choosing", client);
	}
	else if (gShootoutStarting)
	{
		int seconds = RoundToCeil(gShootoutStartTime - GetGameTime());
		Format(status, sizeof(status), "%T", "Hud_Shootout_Starting", client, seconds > 0 ? seconds : 0);
	}
	else if (gShootoutActive && gPenaltyActive && IsValidClient(gPenaltyShooter))
	{
		char team[4];
		strcopy(team, sizeof(team), gPenaltyTeam == TEAM_CT ? "CT" : "T");
		if (gPenaltyWaitingForKick)
		{
			int seconds = RoundToCeil(gPenaltyDeadline - GetGameTime());
			Format(status, sizeof(status), "%T", "Hud_Shootout_Kick", client, gPenaltyShooter, team, seconds > 0 ? seconds : 0);
		}
		else
		{
			Format(status, sizeof(status), "%T", "Hud_Shootout_Shot", client, gPenaltyShooter, team);
		}
	}
	else if (gShootoutActive)
	{
		Format(status, sizeof(status), "%T", "Hud_Shootout_Next", client);
	}
	else if (gShootoutWinner != 0)
	{
		Format(status, sizeof(status), "%T", "Hud_Shootout_Winner", client, gShootoutWinner == TEAM_CT ? "CT" : "T");
	}
	else
	{
		Format(status, sizeof(status), "%T", "Hud_Shootout_NoWinner", client);
	}

	Format(buffer, maxlen, "%s\n%s\n%s\n%s", title, rowCT, rowT, status);
}

void FormatShootoutRow(int team, const char[] label, char[] buffer, int maxlen)
{
	int index = ShootoutIndex(team);
	int slots = gShootoutKickers;
	if (gShootoutTakenCT > slots)
	{
		slots = gShootoutTakenCT;
	}
	if (gShootoutTakenT > slots)
	{
		slots = gShootoutTakenT;
	}
	if (slots > SHOOTOUT_MAX_SLOTS)
	{
		slots = SHOOTOUT_MAX_SLOTS;
	}
	// At most SHOOTOUT_HUD_SLOTS kicks, following the ones being taken.
	int taken = gShootoutTakenCT > gShootoutTakenT ? gShootoutTakenCT : gShootoutTakenT;
	int last = taken + 1 > SHOOTOUT_HUD_SLOTS ? taken + 1 : SHOOTOUT_HUD_SLOTS;
	if (last > slots)
	{
		last = slots;
	}
	int first = last > SHOOTOUT_HUD_SLOTS ? last - SHOOTOUT_HUD_SLOTS : 0;

	strcopy(buffer, maxlen, label);
	for (int kick = first; kick < last; kick++)
	{
		switch (gShootoutResult[index][kick])
		{
			case SHOOTOUT_RESULT_GOAL:
			{
				StrCat(buffer, maxlen, "  O");
			}
			case SHOOTOUT_RESULT_MISS:
			{
				StrCat(buffer, maxlen, "  X");
			}
			default:
			{
				StrCat(buffer, maxlen, "  -");
			}
		}
	}
}
