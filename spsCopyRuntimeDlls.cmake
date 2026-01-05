#[==[.rst:
*******************
spsCopyRuntimeDlls
*******************

Copy runtime DLLs to executable directory on Windows (shared library builds).

Usage::

  include(spsCopyRuntimeDlls)

  add_executable(myapp main.cpp)
  target_link_libraries(myapp PRIVATE mylib)

  sps_copy_runtime_dlls(myapp)

Requires CMake 3.21+ for TARGET_RUNTIME_DLLS generator expression.

#]==]

#[==[.rst:
.. cmake:command:: sps_copy_runtime_dlls

  Copy all runtime DLLs for a target to its output directory::

    sps_copy_runtime_dlls(<target>)

  On Windows with shared libraries, this adds a post-build command to copy
  all dependent DLLs next to the executable. Does nothing on other platforms.

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
