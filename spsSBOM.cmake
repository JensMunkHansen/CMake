#[==[.rst:
*********
spsSBOM
*********
Software Bill of Materials (SBOM) management for dependency versions.

Provides functions to read dependency versions from a centralized versions.txt
file in the repository root, with fallback support for projects without the file.

File Format (versions.txt):
  KEY=VALUE
  # Comments start with #
  # Empty lines are ignored

Usage:
  include(spsSBOM)
  sps_get_version(CATCH2_VERSION "3.5.2")  # Gets version or uses fallback
#]==]

# Internal cache to avoid reading the versions file multiple times
if(NOT DEFINED _SPS_VERSIONS_LOADED)
    set(_SPS_VERSIONS_LOADED FALSE CACHE INTERNAL "Whether versions.txt has been loaded")
    set(_SPS_VERSIONS_AVAILABLE FALSE CACHE INTERNAL "Whether versions.txt file exists")
endif()

#[==[.rst:
.. command:: sps_read_versions_file

  Internal function to read and parse the versions.txt file.

  ::

    sps_read_versions_file(<file_path>)

  ``<file_path>``
    Path to the versions.txt file to parse

  The function will:
    1. Read the file line by line
    2. Skip empty lines and comments (lines starting with #)
    3. Parse KEY=VALUE pairs
    4. Set variables in PARENT_SCOPE with the parsed values

  File format:
    - One KEY=VALUE pair per line
    - Lines starting with # are comments
    - Empty lines are ignored
    - Whitespace around = is allowed (KEY = VALUE is valid)
#]==]
function(sps_read_versions_file FILE_PATH)
    if(NOT EXISTS "${FILE_PATH}")
        message(STATUS "📦 SBOM: File does not exist: ${FILE_PATH}")
        return()
    endif()

    # Read file content line by line
    file(STRINGS "${FILE_PATH}" _file_lines)

    set(_parsed_count 0)
    foreach(_line IN LISTS _file_lines)
        # Skip empty lines
        if("${_line}" STREQUAL "")
            continue()
        endif()

        # Skip comments (lines starting with #)
        string(REGEX MATCH "^[ \t]*#" _is_comment "${_line}")
        if(_is_comment)
            continue()
        endif()

        # Parse KEY=VALUE format (allowing whitespace around =)
        string(REGEX MATCH "^[ \t]*([A-Za-z0-9_]+)[ \t]*=[ \t]*(.+)[ \t]*$" _matched "${_line}")

        if(_matched)
            set(_key "${CMAKE_MATCH_1}")
            set(_value "${CMAKE_MATCH_2}")

            # Trim trailing whitespace from value
            string(STRIP "${_value}" _value)

            # Set the variable in parent scope
            set(${_key} "${_value}" PARENT_SCOPE)

            math(EXPR _parsed_count "${_parsed_count} + 1")
            message(STATUS "📦 SBOM: Parsed ${_key} = ${_value}")
        else()
            message(WARNING "📦 SBOM: Cannot parse line: ${_line}")
        endif()
    endforeach()

    if(_parsed_count GREATER 0)
        message(STATUS "📦 SBOM: Successfully parsed ${_parsed_count} version(s) from ${FILE_PATH}")
    endif()
endfunction()

#[==[.rst:
.. command:: sps_get_version

  Get a version number from the centralized versions.txt file.

  ::

    sps_get_version(<variable_name> [<fallback_value>])

  ``<variable_name>``
    Name of the version variable (e.g., CATCH2_VERSION)

  ``<fallback_value>``
    Optional fallback value if versions.txt doesn't exist or doesn't define the variable

  The function will:
    1. Look for versions.txt in the parent directory (repository root)
    2. If found, parse it and use the version defined there
    3. If not found or variable not defined, use the fallback value
    4. Set the variable in the PARENT_SCOPE

  Example:
    sps_get_version(CATCH2_VERSION "3.5.2")
    message(STATUS "Using Catch2 version: ${CATCH2_VERSION}")
#]==]
function(sps_get_version VARIABLE_NAME)
    set(FALLBACK_VALUE "")
    if(ARGC GREATER 1)
        set(FALLBACK_VALUE "${ARGV1}")
    endif()

    # Try to load the versions file only once
    if(NOT _SPS_VERSIONS_LOADED)
        # Construct path to versions.txt in the repository root
        # Since this file is in CMake/, the parent directory is the repo root
        set(_VERSIONS_FILE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../versions.txt")

        if(EXISTS "${_VERSIONS_FILE}")
            # Parse the versions file
            sps_read_versions_file("${_VERSIONS_FILE}")

            # Propagate all parsed variables to this scope
            file(STRINGS "${_VERSIONS_FILE}" _file_lines)
            foreach(_line IN LISTS _file_lines)
                string(REGEX MATCH "^[ \t]*([A-Za-z0-9_]+)[ \t]*=[ \t]*(.+)[ \t]*$" _matched "${_line}")
                if(_matched)
                    set(_key "${CMAKE_MATCH_1}")
                    set(_value "${CMAKE_MATCH_2}")
                    string(STRIP "${_value}" _value)
                    set(${_key} "${_value}" PARENT_SCOPE)
                endif()
            endforeach()

            set(_SPS_VERSIONS_AVAILABLE TRUE CACHE INTERNAL "Whether versions.txt file exists")
        else()
            set(_SPS_VERSIONS_AVAILABLE FALSE CACHE INTERNAL "Whether versions.txt file exists")
            message(STATUS "📦 SBOM: versions.txt not found at ${_VERSIONS_FILE}")
        endif()

        set(_SPS_VERSIONS_LOADED TRUE CACHE INTERNAL "Whether versions.txt has been loaded")
    endif()

    # Check if the variable is defined (either from versions.txt or already set)
    if(DEFINED ${VARIABLE_NAME})
        # Variable is defined, propagate it to parent scope
        set(${VARIABLE_NAME} "${${VARIABLE_NAME}}" PARENT_SCOPE)
        message(STATUS "📦 SBOM: Using ${VARIABLE_NAME} = ${${VARIABLE_NAME}}")
    elseif(FALLBACK_VALUE)
        # Use fallback value
        set(${VARIABLE_NAME} "${FALLBACK_VALUE}" PARENT_SCOPE)
        message(STATUS "📦 SBOM: Using ${VARIABLE_NAME} = ${FALLBACK_VALUE} (fallback)")
    else()
        message(WARNING "📦 SBOM: ${VARIABLE_NAME} not defined and no fallback provided")
    endif()
endfunction()
