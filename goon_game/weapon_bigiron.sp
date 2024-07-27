#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <customguns>

#define CLASSNAME "weapon_bigiron"

#define CLIP_SIZE 6
#define RELOAD_AMOUNT 1

#define GUN_DAMAGE 50.0
#define SPREAD 0.00873 // -> VECTOR_CONE_1DEGREES

#define COOLDOWN_TICK 0.025
#define COOLDOWN_DRAW 1.0
#define COOLDOWN_PRIMARY_FIRE 2.0
#define COOLDOWN_STARTING_RELOAD 2.0
#define COOLDOWN_RELOAD_LOOP 2.0
#define COOLDOWN_ENDING_RELOAD 2.0
#define COOLDOWN_DRYFIRE 2.0


float timeToNextAction[MAXPLAYERS+1];
WeaponState weaponState[MAXPLAYERS+1];
int bulletCount[MAXPLAYERS+1]; // Cheese to force the bullet count to remain consistent while reloading

enum WeaponState{
    WEAPON_IDLE,
    WEAPON_CLICK_RELOAD,
    WEAPON_STARTING_RELOAD,
    WEAPON_RELOADING,
    WEAPON_ENDING_RELOAD,
};

char g_FireSounds[][] = {
	"weapons/peacemaker/peacemaker_single1.wav",
    "weapons/peacemaker/peacemaker_single2.wav",
    "weapons/peacemaker/peacemaker_single3.wav",
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
		//SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
        SDKHook(client, SDKHook_PreThink, OnPostThinkPost);
		timeToNextAction[client] = COOLDOWN_DRAW;
		weaponState[client] = WEAPON_IDLE;
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

public void PrimaryAttack(int client, int weapon){
	if (bulletCount[client] == 0) {
        CG_PlayActivity(weapon, ACT_VM_DRYFIRE);
        timeToNextAction[client] = COOLDOWN_DRYFIRE;
	} else {
        bulletCount[client] -= 1;
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

	GetVectorAngles(vecFwd, angles);
	
	TR_TraceRayFilter(startPos, angles, MASK_SHOT, RayType_Infinite, TraceEntityFilter, client);
	TR_GetEndPosition(endPos);
	TR_GetPlaneNormal(null, traceNormal);
	int entityHit = TR_GetEntityIndex();
	
	if(entityHit <= 0) { // hit world or missed
		if (entityHit == 0) { // draw decal if hit world
			UTIL_ImpactTrace(startPos, DMG_BULLET);
			float hitAngle = -GetVectorDotProduct(traceNormal, vecDir);
		}
		// Heh heh you missed pal
		Missed(client, weapon);
	}
	else {
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

	float viewPunch[3];
	viewPunch[0] = GetRandomFloat( -0.5, -0.2 );
	viewPunch[1] = GetRandomFloat( -0.5,  0.5 );
	Tools_ViewPunch(client, viewPunch);
}

void Missed(int client, int weapon) {
	// could do something more interesting here, but for now client just drops the weapon when they miss
	// TODO: Also probably need to add another "missed" state so the gun actually fires before being yoinked
	CG_DropWeapon(client, weapon);
	weaponState[client] = WEAPON_IDLE;
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if (!IsFakeClient(client))
	{
		char sWeapon[32];
		GetClientWeapon(client, sWeapon, sizeof(sWeapon));
		if(StrEqual(sWeapon, CLASSNAME)) {
			if (timeToNextAction[client] <= 0) {
				weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
				if (buttons & IN_ATTACK) {
					PrintToServer("Attempting Fire of Weeze Wacker!");
					PrimaryAttack(client, weapon);
				}
				else if (buttons & IN_RELOAD) {
					PrintToServer("Attempting Reload of Weeze Wacker!");
                    int bullets = GetEntProp(weapon, Prop_Send, "m_iClip1");
                    if ((weaponState[client] == WEAPON_IDLE) && (bullets < CLIP_SIZE)) {
                        weaponState[client] = WEAPON_CLICK_RELOAD;
                    }
				}
			}
		}
	}
}

public OnPostThinkPost(client) {
	if (!IsFakeClient(client) && IsPlayerAlive(client)){
		char sWeapon[32];
		GetClientWeapon(client, sWeapon, sizeof(sWeapon));
		if(StrEqual(sWeapon, CLASSNAME)) {
			// Prevent client-side prediction
			float delayAttack = GetGameTime() + 999.0;
			int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", delayAttack);
			SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", delayAttack);
            SetEntProp(weapon, Prop_Send, "m_iClip1", bulletCount[client]);
			//float accuracy = GetEntPropFloat(weapon, Prop_Data, "m_flAccuracyPenalty");
			//PrintToServer("Weapon Accuracy: %f", accuracy);

            timeToNextAction[client] -= COOLDOWN_TICK;
            if (timeToNextAction[client] < 0 && weaponState[client] != WEAPON_IDLE) {
                PrintToServer("----------")
                PrintToServer("Time's Up!")
                if (weaponState[client] == WEAPON_CLICK_RELOAD) {
                    CG_PlayActivity(weapon, ACT_VM_RELOAD_START);
                    timeToNextAction[client] = COOLDOWN_STARTING_RELOAD;
                    weaponState[client] = WEAPON_STARTING_RELOAD;
                    PrintToServer("Click Reload to Starting Reload");
                } 
                else if(weaponState[client] == WEAPON_STARTING_RELOAD)
                {
                    CG_PlayActivity(weapon, ACT_VM_RELOAD);
                    timeToNextAction[client] = COOLDOWN_RELOAD_LOOP;
                    weaponState[client] = WEAPON_RELOADING;
                    PrintToServer("Starting Reload to Reloading");
                }
                else if (weaponState[client] == WEAPON_RELOADING)
                {
                    if (bulletCount[client] >= CLIP_SIZE) {
                        CG_PlayActivity(weapon, ACT_VM_RELOAD_FINISH);
                        timeToNextAction[client] = COOLDOWN_ENDING_RELOAD;
                        weaponState[client] = WEAPON_ENDING_RELOAD;
                        PrintToServer("Reloading to Ending Reload");
                    } else {
                        bulletCount[client] += RELOAD_AMOUNT;
                        CG_PlayActivity(weapon, ACT_VM_RELOAD);
                        timeToNextAction[client] = COOLDOWN_RELOAD_LOOP;
                        PrintToServer("Looping Reload");
                    }
                }
                else if (weaponState[client] == WEAPON_ENDING_RELOAD) {
                    weaponState[client] = WEAPON_IDLE;
                    PrintToServer("Ending Reload to Idle");
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