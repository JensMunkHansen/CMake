#[==[.rst:

.. cmake:command:: sps_set_emscripten_defaults

  Set default emscripten settings for debug and optimization

  The :cmake:command:`sps_set_emscripten_defaults` function is provided to define options
  for different levels of optimization and debug

  .. code-block:: cmake
    sps_set_emscripten_defaults(PROJECT_NAME)

  It adds CMake options, which can be set from outside and with default values for
  CMAKE_BUILD_TYPE=Release and CMAKE_BUILD_TYPE=Debug. The options are named:

  ${PROJECT}_DEBUG
  ${PROJECT}_OPTIMIZATION (link optimization, which is the most important)
  ${PROJECT}_COMPILE_OPTIMIZATION 

  They are only used for Emscripten.

#]==]
function(sps_set_emscripten_defaults project_name)
  # Check and set the default optimization value based on the build type
  if (CMAKE_CONFIGURATION_TYPES)
    message("This is a multi-configuration build, so defaults are set not set using CMAKE_BUILD_TYPE\n")
    message("\tYou can set options:\n"
      "\t-D${project_name}_DEBUG=\n"
      "\t-D${project_name}_OPTIMIZATION=\n"
      "\t-D${project_name}_COMPILE_OPTIMIZATION=\n")
  endif()
  if (NOT DEFINED ${project_name}_OPTIMIZATION)
    if (CMAKE_BUILD_TYPE STREQUAL "Release")
      set(${project_name}_OPTIMIZATION BEST CACHE STRING "Link optimization level for ${project_name} (default: BEST for Release)")
    elseif (CMAKE_BUILD_TYPE STREQUAL "Debug")
      set(${project_name}_OPTIMIZATION NONE CACHE STRING "Link optimization level for ${project_name} (default: NONE for Debug)")
    else()
      set(${project_name}_OPTIMIZATION NONE CACHE STRING "Link optimization level for ${project_name} (default: NONE for unknown build type)")
    endif()
  endif()
  set_property(CACHE ${project_name}_OPTIMIZATION PROPERTY STRINGS "NONE" "SMALLEST" "BEST" "SMALLEST_WITH_CLOSURE")

  if (NOT DEFINED ${project_name}_COMPILE_OPTIMIZATION)
    if (CMAKE_BUILD_TYPE STREQUAL "Release")
      set(${project_name}_COMPILE_OPTIMIZATION BEST CACHE STRING "Compile optimization level for ${project_name} (default: BEST for Release)")
    elseif (CMAKE_BUILD_TYPE STREQUAL "Debug")
      set(${project_name}_COMPILE_OPTIMIZATION NONE CACHE STRING "Compile optimization level for ${project_name} (default: NONE for Debug)")
    else()
      set(${project_name}_COMPILE_OPTIMIZATION NONE CACHE STRING "Compile optimization level for ${project_name} (default: NONE for unknown build type)")
    endif()
  endif()
  set_property(CACHE ${project_name}_COMPILE_OPTIMIZATION PROPERTY STRINGS "NONE" "SMALLEST" "BEST" "SMALLEST_WITH_CLOSURE")

  if (NOT DEFINED ${project_name}_DEBUG)
    if (CMAKE_BUILD_TYPE STREQUAL "Release")
      set(${project_name}_DEBUG READABLE_JS CACHE STRING "Debug level for ${project_name} (default: READABLE_JS for Release)")
    elseif (CMAKE_BUILD_TYPE STREQUAL "Debug")
      set(${project_name}_DEBUG DEBUG_NATIVE CACHE STRING "Debug level for ${project_name} (default: DEBUG_NATIVE for Debug)")
    else()
      set(${project_name}_DEBUG NONE CACHE STRING "Debug level for ${project_name} (default: NONE for unknown build type)")
    endif()
  endif()
  set_property(CACHE ${project_name}_DEBUG PROPERTY STRINGS "NONE" "READABLE_JS" "PROFILE" "DEBUG_NATIVE" "SOURCE_MAPS")
  message("Default for Emscripten targets (if any)")
  if (${project_name}_DEBUG)
    message("${project_name}_DEBUG=${${project_name}_DEBUG}")
  endif()
  if (${project_name}_OPTIMIZATION)
    message("${project_name}_OPTIMIZATION=${${project_name}_OPTIMIZATION}")
  endif()
  if (${project_name}_COMPILE_OPTIMIZATION)
    message("${project_name}_COMPILE_OPTIMIZATION=${${project_name}_OPTIMIZATION}")
  endif()
endfunction()
