import subprocess
import os
import shutil
import time
import sys
from pathlib import Path
from datetime import datetime

# this script assumes the following:
# 1. All ASM/IPS patches are in a folder called "ASM", a folder that exists in the same directory as this script
# 2. The Hack and Vanilla ROM also exist in the same directory as this script
# 3. You have added asar and floating IPS to your system's PATH variable.
# Notes: 1. This script creates a folder called "Symbols" in the same directory as itself. Feel free to add any symbol files you'd like into it.
#           The script also creates a subfolder at "Symbols\AUTO_GENERATED" and will automatically generate symbols for your asm files there.
#           TODO: The script will then merge all of these symbol files into an output file that you can drag into your debugger and see everything there.
#        2. Modify the script_directory variable to move the directoy where all of this is happening to be somewhere other than the same directory as this script.

# todo: the msl file works if you change the extension to mlb. but that prese

HACK_FILENAME = "Hack.smc"
VANILLA_FILENAME = "Super Metroid (JU) [!].smc"
ASM_FOLDER = "ASM"
SYMBOLS_FOLDER = "Symbols"
SYMBOLS_EXPORT_FILENAME = "aSymbolsExport.sym" # WLA file format - https://wla-dx.readthedocs.io/en/stable/symbols.html - asar appears to use version 1

script_directory = os.path.abspath(os.path.dirname(__file__))
hack_filepath = script_directory + "\\" + HACK_FILENAME
vanilla_filepath = script_directory + "\\" + VANILLA_FILENAME
asm_folderpath = script_directory + "\\" + ASM_FOLDER
symbols_folderpath = script_directory + "\\" + SYMBOLS_FOLDER
generated_symbols_folderpath = symbols_folderpath + "\\" + "AUTO_GENERATED"


def main():

    starttime = datetime.now()

    current_step = 0
    print("=========== BUILDING SUPER METROID HACK ===========")
    print()

    copyVanillaRom()

    # never ported this from batch to python, didn't need it yet
    #current_step += 1
    # @echo ============= [" + str(current_step) + "] Recompressing Data ==============
    # cd ".\bin\DECOMPRESSED"
    # for %%f in (*.bin) do "..\..\Lunar Compress\recomp" "%%f" ".\OUTPUT\%%f" 0 1004 0
    # cd ..\..
    # @echo( & @echo( & @echo(

    current_step += 1
    print("============== [" + str(current_step) + "] Applying Patches ===============")
    print()

    # delete existing generated symbol files if any exist
    os.makedirs(generated_symbols_folderpath, exist_ok=True)
    for filename in os.listdir(generated_symbols_folderpath):
        file = Path(generated_symbols_folderpath + "\\" + filename)
        os.remove(file.resolve())

    # TODO: HANDLE IPS PATCHES

    os.makedirs(asm_folderpath, exist_ok=True)
    for filename in os.listdir(asm_folderpath):
        file = Path(asm_folderpath + "\\" + filename)
        if file.suffix.lower() == ".asm":
            print(file.resolve())
            result = subprocess.run(args = ["asar", "--no-title-check", "--fix-checksum=off", "-wnoWfeature_deprecated", "--symbols=wla", "--symbols-path=" + generated_symbols_folderpath + "\\" + file.stem + ".sym", file.resolve(), hack_filepath])
            if result.returncode != 0:
                handleError()
    print()

    #current_step += 1
    #print("========= [" + str(current_step) + "] Importing SMART Data to ROM =========")
    #print()
    #smartargs = ["SMART.exe", "import", "|", "findstr", "\"^\""]
    #print(smartargs)
    #subprocess.run(smartargs)
    #print()

    current_step += 1
    print("=========== [" + str(current_step) + "] Combining Symbol Files ============")
    print("todo")
    # todo: also test if mesen can import this symbol file via command line? kinda doubt it but it's worth a shot
    print()

    print("================= BUILD COMPLETED =================" + " Time elapsed (seconds): " + str((datetime.now() - starttime).total_seconds()))

def handleError(msg="Press Enter to continue..."):
    copyVanillaRom()
    input(msg)
    sys.exit(1)

def copyVanillaRom():
    os.remove(hack_filepath)
    shutil.copy(vanilla_filepath, hack_filepath)

main()