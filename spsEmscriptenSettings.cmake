get_filename_component(_EmscriptenSetting_dir "${CMAKE_CURRENT_LIST_FILE}" DIRECTORY)

include(spsHardware)

find_package(Threads REQUIRED)

#[==[.rst:
*********
spsEmscriptenSettings
*********
#
#]==]

# Function to set Emscripten optimization flags
function(sps_set_emscripten_optimization_flags optimization_level optimization_flags link_options)
  if (${optimization_level} STREQUAL "NONE")
    set(${optimization_flags} "-O0" PARENT_SCOPE)
  elseif (${optimization_level} STREQUAL "LITTLE")
    set(${optimization_flags} "-O1" PARENT_SCOPE)
  elseif (${optimization_level} STREQUAL "MORE")
    set(${optimization_flags} "-O2" PARENT_SCOPE)
  elseif (${optimization_level} STREQUAL "BEST")
    list(APPEND ${optimization_flags} "-O3")
    list(APPEND ${optimization_flags} "-msimd128") # NEW
#    list(APPEND ${optimization_flags} "-falign-data=16") # Only GCC
    list(APPEND ${optimization_flags} "-ffast-math") # NEW
    list(APPEND ${optimization_flags} -Wno-pthreads-mem-growth)
    set(${optimization_flags} "${${optimization_flags}}" PARENT_SCOPE)
  elseif (${optimization_level} STREQUAL "SMALL")
    set(${optimization_flags} "-Os" PARENT_SCOPE)
  elseif (${optimization_level} STREQUAL "SMALLEST")
    set(${optimization_flags} "-Oz" PARENT_SCOPE)
  elseif (${optimization_level} STREQUAL "SMALLEST_WITH_CLOSURE")
    set(${optimization_flags} "-Oz" PARENT_SCOPE)
    list(APPEND ${link_options} "--closure 1")
    set(${link_options} "${${link_options}}" PARENT_SCOPE)
  endif()
endfunction()


#[==[.rst:

.. cmake:command:: sps_target_compile_flags

  Conditionally output debug statements
  |module-internal|

  The :cmake:command:`sps_target_compile_flags` function is provided to assist in compiling WASM

  .. code-block:: cmake
    sps_target_compile_flags(TARGET
      TRHEADING_ENABLED             <ON|OFF> (default: OFF)
      OPTIMIZATION                  <NONE, LITTLE, MORE, BEST, SMALL,
                                     SMALLEST, SMALLEST_WITH_CLOSURE> (default: NONE)
      DEBUG                         <NONE, READABLE_JS, PROFILE,
                                     DEBUG_NATIVE> (default: READABLE_JS)
    )
#]==]

# Ensure at least one argument (the target) is passed
function(sps_target_compile_flags target)
    if (NOT target)
        message(FATAL_ERROR "The 'sps_target_compile_flags' function requires a target.")
    endif()

    # TODO: -Wno-pthreads-mem-growth
    
    # Process the rest of the arguments as key-value pairs
    set(options) # Define valid keys
    set(one_value_args THREADING_ENABLED OPTIMIZATION DEBUG) # Mark keys as single-value arguments
    cmake_parse_arguments(ARGS "" "${options}" "${one_value_args}" ${ARGN})

    if(ARGS_UNPARSED_ARGUMENTS)
      message(FATAL_ERROR "Unknown arguments: ${ARGS_UNPARSED_ARGUMENTS}")
    endif()

    if (EMSCRIPTEN)
      # Apply the THREADING option, if specified
      if (ARGS_THREADING_ENABLED)
        if (ARGS_THREADING_ENABLED STREQUAL "ON")
      	  #target_link_libraries(${target} PRIVATE Threads::Threads)
      	  target_compile_options(${target} PUBLIC
            -Wno-pthreads-mem-growth
	    -pthread
      	    -matomics 
      	    -mbulk-memory)
        endif()
      endif()
      if (ARGS_OPTIMIZATION)
        # No positive effect
	set(emscripten_optimization_flags)
	set(emscripten_link_options)
	sps_set_emscripten_optimization_flags(${ARGS_OPTIMIZATION} emscripten_optimization_flags emscripten_link_options)
      	target_compile_options(${target} PRIVATE 
      	  ${emscripten_optimization_flags})
      endif()
    endif()
endfunction()

#[==[.rst:

.. cmake:command:: _sps_check_files_for_main

  Conditionally output debug statements
  |module-internal|

  The :cmake:command:`_sps_check_files_for_main` function is provided to assist in linking. It
  uses sps_check_files_for_main.py for scanning files for presence of a main functions.

  .. code-block:: cmake

    __sps_check_files_for_main(<files> <ON|OFF>)

  The output is either ON or OFF depending on a main is found for export.
#]==]
function(_sps_check_files_for_main FILES HAS_MAIN)
    # Assume the Python script is located in the same directory as this CMake file
    set(SCRIPT_PATH "${_EmscriptenSetting_dir}/sps_check_for_main.py")
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

#[==[.rst:

.. cmake:command:: _sps_prefix_and_format_exports

  Prefix functions for export
  |module-internal|

  The :cmake:command:`_sps_prefix_and_format_exports` function is provided for prefix functions
  for export.

  .. code-block:: cmake

    _sps_prefix_and_format_exports input_list(<functions> <prefixed_functions>)
#]==]
function(_sps_prefix_and_format_exports input_list output_variable)
    # Prefixed functions list
    set(prefixed_functions)

    # Prefix each function with '_'
    foreach(func IN LISTS ${input_list})
        list(APPEND prefixed_functions "'_${func}'")
    endforeach()

    # Convert the list to a comma-separated string and wrap in square brackets
    string(REPLACE ";" "," exported_functions_comma "${prefixed_functions}")
    string(CONCAT exported_functions_str "[" "${exported_functions_comma}" "]")

    # Set the output variable
    set(${output_variable} "${exported_functions_str}" PARENT_SCOPE)
endfunction()

function(_sps_format_exports input_list output_variable)
  # Convert the list to a comma-separated string and wrap in square brackets
  set(prefixed_functions)
  foreach(func IN LISTS ${input_list})
    list(APPEND prefixed_functions "'${func}'")
  endforeach()
  string(REPLACE ";" "," exported_functions_comma "${prefixed_functions}")
  string(CONCAT exported_functions_str "[" "${exported_functions_comma}" "]")
  set(${output_variable} "${exported_functions_str}" PARENT_SCOPE)
endfunction()

#[==[.rst:

.. cmake:command:: _sps_target_info
#]==]
function(_sps_target_info target)
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
.. cmake:command:: _sps_emscripten_settings
Set various variables for Emscripten
.. code-block:: cmake
_sps_emscripten_settings(
  TRHEADING_ENABLED             <ON|OFF> (default: OFF)
  THREAD_POOL_SIZE              (default: 4)
  MAX_NUMBER_OF_THREADS         (default: 4, hard limit for runtime threads)
  EMBIND                        <ON|OFF> (default: OFF)
  ES6_MODULE                    <ON|OFF> (default: ON)
  EXPORT_NAME                   <variable>
  ENVIRONMENT                   <default: qualified guess>
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
#]==]
function(_sps_emscripten_settings)

  #-sALLOW_MEMORY_GROWTH=0 -sTOTAL_MEMORY=64MB
  
  # Define the arguments that the function accepts
  set(options)  # Boolean options (without ON/OFF).
  set(one_value_args
    DISABLE_NODE
    THREADING_ENABLED
    THREAD_POOL_SIZE
    MAX_NUMBER_OF_THREADS
    ENVIRONMENT
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
  set(emscripten_exported_runtime_methods)
  set(emscripten_optimization_flags)

  sps_set_emscripten_optimization_flags(${ARGS_OPTIMIZATION} emscripten_optimization_flags emscripten_link_options)

  # Set the debug flags based on DEBUG value
  if(ARGS_DEBUG STREQUAL "NONE")
    list(APPEND emscripten_debug_options
      "-g0")
    list(APPEND emscripten_link_options
      "-sASSERTIONS=1") # Deadlocks without it????
  elseif(ARGS_DEBUG STREQUAL "READABLE_JS")
    list(APPEND emscripten_link_options
      "-sASSERTIONS=1") # Deadlocks without it????
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
    "-sERROR_ON_UNDEFINED_SYMBOLS=0" # 0 for bindings project
    "-sDISABLE_EXCEPTION_CATCHING=0" # We use exceptions in C++
    "-sALLOW_BLOCKING_ON_MAIN_THREAD=1" # 1 for bindings project
  )

  # Link to embind
  if (ARGS_EMBIND STREQUAL "ON")
    list(APPEND emscripten_link_options
      "-lembind")
  endif()

  # Copy package-json
  set(node_files
    package.json
    package-lock.json
  )
  set(PACKAGE_FOUND OFF)
  # TODO: Consider throwing if no package.json exists and we have an ES6 module
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
  
  # Handle ES6 modules
  if (ARGS_ES6_MODULE STREQUAL "ON")
    # We always do this for ES6 modules
    list(APPEND emscripten_link_options
      "-sNO_EXIT_RUNTIME=1")
    if (NOT DEFINED ARGS_EXPORT_NAME)
      set(ARGS_EXPORT_NAME Module)
    endif()
    list(APPEND emscripten_exported_functions "free")
    list(APPEND emscripten_exported_functions "malloc")
    list(APPEND emscripten_link_options
      "-sMODULARIZE=1"
      "-sEXPORT_ES6=1"
      "-sINCLUDE_FULL_LIBRARY" # for addFunction
      "-sALLOW_TABLE_GROWTH=1"
      "-sALLOW_MEMORY_GROWTH=0"
      "-sEXPORT_NAME=${ARGS_EXPORT_NAME}"
      "-sINITIAL_MEMORY=${ARGS_INITIAL_MEMORY}"
      "-sMAXIMUM_MEMORY=${ARGS_MAXIMUM_MEMORY}"
    )

    if (NOT DEFINED ARGS_ENVIRONMENT)
      if (ARGS_THREADING_ENABLED STREQUAL "ON")
        if ("${ARGS_DISABLE_NODE}" STREQUAL "ON")      
          list(APPEND emscripten_link_options
            "-sENVIRONMENT=web,worker"
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
    else()
      list(APPEND emscripten_link_options
        "-sENVIRONMENT=${ARGS_ENVIRONMENT}"
      )
    endif()
    if (NOT PACKAGE_FOUND)
      message("Warning: No package.json found")
    endif()
    
  else()
    if (NOT ARGS_EXIT_RUNTIME)
      set(ARGS_EXIT_RUNTIME OFF)
    endif()

    list(APPEND emscripten_link_options
      "-sALLOW_MEMORY_GROWTH=1"
      )
    if (ARGS_EXIT_RUNTIME STREQUAL "ON")
      list(APPEND emscripten_link_options
        "-sEXIT_RUNTIME=1")
    else()
      list(APPEND emscripten_link_options
        "-sNO_EXIT_RUNTIME=1")
    endif()

    # NOT AN ES6 module
    if (NOT DEFINED ARGS_ENVIRONMENT)
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
    else()
      list(APPEND emscripten_link_options
        "-sENVIRONMENT=web,worker"
      )
    endif()
  endif()

  list(APPEND emscripten_exported_functions "printf")

  if (ARGS_THREADING_ENABLED STREQUAL "ON")
    list(APPEND emscripten_link_options
      "-pthread"
      "-sUSE_PTHREADS=1"
      "-sPTHREAD_POOL_SIZE=${ARGS_THREAD_POOL_SIZE}"
      "-sPTHREAD_POOL_SIZE_STRICT=${ARGS_MAX_NUMBER_OF_THREADS}"
      # Bug in Emscripten, we cannot use SHARED_MEMORY on .c files if em++
      "-sSHARED_MEMORY=1")
    if (0)
      # Temporarily disabled
      list(APPEND emscripten_link_options
        "-sASYNCIFY_STACK_SIZE=81920" #~297 nesting levels
        "-sASYNCIFY=1"
        "-sWASM=1"
      )
    endif()
    # Use --preload-file or --embed-file if Needed: If you need to load assets asynchronously, Emscripten can manage preloading with --preload-file
    
  endif()

  # Assign the options list to the specified variable
  set(${ARGS_EMSCRIPTEN_LINK_OPTIONS} "${emscripten_link_options}" PARENT_SCOPE)
  set(${ARGS_EMSCRIPTEN_OPTIMIZATION_FLAGS} "${emscripten_optimization_flags}" PARENT_SCOPE)
  set(${ARGS_EMSCRIPTEN_DEBUG_INFO} "${emscripten_debug_options}" PARENT_SCOPE)
endfunction()

#[==[.rst:
.. cmake:command:: sps_emscripten_module
Create a WASM Emscripten module
.. code-block:: cmake
sps_emscripten_module(
  SIDE_MODULE
  MAIN_MODULE
  64_BIT                        <ON|OFF> (default: OFF)
  TARGET_NAME                   <variable>
  SOURCE_FILES                  <list>     (.cxx, .c)
  INCLUDE_DIRS                  <list>
  JAVASCRIPT_FILES              <list>     (copied to outdir)
  DISABLE_NODE
  PRE_JS                        --pre-js
  ENVIRONMENT                   (default: AUTO)
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
function(sps_emscripten_module)
  # Define the arguments that the function accepts
  set(options SIDE_MODULE MAIN_MODULE VERBOSE DISABLE_NODE 64_BIT)
  set(one_value_args
    TARGET_NAME
    ES6_MODULE
    ASYNCIFY
    EMBIND
    EXIT_RUNTIME
    EXPORT_NAME
    DEBUG
    INITIAL_MEMORY
    MAXIMUM_MEMORY
    FILE_SYSTEM
    OPTIMIZATION
    THREADING_ENABLED
    PRE_JS
    THREAD_POOL_SIZE
    EXTRA_LINK_ARGS    
    MAX_NUMBER_OF_THREADS
    ENVIRONMENT)
  set(multi_value_args SOURCE_FILES JAVASCRIPT_FILES SIDE_MODULES EXPORTED_FUNCTIONS LIBRARIES INCLUDE_DIRS)

  # Parse the arguments using cmake_parse_arguments
  cmake_parse_arguments(ARGS "${options}" "${one_value_args}" "${multi_value_args}" ${ARGV})

  if(ARGS_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "Unknown arguments: ${ARGS_UNPARSED_ARGUMENTS}")
  endif()
  
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

  # Platform arguments
  if (NOT ARGS_64_BIT)
    set(ARGS_64_BIT OFF)
  endif()
  if (NOT ARGS_FILE_SYSTEM)
    set(ARGS_FILE_SYSTEM OFF)
  endif()
  if (NOT ARGS_ASYNCIFY)
    set(ARGS_ASYNCIFY OFF)
  endif()
  
  # Threading
  if (ARGS_THREADING_ENABLED STREQUAL "ON")
    find_package(Threads REQUIRED)
  endif()

  if (ARGS_SOURCE_FILES)
    list(GET ${ARGS_SOURCE_FILES} 0 first_file)
    get_filename_component(extension ${first_file} EXT)
    if ("${extension}" STREQUAL ".c")
      set(CMAKE_C_COMPILER emcc)
    endif()
  endif()

  # Add executable
  add_executable(${ARGS_TARGET_NAME} ${ARGS_SOURCE_FILES})

  # Link libraries
  target_link_libraries(${ARGS_TARGET_NAME} PRIVATE ${ARGS_LIBRARIES})
  target_include_directories(${ARGS_TARGET_NAME} PRIVATE ${ARGS_INCLUDE_DIRS})

  # Prepare variables for emscripten_settings
  set(emscripten_link_options)
  set(emscripten_optimization_flags)
  set(emscripten_debug_options)
  set(emscripten_exported_functions)
  set(emscripten_exported_runtime_methods)

  # Call emscripten_settings with the provided arguments
  _sps_emscripten_settings(
    ES6_MODULE ${ARGS_ES6_MODULE}
    EMBIND ${ARGS_EMBIND}
    EXPORT_NAME ${ARGS_EXPORT_NAME}
    DISABLE_NODE ${ARGS_DISABLE_NODE}
    DEBUG ${ARGS_DEBUG}
    ENVIRONMENT ${ARGS_ENVIRONMENT}
    INITIAL_MEMORY ${ARGS_INITIAL_MEMORY}
    MAXIMUM_MEMORY ${ARGS_MAXIMUM_MEMORY}
    THREADING_ENABLED ${ARGS_THREADING_ENABLED}
    THREAD_POOL_SIZE ${ARGS_THREAD_POOL_SIZE}
    MAX_NUMBER_OF_THREADS ${ARGS_MAX_NUMBER_OF_THREADS}
    OPTIMIZATION ${ARGS_OPTIMIZATION}
    EMSCRIPTEN_EXPORTED_FUNCTIONS emscripten_exported_functions
    EMSCRIPTEN_LINK_OPTIONS emscripten_link_options
    EMSCRIPTEN_OPTIMIZATION_FLAGS emscripten_optimization_flags
    EMSCRIPTEN_DEBUG_INFO emscripten_debug_options
  )
  if (ARGS_ES6_MODULE STREQUAL ON)
    # Runtime methods needed for ES6
    set(emscripten_exported_runtime_methods "ENV;FS;addFunction")
  endif()
  # Is it okay always to export this???
  list(APPEND emscripten_exported_runtime_methods "ccall;cwrap;stringToNewUTF8")

  
  if (ARGS_THREADING_ENABLED STREQUAL "ON")
    list(APPEND emscripten_exported_runtime_methods "spawnThread")
  endif()

  if (ARGS_EXPORTED_FUNCTIONS)
    list(APPEND emscripten_exported_functions ${ARGS_EXPORTED_FUNCTIONS})
  endif()
  
  if (ARGS_SIDE_MODULE)
    list(APPEND emscripten_link_options
      "-sSIDE_MODULE=2")
  elseif (ARGS_MAIN_MODULE)
    if (ARGS_SIDE_MODULES)
      list(APPEND emscripten_link_options "-sMAIN_MODULE=2" ${ARGS_SIDE_MODULES})
    else()
      message(FATAL_ERROR "No side modules (.wasm) specified")
    endif()
  endif()

  # Check for main
  if (ARGS_SOURCE_FILES)
    _sps_check_files_for_main(${ARGS_SOURCE_FILES} TARGET_HAS_MAIN)
  endif()
  if (ARGS_ES6_MODULE STREQUAL "OFF" AND NOT ARGS_SIDE_MODULE)
    # If not an ES6 module and no JavaScript files, we assume it is
    # a file to be executed. Linking to Catch2 requires main
    set(TARGET_HAS_MAIN ON)
  endif()

  if (TARGET_HAS_MAIN)
    list(APPEND emscripten_exported_functions "main")
    set_target_properties(${ARGS_TARGET_NAME} PROPERTIES SUFFIX ".cjs")
    list(APPEND emscripten_exported_runtime_methods "callMain")
  endif()

  # 64-bit support (experimental)
  if (ARGS_64_BIT STREQUAL "ON")
    list(APPEND emscripten_link_options
      "-sWASM_BIGINT=1"
      "-sMEMORY64=1")
    list(APPEND emscripten_compile_options
      "-target=wasm64"
      "-sWASM_BIGINT=1"
      "-sMEMORY64=1")
  endif()

  if (ARGS_FILE_SYSTEM STREQUAL "ON")
    list(APPEND emscripten_link_options
      "-sFORCE_FILESYSTEM=1"
    )
    list(APPEND emscripten_exported_runtime_methods "FS")
  endif()

  if (ARGS_ASYNCIFY STREQUAL "ON")
    list(APPEND emscripten_link_options
      "-sASYNCIFY=1"
      #"-sASYNCIFY_DEBUG=1"
    )
  endif()

  # Prefix and format the exports
  _sps_prefix_and_format_exports(emscripten_exported_functions exported_functions_str)
  _sps_format_exports(emscripten_exported_runtime_methods exported_runtime_methods_str)

  # Here add the exports
  list(APPEND emscripten_link_options
    "-sEXPORTED_RUNTIME_METHODS=${exported_runtime_methods_str}")
  list(APPEND emscripten_link_options
    "-sEXPORTED_FUNCTIONS=${exported_functions_str}")

  # C++-exceptions (allow them)
  if (ARGS_SOURCE_FILES)
    list(GET ${ARGS_SOURCE_FILES} 0 first_file)
    get_filename_component(extension ${first_file} EXT)
    if (NOT "${extension}" STREQUAL ".c")
      list(APPEND emscripten_compile_options "-fexceptions")
    endif()
  else()
    list(APPEND emscripten_compile_options "-fexceptions")
  endif()
  

  # Position-independent code
  if (ARGS_SIDE_MODULE OR ARGS_MAIN_MODULE)
    # Shared libraries with WASM
    list(APPEND emscripten_compile_options "-fPIC")
  endif()

  # Threading
  if (ARGS_THREADING_ENABLED STREQUAL "ON")
    target_link_libraries(${ARGS_TARGET_NAME} PRIVATE Threads::Threads)
    list(APPEND emscripten_compile_options "-pthread")
    list(APPEND emscripten_compile_options "-matomics")
    list(APPEND emscripten_compile_options "-mbulk-memory")
    list(APPEND emscripten_compile_options "-msimd128")
    # TODO: Verify why this is needed
    list(APPEND emscripten_link_options
      "-sSUPPORT_LONGJMP=1")
  endif()

  if (ARGS_EXTRA_LINK_ARGS)
    list(APPEND emscripten_link_options
      "${ARGS_EXTRA_LINK_ARGS}")
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

  # Initialization JavaScript file
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

  # Display results
  if (ARGS_VERBOSE)
    _sps_target_info(${ARGS_TARGET_NAME})
  endif()
endfunction()

function(print_target_details target)
    message(STATUS "Target: ${target}")

    # Get linked libraries
    get_target_property(LINKED_LIBRARIES ${target} LINK_LIBRARIES)
    if (LINKED_LIBRARIES)
        message(STATUS "Linked Libraries: ${LINKED_LIBRARIES}")
        foreach(lib ${LINKED_LIBRARIES})
            # Print details of each linked library
            print_target_details(${lib})
        endforeach()
    else()
        message(STATUS "No linked libraries for ${target}")
    endif()

    # Get compile flags
    get_target_property(COMPILE_FLAGS ${target} COMPILE_FLAGS)
    get_target_property(COMPILE_OPTIONS ${target} COMPILE_OPTIONS)
    if (COMPILE_FLAGS)
        message(STATUS "Compile Flags: ${COMPILE_FLAGS}")
    else()
        message(STATUS "No compile flags for ${target}")
    endif()

    if (COMPILE_OPTIONS)
        message(STATUS "Compile Options: ${COMPILE_OPTIONS}")
    else()
        message(STATUS "No compile options for ${target}")
    endif()
endfunction()

# Example usage

