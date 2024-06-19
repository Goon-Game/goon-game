# goon-game
Fistful of Frags gungame with additional weapons

# PRESENT ISSUES

Client-side prediction causes viewmodels to flicker, or reload buttons need to be pressed multiple times, or the viewmodel to be entirely absent. Looking for a proper workaround.

Weapons do not retain their ammo level after being dropped.

Gauss gun spawns with no ammo and cannot be fired.

When picking up multiple custom guns, only one can ever be active and if dropped the other disappears.

Custom content is not downloaded to players connecting to server.

## Installation

### Server
Merge the 'fof' folder with your server's 'fof' folder.

### Client
Copy fof/custom/*.vpk to your custom folder. Note this is necessary for all players connecting to the server, since automatic resource downloading is not implemented yet.

## Added Weapons

In console, type "cg weapon_name" to spawn a weapon on the ground.

weapon_crowbar: Half life crowbar

weapon_shovel: Melee from customguns

weapon_gauss: Weapon from customguns

weapon_bigiron: Just a peacemaker model with a longer barrel

weapon_brownbess: From another sourcemod game (battlegrounds 3), just trying stuff out

