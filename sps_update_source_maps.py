import os
import sys
import json
import re
import shutil

def process_source_map(file_path):
    # Check if EMSDK environment variable exists
    emsdk_path = os.environ.get('EMSDK')
    if not emsdk_path:
        print("EMSDK environment variable not set.")
        return

    pattern = os.path.join(os.path.relpath('/', os.getcwd()), 'emsdk')
    replacement_prefix = os.path.relpath(os.path.join(emsdk_path, 'upstream'), os.getcwd())
    
    # Load the source map file
    with open(file_path, 'r') as f:
        source_map = json.load(f)

    # Replace matching paths in the "sources" array
    updated_sources = []
    for src in source_map.get('sources', []):
        updated_src = re.sub(pattern, replacement_prefix, src)
        updated_sources.append(updated_src)

    # Update the source map with the modified sources
    source_map['sources'] = updated_sources

    # Write the updated source map to a temporary file
    temp_file_path = f"{file_path}.tmp"
    with open(temp_file_path, 'w') as temp_file:
        json.dump(source_map, temp_file, indent=2)

    # Atomically replace the original file with the temporary file
    shutil.move(temp_file_path, file_path)

    print(f"Updated source map written to {file_path}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py <mapFile>")
        sys.exit(1)

    mapFile = sys.argv[1]
    process_source_map(mapFile)
