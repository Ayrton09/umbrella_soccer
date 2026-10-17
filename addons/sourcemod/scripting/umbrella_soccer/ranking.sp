// Persistent ranking.
//
// Stats are kept in memory per player and written to the database at every
// round start, at the end of a match, on disconnect and on map end. Play during
// a match goes to the match ranking; play outside one goes to the public
// ranking, which can be turned off. SQLite (a local file, nothing to set up) is
// the default; MySQL uses a section of configs/databases.cfg.

#define RANK_SCOPE_PUBLIC 0
#define RANK_SCOPE_MATCH 1
#define RANK_SCOPES 2

#define RANK_STAT_POINTS 0
#define RANK_STAT_GOALS 1
#define RANK_STAT_ASSISTS 2
#define RANK_STAT_OWN_GOALS 3
#define RANK_STAT_HITS 4
#define RANK_STAT_PASSES 5
#define RANK_STAT_INTERCEPTIONS 6
#define RANK_STAT_BALL_LOSSES 7
#define RANK_STAT_SAVES 8
#define RANK_STAT_ROUNDS_WON 9
#define RANK_STAT_ROUNDS_LOST 10
#define RANK_STAT_MATCHES 11
#define RANK_STAT_MVPS 12
#define RANK_STAT_COUNT 13

#define RANK_TABLE "umbrella_soccer_ranking"
#define RANK_TOP_SIZE 10

static const char gRankColumns[RANK_STAT_COUNT][] =
{
	"points",
	"goals",
	"assists",
	"own_goals",
	"hits",
	"passes",
	"interceptions",
	"ball_losses",
	"saves",
	"rounds_won",
	"rounds_lost",
	"matches",
	"mvps"
};

ConVar gCvarRanking;
ConVar gCvarRankingDriver;
ConVar gCvarRankingDatabase;
ConVar gCvarRankingPublic;
ConVar gCvarRankingPointsMvp;

Database gRankDb;
bool gRankIsMySQL;
bool gRankConnecting;

int gRankDelta[MAXPLAYERS + 1][RANK_SCOPES][RANK_STAT_COUNT];
bool gRankDirty[MAXPLAYERS + 1];
char gRankAuth[MAXPLAYERS + 1][MAX_AUTH_ID_LENGTH];

void RankingOnPluginStart()
{
	gCvarRanking = CreateConVar("sm_soccer_ranking", "1", "Keep a persistent player ranking.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	gCvarRankingDriver = CreateConVar("sm_soccer_ranking_driver", "sqlite", "Ranking database: sqlite (local file) or mysql.", FCVAR_NONE);
	gCvarRankingDatabase = CreateConVar("sm_soccer_ranking_database", "umbrella_soccer", "SQLite: file name in data/sqlite. MySQL: section name in configs/databases.cfg.", FCVAR_NONE);
	gCvarRankingPublic = CreateConVar("sm_soccer_ranking_public", "1", "Also rank play outside matches, in a separate public ranking.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	gCvarRankingPointsMvp = CreateConVar("soccer_mod_ranking_points_motm", "50", "Ranking points for the man of the match. Original default: 50.", FCVAR_NOTIFY, true, -100.0, true, 200.0);

	RegConsoleCmd("sm_rank", CmdRank, "Show your soccer ranking.");
	RegConsoleCmd("sm_top", CmdTop, "Show the soccer top 10.");
}

// Connects once, after the config has set the driver and database cvars.
void RankingOnConfigsExecuted()
{
	if (!gCvarRanking.BoolValue || gRankDb != null || gRankConnecting)
	{
		return;
	}

	char driver[16];
	char database[64];
	gCvarRankingDriver.GetString(driver, sizeof(driver));
	gCvarRankingDatabase.GetString(database, sizeof(database));
	TrimString(driver);
	TrimString(database);
	if (database[0] == '\0')
	{
		strcopy(database, sizeof(database), "umbrella_soccer");
	}

	if (StrEqual(driver, "mysql", false))
	{
		gRankConnecting = true;
		Database.Connect(OnRankDbConnected, database);
		return;
	}

	char error[255];
	Database db = SQLite_UseDatabase(database, error, sizeof(error));
	if (db == null)
	{
		LogError("Ranking: could not open SQLite database \"%s\": %s", database, error);
		return;
	}
	SetupRankDatabase(db);
}

public void OnRankDbConnected(Database db, const char[] error, any data)
{
	gRankConnecting = false;
	if (db == null)
	{
		LogError("Ranking: could not connect to MySQL: %s", error);
		return;
	}
	SetupRankDatabase(db);
}

void SetupRankDatabase(Database db)
{
	char ident[16];
	db.Driver.GetIdentifier(ident, sizeof(ident));
	gRankIsMySQL = StrEqual(ident, "mysql", false);
	if (gRankIsMySQL)
	{
		db.SetCharset("utf8mb4");
	}
	gRankDb = db;

	char query[1024];
	int length = Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS %s (steamid VARCHAR(32) NOT NULL, scope INT NOT NULL, name VARCHAR(128) NOT NULL DEFAULT ''", RANK_TABLE);
	for (int stat = 0; stat < RANK_STAT_COUNT; stat++)
	{
		length += Format(query[length], sizeof(query) - length, ", %s INT NOT NULL DEFAULT 0", gRankColumns[stat]);
	}
	Format(query[length], sizeof(query) - length, ", last_seen INT NOT NULL DEFAULT 0, PRIMARY KEY (steamid, scope))%s", gRankIsMySQL ? " DEFAULT CHARSET=utf8mb4" : "");
	gRankDb.Query(OnRankQueryDone, query);
}

public void OnRankQueryDone(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("Ranking query failed: %s", error);
	}
}

void RankingOnClientPutInServer(int client)
{
	gRankAuth[client][0] = '\0';
	gRankDirty[client] = false;
	for (int scope = 0; scope < RANK_SCOPES; scope++)
	{
		for (int stat = 0; stat < RANK_STAT_COUNT; stat++)
		{
			gRankDelta[client][scope][stat] = 0;
		}
	}
}

void RankingOnClientDisconnect(int client)
{
	RankingFlushClient(client);
	gRankAuth[client][0] = '\0';
}

void RankingAddStat(int client, int stat, int amount)
{
	if (!gCvarRanking.BoolValue || amount == 0 || !IsValidClient(client) || IsFakeClient(client))
	{
		return;
	}

	int scope = gMatchLive ? RANK_SCOPE_MATCH : RANK_SCOPE_PUBLIC;
	if (scope == RANK_SCOPE_PUBLIC && !gCvarRankingPublic.BoolValue)
	{
		return;
	}

	if (gRankAuth[client][0] == '\0'
		&& !GetClientAuthId(client, AuthId_Steam2, gRankAuth[client], sizeof(gRankAuth[]), true))
	{
		gRankAuth[client][0] = '\0';
		return;
	}

	gRankDelta[client][scope][stat] += amount;
	gRankDirty[client] = true;
}

void RankingFlushAll()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		RankingFlushClient(client);
	}
}

// Writes the pending stats of one player as an upsert per ranking scope. Stats
// stay in memory while there is no connection yet.
void RankingFlushClient(int client)
{
	if (!gRankDirty[client] || gRankDb == null || gRankAuth[client][0] == '\0' || !IsClientConnected(client))
	{
		return;
	}

	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	char escapedName[MAX_NAME_LENGTH * 2 + 1];
	char escapedAuth[MAX_AUTH_ID_LENGTH * 2 + 1];
	gRankDb.Escape(name, escapedName, sizeof(escapedName));
	gRankDb.Escape(gRankAuth[client], escapedAuth, sizeof(escapedAuth));

	Transaction txn = new Transaction();
	int queries;
	char query[1024];
	for (int scope = 0; scope < RANK_SCOPES; scope++)
	{
		bool changed;
		for (int stat = 0; stat < RANK_STAT_COUNT; stat++)
		{
			if (gRankDelta[client][scope][stat] != 0)
			{
				changed = true;
				break;
			}
		}
		if (!changed)
		{
			continue;
		}

		Format(query, sizeof(query), "%s INTO %s (steamid, scope, name) VALUES ('%s', %d, '%s')",
			gRankIsMySQL ? "INSERT IGNORE" : "INSERT OR IGNORE", RANK_TABLE, escapedAuth, scope, escapedName);
		txn.AddQuery(query);

		int length = Format(query, sizeof(query), "UPDATE %s SET name = '%s', last_seen = %d", RANK_TABLE, escapedName, GetTime());
		for (int stat = 0; stat < RANK_STAT_COUNT; stat++)
		{
			if (gRankDelta[client][scope][stat] != 0)
			{
				length += Format(query[length], sizeof(query) - length, ", %s = %s + %d",
					gRankColumns[stat], gRankColumns[stat], gRankDelta[client][scope][stat]);
				gRankDelta[client][scope][stat] = 0;
			}
		}
		Format(query[length], sizeof(query) - length, " WHERE steamid = '%s' AND scope = %d", escapedAuth, scope);
		txn.AddQuery(query);
		queries += 2;
	}

	gRankDirty[client] = false;
	if (queries == 0)
	{
		delete txn;
		return;
	}
	gRankDb.Execute(txn, _, OnRankTxnFailed);
}

public void OnRankTxnFailed(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("Ranking: saving stats failed at query %d: %s", failIndex, error);
}

// Match end: everyone on a team played the match, and the MVP gets the bonus.
void RankingOnMatchFinished(int mvp)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidClient(client) && GetClientTeam(client) >= TEAM_T)
		{
			RankingAddStat(client, RANK_STAT_MATCHES, 1);
		}
	}

	if (IsValidClient(mvp))
	{
		RankingAddStat(mvp, RANK_STAT_MVPS, 1);
		RankingAddStat(mvp, RANK_STAT_POINTS, gCvarRankingPointsMvp.IntValue);
	}
	RankingFlushAll();
}

public Action CmdRank(int client, int args)
{
	if (IsValidClient(client))
	{
		ShowClientRank(client);
	}
	return Plugin_Handled;
}

public Action CmdTop(int client, int args)
{
	if (IsValidClient(client))
	{
		ShowTopScopeMenu(client);
	}
	return Plugin_Handled;
}

bool CheckRankingAvailable(int client)
{
	if (gRankDb == null)
	{
		PrintToChat(client, "%t", "Ranking_Unavailable");
		return false;
	}
	return true;
}

void ShowClientRank(int client)
{
	if (!CheckRankingAvailable(client))
	{
		return;
	}

	char auth[MAX_AUTH_ID_LENGTH];
	if (!GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth), true))
	{
		PrintToChat(client, "%t", "Ranking_Unavailable");
		return;
	}

	// Queries run in order on the connection, so this flush is counted below.
	RankingFlushClient(client);

	char escapedAuth[MAX_AUTH_ID_LENGTH * 2 + 1];
	gRankDb.Escape(auth, escapedAuth, sizeof(escapedAuth));
	char query[512];
	for (int scope = RANK_SCOPE_MATCH; scope >= RANK_SCOPE_PUBLIC; scope--)
	{
		Format(query, sizeof(query),
			"SELECT r.points, r.goals, r.assists, r.saves, "
			... "(SELECT COUNT(*) FROM %s b WHERE b.scope = r.scope AND b.points > r.points) + 1, "
			... "(SELECT COUNT(*) FROM %s c WHERE c.scope = r.scope) "
			... "FROM %s r WHERE r.steamid = '%s' AND r.scope = %d",
			RANK_TABLE, RANK_TABLE, RANK_TABLE, escapedAuth, scope);

		DataPack pack = new DataPack();
		pack.WriteCell(GetClientUserId(client));
		pack.WriteCell(scope);
		gRankDb.Query(OnRankRowLoaded, query, pack);
	}
}

public void OnRankRowLoaded(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	int scope = pack.ReadCell();
	delete pack;

	if (results == null)
	{
		LogError("Ranking query failed: %s", error);
		return;
	}
	if (!IsValidClient(client))
	{
		return;
	}

	char scopeName[32];
	FormatRankScopeName(client, scope, scopeName, sizeof(scopeName));
	if (!results.FetchRow())
	{
		PrintToChat(client, "%t", "Ranking_NoData", scopeName);
		return;
	}

	PrintToChat(client, "%t", "Ranking_Line", scopeName, results.FetchInt(4), results.FetchInt(5),
		results.FetchInt(0), results.FetchInt(1), results.FetchInt(2), results.FetchInt(3));
}

void FormatRankScopeName(int client, int scope, char[] buffer, int maxlen)
{
	Format(buffer, maxlen, "%T", scope == RANK_SCOPE_MATCH ? "Ranking_Scope_Match" : "Ranking_Scope_Public", client);
}

void ShowTopScopeMenu(int client)
{
	Menu menu = new Menu(MenuHandlerTopScope);
	char title[64];
	Format(title, sizeof(title), "%T", "Menu_Top_Choose", client);
	menu.SetTitle(title);
	AddMenuItemPhrase(menu, client, "1", "Ranking_Scope_Match");
	AddMenuItemPhrase(menu, client, "0", "Ranking_Scope_Public");
	menu.Display(client, 20);
}

public int MenuHandlerTopScope(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action != MenuAction_Select || !IsValidClient(client) || !CheckRankingAvailable(client))
	{
		return 0;
	}

	char info[4];
	menu.GetItem(item, info, sizeof(info));
	int scope = StringToInt(info) == RANK_SCOPE_MATCH ? RANK_SCOPE_MATCH : RANK_SCOPE_PUBLIC;

	char query[256];
	Format(query, sizeof(query), "SELECT name, points, goals, assists, saves FROM %s WHERE scope = %d ORDER BY points DESC LIMIT %d",
		RANK_TABLE, scope, RANK_TOP_SIZE);
	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(scope);
	gRankDb.Query(OnRankTopLoaded, query, pack);
	return 0;
}

public void OnRankTopLoaded(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	int scope = pack.ReadCell();
	delete pack;

	if (results == null)
	{
		LogError("Ranking query failed: %s", error);
		return;
	}
	if (!IsValidClient(client))
	{
		return;
	}

	char scopeName[32];
	FormatRankScopeName(client, scope, scopeName, sizeof(scopeName));
	if (results.RowCount == 0)
	{
		PrintToChat(client, "%t", "Ranking_NoData", scopeName);
		return;
	}

	Menu menu = new Menu(MenuHandlerTopList);
	char title[64];
	Format(title, sizeof(title), "%T", "Menu_Top_Title", client, scopeName);
	menu.SetTitle(title);

	char name[MAX_NAME_LENGTH];
	char line[128];
	int position;
	while (results.FetchRow())
	{
		position++;
		results.FetchString(0, name, sizeof(name));
		Format(line, sizeof(line), "%T", "Menu_Top_Line", client, position, name,
			results.FetchInt(1), results.FetchInt(2), results.FetchInt(3), results.FetchInt(4));
		menu.AddItem("", line, ITEMDRAW_DISABLED);
	}
	menu.Display(client, 30);
}

public int MenuHandlerTopList(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}
