#[==[.rst:
*********
spsNode
*********
#
# Setting for Node in Emscripten projects
#]==]

include(spsMultiConfiguration)

function(_sps_generate_initialize_node_script target_name output_file)
  # Check if single or multi-configuration
  if (CMAKE_CONFIGURATION_TYPES)
    set(CONFIG "\${CONFIGURATION}")
  else()
    set(CONFIG)
  endif()
  set(package_files
    package-lock.json
    package.json
  )
  # Write the header to the script
  file(WRITE "${output_file}" "# Auto-generated script for copying package.json and package-lock.json and initializing node\n\n")
  foreach (package_file ${package_files})
    if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${package_file}")
      file(APPEND "${output_file}" "message(STATUS \"Copying ${package_file} to ${CMAKE_CURRENT_BINARY_DIR}/\${CONFIGURATION}/${package_file}\")\n")
      file(APPEND "${output_file}"
        "execute_process(\n
          COMMAND \${CMAKE_COMMAND} -E copy_if_different \"${CMAKE_CURRENT_SOURCE_DIR}/${package_file}\" \"${CMAKE_CURRENT_BINARY_DIR}/${CONFIG}/${package_file}\"\n
     )\n")
    endif()
  endforeach()

  if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/package-lock.json")
    file(APPEND "${output_file}"
      "execute_process(\n
        COMMAND npm ci\n
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${CONFIG}\n
      )\n")
  elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/package.json")
    file(APPEND "${output_file}"
      "execute_process(\n
        COMMAND npm install\n
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${CONFIG}\n
      )\n")
  endif()
  message(STATUS "Generated script: ${output_file}")
endfunction()

function(sps_initialize_node target)
  set(COPY_INITIALIZE_NODE_SCRIPT "${CMAKE_CURRENT_BINARY_DIR}/${target}_initialize_node_script.cmake")
  _sps_generate_initialize_node_script(${target} ${COPY_INITIALIZE_NODE_SCRIPT} "${GENERATED_SCRIPT}")
  add_custom_target(${target}InitializeNode ALL
    DEPENDS ${COPY_INITIALIZE_NODE_SCRIPT}
    COMMAND ${CMAKE_COMMAND} -DCONFIGURATION=$<CONFIG> -P "${COPY_INITIALIZE_NODE_SCRIPT}"
    COMMENT "Intiailizing Node")
  add_dependencies(${target} ${target}InitializeNode)
endfunction()

