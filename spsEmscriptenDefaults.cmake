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

  ${PROJECT}_TEST_DEBUG
  ${PROJECT}_TEST_OPTIMIZATION (link optimization, which is the most important)
  ${PROJECT}_TEST_COMPILE_OPTIMIZATION 
  
  They are only used for Emscripten.

#]==]

# Defaults used for configurations.

# Note this does not support multi-configuration - or for
# multi-configuration variables must be set in preset, since these
# configurations are just made using global variables in the
# cache. When we get to support Multi-configuration, we can define
# real configuration types.

# Default configurations
set(_DEFAULT_RELEASE_DEBUG READABLE_JS)
set(_DEFAULT_RELEASE_OPTIMIZATION BEST)
set(_DEFAULT_RELEASE_COMPILE_OPTIMIZATION NONE)
set(_DEFAULT_DEBUG_DEBUG DEBUG_NATIVE)
set(_DEFAULT_DEBUG_OPTIMIZATION NONE)
set(_DEFAULT_DEBUG_COMPILE_OPTIMIZATION NONE)

# Default test configurations
set(_DEFAULT_TEST_RELEASE_DEBUG READABLE_JS)
set(_DEFAULT_TEST_RELEASE_OPTIMIZATION NONE)
set(_DEFAULT_TEST_RELEASE_COMPILE_OPTIMIZATION NONE)
set(_DEFAULT_TEST_DEBUG_DEBUG READABLE_JS)
set(_DEFAULT_TEST_DEBUG_OPTIMIZATION NONE)
set(_DEFAULT_TEST_DEBUG_COMPILE_OPTIMIZATION NONE)

option(${project_name}_WASM_SIMD "Enable SIMD" ON)

function(sps_set_emscripten_defaults project_name)
  # Check and set the default optimization value based on the build type
  if (CMAKE_CONFIGURATION_TYPES)
    message("This is a multi-configuration build, so defaults are not set using CMAKE_BUILD_TYPE\n")
    message("\tYou can set options:\n"
      "\t-D${project_name}_DEBUG=\n"
      "\t-D${project_name}_OPTIMIZATION=\n"
      "\t-D${project_name}_COMPILE_OPTIMIZATION=\n")
  endif()

  # Set options available and defaults.
  if (NOT DEFINED ${project_name}_OPTIMIZATION)
    if (CMAKE_BUILD_TYPE STREQUAL "Release")
      set(${project_name}_OPTIMIZATION ${_DEFAULT_RELEASE_OPTIMIZATION} CACHE STRING "Link optimization level for ${project_name} (default: ${_DEFAULT_RELEASE_OPTIMIZATION} for Release)")
    elseif (CMAKE_BUILD_TYPE STREQUAL "Debug")
      set(${project_name}_OPTIMIZATION ${_DEFAULT_DEBUG_OPTIMIZATION} CACHE STRING "Link optimization level for ${project_name} (default: ${_DEFAULT_DEBUG_OPTIMIZATION} for Debug)")
    else()
      set(${project_name}_OPTIMIZATION NONE CACHE STRING "Link optimization level for ${project_name} (default: NONE for unknown build type)")
    endif()
  endif()
  set_property(CACHE ${project_name}_OPTIMIZATION PROPERTY STRINGS "NONE" "SMALLEST" "BEST" "SMALLEST_WITH_CLOSURE")

  if (NOT DEFINED ${project_name}_COMPILE_OPTIMIZATION)
    if (CMAKE_BUILD_TYPE STREQUAL "Release")
      set(${project_name}_COMPILE_OPTIMIZATION ${_DEFAULT_RELEASE_COMPILE_OPTIMIZATION} CACHE STRING "Compile optimization level for ${project_name} (default: ${_DEFAULT_RELEASE_COMPILE_OPTIMIZATION} for Release)")
    elseif (CMAKE_BUILD_TYPE STREQUAL "Debug")
      set(${project_name}_COMPILE_OPTIMIZATION ${_DEFAULT_DEBUG_COMPILE_OPTIMIZATION} CACHE STRING "Compile optimization level for ${project_name} (default: ${_DEFAULT_DEBUG_COMPILE_OPTIMIZATION} for Debug)")
    else()
      set(${project_name}_COMPILE_OPTIMIZATION NONE CACHE STRING "Compile optimization level for ${project_name} (default: NONE for unknown build type)")
    endif()
  endif()
  set_property(CACHE ${project_name}_COMPILE_OPTIMIZATION PROPERTY STRINGS "NONE" "SMALLEST" "BEST" "SMALLEST_WITH_CLOSURE")

  if (NOT DEFINED ${project_name}_DEBUG)
    if (CMAKE_BUILD_TYPE STREQUAL "Release")
      set(${project_name}_DEBUG ${_DEFAULT_RELEASE_DEBUG} CACHE STRING "Debug level for ${project_name} (default: ${_DEFAULT_RELEASE_DEBUG} for Release)")
    elseif (CMAKE_BUILD_TYPE STREQUAL "Debug")
      set(${project_name}_DEBUG ${_DEFAULT_DEBUG_DEBUG} CACHE STRING "Debug level for ${project_name} (default: ${_DEFAULT_DEBUG_DEBUG} for Debug)")
    else()
      set(${project_name}_DEBUG NONE CACHE STRING "Debug level for ${project_name} (default: NONE for unknown build type)")
    endif()
  endif()
  set_property(CACHE ${project_name}_DEBUG PROPERTY STRINGS "NONE" "READABLE_JS" "PROFILE" "DEBUG_NATIVE" "SOURCE_MAPS")

  # Repeat options available and defaults (for test targets)
  if (NOT DEFINED ${project_name}_TEST_OPTIMIZATION)
    if (CMAKE_BUILD_TYPE STREQUAL "Release")
      set(${project_name}_TEST_OPTIMIZATION ${_DEFAULT_TEST_RELEASE_OPTIMIZATION} CACHE STRING "Link optimization level for ${project_name} (default: ${_DEFAULT_TEST_RELEASE_OPTIMIZATION} for Release)")
    elseif (CMAKE_BUILD_TYPE STREQUAL "Debug")
      set(${project_name}_TEST_OPTIMIZATION ${_DEFAULT_TEST_DEBUG_OPTIMIZATION} CACHE STRING "Link optimization level for ${project_name} (default: ${_DEFAULT_TEST_DEBUG_OPTIMIZATION} for Debug)")
    else()
      set(${project_name}_TEST_OPTIMIZATION NONE CACHE STRING "Link optimization level for ${project_name} (default: NONE for unknown build type)")
    endif()
  endif()
  set_property(CACHE ${project_name}_TEST_OPTIMIZATION PROPERTY STRINGS "NONE" "SMALLEST" "BEST" "SMALLEST_WITH_CLOSURE")

  if (NOT DEFINED ${project_name}_TEST_COMPILE_OPTIMIZATION)
    if (CMAKE_BUILD_TYPE STREQUAL "Release")
      set(${project_name}_TEST_COMPILE_OPTIMIZATION ${_DEFAULT_TEST_RELEASE_COMPILE_OPTIMIZATION} CACHE STRING "Compile optimization level for ${project_name} (default: ${_DEFAULT_TEST_RELEASE_COMPILE_OPTIMIZATION} for Release)")
    elseif (CMAKE_BUILD_TYPE STREQUAL "Debug")
      set(${project_name}_TEST_COMPILE_OPTIMIZATION ${_DEFAULT_TEST_DEBUG_COMPILE_OPTIMIZATION} CACHE STRING "Compile optimization level for ${project_name} (default: ${_DEFAULT_TEST_DEBUG_COMPILE_OPTIMIZATION} for Debug)")
    else()
      set(${project_name}_TEST_COMPILE_OPTIMIZATION NONE CACHE STRING "Compile optimization level for ${project_name} (default: NONE for unknown build type)")
    endif()
  endif()
  set_property(CACHE ${project_name}_TEST_COMPILE_OPTIMIZATION PROPERTY STRINGS "NONE" "SMALLEST" "BEST" "SMALLEST_WITH_CLOSURE")

  if (NOT DEFINED ${project_name}_TEST_DEBUG)
    if (CMAKE_BUILD_TYPE STREQUAL "Release")
      set(${project_name}_TEST_DEBUG ${_DEFAULT_TEST_RELEASE_DEBUG} CACHE STRING "Debug level for ${project_name} (default: ${_DEFAULT_TEST_RELEASE_DEBUG} for Release)")
    elseif (CMAKE_BUILD_TYPE STREQUAL "Debug")
      set(${project_name}_TEST_DEBUG ${_DEFAULT_TEST_DEBUG_DEBUG} CACHE STRING "Debug level for ${project_name} (default: ${_DEFAULT_TEST_DEBUG_DEBUG} for Debug)")
    else()
      set(${project_name}_TEST_DEBUG NONE CACHE STRING "Debug level for ${project_name} (default: NONE for unknown build type)")
    endif()
  endif()
  set_property(CACHE ${project_name}_TEST_DEBUG PROPERTY STRINGS "NONE" "READABLE_JS" "PROFILE" "DEBUG_NATIVE" "SOURCE_MAPS")

  # Programs
  message("Default for Emscripten targets (if any)")
  if (${project_name}_DEBUG)
    message("${project_name}_DEBUG=${${project_name}_DEBUG}")
  endif()
  if (${project_name}_OPTIMIZATION)
    message("${project_name}_OPTIMIZATION=${${project_name}_OPTIMIZATION}")
  endif()
  if (${project_name}_COMPILE_OPTIMIZATION)
    message("${project_name}_COMPILE_OPTIMIZATION=${${project_name}_COMPILE_OPTIMIZATION}")
  endif()

  # Unit tests
  message("Default for Emscripten targets (if any)")
  if (${project_name}_TEST_DEBUG)
    message("${project_name}_TEST_DEBUG=${${project_name}_TEST_DEBUG}")
  endif()
  if (${project_name}_TEST_OPTIMIZATION)
    message("${project_name}_TEST_OPTIMIZATION=${${project_name}_TEST_OPTIMIZATION}")
  endif()
  if (${project_name}_TEST_COMPILE_OPTIMIZATION)
    message("${project_name}_TEST_COMPILE_OPTIMIZATION=${${project_name}_TEST_COMPILE_OPTIMIZATION}")
  endif()
  
endfunction()
