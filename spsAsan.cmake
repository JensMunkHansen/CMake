#[==[.rst:
*********
spsAsan
*********
  Address sanitizer for any product. Include for convenience.

  We could add the following
    -fsanitize-recover=address: Allows program continuation after an ASan error (optional).
    -fsanitize=leak: Detects memory leaks.
    -fsanitize-address-use-after-scope: Detects use-after-scope bugs.

    -fsanitize=address,undefined
#]==]

get_property(isMultiConfig GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)

if(isMultiConfig)
  if(NOT "Asan" IN_LIST CMAKE_CONFIGURATION_TYPES)
    list(APPEND CMAKE_CONFIGURATION_TYPES Asan)
  endif()
else()
  set(allowedBuildTypes Asan Debug Release RelWithDebInfo MinSizeRel)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "${allowedBuildTypes}")

  if(CMAKE_BUILD_TYPE AND NOT CMAKE_BUILD_TYPE IN_LIST allowedBuildTypes)
    message(FATAL_ERROR "Invalid build type: ${CMAKE_BUILD_TYPE}")
  endif()
endif()

# Detect clang-cl (Clang with MSVC compatibility frontend)
if (CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND MSVC)
  set(IS_CLANG_CL TRUE)
else()
  set(IS_CLANG_CL FALSE)
endif()

# Setup sanitizer flags
set(_sps_sanitize_flags "address")

set(_sps_no_omit_frame_pointer "")
if (NOT MSVC)
  set(_sps_omit_frame_pointer "-fno-omit-frame-pointer")
  if(SPS_SANITIZE_THREAD)
    set(_sps_sanitize_flags "thread")
  endif()
endif()

# Compiler/platform detection
if(MSVC AND NOT IS_CLANG_CL)
  # MSVC AddressSanitizer (only works on x64, Debug and RelWithDebInfo)
  set(_sps_sanitize_args "/fsanitize=${_sps_sanitize_flags}")
  set(_sps_linker_args "/INFERASANLIBS") # TODO: Actually use these
  set(_sps_no_omit_frame-pointer)
elseif(CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU" AND NOT IS_CLANG_CL)
  set(_sps_no_omit_frame-pointer "-fno-omit-frame-pointer")
  set(_sps_sanitize_args "${_sps_no_omit_frame-pointer} -fsanitize=${_sps_sanitize_flags}")
  set(_sps_linker_args "${_sps_sanitize_args}")
else()
  message(WARNING "Unknown compiler for ASan: ${CMAKE_CXX_COMPILER_ID}")
  set(_sps_sanitize_args "")
  set(_sps_linker_args "")
endif()

# Define macro for ASan detection
if(MSVC AND NOT IS_CLANG_CL)
  set(_sps_asan_define "/DSPS_USING_ASAN=1")
else()
  set(_sps_asan_define "-DSPS_USING_ASAN=1")
endif()

# Define config-specific flags
set(CMAKE_C_FLAGS_ASAN
  "${CMAKE_C_FLAGS_DEBUG} ${_sps_sanitize_args} ${_sps_no_omit_frame-pointer} ${_sps_asan_define}" CACHE STRING
  "Flags used by the C compiler for Asan build type or configuration." FORCE)

set(CMAKE_CXX_FLAGS_ASAN
  "${CMAKE_CXX_FLAGS_DEBUG} ${_sps_sanitize_args} ${_sps_no_omit_frame-pointer} ${_sps_asan_define}" CACHE STRING
  "Flags used by the C++ compiler for Asan build type or configuration." FORCE)

set(CMAKE_EXE_LINKER_FLAGS_ASAN
  "${CMAKE_SHARED_LINKER_FLAGS_DEBUG} ${_sps_sanitize_args}" CACHE STRING
  "Linker flags to be used to create executables for Asan build type." FORCE)

set(CMAKE_SHARED_LINKER_FLAGS_ASAN
  "${CMAKE_SHARED_LINKER_FLAGS_DEBUG} ${_sps_sanitize_args}" CACHE STRING
  "Linker lags to be used to create shared libraries for Asan build type." FORCE)

# For single-config generators, apply the flags directly
if(NOT isMultiConfig AND CMAKE_BUILD_TYPE STREQUAL "Asan")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS_ASAN}")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS_ASAN}")
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS_ASAN}")
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS_ASAN}")
endif()

if(MSVC)
  # For multi-config generators like Visual Studio, Ninja Multi-Config
  if(CMAKE_CONFIGURATION_TYPES)
    # For multi-config, CMake automatically handles Debug and Release configurations
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL" CACHE STRING "" FORCE)
  else()
    # For single-config (e.g., make, single-config generators)
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
      set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreadedDebugDLL" CACHE STRING "" FORCE)
    else()
      set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreadedDLL" CACHE STRING "" FORCE)
    endif()
  endif()
endif()

