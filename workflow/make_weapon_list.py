WEAPON_FILE = "sm-gungame-fof/addons/sourcemod/configs/goongame_weapons.txt"

# This list goes (right hand, left hand)
# typical names are like "weapon_walker"
# the left hand weapons are like "weapon_walker2"
WEAPONS_LIST = [
    # Busted
    ("weapon_walker", ""),
    ("weapon_sharps", ""),
    ("weapon_xbow", "weapon_x_arrow"),

    # Very good
    ("weapon_peacemaker", ""),
    ("weapon_henryrifle", ""),
    ("weapon_spencer", ""),
    ("weapon_mauser", ""),
    ("weapon_schofield", ""),
    ("weapon_shotgun", ""),

    # Solid
    ("weapon_bigiron", ""),
    ("weapon_carbine", ""),
    ("weapon_coltnavy", ""),
    ("weapon_bow_black", "weapon_arrow_black"),
    ("weapon_maresleg", ""),
    ("weapon_machete", ""),
    ("weapon_bow", ""),

    # Ok
    ("weapon_shovel", ""),
    ("weapon_coachgun", ""),
    ("weapon_remington_army", ""),
    ("weapon_volcanic", ""),
    ("weapon_sawedoff_shotgun", "weapon_ghostgun2"),
    ("weapon_guncoach", ""),
    ("weapon_axe", ""),

    # Mediocre
    ("weapon_deringer", "weapon_deringer2"),
    ("weapon_brownbess", ""),

    # Terrible
    ("weapon_hammerless", ""),
    ("weapon_knife", ""),
    ("weapon_dynamite_belt", "weapon_dynamite_yellow"),
    ("weapon_weeze_wacker", ""),
    ("weapon_dynamite", ""),
    ("weapon_fists_ghost", "weapon_ghostgun"),

    # Winner!
    ("weapon_oddball", ""),
]

with open(WEAPON_FILE, "w+") as file:
    file.writelines("\"gungame_weapons\"\n{\n")

    for i, (right_hand, left_hand) in enumerate(WEAPONS_LIST):
        if (i == len(WEAPONS_LIST)-1):
            weapon_index = "winner"
        else:
            weapon_index = i + 1

        lines = [
            f"\t\"{weapon_index}\"",
            f"\t{{\n"
            f"\t\t\"{right_hand}\"\t\"{left_hand}\"\n"
            f"\t}}"
        ]
        full_lines = [f"{line}\n" for line in lines]

        file.writelines(full_lines)

    file.writelines("}")

    file.close()



