#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <customguns>
#include <fof_props>
#include <weapon_functions>

#define CLASSNAME "weapon_ak47"

#define SPREAD 0.00873 // -> VECTOR_CONE_1DEGREES
#define MAX_SPREAD 20.0

#define CLIP_SIZE 30

#define GUN_DAMAGE 40.0
#define HEADSHOT 2.0
#define CHESTSHOT 1.1
#define BODYSHOT 1.0
#define ARMSHOT 0.9
#define LEGSHOT 0.8

#define RAMPUP 1.2
#define FALLOFF 0.2
#define MINRANGE 40.0
#define MIDRANGE 400.0
#define MAXRANGE 1024.0

#define COOLDOWN_TICK 0.025
#define COOLDOWN_DRAW 1.7
#define COOLDOWN_ATTACK 0.2
#define COOLDOWN_RELOAD_START 2.5 // First part of reload, up until bullets inserted
#define COOLDOWN_RELOAD_END 1.2 // Gotta cycle the whatever it's called. Receiver? I don't know guns.

float timeToNextAction[MAXPLAYERS+1];
WeaponState weaponState[MAXPLAYERS+1];
int trueBullets[MAXPLAYERS+1];
bool loopToggle[MAXPLAYERS+1]; // Toggles between firing animations so the sequence can play back to back

enum WeaponState{
	WEAPON_HOLSTERED,
	WEAPON_DRAWING,
	WEAPON_IDLE,
	WEAPON_CLICK_ATTACK,
	WEAPON_ATTACKING,
	WEAPON_CLICK_RELOAD,
	WEAPON_RELOAD_STARTING,
	WEAPON_RELOAD_ENDING,
};

enum SpecialCommand {
	FIRE_REGULAR,
	RELOAD_START,
	RELOAD_INSERT,
}

public OnMapStart() {
	g_sprite = PrecacheModel("materials/effects/gunshiptracer.vmt");
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

/**
 * This is the state machine where most of the weapon's logic goes.
 * THIS IS THE ONLY PLACE WHERE TIME TO NEXT ACTION SHOULD BE CHANGED WHEN DOING STUFF
 * 
 * Some animations may be played here, but if possible they should be
 * left to the base fof weapon or put in their own functions like Attack
 */
public OnPreThink(client) {
	if (!IsFakeClient(client) && IsPlayerAlive(client)) {
		char sWeapon[32];
		GetClientWeapon(client, sWeapon, sizeof(sWeapon));
		if(StrEqual(sWeapon, CLASSNAME)) {
			// Prevent client-side prediction
			int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			float delayAttack = GetGameTime() + 999.0;
			SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", delayAttack);
			SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", delayAttack);
			timeToNextAction[client] -= COOLDOWN_TICK;
			if (timeToNextAction[client] < 0) {
				switch (weaponState[client]) {
					case (WEAPON_HOLSTERED): {
						// Best to let the weapon animate its own draw, unless it's REALLY broken
						EmitGameSoundToAll("Weapon_AK47.Draw", weapon);
						timeToNextAction[client] = COOLDOWN_DRAW;
						weaponState[client] = WEAPON_DRAWING;
					}
					case (WEAPON_DRAWING): {
						weaponState[client] = WEAPON_IDLE;
					} case (WEAPON_IDLE): {
						// do nothing
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
						if (trueBullets[client] < CLIP_SIZE) {
							Reload(client, weapon, RELOAD_START);
							timeToNextAction[client] = COOLDOWN_RELOAD_START;
							weaponState[client] = WEAPON_RELOAD_STARTING;
						} else {
							weaponState[client] = WEAPON_IDLE;
						}
					}
					case (WEAPON_RELOAD_STARTING): {
						Reload(client, weapon, RELOAD_INSERT);
						timeToNextAction[client] = COOLDOWN_RELOAD_END;
						weaponState[client] = WEAPON_RELOAD_ENDING;
					}
					case (WEAPON_RELOAD_ENDING): {
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

void Attack(int client, SpecialCommand fire) {
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	int bullets = GetEntProp(weapon, Prop_Send, "m_iClip1");
	switch (fire) {
		case (FIRE_REGULAR): {
			if (bullets > 0) {
				SetEntProp(weapon, Prop_Send, "m_iClip1", bullets-1);
				CG_SetPlayerAnimation(client, PLAYER_ATTACK1);
				if (loopToggle[client]) {
					vmSeq(client, 1, 2.0);
					loopToggle[client] = false;
				} else {
					vmSeq(client, 2, 2.0);
					loopToggle[client] = true;
				}
				Fire(client, weapon);
				weaponState[client] = WEAPON_CLICK_ATTACK;
			}
		}
	}
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
			CG_PlayActivity(weapon, ACT_VM_RELOAD); // LMAO this segfaults if you get it wrong
			EmitGameSoundToAll("Weapon_AK47.ReloadStart", weapon);
		}
		case (RELOAD_INSERT): {
			trueBullets[client] = CLIP_SIZE;
			SetEntProp(weapon, Prop_Send, "m_iClip1", trueBullets[client]);
			EmitGameSoundToAll("Weapon_AK47.ReloadEnd", weapon);
		}
		default: {
			PrintToServer("BIG PROBLEM: Unknown reload command in %s", CLASSNAME);
		}
	}
}

//////////////////////////////////////
// BULLETS, PROJECTILES, EXPLOSIONS //
//////////////////////////////////////

void Fire(int client, int weapon) {
	EmitGameSoundToAll("Weapon_AK47.Single", weapon);

	float angles[3], startPos[3], endPos[3], vecDir[3], traceNormal[3], vecFwd[3], vecUp[3], vecRight[3];
	CG_GetShootPosition(client, startPos);
	GetClientEyeAngles(client, angles);
	GetAngleVectors(angles, vecFwd, vecRight, vecUp);

	GetVectorAngles(vecFwd, angles);

	// Add impact from inaccuracy to the spread
	// This is based off the remington's accuracy crouching
	float inaccuracy = FP_Inaccuracy(client) - 0.04;
	float spread = inaccuracy * SPREAD * MAX_SPREAD * 100; // I don't know why, but the spread needs to be multiplied to do anything
	float vecInaccuracy[3];
	vecInaccuracy[0] = GetRandomFloat( -spread, spread );
	vecInaccuracy[1] = GetRandomFloat( -spread,  spread );
	vecInaccuracy[2] = 0.0;
	
	// Add impact from view punch to the spread
	float m_vecPunchAngle[3];
	GetEntPropVector(client, Prop_Send, "m_vecPunchAngle", m_vecPunchAngle);

	angles[0] = angles[0] + m_vecPunchAngle[0] + vecInaccuracy[0];
	angles[1] = angles[1] + m_vecPunchAngle[1] + vecInaccuracy[1];
	angles[2] = angles[2] + m_vecPunchAngle[2] + vecInaccuracy[2];
	
	TR_TraceRayFilter(startPos, angles, MASK_SHOT, RayType_Infinite, TraceEntityFilter, client);
	TR_GetEndPosition(endPos);
	TR_GetPlaneNormal(null, traceNormal);
	int entityHit = TR_GetEntityIndex();
	
	if(entityHit <= 0) { // hit world or missed
		if (entityHit == 0) { // draw decal if hit world
			UTIL_ImpactTrace(startPos, DMG_BULLET);
		}
	}
	else {
		if(IsPlayer(entityHit)){
			float dmgForce[3];
			NormalizeVector(vecDir, dmgForce);
			ScaleVector(dmgForce, 10.0);
			int hitGroup = TR_GetHitGroup();
			float distance = GetVectorDistance(startPos, endPos);
			float falloff = DamageFalloff(distance, RAMPUP, FALLOFF, MINRANGE, MIDRANGE, MAXRANGE);
			float group = DamageGroup(hitGroup, HEADSHOT, CHESTSHOT, BODYSHOT, ARMSHOT, LEGSHOT);
			float damageDealt = GUN_DAMAGE * falloff * group;
			SDKHooks_TakeDamage(entityHit, client, client, damageDealt, DMG_BULLET, weapon, dmgForce, endPos);
		}
		UTIL_ImpactTrace(startPos, DMG_BULLET);
	}

	float viewPunch[3];
	viewPunch[0] = GetRandomFloat( -0.5, -0.2 );
	viewPunch[1] = GetRandomFloat( -0.5,  0.5 );
	Tools_ViewPunch(client, viewPunch);
	Tools_AddViewKick(client, 4.0, 1.0, 1.0, 2.0);
}

///////////////////////////////////
// HELPERS AND OTHER MISC THINGS //
///////////////////////////////////

void Reset(client) {
	loopToggle[client] = true;
	timeToNextAction[client] = 0.0;
	weaponState[client] = WEAPON_HOLSTERED;
}

public bool TraceEntityFilter(int entity, int mask, any data){
	if (entity == data)
		return false;
	return true;
}

public void CG_OnHolster(int client, int weapon, int switchingTo){
	char sWeapon[32];
	GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));
	if(StrEqual(sWeapon, CLASSNAME)){
		Reset(client);
	}
}