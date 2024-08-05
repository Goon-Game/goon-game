SHELL=/bin/bash

.DEFAULT_GOAL := all

# The pathing in this project gets a little funny because the valve compilation tools
# are really particular about where they're executed, so in order to preserve the custom folder strcuture
# we need to do some pathing shenanigans
# Set these ABSOLUTE PATHS in your .bashrc
# PROJ_DIR // Wherever this project is installed
# FOF_INSTALL_DIR // sdk things like vpk and studiomdl
# FOF_SERVER_DIR // sourcemod things like spcomp and includes
# WEAPON_MODEL_DIR // Assumes each weapon type has a folder with its name containing all viewmodel, worldmodel, and material files

# This is for my setup where I have a windows machine with the game,
# while my dev environment and fof server is on wsl
# For your own use, set these things in your .bashrc to whatever
VPK="$(FOF_INSTALL_DIR)/sdk/bin/vpk.exe"
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
override customguns_inc_files=$(shell find customguns-fof/scripting/include -name '*.inc')

customguns_plugin: $(customguns_sps:customguns-fof/scripting/%.sp=$(plugins_dir)/%.smx)

$(plugins_dir)/%.smx: customguns-fof/scripting/%.sp $(customguns_incs) $(customguns_inc_files)
	@$(SPCOMP) $< -o $@ $(customguns_inc_flags) -O2 -v2

# Other
customguns_other: fof/addons/sourcemod/gamedata/customguns.txt fof/addons/sourcemod/configs/customguns_styles.txt
	
fof/addons/sourcemod/gamedata/customguns.txt: customguns-fof/gamedata/customguns.txt
	cp customguns-fof/gamedata/customguns.txt fof/addons/sourcemod/gamedata/customguns.txt

fof/addons/sourcemod/configs/customguns_styles.txt: customguns-fof/configs/customguns_styles.txt
	cp customguns-fof/configs/customguns_styles.txt fof/addons/sourcemod/configs/customguns_styles.txt

customguns: customguns_plugin customguns_other

override gungame_sps=$(shell find sm-gungame-fof/addons/sourcemod/scripting -name '*.sp' 2>/dev/null)
override gungame_incs=sm-gungame-fof/addons/sourcemod/scripting/include $(sourcemod_incs) $(customguns-incs)
override gungame_inc_flags=$(addprefix -i ,$(gungame_incs))
override gungame_inc_files=$(shell find sm-gungame-fof/addons/sourcemod/scripting/include -name '*.inc')

gungame_plugin: $(gungame_sps:sm-gungame-fof/addons/sourcemod/scripting/%.sp=$(plugins_dir)/%.smx)

$(plugins_dir)/%.smx: sm-gungame-fof/addons/sourcemod/scripting/%.sp $(gungame_incs)
	@$(SPCOMP) $< -o $@ $(gungame_inc_flags) $(customguns_inc_flags) -O2 -v2

gungame_configs: fof/addons/sourcemod/configs/goongame_weapons.txt fof/addons/sourcemod/configs/goongame_weapons_short.txt

fof/addons/sourcemod/configs/goongame_weapons.txt: sm-gungame-fof/addons/sourcemod/configs/goongame_weapons.txt
	cp sm-gungame-fof/addons/sourcemod/configs/goongame_weapons.txt fof/addons/sourcemod/configs/goongame_weapons.txt

fof/addons/sourcemod/configs/goongame_weapons_short.txt: sm-gungame-fof/addons/sourcemod/configs/goongame_weapons_short.txt
	cp sm-gungame-fof/addons/sourcemod/configs/goongame_weapons_short.txt fof/addons/sourcemod/configs/goongame_weapons_short.txt

gungame: gungame_plugin gungame_configs

override goongame_txts=$(shell find scripts -name '*.txt' 2>/dev/null)

override goongame_sps=$(shell find goon_game -name '*.sp' 2>/dev/null)
override goongame_incs=goon_game/include $(sourcemod_incs) $(gungame_incs) $(customguns_incs)
override goongame_inc_flags=$(addprefix -i ,$(goongame_incs))
override goongame_inc_files=$(shell find goon_game/include -name '*.inc')

goongame_plugin: $(goongame_sps:goon_game/%.sp=$(plugins_dir)/%.smx)

$(plugins_dir)/%.smx: goon_game/%.sp $(goongame_incs) $(goongame_inc_files) $(customguns_incs)
	@$(SPCOMP) $< -o $@ $(goongame_inc_flags) $(customguns_inc_flags) -O2 -v2

$(custom_dir)/goongame_scripts.vpk: $(goongame_txts)
	${RM} $(custom_dir)/goongame_scripts.vpk
	$(VPK) a $(custom_dir)/goongame_scripts.vpk $(goongame_txts)

# Any change to the asset files or folders should be detected
override goongame_assets = $(shell find $(WEAPON_MODEL_DIR))
# A model not being there also should be detected
override goongame_weapon_names=$(shell find $(WEAPON_MODEL_DIR) -maxdepth 1 -mindepth 1 -type d -exec basename {} \;)
override goongame_model_files=$(foreach name,$(goongame_weapon_names),$(WEAPON_MODEL_DIR)/$(name)/v_$(name).mdl) $(foreach name,$(goongame_weapon_names),$(WEAPON_MODEL_DIR)/$(name)/w_$(name).mdl)

# % is gonna be name/v_name or name/w_name
$(WEAPON_MODEL_DIR)/%.mdl: workflow/model_Makefile
	@wildcard_string=$*; \
	name=$${wildcard_string%%/*}; \
	cp -u workflow/model_Makefile "$(WEAPON_MODEL_DIR)/$$name/Makefile"; \
	cd "$(WEAPON_MODEL_DIR)/$$name" && make; \

# VPK requires executing things in a particular directory
# Also, this modularization makes it a bit easier to debug asset compilation
$(WEAPON_MODEL_DIR)/../goongame_assets.vpk: $(goongame_model_files) workflow/asset_Makefile
	cp -u workflow/asset_Makefile $(WEAPON_MODEL_DIR)/../Makefile
	${RM} $(WEAPON_MODEL_DIR)/../goongame_assets.vpk
	(cd $(WEAPON_MODEL_DIR)/.. && make)

goongame: $(custom_dir)/goongame_scripts.vpk $(WEAPON_MODEL_DIR)/../goongame_assets.vpk goongame_plugin

all: customguns gungame goongame

# Copy only updated stuff to server and client
upload_server: all
	${RM} -r $(FOF_SERVER_DIR)/fof/custom/*.cache
	cp -r -u fof $(FOF_SERVER_DIR)
	cp -u $(WEAPON_MODEL_DIR)/../goongame_assets.vpk $(FOF_SERVER_DIR)/fof/custom/goongame_assets.vpk
	${RM} $(FOF_SERVER_DIR)/fof/addons/sourcemod/plugins/gungame_goon.smx

upload_server_gungame: all
	${RM} -r $(FOF_SERVER_DIR)/fof/custom/*.cache
	cp -r -u fof $(FOF_SERVER_DIR)
	cp -u $(WEAPON_MODEL_DIR)/../goongame_assets.vpk $(FOF_SERVER_DIR)/fof/custom/goongame_assets.vpk
	
# THIS DOES NOT WORK IF HLMV++ HAS A MODEL OPEN
upload_client: all
	${RM} -r "$(FOF_INSTALL_DIR)/fof/custom/"*.cache
	cp "$(custom_dir)/goongame_scripts.vpk" "$(FOF_INSTALL_DIR)/fof/custom/goongame_scripts.vpk"
	cp $(WEAPON_MODEL_DIR)/../goongame_assets.vpk "$(FOF_INSTALL_DIR)/fof/custom/goongame_assets.vpk"

upload: upload_server upload_client

# # Make a zip folder containing everything
release_zip: all
	cp -u $(WEAPON_MODEL_DIR)/../goongame_assets.vpk $(custom_dir)/goongame_assets.vpk 
	zip -r goongame.zip fof

clean:
	$(RM) fof/addons/sourcemod/configs/*.txt
	$(RM) fof/addons/sourcemod/gamedata/*.txt
	$(RM) fof/addons/sourcemod/plugins/*.smx
	$(RM) fof/custom/*.vpk
	$(RM) $(WEAPON_MODEL_DIR)/../goongame_assets.vpk
	$(RM) $(WEAPON_MODEL_DIR)/*/*.mdl
	$(RM) -r $(WEAPON_MODEL_DIR)/../goongame_assets
	$(RM) "$(FOF_INSTALL_DIR)/fof/custom/*.vpk"
	$(RM) $(FOF_SERVER_DIR)/fof/custom/*.vpk
	
dirs:
	@echo $(PROJ_DIR)

# TODO: working on 
test:
	@echo $(goongame_model_files)

