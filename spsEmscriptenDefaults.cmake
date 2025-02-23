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

  ${PROJECT}_TEST_DEBUG
  ${PROJECT}_TEST_OPTIMIZATION (link optimization, which is the most important)
  
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
set(_DEFAULT_DEBUG_DEBUG DEBUG_NATIVE)
set(_DEFAULT_DEBUG_OPTIMIZATION NONE)

# Default test configurations
set(_DEFAULT_TEST_RELEASE_DEBUG READABLE_JS)
set(_DEFAULT_TEST_RELEASE_OPTIMIZATION NONE)
set(_DEFAULT_TEST_DEBUG_DEBUG READABLE_JS)
set(_DEFAULT_TEST_DEBUG_OPTIMIZATION NONE)

option(${project_name}_WASM_SIMD "Enable SIMD" ON)

# Define reusable lists for optimization
set(_OPTIMIZATION_LEVELS
  NO_OPTIMIZATION
  LITTLE
  MORE
  BEST
  SMALL
  SMALLEST
  SMALLEST_WITH_CLOSURE
)

# Define reusable lists for debuginfo
set(_DEBUG_LEVELS
  NONE
  READABLE_JS
  PROFILE
  DEBUG_NATIVE
  SOURCE_MAPS
)

function(sps_set_emscripten_defaults project_name)
  # Check and set the default optimization value based on the build type
  if (CMAKE_CONFIGURATION_TYPES)
    message("This is a multi-configuration build, so defaults are not set using CMAKE_BUILD_TYPE\n")
    message("\tYou can set options:\n"
      "\t-D${project_name}_DEBUG=\n"
      "\t-D${project_name}_OPTIMIZATION=\n")
  endif()

  # Define a helper macro to avoid repetition
  macro(set_project_option option_name default_value description valid_values)
    if (NOT DEFINED ${option_name})
      set(${option_name} ${default_value} CACHE STRING "${description} (default: ${default_value})")
    endif()
    set_property(CACHE ${option_name} PROPERTY STRINGS ${valid_values})
  endmacro()

  # Set project-level optimization and debug options
  set_project_option(${project_name}_OPTIMIZATION 
    ${_DEFAULT_RELEASE_OPTIMIZATION} 
    "Link optimization level for ${project_name}" 
    "${_OPTIMIZATION_LEVELS}"
  )
  set_project_option(${project_name}_DEBUG 
    ${_DEFAULT_RELEASE_DEBUG} 
    "Debug level for ${project_name}" 
    "${_DEBUG_LEVELS}"
  )

  # Set test-specific optimization and debug options
  set_project_option(${project_name}_TEST_OPTIMIZATION 
    ${_DEFAULT_TEST_RELEASE_OPTIMIZATION} 
    "Link optimization level for ${project_name} (test)" 
    "${_OPTIMIZATION_LEVELS}"
  )
  set_project_option(${project_name}_TEST_DEBUG 
    ${_DEFAULT_TEST_RELEASE_DEBUG} 
    "Debug level for ${project_name} (test)" 
    "${_DEBUG_LEVELS}"
  )

  # Programs
  message("Default for Emscripten targets (if any)")
  message("${project_name}_DEBUG=${${project_name}_DEBUG}")
  message("${project_name}_OPTIMIZATION=${${project_name}_OPTIMIZATION}")

  # Unit tests
  message("Default for Emscripten test targets (if any)")
  message("${project_name}_TEST_DEBUG=${${project_name}_TEST_DEBUG}")
  message("${project_name}_TEST_OPTIMIZATION=${${project_name}_TEST_OPTIMIZATION}")
endfunction()

