#[==[.rst:
.. cmake:command:: spsSetDebugPostfix

  Set a debug postfix on a target for debug builds::

    spsSetDebugPostfix(<target> <postfix>)

  Adds the specified postfix (e.g., "d") to the target's output filename
  in Debug builds. Handles both multi-config (Visual Studio, Xcode) and
  single-config generators. Skips INTERFACE library targets.

#]==]
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

#[==[.rst:
.. cmake:command:: sps_copy_runtime_dlls

  Copy all runtime DLLs for a target to its output directory::

    sps_copy_runtime_dlls(<target>)

  On Windows with shared libraries, this adds a post-build command to copy
  all dependent DLLs next to the executable. Does nothing on other platforms.
  Requires CMake 3.21+ for TARGET_RUNTIME_DLLS generator expression.

#]==]
function(sps_copy_runtime_dlls target)
    if(WIN32)
        # Use $<IF:...> to run 'cmake -E true' (no-op) when DLL list is empty,
        # avoiding errors from copy_if_different with no source files
        add_custom_command(TARGET ${target} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E
                "$<IF:$<BOOL:$<TARGET_RUNTIME_DLLS:${target}>>,copy_if_different,true>"
                $<TARGET_RUNTIME_DLLS:${target}>
                "$<$<BOOL:$<TARGET_RUNTIME_DLLS:${target}>>:$<TARGET_FILE_DIR:${target}>>"
            COMMAND_EXPAND_LISTS
            COMMENT "Copying runtime DLLs for ${target}"
        )
    endif()
endfunction()
