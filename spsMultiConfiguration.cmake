
function(sps_generate_copy_script target_name input_files output_file)
  # Write the header to the script
  file(WRITE "${output_file}" "# Auto-generated script for copying JavaScript files\n\n")
  if (CMAKE_CONFIGURATION_TYPES)
    set(CONFIG "\${CONFIGURATION}")
  else()
    set(CONFIG)
  endif()
  # Write commands to copy each JavaScript file
  foreach(input_file ${input_files})
    file(APPEND "${output_file}" "message(STATUS \"Copying ${input_file} to ${CMAKE_CURRENT_BINARY_DIR}/\${CONFIGURATION}/${input_file}\")\n")
    file(APPEND "${output_file}"
         "execute_process(COMMAND \${CMAKE_COMMAND} -E copy_if_different \"${CMAKE_CURRENT_SOURCE_DIR}/${input_file}\" \"${CMAKE_CURRENT_BINARY_DIR}/${CONFIG}/${input_file}\")\n")
  endforeach()

  message(STATUS "Generated script: ${output_file}")
endfunction()

function(sps_generate_initialize_node_script target_name output_file)
  # Write the header to the script
  file(WRITE "${output_file}" "# Auto-generated script for copying package.json and package-lock.json and initializing node\n\n")
  if (CMAKE_CONFIGURATION_TYPES)
    set(CONFIG "\${CONFIGURATION}")
  else()
    set(CONFIG)
  endif()

  if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/package-lock.json")
    file(APPEND "${output_file}" "message(STATUS \"Copying package-lock.json to ${CMAKE_CURRENT_BINARY_DIR}/\${CONFIGURATION}/package-lock.json\")\n")
    file(APPEND "${output_file}" "execute_process(COMMAND \${CMAKE_COMMAND} -E copy_if_different \"${CMAKE_CURRENT_SOURCE_DIR}/package-lock.json\" \"${CMAKE_CURRENT_BINARY_DIR}/${CONFIG}/package-lock.json\")\n")
    file(APPEND "${output_file}" "
      execute_process(\n
        COMMAND npm ci\n
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${CONFIG}\n
      )\n")
  elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/package.json")
    file(APPEND "${output_file}" "message(STATUS \"Copying package.json to ${CMAKE_CURRENT_BINARY_DIR}/\${CONFIGURATION}/package.json\")\n")
    file(APPEND "${output_file}" "execute_process(COMMAND \${CMAKE_COMMAND} -E copy_if_different \"${CMAKE_CURRENT_SOURCE_DIR}/package.json\" \"${CMAKE_CURRENT_BINARY_DIR}/${CONFIG}/package.json\")\n")
    file(APPEND "${output_file}" 
      "execute_process(\n
        COMMAND npm install\n
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${CONFIG}\n
      )\n")
  endif()
  message(STATUS "Generated script: ${output_file}")
endfunction()


