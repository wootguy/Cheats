
// Requests:
// giveammo [amt] [type] - if type is ommitted, it gives ammo for current weapon
// rate of fire modifier? clip/max ammo modifier? reload speed? damage modifier?
// infinite jump
// infammo
// setammo

// TEST:
// maxhealth amt
// maxcharge amt

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor( "w00tguy" );
	g_Module.ScriptInfo.SetContactInfo( "w00tguy123 - forums.svencoop.com" );
	
	g_Hooks.RegisterHook( Hooks::Player::ClientSay, @ClientSayCheat );
	g_Hooks.RegisterHook( Hooks::Game::MapChange, @MapChange );
	
	initCheatAliases();
	
	g_Scheduler.SetInterval("noclipFix", 0);
}

void print(string text) { g_Game.AlertMessage( at_console, text); }
void println(string text) { print(text + "\n"); }

void printPlr(CBasePlayer@ plr, string text) { g_PlayerFuncs.ClientPrint( plr, HUD_PRINTCONSOLE, text); }
void printlnPlr(CBasePlayer@ plr, string text) { printPlr(plr, text + "\n"); }

HookReturnCode MapChange()
{
	player_states.deleteAll();
	//cheats_for_all = false;	
	return HOOK_CONTINUE;
}

enum cheat_type
{
	CHEAT_TOGGLE, // some state like godmode or noclip
	CHEAT_GIVE, // a give command or impulse 101
	CHEAT_ACTION, // do something to someone (e.g. revive, heal, charge)
};

enum cheat_toggle_modes
{
	TOGGLE_OFF,
	TOGGLE_ON,
	TOGGLE_TOGGLE, // lol	
};

enum cheat_fail_reasons
{
	FAIL_TARGET_DEAD = -999,
	FAIL_TARGET_ALIVE,
	FAIL_TARGET_ADMIN,
}

// params = target player, cheat arguments
funcdef int CheatFunction(CBasePlayer@, array<string>@);

class Cheat
{
	string name; // used in text messages (e.g. "w00tguy gave you noclip")
	CheatFunction@ cheatFunc; // function to execute
	int type;	 // cheat_type
	int numArgs; // args required by the command
	int lastState; // for toggled cheats
	bool adminOnly; // if true, peasents can't use the cheat even when global cheats are enabled
	bool ownerOnly; // if true, nobody but the server owner can use the cheat
	
	Cheat(string name, CheatFunction@ cheatFunc, int type, int numArgs, bool adminOnly, bool ownerOnly)
	{
		this.name = name;
		@this.cheatFunc = cheatFunc;
		this.type = type;
		this.numArgs = numArgs;
		this.adminOnly = adminOnly;
		this.ownerOnly = ownerOnly;
		lastState = TOGGLE_OFF;
	}
};

// --------------------------------
// CHANGE CHEAT PERMISSIONS HERE!!!
// --------------------------------

// The last two columns with true/false values control who can use the cheat:
// 'true' in the 1st column = only admins can use the cheat when '.cheats 1' is active
// 'true' in the 2nd column = only the server owner can use the cheat
dictionary cheats = {
	{'.noclip',     Cheat("noclip",     toggleNoclip,   CHEAT_TOGGLE,   0, false, false)},
	{'.godmode',    Cheat("godmode",    toggleGodmode,  CHEAT_TOGGLE,   0, false, false)},
	{'.notarget',   Cheat("notarget",   toggleNotarget, CHEAT_TOGGLE,   0, false, false)},
	{'.cloak',   	Cheat("cloak",   	toggleCloak, 	CHEAT_TOGGLE,   0, false, false)},
	{'.notouch',    Cheat("notouch",    toggleNotouch,  CHEAT_TOGGLE,   0, false, false)},
	{'.cheats',     Cheat("cheats",     toggleCheats,  	CHEAT_TOGGLE,   0, true,  false)},
	{'.impulse',    Cheat("impulse %0", useImpulse,     CHEAT_GIVE,     1, false, false)},
	{'.give',  	    Cheat("%0",   	    giveItem,       CHEAT_GIVE, 	1, false, false)},
	{'.givepoints', Cheat("%0 points",  givePoints,     CHEAT_GIVE, 	1, false, false)},
	{'.maxhealth',  Cheat("maxhealth",  setMaxHealth,   CHEAT_GIVE,     1, false, false)},
	{'.maxarmor',   Cheat("maxarmor",   setMaxCharge,   CHEAT_GIVE,     1, false, false)},
	{'.speed',   	Cheat("speed",   	setMaxSpeed,    CHEAT_GIVE,     1, false, false)},
	{'.giveall',    Cheat("everything", giveAll,        CHEAT_GIVE, 	0, false, false)},
	{'.heal',       Cheat("healed",	    heal,     	    CHEAT_ACTION,   0, false, false)},
	{'.charge',     Cheat("recharged",  charge,     	CHEAT_ACTION,   0, false, false)},
	{'.revive',     Cheat("revived",    revive,     	CHEAT_ACTION,   0, false, false)},
	{'.strip',      Cheat("stripped",   strip,     	    CHEAT_ACTION,   0, false, false)}
};

// ------------------
// End of permissions
// ------------------

CClientCommand _cheatlist(  "cheatlist",  "Show all possible cheats", @cheatCmd );
CClientCommand _noclip(     "noclip",     "Fly through walls", @cheatCmd );
CClientCommand _godmode(    "godmode",    "Take no damage", @cheatCmd );
CClientCommand _god(        "god",        "Take no damage", @cheatCmd );
CClientCommand _notarget(   "notarget",   "Monsters ignore you", @cheatCmd );
CClientCommand _cloak(   	"cloak",      "Monsters ignore you and you're invisible", @cheatCmd );
CClientCommand _notouch(    "notouch",    "Things pass through you, triggers ignore you", @cheatCmd );
CClientCommand _nonsolid(   "nonsolid",   "Things pass through you, triggers ignore you", @cheatCmd );
CClientCommand _cheats(     "cheats",     "Allow cheats for players", @cheatCmd );
CClientCommand _impulse(    "impulse",    "Half-Life impulse cheats", @cheatCmd );
CClientCommand _give(       "give",       "Give a weapon_ or ammo_ item", @cheatCmd );
CClientCommand _givepoints( "givepoints", "Adjust user score", @cheatCmd );
CClientCommand _giveall(    "giveall",    "Give all weapons and infinite ammo", @cheatCmd );
CClientCommand _heal(       "heal",       "Retore to full health", @cheatCmd );
CClientCommand _healme(     "healme",     "Retore to full health", @cheatCmd );
CClientCommand _charge(     "charge",     "Fully charge HEV suit", @cheatCmd );
CClientCommand _chargeme(   "chargeme",   "Fully charge HEV suit", @cheatCmd );
CClientCommand _recharge(   "recharge",   "Fully charge HEV suit", @cheatCmd );
CClientCommand _revive(     "revive",     "Bring back to life", @cheatCmd );
CClientCommand _strip(      "strip",      "Remove all weapons and ammo", @cheatCmd );
CClientCommand _maxhealth(  "maxhealth",  "Adjust maximum health", @cheatCmd );
CClientCommand _maxarmor(   "maxarmor",   "Adjust maximum armor", @cheatCmd );
CClientCommand _maxcharge(  "maxcharge",  "Adjust maximum armor", @cheatCmd );
CClientCommand _speed(   	"speed",  	  "Adjust maximum movement speed", @cheatCmd );

void initCheatAliases() {
	cheats[".god"] = cheats[".godmode"];
	cheats[".nonsolid"] = cheats[".notouch"];
	cheats[".healme"] = cheats[".heal"];
	cheats[".chargeme"] = cheats[".charge"];
	cheats[".recharge"] = cheats[".charge"];
	cheats[".reviveme"] = cheats[".revive"];
	cheats[".maxcharge"] = cheats[".maxarmor"];
}

array<string> impulse_101_weapons = {
	"weapon_crowbar",
	"weapon_9mmhandgun",
	"weapon_357",
	"weapon_9mmAR",
	"weapon_crossbow",
	"weapon_shotgun",
	"weapon_rpg",
	"weapon_gauss",
	"weapon_egon",
	"weapon_hornetgun",
	"weapon_uziakimbo",
	"weapon_medkit",
	"weapon_pipewrench",
	"weapon_grapple",
	"weapon_sniperrifle",
	"weapon_m249",
	"weapon_m16",
	"weapon_sporelauncher",
	"weapon_eagle",
	"weapon_displacer"
};

array<string> impulse_101_items = {
	"weapon_handgrenade",
	"weapon_tripmine",
	"weapon_satchel",
	"weapon_snark"
};

array<string> impulse_101_ammo = {
	"ammo_sporeclip", "ammo_sporeclip", "ammo_sporeclip", "ammo_sporeclip", "ammo_sporeclip",
	"ammo_357",
	"ammo_556",
	"ammo_762",
	"ammo_rpgclip",
	"ammo_gaussclip",
	"ammo_9mmAR", "ammo_9mmclip",
	"ammo_buckshot", "ammo_buckshot",
	"ammo_ARgrenades",
	"ammo_crossbow", "ammo_crossbow"
};

array<string> giveAllList = {
	"weapon_crowbar",
	"weapon_9mmhandgun",
	"weapon_357",
	"weapon_9mmAR",
	"weapon_crossbow",
	"weapon_shotgun",
	"weapon_rpg",
	"weapon_gauss",
	"weapon_egon",
	"weapon_hornetgun",
	"weapon_handgrenade", "weapon_handgrenade",
	"weapon_tripmine", "weapon_tripmine", "weapon_tripmine", "weapon_tripmine", "weapon_tripmine",
	"weapon_satchel", "weapon_satchel", "weapon_satchel", "weapon_satchel", "weapon_satchel",
	"weapon_snark", "weapon_snark", "weapon_snark",
	"weapon_uziakimbo",
	"weapon_medkit",
	"weapon_pipewrench",
	"weapon_grapple",
	"weapon_sniperrifle",
	"weapon_m249",
	"weapon_m16",
	"weapon_sporelauncher",
	"weapon_eagle",
	"weapon_displacer"
};

// ammo indexes (since I don't know the ammo item names to use with GetAmmoIndex())
int AMMO_SHOTGUN = 1;
int AMMO_MEDKIT = 2;
int AMMO_556 = 3;
int AMMO_762 = 4;
int AMMO_ARGRENADES = 5;
int AMMO_357 = 6;
int AMMO_9MM = 7;
int AMMO_SPORE = 9;
int AMMO_GAUSS = 10;
int AMMO_RPG = 11;
int AMMO_CROSSBOW = 12;
// Unused indexes(?): 0, 8

bool cheats_for_all = false;

dictionary player_states; // values are 0 or 1 (cheats enabled for non-admin)
array<EHandle> noclip_users; // list of players currently in noclip mode

bool isAdmin(CBasePlayer@ plr)
{
	return g_PlayerFuncs.AdminLevel(plr) >= ADMIN_YES;
}

bool isOwner(CBasePlayer@ plr)
{
	return g_PlayerFuncs.AdminLevel(plr) >= ADMIN_OWNER;
}

bool canCheat(CBasePlayer@ plr, bool adminOnlyCommand, bool ownerOnlyCommand)
{
	if (isAdmin(plr))
		return !ownerOnlyCommand;
		
	string id = getPlayerUniqueId(plr);
	bool peasentWithPrivledges = player_states.exists(id) and int(player_states[id]) != 0;
	
	if (cheats_for_all or peasentWithPrivledges)
		return !(adminOnlyCommand or ownerOnlyCommand);
		
	return false;
}

string getPlayerUniqueId(CBasePlayer@ plr)
{
	string steamId = g_EngineFuncs.GetPlayerAuthId( plr.edict() );
	if (steamId == 'STEAM_ID_LAN') {
		steamId = plr.pev.netname;
	}
	return steamId;
}

// get player by name, partial name, or steamId
CBasePlayer@ getPlayer(CBasePlayer@ caller, string name)
{
	name = name.ToLowercase();
	int partialMatches = 0;
	CBasePlayer@ partialMatch;
	CBaseEntity@ ent = null;
	do {
		@ent = g_EntityFuncs.FindEntityByClassname(ent, "player");
		if (ent !is null) {
			CBasePlayer@ plr = cast<CBasePlayer@>(ent);
			string plrName = string(plr.pev.netname).ToLowercase();
			string plrId = getPlayerUniqueId(plr).ToLowercase();
			if (plrName == name)
				return plr;
			else if (plrId == name)
				return plr;
			else if (plrName.Find(name) != uint(-1))
			{
				@partialMatch = plr;
				partialMatches++;
			}
		}
	} while (ent !is null);
	
	if (partialMatches == 1) {
		return partialMatch;
	} else if (partialMatches > 1) {
		g_PlayerFuncs.SayText(caller, 'Cheat failed. There are ' + partialMatches + ' players that have "' + name + '" in their name. Be more specific.');
	} else {
		g_PlayerFuncs.SayText(caller, 'Cheat failed. There is no player named "' + name + '"');
	}
	
	return null;
}

// disabling cheats should also remove active ones from peasents (they can't turn them off themselves)
void removePeasentCheats(CBasePlayer@ plr)
{
	if (!isAdmin(plr))
	{
		array<string> gargs = { "0" };
		toggleGodmode(plr, gargs);
		toggleNotarget(plr, gargs);
		toggleNotouch(plr, gargs);
		toggleNoclip(plr, gargs);
	}
}

// Apply a generic cheat after validating the arguments
// Also print out what happened in chat
void applyCheat(Cheat@ cheat, CBasePlayer@ cheater, const CCommand@ args)
{
	array<string> cheatArgs;
	// Cheat has enough args?
	if (args.ArgC()-1 < cheat.numArgs) {
		g_PlayerFuncs.SayText(cheater, "Not enough arguments supplied for cheat");
		return;
	}
	
	// player is allowed to use this cheat?
	if (!canCheat(cheater, cheat.adminOnly, cheat.ownerOnly)) {
		g_PlayerFuncs.SayText(cheater, "You don't have access to that command, peasent.\n");
		return;
	}
	
	// player wants to set toggle cheat on/off as opposed to just toggling it?
	int playerArg = cheat.numArgs+1;
	int toggleState = TOGGLE_TOGGLE;
	if (cheat.type == CHEAT_TOGGLE and args.ArgC() > 1) 
	{
		if (args[1] == '0' or args[1] == '1') {
			toggleState = atoi(args[1]);
			cheatArgs.insertLast(args[1]); // optional arg
			playerArg++;
		}
	} 
	
	// player is targetting someone else?
	CBasePlayer@ target = cheater;
	bool allPlayers = false;
	if (args.ArgC() > playerArg) {
		if (isAdmin(cheater))
		{
			if (args[playerArg][0] == '\\all' or args[playerArg] == '\\') {
				allPlayers = true;
			}
			else
			{
				@target = getPlayer(cheater, args[playerArg]);
				if (target is null)
					return;
			}
		}
		else
		{
			g_PlayerFuncs.SayTextAll(cheater, "Sorry, only admins can set cheats on other players\n");
			return;
		}
	}
	
	if (allPlayers and toggleState == TOGGLE_TOGGLE and cheat.type == CHEAT_TOGGLE and args[0] != '.cheats')
	{
		if (cheat.lastState == TOGGLE_OFF)
			toggleState = TOGGLE_ON;
		else
			toggleState = TOGGLE_OFF;
		cheat.lastState = toggleState;
		cheatArgs.insertLast(toggleState);
	}
	
	for (int i = 1; i < cheat.numArgs+1; i++) {
		cheatArgs.insertLast(args[i]);
	}
	
	if (args[0] == ".cheats" and cheater == target and !allPlayers)
	{
		if (toggleState != TOGGLE_TOGGLE)
		{
			allPlayers = true;
		}
		else
		{
			if (cheats_for_all)
				g_PlayerFuncs.SayText(target, "cheats are currently enabled for everyone\n");
			else
				g_PlayerFuncs.SayText(target, "cheats are currently disabled for all users except admins\n");
			return;
		}
	}
	
	if (allPlayers) // apply cheat to all players
	{
		CBaseEntity@ ent = null;
		do {
			@ent = g_EntityFuncs.FindEntityByClassname(ent, "player");
			if (ent !is null) {
				CBasePlayer@ plr = cast<CBasePlayer@>(ent);
				cheat.cheatFunc(plr, cheatArgs);
				
				if (args[0] == ".cheats" and (toggleState == TOGGLE_OFF or cheats_for_all))
					removePeasentCheats(plr);
			}
		} while (ent !is null);
		
		if (args[0] == ".cheats")
		{
			if (toggleState == TOGGLE_OFF)
				cheats_for_all = false;
			else if (toggleState == TOGGLE_ON)
				cheats_for_all = true;
			else
				cheats_for_all = !cheats_for_all;
			
			if (cheats_for_all)
				g_PlayerFuncs.SayTextAll(cheater, "" + cheater.pev.netname + " enabled cheats for everyone (type .cheatlist in console for help)\n");
			else
				g_PlayerFuncs.SayTextAll(cheater, "" + cheater.pev.netname + " disabled cheats for everyone\n");
		}
		else if (cheat.type == CHEAT_TOGGLE)
		{
			if (toggleState == TOGGLE_TOGGLE)
				g_PlayerFuncs.SayTextAll(cheater, "" + cheater.pev.netname + " toggled " + cheat.name + " on everyone\n");
			else if (toggleState == TOGGLE_ON)
				g_PlayerFuncs.SayTextAll(cheater, "" + cheater.pev.netname + " gave everyone " + cheat.name + "\n");
			else if (toggleState == TOGGLE_OFF)
				g_PlayerFuncs.SayTextAll(cheater, "" + cheater.pev.netname + " removed everyone's " + cheat.name + "\n");
		}
		else if (cheat.type == CHEAT_GIVE)
		{
			string giveName = cheat.name;
			if (giveName.Find("%0") != uint(-1)) {
				giveName = giveName.Replace("%0", cheatArgs[0]);
			}
			g_PlayerFuncs.SayTextAll(cheater, "" + cheater.pev.netname + " gave everyone " + giveName + "\n");
		}
		else if (cheat.type == CHEAT_ACTION)
		{
			g_PlayerFuncs.SayTextAll(target, "" + cheater.pev.netname + " " + cheat.name + " everyone\n");
		}
	}
	else // apply to specific player or self
	{
		//println("Apply " + args[0] + " from " + cheater.pev.netname + " to " + target.pev.netname);
		int ret = cheat.cheatFunc(target, cheatArgs);
		
		if (cheater != target) {
			// cheat applied to someone else
			
			if (cheat.type == CHEAT_TOGGLE)
			{
				if (ret == TOGGLE_ON) {
					g_PlayerFuncs.SayText(cheater, cheat.name + " enabled on " + target.pev.netname + "\n");
					
					if (args[0] == '.cheats')
						g_PlayerFuncs.SayText(target, "" + cheater.pev.netname + " gave you " + cheat.name + " (type .cheatlist in console for help)\n");
					else
						g_PlayerFuncs.SayText(target, "" + cheater.pev.netname + " gave you " + cheat.name + "\n");
				}
				else if (ret == TOGGLE_OFF) {
					g_PlayerFuncs.SayText(cheater, cheat.name + " disabled on " + target.pev.netname + "\n");
					g_PlayerFuncs.SayText(target, "" + cheater.pev.netname + " removed your " + cheat.name + "\n");
				}
				else if (ret == FAIL_TARGET_ADMIN) {
					g_PlayerFuncs.SayText(cheater, "Cheat failed. " + target.pev.netname + " is an admin.\n");
				}
				if (args[0] == ".cheats" and ret == TOGGLE_OFF)
					removePeasentCheats(target);
			}
			else if (cheat.type == CHEAT_GIVE)
			{
				string giveName = cheat.name;
				if (giveName.Find("%0") != uint(-1)) {
					giveName = giveName.Replace("%0", cheatArgs[0]);
				}
				g_PlayerFuncs.SayText(cheater, "Gave " + giveName + " to " + target.pev.netname + "\n");
				g_PlayerFuncs.SayText(target, "" + cheater.pev.netname + " gave you " + giveName + "\n");
			}
			else if (cheat.type == CHEAT_ACTION)
			{
				if (ret == FAIL_TARGET_DEAD)
					g_PlayerFuncs.SayText(cheater, "Cheat failed. " + target.pev.netname + " is dead.\n");
				else if (ret == FAIL_TARGET_ALIVE)
					g_PlayerFuncs.SayText(cheater, "Cheat failed. " + target.pev.netname + " is alive.\n");
				else {
					g_PlayerFuncs.SayText(cheater, cheat.name + " " + target.pev.netname + "\n");
					g_PlayerFuncs.SayText(target, "" + cheater.pev.netname + " " + cheat.name + " you\n");
				}
			}
		}
		else
		{
			if (ret == FAIL_TARGET_ADMIN)
				g_PlayerFuncs.SayText(cheater, "You can't use " + args[0] + " on yourself\n");
		}
	}
}

int toggleNoclip(CBasePlayer@ target, array<string>@ args)
{	
	int toggleState = (args.length() > 0) ? atoi(args[0]) : TOGGLE_TOGGLE;
	if (target.pev.movetype == MOVETYPE_NOCLIP and toggleState != TOGGLE_ON or toggleState == TOGGLE_OFF)
	{
		target.pev.movetype = MOVETYPE_WALK;
		
		for (uint i = 0; i < noclip_users.length(); i++)
		{
			if (noclip_users[i])
			{
				CBaseEntity@ ent = noclip_users[i];
				if (ent.entindex() == target.entindex())
				{
					noclip_users.removeAt(i);
					break;
				}
			}
		}
		g_PlayerFuncs.PrintKeyBindingString(target, "No clip OFF");
		return TOGGLE_OFF;
	}
	else
	{
		target.pev.movetype = MOVETYPE_NOCLIP;
		EHandle h_plr = target;
		noclip_users.insertLast(h_plr);
		g_PlayerFuncs.PrintKeyBindingString(target, "No clip ON");
		return TOGGLE_ON;
	}
}

int toggleGodmode(CBasePlayer@ target, array<string>@ args)
{	
	int toggleState = (args.length() > 0) ? atoi(args[0]) : TOGGLE_TOGGLE;
	if (target.pev.flags & FL_GODMODE != 0 and toggleState != TOGGLE_ON or toggleState == TOGGLE_OFF)
	{
		target.pev.flags &= ~FL_GODMODE;
		g_PlayerFuncs.PrintKeyBindingString(target, "God mode OFF");
		return TOGGLE_OFF;
	}
	else
	{
		target.pev.flags |= FL_GODMODE;
		g_PlayerFuncs.PrintKeyBindingString(target, "God mode ON");
		return TOGGLE_ON;
	}
}

int toggleNotarget(CBasePlayer@ target, array<string>@ args)
{
	int toggleState = (args.length() > 0) ? atoi(args[0]) : TOGGLE_TOGGLE;
	if (target.pev.flags & FL_NOTARGET != 0 and toggleState != TOGGLE_ON or toggleState == TOGGLE_OFF)
	{
		target.pev.flags &= ~FL_NOTARGET;
		g_PlayerFuncs.PrintKeyBindingString(target, "No target OFF");
		return TOGGLE_OFF;
	}
	else
	{
		target.pev.flags |= FL_NOTARGET;
		g_PlayerFuncs.PrintKeyBindingString(target, "No target ON");
		return TOGGLE_ON;
	}
}

int toggleCloak(CBasePlayer@ target, array<string>@ args)
{
	int toggleState = (args.length() > 0) ? atoi(args[0]) : TOGGLE_TOGGLE;
	bool currentlyEnabled = target.pev.flags & FL_NOTARGET != 0 and target.pev.rendermode == kRenderTransTexture and target.pev.renderamt == 0;
	
	if (currentlyEnabled and toggleState != TOGGLE_ON or toggleState == TOGGLE_OFF)
	{
		target.pev.flags &= ~FL_NOTARGET;
		target.pev.rendermode = kRenderNormal;
		g_PlayerFuncs.PrintKeyBindingString(target, "Cloak OFF");
		return TOGGLE_OFF;
	}
	else
	{
		target.pev.flags |= FL_NOTARGET;
		target.pev.rendermode = kRenderTransTexture;
		target.pev.renderamt = 0;
		g_PlayerFuncs.PrintKeyBindingString(target, "Cloak ON");
		return TOGGLE_ON;
	}
}

int toggleNotouch(CBasePlayer@ target, array<string>@ args)
{
	int toggleState = (args.length() > 0) ? atoi(args[0]) : TOGGLE_TOGGLE;
	if (target.pev.solid == SOLID_NOT and toggleState != TOGGLE_ON or toggleState == TOGGLE_OFF)
	{
		target.pev.solid = SOLID_SLIDEBOX;
		g_PlayerFuncs.PrintKeyBindingString(target, "Non-solid OFF");
		return TOGGLE_OFF;
	}
	else
	{
		target.pev.solid = SOLID_NOT;
		g_PlayerFuncs.PrintKeyBindingString(target, "Non-solid ON");
		return TOGGLE_ON;
	}
}

int toggleCheats(CBasePlayer@ target, array<string>@ args)
{
	int toggleState = (args.length() > 0) ? atoi(args[0]) : TOGGLE_TOGGLE;
	
	if (g_PlayerFuncs.AdminLevel(target) >= ADMIN_YES) {
		return FAIL_TARGET_ADMIN; // admins can't control whether other admins can use cheats or not.
	}
	
	string id = getPlayerUniqueId(target);
	if (!player_states.exists(id))
		player_states[id] = 0;
	
	if (int(player_states[id]) > 0 and toggleState != TOGGLE_ON or toggleState == TOGGLE_OFF)
	{
		player_states[id] = 0;
		return TOGGLE_OFF;
	}
	else
	{
		player_states[id] = 1;
		return TOGGLE_ON;
	}
}

// give ammo to player X times only if the ammo cap isn't reached
void giveAmmoCapped(CBasePlayer@ plr, int ammoIdx, string item, int count)
{
	for (int i = 0; i < count; i++) {
		if (plr.m_rgAmmo(ammoIdx) < plr.GetMaxAmmo(ammoIdx)) {
			array<string> args = {item};
			giveItem(plr, args);
		}
	}
}

int useImpulse(CBasePlayer@ target, array<string>@ args)
{
	int impulse = atoi(args[0]);
	if (impulse == 50) // toggle suit
	{
		target.SetHasSuit(!target.HasSuit());
	}
	else if (impulse == 101) // all weapons and ammo
	{
		target.SetItemPickupTimes(0);
		for (uint i = 0; i < impulse_101_weapons.length(); i++) {
			string checkName = impulse_101_weapons[i];
			if (checkName == "weapon_uziakimbo")
				checkName = "weapon_uzi";
			if (target.HasNamedPlayerItem(checkName) is null) {
				array<string> gargs = {impulse_101_weapons[i]};
				giveItem(target, gargs);
			}
		}
		
		for (uint i = 0; i < impulse_101_items.length(); i++) {
			array<string> gargs = {impulse_101_items[i]};
			giveItem(target, gargs);
		}
		
		// Replicate impulse 101 exactly (even though it's ineffecient)
		giveAmmoCapped(target, AMMO_SHOTGUN, "ammo_buckshot", 1);
		giveAmmoCapped(target, AMMO_556, "ammo_556", 1);
		giveAmmoCapped(target, AMMO_762, "ammo_762", 1);
		giveAmmoCapped(target, AMMO_ARGRENADES, "ammo_ARgrenades", 1);
		giveAmmoCapped(target, AMMO_357, "ammo_357", 1);
		giveAmmoCapped(target, AMMO_9MM, "ammo_9mmAR", 1);
		giveAmmoCapped(target, AMMO_9MM, "ammo_9mmclip", 1);
		giveAmmoCapped(target, AMMO_SPORE, "ammo_sporeclip", 5);
		giveAmmoCapped(target, AMMO_GAUSS, "ammo_gaussclip", 1);
		giveAmmoCapped(target, AMMO_RPG, "ammo_rpgclip", 1);
		giveAmmoCapped(target, AMMO_CROSSBOW, "ammo_crossbow", 1);
		
		// give battery if not fully charged
		if (target.pev.armorvalue < target.pev.armortype) {
			array<string> gargs = {"item_battery"};
			giveItem(target, gargs);
		}
	}
	return 0;
}

int giveItem(CBasePlayer@ target, array<string>@ args)
{
	bool validItem = false;
	if (args[0].Find("weapon_") == 0) validItem = true;
	if (args[0].Find("ammo_") == 0) validItem = true;
	if (args[0].Find("item_") == 0) validItem = true;
		
	if (validItem)
		target.GiveNamedItem(args[0], 0, 0);
	return 0;
}

int givePoints(CBasePlayer@ target, array<string>@ args)
{
	target.pev.frags += atoi(args[0]);
	return 0;
}

int setMaxHealth(CBasePlayer@ target, array<string>@ args)
{
	target.pev.max_health = atoi(args[0]);
	return 0;
}

int setMaxCharge(CBasePlayer@ target, array<string>@ args)
{
	target.pev.armortype = atoi(args[0]);
	return 0;
}

int setMaxSpeed(CBasePlayer@ target, array<string>@ args)
{
	float speed = atof(args[0]);
	if (speed == 0)
		speed = 0.000000001; // 0 just resets to default
		
	target.pev.maxspeed = speed;
	return 0;
}

int heal(CBasePlayer@ target, array<string>@ args)
{
	if (target.pev.deadflag != 0) {
		g_PlayerFuncs.PrintKeyBindingString(target, "Heal N/A: You're dead");
		return FAIL_TARGET_DEAD;
	} else {
		target.pev.health = target.pev.max_health;
		return 0;
	}
}

int charge(CBasePlayer@ target, array<string>@ args)
{
	if (target.pev.deadflag != 0) {
		g_PlayerFuncs.PrintKeyBindingString(target, "HEV charge N/A: You're dead");
		return FAIL_TARGET_DEAD;
	} else {
		target.pev.armorvalue = target.pev.armortype;
		return 0;
	}
}

int revive(CBasePlayer@ target, array<string>@ args)
{
	if (target.pev.deadflag == 0) {
		g_PlayerFuncs.PrintKeyBindingString(target, "Self revive N/A: Already alive");
		return FAIL_TARGET_ALIVE;
	} else {
		target.EndRevive(0);
		return 0;
	}
}

int strip(CBasePlayer@ target, array<string>@ args)
{
	target.RemoveAllItems(false);
	target.SetItemPickupTimes(0);
	return 0;
}

int giveAll(CBasePlayer@ target, array<string>@ args)
{
	// remember current weapon
	string activeItem;
	if (target.m_pActiveItem !is null)
		activeItem = target.m_pActiveItem.pev.classname;

	target.SetItemPickupTimes(0); // maybe not needed?
	
	// no delays needed for weapons. Does not cause a crash like with ammo entities
	for (uint i = 0; i < giveAllList.length(); i++) {
		array<string> gargs = {giveAllList[i]};
		giveItem(target, gargs);
	}
	
	// "infinite" ammo for all weapons
	for (int i = 0; i < 13; i++)
		target.m_rgAmmo(i, 1000000);
		
	if (activeItem.Length() > 0)
		target.SelectItem(activeItem);
	return 0;
}

// entering a trigger_gravity or friction disables noclip for some reason
// so I guess we just have to keep setting the noclip flag every single frame
void noclipFix()
{
	for (uint i = 0; i < noclip_users.length(); i++)
	{
		if (noclip_users[i])
		{
			CBaseEntity@ ent = noclip_users[i];
			if (ent.IsAlive())
			{
				ent.pev.movetype = MOVETYPE_NOCLIP;
				continue;
			}
		}
		noclip_users.removeAt(i);
		i--;
	}
}

bool doCheat(CBasePlayer@ plr, const CCommand@ args)
{
	if (cheats.exists(args[0])) 
	{
		Cheat@ cheat = cast<Cheat@>( cheats[args[0]] );
		applyCheat(cheat, plr, args);
		return true;
	} 
	else if (args[0] == '.cheatlist')
	{
		printlnPlr(plr, "--------------------- Available cheat commands --------------------");
		if (isAdmin(plr)) {
			printlnPlr(plr, ".cheats [0,1] [player] - Enable/disable cheats for everyone or a specfic player");
		}
		printlnPlr(plr, ".noclip - Fly through walls"); 
		printlnPlr(plr, ".god - Become invincible"); 
		printlnPlr(plr, ".notarget - Monsters ignore you"); 
		printlnPlr(plr, ".notouch - Entities pass through you and map triggers ignore you"); 
		printlnPlr(plr, ".impulse 101 - Gives all weapons, some ammo, and a battery"); 
		printlnPlr(plr, ".give - Gives a weapon, ammo, or item entity"); 
		printlnPlr(plr, ".givepoints - Add points to score"); 
		printlnPlr(plr, ".giveall - Give all weapons and INFINITE AMMO (even better than impulse 101)"); 
		printlnPlr(plr, ".heal - Fully restores health"); 
		printlnPlr(plr, ".charge - Fully charges HEV suit"); 
		printlnPlr(plr, ".revive - Come back to life"); 
		printlnPlr(plr, ".strip - Remove all weapons and ammo");
		printlnPlr(plr, ".cloak - Same as notarget but also makes your player model invisible");
		printlnPlr(plr, ".speed - Change movement speed (range is 0 to sv_maxspeed)");
		printlnPlr(plr, "\n---------------------------- Command Syntax ---------------------"); 
		printlnPlr(plr, "Format for cheats:"); 
		
		if (isAdmin(plr)) {
			printlnPlr(plr, "\n.god [0,1] [player]\n");
			printlnPlr(plr, "The 0/1 argument is optional, and only applies to some cheats (god, noclip, notarget, notouch)");
			printlnPlr(plr, "\nWhen specifying a player (optional), you can use part of their username, or their Steam ID.");
			printlnPlr(plr, 'To apply a cheat to all players in a server, use \\all (ex: ".god 1 \\all")');
		} else {
			printlnPlr(plr, "\n.god [0,1]\n");
			printlnPlr(plr, "The 0/1 argument is optional, and only applies to some cheats (god, noclip, notarget, notouch)");
			printlnPlr(plr, 'Example: to turn on godmode, type ".god 1"');
		}
		printlnPlr(plr, '\nAll commands can be used in chat as well as the console.');
		printlnPlr(plr, "\n------------------------------------------------------------------"); 
		
		return true;
	}
	return false;
}

HookReturnCode ClientSayCheat( SayParameters@ pParams )
{
	CBasePlayer@ plr = pParams.GetPlayer();
	const CCommand@ args = pParams.GetArguments();
	if (plr is null)
		return HOOK_CONTINUE;
	
	if ( args.ArgC() > 0 )
	{
		if (doCheat(plr, args)) 
		{
			pParams.ShouldHide = true;
			return HOOK_HANDLED;
		}
	}
	return HOOK_CONTINUE;
}

void cheatCmd( const CCommand@ args )
{
	CBasePlayer@ plr = g_ConCommandSystem.GetCurrentPlayer();
	doCheat(plr, args);
}
