#[==[.rst:
.. cmake:command:: emscripten_settings
Set various variables for Emscripten
.. code-block:: cmake
emscripten_settings(
  TRHEADING_ENABLED             <ON|OFF>
  EMBIND                        <ON|OFF>
  ES6_MODULE                    <ON|OFF>
  EXPORT_NAME                   <variable>
  OPTIMIZATION                  <NONE, LITTLE, MORE, BEST, SMALL, SMALLEST, SMALLEST_WITH_CLOSURE>
  DEBUG                         <NONE, READABLE_JS, PROFILE, DEBUG_NATIVE>
  EMSCRIPTEN_EXPORTED_FUNCTIONS <variable>
  EMSCRIPTEN_DEBUG_INFO         <variable>
  EMSCRIPTEN_LINK_OPTIONS       <variable>
  EMSCRIPTEN_OPTIMIZATION_FLAGS <variable>)

We can add more input/output variables. Note, this is not what we like
for our production code, e.g. the export _DoWork or the fixed number of
threads.
#]==]

function(emscripten_settings)
  # Define the arguments that the function accepts
  set(options)  # Boolean options (without ON/OFF).
  set(one_value_args
    THREADING_ENABLED
    EMBIND
    ES6_MODULE
    EXPORT_NAME
    OPTIMIZATION
    DEBUG
    EMSCRIPTEN_LINK_OPTIONS
    EMSCRIPTEN_OPTIMIZATION_FLAGS
    EMSCRIPTEN_DEBUG_INFO
    EMSCRIPTEN_EXPORTED_FUNCTIONS
  )

  # Parse the arguments using cmake_parse_arguments
  cmake_parse_arguments(ARGS "${options}" "${one_value_args}" "${multi_value_args}" ${ARGV})

  # Validate presence of required output arguments
  if (NOT ARGS_EMSCRIPTEN_LINK_OPTIONS)
    message(FATAL_ERROR "EMSCRIPTEN_LINK_OPTIONS must be specified.")
  endif()

  if (NOT ARGS_EMSCRIPTEN_OPTIMIZATION_FLAGS)
    message(FATAL_ERROR "EMSCRIPTEN_OPTIMIZATION_FLAGS must be specified.")
  endif()

  if (NOT ARGS_EMSCRIPTEN_DEBUG_INFO)
    message(FATAL_ERROR "EMSCRIPTEN_OPTIMIZATION_FLAGS must be specified.")
  endif()

  if (NOT ARGS_EMSCRIPTEN_EXPORTED_FUNCTIONS)
    message(FATAL_ERROR "EMSCRIPTEN_EXPORTED_FUNCTIONS must be specified.")
  endif()
  
  # Default values  
  if (NOT DEFINED ARGS_THREADING_ENABLED)
    set(ARGS_THREADING_ENABLED OFF) 
  endif()
  if (NOT DEFINED ARGS_ES6_MODULE)
    set(ARGS_ES6_MODULE ON)
  endif()
  if (NOT DEFINED ARGS_EMBIND)
    set(ARGS_EMBIND OFF)
  endif()

  # Default arguments for debug and optimization
  if (NOT DEFINED ARGS_OPTIMIZATION)
    set(ARGS_OPTIMIZATION "NONE")
  endif()
  if (NOT DEFINED ARGS_DEBUG)
    set(ARGS_DEBUG "NONE")
  endif()

  # Define valid options for OPTIMIZATION
  set(valid_optimization_levels NONE LITTLE MORE BEST SMALL SMALLEST SMALLEST_WITH_CLOSURE)
  
  # Validate OPTIMIZATION argument
  list(FIND valid_optimization_levels "${ARGS_OPTIMIZATION}" opt_index)
  if (opt_index EQUAL -1)
    message(FATAL_ERROR "Invalid value for OPTIMIZATION. Must be one of NONE, LITTLE, or MORE.")
  endif()

  # Define valid options for DEBUG
  set(valid_debug_levels NONE READABLE_JS PROFILE DEBUG_NATIVE SOURCE_MAPS)
  
  # Validate DEBUG argument
  list(FIND valid_debug_levels "${ARGS_DEBUG}" opt_index)
  if (opt_index EQUAL -1)
    message(FATAL_ERROR "Invalid value for DEBUG. Must be one of NONE, READABLE_JS, PROFILE, DEBUG_NATIVE or SOURCE_MAPS")
  endif()

  # Populate lists
  set(emscripten_debug_info)
  set(emscripten_link_options)
  set(emscripten_exported_functions)
  
  # Set the optimization flags based on OPTIMIZATION value
  if (ARGS_OPTIMIZATION STREQUAL "NONE")
    set(emscripten_optimization_flags "-O0")
  elseif (ARGS_OPTIMIZATION STREQUAL "LITTLE")
    set(emscripten_optimization_flags "-O1")
  elseif (ARGS_OPTIMIZATION STREQUAL "MORE")
    set(emscripten_optimization_flags "-O2")
  elseif(ARGS_OPTIMIZATION STREQUAL "BEST")
    list(APPEND emscripten_optimization_flags
      "-O3")
  elseif(ARGS_OPTIMIZATION STREQUAL "SMALL")
    list(APPEND emscripten_optimization_flags
      "-Os")
  elseif(ARGS_OPTIMIZATION STREQUAL "SMALLEST")
    list(APPEND emscripten_optimization_flags
      "-Oz")
  elseif(ARGS_OPTIMIZATION STREQUAL "SMALLEST_WITH_CLOSURE")
    list(APPEND emscripten_optimization_flags
      "-Oz")
    list(APPEND emscripten_link_options
      "--closure 1")
  endif()

  # Set the debug flags based on DEBUG value
  if(ARGS_DEBUG STREQUAL "NONE")
    list(APPEND emscripten_debug_info
      "-g0")
  elseif(ARGS_DEBUG STREQUAL "READABLE_JS")
    list(APPEND emscripten_debug_info
      "-g1")
  elseif(ARGS_DEBUG STREQUAL "PROFILE")
    list(APPEND emscripten_debug_info
      "-g2")
  elseif(ARGS_DEBUG STREQUAL "DEBUG_NATIVE")
    list(APPEND emscripten_debug_info
      "-g3")
    list(APPEND emscripten_link_options
      "-sASSERTIONS=1")
  elseif(ARGS_DEBUG STREQUAL "SOURCE_MAPS")
    list(APPEND emscripten_debug_info
      "-gsource-map")
  endif()

  # Default linker options
  list(APPEND emscripten_link_options
    "-sASSERTIONS=1"
    "-sERROR_ON_UNDEFINED_SYMBOLS=1"
    "-sNO_EXIT_RUNTIME=0")

  # Link to embind
  if (ARGS_EMBIND STREQUAL "ON")
    list(APPEND emscripten_link_options
      "-lembind")
  endif()

  # Handle ES6 modules
  if (ARGS_ES6_MODULE STREQUAL "ON")
    list(APPEND emscripten_exported_functions "free")
    list(APPEND emscripten_exported_functions "malloc")
    list(APPEND emscripten_link_options
      "-sMODULARIZE=1"
      "-sEXPORT_ES6=1"
      "-sEXPORTED_RUNTIME_METHODS=['ENV', 'FS', 'ccall', 'stringToNewUTF8', 'addFunction']"
      "-sINCLUDE_FULL_LIBRARY"
      "-sALLOW_TABLE_GROWTH=1"
      "-sALLOW_MEMORY_GROWTH=1"
      "-sEXPORT_NAME=${ARGS_EXPORT_NAME}")

    if (ARGS_THREADING_ENABLED STREQUAL "ON")
      list(APPEND emscripten_link_options
        "-sENVIRONMENT=web,node,worker"
      )
    else()
      list(APPEND emscripten_link_options
        "-sENVIRONMENT=web,node"
      )
    endif()
    # Copy package-json
    set(node_files
      package.json
      package-lock.json
    )
    # Consider throwing if no package.json exists
    foreach(node_file ${node_files})
      if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${node_file}")
        add_custom_command(
          TARGET ${ARGS_TARGET_NAME}
          COMMAND
          ${CMAKE_COMMAND} -E copy_if_different
          "${CMAKE_CURRENT_SOURCE_DIR}/${node_file}"
          "${CMAKE_CURRENT_BINARY_DIR}")
      endif()
    endforeach()

    # Install npm
    add_custom_command(
      TARGET ${TARGET_NAME}
      POST_BUILD
      COMMAND
        npm install
      WORKING_DIRECTORY
        ${CMAKE_CURRENT_BINARY_DIR})
  else()
    if (ARGS_THREADING_ENABLED STREQUAL "ON")
      list(APPEND emscripten_link_options
        "-sENVIRONMENT=node,worker"
      )  
    else()
      list(APPEND emscripten_link_options
        "-sENVIRONMENT=node"
      )  
    endif()
    # TODO: If unit tests change target name to .cjs
  endif()
  list(APPEND emscripten_exported_functions "printf")

  # TODO: Handle number of threads
  if (ARGS_THREADING_ENABLED STREQUAL "ON")
    list(APPEND emscripten_link_options
      "-sUSE_PTHREADS=1"
      "-sSHARED_MEMORY=1"
      "-sINITIAL_MEMORY=64MB"
      "-sPTHREAD_POOL_SIZE=4")
  endif()

  # Assign the options list to the specified variable
  set(${ARGS_EMSCRIPTEN_LINK_OPTIONS} "${emscripten_link_options}" PARENT_SCOPE)
  set(${ARGS_EMSCRIPTEN_OPTIMIZATION_FLAGS} "${emscripten_optimization_flags}" PARENT_SCOPE)
  set(${ARGS_EMSCRIPTEN_DEBUG_INFO} "${emscripten_debug_info}" PARENT_SCOPE)
endfunction()

#[==[.rst:
.. cmake:command:: emscripten_module
Create a WASM Emscripten module
.. code-block:: cmake
emscripten_module(
  SIDE_MODULE
  MAIN_MODULE
  TARGET_NAME                   <variable>
  SOURCE_FILES                  <list>
  JAVASCRIPT_FILES              <list>
  TRHEADING_ENABLED             <ON|OFF>
  EMBIND                        <ON|OFF>
  OPTIMIZATION                  <variable>
  DEBUG                         <variable>  
  ES6_MODULE                    <ON|OFF>
  SIDE_MODULES                  <list>
  EXPORTED_FUNCTIONS            <list>
  EXPORT_NAME                   <variable>
  OPTIMIZATION                  <NONE, LITTLE, MORE, BEST, SMALL, SMALLEST, SMALLEST_WITH_CLOSURE>
  DEBUG                         <NONE, READABLE_JS, PROFILE, DEBUG_NATIVE>)

#]==]

# For unit tests
#   set_target_properties(sampleTest PROPERTIES SUFFIX ".cjs")

function(emscripten_module)
  # Define the arguments that the function accepts
  set(options SIDE_MODULE MAIN_MODULE VERBOSE)
  set(one_value_args TARGET_NAME ES6_MODULE EMBIND EXPORT_NAME DEBUG OPTIMIZATION THREADING_ENABLED)
  set(multi_value_args SOURCE_FILES JAVASCRIPT_FILES SIDE_MODULES EXPORTED_FUNCTIONS)

  # Parse the arguments using cmake_parse_arguments
  cmake_parse_arguments(ARGS "${options}" "${one_value_args}" "${multi_value_args}" ${ARGV})

  # Validate required arguments
  if (NOT ARGS_TARGET_NAME)
    message(FATAL_ERROR "TARGET_NAME must be specified.")
  endif()
  if (NOT ARGS_SOURCE_FILES)
    message(FATAL_ERROR "SOURCE_FILES must be specified.")
  endif()

  # Default arguments for optimization and debug
  if (NOT ARGS_OPTIMIZATION)
    set(ARGS_OPTIMIZATION "NONE")
  endif()
  if (NOT ARGS_DEBUG)
    set(ARGS_DEBUG "NONE")
  endif()
  
  # Add executable
  add_executable(${ARGS_TARGET_NAME} ${ARGS_SOURCE_FILES})

  # Prepare variables for emscripten_settings
  set(emscripten_link_options)
  set(emscripten_optimization_flags)
  set(emscripten_debug_info)
  set(emscripten_exported_functions)

  # Call emscripten_settings with the provided arguments
  emscripten_settings(
    ES6_MODULE ${ARGS_ES6_MODULE}
    EMBIND ${ARGS_EMBIND}
    EXPORT_NAME ${ARGS_EXPORT_NAME}
    DEBUG ${ARGS_DEBUG}
    THREADING_ENABLED ${ARGS_THREADING_ENABLED}
    OPTIMIZATION ${ARGS_OPTIMIZATION}
    EMSCRIPTEN_EXPORTED_FUNCTIONS emscripten_exported_functions
    EMSCRIPTEN_LINK_OPTIONS emscripten_link_options
    EMSCRIPTEN_OPTIMIZATION_FLAGS emscripten_optimization_flags
    EMSCRIPTEN_DEBUG_INFO emscripten_debug_info
  )

  if (ARGS_EXPORTED_FUNCTIONS)
    list(APPEND emscripten_exported_functions ${ARGS_EXPORTED_FUNCTIONS})
  endif()
  
  if (ARGS_SIDE_MODULE)
    list(APPEND emscripten_link_options
      "-sSIDE_MODULE=2")
  endif()

  # Main modules can link to shared modules, only tested for ANSI-C
  if (ARGS_MAIN_MODULE)
    if (ARGS_SIDE_MODULES)
      list(APPEND emscripten_exported_functions "printf")
      list(APPEND emscripten_link_options "-sMAIN_MODULE=2" ${ARGS_SIDE_MODULES})
      #list(APPEND emscripten_link_options "-sENVIRONMENT=web,worker")
    endif()
  endif()

  # Exported functions
  set(prefixed_functions)
  foreach(func ${emscripten_exported_functions})
    list(APPEND prefixed_functions "'_${func}'")
  endforeach()

  # Convert the list to a comma-separated string and wrap in square brackets
  string(REPLACE ";" "," exported_functions_comma "${prefixed_functions}")
  string(CONCAT exported_functions_str "[" "${exported_functions_comma}" "]")

  # Here add the exports
  list(APPEND emscripten_link_options
    "-sEXPORTED_FUNCTIONS=${exported_functions_str}")

  # Position-independent code
  set(EXTRA_COMPILE_ARGS)
  if (ARGS_SIDE_MODULE OR ARGS_MAIN_MODULE)
    set(EXTRA_COMPILE_ARGS "-fPIC")
  endif()
  if (ARGS_THREADING_ENABLED STREQUAL "ON")
    # TODO: Introduce emscripten_compile_flags
    # set(EXTRA_COMPILE_ARGS "-fPIC -matomics\ -mbulk-memory")
  endif()
  # Link and compile options
  target_link_options(${ARGS_TARGET_NAME} PRIVATE ${emscripten_link_options})
  target_compile_options(${ARGS_TARGET_NAME} PRIVATE ${emscripten_optimization_flags} ${EXTRA_COMPILE_ARGS})

  # TODO: Rename threaded output .js to .mjs (required by CTest)
  
  # Side modules must be renamed
  if (ARGS_SIDE_MODULE)
    set_target_properties(${ARGS_TARGET_NAME} PROPERTIES
      SUFFIX ".wasm")
    target_compile_definitions(${ARGS_TARGET_NAME} PRIVATE IS_SIDE_MODULE)    
  elseif(ARGS_MAIN_MODULE)
    target_compile_definitions(${ARGS_TARGET_NAME} PRIVATE IS_MAIN_MODULE)    
  endif()

  # Copy any JavaScript files
  foreach(javascript_file ${ARGS_JAVASCRIPT_FILES})
    set(copyTarget ${TARGET_NAME}_copy_${javascript_file})
    add_custom_target(
      ${copyTarget}
      COMMAND
      ${CMAKE_COMMAND} -E copy_if_different
      "${CMAKE_CURRENT_SOURCE_DIR}/${javascript_file}"
      "${CMAKE_CURRENT_BINARY_DIR}")
    add_dependencies(${TARGET_NAME} ${copyTarget})
  endforeach()
endfunction()
