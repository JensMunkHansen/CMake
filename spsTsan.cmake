#[==[.rst:
*********
spsTsan
*********
  Thread sanitizer for any product.

  ThreadSanitizer (TSAN) detects data races and other threading bugs.
  This is particularly useful for detecting issues like the std::vector<bool>
  race condition that was fixed in VoxelationUpdateVolume.cpp.

  On Linux: This works for GCC and Clang (but NOT on WSL due to compatibility issues)

  On Windows: TSAN is NOT supported by MSVC.
   - Only available with Clang on Linux/Mac
   - Cannot be combined with AddressSanitizer (Asan)

  Include this file to enable thread sanitizer builds.

  Usage:
    cmake --preset linux-gcc -DCMAKE_BUILD_TYPE=Tsan
    cmake --build build/linux-gcc --config Tsan
    ctest --test-dir build/linux-gcc -C Tsan

  Note: Automatically disabled on WSL. Use real Linux for TSAN.
#]==]

# Detect WSL and disable TSAN if running on WSL
set(IS_WSL FALSE)
if(UNIX AND NOT APPLE)
  if(EXISTS "/proc/version")
    file(READ "/proc/version" PROC_VERSION)
    string(FIND "${PROC_VERSION}" "microsoft" WSL_FOUND)
    string(FIND "${PROC_VERSION}" "WSL" WSL_FOUND2)
    if(NOT WSL_FOUND EQUAL -1 OR NOT WSL_FOUND2 EQUAL -1)
      set(IS_WSL TRUE)
    endif()
  endif()
endif()

if(IS_WSL)
  message(STATUS "ThreadSanitizer (TSAN) disabled - WSL detected. Use real Linux for race detection.")
  return()
endif()

# ThreadSanitizer is only supported on Clang and GCC (not MSVC/ClangCL)
if(NOT (CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU" AND NOT MSVC))
  message(STATUS "ThreadSanitizer (TSAN) not supported with ${CMAKE_CXX_COMPILER_ID} on this platform")
  return()
endif()

get_property(isMultiConfig GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)

if(isMultiConfig)
  if(NOT "Tsan" IN_LIST CMAKE_CONFIGURATION_TYPES)
    list(APPEND CMAKE_CONFIGURATION_TYPES Tsan)
  endif()
else()
  set(allowedBuildTypes Tsan Debug Release RelWithDebInfo MinSizeRel Asan)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "${allowedBuildTypes}")

  if(CMAKE_BUILD_TYPE AND NOT CMAKE_BUILD_TYPE IN_LIST allowedBuildTypes)
    message(FATAL_ERROR "Invalid build type: ${CMAKE_BUILD_TYPE}")
  endif()
endif()

set(_ts_sanitize_flags "thread")
set(_ts_sanitize_args "-fno-omit-frame-pointer -fsanitize=${_ts_sanitize_flags}")
set(_ts_linker_args "${_ts_sanitize_args}")

# Define config-specific flags
set(CMAKE_C_FLAGS_TSAN
  "${CMAKE_C_FLAGS_DEBUG} ${_ts_sanitize_args}" CACHE STRING
  "Flags used by the C compiler for Tsan build type or configuration." FORCE)

set(CMAKE_CXX_FLAGS_TSAN
  "${CMAKE_CXX_FLAGS_DEBUG} ${_ts_sanitize_args}" CACHE STRING
  "Flags used by the C++ compiler for Tsan build type or configuration." FORCE)

set(CMAKE_EXE_LINKER_FLAGS_TSAN
  "${CMAKE_SHARED_LINKER_FLAGS_DEBUG} ${_ts_linker_args}" CACHE STRING
  "Linker flags to be used to create executables for Tsan build type." FORCE)

set(CMAKE_SHARED_LINKER_FLAGS_TSAN
  "${CMAKE_SHARED_LINKER_FLAGS_DEBUG} ${_ts_linker_args}" CACHE STRING
  "Linker flags to be used to create shared libraries for Tsan build type." FORCE)

# For single-config generators, apply the flags directly
if(NOT isMultiConfig AND CMAKE_BUILD_TYPE STREQUAL "Tsan")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS_TSAN}")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS_TSAN}")
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS_TSAN}")
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS_TSAN}")
endif()

message(STATUS "ThreadSanitizer (TSAN) support enabled")
