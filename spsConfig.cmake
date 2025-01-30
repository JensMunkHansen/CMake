#[==[.rst:
*********
spsConfig
*********
  Generate xxxx.h from xxx.h.in. The function configure_file generalized to support multi configurations.

  sps_config(TARGET config.h.in @ONLY)

  Support with/without @ONLY
#]==]
function(sps_config target input_file)
    # Extract filename without extension
    get_filename_component(output_file "${input_file}" NAME_WE)
    set(output_file "${output_file}.h")
    # Detect whether @ONLY was passed
    set(USE_AT_ONLY OFF)
    foreach(arg ${ARGN})
        if(arg STREQUAL "@ONLY")
            set(USE_AT_ONLY ON)
        endif()
    endforeach()

    # Get the target-specific binary directory
    get_property(target_binary_dir TARGET ${target} PROPERTY BINARY_DIR)

    if (CMAKE_CONFIGURATION_TYPES)
      # Generate config files per configuration
      foreach(config ${CMAKE_CONFIGURATION_TYPES})
        message(${config})
          set(CONFIG_FILE_PATH "${target_binary_dir}/${config}/${output_file}")
      
          if(USE_AT_ONLY)
              configure_file("${input_file}" "${CONFIG_FILE_PATH}" @ONLY)
          else()
              configure_file("${input_file}" "${CONFIG_FILE_PATH}")
          endif()
      endforeach()
      # Add include directory for the target
      target_include_directories(${target} PRIVATE
        "$<BUILD_INTERFACE:${target_binary_dir}/$<CONFIG>>")
    else()
      set(CONFIG_FILE_PATH "${CMAKE_CURRENT_BINARY_DIR}/${output_file}")
      configure_file("${input_file}" "${CONFIG_FILE_PATH}" @ONLY)
      target_include_directories(${target} PRIVATE
        "$<BUILD_INTERFACE:${target_binary_dir}"
      )    
    endif()
endfunction()
