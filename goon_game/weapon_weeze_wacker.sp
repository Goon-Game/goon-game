#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <customguns>

#define CLASSNAME "weapon_weeze_wacker"

#define CLIP_SIZE 6 // This gun just fires all of them at once but need to be consistent

#define GUN_DAMAGE 44.0
#define SPREAD 0.00873 // -> VECTOR_CONE_1DEGREES

#define COOLDOWN_TICK 0.025
#define COOLDOWN_DRAW 1.0
#define COOLDOWN_ATTACK 1.5
#define COOLDOWN_RELOAD 5.0
#define COOLDOWN_DRYFIRE 1.0

float timeToNextAction[MAXPLAYERS+1];
WeaponState weaponState[MAXPLAYERS+1];
int trueBullets[MAXPLAYERS+1];

enum WeaponState{
	WEAPON_HOLSTERED,
	WEAPON_DRAWING,
	WEAPON_IDLE,
	WEAPON_CLICK_ATTACK,
	WEAPON_ATTACKING,
	WEAPON_CLICK_RELOAD,
	WEAPON_RELOADING,
};

enum SpecialCommand {
	FIRE_REGULAR,
	RELOAD_START,
	RELOAD_INSERT,
}

enum WeaponSounds {
	SOUND_FIRE,
}

char g_FireSounds[][] = {
	"weapons/carbine/smith_carbine_fire.wav"
}

public void OnMapStart() {
	for(int i=0; i < sizeof(g_FireSounds); i++)
	{
		PrecacheSound(g_FireSounds[i]);
	}
}

public OnClientPutInServer(int client) {
	if (!IsFakeClient(client)) {
		SDKHook(client, SDKHook_PreThink, OnPreThink);
		Reset(client);
	}
}

////////////////////////
// COMMANDS AND LOGIC //
////////////////////////

/**
 * To avoid side effects from the base weapon, eat the player's command inputs.
 * Only advance the weapon's state if it is presently WEAPON_IDLE.
 */
public Action OnPlayerRunCmd(client, &iButtons, &Impulse, Float:fVelocity[3], Float:fAngles[3], &iWeapon) {
	if (!IsFakeClient(client)) {
		char sWeapon[32];
		GetClientWeapon(client, sWeapon, sizeof(sWeapon));
		if(StrEqual(sWeapon, CLASSNAME)) {
			if (iButtons & IN_ATTACK) {
				iButtons &= ~IN_ATTACK;
				if (timeToNextAction[client] <= 0 && weaponState[client] == WEAPON_IDLE) {
					// The attack call is special because it needs to happen right away
					// The state will be advanced in there.
					Attack(client, FIRE_REGULAR);
				}
			}
			if (iButtons & IN_ATTACK2) {
				iButtons &= ~IN_ATTACK2; // no related state in this case, just let it pass
			}
			if (iButtons & IN_RELOAD) {
				iButtons &= ~IN_RELOAD;
				if (timeToNextAction[client] <= 0 && weaponState[client] == WEAPON_IDLE) {
					weaponState[client] = WEAPON_CLICK_RELOAD;
				}
			}
		}
	}
	return Plugin_Continue;
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
				switch (weaponState[client]) {
					case (WEAPON_HOLSTERED): {
						// Best to let the weapon animate its own draw, unless it's REALLY broken
						timeToNextAction[client] = COOLDOWN_DRAW;
						weaponState[client] = WEAPON_DRAWING;
					}
					case (WEAPON_DRAWING): {
						weaponState[client] = WEAPON_IDLE;
					}
					case (WEAPON_CLICK_ATTACK): {
						// Attack() already called in OnPlayerRunCmd
						timeToNextAction[client] = COOLDOWN_ATTACK;
						weaponState[client] = WEAPON_ATTACKING;
					}
					case (WEAPON_ATTACKING): {
						weaponState[client] = WEAPON_IDLE;
					}
					case (WEAPON_CLICK_RELOAD): {
						// Only *read* from the prop when you first click reload
						trueBullets[client] = GetEntProp(weapon, Prop_Send, "m_iClip1");
						PrintToServer("CLICK RELOAD WITH %d BULLETS", trueBullets[client]);
						if (trueBullets[client] < CLIP_SIZE) {
							Reload(client, weapon, RELOAD_START);
							timeToNextAction[client] = COOLDOWN_RELOAD;
							weaponState[client] = WEAPON_RELOADING;
						} else {
							weaponState[client] = WEAPON_IDLE;
						}
					}
					case (WEAPON_RELOADING): {
						Reload(client, weapon, RELOAD_INSERT);
						weaponState[client] = WEAPON_IDLE;
					}
					default: {
						// Something messed up, shouldn't be able to get here
						PrintToServer("BIG PROBLEM: Invalid state encountered in %s", CLASSNAME);
						weaponState[client] = WEAPON_IDLE;
					}
				}
			}
		} else {
			Reset(client);
		}
	}
}

void Attack(int client, SpecialCommand fire){
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	int bullets = GetEntProp(weapon, Prop_Send, "m_iClip1");
	if (bullets > 0) {
		SetEntProp(weapon, Prop_Send, "m_iClip1", 0);
		CG_SetPlayerAnimation(client, PLAYER_ATTACK1);
		CG_PlayActivity(weapon, ACT_VM_PRIMARYATTACK);
		PlaySound(weapon, 1);
		Fire(client, weapon);
		weaponState[client] = WEAPON_CLICK_ATTACK;
	}
}

//////////////////////////////////////
// BULLETS, PROJECTILES, EXPLOSIONS //
//////////////////////////////////////

void Fire(int client, int weapon) {
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
				float dmgForce[3];
				NormalizeVector(vecDir, dmgForce);
				ScaleVector(dmgForce, 10.0);
				SDKHooks_TakeDamage(entityHit, client, client, GUN_DAMAGE, DMG_BULLET, weapon, dmgForce, endPos);
			}
			UTIL_ImpactTrace(startPos, DMG_BULLET);
		}
	}
	
	float viewPunch[3];
	viewPunch[0] = GetRandomFloat( -0.5, -0.2 );
	viewPunch[1] = GetRandomFloat( -0.5,  0.5 );
	Tools_ViewPunch(client, viewPunch);
}

/**
 * This guy determines what actually happens when we say 'reload'
 */
void Reload(int client, int weapon, SpecialCommand reload) {
	// The sequence durations don't really matter, as far as
	// they are long enough to not end before the next action
	// I'm just tying them to the cooldown lengths so they roughly change in proportion
	switch (reload) {
		case (RELOAD_START): {
			CG_SetPlayerAnimation(client, PLAYER_RELOAD);
			CG_PlayActivity(weapon, ACT_VM_RELOAD);
		}
		case (RELOAD_INSERT): {
			trueBullets[client] = CLIP_SIZE;
			SetEntProp(weapon, Prop_Send, "m_iClip1", trueBullets[client]);
		}
		default: {
			PrintToServer("BIG PROBLEM: Unknown reload command in %s", CLASSNAME);
		}
	}
}

///////////////////////////////////
// HELPERS AND OTHER MISC THINGS //
///////////////////////////////////

public bool TraceEntityFilter(int entity, int mask, any data){
	if (entity == data)
		return false;
	return true;
}

void Reset(client) {
	timeToNextAction[client] = 0;
	weaponState[client] = WEAPON_HOLSTERED;
}

public void CG_OnHolster(int client, int weapon, int switchingTo){
	char sWeapon[32];
	GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));
	
	if(StrEqual(sWeapon, CLASSNAME)){
		Reset(client);
	}
}

void PlaySound(int entity, WeaponSounds soundType) {
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