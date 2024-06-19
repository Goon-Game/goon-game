SHELL=/bin/bash

.DEFAULT_GOAL := all

# Set these things in your .bashrc
# FOF_INSTALL_DIR // sdk things like vpk and studiomdl
# FOF_SERVER_DIR // sourcemod things like spcomp and includes
# WEAPON_MODEL_DIR // Assumes each weapon type has a folder with its name, containing w_name and v_name folders

# This is for my setup where I have a windows machine with the game,
# while my dev environment and fof server is on wsl
# For your own use, set these things in your .bashrc to whatever
VPK="$(FOF_INSTALL_DIR)/sdk/bin/vpk.exe"
STUDIOMDL="$(FOF_INSTALL_DIR)/sdk/bin/studiomdl.exe"
SPCOMP="$(FOF_SERVER_DIR)/fof/addons/sourcemod/scripting/spcomp"

override sourcemod_incs_dir="$(FOF_SERVER_DIR)/fof/addons/sourcemod/scripting/include"
override plugins_dir=fof/addons/sourcemod/plugins
override custom_dir=fof/custom

# plugin refers to the .sp files
# scripts, models, and sounds are for custom .vpk's
# other is for anything else that needs to get put in the right spot

override sourcemod_incs=$(shell find $(sourcemod_incs_dir) -name '*.inc' 2>/dev/null)

override customguns_sps=$(shell find customguns-fof/scripting -name '*.sp' 2>/dev/null)
override customguns_incs=customguns-fof/scripting/include $(sourcemod_incs)
override customguns_inc_flags=$(addprefix -i ,$(customguns_incs))

customguns_plugin: $(customguns_sps:customguns-fof/scripting/%.sp=$(plugins_dir)/%.smx)

$(plugins_dir)/%.smx: customguns-fof/scripting/%.sp $(customguns_incs)
	$(SPCOMP) $< -o $@ $(customguns_inc_flags) -O2 -v2

# Other
customguns_other: fof/addons/sourcemod/gamedata/customguns.txt fof/addons/sourcemod/configs/customguns_styles.txt
	
fof/addons/sourcemod/gamedata/customguns.txt: customguns-fof/gamedata/customguns.txt
	cp customguns-fof/gamedata/customguns.txt fof/addons/sourcemod/gamedata/customguns.txt

fof/addons/sourcemod/configs/customguns_styles.txt: customguns-fof/configs/customguns_styles.txt
	cp customguns-fof/configs/customguns_styles.txt fof/addons/sourcemod/configs/customguns_styles.txt

customguns: customguns_plugin customguns_other

# gungame_plugin:


override goongame_txts=$(shell find scripts -name '*.txt' 2>/dev/null)
# goongame_plugin:

$(custom_dir)/goongame_scripts.vpk: $(goongame_txts)
	$(VPK) a $(custom_dir)/goongame_scripts.vpk $(goongame_txts)

goongame: $(custom_dir)/goongame_scripts.vpk

all: customguns goongame

# Copy only updated stuff to server and client
upload: all
	cp -r -u fof $(FOF_SERVER_DIR)
	cp -r -u fof/custom "$(FOF_INSTALL_DIR)"

# # Make a zip folder containing everything
release_zip: all
	zip -r goongame.zip fof

clean:
	rm fof/addons/sourcemod/configs/*.txt
	rm fof/addons/sourcemod/gamedata/*.txt
	rm fof/addons/sourcemod/plugins/*.smx
	rm fof/custom/*.vpk
	
