#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <customguns>

#define CLASSNAME "weapon_brownbess"

#define CLIP_SIZE 1

#define GUN_DAMAGE 40.0
#define BASE_INACCURACY 3.0
#define SPREAD 0.00873 // -> VECTOR_CONE_1DEGREES

#define STAB_DAMAGE 40.0
#define STAB_RANGE 120.0

#define COOLDOWN_TICK 0.025
#define COOLDOWN_DRAW 2.5
#define COOLDOWN_PRIMARY_FIRE 1.5
#define COOLDOWN_SECONDARY_FIRE 2.0
#define COOLDOWN_RELOAD 10.0
#define COOLDOWN_DRYFIRE 2.0

float timeToNextAction[MAXPLAYERS+1];
WeaponState weaponState[MAXPLAYERS+1];
// We're erasing the buttons pressed by the player for reload and secondary attack to prevent them from happening
// But we still need to use them later, so instead we'll be using these
bool commandReload[MAXPLAYERS+1];
bool commandAttack2[MAXPLAYERS+1];

enum WeaponState{
	WEAPON_HOLSTERED,
	WEAPON_DRAWING,
    WEAPON_IDLE,
    WEAPON_CLICK_RELOAD,
    WEAPON_RELOADING,
	WEAPON_CLICK_FIRE,
	WEAPON_FIRING,
	WEAPON_CLICK_STAB,
	WEAPON_STABBING,
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
        SDKHook(client, SDKHook_PreThink, OnPreThink);
		timeToNextAction[client] = 0;
		weaponState[client] = WEAPON_HOLSTERED;
		commandAttack2[client] = false;
		commandReload[client] = false;
	}
}

public void CG_OnHolster(int client, int weapon, int switchingTo){
	char sWeapon[32];
	GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));
	
	if(StrEqual(sWeapon, CLASSNAME)){
		timeToNextAction[client] = 0;
		weaponState[client] = WEAPON_HOLSTERED;
	}
}

void PrimaryAttack(int client, int weapon){
	int bullets = GetEntProp(weapon, Prop_Send, "m_iClip1");
	if (bullets == 0) {
		// chamber empty, just send them to reload
        weaponState[client] = WEAPON_CLICK_RELOAD;
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

	GetVectorAngles(vecFwd, angles);
	
	TR_TraceRayFilter(startPos, angles, MASK_SHOT, RayType_Infinite, TraceEntityFilter, client);
	TR_GetEndPosition(endPos);
	TR_GetPlaneNormal(null, traceNormal);
	int entityHit = TR_GetEntityIndex();
	
	if(entityHit == 0) { // hit world
		UTIL_ImpactTrace(startPos, DMG_BULLET);
	}
	else if (entityHit != -1) {
		if(IsPlayer(entityHit)){
			float dmgForce[3];
			NormalizeVector(vecDir, dmgForce);
			ScaleVector(dmgForce, 10.0);
			SDKHooks_TakeDamage(entityHit, client, client, GUN_DAMAGE, DMG_BULLET, weapon, dmgForce, endPos, false);
		}
		UTIL_ImpactTrace(startPos, DMG_BULLET);
	}

	float viewPunch[3];
	viewPunch[0] = GetRandomFloat( -0.5, -0.2 );
	viewPunch[1] = GetRandomFloat( -0.5,  0.5 );
	Tools_ViewPunch(client, viewPunch);
}

void SecondaryAttack(int client, int weapon) {
	CG_SetPlayerAnimation(client, PLAYER_ATTACK1); // TODO: player animations for stab?
	CG_PlayActivity(weapon, ACT_VM_SECONDARYATTACK);
	//PlaySound(weapon, 1);
	SecondaryFire(client, weapon);
	timeToNextAction[client] = COOLDOWN_SECONDARY_FIRE;
}

void SecondaryFire(int client, int weapon) {
	float pos[3], angles[3], endPos[3];
	CG_GetShootPosition(client, pos);
	GetClientEyeAngles(client, angles);
	
	GetAngleVectors(angles, endPos, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(endPos, STAB_RANGE);
	AddVectors(pos, endPos, endPos);
	
	TR_TraceHullFilter(pos, endPos, view_as<float>({-10.0, -10.0, -10.0}), view_as<float>({10.0, 10.0, 10.0}), MASK_SHOT_HULL, TraceEntityFilter, client);
	
	float punchAngle[3];
	punchAngle[0] = GetRandomFloat( 1.0, 2.0 );
	punchAngle[1] = GetRandomFloat( -2.0, -1.0 );
	Tools_ViewPunch(client, punchAngle);
	
	if(TR_DidHit())
	{
		EmitGameSoundToAll("Weapon_Crowbar.Melee_Hit", weapon);
		
		int entityHit = TR_GetEntityIndex();
		if(entityHit > 0 && (!IsPlayer(entityHit) || GetClientTeam(entityHit) != GetClientTeam(client)) )
		{
			char classname[32];
			GetEntityClassname(entityHit, classname, sizeof(classname));
			SDKHooks_TakeDamage(entityHit, client, client, STAB_DAMAGE, DMG_CLUB, -1, NULL_VECTOR, NULL_VECTOR, false);
		}
		
		// Do additional trace for impact effects
		float impactEndPos[3];
		GetAngleVectors(angles, impactEndPos, NULL_VECTOR, NULL_VECTOR);
		ScaleVector(impactEndPos, STAB_RANGE);
		TR_GetEndPosition(endPos);
		AddVectors(impactEndPos, endPos, impactEndPos);

		TR_TraceRayFilter(endPos, impactEndPos, MASK_SHOT_HULL, RayType_EndPoint, TraceEntityFilter, client);
		if(TR_DidHit())
		{
			UTIL_ImpactTrace(pos, DMG_CLUB);
		}
	}
	else
	{
		EmitGameSoundToAll("Weapon_Crowbar.Single", weapon);
	}
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
				if (timeToNextAction[client] <= 0 && weaponState[client] == WEAPON_IDLE) {
					commandAttack2[client] = true;
				}
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
					PrintToServer("Attempting Primay Fire of Brownbess! Gametime: %f", GetGameTime());
					PrimaryAttack(client, weapon);
				}
				if (commandAttack2[client]) {
					PrintToServer("Attempting Secondary Fire of Brownbess! Gametime: %f", GetGameTime());
					SecondaryAttack(client, weapon);
					commandAttack2[client] = false;
				}
				if (commandReload[client]) {
					PrintToServer("Attempting Reload of Brownbess! %f", GetGameTime());
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
			weaponState[client] = WEAPON_HOLSTERED;
			timeToNextAction[client] = 0;
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
			int bullets = GetEntProp(weapon, Prop_Send, "m_iClip1");
			int vm = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
			SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", delayAttack);
			SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", delayAttack);
			//float accuracy = GetEntPropFloat(weapon, Prop_Data, "m_flAccuracyPenalty");
			//PrintToServer("Weapon Accuracy: %f", accuracy);
			timeToNextAction[client] -= COOLDOWN_TICK;
            if (timeToNextAction[client] < 0 && weaponState[client] != WEAPON_IDLE) {
                PrintToServer("----------")
                PrintToServer("Time's Up!")
				if (weaponState[client] == WEAPON_HOLSTERED) {
					if (bullets > 0) {
						//SetEntProp(vm, Prop_Send, "m_nSequence", ACT_VM_DRAW_EMPTY);
					} else {
						//SetEntProp(vm, Prop_Send, "m_nSequence", ACT_VM_DRAW);
					}
					timeToNextAction[client] = COOLDOWN_DRAW;
					weaponState[client] = WEAPON_DRAWING;
				} else if (weaponState[client] == WEAPON_DRAWING) {
					if (bullets > 0) {
						//SetEntProp(vm, Prop_Send, "m_nSequence", ACT_VM_IDLE);
					} else {
						//SetEntProp(vm, Prop_Send, "m_nSequence", ACT_VM_IDLE_1);
					}
					//FakeClientCommand(client, "+reload");
					//FakeClientCommand(client, "-reload");
					weaponState[client] = WEAPON_IDLE;
				}
				else if (weaponState[client] == WEAPON_CLICK_FIRE) {

				}
                else if (weaponState[client] == WEAPON_CLICK_RELOAD) {
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
			} else if (weaponState[client] == WEAPON_IDLE) {
				if (bullets > 0) {
					//SetEntProp(vm, Prop_Send, "m_nSequence", ACT_VM_IDLE);
					// SetEntProp(vm, Prop_Send, "m_nAnimationParity", (GetEntProp(vm, Prop_Send, "m_nAnimationParity")+1)  & ( (1<<EF_PARITY_BITS) - 1 ));
					//SetEntPropFloat(vm, Prop_Data, "m_flCycle", 0.0);
					//SetEntPropFloat(vm, Prop_Data, "m_flAnimTime", GetGameTime());
				} else {
					//SetEntProp(vm, Prop_Send, "m_nSequence", ACT_VM_IDLE_1);
				}
			}
			int m_nNewSequenceParity = GetEntProp(vm, Prop_Send, "m_nNewSequenceParity");
			int m_nResetEventsParity = GetEntProp(vm, Prop_Send, "m_nResetEventsParity");
			//float m_flCycle = GetEntPropFloat(vm, Prop_Send, "m_flCycle");
			float m_flPlaybackRate = GetEntPropFloat(vm, Prop_Send, "m_flPlaybackRate");
			//PrintToServer("New Sequence: %d \tReset Events: %d \tflCycle: %f \t Playback Rate %f", m_nNewSequenceParity, m_nResetEventsParity, m_flCycle, m_flPlaybackRate);
			//PrintToServer("New Sequence: %d \tReset Events: %d \t Playback Rate %f", m_nNewSequenceParity, m_nResetEventsParity, m_flPlaybackRate);
		}
	}
}

public void CG_OnPrimaryAttack(int client, int weapon){
	char sWeapon[32];
	GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));
	if(StrEqual(sWeapon, CLASSNAME)){
        PrintToServer("ERROR! Regular primary attack got through!");
    }
}

public void CG_OnSecondaryAttack(int client, int weapon) {
	char sWeapon[32];
	GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));
	if(StrEqual(sWeapon, CLASSNAME)){
        PrintToServer("ERROR! Regular %s secondary attack got through!", CLASSNAME);
    }
}

public bool TraceEntityFilter(int entity, int mask, any data){
	if (entity == data)
		return false;
	return true;
}