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
SYMBOLS_EXPORT_FILENAME = "aSymbolsExport.mlb"

script_directory = os.path.abspath(os.path.dirname(__file__))
hack_filepath = script_directory + "\\" + HACK_FILENAME
vanilla_filepath = script_directory + "\\" + VANILLA_FILENAME
asm_folderpath = script_directory + "\\" + ASM_FOLDER
symbols_folderpath = script_directory + "\\" + SYMBOLS_FOLDER
symbol_export_filepath = script_directory + "\\" + SYMBOLS_EXPORT_FILENAME
generated_symbols_folderpath = symbols_folderpath + "\\" + "AUTO_GENERATED"
vanilla_symbol_file_path = symbols_folderpath + "\\vanilla.mlb"


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
        deleteFileIfExists(file.resolve())

    # TODO: HANDLE IPS PATCHES

    os.makedirs(asm_folderpath, exist_ok=True)
    for filename in os.listdir(asm_folderpath):
        file = Path(asm_folderpath + "\\" + filename)
        if file.suffix.lower() == ".asm":
            print(file.resolve()) # "-wnoWfeature_deprecated"
            result = subprocess.run(args = ["asar", "--no-title-check", "--fix-checksum=off", "--symbols=wla", "--symbols-path=" + generated_symbols_folderpath + "\\" + file.stem + ".sym", file.resolve(), hack_filepath])
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
    if (len(SYMBOLS_EXPORT_FILENAME) > 0):
        combineSymbolFiles(symbols_folderpath, generated_symbols_folderpath, symbol_export_filepath)
    print()

    print("================= BUILD COMPLETED =================" + " Time elapsed (seconds): " + str((datetime.now() - starttime).total_seconds()))

def handleError(msg="Press Enter to continue..."):
    copyVanillaRom()
    input(msg)
    sys.exit(1)

def copyVanillaRom():
    deleteFileIfExists(hack_filepath)
    shutil.copy(vanilla_filepath, hack_filepath)

def combineSymbolFiles(symbols_folderpath, generated_symbols_folderpath, symbol_export_filepath):
    symbol_table = {}
    print(vanilla_symbol_file_path)
    parseMlbFile(vanilla_symbol_file_path, symbol_table)
    for filename in os.listdir(generated_symbols_folderpath):
        file = Path(generated_symbols_folderpath + "\\" + filename)
        if file.suffix.lower() == ".sym":
            print(file.resolve())
            parseSymFile(file.resolve(), symbol_table)
    generateNewMlbFile(symbol_table, symbol_export_filepath)

def parseMlbFile(file_path, symbol_table):
    try:
        with open(file_path, 'r') as f:
            for line in f:
                # Strip whitespace and check if the line is empty or a comment
                line = line.strip()
                if not line or line.startswith(';'):
                    continue

                # Split the line at the colon delimiter
                parts = line.split(':', 2)
                if len(parts) == 3:
                    address_type = parts[0].strip().removeprefix("ï»¿")
                    pc_address = parts[1].strip()
                    symbol_name = parts[2].strip()
                    addSymbolToSymbolTable(symbol_table, address_type, pc_address, symbol_name)
                    
    except FileNotFoundError:
        print(f"Error: The file {file_path} was not found.")
    except Exception as e:
        print(f"An error occurred while reading the file: {e}")

def parseSymFile(file_path, symbol_table):
    in_labels_section = False
    with open(file_path, 'r') as f:
        for line in f:
            # Strip whitespace and check if the line is empty or a comment
                line = line.strip()
                if not line or line.startswith(';'):
                    continue
                if line.startswith('[labels]'):
                    in_labels_section = True
                    continue
                if line.startswith('['):
                    in_labels_section = False
                    continue
                if not in_labels_section:
                    continue
                # Split the line at the space delimiter
                parts = line.split(' ', 1)
                lorom_address = parts[0].strip().replace(":", "")
                address_type = get_address_type(lorom_address)
                if len(address_type) < 1:
                    continue
                pc_address = lorom_to_pc(lorom_address, address_type)
                symbol_name = parts[1].strip().replace(":", "")
                addSymbolToSymbolTable(symbol_table, address_type, pc_address, symbol_name)

def generateNewMlbFile(symbol_table, symbol_export_filepath):
    deleteFileIfExists(symbol_export_filepath)
    filteredDicts = []
    filteredDicts.append({k: v for k, v in symbol_table.items() if k.startswith('PRG')})
    filteredDicts.append({k: v for k, v in symbol_table.items() if k.startswith('WORK')})
    filteredDicts.append({k: v for k, v in symbol_table.items() if k.startswith('SAVE')})
    filteredDicts.append({k: v for k, v in symbol_table.items() if k.startswith('SPCRAM')})
    filteredDicts.append({k: v for k, v in symbol_table.items() if k.startswith('REG')})
    with open(symbol_export_filepath, 'w') as file:
        for dict in filteredDicts:
            for key, value in dict.items():
                file.write(f"{key}:{value}\n")

# lorom
def get_address_type(lorom_address):
    bankInt = int(lorom_address[:2], 16)
    addrWithoutBankInt = int(lorom_address[2:], 16)
    if (bankInt >= int("80", 16) and bankInt <= int("FF", 16) and addrWithoutBankInt >= int("8000", 16)):
        return "PRG" # ROM
    if (bankInt >= int("7E", 16) and bankInt <= int("7F", 16)):
        return "WORK" # WRAM
    return "" # not handling the rest atm

# this is apparently not as simple as lorom to pc address converstion...
# because each section of memory starts at 0 in .mlb files.
# so PRG starts at 0 (maps to lorom 808000), WORK starts at 0 (maps to lorom 7E0000)...
def lorom_to_pc(lorom_address, address_type):
    bankInt = int(lorom_address[:2], 16)
    addrWithoutBankInt = int(lorom_address[2:], 16)
    pcAddressInt = ((bankInt - int("80", 16))*int("8000", 16)) + (addrWithoutBankInt - int("8000", 16))
    if (address_type == "WORK"):
        pcAddressInt = pcAddressInt - int("7E0000", 16)
    return pcAddressInt.to_bytes(3, byteorder="big").hex()


def addSymbolToSymbolTable(symbol_table, address_type, pc_address, symbol_name):
    try:
        # If the symbol already exists, overwrites it. This is intentional.
        key = address_type + ":" + pc_address
        if (key in symbol_table) and ("_freespace" in symbol_name):
            return # Actually don't overwrite it if the new one is just a freespace indicator.
        symbol_table[key] = symbol_name
    except ValueError:
        print(f"Skipping line due to invalid address format: {symbol_name}")
    
def deleteFileIfExists(path):
    if os.path.exists(path):
        os.remove(path)

main()