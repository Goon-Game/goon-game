#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <sdkhooks>
#include <dhooks>
#include <customguns>

public void OnPluginStart() {
    RegConsoleCmd("gun", Gun_Menu);
    //RegConsoleCmd("melee", Melee_Menu);
    //RegConsoleCmd("misc", Misc_Menu);
}

public Action Gun_Menu(int client, int args) {
    Menu menu = new Menu(Gun_Menu_Callback);
    menu.SetTitle("Custom Gun Menu");
    menu.AddItem("weapon_bigiron", "Big Iron");
    menu.AddItem("weapon_brownbess", "Brownbess Musket");
    menu.AddItem("weapon_guncoach", "Guncoach");
    menu.AddItem("weapon_weeze_wacker", "Duckfoot Pistol");
    menu.ExitButton = true;
    menu.Display(client, 30);
    return Plugin_Handled;
}

public int Gun_Menu_Callback(Menu menu, MenuAction action, int client, int param2) {
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