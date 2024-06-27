# Rename all the bones in decompiled .smd's so that 
# the model can be repositioned on the server after bonemerging
# Accomplished by adding SUFFIX to the end of bone names that don't already have it
# Be careful!!! Make a backup before executing!!!
# This script is intended to be ran in the same directory as the .qc file
# Where in this directory are the .smd's used in the model, and folders containing .smd's for the animations
# This script WILL rename ALL instances of the bones found in the .qc and any .smd's it can get its grubby hands on!

import os
import shlex

SUFFIX = "_gg" # For goon-game

print(f"Bonemerge fix running in {os.getcwd()}")

# Get the .qc file(s) and .smd's
qc_files = []
smd_files = []
for root, dirs, files in os.walk("."):
    for file in files:
        if file.endswith(".qc"):
            qc_files.append(f"{root}/{file}")
        elif file.endswith(".smd"):
            smd_files.append(f"{root}/{file}")

# Get the bone names from the .qc file
# And update them in the .qc file if applicable
bone_names = []
for qc_file in qc_files:
    with open(qc_file, 'r') as file:
        lines = file.readlines()

    file_modified = False
    for i, line in enumerate(lines):
        # Rename entries for bones and their parents
        if line.startswith("$definebone"):
            line_components = shlex.split(line) # Split on spaces but respect quoted substrings

            stored_bone_name = line_components[1] 
            if stored_bone_name.endswith(SUFFIX):
                original_bone_name = stored_bone_name.removesuffix(SUFFIX)
                line_components[1]=f"\"{stored_bone_name}\""
            else:
                original_bone_name = stored_bone_name
                line_components[1] = f"\"{stored_bone_name}{SUFFIX}\"" # bone names are stored with "" around them
                file_modified = True
            bone_names.append(original_bone_name)

            stored_parent_name = line_components[2]
            if stored_parent_name == "":
                line_components[2] = f"\"\"" # Put the empty "" back into the line components
            elif not stored_parent_name.endswith(SUFFIX):
                line_components[2] = f"\"{stored_parent_name}{SUFFIX}\""
                file_modified = True
            else:
                line_components[2] = f"\"{stored_parent_name}\""
            
            modified_line = " ".join(line_components)
            lines[i] = f"{modified_line}\n"

        # Rename the bone component of $attachment and $hbox commands
        # Shouldn't need to save bone names here since they need to be mentioned in $definebone
        elif line.startswith("$attachment") or (line.startswith("$hbox") and not line.startswith("$hboxset")):
            line_components = shlex.split(line)

            line_components[1] = f"\"{line_components[1]}\""

            stored_bone_name = line_components[2]
            if stored_bone_name.endswith(SUFFIX):
                line_components[2] = f"\"{stored_bone_name}\""
            else:
                line_components[2] = f"\"{stored_bone_name}{SUFFIX}\""
                file_modified = True

            modified_line = " ".join(line_components)
            lines[i] = f"{modified_line}\n"

    # Fix the attachment lines

    # I don't think qc files have a set ordering,
    # so need to rewrite the whole thing 
    if file_modified:
        with open(qc_file, 'w') as file:
            for line in lines:
                file.write(line)

for smd_file in smd_files:
    with open(smd_file, 'r') as file:
        lines = file.readlines()
    
    file_modified = False
    for i, line in enumerate(lines):
        # smd's start with the skeleton, so stop reading once we get there
        if line.startswith("skeleton"):
            break
        line_components = shlex.split(line)
        if len(line_components) == 3: # bone_id "bone_name" parent_id
            stored_bone_name = line_components[1]
            if stored_bone_name in bone_names:
                line_components[1] = f"\"{stored_bone_name}{SUFFIX}\""
                file_modified = True
            else:
                line_components[1] = f"\"{stored_bone_name}\""
            
            modified_line = " ".join(line_components)
            lines[i] = f"{modified_line}\n"

    if file_modified:
        with open(smd_file, 'w') as file:
            for line in lines:
                file.write(line)

    print(smd_file)






