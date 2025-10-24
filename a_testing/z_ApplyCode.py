import subprocess
import os
import shutil
import time
from pathlib import Path
from datetime import datetime

# this script assumes the following:
# All ASM/IPS patches are in a folder called "ASM", a folder that exists in the same directory as this script
# The Hack and Vanilla ROM also exist in the same directory as this script
# Note: This script creates a folder called "Symbols" in the same directory as itself. Feel free to add any symbol files you'd like into it.
#       The script also creates a subfolder at "Symbols\AUTO_GENERATED" and will automatically generate symbols for your asm files there.
#       TODO: The script will then merge all of these symbol files into an output file that you can drag into your debugger and see everything there.

HACK_FILENAME = "Hack.smc"
VANILLA_FILENAME = "Super Metroid (JU) [!].smc"
ASM_FOLDER = "ASM"
SYMBOLS_FOLDER = "Symbols"

script_directory = os.path.abspath(os.path.dirname(__file__))
hack_filepath = script_directory + "\\" + HACK_FILENAME
vanilla_filepath = script_directory + "\\" + VANILLA_FILENAME
asm_folderpath = script_directory + "\\" + ASM_FOLDER
symbols_folderpath = script_directory + "\\" + SYMBOLS_FOLDER
generated_symbols_folderpath = symbols_folderpath + "\\" + "AUTO_GENERATED"

starttime = datetime.now()

print("=========== BUILDING SUPER METROID HACK ===========")
print()
print("====== [1] Copying Super Metroid Vanilla ROM ======")
print()
os.remove(hack_filepath)
shutil.copy(vanilla_filepath, hack_filepath)

# never ported this from batch to python, didn't need it yet
# @echo ============= [2] Recompressing Data ==============
# cd ".\bin\DECOMPRESSED"
# for %%f in (*.bin) do "..\..\Lunar Compress\recomp" "%%f" ".\OUTPUT\%%f" 0 1004 0
# cd ..\..
# @echo( & @echo( & @echo(

print("============== [3] Applying Patches ===============")
print()

# delete existing generated symbol files if any exist
os.makedirs(generated_symbols_folderpath, exist_ok=True)
for filename in os.listdir(generated_symbols_folderpath):
    file = Path(generated_symbols_folderpath + "\\" + filename)
    os.remove(file.resolve())

# TODO: HANDLE IPS PATCHES

for filename in os.listdir(asm_folderpath):
    file = Path(asm_folderpath + "\\" + filename)
    if file.suffix.lower() == ".asm":
        print(file.resolve())
        subprocess.run(args = ["asar", "--no-title-check", "--fix-checksum=off", "--symbols=wla", "--symbols-path=" + generated_symbols_folderpath + "\\" + file.stem + ".sym", file.resolve(), hack_filepath])
print()

#print("========= [4] Importing SMART Data to ROM =========")
#print()
#smartargs = ["SMART.exe", "import", "|", "findstr", "\"^\""]
#subprocess.run(smartargs)

print("=========== [5] Combining Symbol Files ============")
print("todo")
print()

print("================= BUILD COMPLETED =================")
print("Time elapsed (seconds): " + str((datetime.now() - starttime).total_seconds()))
print()