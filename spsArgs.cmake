#[==[.rst:
********
spsArgs
********
 args library setup with find/fallback and completion utilities:
  - Try to find args using CONFIG
  - Falls back to FetchContent if not found
  - Provides sps_args_completion() for bash/PowerShell completion setup

 Usage::

   include(spsArgs)

   add_executable(myapp main.cpp)
   target_link_libraries(myapp PRIVATE taywee::args)

   # Optional: set up shell completion as post-build step
   sps_args_completion(myapp)

#]==]

include(spsSBOM)
sps_get_version(ARGS_VERSION "6.4.7")
set(SPS_ARGS_VERSION "${ARGS_VERSION}")

message(STATUS "=== ARGS SEARCH ===")

# Try to find args
find_package(args ${SPS_ARGS_VERSION} QUIET CONFIG NO_MODULE NO_CMAKE_PACKAGE_REGISTRY)

if(args_FOUND)
    message(STATUS "✅ args ${SPS_ARGS_VERSION} found successfully!")
    message(STATUS "   Location: ${args_DIR}")
else()
    message(STATUS "❌ args NOT FOUND")
    message(STATUS "🔨 Building args ${SPS_ARGS_VERSION} from source...")

    include(FetchContent)

    FetchContent_Declare(
        args
        GIT_REPOSITORY https://github.com/Taywee/args.git
        GIT_TAG ${SPS_ARGS_VERSION}
    )

    # Backup and disable tests/examples
    set(SPS_BACKUP_ARGS_BUILD_EXAMPLE ${ARGS_BUILD_EXAMPLE})
    set(SPS_BACKUP_ARGS_BUILD_UNITTESTS ${ARGS_BUILD_UNITTESTS})
    set(ARGS_BUILD_EXAMPLE OFF CACHE BOOL "Build examples" FORCE)
    set(ARGS_BUILD_UNITTESTS OFF CACHE BOOL "Build unit tests" FORCE)

    FetchContent_MakeAvailable(args)

    # Restore
    if(DEFINED SPS_BACKUP_ARGS_BUILD_EXAMPLE)
        set(ARGS_BUILD_EXAMPLE ${SPS_BACKUP_ARGS_BUILD_EXAMPLE} CACHE BOOL "Build examples" FORCE)
    endif()
    if(DEFINED SPS_BACKUP_ARGS_BUILD_UNITTESTS)
        set(ARGS_BUILD_UNITTESTS ${SPS_BACKUP_ARGS_BUILD_UNITTESTS} CACHE BOOL "Build unit tests" FORCE)
    endif()

    message(STATUS "✅ args ${SPS_ARGS_VERSION} built and configured successfully!")
    message(STATUS "   Location: ${args_SOURCE_DIR}")
endif()

#[==[.rst:
.. cmake:command:: sps_args_completion

  Set up shell completion for a target that uses args library::

    sps_args_completion(<target>
        [SYMLINK_DIR <dir>]      # Directory for symlink (default: ${CMAKE_SOURCE_DIR}/bin)
        [BASH]                   # Enable bash completion (default on Linux)
        [POWERSHELL]             # Enable PowerShell completion (default on Windows)
    )

  This adds post-build commands to:
  - Create a symlink to the executable in SYMLINK_DIR
  - Install bash completion script (Linux)
  - Generate PowerShell completion script (Windows)

#]==]
function(sps_args_completion target)
    cmake_parse_arguments(PARSE_ARGV 1 ARG
        "BASH;POWERSHELL"
        "SYMLINK_DIR"
        ""
    )

    # Default symlink directory
    if(NOT ARG_SYMLINK_DIR)
        set(ARG_SYMLINK_DIR "${CMAKE_SOURCE_DIR}/bin")
    endif()

    # Default: bash on Unix, PowerShell on Windows
    if(NOT ARG_BASH AND NOT ARG_POWERSHELL)
        if(UNIX)
            set(ARG_BASH TRUE)
        endif()
        if(WIN32)
            set(ARG_POWERSHELL TRUE)
        endif()
    endif()

    set(SYMLINK_PATH "${ARG_SYMLINK_DIR}/${target}")

    # Create symlink (Unix only - Windows requires admin/developer mode)
    if(UNIX)
        add_custom_command(TARGET ${target} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E make_directory "${ARG_SYMLINK_DIR}"
            COMMAND ${CMAKE_COMMAND} -E create_symlink
                "$<TARGET_FILE:${target}>"
                "${SYMLINK_PATH}"
            COMMENT "Creating symlink: ${ARG_SYMLINK_DIR}/${target}"
        )
    endif()

    # Bash completion (Linux/macOS)
    if(ARG_BASH AND UNIX)
        set(COMPLETION_SCRIPT "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/spsArgsCompletion.bash")
        add_custom_command(TARGET ${target} POST_BUILD
            COMMAND ${COMPLETION_SCRIPT} "$<TARGET_FILE:${target}>" "${SYMLINK_PATH}"
            COMMENT "Installing bash completion for ${target}"
        )
    endif()

    # PowerShell completion (Windows)
    if(ARG_POWERSHELL AND WIN32)
        set(COMPLETION_SCRIPT "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/spsArgsCompletion.ps1")
        add_custom_command(TARGET ${target} POST_BUILD
            COMMAND powershell -ExecutionPolicy Bypass -File "${COMPLETION_SCRIPT}"
                -ExecutablePath "$<TARGET_FILE:${target}>"
            COMMENT "Installing PowerShell completion for ${target}"
        )
    endif()
endfunction()
