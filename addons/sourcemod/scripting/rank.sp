#pragma semicolon 1
#include <sdkhooks>
#include <sdktools>
#include <csgo_colors>
#include <adminmenu>
#include <cstrike>
#include <clientprefs>
#undef REQUIRE_PLUGIN
#include <scp>
#include <gameme>
#include <rankme>

enum StatusRank
{
	Core = 0,
	gameme = 1,
	rankme = 2,
	hlstats = 3
}

new bool:IRank[StatusRank];
new StatusRank:RankCore = Core;
new String:hlstats_game[64];

new Handle:TopM = INVALID_HANDLE,
	Handle:Menu2,
	Handle:Menu3,
	Handle:Menu4,
	cl[MAXPLAYERS+1];

new Handle:bd_rank,
	Handle:kv_rank,
	Handle:trie_weapon,
	Handle:trie_rank1,
	Handle:trie_rank2,
	Handle:trie_rank3;

new kill,
	death,
	assister,
	headshot,
	penetrated,
	c4,
	rank[50],
	rank_k,
	rank_l[MAXPLAYERS+1],
	bool:say_l[MAXPLAYERS+1],
	iRankH[MAXPLAYERS+1] = {INVALID_ENT_REFERENCE, ...},
	iRankHB[MAXPLAYERS+1] = {INVALID_ENT_REFERENCE, ...};
	
new xp[MAXPLAYERS+1],
	resetcl[MAXPLAYERS+1];

new iRankOffset, iRankOffsetPl[MAXPLAYERS+1];
new rank_v[MAXPLAYERS+1];

new String:steamid[MAXPLAYERS+1][32],
	String:teg[MAXPLAYERS+1][64],
	String:lvl_sound[2][256],
	String:lvl_overlay[2][256];
	
new bool:mnxp, bool:mmxp, delit, bool:mesn;
new g_iTotalPlayers;

new Handle:ran,
	Handle:rannam,
	Handle:Cookie;
	
new bool:resetu,
	minpl,
	bool:tab_rank,
	bool:rank_hd,
	bool:rank_hd_team;

new fg;

#define vers "1.9.1"

public Plugin:myinfo =
{
	name = "Rank",
	author = "Pheonix (˙·٠●Феникс●٠·˙), CrazyHackGUT aka Kruzya",
	version = vers,
	url = "http://zizt.ru/"
};

public OnPluginStart()
{ 
		KFG_load();
		Cookie = RegClientCookie("rank", "Rank", CookieAccess_Protected);
		CreateConVar("sm_rank_version", vers, "Rank Version", FCVAR_DONTRECORD|FCVAR_NOTIFY);
		Create_menu();
		HookEvent("player_death", Event_player_death);
		HookEvent("player_team", EventPlayerTeam);
		HookEvent("player_spawn", Event_Spawn);
		if(RankCore == Core)
		{
			HookEvent("player_changename", Event_player_changename);
			HookEvent("bomb_planted", Event_bomb_planted);
			HookEvent("bomb_defused", Event_bomb_defused);
			HookEvent("hostage_rescued", Event_hostage_rescued);
			AddCommandListener(Say, "say"); 
			AddCommandListener(Say, "say_team");
		}
		else HookEvent("round_start", Event_RoundStart);
		LoadTranslations("rank.phrases");
		OnAdminMenuReady(GetAdminTopMenu()); 
		if(ran != INVALID_HANDLE) CloseHandle(ran);
		ran = CreateMenu(ranMenu); 
		AddMenuItem(ran, "", "Список званий");
		if(RankCore == Core) AddMenuItem(ran, "", "Топ 10");
		AddMenuItem(ran, "", "Вкл/Выкл уведомление в чат");
		if(resetu && RankCore == Core) AddMenuItem(ran, "", "Сбросить свое звание");
		if (LibraryExists("gameme")) IRank[gameme] = true;
		if (LibraryExists("rankme")) IRank[rankme] = true;
		for (new u = 1; u <= MaxClients; u++) if(IsClientInGame(u) && !IsFakeClient(u)) 
		{
			OnClientPutInServer(u);
			if(AreClientCookiesCached(u)) OnClientCookiesCached(u);
		}
}

public OnLibraryAdded(const String:name[]) 
{
	if (StrEqual(name, "gameme")) IRank[gameme] = true;
	if (StrEqual(name, "rankme")) IRank[rankme] = true;
}

public OnMapStart() 
{
		switch (RankCore)
		{
			case gameme: if(!IRank[gameme]) SetFailState("[Rank] - gameme не найден");
			case rankme: if(!IRank[rankme]) SetFailState("[Rank] - rankme не найден");
			case hlstats: if(!IRank[hlstats]) SetFailState("[Rank] - hlstats не найден");
		}
		iRankOffset = FindSendPropInfo("CCSPlayerResource", "m_iCompetitiveRanking");
		for (new u = 1; u <= MaxClients; u++) iRankOffsetPl[u] = iRankOffset+u*4;
		SDKHook(FindEntityByClassname(MaxClients+1, "cs_player_manager"), SDKHook_ThinkPost, Hook_OnThinkPost);
		SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & (~FCVAR_CHEAT));
		PrecacheModel("models/weapons/v_knife_default_ct.mdl");
		decl String:buf[256];
		if(rank_hd)
		{
			for (new i = 1; i <= 18; i++)
			{
				FormatEx(buf, 256, "materials/sprites/rank_x/%d.vmt", i);
				AddFileToDownloadsTable(buf);
				PrecacheModel(buf);
				FormatEx(buf, 256, "materials/sprites/rank_x/%d.vtf", i);
				AddFileToDownloadsTable(buf);
			}
		}
		if(lvl_sound[0][0])
		{
			ReplaceString(lvl_sound[0], 256, "\\", "/");
			FormatEx(buf, 256, "sound/%s", lvl_sound[0]);
			AddFileToDownloadsTable(buf);
		}
		if(lvl_sound[1][0])
		{
			ReplaceString(lvl_sound[1], 256, "\\", "/");
			FormatEx(buf, 256, "sound/%s", lvl_sound[1]);
			AddFileToDownloadsTable(buf);
		}
		if(lvl_overlay[0][0])
		{
			ReplaceString(lvl_overlay[0], 256, "\\", "/");
			FormatEx(buf, 256, "materials/%s.vmt", lvl_overlay[0]);
			AddFileToDownloadsTable(buf);
			ReplaceString(buf, 256, ".vmt", ".vtf");
			AddFileToDownloadsTable(buf);
		}
		if(lvl_overlay[1][0])
		{
			ReplaceString(lvl_overlay[1], 256, "\\", "/");
			FormatEx(buf, 256, "materials/%s.vmt", lvl_overlay[1]);
			AddFileToDownloadsTable(buf);
			ReplaceString(buf, 256, ".vmt", ".vtf");
			AddFileToDownloadsTable(buf);
		}
}

public Action:Event_player_death(Handle:event, const String:name[], bool:dontBroadcast)
{
		new iClient = GetClientOfUserId(GetEventInt(event, "attacker"));
		new ig = GetClientOfUserId(GetEventInt(event, "userid"));
		new mid = EntRefToEntIndex(iRankH[ig]);
		if(mid != INVALID_ENT_REFERENCE) AcceptEntityInput(mid, "Kill");
		mid = EntRefToEntIndex(iRankHB[iClient]);
		if(mid != INVALID_ENT_REFERENCE) AcceptEntityInput(mid, "Kill");
		iRankH[iClient] = INVALID_ENT_REFERENCE;
		iRankHB[iClient] = INVALID_ENT_REFERENCE;
		if(RankCore == Core && ig && (!minpl || (minpl <= GetCount())) && iClient && IsClientInGame(iClient) && IsClientInGame(ig) && iClient != ig)
		{
			decl String:weapon[64];
			GetEventString(event, "weapon", weapon, 64);
			new Float:a, d, kl;
			d = kill;
			if(headshot && GetEventBool(event, "headshot")) d += headshot;
			if(penetrated && GetEventBool(event, "penetrated")) d += penetrated;
			kl = (xp[ig]-xp[iClient])/delit;
			if(kl < 0) kl = 0;
			if(mnxp) d += kl;
			if(GetTrieValue(trie_weapon, weapon, a))
			{
				d = RoundToZero(float(d)*a);
			}
			if(say_l[iClient]) CGOPrintToChat(iClient, "%t", "kill", d, ig);
			give_xp(iClient, d);
			if(assister)
			{
				iClient = GetClientOfUserId(GetEventInt(event, "assister"));
				if(iClient)
				{
					d = assister;
					if(mnxp)
					{
						new k;
						k = (xp[ig]-xp[iClient])/delit;
						if(k > 0) d += k;
					}
					if(GetTrieValue(trie_weapon, weapon, a))
					{
						d = RoundToZero(float(d)*a);
					}
					if(say_l[iClient]) CGOPrintToChat(iClient, "%t", "assister", d, ig);
					give_xp(iClient, d);
				}
			}
			if(death)
			{
				new t = death;
				if(mmxp) t += kl;
				if(say_l[ig]) CGOPrintToChat(ig, "%t", "death", t);
				give_xp(ig, (t*-1));
			}
		}
}

public Action:EventPlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(0.1, Timer_PlayerTeam, GetEventInt(event, "userid"));
}

public Action:Timer_PlayerTeam(Handle:timer, any:id)
{
		new iClient = GetClientOfUserId(id);
		if(iClient && !IsPlayerAlive(iClient))
		{
			new mid = EntRefToEntIndex(iRankH[iClient]);
			if(mid != INVALID_ENT_REFERENCE) AcceptEntityInput(mid, "Kill");
			mid = EntRefToEntIndex(iRankHB[iClient]);
			if(mid != INVALID_ENT_REFERENCE) AcceptEntityInput(mid, "Kill");
			iRankH[iClient] = INVALID_ENT_REFERENCE;
			iRankHB[iClient] = INVALID_ENT_REFERENCE;
		}
}

public Action:Event_Spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
		new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
		iRankH[iClient] = INVALID_ENT_REFERENCE;
		iRankHB[iClient] = INVALID_ENT_REFERENCE;
		CU_rank_bar(iClient);
}

CU_rank_bar(iClient)
{
	if(rank_hd)
	{
		if(IsPlayerAlive(iClient) && rank_v[iClient])
		{
			new mid = EntRefToEntIndex(iRankH[iClient]);
			decl String:buf[256];
			FormatEx(buf, 256, "materials/sprites/rank_x/%d.vmt", rank_v[iClient]);
			if(mid == INVALID_ENT_REFERENCE)
			{
				new Ent = CreateEntityByName("env_sprite_oriented");
				DispatchKeyValue(Ent, "classname", "rank_hud");
				DispatchKeyValue(Ent, "model", buf);
				DispatchSpawn(Ent);
				decl Float:origin[3];
				GetClientAbsOrigin(iClient, origin);
				origin[2] += 80;
				new PEnt = CreateEntityByName("prop_dynamic_override");
				DispatchKeyValue(PEnt, "model", "models/weapons/v_knife_default_ct.mdl");
				DispatchSpawn(PEnt);
				SetEntityRenderMode(PEnt, RENDER_NONE);
				TeleportEntity(Ent, origin, NULL_VECTOR, NULL_VECTOR);
				origin[2] -= 90;
				TeleportEntity(PEnt, origin, NULL_VECTOR, NULL_VECTOR);
				SetEntPropEnt(Ent, Prop_Send, "m_hOwnerEntity", iClient);
				SetVariantString("!activator");
				AcceptEntityInput(PEnt, "SetParent", iClient, PEnt, 0);
				SetVariantString("!activator");
				AcceptEntityInput(Ent, "SetParent", PEnt, Ent, 0);
				if(rank_hd_team) SDKHook(Ent, SDKHook_SetTransmit, Hook_Hide);
				iRankH[iClient] = EntIndexToEntRef(Ent);
				iRankHB[iClient] = EntIndexToEntRef(PEnt);
			}
			else SetEntityModel(mid, buf);
		}
		else
		{
			new mid = EntRefToEntIndex(iRankH[iClient]);
			if(mid != INVALID_ENT_REFERENCE) AcceptEntityInput(mid, "Kill");
			mid = EntRefToEntIndex(iRankHB[iClient]);
			if(mid != INVALID_ENT_REFERENCE) AcceptEntityInput(mid, "Kill");
			iRankH[iClient] = INVALID_ENT_REFERENCE;
			iRankHB[iClient] = INVALID_ENT_REFERENCE;
		}
	}
}

public Action:Hook_Hide(entity, client)
{
	new owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (owner != -1 && (owner == client || GetClientTeam(owner) != GetClientTeam(client))) return Plugin_Handled;
	return Plugin_Continue;
}

GetCount()
{
	new j;
	for (new u = 1; u <= MaxClients; u++)
	{
		if(IsClientInGame(u) && GetClientTeam(u) > 1) j++;
	}
	return j;
}

public OnClientPutInServer(iClient)
{
		iRankH[iClient] = INVALID_ENT_REFERENCE;
		if(!IsFakeClient(iClient))
		{
			GetClientAuthId(iClient, AuthId_Steam2, steamid[iClient],  32);
			load_pl(iClient);
			resetcl[iClient] = 0;
		}
}

public OnClientDisconnect(iClient)
{
	rank_v[iClient] = 0;
}

public OnClientCookiesCached(iClient)
{
	if(!IsFakeClient(iClient))
	{
		decl String:sCookieValue[10];
		GetClientCookie(iClient, Cookie, sCookieValue, sizeof(sCookieValue));
		if(sCookieValue[0]) say_l[iClient] = bool:StringToInt(sCookieValue);
		else say_l[iClient] = mesn;
	}
}

save_say(iClient, bool:st)
{
	say_l[iClient] = st;
	decl String:sCookieValue[10];
	IntToString(st, sCookieValue, sizeof(sCookieValue));
	SetClientCookie(iClient, Cookie, sCookieValue);
}

public Action:OnChatMessage(&iClient, Handle:recipients, String:name[], String:message[])
{
	if(teg[iClient][0] != '\0')
	{
		Format(name, MAXLENGTH_NAME, " %s \x03%s", teg[iClient], name);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action:sm_rank(iClient, args)
{
		if(RankCore == Core)
		{
			decl String:sQuery[256];
			Format(sQuery, 256, "SELECT `xp` FROM `rank` WHERE  (`xp` >= %d)", xp[iClient]);
			SQL_TQuery(bd_rank, SQLT_ShowRank, sQuery, GetClientUserId(iClient));
		}
		else
		{
			decl String:r[500];
			IntToString(rank[get_lv(iClient)] ,r, 500);
			GetTrieString(trie_rank3, r, r, 500);
			Format(r, 500, "%T", "rank_nocore", iClient, r, xp[iClient]);
			SetMenuTitle(ran, r);
			DisplayMenu(ran, iClient, 20);
		}
		return Plugin_Handled;
}

public SQLT_ShowRank(Handle:hOwner, Handle:hQuery, const String:sError[], any:iUserId)
{
	new iClient = GetClientOfUserId(iUserId);
	if (iClient)
	{
		decl String:r[500];
		IntToString(rank[get_lv(iClient)] ,r, 500);
		GetTrieString(trie_rank3, r, r, 500);
		Format(r, 500, "%T", "rank", iClient, r, xp[iClient], SQL_GetRowCount(hQuery), g_iTotalPlayers);
		SetMenuTitle(ran, r);
		DisplayMenu(ran, iClient, 20);
	}
}

public ranMenu(Handle:hMenu, MenuAction:action, iClient, Item)
{
		if(action == MenuAction_Select)
		{
			switch(Item)
			{
				case 0: DisplayMenu(rannam, iClient, 20);
				case 1: 
				{
					if(RankCore == Core) SQL_TQuery(bd_rank, GetTop10, "SELECT `name`, `xp` FROM `rank` ORDER BY `xp` DESC LIMIT 10", GetClientSerial(iClient));
					else
					{
						if(say_l[iClient]) 
						{
							CGOPrintToChat(iClient, "{GREEN}Уведомления в чат выключены");
							save_say(iClient, false);
						}
						else 
						{
							CGOPrintToChat(iClient, "{GREEN}Уведомления в чат включены");
							save_say(iClient, true);
						}
						DisplayMenu(ran, iClient, 20);
					}
				}
				case 2:
				{
					if(say_l[iClient]) 
					{
						CGOPrintToChat(iClient, "{GREEN}Уведомления в чат выключены");
						save_say(iClient, false);
					}
					else 
					{
						CGOPrintToChat(iClient, "{GREEN}Уведомления в чат включены");
						save_say(iClient, true);
					}
					DisplayMenu(ran, iClient, 20);
				}
				case 3:
				{
					resetcl[iClient] = GetRandomInt(1000, 9999);
					CGOPrintToChat(iClient, "{RED}Для подтверждения обнуления введите в чат {GREEN}%d {RED}для отмены stopr", resetcl[iClient]);
					DisplayMenu(ran, iClient, 20);
				}
			}
		}
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
		switch (RankCore)
		{
			case gameme:
			{
				for (new iClient = 1; iClient <= MaxClients; iClient++)
				{
					if (IsClientInGame(iClient) && !IsFakeClient(iClient))
					{
						QueryGameMEStats("playerinfo", iClient, QuerygameMEStatsCallback, 0);
					}
				}
			}
			case rankme:
			{
				for (new iClient = 1; iClient <= MaxClients; iClient++)
				{
					if (IsClientInGame(iClient) && !IsFakeClient(iClient))
					{
						give_xp(iClient, RankMe_GetPoints(iClient)-xp[iClient]);
					}
				}	
			}
			case hlstats:
			{
				for (new iClient = 1; iClient <= MaxClients; iClient++)
				{
					if (IsClientInGame(iClient) && !IsFakeClient(iClient))
					{
						give_xp(iClient, hlstats_get(iClient)-xp[iClient]);
					}
				}
			}
		}
}

public QuerygameMEStatsCallback(command, payload, iClient, &Handle: datapack)
{
	if ((iClient > 0) && (command == RAW_MESSAGE_CALLBACK_PLAYER))
	{
		new Handle: data = CloneHandle(datapack);
		SetPackPosition(data, 18);
		give_xp(iClient, ReadPackCell(data)-xp[iClient]);
		CloseHandle(data);
	}
}

load_pl(iClient)
{		switch (RankCore)
		{
			case Core:
			{
				decl String:query[128];   		
				FormatEx(query, 128, "SELECT xp FROM rank WHERE steamid='%s';", steamid[iClient]);
				new Handle:hquery = SQL_Query(bd_rank, query);    
				if (hquery != INVALID_HANDLE && SQL_FetchRow(hquery)) xp[iClient] = SQL_FetchInt(hquery, 0); 
				else
				{
					FormatEx(query, 128, "INSERT INTO rank (steamid, name, xp) VALUES ('%s', '', 0);", steamid[iClient]);
					SQL_TQuery(bd_rank, SQL_Check, query);
					xp[iClient] = 0;
					rank_l[iClient] = 0;
					rank_v[iClient] = 0;
					IntToString(rank[rank_l[iClient]], query, 128);
					GetTrieString(trie_rank2, query, teg[iClient], 64);
					g_iTotalPlayers++;
				}
				CloseHandle(hquery);
				update_name(iClient);
				update_tim(iClient);
			}
			case gameme: QueryGameMEStats("playerinfo", iClient, QuerygameMEStatsCallback, 0);
			case rankme: xp[iClient] = RankMe_GetPoints(iClient);
			case hlstats: xp[iClient] = hlstats_get(iClient);
		}
		decl String:buf[64];
		rank_l[iClient] = get_lv(iClient);
		IntToString(rank[rank_l[iClient]], buf, 64);
		GetTrieValue(trie_rank1, buf, rank_v[iClient]);
		GetTrieString(trie_rank2, buf, teg[iClient], 64);
		if(tab_rank) CS_SetClientContributionScore(iClient, xp[iClient]);
}

hlstats_get(iClient)
{
	decl String:query[512];   		
	FormatEx(query, 512, "(SELECT skill from hlstats_Players JOIN hlstats_PlayerUniqueIds ON hlstats_Players.playerId = hlstats_PlayerUniqueIds.playerId WHERE uniqueID = MID('%s', 9) AND hlstats_PlayerUniqueIds.game = '%s')", steamid[iClient], hlstats_game);
	new Handle:hquery = SQL_Query(bd_rank, query); 
	if (hquery != INVALID_HANDLE && SQL_FetchRow(hquery)) return SQL_FetchInt(hquery, 0);  
	return 0; 
}

give_xp(iClient, o)
{
		xp[iClient] += o;
		if(xp[iClient] <= -1) xp[iClient] = 0;
		decl String:up[256], String:n[64];
		new h = get_lv(iClient);
		if(h != rank_l[iClient])
		{
			IntToString(rank[h], up, 256);
			GetTrieString(trie_rank3, up, n, 64);
			if(h > rank_l[iClient]) 
			{
				if(say_l[iClient]) CGOPrintToChat(iClient, "%t", "up", n);
				if(lvl_sound[0][0]) ClientCommand(iClient, "play *%s", lvl_sound[0]);
				if(lvl_overlay[0][0]) ClientOverlay(iClient, lvl_overlay[0], 3.0);
			}
			else 
			{
				if(say_l[iClient]) CGOPrintToChat(iClient, "%t", "down", n);
				if(lvl_sound[1][0]) ClientCommand(iClient, "play *%s", lvl_sound[1]);
				if(lvl_overlay[1][0]) ClientOverlay(iClient, lvl_overlay[1], 3.0);
			}
			rank_l[iClient] = h;
			GetTrieValue(trie_rank1, up, rank_v[iClient]);
			GetTrieString(trie_rank2, up, teg[iClient], 64);
			CU_rank_bar(iClient);
		}
		if(rank[rank_k] > xp[iClient]) if(say_l[iClient]) CGOPrintToChat(iClient, "%t", "xp", xp[iClient], rank[rank_l[iClient]+1]);
		else if(say_l[iClient]) CGOPrintToChat(iClient, "%t", "xp_max", xp[iClient]);
		if(tab_rank) CS_SetClientContributionScore(iClient, xp[iClient]);
		if(RankCore == Core)
		{
			FormatEx(up, 256, "UPDATE rank SET xp = '%d' WHERE steamid = '%s';", xp[iClient], steamid[iClient]);
			SQL_TQuery(bd_rank, SQL_Check, up);
		}
}

get_lv(iClient)
{
	if(rank[rank_k] > xp[iClient])
	{
		new lv = -1;
		do lv++;
		while (rank[lv] <= xp[iClient]);
		return lv-1;
	}
	else return rank_k;
}

get_lv_xp(x)
{
	if(rank[rank_k] > x)
	{
		new lv = -1;
		do lv++;
		while (rank[lv] <= x);
		return lv-1;
	}
	else return rank_k;
}

update_name(iClient)
{
	decl String:up[128];
	GetClientName(iClient, up, 128);
	SQL_EscapeString(bd_rank, up, up, 128);
	Format(up, 128, "UPDATE rank SET name = '%s' WHERE steamid = '%s';", up, steamid[iClient]);
	SQL_TQuery(bd_rank, SQL_Check, up);
}

update_tim(iClient)
{
	decl String:up[128];
	FormatEx(up, 128, "UPDATE rank SET tim = '%d' WHERE steamid = '%s';", GetTime(), steamid[iClient]);
	SQL_TQuery(bd_rank, SQL_Check, up);
}

public Hook_OnThinkPost(iEnt)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if(rank_v[i]) SetEntData(iEnt, iRankOffsetPl[i], rank_v[i]);
	}
}

public Action:OnPlayerRunCmd(iClient, &buttons, &impulse, Float:vel[3], Float:angles[3], &Weapon)
{
	if (StartMessageOne("ServerRankRevealAll", iClient) != INVALID_HANDLE) EndMessage();
}

public GetTop10(Handle:owner, Handle:hndl, const String:error[], any:serial) 
{ 
	new iClient = GetClientFromSerial(serial);
	if (!iClient)
	{
		return;
	}
	
	new count = SQL_GetRowCount(hndl);
	if (count > 10)
	{
		count = 10;
	}
	else if (!count)
	{
		return;
	}
		
	new Handle:panel = CreatePanel();
	decl String:display[128], String:r[64], String:name[MAX_NAME_LENGTH+1], x;
	FormatEx(display, 128, "Топ 10");
	SetPanelTitle(panel, display);
	
	DrawPanelItem(panel, " ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	
	for (new i = 1; i <= count; i++)
	{
		SQL_FetchRow(hndl);
		
		SQL_FetchString(hndl, 0, name, sizeof(name));
		x = SQL_FetchInt(hndl, 1);
		
		IntToString(rank[get_lv_xp(x)] ,r, 64);
		GetTrieString(trie_rank3, r, r, 64);
		FormatEx(display, 128, "%i. %s - [%d xp] - %s", i, name, x, r);
		DrawPanelText(panel, display);
	}
	
	DrawPanelItem(panel, " ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	
	SetPanelCurrentKey(panel, 7);
	DrawPanelItem(panel, "Назад\n ");
	SetPanelCurrentKey(panel, 9);
	DrawPanelItem(panel, "Выход");
	
	SendPanelToClient(panel, iClient, PanelHandler, 20);
	CloseHandle(panel);
}

public PanelHandler(Handle:menu, MenuAction:action, param1, param2) if (param2 == 7) sm_rank(param1, 0);

public Action:Event_player_changename(Handle:event, const String:name[], bool:dontBroadcast)
{
	update_name(GetClientOfUserId(GetEventInt(event, "userid")));
} 

public Action:Event_bomb_planted(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!minpl || (minpl <= GetCount()))
	{
		new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
		if(say_l[iClient]) CGOPrintToChat(iClient, "%t", "bomb_planted", c4);
		give_xp(iClient, c4);
	}
} 

public Action:Event_bomb_defused(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!minpl || (minpl <= GetCount()))
	{
		new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
		if(say_l[iClient]) CGOPrintToChat(iClient, "%t", "bomb_defused", c4);
		give_xp(iClient, c4);
	}
} 

public Action:Event_hostage_rescued(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!minpl || (minpl <= GetCount()))
	{
		new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
		if(say_l[iClient]) CGOPrintToChat(iClient, "%t", "hostage_rescued", c4);
		give_xp(iClient, c4);
	}
} 

public OnAdminMenuReady(Handle:topme)
{
	if (topme == INVALID_HANDLE || topme == TopM) return;
	TopM = topme;
	new TopMenuObject:mn = AddToTopMenu(topme, "sm_rank", TopMenuObject_Category, TopMenuCallBack, INVALID_TOPMENUOBJECT, _, fg);
	if(RankCore == Core) AddToTopMenu(topme, "sm_rank_upr", TopMenuObject_Item, MenuCallBack1, mn, _, fg);
	AddToTopMenu(topme, "sm_rank_reload", TopMenuObject_Item, MenuCallBack2, mn, _, fg);
}

public TopMenuCallBack(Handle:topme, TopMenuAction:action, TopMenuObject:object_id, iClient, String:buffer[], maxlength)
{
	switch (action)
	{
		case TopMenuAction_DisplayOption: FormatEx(buffer, maxlength, "Управление Rank");
		case TopMenuAction_DisplayTitle: FormatEx(buffer, maxlength, "Управление Rank");
	}
}

public MenuCallBack1(Handle:topme, TopMenuAction:action, TopMenuObject:object_id, iClient, String:buffer[], maxlength)
{
	switch (action)
	{
		case TopMenuAction_DisplayOption: FormatEx(buffer, maxlength, "Управление игроками");
		case TopMenuAction_SelectOption: Select_PL_MENU(iClient);
	}
}

public MenuCallBack2(Handle:topme, TopMenuAction:action, TopMenuObject:object_id, iClient, String:buffer[], maxlength)
{
	switch (action)
	{
		case TopMenuAction_DisplayOption: FormatEx(buffer, maxlength, "Перезагрузить кфг файл");
		case TopMenuAction_SelectOption:
		{
			KFG_load();
			for (new i = 1; i <= MaxClients; i++) if (IsClientInGame(i)) load_pl(iClient);
			CGOPrintToChat(iClient, "{GREEN}Файл конфигурации успешно перезагружен");
			DisplayTopMenu(TopM, iClient, TopMenuPosition_LastCategory);
		}
	}
}

Create_menu()
{
	Menu2 = CreateMenu(Menu2Handler);
	SetMenuExitBackButton(Menu2, true);
	AddMenuItem(Menu2, "", "Дать xp");
	AddMenuItem(Menu2, "", "Забрать xp");
	AddMenuItem(Menu2, "", "Обнулить игрока");
	Menu3 = CreateMenu(Menu3Handler);
	SetMenuExitBackButton(Menu3, true);
	AddMenuItem(Menu3, "10", "10");
	AddMenuItem(Menu3, "50", "50");
	AddMenuItem(Menu3, "100", "100");
	AddMenuItem(Menu3, "200", "200");
	AddMenuItem(Menu3, "500", "500");
	AddMenuItem(Menu3, "1000", "1000");
	Menu4 = CreateMenu(Menu4Handler);
	SetMenuExitBackButton(Menu4, true);
	AddMenuItem(Menu4, "10", "10");
	AddMenuItem(Menu4, "50", "50");
	AddMenuItem(Menu4, "100", "100");
	AddMenuItem(Menu4, "200", "200");
	AddMenuItem(Menu4, "500", "500");
	AddMenuItem(Menu4, "1000", "1000");
}

Select_PL_MENU(iClient)
{
	new Handle:menu = CreateMenu(Select_PL);
	SetMenuTitle(menu, "Выберите Игрока:");
	decl String:userid[15], String:name[64];
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			IntToString(GetClientUserId(i), userid, 15);
			GetClientName(i, name, 64);
			AddMenuItem(menu, userid, name);
		}
	}
	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, iClient, 0);
}

public Select_PL(Handle:menu, MenuAction:action, iClient, option)
{
	if (action == MenuAction_Select)
	{
		decl String:userid[15];
		GetMenuItem(menu, option, userid, 15);
		new u = StringToInt(userid);
		new target = GetClientOfUserId(u);
		if (target)
		{
			cl[iClient] = u;
			SetMenuTitle(Menu2, "Управление %N - %d xp", target, xp[target]);
			DisplayMenu(Menu2, iClient, MENU_TIME_FOREVER);
		}
		else 
		{
			CGOPrintToChat(iClient, "{LIGHTRED}Игрок не найден (вышел с сервера)");
			DisplayTopMenu(TopM, iClient, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Cancel && option == MenuCancel_ExitBack) DisplayTopMenu(TopM, iClient, TopMenuPosition_LastCategory);
	else if (action == MenuAction_End) CloseHandle(menu);
}

public Menu2Handler(Handle:hMenu, MenuAction:action, iClient, Item)
{
	switch(action)
	{
		case MenuAction_Cancel:
		{
			if(Item == MenuCancel_ExitBack) Select_PL_MENU(iClient);
		}
		case MenuAction_Select:
		{
			new ch = GetClientOfUserId(cl[iClient]);
			if(ch)
			{
				switch(Item)
				{
					case 0:
					{
						SetMenuTitle(Menu3, "Дать xp у %N - %d xp", ch, xp[ch]);
						DisplayMenu(Menu3, iClient, MENU_TIME_FOREVER);
					}
					case 1:
					{
						SetMenuTitle(Menu4, "Забрать xp %N - %d xp", ch, xp[ch]);
						DisplayMenu(Menu4, iClient, MENU_TIME_FOREVER);
					}
					case 2:
					{
						give_xp(ch, xp[ch]*-1);
						CGOPrintToChat(iClient, "{GREEN}Вы успешно обнулили {LIGHTRED}%N", ch);
						SetMenuTitle(Menu2, "Управление %N - %d xp", ch, xp[ch]);
						DisplayMenu(Menu2, iClient, MENU_TIME_FOREVER);
					}
				}
			}
			else
			{
				CGOPrintToChat(iClient, "{LIGHTRED}Игрок не найден (вышел с сервера)");
				DisplayTopMenu(TopM, iClient, TopMenuPosition_LastCategory);
			}
		}
	}
}

public Menu3Handler(Handle:hMenu, MenuAction:action, iClient, Item)
{
	switch(action)
	{
		case MenuAction_Cancel:
		{
			if(Item == MenuCancel_ExitBack)
			{
				new ch = GetClientOfUserId(cl[iClient]);
				if(ch)
				{
					SetMenuTitle(Menu2, "Управление %N - %d xp", ch, xp[ch]);
					DisplayMenu(Menu2, iClient, MENU_TIME_FOREVER);
				}
				else
				{
					CGOPrintToChat(iClient, "{LIGHTRED}Нельзя вернуться назад так как игрок не найден (вышел с сервера)");
					DisplayTopMenu(TopM, iClient, TopMenuPosition_LastCategory);
				}
			}
		}
		case MenuAction_Select:
		{
			new ch = GetClientOfUserId(cl[iClient]);
			if(ch)
			{
				decl String:h[15];
				GetMenuItem(hMenu, Item, h, 15);
				new u = StringToInt(h);
				give_xp(ch, u);
				CGOPrintToChat(iClient, "{GREEN}Вы успешно дали %d xp {LIGHTRED}%N", u, ch);
				SetMenuTitle(Menu3, "Дать xp у %N - %d xp", ch, xp[ch]);
				DisplayMenu(Menu3, iClient, MENU_TIME_FOREVER);
			}
			else
			{
				CGOPrintToChat(iClient, "{LIGHTRED}Игрок не найден (вышел с сервера)");
				DisplayTopMenu(TopM, iClient, TopMenuPosition_LastCategory);
			}
		}
	}
}

public Menu4Handler(Handle:hMenu, MenuAction:action, iClient, Item)
{
	switch(action)
	{
		case MenuAction_Cancel:
		{
			if(Item == MenuCancel_ExitBack)
			{
				new ch = GetClientOfUserId(cl[iClient]);
				if(ch)
				{
					SetMenuTitle(Menu2, "Управление %N - %d xp", ch, xp[ch]);
					DisplayMenu(Menu2, iClient, MENU_TIME_FOREVER);
				}
				else
				{
					CGOPrintToChat(iClient, "{LIGHTRED}Нельзя вернуться назад так как игрок не найден (вышел с сервера)");
					DisplayTopMenu(TopM, iClient, TopMenuPosition_LastCategory);
				}
			}
		}
		case MenuAction_Select:
		{
			new ch = GetClientOfUserId(cl[iClient]);
			if(ch)
			{
				decl String:h[15];
				GetMenuItem(hMenu, Item, h, 15);
				new u = StringToInt(h);
				give_xp(ch, u*-1);
				CGOPrintToChat(iClient, "{GREEN}Вы успешно забрали %d xp у {LIGHTRED}%N", u, ch);
				SetMenuTitle(Menu4, "Забрать xp %N - %d xp", ch, xp[ch]);
				DisplayMenu(Menu4, iClient, MENU_TIME_FOREVER);
			}
			else
			{
				CGOPrintToChat(iClient, "{LIGHTRED}Игрок не найден (вышел с сервера)");
				DisplayTopMenu(TopM, iClient, TopMenuPosition_LastCategory);
			}
		}
	}
}

//---//
//KFG//
//---//
KFG_load()
{
		if(kv_rank != INVALID_HANDLE) CloseHandle(kv_rank);
		if(rannam != INVALID_HANDLE) CloseHandle(rannam);
		if(trie_weapon != INVALID_HANDLE) CloseHandle(trie_weapon);
		if(trie_rank1 != INVALID_HANDLE) CloseHandle(trie_rank1);
		if(trie_rank2 != INVALID_HANDLE) CloseHandle(trie_rank2);
		if(trie_rank3 != INVALID_HANDLE) CloseHandle(trie_rank3);
		kv_rank = CreateKeyValues("rank");
		decl String:path[128];
		BuildPath(Path_SM, path, 128, "configs/rank.ini");
		if(!FileToKeyValues(kv_rank, path)) SetFailState("[Rank] - Файл конфигураций не найден");
		else
		{
			decl String:w[32], String:h[128];
			KvRewind(kv_rank);
			RankCore = StatusRank:KvGetNum(kv_rank, "mode");
			KvGetString(kv_rank, "flag", path, 128, "z");
			for(new i = 0; i < 128; i++) path[i] = CharToLower(path[i]);
			fg = ReadFlagString(path);
			tab_rank = bool:KvGetNum(kv_rank, "tab_rank");
			rank_hd = bool:KvGetNum(kv_rank, "rank_hd");
			rank_hd_team = bool:KvGetNum(kv_rank, "rank_hd_team");
			switch (RankCore)
			{
				case Core:
				{
					Database_connect();
					mesn = bool:KvGetNum(kv_rank, "mesn");
					kill = KvGetNum(kv_rank, "kill");
					death = KvGetNum(kv_rank, "death");
					assister = KvGetNum(kv_rank, "assister");
					headshot = KvGetNum(kv_rank, "headshot");
					penetrated = KvGetNum(kv_rank, "penetrated");
					c4 = KvGetNum(kv_rank, "c4");
					mnxp = bool:KvGetNum(kv_rank, "m_xp");
					mmxp = bool:KvGetNum(kv_rank, "r_xp");
					delit = KvGetNum(kv_rank, "del");
					if(delit < 1) delit = 1;
					resetu = bool:KvGetNum(kv_rank, "reset_pl");
					minpl = KvGetNum(kv_rank, "min_pl");
					new del_tim = KvGetNum(kv_rank, "del_tim");
					if(del_tim)
					{
						FormatEx(path, 128, "DELETE FROM rank WHERE tim <= %d;", GetTime()-(del_tim*86400));
						SQL_TQuery(bd_rank, SQL_Check, path);
					}
					SQL_TQuery(bd_rank, SQLT_OnGetTotal, "SELECT COUNT(*) FROM `rank`");
					KvJumpToKey(kv_rank, "weapon");
					KvGotoFirstSubKey(kv_rank, false); 
					trie_weapon = CreateTrie(); 
					do
					{
						KvGetSectionName(kv_rank, w, 32);
						SetTrieValue(trie_weapon, w, KvGetFloat(kv_rank, "")); 
					}
					while (KvGotoNextKey(kv_rank, false));
				}
				case hlstats:
				{
					KvGetString(kv_rank, "hlstats_game", hlstats_game, 64);
					if(!hlstats_game[0]) SetFailState("[Rank] Ошибка hlstats_game не указано");
					if(bd_rank != INVALID_HANDLE) CloseHandle(bd_rank);
					decl String:szError[255];
					bd_rank = SQL_Connect("hlstats", false, szError, 255);
					if(bd_rank == INVALID_HANDLE) SetFailState("[Rank] Ошибка подключения к базе данных (%s)", szError);
					IRank[hlstats] = true;
				}
			}
			KvRewind(kv_rank);
			decl String:ui[32][32], String:uo[512];
			KvGetString(kv_rank, "comand", uo, 512, "sm_rank");
			new jl = ExplodeString(uo, ";", ui, 32, 32);
			for (new i = 0; i < jl; i++) RegConsoleCmd(ui[i], sm_rank);
			KvGetString(kv_rank, "lvl_up_sound", lvl_sound[0], 256);
			KvGetString(kv_rank, "lvl_down_sound", lvl_sound[1], 256);
			KvGetString(kv_rank, "lvl_up_overlay", lvl_overlay[0], 256);
			KvGetString(kv_rank, "lvl_down_overlay", lvl_overlay[1], 256);
			KvJumpToKey(kv_rank, "xp");
			KvGotoFirstSubKey(kv_rank);
			trie_rank1 = CreateTrie();
			trie_rank2 = CreateTrie();
			trie_rank3 = CreateTrie();
			rannam = CreateMenu(rannamMenu);
			SetMenuTitle(rannam, "Список званий\n ");
			SetMenuExitBackButton(rannam, true);
			rank_k = -1;
			do
			{
				if(KvGetSectionName(kv_rank, w, 32))
				{
					rank_k++;
					rank[rank_k] = StringToInt(w);
					SetTrieValue(trie_rank1, w, KvGetNum(kv_rank, "rank"));
					KvGetString(kv_rank, "pref", h, 128);
					CGOReplaceColorSay(h, 128);
					SetTrieString(trie_rank2, w, h);
					KvGetString(kv_rank, "name", h, 128);
					SetTrieString(trie_rank3, w, h);
					FormatEx(path, 128, "%s - %d xp", h, rank[rank_k]);
					AddMenuItem(rannam, "", path, ITEMDRAW_DISABLED);
				}
			}
			while KvGotoNextKey(kv_rank);
		}
}

public rannamMenu(Handle:hMenu, MenuAction:action, iClient, Item)
{
	if(action == MenuAction_Cancel && Item == MenuCancel_ExitBack) sm_rank(iClient, 0);
}

public SQL_Check(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl == INVALID_HANDLE) LogError("[Rank] Ошибка (%s)", error);	
}

//----------//
// database //
//----------//
Database_connect()
{
	if(bd_rank != INVALID_HANDLE) CloseHandle(bd_rank);
	decl String:szError[255];
	bd_rank = SQL_Connect("rank", false, szError, 255);
	if(bd_rank == INVALID_HANDLE) SetFailState("[Rank] Ошибка подключения к базе данных (%s)", szError);
	SQL_LockDatabase(bd_rank);
	SQL_FastQuery(bd_rank, "CREATE TABLE IF NOT EXISTS rank (steamid VARCHAR(32) PRIMARY KEY, name VARCHAR(128), xp int(12), tim int(12));");
	SQL_UnlockDatabase(bd_rank);
}

public SQLT_OnGetTotal(Handle:hOwner, Handle:hQuery, const String:sError[], any:uuu) g_iTotalPlayers = SQL_FetchInt(hQuery, 0);

ClientOverlay(iClient, String:strOverlay[], Float:yy)
{
	ClientCommand(iClient, "r_screenoverlay \"%s\"", strOverlay);
	CreateTimer(yy, DeleteOverlay, GetClientUserId(iClient));
}

public Action:DeleteOverlay(Handle:hTimer, any:id)
{
	new iClient = GetClientOfUserId(id);
	if(iClient) ClientCommand(iClient, "r_screenoverlay \"\"");
}

public Action:Say(iClient, const String:command[], args) 
{ 
	if(!iClient || !IsClientInGame(iClient)) return Plugin_Continue; 
	decl String:sText[192]; 
	GetCmdArgString(sText, sizeof(sText)); 
	if(resetcl[iClient]) 
	{
		decl String:nuum[50]; 
		IntToString(resetcl[iClient], nuum, 50); 
		if(StrContains(sText, nuum) != -1)
		{
			resetcl[iClient] = 0;
			give_xp(iClient, xp[iClient]*-1);
			CGOPrintToChat(iClient, "{RED}Вы успешно сбросили свое звание");
		}
		else if(StrContains(sText, "stopr") != -1)
		{
			resetcl[iClient] = 0;
			CGOPrintToChat(iClient, "{GREEN}Сброс звание отменен");
		}
		else CGOPrintToChat(iClient, "{RED}Для подтверждения обнуления введите в чат {GREEN}%s {RED}для отмены stopr", nuum);
		return Plugin_Handled;
	}
	return Plugin_Continue; 
}