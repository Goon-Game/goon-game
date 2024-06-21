#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <sdkhooks>
#include <dhooks>

public OnClientPutInServer(int client) {
    PrintToChatAll("Client in Server");
}