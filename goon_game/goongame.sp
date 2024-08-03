#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <sdkhooks>
#include <dhooks>
#include <customguns>
#include <gungame_goon>

#define PLUGIN_VERSION "0.1.0"
#define PLUGIN_NAME "[FoF] Goon Game"
#define CHAT_PREFIX "\x04 GG \x07FFDA00 "
#define CONSOLE_PREFIX "[GoonGame] "

public Plugin:myinfo =
{
    name = PLUGIN_NAME,
    author = "Baker80k",
    description = "Funny Guns for Fistful of Frags",
    version = PLUGIN_VERSION,
    url = "https://github.com/Goon-Game/goon-game"
};

public OnClientPutInServer(int client) {
    PrintToChatAll("Client in Server");
}

public void OnPluginStart() {
    RegConsoleCmd("gun", Gun_Menu);
    RegConsoleCmd("melee", Melee_Menu);
    //RegConsoleCmd("melee", Melee_Menu);
    //RegConsoleCmd("misc", Misc_Menu);
    RegConsoleCmd("debug", Debug_Client);
}

public Action Gun_Menu(int client, int args) {
    Menu menu = new Menu(Menu_Callback);
    menu.SetTitle("Custom Gun Menu");
    menu.AddItem("weapon_bigiron", "Big  Iron");
    menu.AddItem("weapon_brownbess", "Brownbess Musket");
    menu.AddItem("weapon_guncoach", "Guncoach");
    menu.AddItem("weapon_weeze_wacker", "Weeze Wacker");
    menu.AddItem("weapon_gauss", "Hl1 Gauss Gun");
    menu.ExitButton = true;
    menu.Display(client, 30);
    return Plugin_Handled;
}

public Action Melee_Menu(int client, int args) {
    Menu menu = new Menu(Menu_Callback);
    menu.SetTitle("Custom Melee Menu");
    menu.AddItem("weapon_shovel", "Shovel");
    menu.AddItem("weapon_oddball", "Halo Oddball");
    menu.ExitButton = true;
    menu.Display(client, 30);
    return Plugin_Handled;
}

public Action Debug_Client(int client, int args) {
    PrintToChatAll("%sPrinting debug message for %d", CONSOLE_PREFIX, client);
    //GunGame_PrintClientDebug(client);
    CG_PrintClientDebug(client);
    return Plugin_Handled;
}

public int Menu_Callback(Menu menu, MenuAction action, int client, int param2) {
    switch (action) {
        case MenuAction_Start:
        {
            PrintToServer("Displaying menu");
        }

        case MenuAction_Display:
        {
            char buffer[255];
            Format(buffer, sizeof(buffer), "%T", "Vote Nextmap", client);
        
            Panel panel = view_as<Panel>(param2);
            panel.SetTitle(buffer);
            PrintToServer("Client %d was sent menu with panel %x", client, param2);
        }

        case MenuAction_Select:
        {
            char info[32];
            menu.GetItem(param2, info, sizeof(info));
            PrintToServer("Client %d selected %s", client, info);
            CG_GiveGun(client, info);
        }

        case MenuAction_Cancel:
        {
            PrintToServer("Client %d's menu was cancelled for reason %d", client, param2);
        }

        case MenuAction_End:
        {
            delete menu;
        }

    }

}