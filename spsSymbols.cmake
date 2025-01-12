get_filename_component(_Symbols_dir "${CMAKE_CURRENT_LIST_FILE}" DIRECTORY)

include(spsMultiConfiguration)

function(_sps_replace_symbols_script target_name output_file)
  # Write the header to the script
  file(WRITE "${output_file}" "# Auto-generated script for updating debug symbols\n\n")
  if (CMAKE_CONFIGURATION_TYPES)
    set(CONFIG "\${CONFIGURATION}")
  else()
    set(CONFIG)
  endif()
  set(SCRIPT_PATH "${_Symbols_dir}/sps_update_source_maps.py")
  set(MAP_FILE "${CMAKE_CURRENT_BINARY_DIR}/${CONFIG}/${target_name}.wasm.map")
  file(APPEND "${output_file}"
      "execute_process(\n"
      "  COMMAND ${CMAKE_COMMAND} -E env python3 ${SCRIPT_PATH} ${MAP_FILE}\n" 
      "  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${CONFIG}\n"
      ")\n")
  message(STATUS "Generated script: ${output_file}")
endfunction()

function(sps_update_symbols target)
  set(REPLACE_SYMBOLS_SCRIPT "${CMAKE_CURRENT_BINARY_DIR}/${target}_replace_symbols_script.cmake")
  _sps_replace_symbols_script(${target} ${REPLACE_SYMBOLS_SCRIPT} "${GENERATED_SCRIPT}")
  add_custom_target(${target}UpdateSymbols ALL
    COMMAND ${CMAKE_COMMAND} -DCONFIGURATION=$<CONFIG> -P "${REPLACE_SYMBOLS_SCRIPT}"
    COMMENT "Updating symbol map")
endfunction()

