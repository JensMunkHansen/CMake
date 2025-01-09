# CustomConfig.cmake
# Handles Emscripten-specific logic and configuration mapping for single- and multiconfiguration generators.
# Exposes unified variables and functions for clean usage in CMakeLists.txt.

# Determine if the generator supports multiple configurations
function(setup_custom_config_mapping)
    if(CMAKE_C_COMPILER MATCHES "emcc")
        set(IS_EMSCRIPTEN TRUE)
    else()
        set(IS_EMSCRIPTEN FALSE)
    endif()

    if(IS_EMSCRIPTEN)
        set(CUSTOM_CONFIG_MAP)
        list(APPEND CUSTOM_CONFIG_MAP "Debug=DebugNative")
        list(APPEND CUSTOM_CONFIG_MAP "Release=Release")
        list(APPEND CUSTOM_CONFIG_MAP "MinSizeRel=MinSizeClosureRel")
        list(APPEND CUSTOM_CONFIG_MAP "RelWithDebInfo=RelWithSourceMaps")
    else()
        set(CUSTOM_CONFIG_MAP)
        list(APPEND CUSTOM_CONFIG_MAP "Debug=Debug")
        list(APPEND CUSTOM_CONFIG_MAP "Release=Release")
        list(APPEND CUSTOM_CONFIG_MAP "MinSizeRel=MinSizeRel")
        list(APPEND CUSTOM_CONFIG_MAP "RelWithDebInfo=RelWithDebInfo")
    endif()

    # Cache individual mappings for each configuration
    foreach(mapping IN LISTS CUSTOM_CONFIG_MAP)
        string(REPLACE "=" ";" mapping_parts "${mapping}")
        list(GET mapping_parts 0 standard_config)
        list(GET mapping_parts 1 custom_config)

        # Define variables like XXX_Debug, XXX_Release
        set(${PROJECT_NAME}_CUSTOM_CONFIG_${standard_config} "${custom_config}" CACHE INTERNAL "Custom mapping for ${standard_config}")
        set(${PROJECT_NAME}_${custom_config} "${custom_config}" CACHE INTERNAL "Predefined configuration for ${custom_config}")

        message(STATUS "Mapped '${standard_config}' to '${custom_config}'")
    endforeach()
endfunction()

function(determine_active_config OUT_VAR)
    setup_custom_config_mapping()

    if(CMAKE_CONFIGURATION_TYPES)
        # Multi-Configuration Generators: Define a mapping for all configurations
        set(ACTIVE_CONFIG_MAP "")
        foreach(config ${CMAKE_CONFIGURATION_TYPES})
            set(mapped_config "${${PROJECT_NAME}_CUSTOM_CONFIG_${config}}")
            if(mapped_config)
                list(APPEND ACTIVE_CONFIG_MAP "${config}=${mapped_config}")
            else()
                message(FATAL_ERROR "No mapping for configuration: ${config}")
            endif()
        endforeach()

        # Expand all configurations into a mapping table
        set(${OUT_VAR} "${ACTIVE_CONFIG_MAP}" CACHE INTERNAL "Active custom configuration map for multi-config generators")
        message(STATUS "Generated ACTIVE_CUSTOM_CONFIG map: ${ACTIVE_CONFIG_MAP}")
    else()
        # Single-Configuration Generators: Resolve immediately
        set(mapped_config "${${PROJECT_NAME}_CUSTOM_CONFIG_${CMAKE_BUILD_TYPE}}")
        if(NOT mapped_config)
            message(FATAL_ERROR "Unsupported CMAKE_BUILD_TYPE: '${CMAKE_BUILD_TYPE}'")
        endif()

        set(${OUT_VAR} "${mapped_config}" CACHE STRING "Active custom configuration for single-config generators")
        message(STATUS "Resolved ACTIVE_CUSTOM_CONFIG: '${mapped_config}'")
    endif()
endfunction()
