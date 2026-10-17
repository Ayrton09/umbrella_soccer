// Saves.
//
// Each goal has a goalkeeper area: a box in front of it, stored per map in
// configs/umbrella_soccer_gk_areas.cfg and marked in game from the admin menu.
// A player, goalkeeper or defender, who touches the ball inside their own area
// right after an opponent touched it makes a save, counted and announced on
// that touch. If the ball still goes into their goal before anyone else touches
// it, the save is quietly taken back and the goal goes to the opponent who shot.

#define GK_AREA_T 0
#define GK_AREA_CT 1
#define GK_AREA_FLOOR_MARGIN 32.0
#define GK_AREA_HEIGHT 256.0
#define GK_AREA_BEHIND 48.0
#define GK_AREA_BEAM_TIME 10.0

ConVar gCvarSaves;
ConVar gCvarRankingPointsSave;
ConVar gCvarGkAreaWidth;
ConVar gCvarGkAreaDepth;

char gGkAreasPath[PLATFORM_MAX_PATH];
float gGkAreaMin[2][3];
float gGkAreaMax[2][3];
bool gGkAreaValid[2];

// The goalkeeper whose save nobody else has touched since, the team whose
// goal it was, and who shot.
int gLastSaver;
int gLastSaveTeam;
int gLastSaveShooter;
int gBeamSprite = -1;
int gHaloSprite = -1;

void SavesOnPluginStart()
{
	gCvarSaves = CreateConVar("sm_soccer_saves", "1", "Count saves: touching the ball inside your own goalkeeper area right after an opponent.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	gCvarRankingPointsSave = CreateConVar("soccer_mod_ranking_points_save", "5", "Points received for a save, on top of the interception and hit points of that touch. Original default: 10.", FCVAR_NOTIFY, true, -100.0, true, 100.0);
	gCvarGkAreaWidth = CreateConVar("sm_soccer_gk_area_width", "640", "Width of a goalkeeper area marked from the admin menu, in units, centred on the goal.", FCVAR_NONE, true, 64.0, true, 4096.0);
	gCvarGkAreaDepth = CreateConVar("sm_soccer_gk_area_depth", "224", "Depth of a goalkeeper area marked from the admin menu, in units, from the goal line towards the pitch.", FCVAR_NONE, true, 64.0, true, 4096.0);
	BuildPath(Path_SM, gGkAreasPath, sizeof(gGkAreasPath), "configs/umbrella_soccer_gk_areas.cfg");
}

void SavesOnMapStart()
{
	ClearLastSave();
	gBeamSprite = PrecacheModel("sprites/laser.vmt", true);
	gHaloSprite = PrecacheModel("sprites/halo01.vmt", true);
	LoadGoalkeeperAreas();
}

// Safety net for a plugin loaded mid-map: if the sprites and the areas were
// not set up yet, nothing could be drawn or counted until a map change.
void SavesOnConfigsExecuted()
{
	if (gBeamSprite == -1)
	{
		SavesOnMapStart();
	}
}

void SavesOnRoundStart()
{
	ClearLastSave();
}

void SavesOnClientDisconnect(int client)
{
	if (gLastSaver == client)
	{
		ClearLastSave();
	}
	else if (gLastSaveShooter == client)
	{
		// The save can still be taken back; the goal just has no known scorer.
		gLastSaveShooter = 0;
	}
}

void ClearLastSave()
{
	gLastSaver = 0;
	gLastSaveTeam = 0;
	gLastSaveShooter = 0;
}

int GetTeamGkArea(int team)
{
	if (team == TEAM_T)
	{
		return GK_AREA_T;
	}
	if (team == TEAM_CT)
	{
		return GK_AREA_CT;
	}
	return -1;
}

bool IsPointInGkArea(int area, const float point[3])
{
	if (area < 0 || !gGkAreaValid[area])
	{
		return false;
	}

	for (int axis = 0; axis < 3; axis++)
	{
		if (point[axis] < gGkAreaMin[area][axis] || point[axis] > gGkAreaMax[area][axis])
		{
			return false;
		}
	}
	return true;
}

// Called for every counted touch, before the toucher history moves on.
void SavesOnBallTouch(int client, int ball, int previousToucher)
{
	// Anyone else touching the ball makes the last save final.
	if (gLastSaver != 0 && client != gLastSaver)
	{
		ClearLastSave();
	}

	if (!gCvarSaves.BoolValue || gPenaltyActive || gShootoutActive || !IsValidClient(previousToucher))
	{
		return;
	}

	int team = GetClientTeam(client);
	int previousTeam = GetClientTeam(previousToucher);
	if (team < TEAM_T || previousTeam < TEAM_T || team == previousTeam || !IsValidEntity(ball))
	{
		return;
	}

	float origin[3];
	GetEntPropVector(ball, Prop_Send, "m_vecOrigin", origin);
	if (!IsPointInGkArea(GetTeamGkArea(team), origin))
	{
		return;
	}

	gLastSaver = client;
	gLastSaveTeam = team;
	gLastSaveShooter = previousToucher;
	AddPlayerPoints(client, gCvarRankingPointsSave.IntValue);
	RankingAddStat(client, RANK_STAT_SAVES, 1);
	PrintToChatAll("%t", "Save_Announce", client);
}

// Called for every goal. When the ball went in straight off a save, the save is
// taken back and the opponent who shot is returned as the scorer, or -1 when
// they are gone or changed sides. Any other goal returns 0.
int SavesOnGoal(int scoringTeam)
{
	int saver = gLastSaver;
	int saveTeam = gLastSaveTeam;
	int shooter = gLastSaveShooter;
	ClearLastSave();
	if (!IsValidClient(saver) || saveTeam == scoringTeam)
	{
		return 0;
	}

	AddPlayerPoints(saver, -gCvarRankingPointsSave.IntValue);
	RankingAddStat(saver, RANK_STAT_SAVES, -1);

	if (IsValidClient(shooter) && GetClientTeam(shooter) == scoringTeam)
	{
		return shooter;
	}
	return -1;
}

void LoadGoalkeeperAreas()
{
	gGkAreaValid[GK_AREA_T] = false;
	gGkAreaValid[GK_AREA_CT] = false;

	char map[PLATFORM_MAX_PATH];
	GetCurrentMap(map, sizeof(map));

	KeyValues kv = new KeyValues("GoalkeeperAreas");
	if (kv.ImportFromFile(gGkAreasPath) && kv.JumpToKey(map))
	{
		ReadGkArea(kv, "t", GK_AREA_T);
		ReadGkArea(kv, "ct", GK_AREA_CT);
	}
	delete kv;
}

void ReadGkArea(KeyValues kv, const char[] key, int area)
{
	if (!kv.JumpToKey(key))
	{
		return;
	}

	kv.GetVector("min", gGkAreaMin[area]);
	kv.GetVector("max", gGkAreaMax[area]);
	gGkAreaValid[area] = gGkAreaMin[area][0] < gGkAreaMax[area][0]
		&& gGkAreaMin[area][1] < gGkAreaMax[area][1]
		&& gGkAreaMin[area][2] < gGkAreaMax[area][2];
	kv.GoBack();
}

bool SaveGoalkeeperAreas()
{
	char map[PLATFORM_MAX_PATH];
	GetCurrentMap(map, sizeof(map));

	KeyValues kv = new KeyValues("GoalkeeperAreas");
	kv.ImportFromFile(gGkAreasPath);
	kv.JumpToKey(map, true);
	WriteGkArea(kv, "t", GK_AREA_T);
	WriteGkArea(kv, "ct", GK_AREA_CT);
	kv.Rewind();
	bool saved = kv.ExportToFile(gGkAreasPath);
	delete kv;
	return saved;
}

void WriteGkArea(KeyValues kv, const char[] key, int area)
{
	if (!gGkAreaValid[area])
	{
		return;
	}

	kv.JumpToKey(key, true);
	kv.SetVector("min", gGkAreaMin[area]);
	kv.SetVector("max", gGkAreaMax[area]);
	kv.GoBack();
}

// Builds an area from where the admin stands: the middle of the goal line. It
// runs along the pitch towards the centre spot, so where the admin looks does
// not matter; only without a known centre spot is the view direction used.
void BuildGkAreaFromPosition(int client, int area)
{
	float origin[3];
	GetClientAbsOrigin(client, origin);

	float toPitch[3];
	if (gBallStartPositionValid)
	{
		toPitch[0] = gBallStartPosition[0] - origin[0];
		toPitch[1] = gBallStartPosition[1] - origin[1];
	}
	if (!gBallStartPositionValid || (toPitch[0] == 0.0 && toPitch[1] == 0.0))
	{
		float angles[3];
		GetClientEyeAngles(client, angles);
		GetAngleVectors(angles, toPitch, NULL_VECTOR, NULL_VECTOR);
	}

	int depthAxis = FloatAbs(toPitch[0]) >= FloatAbs(toPitch[1]) ? 0 : 1;
	int widthAxis = 1 - depthAxis;
	float direction = toPitch[depthAxis] < 0.0 ? -1.0 : 1.0;
	float back = origin[depthAxis] - direction * GK_AREA_BEHIND;
	float front = origin[depthAxis] + direction * gCvarGkAreaDepth.FloatValue;
	float halfWidth = gCvarGkAreaWidth.FloatValue / 2.0;

	gGkAreaMin[area][depthAxis] = back < front ? back : front;
	gGkAreaMax[area][depthAxis] = back > front ? back : front;
	gGkAreaMin[area][widthAxis] = origin[widthAxis] - halfWidth;
	gGkAreaMax[area][widthAxis] = origin[widthAxis] + halfWidth;
	gGkAreaMin[area][2] = origin[2] - GK_AREA_FLOOR_MARGIN;
	gGkAreaMax[area][2] = origin[2] + GK_AREA_HEIGHT;
	gGkAreaValid[area] = true;
}

void ShowGkAreaMenu(int client)
{
	Menu menu = new Menu(MenuHandlerGkArea);
	char stateCT[16];
	char stateT[16];
	Format(stateCT, sizeof(stateCT), "%T", gGkAreaValid[GK_AREA_CT] ? "State_Yes" : "State_No", client);
	Format(stateT, sizeof(stateT), "%T", gGkAreaValid[GK_AREA_T] ? "State_Yes" : "State_No", client);
	char title[128];
	Format(title, sizeof(title), "%T", "Menu_GkAreas_Title", client, stateCT, stateT);
	menu.SetTitle(title);
	AddMenuItemPhrase(menu, client, "ct", "Menu_GkArea_Mark_CT");
	AddMenuItemPhrase(menu, client, "t", "Menu_GkArea_Mark_T");
	AddMenuItemPhrase(menu, client, "show", "Menu_GkArea_Show");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandlerGkArea(Menu menu, MenuAction action, int client, int item)
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

	char info[16];
	menu.GetItem(item, info, sizeof(info));
	if (StrEqual(info, "show"))
	{
		DrawGkAreas(client);
	}
	else if (!IsPlayerAlive(client))
	{
		PrintToChat(client, "%t", "GkArea_Need_Alive");
	}
	else
	{
		int area = StrEqual(info, "ct") ? GK_AREA_CT : GK_AREA_T;
		BuildGkAreaFromPosition(client, area);

		char teamName[16];
		GetTeamNameServer(area == GK_AREA_CT ? TEAM_CT : TEAM_T, teamName, sizeof(teamName));
		char map[PLATFORM_MAX_PATH];
		GetCurrentMap(map, sizeof(map));
		if (SaveGoalkeeperAreas())
		{
			PrintToChat(client, "%t", "GkArea_Marked", teamName, map);
		}
		else
		{
			PrintToChat(client, "%t", "GkArea_Save_Failed");
		}
		DrawGkAreas(client);
	}

	ShowGkAreaMenu(client);
	return 0;
}

// Outlines both areas on the floor for the admin only, for GK_AREA_BEAM_TIME
// seconds: CT in blue, TT in red.
void DrawGkAreas(int client)
{
	if (gBeamSprite == -1)
	{
		return;
	}

	if (!gGkAreaValid[GK_AREA_CT] && !gGkAreaValid[GK_AREA_T])
	{
		PrintToChat(client, "%t", "GkArea_Nothing_To_Show");
		return;
	}

	int colorCT[4] = {74, 163, 255, 255};
	int colorT[4] = {255, 74, 74, 255};
	for (int area = 0; area < 2; area++)
	{
		if (gGkAreaValid[area])
		{
			DrawBox(client, gGkAreaMin[area], gGkAreaMax[area], area == GK_AREA_CT ? colorCT : colorT);
		}
	}
}

void DrawBeam(int client, const float start[3], const float end[3], const int color[4])
{
	TE_SetupBeamPoints(start, end, gBeamSprite, gHaloSprite, 0, 15, GK_AREA_BEAM_TIME, 3.0, 3.0, 1, 0.0, color, 0);
	TE_SendToClient(client);
}

// Outlines the area on the floor: four beams, so several areas can be shown at
// once without hitting the engine's limit of temp entities per update.
void DrawBox(int client, const float mins[3], const float maxs[3], const int color[4])
{
	float z = mins[2] + GK_AREA_FLOOR_MARGIN + 4.0;
	float corners[4][3];
	corners[0][0] = mins[0]; corners[0][1] = mins[1];
	corners[1][0] = maxs[0]; corners[1][1] = mins[1];
	corners[2][0] = maxs[0]; corners[2][1] = maxs[1];
	corners[3][0] = mins[0]; corners[3][1] = maxs[1];
	for (int i = 0; i < 4; i++)
	{
		corners[i][2] = z;
	}

	for (int i = 0; i < 4; i++)
	{
		DrawBeam(client, corners[i], corners[(i + 1) % 4], color);
	}
}
