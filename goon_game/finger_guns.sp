#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <customguns>

Handle CALL_FireBullets;

public OnPluginStart() {
	Handle gamedata = LoadGameConfigFile("customguns");
	// void CHL2MP_Player::FireBullets ( const FireBulletsInfo_t &info )
	/* "FireBulletsInfo_t":
	0 int m_iShots;
	4 Vector m_vecSrc;
	16 Vector m_vecDirShooting;
	28 Vector m_vecSpread;
	40 float m_flDistance;
	44 int m_iAmmoType;
	48 int m_iTracerFreq;
	52 float m_flDamage;
	56 int m_iPlayerDamage;
	60 int m_nFlags;
	64 float m_flDamageForceScale;
	68 CBaseEntity *m_pAttacker;
	72 CBaseEntity *m_pAdditionalIgnoreEnt;
	76 bool m_bPrimaryAttack;
	*/
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "FireBullets");

    // Ok, so pointer and byRef both at least fire the bullets
	//PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByRef);
    CALL_FireBullets = EndPrepSDKCall();
}

void FireTrace(int client) {
	new Handle:hBulletInfo;
	hBulletInfo = new DataPack();
	// shots
	WritePackCell(hBulletInfo, 1);

	float shootPos[3];
	CG_GetShootPosition(client, shootPos);
	WritePackFloat(hBulletInfo, shootPos[0]);
	WritePackFloat(hBulletInfo, shootPos[1]);
	WritePackFloat(hBulletInfo, shootPos[2]);

	float shootAngle[3];
	GetClientEyeAngles(client, shootAngle);
	WritePackFloat(hBulletInfo, shootAngle[0]);
	WritePackFloat(hBulletInfo, shootAngle[1]);
	WritePackFloat(hBulletInfo, shootAngle[2]);

	// spread
	WritePackFloat(hBulletInfo, 0.0);
	WritePackFloat(hBulletInfo, 0.0);
	WritePackFloat(hBulletInfo, 0.0);

	// distance
	WritePackFloat(hBulletInfo, 0.1);

	// ammo type
	WritePackCell(hBulletInfo, 1);

	// Tracer freq
	WritePackCell(hBulletInfo, 1);

	// Damage
	WritePackFloat(hBulletInfo, 0.0);

	// Player damage?
	WritePackCell(hBulletInfo, 1);

	// Flags
	WritePackCell(hBulletInfo, 0);

	// Damage force scale
	WritePackFloat(hBulletInfo, 0.0);

	int client_ptr = EntIndexToEntRef(client);
	// Attacker
	WritePackCell(hBulletInfo, client_ptr);

	// Additional ignore ent?
	WritePackCell(hBulletInfo, 0);

	// Primary attack
	WritePackCell(hBulletInfo, false);
	
    // Apparently the 'client' thing is necessary
    // See SDKCall CALL_GiveAmmo
	SDKCall(CALL_FireBullets, client, hBulletInfo);
}

public OnClientPutInServer(int client) {
	SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
}

public Action OnTraceAttack(victim, &attacker, &inflictor, &Float:damage, &damagetype, &ammotype, hitbox, hitgroup) {
	PrintToServer("Traceattack, box: %d, group: %d", hitbox, hitgroup);
	return Plugin_Continue;
}

/**
 * To avoid side effects from the base weapon, eat the player's command inputs.
 * Only advance the weapon's state if it is presently WEAPON_IDLE.
 */
public Action OnPlayerRunCmd(client, &iButtons, &Impulse, Float:fVelocity[3], Float:fAngles[3], &iWeapon) {
	if (!IsFakeClient(client) && IsPlayerAlive(client)) {
        if (iButtons & IN_ATTACK) {
            iButtons &= ~IN_ATTACK;
            // The attack call is special because it needs to happen right away
            // The state will be advanced in there.
            FireTrace(client);
        }
	}
	return Plugin_Continue;
}