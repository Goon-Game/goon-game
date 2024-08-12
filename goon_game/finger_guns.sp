#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <customguns>
#include <weapon_functions>

void FireTrace(int client) {

}

public OnMapStart() //*from laser_tag.sp
{
	g_sprite = PrecacheModel("materials/effects/gunshiptracer.vmt");
    PrecacheModel("materials/sprites/laser.vmt");
}


stock CreateBulletTrace(const Float:origin[3], const Float:dest[3], const Float:speed = 6000.0, const Float:startwidth = 0.5, const Float:endwidth = 0.2, const String:color[] = "200 200 0") {
    // https://forums.alliedmods.net/showthread.php?p=1913307
	PrintToServer("Origin: %f %f %f", origin[0], origin[1], origin[2]);
    PrintToServer("Dest: %f %f %f", dest[0], dest[1], dest[2]);
    
    
    new entity = CreateEntityByName("env_spritetrail");
	if (entity == -1){
		LogError("Couldn't create entity 'bullet_trace'");
        PrintToServer("Coudln't creat entity 'bullet trace");
		return -1;
	} else {
        PrintToServer("Made bullet trace %d", entity);
    }
	if (DispatchKeyValue(entity, "classname", "bullet_trace")) {
        PrintToServer("Made bullet trace");
    }
	DispatchKeyValue(entity, "spritename", "materials/sprites/laser.vmt");
    //DispatchKeyValue(entity, "spritename", "materials/sprites/cannon_muzzle.vmt");
	DispatchKeyValue(entity, "renderamt", "255");
	DispatchKeyValue(entity, "rendercolor", color);
	DispatchKeyValue(entity, "rendermode", "5");
	DispatchKeyValueFloat(entity, "startwidth", startwidth);
	DispatchKeyValueFloat(entity, "endwidth", endwidth);
	DispatchKeyValueFloat(entity, "lifetime", 240.0 / speed);
	if (!DispatchSpawn(entity)) {
		AcceptEntityInput(entity, "Kill");
        PrintToServer("Couldn't create bullet_trace");
		LogError("Couldn't create entity 'bullet_trace'");
		return -1;
	} else {
        PrintToServer("Made bullet_trace");
    }
	
	SetEntPropFloat(entity, Prop_Send, "m_flTextureRes", 0.05);
	
	decl Float:vecVeloc[3], Float:angRotation[3];
	MakeVectorFromPoints(origin, dest, vecVeloc);
	GetVectorAngles(vecVeloc, angRotation);
	NormalizeVector(vecVeloc, vecVeloc);
	ScaleVector(vecVeloc, speed);
	
	TeleportEntity(entity, origin, angRotation, vecVeloc);
	
	decl String:_tmp[128];
	FormatEx(_tmp, sizeof(_tmp), "OnUser1 !self:kill::%f:-1", GetVectorDistance(origin, dest) / speed);
	SetVariantString(_tmp);
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser1");
	
	return entity;
}

int cooldown;

/**
 * To avoid side effects from the base weapon, eat the player's command inputs.
 * Only advance the weapon's state if it is presently WEAPON_IDLE.
 */
public Action OnPlayerRunCmd(client, &iButtons, &Impulse, Float:fVelocity[3], Float:fAngles[3], &iWeapon) {
	if (!IsFakeClient(client) && IsPlayerAlive(client)) {
		if (iButtons & IN_ATTACK) {
			//iButtons &= ~IN_ATTACK;
			// The attack call is special because it needs to happen right away
			// The state will be advanced in there.
            if (cooldown > 100) {
                cooldown = 0;
                //FireTraceBeam(client);
                // new Float:start[3];
                // CG_GetShootPosition(client, start);

                // float angles[3];
                // GetClientEyeAngles(client, angles);
                // TR_TraceRayFilter(start, angles, MASK_SHOT, RayType_Infinite, TraceEntityFilter, client);
                
                // new Float:end[3]; //consolidated from earlier code however simular to usage in laser_tag.sp
                // TR_GetEndPosition(end);
                // CreateBulletTrace(start, end);
                // PrintToServer("Loop!");
            }
            else if (cooldown < 0) {
                cooldown = 0;
            }
            cooldown++;
		}
	}
	return Plugin_Continue;
}

public bool TraceEntityFilter(int entity, int mask, any data){
	if (entity == data)
		return false;
	return true;
}