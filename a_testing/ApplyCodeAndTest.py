import subprocess
import os
import sys

script_directory = os.path.abspath(os.path.dirname(__file__))
result = subprocess.run(["python", "z_ApplyCode.py"], cwd=script_directory)
if result.returncode != 0:
    sys.exit(1)
else:
    os.startfile(script_directory + "\\Hack.smc")
