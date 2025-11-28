# SetupCppCheck.cmake
#
# Sets up cppcheck static analysis for the project.
# Requires CMAKE_EXPORT_COMPILE_COMMANDS to be ON for best results.
#
# Creates a 'cppcheck' target that runs static analysis on the source tree.
#
# Options:
#   CPPCHECK_ENABLE        - Enable/disable cppcheck integration (default: ON if found)
#   CPPCHECK_SUPPRESSIONS  - Path to suppressions file
#   CPPCHECK_EXTRA_ARGS    - Additional arguments to pass to cppcheck

find_program(CPPCHECK_EXECUTABLE
  NAMES cppcheck
  DOC "Path to cppcheck executable"
)

if(CPPCHECK_EXECUTABLE)
  # Get cppcheck version
  execute_process(
    COMMAND ${CPPCHECK_EXECUTABLE} --version
    OUTPUT_VARIABLE CPPCHECK_VERSION_OUTPUT
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  string(REGEX MATCH "[0-9]+\\.[0-9]+" CPPCHECK_VERSION "${CPPCHECK_VERSION_OUTPUT}")
  message(STATUS "Found cppcheck: ${CPPCHECK_EXECUTABLE} (version ${CPPCHECK_VERSION})")

  option(CPPCHECK_ENABLE "Enable cppcheck static analysis" ON)

  if(CPPCHECK_ENABLE)
    # Build the cppcheck command arguments
    set(CPPCHECK_ARGS
      --enable=warning,style,performance,portability
      --suppress=missingIncludeSystem
      --inline-suppr
      --quiet
      --error-exitcode=0
    )

    # Use compile_commands.json if available
    if(CMAKE_EXPORT_COMPILE_COMMANDS)
      list(APPEND CPPCHECK_ARGS
        --project=${CMAKE_BINARY_DIR}/compile_commands.json
      )
    endif()

    # Add suppressions file if specified
    if(CPPCHECK_SUPPRESSIONS AND EXISTS "${CPPCHECK_SUPPRESSIONS}")
      list(APPEND CPPCHECK_ARGS --suppressions-list=${CPPCHECK_SUPPRESSIONS})
    endif()

    # Add any extra arguments
    if(CPPCHECK_EXTRA_ARGS)
      list(APPEND CPPCHECK_ARGS ${CPPCHECK_EXTRA_ARGS})
    endif()

    # Create the cppcheck target
    add_custom_target(cppcheck
      COMMAND ${CPPCHECK_EXECUTABLE} ${CPPCHECK_ARGS}
      WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
      COMMENT "Running cppcheck static analysis..."
      VERBATIM
    )

    # Optionally set CMAKE_CXX_CPPCHECK for automatic analysis during build
    # Uncomment to enable automatic cppcheck on every build:
    # set(CMAKE_CXX_CPPCHECK
    #   ${CPPCHECK_EXECUTABLE}
    #   --enable=warning
    #   --suppress=missingIncludeSystem
    #   --inline-suppr
    #   --quiet
    # )
  endif()
else()
  message(STATUS "cppcheck not found - static analysis target disabled")
endif()
