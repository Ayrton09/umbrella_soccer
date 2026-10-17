// Goalkeeper saves.
//
// Each goal has a goalkeeper area: a box in front of it, stored per map in
// configs/umbrella_soccer_gk_areas.cfg and set in game from the admin menu. A
// player who touches the ball inside their own area right after an opponent
// touched it makes a save. The save is confirmed by the next touch from anyone
// else, or by a goal at the other end, and dropped if their team concedes.

#define GK_AREA_T 0
#define GK_AREA_CT 1
#define GK_AREA_FLOOR_MARGIN 32.0
#define GK_AREA_HEIGHT 256.0
#define GK_AREA_BEAM_TIME 10.0

ConVar gCvarSaves;
ConVar gCvarRankingPointsSave;

char gGkAreasPath[PLATFORM_MAX_PATH];
float gGkAreaMin[2][3];
float gGkAreaMax[2][3];
bool gGkAreaValid[2];

float gGkCorner[MAXPLAYERS + 1][2][2][3];
bool gGkCornerSet[MAXPLAYERS + 1][2][2];

int gPendingSaver;
int gBeamSprite = -1;

void SavesOnPluginStart()
{
	gCvarSaves = CreateConVar("sm_soccer_saves", "1", "Count goalkeeper saves inside the goalkeeper areas.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	gCvarRankingPointsSave = CreateConVar("soccer_mod_ranking_points_save", "10", "Points received for a save. Original default: 10.", FCVAR_NOTIFY, true, -100.0, true, 100.0);
	BuildPath(Path_SM, gGkAreasPath, sizeof(gGkAreasPath), "configs/umbrella_soccer_gk_areas.cfg");
}

void SavesOnMapStart()
{
	gPendingSaver = 0;
	gBeamSprite = PrecacheModel("sprites/laserbeam.vmt", true);
	LoadGoalkeeperAreas();
}

void SavesOnRoundStart()
{
	gPendingSaver = 0;
}

void SavesOnClientDisconnect(int client)
{
	if (gPendingSaver == client)
	{
		gPendingSaver = 0;
	}
	for (int area = 0; area < 2; area++)
	{
		gGkCornerSet[client][area][0] = false;
		gGkCornerSet[client][area][1] = false;
	}
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
	if (gPendingSaver != 0 && client != gPendingSaver)
	{
		ConfirmPendingSave();
	}

	if (!gCvarSaves.BoolValue || gPenaltyActive || gShootoutActive || gPendingSaver == client || !IsValidClient(previousToucher))
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
	if (IsPointInGkArea(GetTeamGkArea(team), origin))
	{
		gPendingSaver = client;
	}
}

// A goal at the other end confirms a pending save; conceding drops it.
void SavesOnGoal(int scoringTeam)
{
	if (gPendingSaver == 0)
	{
		return;
	}

	if (IsValidClient(gPendingSaver) && GetClientTeam(gPendingSaver) == scoringTeam)
	{
		ConfirmPendingSave();
	}
	gPendingSaver = 0;
}

void ConfirmPendingSave()
{
	int saver = gPendingSaver;
	gPendingSaver = 0;
	if (!IsValidClient(saver))
	{
		return;
	}

	AddPlayerPoints(saver, gCvarRankingPointsSave.IntValue);
	RankingAddStat(saver, RANK_STAT_SAVES, 1);
	PrintToChatAll("%t", "Save_Announce", saver);
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

// Builds an area from two opposite floor corners. The box reaches a little
// below the floor and high enough to cover balls in the air.
bool BuildGkAreaFromCorners(int client, int area)
{
	if (!gGkCornerSet[client][area][0] || !gGkCornerSet[client][area][1])
	{
		return false;
	}

	for (int axis = 0; axis < 3; axis++)
	{
		float a = gGkCorner[client][area][0][axis];
		float b = gGkCorner[client][area][1][axis];
		gGkAreaMin[area][axis] = a < b ? a : b;
		gGkAreaMax[area][axis] = a > b ? a : b;
	}
	gGkAreaMin[area][2] -= GK_AREA_FLOOR_MARGIN;
	gGkAreaMax[area][2] += GK_AREA_HEIGHT;
	gGkAreaValid[area] = gGkAreaMin[area][0] < gGkAreaMax[area][0] && gGkAreaMin[area][1] < gGkAreaMax[area][1];
	return gGkAreaValid[area];
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
	AddMenuItemPhrase(menu, client, "ct0", "Menu_GkArea_CT_Corner1");
	AddMenuItemPhrase(menu, client, "ct1", "Menu_GkArea_CT_Corner2");
	AddMenuItemPhrase(menu, client, "t0", "Menu_GkArea_T_Corner1");
	AddMenuItemPhrase(menu, client, "t1", "Menu_GkArea_T_Corner2");
	AddMenuItemPhrase(menu, client, "show", "Menu_GkArea_Show");
	AddMenuItemPhrase(menu, client, "save", "Menu_GkArea_Save");
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
	else if (StrEqual(info, "save"))
	{
		bool builtCT = BuildGkAreaFromCorners(client, GK_AREA_CT);
		bool builtT = BuildGkAreaFromCorners(client, GK_AREA_T);
		if (!builtCT && !builtT)
		{
			PrintToChat(client, "%t", "GkArea_Incomplete");
		}
		else if (SaveGoalkeeperAreas())
		{
			char map[PLATFORM_MAX_PATH];
			GetCurrentMap(map, sizeof(map));
			PrintToChat(client, "%t", "GkArea_Saved", map);
			DrawGkAreas(client);
		}
	}
	else
	{
		int area = info[0] == 'c' ? GK_AREA_CT : GK_AREA_T;
		int corner = info[strlen(info) - 1] == '1' ? 1 : 0;
		float position[3];
		if (!GetAimPosition(client, position))
		{
			GetClientAbsOrigin(client, position);
		}
		gGkCorner[client][area][corner] = position;
		gGkCornerSet[client][area][corner] = true;

		char teamName[16];
		GetTeamNameServer(area == GK_AREA_CT ? TEAM_CT : TEAM_T, teamName, sizeof(teamName));
		PrintToChat(client, "%t", "GkArea_Corner_Set", teamName, corner + 1);
	}

	ShowGkAreaMenu(client);
	return 0;
}

// Outlines both areas for the admin only, for GK_AREA_BEAM_TIME seconds.
void DrawGkAreas(int client)
{
	if (gBeamSprite == -1)
	{
		return;
	}

	int colorCT[4] = {74, 163, 255, 255};
	int colorT[4] = {255, 74, 74, 255};
	if (gGkAreaValid[GK_AREA_CT])
	{
		DrawBox(client, gGkAreaMin[GK_AREA_CT], gGkAreaMax[GK_AREA_CT], colorCT);
	}
	if (gGkAreaValid[GK_AREA_T])
	{
		DrawBox(client, gGkAreaMin[GK_AREA_T], gGkAreaMax[GK_AREA_T], colorT);
	}
}

void DrawBox(int client, const float mins[3], const float maxs[3], const int color[4])
{
	float corners[8][3];
	for (int i = 0; i < 8; i++)
	{
		corners[i][0] = (i & 1) ? maxs[0] : mins[0];
		corners[i][1] = (i & 2) ? maxs[1] : mins[1];
		corners[i][2] = (i & 4) ? maxs[2] : mins[2];
	}

	// Each edge joins two corners that differ in exactly one axis bit.
	for (int i = 0; i < 8; i++)
	{
		for (int bit = 1; bit <= 4; bit <<= 1)
		{
			int j = i | bit;
			if (j == i)
			{
				continue;
			}
			TE_SetupBeamPoints(corners[i], corners[j], gBeamSprite, 0, 0, 0, GK_AREA_BEAM_TIME, 2.0, 2.0, 0, 0.0, color, 0);
			TE_SendToClient(client);
		}
	}
}
