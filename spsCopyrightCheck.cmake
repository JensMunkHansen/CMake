#[=======================================================================[.rst:
spsCopyrightCheck
-----------------

Check that source files contain required copyright headers.

This module provides functions to verify that source files contain
the required SPDX license identifier and copyright notice.

Functions
^^^^^^^^^

.. cmake:command:: sps_check_copyright

  Check files for copyright headers::

    sps_check_copyright(
      FILES <file1> [<file2> ...]
      [COPYRIGHT_PATTERN <regex>]
      [LICENSE_PATTERN <regex>]
      [EXCLUDE <pattern1> [<pattern2> ...]]
    )

  ``FILES``
    List of files or glob patterns to check.

  ``COPYRIGHT_PATTERN``
    Regex pattern for copyright line. Default: "Copyright.*Jens Munk Hansen"

  ``LICENSE_PATTERN``
    Regex pattern for license line. Default: "SPDX-License-Identifier:"

  ``EXCLUDE``
    Patterns to exclude from checking.

.. cmake:command:: sps_add_copyright_check_target

  Add a build target that checks copyright headers::

    sps_add_copyright_check_target(
      TARGET <target_name>
      DIRECTORIES <dir1> [<dir2> ...]
      [EXTENSIONS <ext1> [<ext2> ...]]
      [COPYRIGHT_PATTERN <regex>]
      [LICENSE_PATTERN <regex>]
      [EXCLUDE <pattern1> [<pattern2> ...]]
      [ALL]
    )

  ``TARGET``
    Name of the custom target to create.

  ``DIRECTORIES``
    Directories to search for source files.

  ``EXTENSIONS``
    File extensions to check. Default: h;hpp;c;cpp;cxx

  ``ALL``
    Add target to the default build (makes build fail on missing headers).

#]=======================================================================]

include_guard(GLOBAL)

# Script that checks a single file for copyright header
set(_SPS_COPYRIGHT_CHECK_SCRIPT [=[
import sys
import re

def check_file(filepath, copyright_pattern, license_pattern):
    try:
        with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
            # Read first 20 lines (header should be at top)
            header_lines = []
            for i, line in enumerate(f):
                if i >= 20:
                    break
                header_lines.append(line)
            header = ''.join(header_lines)
    except Exception as e:
        print(f"ERROR: Cannot read {filepath}: {e}", file=sys.stderr)
        return False

    has_copyright = bool(re.search(copyright_pattern, header))
    has_license = bool(re.search(license_pattern, header))

    if not has_copyright or not has_license:
        missing = []
        if not has_license:
            missing.append("SPDX-License-Identifier")
        if not has_copyright:
            missing.append("Copyright notice")
        print(f"{filepath}: Missing {', '.join(missing)}")
        return False
    return True

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: script.py <copyright_pattern> <license_pattern> <file1> [file2 ...]", file=sys.stderr)
        sys.exit(1)

    copyright_pattern = sys.argv[1]
    license_pattern = sys.argv[2]
    files = sys.argv[3:]

    failed = []
    for f in files:
        if not check_file(f, copyright_pattern, license_pattern):
            failed.append(f)

    if failed:
        print(f"\n{len(failed)} file(s) missing copyright header", file=sys.stderr)
        sys.exit(1)
    sys.exit(0)
]=])

function(sps_add_copyright_check_target)
  set(options ALL)
  set(oneValueArgs TARGET COPYRIGHT_PATTERN LICENSE_PATTERN)
  set(multiValueArgs DIRECTORIES EXTENSIONS EXCLUDE)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if(NOT ARG_TARGET)
    message(FATAL_ERROR "sps_add_copyright_check_target: TARGET is required")
  endif()

  if(NOT ARG_DIRECTORIES)
    message(FATAL_ERROR "sps_add_copyright_check_target: DIRECTORIES is required")
  endif()

  # Defaults
  if(NOT ARG_EXTENSIONS)
    set(ARG_EXTENSIONS h hpp c cpp cxx)
  endif()

  if(NOT ARG_COPYRIGHT_PATTERN)
    set(ARG_COPYRIGHT_PATTERN "Copyright.*Jens Munk Hansen")
  endif()

  if(NOT ARG_LICENSE_PATTERN)
    set(ARG_LICENSE_PATTERN "SPDX-License-Identifier:")
  endif()

  # Find Python
  find_package(Python3 COMPONENTS Interpreter QUIET)
  if(NOT Python3_FOUND)
    message(WARNING "Python3 not found, copyright check target disabled")
    return()
  endif()

  # Write the check script
  set(SCRIPT_FILE "${CMAKE_BINARY_DIR}/cmake/check_copyright.py")
  file(WRITE "${SCRIPT_FILE}" "${_SPS_COPYRIGHT_CHECK_SCRIPT}")

  # Collect all source files
  set(ALL_FILES "")
  foreach(dir ${ARG_DIRECTORIES})
    foreach(ext ${ARG_EXTENSIONS})
      file(GLOB_RECURSE FILES_IN_DIR "${dir}/*.${ext}")
      list(APPEND ALL_FILES ${FILES_IN_DIR})
    endforeach()
  endforeach()

  # Apply exclusions
  if(ARG_EXCLUDE)
    foreach(pattern ${ARG_EXCLUDE})
      list(FILTER ALL_FILES EXCLUDE REGEX "${pattern}")
    endforeach()
  endif()

  # Also exclude build directory
  list(FILTER ALL_FILES EXCLUDE REGEX "${CMAKE_BINARY_DIR}")

  if(NOT ALL_FILES)
    message(WARNING "sps_add_copyright_check_target: No files found to check")
    return()
  endif()

  # Create the target
  set(ALL_OPTION "")
  if(ARG_ALL)
    set(ALL_OPTION "ALL")
  endif()

  add_custom_target(${ARG_TARGET} ${ALL_OPTION}
    COMMAND ${Python3_EXECUTABLE} "${SCRIPT_FILE}"
      "${ARG_COPYRIGHT_PATTERN}"
      "${ARG_LICENSE_PATTERN}"
      ${ALL_FILES}
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Checking copyright headers..."
    VERBATIM
  )

  # Store file list for reference
  set_target_properties(${ARG_TARGET} PROPERTIES
    SPS_COPYRIGHT_FILES "${ALL_FILES}"
  )
endfunction()
