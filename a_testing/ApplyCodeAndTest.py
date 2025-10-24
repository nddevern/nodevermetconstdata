import subprocess
import os
script_directory = os.path.abspath(os.path.dirname(__file__))
subprocess.run(["python", "z_ApplyCode.py"], cwd=script_directory)
os.startfile(script_directory + "\\Hack.smc")
