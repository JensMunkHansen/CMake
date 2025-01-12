import os
import json
import re


# Working dir should be output dir

os.path.join(os.environ.get('EMSDK'), 'upstream')

# What to replace
os.path.join(os.path.relpath('/', os.getcwd()), 'emsdk')
# With this
os.path.relpath(os.path.join(os.environ.get('EMSDK'), 'upstream'), os.getcwd())

# TEST THIS
# export EMSCRIPTEN_ROOT="/home/jmh/github/emsdk/upstream/"

def process_source_map(file_path, output_path):
    # Check if EMSDK environment variable exists
    emsdk_path = os.environ.get('EMSDK')
    if not emsdk_path:
        print("EMSDK environment variable not set.")
        return

    #start_path # should be build path
    #target_path the path of the upstream folder
    
    relative_path = os.path.relpath(target_path, start_path)
    
    # Construct the replacement prefix
    replacement_prefix = os.path.relpath(os.path.join(emsdk_path, "upstream"), os.getcwd())

    # Load the source map file
    with open(file_path, 'r') as f:
        source_map = json.load(f)

    # Regular expression to match the ../../../../../../emsdk/emscripten/ pattern
    pattern = r"(\.\./)+emsdk/emscripten/"

    # Replace matching paths in the "sources" array
    updated_sources = []
    for src in source_map.get('sources', []):
        updated_src = re.sub(pattern, replacement_prefix, src)
        updated_sources.append(updated_src)

    # Update the source map with the modified sources
    source_map['sources'] = updated_sources

    # Write the updated source map to the output file
    with open(output_path, 'w') as f:
        json.dump(source_map, f, indent=2)

    print(f"Updated source map written to {output_path}")


# Example usage
source_map_file = "my_code.wasm.map"
output_file = "updated_map.wasm.map"

process_source_map(source_map_file, output_file)



# check_main.py
import sys

def has_main_function(files):
    for file in files:
        try:
            with open(file, 'r') as f:
                content = f.read()
                if 'int main(' in content or 'void main(' in content:
                    return True
        except FileNotFoundError:
            pass
    return False

if __name__ == "__main__":
    mapFile = sys.argv[1:]
    if has_main_function(files):
        print("1")  # Indicates 'main' function exists
    else:
        print("0")  # Indicates no 'main' function
