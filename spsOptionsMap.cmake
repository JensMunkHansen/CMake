# options_map.cmake

# options_map.cmake
# Initialize OPTIONS_MAP if it hasn't been defined
if(NOT DEFINED OPTIONS_MAP)
    set(OPTIONS_MAP "" CACHE INTERNAL "Centralized options map")
endif()

function(add_options_mapping ACTIVE_CUSTOM_CONFIG PLATFORM COMPILE_OPTIONS LINK_OPTIONS DEBUG_OPTIONS)
    # Ensure clean ACTIVE_CUSTOM_CONFIG and PLATFORM
    string(STRIP "${ACTIVE_CUSTOM_CONFIG}" ACTIVE_CUSTOM_CONFIG)
    string(STRIP "${PLATFORM}" PLATFORM)
    string(REPLACE ";" "_" mapping_key "${ACTIVE_CUSTOM_CONFIG}_${PLATFORM}")

    # Cache compile options
    if(NOT "${COMPILE_OPTIONS}" STREQUAL "")
        if(DEFINED COMPILE_OPTIONS_DICT_${mapping_key})
            list(APPEND COMPILE_OPTIONS_DICT_${mapping_key} ${COMPILE_OPTIONS})
            list(REMOVE_DUPLICATES COMPILE_OPTIONS_DICT_${mapping_key})
        else()
            set(COMPILE_OPTIONS_DICT_${mapping_key} "${COMPILE_OPTIONS}")
        endif()
        set(COMPILE_OPTIONS_DICT_${mapping_key} "${COMPILE_OPTIONS_DICT_${mapping_key}}" CACHE INTERNAL "Compile options for ${mapping_key}")
    endif()

    # Cache link options
    if(NOT "${LINK_OPTIONS}" STREQUAL "")
        if(DEFINED LINK_OPTIONS_DICT_${mapping_key})
            list(APPEND LINK_OPTIONS_DICT_${mapping_key} ${LINK_OPTIONS})
            list(REMOVE_DUPLICATES LINK_OPTIONS_DICT_${mapping_key})
        else()
            set(LINK_OPTIONS_DICT_${mapping_key} "${LINK_OPTIONS}")
        endif()
        set(LINK_OPTIONS_DICT_${mapping_key} "${LINK_OPTIONS_DICT_${mapping_key}}" CACHE INTERNAL "Link options for ${mapping_key}")
    endif()

    # Cache debug options
    if(NOT "${DEBUG_OPTIONS}" STREQUAL "")
        if(DEFINED DEBUG_OPTIONS_DICT_${mapping_key})
            list(APPEND DEBUG_OPTIONS_DICT_${mapping_key} ${DEBUG_OPTIONS})
            list(REMOVE_DUPLICATES DEBUG_OPTIONS_DICT_${mapping_key})
        else()
            set(DEBUG_OPTIONS_DICT_${mapping_key} "${DEBUG_OPTIONS}")
        endif()
        set(DEBUG_OPTIONS_DICT_${mapping_key} "${DEBUG_OPTIONS_DICT_${mapping_key}}" CACHE INTERNAL "Debug options for ${mapping_key}")
    endif()

    # Debugging output
    message(STATUS "Updated ${mapping_key}:")
    message(STATUS "  Compile Options: ${COMPILE_OPTIONS_DICT_${mapping_key}}")
    message(STATUS "  Link Options: ${LINK_OPTIONS_DICT_${mapping_key}}")
    message(STATUS "  Debug Options: ${DEBUG_OPTIONS_DICT_${mapping_key}}")
endfunction()

add_options_mapping(
    "DebugNative" "Emscripten"
    "-g3;-matomics"    # Compile Options
    ""                 # Link Options
    "-gsource-map"     # Debug Options
)


add_options_mapping(
    "Release" "Emscripten"
    "-O3;-matomics"
    ""
    ""
)

add_options_mapping(
    "Release" "Native"
    "-DHELLO"
    ""
    ""
)

function(get_options ACTIVE_CUSTOM_CONFIG PLATFORM OUT_COMPILE_OPTIONS OUT_LINK_OPTIONS OUT_DEBUG_OPTIONS)
    # Ensure clean ACTIVE_CUSTOM_CONFIG and PLATFORM
    string(STRIP "${ACTIVE_CUSTOM_CONFIG}" ACTIVE_CUSTOM_CONFIG)
    string(STRIP "${PLATFORM}" PLATFORM)
    string(REPLACE ";" "_" mapping_key "${ACTIVE_CUSTOM_CONFIG}_${PLATFORM}")

    # Retrieve compile options
    if(DEFINED COMPILE_OPTIONS_DICT_${mapping_key})
        set(compile_options "${COMPILE_OPTIONS_DICT_${mapping_key}}")
    else()
        set(compile_options "")
    endif()

    # Retrieve link options
    if(DEFINED LINK_OPTIONS_DICT_${mapping_key})
        set(link_options "${LINK_OPTIONS_DICT_${mapping_key}}")
    else()
        set(link_options "")
    endif()

    # Retrieve debug options
    if(DEFINED DEBUG_OPTIONS_DICT_${mapping_key})
        set(debug_options "${DEBUG_OPTIONS_DICT_${mapping_key}}")
    else()
        set(debug_options "")
    endif()

    # Debugging output
    message(STATUS "Resolved ACTIVE_CUSTOM_CONFIG: '${ACTIVE_CUSTOM_CONFIG}'")
    message(STATUS "Found options for ${mapping_key}:")
    message(STATUS "  Compile Options: ${compile_options}")
    message(STATUS "  Link Options: ${link_options}")
    message(STATUS "  Debug Options: ${debug_options}")

    # Set the outputs
    set(${OUT_COMPILE_OPTIONS} "${compile_options}" PARENT_SCOPE)
    set(${OUT_LINK_OPTIONS} "${link_options}" PARENT_SCOPE)
    set(${OUT_DEBUG_OPTIONS} "${debug_options}" PARENT_SCOPE)
endfunction()
