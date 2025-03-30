function(spsSetDebugPostfix target postfix)
    # Skip INTERFACE targets, which can't have output files
    get_target_property(type ${target} TYPE)
    if(type STREQUAL "INTERFACE_LIBRARY")
        return()
    endif()

    # Apply only if multi-config (e.g., Visual Studio, Xcode, Ninja Multi-Config)
    if(CMAKE_CONFIGURATION_TYPES)
        set_target_properties(${target} PROPERTIES DEBUG_POSTFIX "${postfix}")
    # For single-config, only apply in Debug
    elseif(CMAKE_BUILD_TYPE STREQUAL "Debug")
        set_target_properties(${target} PROPERTIES DEBUG_POSTFIX "${postfix}")
    endif()
endfunction()
