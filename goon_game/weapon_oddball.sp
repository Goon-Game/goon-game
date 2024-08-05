#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <customguns>

#define CLASSNAME "weapon_oddball"

ConVar oddball_hit_damage;
ConVar oddball_throw_damage;

#define COOLDOWN_PRIMARY .5
#define REFIRE 1
#define RANGE 80.0
#define PUSH_SCALE 250.0

float additionalTime[MAXPLAYERS+1];
float nextEnergy[MAXPLAYERS+1];

// This is based on https://github.com/CrimsonTautology/sm-super-kick/blob/master/addons/sourcemod/scripting/super_kick.sp

char g_HitSounds[][] =
{
    "ambient/explosions/explode_1.wav",
    "ambient/explosions/explode_2.wav",
    "ambient/explosions/explode_3.wav",
    "ambient/explosions/explode_4.wav",
    "ambient/explosions/explode_5.wav",
    "ambient/explosions/explode_6.wav",
    "ambient/explosions/explode_7.wav",
    "ambient/explosions/explode_8.wav",
    "ambient/explosions/explode_9.wav",
};

char g_YellSounds[][] =
{
    "player/fallscream1.wav",
    "player/fallscream2.wav",
};

void EmitHitSoundToAll(int entity)
{
    int pitch = GetRandomInt(85, 110);
    int index = GetRandomInt(0, sizeof(g_HitSounds) - 1);

    EmitSoundToAll(
            g_HitSounds[index], entity, SNDCHAN_AUTO, SNDLEVEL_TRAIN,
            SND_CHANGEPITCH, SNDVOL_NORMAL, pitch);
}

void EmitYellSoundToAll(int entity)
{
    int pitch = GetRandomInt(85, 110);
    int index = GetRandomInt(0, sizeof(g_YellSounds) - 1);

    EmitSoundToAll(
            g_YellSounds[index], entity, SNDCHAN_AUTO, SNDLEVEL_SCREAMING,
            SND_CHANGEPITCH, SNDVOL_NORMAL, pitch);
}

public void OnMapStart()
{
    for(int i=0; i < sizeof(g_HitSounds); i++)
    {
        PrecacheSound(g_HitSounds[i]);
    }

    for(int i=0; i < sizeof(g_YellSounds); i++)
    {
        PrecacheSound(g_YellSounds[i]);
    }
}

public void OnPluginStart(){
    oddball_hit_damage = CreateConVar("ob_hit_dmg", "200.0", "Sets the damage of an oddball melee hit.");
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
		PrintToServer("Oddball Primary Attack!");
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
		float pos[3], angles[3], endPos[3];
		CG_GetShootPosition(client, pos);
		GetClientEyeAngles(client, angles);
		
		GetAngleVectors(angles, endPos, NULL_VECTOR, NULL_VECTOR);
		ScaleVector(endPos, RANGE);
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
			if(IsPlayer(entityHit))
			{
				char classname[32];
				GetEntityClassname(entityHit, classname, sizeof(classname));
				if(GetEntityMoveType(entityHit) == MOVETYPE_VPHYSICS || StrContains(classname, "npc_") == 0)
				{
					float force[3];
					GetAngleVectors(angles, force, NULL_VECTOR, NULL_VECTOR);
					ScaleVector(force, PUSH_SCALE);
					TeleportEntity(entityHit, NULL_VECTOR, NULL_VECTOR, force);
					
					if(GetEntityMoveType(entityHit) == MOVETYPE_VPHYSICS)
					{
						SetEntPropVector(entityHit, Prop_Data, "m_vecAbsVelocity", NULL_VECTOR); //trampoline fix
					}
				}
				SDKHooks_TakeDamage(entityHit, client, client, oddball_hit_damage.FloatValue, DMG_CLUB);
				EmitHitSoundToAll(client);
                EmitYellSoundToAll(entityHit);
			}
			
			// Do additional trace for impact effects
			// if ( ImpactWater( pos, endPos ) ) return;
			float impactEndPos[3];
			GetAngleVectors(angles, impactEndPos, NULL_VECTOR, NULL_VECTOR);
			ScaleVector(impactEndPos, 50.0);
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
}

public void CG_OnSecondaryAttack(int client, int weapon){
	char sWeapon[32];
	GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));
	
	if(StrEqual(sWeapon, CLASSNAME)){
        //PrintToServer("Oddball secondary attack!!!");
        // Leaving the secondary attack function in here, but it doesn't do anything right now
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

public bool TraceEntityFilter(int entity, int mask, any data){
	if (entity == data)
		return false;
	return true;
}