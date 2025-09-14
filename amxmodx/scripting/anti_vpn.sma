// Do not uncomment this in prod
//#define DEBUG

#include <amxmodx>
#include <amxmisc>
#include <easy_http>
#include <nvault>
#include <reapi>

#define PLUGIN 	"[Anti-VPN]"
#define VERSION	"3.3-Reapi"
#define AUTHOR	"Shadows Adi"

#if !defined MAX_PLAYERS
#define MAX_PLAYERS 32
#endif

#if !defined MAX_IP_LENGTH
#define MAX_IP_LENGTH 16
#endif

enum _:Pdata
{
	iIP[MAX_IP_LENGTH],
	szNAME[MAX_NAME_LENGTH],
	szCountry[5],
	szCity[32]
}

enum
{
	iCountries = 1,
	iWhiteList,
	iBlackList,
	iWhiteListIPs
}

enum
{
	None = 1,
	VPN,
	Country
}

enum _:Data
{
	iType,
	IP[28]
}

new c_BanDuration;
new c_PusishType;
new g_szContact[64]
new g_szAPIKey[64]

new iVault;

new g_szIP[45][Pdata];
new g_iCurrentIP = 10;

new Array:g_aSkipCheck
new Array:g_aCountryBlock
new Array:g_aIPBlacked
new Array:g_aDetectedIPs
new Array:g_aIPDetected

new EzHttpRequest:g_httpRequestID = EzHttpRequest:-1;

public plugin_precache()
{
	g_aSkipCheck = ArrayCreate(MAX_NAME_LENGTH)
 
	g_aCountryBlock = ArrayCreate(4)
 
	g_aIPBlacked = ArrayCreate(20)
 
	g_aDetectedIPs = ArrayCreate(Data)

	g_aIPDetected = ArrayCreate(30)
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_cvar("anti_vpn", AUTHOR, FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_UNLOGGED|FCVAR_SPONLY);

	c_PusishType = register_cvar("vpn_punish_type", "none");
 
	c_BanDuration = register_cvar("vpn_ban_time", "3");
  
	get_pcvar_string(register_cvar("vpn_contact", ""), g_szContact, charsmax(g_szContact))

	get_pcvar_string(register_cvar("vpn_apikey_cvar", ""), g_szAPIKey, charsmax(g_szAPIKey))
 
 	/* Caching API response in order to avoid API's rate limits */
	new szVault[20], iDate[8];
	get_time("%W_%Y", iDate, charsmax(iDate))
	formatex(szVault, charsmax(szVault), "VPN_Check_%s", iDate);
 
	if( ( iVault = nvault_open(szVault) ) == INVALID_HANDLE )
	{
		set_fail_state("[ANTI-VPN] Can't open %s nVault.", szVault);
	}
 
	register_concmd("amx_remove_vpn", "concmd_remove_vpn", ADMIN_RCON, "<IP Address>");
 
	RegisterHookChain(RH_SV_ConnectClient, "Hook_SV_ConnectClient_pre");
	register_clcmd("say", "check_say");
	register_clcmd("say_team", "check_say");
 
	set_task(5.0, "task_check_players", .flags = "b")
}
 
public plugin_cfg()
{
	new flags[33]
	get_pcvar_string(register_cvar("vpn_reload_file_access", "a"), flags, charsmax(flags))
	register_concmd("amx_reload_whitelist_file", "ConCMD_Reload", read_flags(flags))
 
	ReadFile()
}
 
public ConCMD_Reload(id, level, cid)
{
	if(!cmd_access(id, level, cid, 1))
	{
		return PLUGIN_HANDLED
	}
 
	new iSuccess
	iSuccess = ReadFile()
 
	console_print(id, "%s Configuration file has been reloaded %ssuccesfully", PLUGIN, iSuccess ? "" : "un")
 
	return PLUGIN_HANDLED
}
 
public concmd_remove_vpn(id, level, cid)
{
	if (!cmd_access(id, level, cid, 2, false))
	{
		return;
	}
 
	new szIP[20];
	read_argv(1, szIP, charsmax(szIP));
	trim(szIP);
 
	nvault_remove(iVault, szIP);
 
	console_print(id, "[Anti-VPN] IP Removed: %s", szIP);
	log_to_file("anti_vpn.log", "[IP Removed] %s by %n", szIP, id);
}
 
public plugin_end()
{
	if(ezhttp_is_request_exists(g_httpRequestID))
		ezhttp_cancel_request(g_httpRequestID)

	nvault_close(iVault);
	ArrayDestroy(g_aSkipCheck);
	ArrayDestroy(g_aIPBlacked);
	ArrayDestroy(g_aCountryBlock);
	ArrayDestroy(g_aDetectedIPs);
	ArrayDestroy(g_aIPDetected);
}
 
public task_check_players()
{
	new sIP[30]
	new sUserIP[28]
	static reason[128]

	new iPlayer, iNum, iPlayers[MAX_PLAYERS]
	get_players(iPlayers, iNum)

	for(new j; j < iNum; j++)
	{
		iPlayer = iPlayers[j];

		get_user_ip(iPlayer, sUserIP, charsmax(sUserIP), 1)

		for(new i; i < ArraySize(g_aIPDetected); i++)
		{
			ArrayGetString(g_aIPDetected, i, sIP, charsmax(sIP))

			ArrayDeleteItem(g_aIPDetected, i)

			if(equali(sIP, sUserIP))
			{
				formatex(reason, charsmax(reason),"Your IP is blacklisted! Visit ^"%s^" and leave your name to join!", g_szContact);

				log_to_file("anti_vpn.log", "Blacklisted Player with IP ^"%s^" connected and was kicked!", sUserIP);

				punish_by_type(sIP, .szReason = reason, .bFromCheck = true, .id = iPlayer);
			}
		}
	}
	
	return PLUGIN_CONTINUE;
}

public client_connectex(id, const name[], const ip[], reason[128])
{
	new sIP[Data]
	new sUserIP[28]

	if(id == -1 || !g_aIPDetected)
		return PLUGIN_CONTINUE;
 
	get_user_ip(id, sUserIP, charsmax(sUserIP), 1)
 
	for(new i; i < ArraySize(g_aDetectedIPs); i++)
	{
		ArrayGetArray(g_aDetectedIPs, i, sIP)
 
		if(equali(sIP, sUserIP))
		{
			ArrayDeleteItem(g_aDetectedIPs, i)

			switch(sIP[iType])
			{
				case VPN:
				{
					formatex(reason, charsmax(reason), "VPN Detected!");
					
				}
				case Country:
				{
					formatex(reason, charsmax(reason),"Your Country is blacklisted! Visit ^"%s^" and leave your name to join!", g_szContact);
				}
			}
			server_cmd("kick #%d ^"%s^"", get_user_userid(id), reason);

			return PLUGIN_HANDLED;
		}
	}
	return PLUGIN_CONTINUE;
} 

ReadFile()
{
	new szConfigsDir[256], szFileName[256]
	get_localinfo("amxx_configsdir", szConfigsDir, charsmax(szConfigsDir))
	formatex(szFileName, charsmax(szFileName), "%s/VPNConfiguration.ini", szConfigsDir)
 
	new iFile = fopen(szFileName, "rt")
 
	if(!iFile)
		return 0
 
	ArrayClear(g_aSkipCheck)
	ArrayClear(g_aCountryBlock)
	ArrayClear(g_aIPBlacked)
 
	new szData[40], szTemp[38], iSection
 
	while(fgets(iFile, szData, charsmax(szData)))
	{
		trim(szData)
 
		if(szData[0] == '#' || szData[0] == EOS || szData[0] == ';')
			continue
 
		if(szData[0] == '[')
		{
			iSection += 1
			continue
		}
 
		switch(iSection)
		{
			case iCountries:
			{
				parse(szData, szTemp, charsmax(szTemp))
 
				ArrayPushString(g_aCountryBlock, szTemp)
			}
			case iWhiteList, iWhiteListIPs:
			{
				parse(szData, szTemp, charsmax(szTemp))
 
				ArrayPushString(g_aSkipCheck, szTemp)
			}
			case iBlackList:
			{
				parse(szData, szTemp, charsmax(szTemp))
 
				ArrayPushString(g_aIPBlacked, szTemp)
			}
		}
	}
	fclose(iFile)
 
	return 1
}
 
public Hook_SV_ConnectClient_pre()
{
	g_iCurrentIP += 1;
	if(g_iCurrentIP == 35)
	{
		g_iCurrentIP = 10;
	}
	new szTemp[512];
 
	read_argv(4, szTemp, charsmax(szTemp));
 
	new iPosName = containi(szTemp, "name");

	rh_get_net_from(g_szIP[g_iCurrentIP][iIP], charsmax(g_szIP[][iIP]));
 
	if(iPosName != -1)
	{
		/* iPosName shows the position in the userinfo for name and adding 5 will skip 5 characters  : "name\" */
		copyc(g_szIP[g_iCurrentIP][szNAME], charsmax(g_szIP[][szNAME]), szTemp[iPosName + 5], '\')
	}
 
	new iPos = contain(g_szIP[g_iCurrentIP][iIP], ":");
 
	if(iPos != -1) 
	{
		g_szIP[g_iCurrentIP][iIP][iPos] = EOS;
	}
 
	if(CheckAdditional(g_iCurrentIP))
		return;
 
	SendRequest(g_iCurrentIP, g_szIP[g_iCurrentIP][iIP], g_szIP[g_iCurrentIP][szNAME]);
}

public check_say(id)
{
	g_iCurrentIP += 1;
	if(g_iCurrentIP == 35)
	{
		g_iCurrentIP = 10;
	}

	rh_get_net_from(g_szIP[g_iCurrentIP][iIP], charsmax(g_szIP[][iIP]));
 
	get_user_name(id, g_szIP[g_iCurrentIP][szNAME], charsmax(g_szIP[][szNAME]))
 
	new iPos = contain(g_szIP[g_iCurrentIP][iIP], ":");
 
	if(iPos != -1) 
	{
		g_szIP[g_iCurrentIP][iIP][iPos] = EOS;
	}
 
	if(CheckAdditional(g_iCurrentIP))
		return;
 
	SendRequest(g_iCurrentIP, g_szIP[g_iCurrentIP][iIP], g_szIP[g_iCurrentIP][szNAME]);
}
 
CheckAdditional(id)
{
	new szTemp[48]
 
	for(new i; i < ArraySize(g_aSkipCheck); i++)
	{
		ArrayGetString(g_aSkipCheck, i, szTemp, charsmax(szTemp));
 
		if(equali(szTemp, g_szIP[id][szNAME]))
		{
			log_to_file("anti_vpn.log", "Whitelisted Player ^"%s^" joined the server!", szTemp);
			return PLUGIN_HANDLED;
		}
		else if(equali(szTemp, g_szIP[id][iIP]))
		{
			log_to_file("anti_vpn.log", "Whitelisted IP ^"%s^" joined the server!", szTemp);
			return PLUGIN_HANDLED;
		}
	}
 
	new szFormat[128]
 
	for(new i; i < ArraySize(g_aIPBlacked); i++)
	{
		ArrayGetString(g_aIPBlacked, i, szTemp, charsmax(szTemp));
 
		if(equali(szTemp, g_szIP[id][iIP], strlen(szTemp)))
		{
			formatex(szFormat, charsmax(szFormat), "Your IP is blacklisted! Visit ^"%s^" and leave your name to join!", g_szContact)
			log_to_file("anti_vpn.log", "Blacklisted Player ^"%s^" with IP ^"%s^" tried to join the server!", g_szIP[id][szNAME], g_szIP[id][iIP]);
			punish_by_type(g_szIP[id][iIP], g_szIP[id][szNAME], szFormat);
			return PLUGIN_HANDLED;
		}
	}
 
	return PLUGIN_CONTINUE;
}
 
stock LoadData(id ,const szIP[] = "")
{
	if(iVault == INVALID_HANDLE)
	{
		return 0
	}
 
	new szData[8], iTimestamp;
	if(nvault_lookup(iVault, szIP, szData, charsmax(szData), iTimestamp))
	{
		if(szData[0] == '1')
			return VPN;
 
		else if(szData[2] == '1')
		{
			formatex(g_szIP[id][szCountry], charsmax(g_szIP[][szCountry]), "%s", szData[4])
			return Country;
		}
		else 
		{
			return None
		}
	}
	return 0;
}
 
stock SaveData(szIP[] = "", szValue[])
{
	if(szIP[0] != EOS && iVault != INVALID_HANDLE )
	{
		nvault_set(iVault, szIP, szValue);
	}
}

SendRequest(id = 0, szIP[] = "", szName[] = "")
{
	if(is_bot(szIP))
	{
		log_to_file("anti_vpn.log", "Bot detected ^"%s^". IP: ^"%s^"", szName, szIP);
		return;
	}

	#if !defined DEBUG
	new iValue = LoadData(id, szIP)
	if(iValue)
	{
		if(iValue > None)
		{
			new iData[Data]
			iData[iType] = iValue
 
			copy(iData[IP], charsmax(iData[IP]), szIP)
 
			ArrayPushArray(g_aDetectedIPs, iData)
			ArrayPushString(g_aIPDetected, szIP)
		}
 
		switch(iValue)
		{
			case VPN:
			{
				punish_player(szIP, szName);
				return;
			}
			case Country:
			{
				format_country(id, szIP);
				return;
			}
			default:
			{
				return;
			}
		}
	}
	#endif

	new szTemp[140];
 
	formatex(szTemp, charsmax(szTemp), "https://proxycheck.io/v2/%s?key=%s&vpn=1&asn=1&cur=0&p=0&short=1", szIP, g_szAPIKey);

	new sIP[MAX_IP_LENGTH + 3]

	formatex(sIP, charsmax(sIP), "%s#%i", szIP, id)

	new EzHttpOptions:httpOptions = ezhttp_create_options();

	/* 5s timeout just for safety*/
	ezhttp_option_set_timeout(httpOptions, 5000);
	ezhttp_option_set_plugin_end_behaviour(httpOptions, EZH_CANCEL_REQUEST);
	ezhttp_option_set_user_data(httpOptions, sIP, charsmax(sIP))
	g_httpRequestID = ezhttp_post(szTemp, "CallbackFunc", httpOptions);
}

public CallbackFunc(EzHttpRequest:httpReqID)
{
	if(ezhttp_get_http_code(httpReqID) != 200)
	{
		new szError[128]
		ezhttp_get_error_message(httpReqID, szError, charsmax(szError))
		return
	}

	new szBuffer[512]
	ezhttp_get_data(httpReqID, szBuffer, charsmax(szBuffer))

	new szIP[MAX_IP_LENGTH + 3]
	ezhttp_get_user_data(httpReqID, szIP)

	new id[3]

	strtok2(szIP, szIP, charsmax(szIP), id, charsmax(id), '#')

	new iPlayer = str_to_num(id)

	new EzJSON:eJsonObject 

	if((eJsonObject = ezjson_parse(szBuffer)) == EzInvalid_JSON)
		return

	new szTemp[MAX_IP_LENGTH]

	ezjson_object_get_string(eJsonObject, "status", szTemp, charsmax(szTemp))

	if(containi(szTemp, "ok") == -1)
		return

	ezjson_object_get_string(eJsonObject, "ip", szTemp, charsmax(szTemp))

	copy(g_szIP[iPlayer][iIP], charsmax(g_szIP[][iIP]), szTemp)

	ezjson_object_get_string(eJsonObject, "isocode", szTemp, charsmax(szTemp))

	copy(g_szIP[iPlayer][szCountry], charsmax(g_szIP[][szCountry]), szTemp)

	ezjson_object_get_string(eJsonObject, "city", szTemp, charsmax(szTemp))

	copy(g_szIP[iPlayer][szCity], charsmax(g_szIP[][szCity]), szTemp)

	ezjson_object_get_string(eJsonObject, "proxy", szTemp, charsmax(szTemp))

	new bool:bHasVPN = (szTemp[0] == 'y') ? true : false

	ezjson_free(eJsonObject)

	task_check_vpn(iPlayer, g_szIP[iPlayer][iIP], g_szIP[iPlayer][szNAME], g_szIP[iPlayer][szCountry], g_szIP[iPlayer][szCity], bHasVPN);
}

task_check_vpn(id, sIp[], sName[], sCountry[], sCity[], bool:bVPN = false)
{
	new iValue = CheckCountry(id, sIp)
	#if !defined DEBUG
	if(iValue)
	{
		new szTemp[8]
		formatex(szTemp, charsmax(szTemp), "0;1;%s", sCountry)
		SaveData(sIp, szTemp)
	}
	else if(bVPN)
	{
		SaveData(sIp, "1;0")
	}
	else
	{
		SaveData(sIp, "0;0")
	}
	#endif
 
	if(iValue)
	{
		return
	}
 
	if(bVPN)
	{
		punish_player(sIp, sName, sCountry, sCity);
	}
}
 
public CheckCountry(id, sIp[])
{
	new szTemp[5]
 
	for(new i; i < ArraySize(g_aCountryBlock); i++)
	{
		ArrayGetString(g_aCountryBlock, i, szTemp, charsmax(szTemp));
 
		if(equali(szTemp, g_szIP[id][szCountry], strlen(szTemp)))
		{
			format_country(id, sIp)
			return PLUGIN_HANDLED;
		}
	}
 
	return PLUGIN_CONTINUE;
}

format_country(id, sIp[])
{
	new szFormat[128];

	formatex(szFormat, charsmax(szFormat), "Your Country is blacklisted! Visit ^"%s^" and leave your name to join!", g_szContact);
	log_to_file("anti_vpn.log", "Blacklisted Player ^"%s^" from ^"%s^" tried to join the server! IP: ^"%s^"", g_szIP[id][szNAME], g_szIP[id][szCountry], sIp);
	punish_by_type(g_szIP[id][iIP], g_szIP[id][szNAME], szFormat);
}

punish_player(szIP[], szName[], sCountry[] = "N/A", sCity[] = "N/A") 
{
	log_to_file("anti_vpn.log", "VPN DETECTED: %s | %s | %s | %s", szName, szIP, sCountry, sCity);
	
	punish_by_type(szIP, szName, "VPN Detected!");

	return PLUGIN_HANDLED;
}

punish_by_type(szIP[] = "", szName[] = "", szReason[], bool:bFromCheck = false, id = -1)
{
	new szType[7];
	get_pcvar_string(c_PusishType, szType, charsmax(szType));

	ArrayPushString(g_aIPDetected, szIP)
 	
 	if(bFromCheck)
 	{
 		switch(szType[0])
		{
			case 'k':
			{
				server_cmd("kick #%d ^"%s^"", get_user_userid(id), szReason);
			}
			case 'b':
			{
				server_cmd("addip %d ^"%s^"", get_pcvar_num(c_BanDuration), szIP);
				server_cmd("kick #%d ^"%s^"", get_user_userid(id), szReason);
			}
		}
 	}
 	else
 	{
 		switch(szType[0])
		{
			case 'k':
			{
				server_cmd("kick ^"%s^" ^"%s^"", szName, szReason);
			}
			case 'b':
			{
				server_cmd("addip %d ^"%s^"", get_pcvar_num(c_BanDuration), szIP);
				server_cmd("kick ^"%s^" ^"%s^"", szName, szReason);
			}
		}
 	}
}

bool:is_bot(const szIP[])
{
	if(containi(szIP, "127.0.") != -1 || containi(szIP, "192.168.") != -1)
	{
		return true;
	}
	return false;
}
