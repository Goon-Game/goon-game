#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <customguns>

#define CLASSNAME "TEMPLATE"

#define DAMAGE_ATTACK 8.0
#define CLIP_SIZE 6
#define RELOAD_AMOUNT 1

#define COOLDOWN_TICK 0.025
#define COOLDOWN_DRAW 1.0
#define COOLDOWN_ATTACK 0.5
#define COOLDOWN_ATTACK2 1.0
#define COOLDOWN_RELOAD 3.0

float timeToNextAction[MAXPLAYERS+1];
WeaponState weaponState[MAXPLAYERS+1];

enum WeaponState {
	WEAPON_HOLSTERED,
	WEAPON_DRAWING,
	WEAPON_IDLE,
	WEAPON_CLICK_ATTACK,
	WEAPON_ATTACKING,
	WEAPON_CLICK_RELOAD,
	WEAPON_RELOADING,
};

// This can be whatever.
// In case you need some extra information to give to the Attack() or Reload() functions
enum SpecialCommand {
	FIRE_REGULAR,
	FIRE_DRY,
	RELOAD_START,
	RELOAD_LOADED,
}

enum WeaponSounds {
	SOUND_FIRE,
}

char g_FireSounds[][] = {
	"weapons/peacemaker/peacemaker_single1.wav",
	"weapons/peacemaker/peacemaker_single2.wav",
	"weapons/peacemaker/peacemaker_single3.wav",
}

public void OnMapStart() {
	for(int i=0; i < sizeof(g_FireSounds); i++) {
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
 * TODO: might need to do a little extra in here for weapons where you hold a button down
 * Commands should
 */
public Action OnPlayerRunCmd(client, &iButtons, &Impulse, Float:fVelocity[3], Float:fAngles[3], &iWeapon) {
	if (!IsFakeClient(client)) {
		char sWeapon[32];
		GetClientWeapon(client, sWeapon, sizeof(sWeapon));
		if(StrEqual(sWeapon, CLASSNAME)) {
			if (iButtons & IN_ATTACK) {
				iButtons &= ~IN_ATTACK;
				if (timeToNextAction[client] <= 0 && weaponState[client] == WEAPON_IDLE) {
					Attack(client, FIRE_REGULAR);
					weaponState[client] = WEAPON_CLICK_ATTACK;
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
			if (timeToNextAction[client] < 0 && weaponState[client] != WEAPON_IDLE) {
				int bullets = GetEntProp(weapon, Prop_Send, "m_iClip1");
				switch (weaponState[client]) {
					case (WEAPON_HOLSTERED): {
						timeToNextAction[client] = COOLDOWN_DRAW;
						weaponState[client] = WEAPON_DRAWING;
					}
					case (WEAPON_DRAWING): {
						weaponState[client] = WEAPON_IDLE;
					}
					case (WEAPON_CLICK_ATTACK): {
						timeToNextAction[client] = COOLDOWN_ATTACK;
						weaponState[client] = WEAPON_ATTACKING;
					}
					case (WEAPON_ATTACKING): {
						weaponState[client] = WEAPON_IDLE;
					}
					case (WEAPON_CLICK_RELOAD): {
						if (bullets < CLIP_SIZE) {
							Reload(client, weapon, bullets, RELOAD_START);
							timeToNextAction[client] = COOLDOWN_RELOAD;
							weaponState[client] = WEAPON_RELOADING;
						} else {
							weaponState[client] = WEAPON_IDLE;
						}
					}
					case (WEAPON_RELOADING): {
						Reload(client, weapon, bullets, RELOAD_LOADED);
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
			SetEntProp(weapon, Prop_Send, "m_iClip1", 0);
			CG_SetPlayerAnimation(client, PLAYER_ATTACK1);
			CG_PlayActivity(weapon, ACT_VM_PRIMARYATTACK);
			PlaySound(weapon, 1);
			Fire(client, weapon);
		}
		case (FIRE_DRY): {
			// Can get fancy in here if you want. Not actually using this, just an example
		}
	}
}

/**
 * This guy determines what actually happens when we say 'reload'
 * 
 * It could 
 */
void Reload(int client, int weapon, int bullets, SpecialCommand reload) {
	switch (reload) {
		case (RELOAD_START): {
			CG_SetPlayerAnimation(client, PLAYER_RELOAD);
			CG_PlayActivity(weapon, ACT_VM_RELOAD);
		}
		case (RELOAD_LOADED): {
			SetEntProp(weapon, Prop_Send, "m_iClip1", bullets + 1);
		}
	}
	
}

//////////////////////////////////////
// BULLETS, PROJECTILES, EXPLOSIONS //
//////////////////////////////////////

/**
 * Now for the fun part, actually fire the gun
 */
void Fire(int client, int weapon) {

}

///////////////////////////////////
// HELPERS AND OTHER MISC THINGS //
///////////////////////////////////

void Reset(client) {
	timeToNextAction[client] = 0.0;
	weaponState[client] = WEAPON_HOLSTERED;
}

public bool TraceEntityFilter(int entity, int mask, any data) {
	if (entity == data)
		return false;
	return true;
}

void PlaySound(int entity, WeaponSounds soundType) {
	int index;
	char sSoundFileName[128];
	int pitch = GetRandomInt(85, 110);
	switch (soundType) {
		case (SOUND_FIRE): {
			index = GetRandomInt(0, sizeof(g_FireSounds)-1);
			strcopy(sSoundFileName, sizeof(sSoundFileName), g_FireSounds[index]);
		}
		default: {
			return;
		}
	}
	
	EmitSoundToAll(
			sSoundFileName, entity, SNDCHAN_AUTO, SNDLEVEL_TRAIN,
			SND_CHANGEPITCH, SNDVOL_NORMAL, pitch);
}

public void CG_OnHolster(int client, int weapon, int switchingTo){
	char sWeapon[32];
	GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));
	if(StrEqual(sWeapon, CLASSNAME)){
		Reset(client);
	}
}