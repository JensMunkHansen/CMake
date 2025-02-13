#[==[.rst:
*********
spsEmscriptenSettings
*********
#
#]==]


get_filename_component(_EmscriptenSetting_dir "${CMAKE_CURRENT_LIST_FILE}" DIRECTORY)

include(spsHardware)
include(spsCopyFiles)
include(spsNode)
include(spsSourceMap)

find_package(Threads REQUIRED)

# TODO: Generated .js files with this content
# //# sourceMappingURL=http://127.0.0.1:3001/your_file.wasm.map

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
    # Not super elegant.....
    if (${project_name}_WASM_SIMD)
      list(APPEND ${optimization_flags} "-msimd128")
    endif()
    # Notes:
    #  - only gcc (no clang) support "-falign-data=16", so we cannot use it yet
    #  - "-ffast-math", I have always induced a dead-lock when using this, also small examples (compiler issue)
    # list(APPEND ${optimization_flags} -Wno-pthreads-mem-growth)
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

function(sps_set_emscripten_debug_flags debug_level debug_options)
  if(${debug_level} STREQUAL "NONE")
    list(APPEND ${debug_options}
      "-g0")
  elseif(${debug_level} STREQUAL "READABLE_JS")
    list(APPEND ${debug_options}
      "-g1")
  elseif(${debug_level} STREQUAL "PROFILE")
    list(APPEND ${debug_options}
      "-g2")
  elseif(${debug_level} STREQUAL "DEBUG_NATIVE")
    list(APPEND ${debug_options}
      "-g3")
    list(APPEND emscripten_link_options
      "-sASSERTIONS=1")
  elseif(${debug_level} STREQUAL "SOURCE_MAPS")
    list(APPEND ${debug_options}
      "-gsource-map")
  endif()
  set(${debug_options} "${${debug_options}}" PARENT_SCOPE)
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
          -Wno-pthreads-mem-growth # Do not allow worker threads to grow memory
          -pthread                 # Needed if accessed by pthread
    	  -matomics                # Needed through compilation unit
    	  -mbulk-memory            # Threads and shared memory must go hand-in-hand
        )
      endif()
    endif()
    if (ARGS_OPTIMIZATION)
      # Optimization at compile level, very little effect
      set(emscripten_optimization_flags)
      set(emscripten_link_options)
      sps_set_emscripten_optimization_flags(${ARGS_OPTIMIZATION} emscripten_optimization_flags emscripten_link_options)
    	target_compile_options(${target} PRIVATE
    	  ${emscripten_optimization_flags})
    endif()
  else()
    message(FATAL_ERROR "This needs an Emscripten build environment")
  endif()
endfunction()

#[==[.rst:

.. cmake:command:: _sps_check_files_for_main

  Convenience function for searching for a main function.
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

  Prefix and list functions for export
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

#[==[.rst:

.. cmake:command:: _sps_format_exports (without prefix)

  Format list of functions for export
  |module-internal|

  The :cmake:command:`_sps_format_exports` function is provided for prefix runtime functions
  for export.

  .. code-block:: cmake

    _sps_format_exports(<functions> <list_of_functions>)
#]==]
function(_sps_format_exports input_list output_variable)
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

  Print target info to verify flags
  |module-internal|

  The :cmake:command:`_sps_target_info` function is provided for verbose info
  for export.

  .. code-block:: cmake

    _sps_target_info(<target>)
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
  EMSCRIPTEN_DEBUG_INFO         <variable>
  EMSCRIPTEN_LINK_OPTIONS       <variable>
  EMSCRIPTEN_OPTIMIZATION_FLAGS <variable>)
#]==]
function(_sps_emscripten_settings)

  # TODO: Consider not allowing -sALLOW_MEMORY_GROWTH=0 -sTOTAL_MEMORY=64MB

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
  if (NOT DEFINED ARGS_THREAD_POOL_SIZE)
    # Note for this we need a VTK with improved thread support
    set(ARGS_THREAD_POOL_SIZE 4)
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
    message(FATAL_ERROR "Invalid value for OPTIMIZATION (${ARGS_OPTIMIZATION}). Must be one of NONE, LITTLE, or MORE.")
  endif()

  # Define valid options for DEBUG
  set(valid_debug_levels NONE READABLE_JS PROFILE DEBUG_NATIVE SOURCE_MAPS)

  # Validate DEBUG argument
  list(FIND valid_debug_levels "${ARGS_DEBUG}" opt_index)
  if (opt_index EQUAL -1)
    message(FATAL_ERROR "Invalid value for DEBUG (${ARGS_DEBUG}). Must be one of NONE, READABLE_JS, PROFILE, DEBUG_NATIVE or SOURCE_MAPS")
  endif()

  # Populate lists
  set(emscripten_debug_options)
  set(emscripten_link_options)
  set(emscripten_optimization_flags)

  sps_set_emscripten_optimization_flags(${ARGS_OPTIMIZATION} emscripten_optimization_flags emscripten_link_options)
  sps_set_emscripten_debug_flags(${ARGS_DEBUG} emscripten_debug_options)

  # Default linker options
#  list(APPEND emscripten_link_options
#    "-sERROR_ON_UNDEFINED_SYMBOLS=0" # 0 for bindings project
#    "-sDISABLE_EXCEPTION_CATCHING=0" # We use exceptions in C++
#    "-sALLOW_BLOCKING_ON_MAIN_THREAD=0" # Experiment with threads requires this (bug in Emscripten)
#  )

  # Link to embind
  if (ARGS_EMBIND STREQUAL "ON")
    list(APPEND emscripten_link_options
      "-lembind")
  endif()

  # Handle node
  sps_initialize_node(${ARGS_TARGET_NAME})

  # Handle ES6 modules
  if (ARGS_ES6_MODULE STREQUAL "ON")
    # We always do this for ES6 modules
    list(APPEND emscripten_link_options
      "-sNO_EXIT_RUNTIME=1")
    if (NOT DEFINED ARGS_EXPORT_NAME)
      set(ARGS_EXPORT_NAME Module)
    endif()
    list(APPEND emscripten_link_options
      "-sMODULARIZE=1"
      "-sUSE_WEBGL2=1"
      "-sEXPORT_ES6=1"
#      "-sINCLUDE_FULL_LIBRARY" # for addFunction
#      "-sALLOW_TABLE_GROWTH=1" # TEST FOR SHARED MEMORY
      "-sEXPORT_NAME=${ARGS_EXPORT_NAME}"
    )
    list(APPEND emscripten_link_options
      "-sUSE_WEBGL2=1"
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
  else()
    # NOT AN ES6 module

    # TODO: Can we make this a general option
    if (NOT DEFINED ARGS_EXIT_RUNTIME)
      set(ARGS_EXIT_RUNTIME OFF)
    endif()
    if (ARGS_EXIT_RUNTIME STREQUAL "ON")
      list(APPEND emscripten_link_options
        "-sEXIT_RUNTIME=1")
    else()
      list(APPEND emscripten_link_options
        "-sNO_EXIT_RUNTIME=1")
    endif()
    if (DEFINED ARGS_ENVIRONMENT)
      if (NOT ARGS_ENVIRONMENT STREQUAL "NONE")
        list(APPEND emscripten_link_options
          "-sENVIRONMENT=${ARGS_ENVIRONMENT}"
        )
      endif()
    else()
      # Automatic setting for environment
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
  endif()
  # TODO: Move to module
  if (ARGS_THREADING_ENABLED STREQUAL "ON")
    list(APPEND emscripten_link_options
      "-pthread"
      "-flto"
      "--enable-bulk-memory"
      "-sUSE_PTHREADS=1"
      "-sSTACK_SIZE=262144"
      # Bug in Emscripten, we cannot use SHARED_MEMORY on .c files if em++
      "-sSHARED_MEMORY=1"
      "-sWASM=1")
    # Side module does not own threads (gives a warning, but no biggee)
    list(APPEND emscripten_link_options
      "-sPTHREAD_POOL_SIZE=${ARGS_THREAD_POOL_SIZE}"
      "-sPTHREAD_POOL_SIZE_STRICT=${ARGS_MAX_NUMBER_OF_THREADS}")
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
  SDL2
  IMPORTED_MEMORY
  ASYNCIFY_DEBUG
  DEBUG_VALIDATION              (check if binaryen modifies debug information)
  64_BIT                        <ON|OFF> (default: OFF)
  ENABLE_EXCEPTIONS             <ON|OFF> (default: ON)
  TARGET_NAME                   <variable>
  SOURCE_FILES                  <list>     (.cxx, .c)
  INCLUDE_DIRS                  <list>
  JAVASCRIPT_FILES              <list>     (copied to outdir)
  DISABLE_NODE
  PRE_JS                        --pre-js
  ENVIRONMENT                   (default: AUTO)
  INITIAL_MEMORY                (default: 1GB) May crash if too low
  MAXIMUM_MEMORY                (default: 4GB)
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
  SHARED_MEMORY                 <ON|OFF>
  COMPILE_DEFINITIONS           <list>  
  OPTIMIZATION                  <NONE, LITTLE, MORE, BEST, SMALL, SMALLEST, SMALLEST_WITH_CLOSURE>
  DEBUG                         <NONE, READABLE_JS, PROFILE, DEBUG_NATIVE>
  VERBOSE                       Show stuff)

# Responsible for platform, exported functions, filesystem, threads, stack-size, memory layout etc.
#]==]
function(sps_emscripten_module)
  # Define the arguments that the function accepts
  set(options SIDE_MODULE MAIN_MODULE SDL2 SDL_TTF SDL_MIXER FETCH VERBOSE DISABLE_NODE ASYNCIFY_DEBUG DEBUG_VALIDATION IMPORTED_MEMORY)
  set(one_value_args
    64_BIT
    TARGET_NAME
    ES6_MODULE
    ASYNCIFY
    EMBIND
    EXIT_RUNTIME
    EXPORT_NAME
    DEBUG
    SHARED_MEMORY
    ENABLE_EXCEPTIONS
    ENVIRONMENT
    INITIAL_MEMORY
    MAXIMUM_MEMORY
    FILE_SYSTEM
    OPTIMIZATION
    THREADING_ENABLED
    PRE_JS
    THREAD_POOL_SIZE
    EXTRA_LINK_ARGS
    MAX_NUMBER_OF_THREADS)
  set(multi_value_args SOURCE_FILES COMPILE_DEFINITIONS JAVASCRIPT_FILES SIDE_MODULES EXPORTED_FUNCTIONS ASYNCIFY_IMPORTS LIBRARIES INCLUDE_DIRS)

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
  if (NOT DEFINED ARGS_OPTIMIZATION)
    set(ARGS_OPTIMIZATION "NONE")
  endif()
  if (NOT DEFINED ARGS_DEBUG)
    set(ARGS_DEBUG "NONE")
  endif()
  # Platform arguments
  if (NOT DEFINED ARGS_64_BIT)
    set(ARGS_64_BIT OFF)
  endif()
  if (NOT DEFINED ARGS_FILE_SYSTEM)
    set(ARGS_FILE_SYSTEM OFF)
  endif()
  if (NOT DEFINED ARGS_ASYNCIFY)
    set(ARGS_ASYNCIFY OFF)
  endif()

  # Threading
  if (ARGS_THREADING_ENABLED STREQUAL "ON")
    find_package(Threads REQUIRED)
  endif()

  if (NOT DEFINED ARGS_ENABLE_EXCEPTIONS)
    set(ARGS_ENABLE_EXCEPTIONS ON)
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
  set(emscripten_async_imports)

  # Call emscripten_settings with the provided arguments
  _sps_emscripten_settings(
    ES6_MODULE ${ARGS_ES6_MODULE}
    EMBIND ${ARGS_EMBIND}
    EXPORT_NAME ${ARGS_EXPORT_NAME}
    DISABLE_NODE ${ARGS_DISABLE_NODE}
    DEBUG ${ARGS_DEBUG}
    ENVIRONMENT ${ARGS_ENVIRONMENT}
    THREADING_ENABLED ${ARGS_THREADING_ENABLED}
    THREAD_POOL_SIZE ${ARGS_THREAD_POOL_SIZE}
    MAX_NUMBER_OF_THREADS ${ARGS_MAX_NUMBER_OF_THREADS}
    OPTIMIZATION ${ARGS_OPTIMIZATION}
    EMSCRIPTEN_LINK_OPTIONS emscripten_link_options
    EMSCRIPTEN_OPTIMIZATION_FLAGS emscripten_optimization_flags
    EMSCRIPTEN_DEBUG_INFO emscripten_debug_options
  )

  if (ARGS_ES6_MODULE STREQUAL ON)
    list(APPEND emscripten_exported_functions "free")
    list(APPEND emscripten_exported_functions "malloc")
    # Runtime methods needed for ES6
    set(emscripten_exported_runtime_methods "ENV;FS;addFunction;removeFunction")
  endif()
  # Is it okay always to export this???
  list(APPEND emscripten_exported_runtime_methods "ccall;cwrap;stringToNewUTF8;UTF8ToString;setValue")


  if (ARGS_THREADING_ENABLED STREQUAL "ON")
    list(APPEND emscripten_exported_runtime_methods "spawnThread")
  endif()

  if (ARGS_EXPORTED_FUNCTIONS)
    list(APPEND emscripten_exported_functions ${ARGS_EXPORTED_FUNCTIONS})
  endif()
  if (ARGS_ASYNCIFY_IMPORTS)
    list(APPEND emscripten_async_imports ${ARGS_ASYNCIFY_IMPORTS})
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

  if (ARGS_SDL2)
    list(APPEND emscripten_link_options
      "-sUSE_SDL=2"
    )
  endif()
  if (ARGS_SDL_MIXER)
    list(APPEND emscripten_link_options
      "-sUSE_SDL_MIXER=2"
    )
  endif()      

  if (ARGS_SDL_TTF)
    list(APPEND emscripten_link_options
      "-sUSE_SDL_TTF=2"
    )
  endif()
  if (ARGS_FETCH)
    list(APPEND emscripten_link_options
      "-sFETCH=1"
    )
  endif()
  # Check for main
  if (ARGS_SOURCE_FILES)
    _sps_check_files_for_main(${ARGS_SOURCE_FILES} TARGET_HAS_MAIN)
  endif()
  if (ARGS_ES6_MODULE STREQUAL "OFF" AND NOT ARGS_SIDE_MODULE)
    # If not an ES6 module and no JavaScript files, we assume it is
    # a file to be executed. Linking to Catch2 requires main
    # set(TARGET_HAS_MAIN ON)
  endif()

  if (TARGET_HAS_MAIN)
    list(APPEND emscripten_exported_functions "main")
    set_target_properties(${ARGS_TARGET_NAME} PROPERTIES SUFFIX ".cjs")
    list(APPEND emscripten_exported_runtime_methods "callMain")
  endif()

  # Memory
  if (ARGS_INITIAL_MEMORY)
    list(APPEND emscripten_link_options
      "-sINITIAL_MEMORY=${ARGS_INITIAL_MEMORY}"
    )
  endif()
  if (DEFINED ARGS_MAXIMUM_MEMORY AND DEFINED ARGS_INITIAL_MEMORY)
    list(APPEND emscripten_link_options
      "-sMAXIMUM_MEMORY=${ARGS_MAXIMUM_MEMORY}")
    if (${ARGS_MAXIMUM_MEMORY} STREQUAL ${ARGS_INITIAL_MEMORY})
      list(APPEND emscripten_link_options
        "-sALLOW_MEMORY_GROWTH=0"
      )
    endif()
  elseif (DEFINED ARGS_MAXIMUM_MEMORY)
    list(APPEND emscripten_link_options
      "-sMAXIMUM_MEMORY=${ARGS_MAXIMUM_MEMORY}"
      "-sALLOW_MEMORY_GROWTH=1")
  elseif(${ARGS_DEBUG} STREQUAL "SOURCE_MAPS" OR ${ARGS_DEBUG} STREQUAL "DEBUG_NATIVE")
    list(APPEND emscripten_link_options
      "-sALLOW_MEMORY_GROWTH=1"
    )
  else()
    # Default is that we allow memory to grow
    list(APPEND emscripten_link_options
      "-sALLOW_MEMORY_GROWTH=1"
    )
  endif()

  if (ARGS_SHARED_MEMORY STREQUAL "ON")
    list(APPEND emscripten_link_options
      "-SHARED_MEMORY=1")
  endif()
  
  if (ARGS_IMPORTED_MEMORY)
    list(APPEND emscripten_link_options
      "-sIMPORTED_MEMORY"
#      "-sEMSCRIPTEN_ALIGN_MEMORY"
    )
  endif()
  
  # 64-bit support (experimental)
  if (ARGS_64_BIT STREQUAL "ON")
    
    list(APPEND emscripten_link_options
#      "-sMEMORY64=1" # Issues if not ES6
#      "-sWASM_BIGINT=1" # Issues if not ES6
    )
    list(APPEND emscripten_compile_options
      "-target=wasm64")
#      "-sWASM_BIGINT=1" # Issues if not ES6
#      "-sMEMORY64=1") # Issues if not ES6
  endif()


#  list(APPEND emscripten_link_options
#    "-sWASM_BIGINT=1"
#    "--separate-dwarf=${ARGS_TARGET_NAME}.debug.wasm"
#  )
  if (ARGS_FILE_SYSTEM STREQUAL "ON")
    list(APPEND emscripten_link_options
      "-sFORCE_FILESYSTEM=1"
    )
    list(APPEND emscripten_exported_runtime_methods "FS")
  endif()

  if (ARGS_ASYNCIFY STREQUAL "ON")
    list(APPEND emscripten_link_options
        "-sASYNCIFY_STACK_SIZE=8192" #~297 nesting levels
        "-sASYNCIFY=1"
    )
    if (ARGS_ASYNCIFY_DEBUG)
      # Debug stack to track bugs in Emscripten
      list(APPEND emscripten_link_options
        "-sASYNCIFY_DEBUG=1"
      )
    endif()
  endif()

  # Prefix and format the exports
  _sps_prefix_and_format_exports(emscripten_async_imports async_imports_str)
  _sps_prefix_and_format_exports(emscripten_exported_functions exported_functions_str)
  _sps_format_exports(emscripten_exported_runtime_methods exported_runtime_methods_str)

  # Here add the exports
  list(APPEND emscripten_link_options
    "-sEXPORTED_RUNTIME_METHODS=${exported_runtime_methods_str}")
  list(APPEND emscripten_link_options
    "-sEXPORTED_FUNCTIONS=${exported_functions_str}")
  list(APPEND emscripten_link_options
    "-sASYNCIFY_IMPORTS=${async_imports_str}")

  if (${ARGS_ENABLE_EXCEPTIONS} STREQUAL "ON")
    # C++-exceptions (allow them)
    if (ARGS_SOURCE_FILES)
      # C does not support exceptions
      list(GET ${ARGS_SOURCE_FILES} 0 first_file)
      get_filename_component(extension ${first_file} EXT)
      message(${ARGS_ENABLE_EXCEPTIONS})
      if (NOT "${extension}" STREQUAL ".c")
        list(APPEND emscripten_compile_options "-fexceptions")
      endif()
    else()
      list(APPEND emscripten_compile_options "-fexceptions")
    endif()
  else()
#    list(APPEND emscripten_compile_options "-fno-exceptions")
  endif()

  # Position-independent code (required for shared objects)
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
  endif()

  # Support extra link args (if provided)
  if (ARGS_EXTRA_LINK_ARGS)
    list(APPEND emscripten_link_options
      "${ARGS_EXTRA_LINK_ARGS}")
  endif()

  # Initialization JavaScript file
  if (ARGS_PRE_JS)
    list(APPEND emscripten_link_options
      "--pre-js" "${ARGS_PRE_JS}"
    )
  endif()

  # Check that binaryen does not modify debug symbols
  if(${ARGS_DEBUG} STREQUAL "SOURCE_MAPS" AND ARGS_DEBUG_VALIDATION)
    list(APPEND emscripten_link_options
      "--embed-source"
      "-sERROR_ON_WASM_CHANGES_AFTER_LINK")
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
    # Compile definition we use in source files
    target_compile_definitions(${ARGS_TARGET_NAME} PRIVATE IS_SIDE_MODULE)
  elseif(ARGS_MAIN_MODULE)
    # Compile definition we use in source files
    target_compile_definitions(${ARGS_TARGET_NAME} PRIVATE IS_MAIN_MODULE)
  endif()
  if (ARGS_COMPILE_DEFINITIONS)
    target_compile_definitions(${ARGS_TARGET_NAME} PRIVATE ${ARGS_COMPILE_DEFINITIONS})
  endif()

  # Copy JavaScript files
  sps_copy_files(${ARGS_TARGET_NAME} "JavaScript" "${ARGS_JAVASCRIPT_FILES}")

  # Update maps
  if(${ARGS_DEBUG} STREQUAL "SOURCE_MAPS")
    sps_update_source_map(${ARGS_TARGET_NAME})
  endif()

  # Display verbose information about target
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
