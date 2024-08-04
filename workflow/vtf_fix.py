# The goal here is to look through a materials directory, find all .vmt's, and fix the paths of the .vtf's

# This script expects the materials directory to already be full of the required .vmt's of the model
# vmt's referenced by a model can be found by compiling it and looking in the 'model' tab of HLMV++
# The expected structure of the .vmt's is exactly
# materials/models/weapons/weapon_name/something.vmt
# And all the .vtf's should be plonked in there as well.

import os

WEAPON_NAME = "weeze_wacker"
MATERIALS_DIRECTORY = f"/mnt/e/sourcemod/model_compilation/working_model_files/{WEAPON_NAME}/materials"

# Supports all vertexlitgeneric from here https://steamcommunity.com/sharedfiles/filedetails/?id=2162570606
VTF_PARAMETERS = [
    "$albedo",
    "$bumpcompress",
    "$basetexture", 
    "$bumpmap", 
    "$bumpstretch",
    "$compress",
    "$detail",
    "$detailtexturetransform",
    "$emissiveblendbasetexture",
    "$emissiveblendflowtexture",
    "$emissiveblendtexture",
    "$envmap",
    "$envmapmask",
    "$fleshbordertexture1d",
    "$fleshcubetexture",
    "$fleshinteriornoisetexture",
    "$fleshinteriortexture",
    "$fleshnormaltexture",
    "$fleshsubsurfacetexture",
    "$lightwarptexture",
    "$phongexponenttexture",
    "$phongwarptexture",
    "$selfillummask",
    "$stretch"
]

VTF_FIELDS = [f"\"{parameter}\"" for parameter in VTF_PARAMETERS]

# Some VTFs are special, ignore them
IGNORED_VTFS = ["env_cubemap"]

os.chdir(MATERIALS_DIRECTORY)

print(f"VTF fix running in {os.getcwd()}")

expected_vtf_paths = []
for root, dirs, vmt_files in os.walk("."):
    for vmt_file in vmt_files:
        if vmt_file.endswith(".vmt"):
            # Make sure the paths of the .vmt files are correct
            parent_dir_name = root.split("/")[-1]
            if parent_dir_name != WEAPON_NAME:
                raise Exception(f"Improperly placed .vmt file! {vmt_file} in materials/{root}")
            
            # Read the .vmt file for any .vtf's referenced and fix path if necessary
            # Will make changes similar to the following:
            # "$detail" "detail\metal_detail_01"
            # gets changed to 
            # "$detail" "detail/WEAPON_NAME/metal_detail_01"

            vmt_path = f"{root}/{vmt_file}"
            with open(vmt_path) as file:
                lines = file.readlines()

            file_modified = False
            for i, line in enumerate(lines):
                line_components = line.split()
                if (len(line_components) > 0) and (line_components[0] in VTF_FIELDS):
                    original_vtf_path = line_components[1][1:-1].replace("\\", "/") # remove quotes, change to unix path
                    if original_vtf_path in IGNORED_VTFS:
                        continue
                    original_vtf_path_components = original_vtf_path.split("/")
                    original_vtf_parent_dir = original_vtf_path_components[-2]
                    if original_vtf_parent_dir != WEAPON_NAME:
                        file_modified = True
                        new_vtf_path = f"models/weapons/{WEAPON_NAME}/{original_vtf_path_components[-1]}"
                        modified_line = f"\t{line_components[0]}\t\"{new_vtf_path}\"\n"
                        lines[i] = modified_line
                        expected_vtf_path = new_vtf_path
                    else:
                        expected_vtf_path = original_vtf_path
                    expected_vtf_paths.append(expected_vtf_path)

            if file_modified:
                with open(vmt_path, 'w') as file:
                    for line in lines:
                        file.write(line)

# Search for all the .vtf files and print a list of which are missing
problems = False
for vtf_path in expected_vtf_paths:
    if not os.path.isfile(f"{vtf_path}.vtf"):
        print(f"Missing {vtf_path}.vtf!")
        problems = True

if not problems:
    print(f"VTF fix for {WEAPON_NAME} completed!")




