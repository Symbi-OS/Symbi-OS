# This code is explained in idt/idt.ipynb
import ctypes
import os
import subprocess
import pandas as pd


IDT_ENTRIES=256

symbios_path = "../../"
os.environ["LD_LIBRARY_PATH"] += ":" + symbios_path + "Symlib/dynam_build"

def run_cmd(cmd):
    ret = subprocess.run(cmd.split(), capture_output=True, text=True)
    if ret.returncode != 0:
        print("error: ", ret.returncode)
    return ret

def extract_desc_value(output, value):
    ret = output.decode("utf-8").split(value)[1].split("\n")[0]
    return hex(int(ret, 16))

def get_all_desc_values(df, output):
    fields = ["full addr:", "segment:", "ist:", "zero0:", "type:", "dpl:", "p:"]
    values = []
    for field in fields:
        value = extract_desc_value(output, field)
        values.append(value)
    df.loc[len(df)] = values

def read_whole_idt():
    import pandas as pd
    df = pd.DataFrame(columns=["full addr:", "segment:", "ist:", "zero0:", "type:", "dpl:", "p:"])
    for i in range(IDT_ENTRIES):
        output = subprocess.check_output([symbios_path + "Tools/bin/idt_tool", "-p", "-v", str(i)])
        get_all_desc_values(df, output)
    return df