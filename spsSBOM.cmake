#[==[.rst:
******
spsSBOM
******

Software Bill of Materials (SBOM) management for dependency versions.

Provides functions to read dependency versions from a centralized versions.txt
file in the repository root, with fallback support.

File Format (versions.txt)::

  KEY=VALUE
  # Comments start with #
  # Empty lines are ignored

Usage::

  include(spsSBOM)
  sps_get_version(CATCH2_VERSION "v3.5.2")  # Gets version or uses fallback

#]==]

# Global properties are used to store state across function calls within a single
# configure run. They don't persist to disk, so versions.txt is re-read on each
# configure (which CMAKE_CONFIGURE_DEPENDS triggers when the file changes).

#[==[.rst:
.. command:: sps_read_versions_file

  Internal function to read and parse the versions.txt file.

  ::

    sps_read_versions_file(<file_path>)

  ``<file_path>``
    Path to the versions.txt file to parse
#]==]
function(sps_read_versions_file FILE_PATH)
    if(NOT EXISTS "${FILE_PATH}")
        message(STATUS "SBOM: File does not exist: ${FILE_PATH}")
        return()
    endif()

    # Read file content line by line
    file(STRINGS "${FILE_PATH}" _file_lines)

    set(_parsed_count 0)
    set(_parsed_keys "")
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

            # Store in global property for access across function calls
            set_property(GLOBAL PROPERTY "_SPS_SBOM_${_key}" "${_value}")
            list(APPEND _parsed_keys "${_key}")

            math(EXPR _parsed_count "${_parsed_count} + 1")
            message(STATUS "SBOM: Parsed ${_key} = ${_value}")
        else()
            message(WARNING "SBOM: Cannot parse line: ${_line}")
        endif()
    endforeach()

    # Store list of all parsed keys
    set_property(GLOBAL PROPERTY "_SPS_SBOM_KEYS" "${_parsed_keys}")

    if(_parsed_count GREATER 0)
        message(STATUS "SBOM: Successfully parsed ${_parsed_count} version(s) from ${FILE_PATH}")
    endif()
endfunction()

#[==[.rst:
.. command:: sps_get_version

  Get a version number from the centralized versions.txt file.

  ::

    sps_get_version(<variable_name> [<fallback_value>] [REQUIRED])

  ``<variable_name>``
    Name of the version variable (e.g., CATCH2_VERSION)

  ``<fallback_value>``
    Optional fallback value if versions.txt doesn't exist or doesn't define the variable

  ``REQUIRED``
    If specified, a fatal error is raised if the variable is not defined in versions.txt

  Example::

    sps_get_version(CATCH2_VERSION "v3.5.2")
    message(STATUS "Using Catch2 version: ${CATCH2_VERSION}")

    sps_get_version(MYLIB_VERSION REQUIRED)  # Error if not in versions.txt

#]==]
function(sps_get_version VARIABLE_NAME)
    set(_options REQUIRED)
    set(_oneValueArgs "")
    set(_multiValueArgs "")
    cmake_parse_arguments(ARG "${_options}" "${_oneValueArgs}" "${_multiValueArgs}" ${ARGN})

    # Remaining unparsed args become the fallback
    set(FALLBACK_VALUE "")
    if(ARG_UNPARSED_ARGUMENTS)
        list(GET ARG_UNPARSED_ARGUMENTS 0 FALLBACK_VALUE)
    endif()

    # Try to load the versions file only once per configure run
    get_property(_loaded GLOBAL PROPERTY _SPS_VERSIONS_LOADED)
    if(NOT _loaded)
        # Construct path to versions.txt in the repository root
        set(_VERSIONS_FILE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../versions.txt")

        if(EXISTS "${_VERSIONS_FILE}")
            # Make CMake reconfigure when versions.txt changes
            set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${_VERSIONS_FILE}")

            # Parse the versions file (stores in global properties)
            sps_read_versions_file("${_VERSIONS_FILE}")

            set_property(GLOBAL PROPERTY _SPS_VERSIONS_AVAILABLE TRUE)
        else()
            set_property(GLOBAL PROPERTY _SPS_VERSIONS_AVAILABLE FALSE)
            message(STATUS "SBOM: versions.txt not found at ${_VERSIONS_FILE}")
        endif()

        set_property(GLOBAL PROPERTY _SPS_VERSIONS_LOADED TRUE)
    endif()

    # Try to get value from global property
    get_property(_value GLOBAL PROPERTY "_SPS_SBOM_${VARIABLE_NAME}")

    if(_value)
        # Variable found in versions.txt
        set(${VARIABLE_NAME} "${_value}" PARENT_SCOPE)
        message(STATUS "SBOM: Using ${VARIABLE_NAME} = ${_value}")
    elseif(ARG_REQUIRED)
        # REQUIRED specified but variable not found
        message(FATAL_ERROR "SBOM: ${VARIABLE_NAME} not defined in versions.txt (REQUIRED)")
    elseif(FALLBACK_VALUE)
        # Use fallback value
        set(${VARIABLE_NAME} "${FALLBACK_VALUE}" PARENT_SCOPE)
        message(STATUS "SBOM: Using ${VARIABLE_NAME} = ${FALLBACK_VALUE} (fallback)")
    else()
        # No fallback and not required - this is likely a mistake
        message(FATAL_ERROR "SBOM: ${VARIABLE_NAME} not defined and no fallback provided")
    endif()
endfunction()
