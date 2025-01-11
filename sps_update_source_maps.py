import os
import json
import re

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
    replacement_prefix = os.path.join(emsdk_path, "upstream")

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


