#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <customguns>

#pragma newdecls required

#define CLASSNAME "weapon_oddball"

ConVar oddball_hit_damage;
ConVar oddball_throw_damage;

#define COOLDOWN_PRIMARY 0.25
#define COOLDOWN_SECONDARY 0.5
#define RANGE 90.0
#define PUSH_SCALE 250.0

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
	oddball_hit_damage = CreateConVar("ob_hit_dmg", "200", "Sets the damage of an oddball melee hit.");
	oddball_throw_damage = CreateConVar("ob_throw_dmg", "200", "Sets the damage of an oddball throw hit.");
}

public void CG_OnPrimaryAttack(int client, int weapon){
	char sWeapon[32];
	GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));
	
	if(StrEqual(sWeapon, CLASSNAME)){
		//CG_SetPlayerAnimation(client, PLAYER_ATTACK1);
		CG_PlayPrimaryAttack(weapon);
		CG_SetNextPrimaryAttack(weapon, GetGameTime() + COOLDOWN_PRIMARY);
		CG_SetNextSecondaryAttack(weapon, GetGameTime() + COOLDOWN_SECONDARY);
		
		PrimaryFire(client, weapon);
	}
}

public void CG_OnSecondaryAttack(int client, int weapon){
	char sWeapon[32];
	GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));
	
	if(StrEqual(sWeapon, CLASSNAME)){
        PrintToServer("Oddball secondary attack!!!");
        CG_DropWeapon(weapon);
    }
}

void PrimaryFire(int client, int weapon) {
    PrintToServer("Oddball Primary Fire!!!");
    
}

public bool TraceEntityFilter(int entity, int mask, any data){
	if (entity == data)
		return false;
	return true;
}