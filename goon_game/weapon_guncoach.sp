#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <customguns>

#define CLASSNAME "weapon_guncoach"

#define COOLDOWN_PRIMARY .5
#define REFIRE 1.0

#define CLIP_SIZE 2

#define GUN_DAMAGE 8.0
#define SPREAD 0.00873 // -> VECTOR_CONE_1DEGREES
#define CONE 16.0 // Total degrees of spread
#define PATTERN_DIMENSION 6 // number of pellets making up shotgun pattern

float timeToNextAction[MAXPLAYERS+1];
bool reloading[MAXPLAYERS+1];

char g_FireSounds[][] = {
	"weapons/coachgun/coach_fire1.wav",
	"weapons/coachgun/coach_fire2.wav",
	"weapons/coachgun/sw_shotgun_fire.wav"
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
		SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
		timeToNextAction[client] = 1.0;
		reloading[client] = false;
	}
}

public void CG_OnHolster(int client, int weapon, int switchingTo){
	char sWeapon[32];
	GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));
	
	if(StrEqual(sWeapon, CLASSNAME)){
		timeToNextAction[client] = 0.1;
		reloading[client] = false;
	}
}

public void PrimaryAttack(int client, int weapon){
	int bullets = GetEntProp(weapon, Prop_Send, "m_iClip1");
	if (bullets == 0) {
		timeToNextAction[client] = 1.0;
	} else {
		SetEntProp(weapon, Prop_Send, "m_iClip1", bullets-1);
		CG_SetPlayerAnimation(client, PLAYER_ATTACK1);
		CG_PlayActivity(weapon, ACT_VM_PRIMARYATTACK);
		PlaySound(weapon, 1);
		PrimaryFire(client, weapon);
		timeToNextAction[client] = 2.0;
	}
}

void PrimaryFire(int client, int weapon) {
	float angles[3], startPos[3], endPos[3], vecDir[3], traceNormal[3], vecFwd[3], vecUp[3], vecRight[3];
	CG_GetShootPosition(client, startPos);
	GetClientEyeAngles(client, angles);
	GetAngleVectors(angles, vecFwd, vecRight, vecUp);
	
	// How many bullets in a shotgun spread?
	// Let's say 16 and see how that goes

	float starting_angle = -CONE / 2;
	float increment = CONE / PATTERN_DIMENSION;

	float volleyAngles[PATTERN_DIMENSION];

	for (int i = 0; i < PATTERN_DIMENSION; i++) {
		volleyAngles[i] = starting_angle + (i*increment);
	}
	

	for (int i = 0; i < PATTERN_DIMENSION; i++) {
		for (int j = 0; j < PATTERN_DIMENSION; j++) {
			float x = volleyAngles[i];
			float y = volleyAngles[j];
	
			vecDir[0] = vecFwd[0] + x * SPREAD * vecRight[0] + y * SPREAD * vecUp[0];
			vecDir[1] = vecFwd[1] + x * SPREAD * vecRight[1] + y * SPREAD * vecUp[1];
			vecDir[2] = vecFwd[2] + x * SPREAD * vecRight[2] + y * SPREAD * vecUp[2];
			
			GetVectorAngles(vecDir, angles);
			angles[0] += 180;
			
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
	}
	
	float viewPunch[3];
	viewPunch[0] = GetRandomFloat( 1.6, 2.0 );
	viewPunch[1] = GetRandomFloat( -0.5,  0.5 );
	Tools_ViewPunch(client, viewPunch);
}

public void Reload(int client, int weapon) {
	int bullets = GetEntProp(weapon, Prop_Send, "m_iClip1");
	if (bullets < CLIP_SIZE) {
		CG_PlayReload(weapon);
		float seqDuration = GetEntPropFloat(weapon, Prop_Send, "m_flTimeWeaponIdle") - GetGameTime();
		timeToNextAction[client] = seqDuration + 0.5;
		reloading[client] = true;
	}
}

public void CG_ItemPostFrame(int client, int weapon){
	char sWeapon[32];
	GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));
	
	if(StrEqual(sWeapon, CLASSNAME)){
		timeToNextAction[client] -= 0.025;
		if ((timeToNextAction[client] < 0) && reloading[client]) {
			reloading[client] = false;
			SetEntProp(weapon, Prop_Send, "m_iClip1", CLIP_SIZE);
		}
	}
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
					PrintToServer("Attempting Fire of Guncoach!");
					PrimaryAttack(client, weapon);
				}
				else if (buttons & IN_RELOAD) {
					PrintToServer("Attempting Reload of Guncoach!");
					Reload(client, weapon);
				}
			} else {
				PrintToServer("Cannot Execute CMD because %f > 0", timeToNextAction[client]);
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
			//float accuracy = GetEntPropFloat(weapon, Prop_Data, "m_flAccuracyPenalty");
			//PrintToServer("Weapon Accuracy: %f", accuracy);
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