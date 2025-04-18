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

# Setup sanitizer flags
if(SPS_SANITIZE_THREAD)
  set(_sps_sanitize_flags "thread")
else()
  set(_sps_sanitize_flags "address")
endif()

# Compiler/platform detection
if(MSVC)
  # MSVC AddressSanitizer (only works on x64)
  set(_sps_sanitize_args "/fsanitize=${_sps_sanitize_flags}")
  set(_sps_linker_args "/INFERASANLIBS")
elseif(CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU")
  set(_sps_sanitize_args "-fno-omit-frame-pointer -fsanitize=${_sps_sanitize_flags}")
  set(_sps_linker_args "${_sps_sanitize_args}")
else()
  message(WARNING "Unknown compiler for ASan: ${CMAKE_CXX_COMPILER_ID}")
  set(_sps_sanitize_args "")
  set(_sps_linker_args "")
endif()

# Define config-specific flags
set(CMAKE_C_FLAGS_ASAN
  "${CMAKE_C_FLAGS_DEBUG} ${_sps_sanitize_args} -fno-omit-frame-pointer" CACHE STRING
  "Flags used by the C compiler for Asan build type or configuration." FORCE)

set(CMAKE_CXX_FLAGS_ASAN
  "${CMAKE_CXX_FLAGS_DEBUG} ${_sps_sanitize_args} -fno-omit-frame-pointer" CACHE STRING
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
  # Avoid conflicting runtime: force dynamic CRT for ASan
  set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreadedDLL" CACHE STRING "" FORCE)
endif()

# On window
# ASan is officially supported starting with VS 2019 version 16.9, but:
# It only works with x64 builds, not x86.
# It requires /fsanitize=address instead of -fsanitize=address.
# You must disable certain runtime features like /RTC1, /Gy, etc.
# Linking must be done with /INFERASANLIBS.
