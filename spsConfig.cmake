#[==[.rst:
*********
spsConfig
*********
  Generate xxxx from xxx.in. The function configure_file generalized to support multi configurations.

  sps_config(TARGET config.h.in @ONLY)

  Support with/without @ONLY
#]==]
function(sps_configure_file target input_file output_file)
    # Ensure the target exists
    if(NOT TARGET ${target})
        message(FATAL_ERROR "sps_config: Target '${target}' does not exist.")
    endif()

    # Detect whether @ONLY was passed
    set(USE_AT_ONLY OFF)
    foreach(arg ${ARGN})
        if(arg STREQUAL "@ONLY")
            set(USE_AT_ONLY ON)
        endif()
    endforeach()

    # Ensure output file does not retain ".in"
    get_filename_component(output_filename "${output_file}" NAME)
    string(REPLACE ".in" "" output_filename "${output_filename}")

    # Get the target's binary directory
    get_property(target_binary_dir TARGET ${target} PROPERTY BINARY_DIR)

    # Check if this is a multi-config generator (Visual Studio, Xcode, Ninja Multi-Config)
    if(CMAKE_CONFIGURATION_TYPES)
        # Multi-config generator: generate files per configuration
        foreach(config ${CMAKE_CONFIGURATION_TYPES})
            set(CONFIG_FILE_PATH "${target_binary_dir}/${config}/${output_filename}")

            if(USE_AT_ONLY)
                configure_file("${input_file}" "${CONFIG_FILE_PATH}" @ONLY)
            else()
                configure_file("${input_file}" "${CONFIG_FILE_PATH}")
            endif()
        endforeach()

        # Add include directory for multi-config generators
        target_include_directories(${target} PRIVATE
            "$<BUILD_INTERFACE:${target_binary_dir}/$<CONFIG>>"
        )
    else()
        # Single-config generator: just generate a single file
        set(CONFIG_FILE_PATH "${target_binary_dir}/${output_filename}")

        if(USE_AT_ONLY)
            configure_file("${input_file}" "${CONFIG_FILE_PATH}" @ONLY)
        else()
            configure_file("${input_file}" "${CONFIG_FILE_PATH}")
        endif()

        # Add include directory for single-config generators
        target_include_directories(${target} PRIVATE
            "$<BUILD_INTERFACE:${target_binary_dir}>"
        )
    endif()
endfunction()
