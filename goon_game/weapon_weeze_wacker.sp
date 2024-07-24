#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <customguns>

#define CLASSNAME "weapon_weeze_wacker"

#define COOLDOWN_PRIMARY .5
#define REFIRE 1.0

float timeToNextAction[MAXPLAYERS+1];

public OnClientPutInServer(int client)
{
	if (!IsFakeClient(client))
	{
		SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
	}
}

public void CG_OnHolster(int client, int weapon, int switchingTo){
	char sWeapon[32];
	GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));
	
	if(StrEqual(sWeapon, CLASSNAME)){
		timeToNextAction[client] = 0.0;
	}
}

public void WWPrimaryAttack(int client, int weapon){
	int bullets = GetEntProp(weapon, Prop_Send, "m_iClip1");
	if (bullets == 0) {
		timeToNextAction[client] = 1.0;
	} else {
		PrintToServer("WW Fired with %d bullets!", bullets);
		SetEntProp(weapon, Prop_Send, "m_iClip1", bullets-1);
		CG_SetPlayerAnimation(client, PLAYER_ATTACK1);
		CG_PlayActivity(weapon, ACT_VM_PRIMARYATTACK);
		timeToNextAction[client] = 2.0;
	}
}

public void WWReload(int client, int weapon) {
	int bullets = GetEntProp(weapon, Prop_Send, "m_iClip1");
	if (bullets != 6) {
		CG_PlayReload(weapon);
		float seqDuration = GetEntPropFloat(weapon, Prop_Send, "m_flTimeWeaponIdle") - GetGameTime();
		timeToNextAction[client] = seqDuration;
		SetEntProp(weapon, Prop_Send, "m_iClip1", 6); // TODO: need to have a 'reloading' state so you can't just flip weapon away
	}
}

public void CG_ItemPostFrame(int client, int weapon){
	char sWeapon[32];
	GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));
	
	if(StrEqual(sWeapon, CLASSNAME)){
		timeToNextAction[client] -= 0.025;
	}
}

public void OnPlayerRunCmdPre(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2]) {

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
					WWPrimaryAttack(client, weapon);
				}
				else if (buttons & IN_RELOAD) {
					PrintToServer("Attempting Reload of Weeze Wacker!");
					WWReload(client, weapon);
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

// public bool TraceEntityFilter(int entity, int mask, any data){
// 	if (entity == data)
// 		return false;
// 	return true;
// }