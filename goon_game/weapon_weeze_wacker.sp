#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <customguns>

#define CLASSNAME "weapon_weeze_wacker"

#define COOLDOWN_TICK 0.025
#define COOLDOWN_DRAW 1.0
#define COOLDOWN_PRIMARY_FIRE 2.0
#define COOLDOWN_RELOAD 8.0
#define COOLDOWN_DRYFIRE 1.0

#define CLIP_SIZE 1

#define GUN_DAMAGE 44.0
#define SPREAD 0.00873 // -> VECTOR_CONE_1DEGREES

float timeToNextAction[MAXPLAYERS+1];
WeaponState weaponState[MAXPLAYERS+1];
// We're erasing the buttons pressed by the player for reload and secondary attack to prevent them from happening
// But we still need to use them later, so instead we'll be using these
bool commandReload[MAXPLAYERS+1];
bool commandAttack2[MAXPLAYERS+1];

enum WeaponState{
    WEAPON_IDLE,
    WEAPON_CLICK_RELOAD,
    WEAPON_RELOADING,
};

char g_FireSounds[][] = {
	"weapons/carbine/smith_carbine_fire.wav"
}

bool teamplay;

public void OnMapStart()
{
    for(int i=0; i < sizeof(g_FireSounds); i++)
    {
        PrecacheSound(g_FireSounds[i]);
    }
	teamplay = GetConVarBool(FindConVar("mp_teamplay"));
}

void PlaySound(int entity, int soundType) {
	// Play a specified sound
	// sound types:
	// 0: draw
	// 1: primary fire
	// 2: secondary fire
	// 3: reload

	for (int i = 0; i < 4; i++) {
		int pitch = GetRandomInt(85, 110);
		
		int index;
		char sSoundFileName[128];

		if (soundType == 1) {
			index = GetRandomInt(0, sizeof(g_FireSounds)-1);
			strcopy(sSoundFileName, sizeof(sSoundFileName), g_FireSounds[index]);
		}

		EmitSoundToAll(
				sSoundFileName, entity, SNDCHAN_AUTO, SNDLEVEL_TRAIN,
				SND_CHANGEPITCH, SNDVOL_NORMAL, pitch);
	}
}

public OnClientPutInServer(int client)
{
	if (!IsFakeClient(client))
	{
        SDKHook(client, SDKHook_PreThink, OnPreThink);
		timeToNextAction[client] = COOLDOWN_DRAW;
		weaponState[client] = WEAPON_IDLE;
		commandAttack2[client] = false;
		commandReload[client] = false;
	}
}

public void CG_OnHolster(int client, int weapon, int switchingTo){
	char sWeapon[32];
	GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));
	
	if(StrEqual(sWeapon, CLASSNAME)){
		timeToNextAction[client] = COOLDOWN_DRAW;
		weaponState[client] = WEAPON_IDLE;
	}
}

void PrimaryAttack(int client, int weapon){
	int bullets = GetEntProp(weapon, Prop_Send, "m_iClip1");
	if (bullets == 0) {
        CG_PlayActivity(weapon, ACT_VM_DRYFIRE); //TODO: add dryfire
        timeToNextAction[client] = COOLDOWN_DRYFIRE;
	} else {
		SetEntProp(weapon, Prop_Send, "m_iClip1", 0);
		CG_SetPlayerAnimation(client, PLAYER_ATTACK1);
		CG_PlayActivity(weapon, ACT_VM_PRIMARYATTACK);
		PlaySound(weapon, 1);
		PrimaryFire(client, weapon);
		timeToNextAction[client] = COOLDOWN_PRIMARY_FIRE;
	}
}

void PrimaryFire(int client, int weapon) {
	float angles[3], startPos[3], endPos[3], vecDir[3], traceNormal[3], vecFwd[3], vecUp[3], vecRight[3];
	CG_GetShootPosition(client, startPos);
	GetClientEyeAngles(client, angles);
	GetAngleVectors(angles, vecFwd, vecRight, vecUp);
	
	// We have 4 pellets, I'm saying each is 12 degrees of separation
	float volleyAngles[] = {-18.0, -6.0, 6.0, 18.0}

	for (int i = 0; i < 4; i++) {
		float x = volleyAngles[i];
 
		vecDir[0] = vecFwd[0] + x * SPREAD * vecRight[0];
		vecDir[1] = vecFwd[1] + x * SPREAD * vecRight[1];
		vecDir[2] = vecFwd[2] + x * SPREAD * vecRight[2];
		
		GetVectorAngles(vecDir, angles);
		
		TR_TraceRayFilter(startPos, angles, MASK_SHOT, RayType_Infinite, TraceEntityFilter, client);
		TR_GetEndPosition(endPos);
		TR_GetPlaneNormal(null, traceNormal);
		int entityHit = TR_GetEntityIndex();
		
		if(entityHit == 0) { // hit world
			UTIL_ImpactTrace(startPos, DMG_BULLET);
			
			float hitAngle = -GetVectorDotProduct(traceNormal, vecDir);
		}
		else if (entityHit != -1)
		{
			if(IsPlayer(entityHit)){
				if(!teamplay || GetClientTeam(entityHit) != GetClientTeam(client)){
					float dmgForce[3];
					NormalizeVector(vecDir, dmgForce);
					ScaleVector(dmgForce, 10.0);
					SDKHooks_TakeDamage(entityHit, client, client, GUN_DAMAGE, DMG_BULLET, weapon, dmgForce, endPos);
				}
			}
			UTIL_ImpactTrace(startPos, DMG_BULLET);
		}
	}
	
	float viewPunch[3];
	viewPunch[0] = GetRandomFloat( -0.5, -0.2 );
	viewPunch[1] = GetRandomFloat( -0.5,  0.5 );
	Tools_ViewPunch(client, viewPunch);
}

public Action OnPlayerRunCmd(client, &iButtons, &Impulse, Float:fVelocity[3], Float:fAngles[3], &iWeapon)
{
	if (!IsFakeClient(client))
	{
		char sWeapon[32];
		GetClientWeapon(client, sWeapon, sizeof(sWeapon));
		if(StrEqual(sWeapon, CLASSNAME)) {
			if ((iButtons & IN_ATTACK2) == IN_ATTACK2)
			{
				iButtons &= ~IN_ATTACK2;
			}
			if ((iButtons & IN_RELOAD) == IN_RELOAD)
			{
				iButtons &= ~IN_RELOAD;
				if (timeToNextAction[client] <= 0 && weaponState[client] == WEAPON_IDLE) {
					PrintToServer("Initiating reload command, %f", GetGameTime());
					commandReload[client] = true;
				}
			}
		}
	}
	return Plugin_Continue;
} 

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int not_weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if (!IsFakeClient(client))
	{
		char sWeapon[32];
		GetClientWeapon(client, sWeapon, sizeof(sWeapon));
		if(StrEqual(sWeapon, CLASSNAME)) {
			if (timeToNextAction[client] <= 0) {
				int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
				if (buttons & IN_ATTACK) {
					PrintToServer("Attempting Primay Fire of Weeze Wacker!");
					PrimaryAttack(client, weapon);
				}
				if (commandReload[client]) {
					PrintToServer("Attempting Reload of Weeze Wacker! %f", GetGameTime());
					int bullets = GetEntProp(weapon, Prop_Send, "m_iClip1");
					if ((weaponState[client] == WEAPON_IDLE) && (bullets < CLIP_SIZE)) {
						weaponState[client] = WEAPON_CLICK_RELOAD;
						// AHA! this only starts happening on the next gametick, when the reload button is still pressed.
						// Need to be careful for this sort of thing...
					}
					commandReload[client] = false;
				}
			}
		} else {
			// Not holding this weapon, reset important stuff
			commandReload[client] = false;
			commandAttack2[client] = false;
			weaponState[client] = WEAPON_IDLE;
			timeToNextAction[client] = COOLDOWN_DRAW;
		}
	}
}

public OnPreThink(client) {
	if (!IsFakeClient(client) && IsPlayerAlive(client)){
		char sWeapon[32];
		GetClientWeapon(client, sWeapon, sizeof(sWeapon));
		if(StrEqual(sWeapon, CLASSNAME)) {
			// Prevent client-side prediction
			float delayAttack = GetGameTime() + 999.0;
			int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", delayAttack);
			SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", delayAttack);
			timeToNextAction[client] -= COOLDOWN_TICK;
            if (timeToNextAction[client] < 0 && weaponState[client] != WEAPON_IDLE) {
                PrintToServer("----------")
                PrintToServer("Time's Up!")
                if (weaponState[client] == WEAPON_CLICK_RELOAD) {
                    CG_PlayActivity(weapon, ACT_VM_RELOAD);
                    timeToNextAction[client] = COOLDOWN_RELOAD;
                    weaponState[client] = WEAPON_RELOADING;
                    PrintToServer("Click Reload to Reloading");
                }
                else if (weaponState[client] == WEAPON_RELOADING)
                {
					SetEntProp(weapon, Prop_Send, "m_iClip1", CLIP_SIZE);
					weaponState[client] = WEAPON_IDLE;
					PrintToServer("Reloading to Idle");
                }
                PrintToServer("----------")
            }
		}
	}
}

public void CG_OnPrimaryAttack(int client, int weapon){
	char sWeapon[32];
	GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));
	if(StrEqual(sWeapon, CLASSNAME)){
        PrintToServer("ERROR! Regular attack got through!");
    }
}

public bool TraceEntityFilter(int entity, int mask, any data){
	if (entity == data)
		return false;
	return true;
}