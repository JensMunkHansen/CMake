# Utility function for dumping variables
function(cmake_dump_variables)
  get_cmake_property(_variableNames VARIABLES)
  list (SORT _variableNames)
  foreach (_variableName ${_variableNames})
    if (ARGV0)
      unset(MATCHED)
      string(REGEX MATCH ${ARGV0} MATCHED ${_variableName})
      if (NOT MATCHED)
        continue()
      endif()
    endif()
    message(STATUS "${_variableName}=${${_variableName}}")
  endforeach()
endfunction()

# Function to get absolute paths of sources and headers for a target
function(get_target_files_and_includes target)
    # Get source files
    get_target_property(SOURCE_FILES ${target} SOURCES)
    set(ABS_SOURCE_FILES)
    foreach(src ${SOURCE_FILES})
        file(REALPATH ${src} abs_src)
        list(APPEND ABS_SOURCE_FILES ${abs_src})
    endforeach()

    # Get include directories
    get_target_property(INCLUDE_DIRS ${target} INCLUDE_DIRECTORIES)
    set(ABS_INCLUDE_DIRS)
    foreach(inc ${INCLUDE_DIRS})
        file(REALPATH ${inc} abs_inc)
        list(APPEND ABS_INCLUDE_DIRS ${abs_inc})
    endforeach()

    # Print absolute paths
    message(STATUS "Absolute source files for target ${target}: ${ABS_SOURCE_FILES}")
    message(STATUS "Absolute include directories for target ${target}: ${ABS_INCLUDE_DIRS}")

    # Optionally return results to the caller
    set(${ARGN}_SOURCES ${ABS_SOURCE_FILES} PARENT_SCOPE)
    set(${ARGN}_INCLUDES ${ABS_INCLUDE_DIRS} PARENT_SCOPE)
endfunction()

# Example usage
#get_target_files_and_includes(my_target)
#function(export_files_and_source output_file target)
#  file(WRITE ${output_file} "Target: ${target}\n")
#  get_target_files_and_includes(${target})
#foreach(src ${ABS_SOURCE_FILES})
#    file(APPEND headers_and_sources.txt "Source: ${src}\n")
#endforeach()
#foreach(inc ${ABS_INCLUDE_DIRS})
#    file(APPEND headers_and_sources.txt "Include: ${inc}\n")
#endforeach()
