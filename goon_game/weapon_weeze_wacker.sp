#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <customguns>

#define CLASSNAME "weapon_weeze_wacker"

#define COOLDOWN_PRIMARY .5
#define REFIRE 1

float additionalTime[MAXPLAYERS+1];
float nextEnergy[MAXPLAYERS+1];

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
		additionalTime[client] = 0.0;
		nextEnergy[client] = 0.0;
	}
}

public void CG_OnPrimaryAttack(int client, int weapon){
	char sWeapon[32];
	GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));
	
	if(StrEqual(sWeapon, CLASSNAME)){
        PrintToServer("Weeze Wacker Primary Attack!");
        CG_SetPlayerAnimation(client, PLAYER_ATTACK1);
		CG_PlayPrimaryAttack(weapon);

        if(additionalTime[client] <= 0.025)
		{
			additionalTime[client] = 0.025;
		}
		additionalTime[client] += additionalTime[client]*1.2;
		if(additionalTime[client] >= 0.5)
		{
			additionalTime[client] = 0.5;
		}
		
		CG_Cooldown(weapon, REFIRE + additionalTime[client]);
    }
}

public void CG_ItemPostFrame(int client, int weapon){
	char sWeapon[32];
	GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));
	
	if(StrEqual(sWeapon, CLASSNAME)){
		if(!(GetClientButtons(client) & IN_ATTACK) && GetGameTime() >= nextEnergy[client])
		{
			additionalTime[client] *= 0.5;
			nextEnergy[client] = GetGameTime() + 0.25;
		}
	}
}

public void OnPlayerRunCmdPre(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2]) {

}

bool toggle = true;

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if (!IsFakeClient(client))
	{
		char sWeapon[32];
		GetClientWeapon(client, sWeapon, sizeof(sWeapon));
		if(StrEqual(sWeapon, CLASSNAME)){
			weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			if (buttons & IN_RELOAD) {
				if (toggle) {
					PrintToServer("Attempting Reload of Weeze Wacker!");
					CG_PlayReload(weapon);
					toggle = false;
				} else {
					PrintToServer("Attempting Fire of Weeze Wacker!");
					CG_PlayPrimaryAttack(weapon);
					toggle = true;
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

// public bool TraceEntityFilter(int entity, int mask, any data){
// 	if (entity == data)
// 		return false;
// 	return true;
// }