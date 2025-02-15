#[==[.rst:
*********
spsCopyFiles
*********
#
#]==]

#[==[.rst:

.. cmake:command:: _sps_generate_copy_script

  |module-internal|

  The :cmake:command:`_sps_generate_copy_script` function is provided to assist in
  copying files to output directory. It handles single and multi-configuration setups

  .. code-block:: cmake
    _sps_generate_copy_script(
      TARGET_NAME                   <target>
      INPUT_FILES                   <files>
      OUTPUT_FILE                   <script for copying>)
#]==]
function(_sps_generate_copy_script target_name input_files output_file)
  # Handle single and multi-configuration builds
  if (CMAKE_CONFIGURATION_TYPES)
    set(CONFIG "\${CONFIGURATION}")
  else()
    set(CONFIG)
  endif()

  # Write the header to the script
  file(WRITE "${output_file}" "# Auto-generated script for copying files\n\n")

  # Write commands to copy each JavaScript file
  foreach(input_file ${input_files})
    #get_filename_component(file_name_without_path "${input_file}" NAME)
    file(APPEND "${output_file}" "message(STATUS \"Copying ${input_file} to ${CMAKE_CURRENT_BINARY_DIR}/\${CONFIGURATION}/${input_file}\")\n")
    file(APPEND "${output_file}"
         "execute_process(COMMAND\n \${CMAKE_COMMAND} -E copy_if_different \"${CMAKE_CURRENT_SOURCE_DIR}/${input_file}\" \"${CMAKE_CURRENT_BINARY_DIR}/${CONFIG}/${input_file}\")\n")
  endforeach()
  message(STATUS "Generated script: ${output_file}")
endfunction()

#[==[.rst:

.. cmake:command:: sps_copy_files

  The :cmake:command:`sps_copy_files is provided for copying files to
  output directory. It handles single and multi-configuration setups
  and the copying is done during build. Note, this runs independently of
  the target

  .. code-block:: cmake
    sps_copy_files(
      TARGET_NAME
      INPUT_FILES                   <files>)
#]==]
function(sps_copy_files target postfix input_files)
  if (NOT target)
    message(FATAL_ERROR "The 'sps_copy_files' function requires a target.")
  endif()
  # Unique file name
  set(COPY_FILES_SCRIPT "${CMAKE_CURRENT_BINARY_DIR}/${target_name}_copy_${postfix}.cmake")

  _sps_generate_copy_script(${target} "${input_files}" ${COPY_FILES_SCRIPT})
  add_custom_target("${target}_${postfix}" ALL
    DEPENDS ${COPY_FILES_SCRIPT}
    COMMAND ${CMAKE_COMMAND} -DCONFIGURATION=$<CONFIG> -P "${COPY_FILES_SCRIPT}"
    COMMENT "Copying ${postfix} files to the appropriate output directory"
  )
  add_dependencies(${target} "${target}_${postfix}")
endfunction()
