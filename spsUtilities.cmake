#[==[.rst:
*********
spsUtilities
*********
#
#]==]

#[==[.rst:

.. cmake:command:: _sps_cmake_dump_variables

  |module-internal|

  The :cmake:command:`_sps_cmake_dump_variables` function is provided for dumping
  CMake variables that match a regex pattern

  .. code-block:: cmake
    _sps_cmake_dump_variables(
      REGEX                         <pattern>)
#]==]
function(_sps_cmake_dump_variables)
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

#[==[.rst:

.. cmake:command:: spsFindVTKModulePath

  |module-internal|

  The :cmake:command:`spsFindVTKModulePaths is for locating the MODULE_PATH for VTK.

  .. code-block:: cmake
    spsFindVTKModulePaths(
      output_path                       <variable>)
#]==]
function(spsFindVTKModulePath path)
  set(_vtk_cmake_dir)
  set(_vtk_cmake_module_paths
    "${VTK_DIR}/vtkModule.cmake"
    "${VTK_DIR}/lib/cmake/vtk-${VTK_VERSION_MAJOR}.${VTK_VERSION_MINOR}/vtkModule.cmake"
    "${VTK_DIR}/lib/cmake/vtk/vtkModule.cmake")
  foreach (_vtk_cmake_module_path ${_vtk_cmake_module_paths})
    if (EXISTS ${_vtk_cmake_module_path})
      get_filename_component(_dir "${_vtk_cmake_module_path}" DIRECTORY)
      set(_vtk_cmake_dir ${_dir})
    endif()
  endforeach()
  set(${path} ${_vtk_cmake_dir} PARENT_SCOPE)
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
