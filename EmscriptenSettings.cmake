include(Hardware)

set(EmscriptenSetting_SCRIPT_DIR ${CMAKE_CURRENT_LIST_DIR})

function(check_files_for_main FILES HAS_MAIN)
    # Assume the Python script is located in the same directory as this CMake file
    set(SCRIPT_PATH "${EmscriptenSetting_SCRIPT_DIR}/check_main.py")
    if (NOT EXISTS ${SCRIPT_PATH})
        message(FATAL_ERROR "Python script not found: ${SCRIPT_PATH}")
    endif()

    set(${HAS_MAIN} OFF PARENT_SCOPE)  # Default to no main function
    foreach(FILE ${FILES})
        # Use the script to check if this file has a main function
        execute_process(
            COMMAND ${CMAKE_COMMAND} -E env python3 ${SCRIPT_PATH} ${FILE}
            OUTPUT_VARIABLE HAS_MAIN_OUTPUT
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )

        if (HAS_MAIN_OUTPUT STREQUAL "1")
            set(${HAS_MAIN} ON PARENT_SCOPE)
            return()  # Exit as soon as we find a main function
        endif()
    endforeach()
endfunction()

function(target_info target)
  # Compile options
  get_target_property(COMPILE_OPTIONS ${target} COMPILE_OPTIONS)
  message("Compile options for target ${target}: ${COMPILE_OPTIONS}")
  
  # Compile definitions
  get_target_property(COMPILE_DEFINITIONS ${target} COMPILE_DEFINITIONS)
  message("Compile definitions for target ${target}: ${COMPILE_DEFINITIONS}")
  
  # Include directories
  get_target_property(INCLUDE_DIRECTORIES ${target} INCLUDE_DIRECTORIES)
  message("Include directories for target ${target}: ${INCLUDE_DIRECTORIES}")
  
  # Link libraries
  get_target_property(LINK_LIBRARIES ${target} LINK_LIBRARIES)
  message("Link libraries for target ${target}: ${LINK_LIBRARIES}")
  
  # Link options
  get_target_property(LINK_OPTIONS ${target} LINK_OPTIONS)
  message("Link options for target ${target}: ${LINK_OPTIONS}")
endfunction()

#[==[.rst:
.. cmake:command:: emscripten_settings
Set various variables for Emscripten
.. code-block:: cmake
emscripten_settings(
  TRHEADING_ENABLED             <ON|OFF> (default: OFF)
  THREAD_POOL_SIZE              (default: 4)
  MAX_NUMBER_OF_THREADS         (default: 4, hard limit for runtime threads)
  EMBIND                        <ON|OFF> (default: OFF)
  ES6_MODULE                    <ON|OFF> (default: ON)
  EXPORT_NAME                   <variable>
  OPTIMIZATION                  <NONE, LITTLE, MORE, BEST, SMALL,
                                 SMALLEST, SMALLEST_WITH_CLOSURE> (default: NONE)
  DEBUG                         <NONE, READABLE_JS, PROFILE,
                                 DEBUG_NATIVE> (default: READABLE_JS)
  INITIAL_MEMORY                (default: 1GB) May crash if too low
  MAXIMUM_MEMORY                (default: 4GB)
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
  set(options
  )  # Boolean options (without ON/OFF).
  set(one_value_args
    DISABLE_NODE
    THREADING_ENABLED
    THREAD_POOL_SIZE
    MAX_NUMBER_OF_THREADS
    EMBIND
    ES6_MODULE
    EXPORT_NAME
    OPTIMIZATION
    DEBUG
    INITIAL_MEMORY
    MAXIMUM_MEMORY
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
    message(FATAL_ERROR "EMSCRIPTEN_DEBUG_INFO must be specified.")
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
  if (NOT DEFINED ARGS_INITIAL_MEMORY)
    set(ARGS_INITIAL_MEMORY "1GB")
  endif()
  if (NOT DEFINED ARGS_MAXIMUM_MEMORY)
    set(ARGS_MAXIMUM_MEMORY "4GB")
  endif()
  if (NOT DEFINED ARGS_THREAD_POOL_SIZE)
    set(ARGS_THREAD_POOL_SIZE 4)
  endif()
  if (NOT DEFINED ARGS_MAX_NUMBER_OF_THREADS)
    sps_get_processor_count(MAX_CONCURRENCY)
    set(ARGS_MAX_NUMBER_OF_THREADS ${MAX_CONCURRENCY})
  endif()

  if (NOT DEFINED ARGS_MAX_NUMBER_OF_THREADS)
    sps_get_processor_count(MAX_CONCURRENCY_VAR)
    set(ARGS_MAX_NUMBER_OF_THREADS ${MAX_CONCURRENCY_VAR})
  endif()
  
  # Default arguments for debug and optimization
  if (NOT DEFINED ARGS_OPTIMIZATION)
    set(ARGS_OPTIMIZATION "NONE")
  endif()
  if (NOT DEFINED ARGS_DEBUG)
    set(ARGS_DEBUG "READABLE_JS")
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
  set(emscripten_debug_options)
  set(emscripten_link_options)
  set(emscripten_exported_functions)
  set(emscripten_optimization_flags)

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
    list(APPEND emscripten_debug_options
      "-g0")
  elseif(ARGS_DEBUG STREQUAL "READABLE_JS")
    list(APPEND emscripten_debug_options
      "-g1")
  elseif(ARGS_DEBUG STREQUAL "PROFILE")
    list(APPEND emscripten_debug_options
      "-g2")
  elseif(ARGS_DEBUG STREQUAL "DEBUG_NATIVE")
    list(APPEND emscripten_debug_options
      "-g3")
    list(APPEND emscripten_link_options
      "-sASSERTIONS=1")
  elseif(ARGS_DEBUG STREQUAL "SOURCE_MAPS")
    list(APPEND emscripten_debug_options
      "-gsource-map")
  endif()

  # Default linker options
  list(APPEND emscripten_link_options
    "-sASSERTIONS=1"
    "-sERROR_ON_UNDEFINED_SYMBOLS=1"
    "-sNO_EXIT_RUNTIME=1"
    "-sDISABLE_EXCEPTION_CATCHING=0"
  )

  # Not possible with optimization - also stuff we depend on!!!
  if (ARGS_OPTIMIZATION STREQUAL "NONE")
#    list(APPEND emscripten_link_options
#      "-sSAFE_HEAP=1")
  endif()
  
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
      "-sEXPORTED_RUNTIME_METHODS=['ENV', 'FS', 'ccall', 'cwrap', 'stringToNewUTF8', 'addFunction', 'spawnThread']"
      "-sINCLUDE_FULL_LIBRARY" # for addFunction
      "-sALLOW_TABLE_GROWTH=1"
      "-sALLOW_MEMORY_GROWTH=1"
      "-sEXPORT_NAME=${ARGS_EXPORT_NAME}"
      "-sINITIAL_MEMORY=${ARGS_INITIAL_MEMORY}"
      "-sMAXIMUM_MEMORY=${ARGS_MAXIMUM_MEMORY}"
    )

    if (ARGS_THREADING_ENABLED STREQUAL "ON")
      if ("${ARGS_DISABLE_NODE}" STREQUAL "ON")      
        list(APPEND emscripten_link_options
          "-sENVIRONMENT=web,worker" # VTK is not node
        )
      else()
        list(APPEND emscripten_link_options
          "-sENVIRONMENT=web,node,worker"
        )
      endif()
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
    set(PACKAGE_FOUND OFF)
    # Consider throwing if no package.json exists
    foreach(node_file ${node_files})
      if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${node_file}")
        add_custom_command(
          TARGET ${ARGS_TARGET_NAME}
          POST_BUILD
          COMMAND
          ${CMAKE_COMMAND} -E copy_if_different
          "${CMAKE_CURRENT_SOURCE_DIR}/${node_file}"
          "${CMAKE_CURRENT_BINARY_DIR}")
        set(PACKAGE_FOUND ON)
      endif()
    endforeach()

    if (PACKAGE_FOUND)
      # Install npm
      add_custom_command(
        TARGET ${ARGS_TARGET_NAME}
        POST_BUILD
        COMMAND
          npm install
        WORKING_DIRECTORY
          ${CMAKE_CURRENT_BINARY_DIR})
    endif()
  else()
    # NOT AN ES6 module
    if (ARGS_THREADING_ENABLED STREQUAL "ON")
      list(APPEND emscripten_link_options
        "-sENVIRONMENT=node,worker"
      )
      # If we have main function, we can do
      #"-sPROXY_TO_PTHREAD=1"  # Main thread is now a worker
    else()
      list(APPEND emscripten_link_options
        "-sENVIRONMENT=node"
      )
    endif()
  endif()
  list(APPEND emscripten_exported_functions "printf")

  if (ARGS_THREADING_ENABLED STREQUAL "ON")
    list(APPEND emscripten_link_options
      "-pthread"
      "-sUSE_PTHREADS=1"
      "-sSHARED_MEMORY=1"
      "-sPTHREAD_POOL_SIZE_STRICT=${ARGS_THREAD_POOL_SIZE}"
      "-sPTHREAD_POOL_SIZE_STRICT=${ARGS_MAX_NUMBER_OF_THREADS}")
  endif()

  # Assign the options list to the specified variable
  set(${ARGS_EMSCRIPTEN_LINK_OPTIONS} "${emscripten_link_options}" PARENT_SCOPE)
  set(${ARGS_EMSCRIPTEN_OPTIMIZATION_FLAGS} "${emscripten_optimization_flags}" PARENT_SCOPE)
  set(${ARGS_EMSCRIPTEN_DEBUG_INFO} "${emscripten_debug_options}" PARENT_SCOPE)
endfunction()

#[==[.rst:
.. cmake:command:: emscripten_module
Create a WASM Emscripten module
.. code-block:: cmake
emscripten_module(
  SIDE_MODULE
  MAIN_MODULE
  64_BIT
  TARGET_NAME                   <variable>
  SOURCE_FILES                  <list>     (.cxx, .c)
  INCLUDE_DIRS                  <list>
  JAVASCRIPT_FILES              <list>     (copied to outdir)
  DISABLE_NODE
  PRE_JS                        --pre-js
  TRHEADING_ENABLED             <ON|OFF>   (default: OFF)
  THREAD_POOL_SIZE              (default: 4)
  MAX_NUMBER_OF_THREADS         (default: 4)
  EMBIND                        <ON|OFF>   (default: OFF)
  OPTIMIZATION                  <variable> (default: NONE)
  DEBUG                         <variable> (default: READABLE_JS) 
  ES6_MODULE                    <ON|OFF>   (default: OFF)
  SIDE_MODULES                  <list> (modules (.wasm) to use)
  LIBRARIES                     <list> (libraries (.a) to link to)
  EXPORTED_FUNCTIONS            <list> (without '_' prefix)
  EXPORT_NAME                   <variable>
  OPTIMIZATION                  <NONE, LITTLE, MORE, BEST, SMALL, SMALLEST, SMALLEST_WITH_CLOSURE>
  DEBUG                         <NONE, READABLE_JS, PROFILE, DEBUG_NATIVE>
  VERBOSE                       Show stuff)

#]==]

# For unit tests

function(emscripten_module)
  # Define the arguments that the function accepts
  set(options SIDE_MODULE MAIN_MODULE VERBOSE DISABLE_NODE 64_BIT)
  set(one_value_args TARGET_NAME ES6_MODULE EMBIND EXPORT_NAME DEBUG OPTIMIZATION THREADING_ENABLED PRE_JS THREAD_POOL_SIZE MAX_NUMBER_OF_THREADS)
  set(multi_value_args SOURCE_FILES JAVASCRIPT_FILES SIDE_MODULES EXPORTED_FUNCTIONS LIBRARIES INCLUDE_DIRS)

  # Parse the arguments using cmake_parse_arguments
  cmake_parse_arguments(ARGS "${options}" "${one_value_args}" "${multi_value_args}" ${ARGV})

  # Validate required arguments
  if (NOT ARGS_TARGET_NAME)
    message(FATAL_ERROR "TARGET_NAME must be specified.")
  endif()
  if (NOT ARGS_SOURCE_FILES AND NOT ARGS_LIBRARIES)
    message(FATAL_ERROR "SOURCE_FILES must be specified.")
  endif()

  # Default arguments for optimization and debug
  if (NOT ARGS_OPTIMIZATION)
    set(ARGS_OPTIMIZATION "NONE")
  endif()
  if (NOT ARGS_DEBUG)
    set(ARGS_DEBUG "NONE")
  endif()


  if (ARGS_THREADING_ENABLED STREQUAL "ON")
    find_package(Threads REQUIRED)
  endif()
  # Add executable
  add_executable(${ARGS_TARGET_NAME} ${ARGS_SOURCE_FILES})

  target_link_libraries(${ARGS_TARGET_NAME} PRIVATE ${ARGS_LIBRARIES})
  target_include_directories(${ARGS_TARGET_NAME} PRIVATE ${ARGS_INCLUDE_DIRS})
  # Prepare variables for emscripten_settings
  set(emscripten_link_options)
  set(emscripten_optimization_flags)
  set(emscripten_debug_options)
  set(emscripten_exported_functions)

  # Call emscripten_settings with the provided arguments
  emscripten_settings(
    ES6_MODULE ${ARGS_ES6_MODULE}
    EMBIND ${ARGS_EMBIND}
    EXPORT_NAME ${ARGS_EXPORT_NAME}
    DISABLE_NODE ${ARGS_DISABLE_NODE}
    DEBUG ${ARGS_DEBUG}
    THREADING_ENABLED ${ARGS_THREADING_ENABLED}
    THREAD_POOL_SIZE ${ARGS_THREAD_POOL_SIZE}
    MAX_NUMBER_OF_THREADS ${ARGS_MAX_NUMBER_OF_THREADS}
    OPTIMIZATION ${ARGS_OPTIMIZATION}
    EMSCRIPTEN_EXPORTED_FUNCTIONS emscripten_exported_functions
    EMSCRIPTEN_LINK_OPTIONS emscripten_link_options
    EMSCRIPTEN_OPTIMIZATION_FLAGS emscripten_optimization_flags
    EMSCRIPTEN_DEBUG_INFO emscripten_debug_options
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
      list(APPEND emscripten_link_options "-sMAIN_MODULE=2" ${ARGS_SIDE_MODULES})
    endif()
  endif()

  # An experiment
  if (ARGS_ES6_MODULE STREQUAL "ON" AND NOT ARGS_MAIN_MODULE AND NOT ARGS_SIDE_MODULE) 
    list(APPEND emscripten_link_options
      # TODO: We can only do this if a main exists
      #"-sPROXY_TO_PTHREAD=1"  
    )
  endif()

  check_files_for_main(${ARGS_SOURCE_FILES} TARGET_HAS_MAIN)
  
  if (ARGS_ES6_MODULE STREQUAL "OFF" AND NOT ARGS_SIDE_MODULE)
    # If not an ES6 module and no JavaScript files, we assume it is
    # a file to be executed. Linking to Catch2 requires main
    set(TARGET_HAS_MAIN ON)
  endif()

  if (TARGET_HAS_MAIN)
    list(APPEND emscripten_exported_functions "main")
    set_target_properties(${ARGS_TARGET_NAME} PROPERTIES SUFFIX ".cjs")
  endif()
  if (ARGS_64_BIT)
    list(APPEND emscripten_link_options
      "-sWASM_BIGINT=1"
      "-sMEMORY64=1")
    list(APPEND emscripten_compile_options
      "-mwasm64"      
      "-sWASM_BIGINT=1"
      "-sMEMORY64=1")
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

  # C++-exceptions
  set(emscripten_compile_options "-fexceptions")
  # Position-independent code
  if (ARGS_SIDE_MODULE OR ARGS_MAIN_MODULE)
    # Shared libraries with WASM
    list(APPEND emscripten_compile_options "-fPIC")
  endif()
  if (ARGS_THREADING_ENABLED STREQUAL "ON")
    target_link_libraries(${ARGS_TARGET_NAME} PRIVATE Threads::Threads)
    list(APPEND emscripten_compile_options "-pthread")
    list(APPEND emscripten_compile_options "-matomics")
    list(APPEND emscripten_compile_options "-mbulk-memory")
    # TODO: Verify why this is needed
    list(APPEND emscripten_link_options
      "-sSUPPORT_LONGJMP=1")
  endif()
  # Link and compile options
  target_compile_options(${ARGS_TARGET_NAME}
    PRIVATE
      ${emscripten_compile_options}
      ${emscripten_optimization_flags} 
      ${emscripten_debug_options}
  )
  target_link_options(${ARGS_TARGET_NAME}
    PRIVATE
      ${emscripten_link_options}
      ${emscripten_optimization_flags} 
      ${emscripten_debug_options}
  )
  
  if (ARGS_SIDE_MODULE)
    # Side modules must be renamed
    set_target_properties(${ARGS_TARGET_NAME} PROPERTIES
      SUFFIX ".wasm")
    # Definition used in source files
    target_compile_definitions(${ARGS_TARGET_NAME} PRIVATE IS_SIDE_MODULE)    
  elseif(ARGS_MAIN_MODULE)
    # Definition used in source files
    target_compile_definitions(${ARGS_TARGET_NAME} PRIVATE IS_MAIN_MODULE)    
  endif()

  if (ARGS_PRE_JS)
    target_link_options(${ARGS_TARGET_NAME}
      PRIVATE
      "--pre-js" "${ARGS_PRE_JS}")
  endif()
  
  # Copy any JavaScript files
  foreach(javascript_file ${ARGS_JAVASCRIPT_FILES})
    set(copyTarget ${ARGS_TARGET_NAME}_copy_${javascript_file})
    add_custom_target(
      ${copyTarget}
      COMMAND
      ${CMAKE_COMMAND} -E copy_if_different
      "${CMAKE_CURRENT_SOURCE_DIR}/${javascript_file}"
      "${CMAKE_CURRENT_BINARY_DIR}")
    add_dependencies(${ARGS_TARGET_NAME} ${copyTarget})
  endforeach()
  if (ARGS_VERBOSE)
    target_info(${ARGS_TARGET_NAME})
    
    #message("emscripten_link_options: ${emscripten_link_options}")
    #message("emscripten_debug_options: ${emscripten_debug_options}")
    #message("emscripten_optimization_flags: ${emscripten_optimization_flags}")
    #message("emscripten_compile_options: ${emscripten_compile_options}")
  endif()
endfunction()

### OLD STUFF

# -----------------------------------------------------------------------------
# Build and debug options
# -----------------------------------------------------------------------------
function(emscripten_default_debug_and_optimization debuginfo optimize)
  # TODO: Consider supporting that if they arguments are initialized, we
  #       verify that they are valid and we use them. This function currently
  #       initializes them to a default that you can change afterwards
  set(DEBUGINFO "READABLE_JS" CACHE STRING "Type of debug info")
  set_property(CACHE DEBUGINFO PROPERTY
    STRINGS
      NONE              # -g0
      READABLE_JS       # -g1
      PROFILE           # -g2
      DEBUG_NATIVE      # -g3
  )
  
  set(OPTIMIZE "BEST" CACHE STRING "Emscripten optimization")
  set_property(CACHE OPTIMIZE PROPERTY
    STRINGS
      NO_OPTIMIZATION       # -O0
      LITTLE                # -O1
      MORE                  # -O2
      BEST                  # -O3
      SMALL                 # -Os
      SMALLEST              # -Oz
      SMALLEST_WITH_CLOSURE # -Oz --closure 1
  )
  set(${debuginfo} "${DEBUGINFO}" PARENT_SCOPE)
  set(${optimize} "${OPTIMIZE}" PARENT_SCOPE)
endfunction()

# -----------------------------------------------------------------------------
# Build options
# -----------------------------------------------------------------------------
function(emscripten_set_optimization_flags optimization_flags optimization_string)

  if (NOT DEFINED optimization_string OR "${optimization_string}" STREQUAL "")
    set(optimization_string "NO_OPTIMIZATION")
  endif()

  set(flags)
  if("${optimization_string}" STREQUAL "NO_OPTIMIZATION")
    list(APPEND flags
      "-O0")
  elseif("${optimization_string}" STREQUAL "LITTLE")
    list(APPEND flags
      "-O1")
  elseif("${optimization_string}" STREQUAL "MORE")
    list(APPEND flags
      "-O2")
  elseif("${optimization_string}" STREQUAL "BEST")
    list(APPEND flags
      "-O3")
  elseif("${optimization_string}" STREQUAL "SMALL")
    list(APPEND flags
      "-Os"
    )
  elseif("${optimization_string}" STREQUAL "SMALLEST")
    list(APPEND flags
      "-Oz"
    )
  elseif("${optimization_string}" STREQUAL "SMALLEST_WITH_CLOSURE")
    list(APPEND flags
      "-Oz"
    )
    list(APPEND emscripten_link_options
      "--closure 1"
    )
  endif()
  set(${optimization_flags} "${flags}" PARENT_SCOPE)
endfunction()

# -----------------------------------------------------------------------------
# Debug options
# -----------------------------------------------------------------------------
function(emscripten_set_debug_options debug_flags debug_string)

  if (NOT DEFINED debug_string OR "${debug_string}" STREQUAL "")
    set(debug_string "NONE")
  endif()

  set(flags)
  if("${debug_string}" STREQUAL "NONE")
    list(APPEND flags
      "-g0"
    )
  elseif("${debug_string}" STREQUAL "READABLE_JS")
    list(APPEND flags
      "-g1"
    )
  elseif("${debug_string}" STREQUAL "PROFILE")
    list(APPEND flags
      "-g2"
    )
  elseif("${debug_string}" STREQUAL "DEBUG_NATIVE")
    list(APPEND flags
      "-g3"
    )
    list(APPEND emscripten_link_options
      "-sASSERTIONS=1"
    )
  elseif("${debug_string}" STREQUAL "SOURCE_MAPS")
    list(APPEND flags
      "-gsource-map"
    )
  endif()
  set(${debug_flags} "${flags}" PARENT_SCOPE)
endfunction()


