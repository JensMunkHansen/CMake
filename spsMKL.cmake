#[==[.rst:
********
spsMKL
********
Intel MKL setup with multiple detection methods:
 - Uses Intel oneAPI CMake config if available (preferred)
 - Falls back to MKLROOT environment variable
 - Creates MKL::MKL imported target if not already defined
 - Provides sps_target_link_mkl() for easy Eigen+MKL integration

Threading:
 - Uses threaded MKL (mkl_intel_thread + iomp5) if Intel OpenMP is available
 - Falls back to sequential MKL if Intel OpenMP is not found

Usage::

  include(spsMKL)

  # Option 1: Just find MKL
  sps_find_mkl()
  target_link_libraries(myapp PRIVATE MKL::MKL)

  # Option 2: Add MKL to an Eigen target (includes EIGEN_USE_MKL_ALL)
  sps_target_link_mkl(myapp)

Requirements:
  export MKLROOT=/opt/intel/oneapi/mkl/latest  (in .bashrc)

#]==]

# Guard against multiple includes
if(DEFINED _SPS_MKL_INCLUDED)
  return()
endif()
set(_SPS_MKL_INCLUDED TRUE)

#[==[
sps_find_mkl()

Finds Intel MKL and creates MKL::MKL imported target.
Sets SPS_MKL_FOUND to TRUE if successful.
#]==]
function(sps_find_mkl)
  # Already found?
  if(TARGET MKL::MKL)
    set(SPS_MKL_FOUND TRUE PARENT_SCOPE)
    return()
  endif()

  message(STATUS "=== MKL SEARCH ===")

  # Method 1: Try Intel oneAPI CMake config first (preferred)
  find_package(MKL CONFIG QUIET)
  if(MKL_FOUND)
    message(STATUS "MKL: found via oneAPI CMake config")
    set(SPS_MKL_FOUND TRUE PARENT_SCOPE)
    return()
  endif()

  # Method 2: MKLROOT environment variable or common paths
  set(_mklroot "")
  if(DEFINED ENV{MKLROOT})
    set(_mklroot "$ENV{MKLROOT}")
  else()
    # Search common installation paths
    set(_mkl_search_paths
      /opt/intel/oneapi/mkl/latest
      /opt/intel/mkl
      $ENV{HOME}/intel/oneapi/mkl/latest
    )
    foreach(_path ${_mkl_search_paths})
      if(EXISTS "${_path}/include/mkl.h")
        set(_mklroot "${_path}")
        break()
      endif()
    endforeach()
  endif()

  if(_mklroot STREQUAL "")
    message(STATUS "MKL: NOT FOUND - set MKLROOT environment variable")
    set(SPS_MKL_FOUND FALSE PARENT_SCOPE)
    return()
  endif()

  message(STATUS "MKL: MKLROOT=${_mklroot}")

  # Verify key files exist
  if(NOT EXISTS "${_mklroot}/include/mkl.h")
    message(WARNING "MKLROOT set but mkl.h not found at ${_mklroot}/include")
    set(SPS_MKL_FOUND FALSE PARENT_SCOPE)
    return()
  endif()

  # Find the MKL libraries
  find_library(MKL_INTEL_LP64_LIB
    NAMES mkl_intel_lp64
    PATHS "${_mklroot}/lib"
    NO_DEFAULT_PATH
  )

  find_library(MKL_CORE_LIB
    NAMES mkl_core
    PATHS "${_mklroot}/lib"
    NO_DEFAULT_PATH
  )

  find_library(MKL_INTEL_THREAD_LIB
    NAMES mkl_intel_thread
    PATHS "${_mklroot}/lib"
    NO_DEFAULT_PATH
  )

  find_library(MKL_SEQUENTIAL_LIB
    NAMES mkl_sequential
    PATHS "${_mklroot}/lib"
    NO_DEFAULT_PATH
  )

  # Find Intel OpenMP (iomp5)
  set(_compiler_paths
    "${_mklroot}/../compiler/latest/lib"
    "/opt/intel/oneapi/compiler/latest/lib"
  )
  find_library(IOMP5_LIB
    NAMES iomp5
    PATHS ${_compiler_paths}
    NO_DEFAULT_PATH
  )

  if(NOT MKL_INTEL_LP64_LIB OR NOT MKL_CORE_LIB)
    message(WARNING "MKL: Could not find required libraries in ${_mklroot}/lib")
    set(SPS_MKL_FOUND FALSE PARENT_SCOPE)
    return()
  endif()

  # Create imported targets for individual libraries
  if(NOT TARGET MKL::mkl_intel_lp64)
    add_library(MKL::mkl_intel_lp64 SHARED IMPORTED)
    set_target_properties(MKL::mkl_intel_lp64 PROPERTIES
      IMPORTED_LOCATION "${MKL_INTEL_LP64_LIB}"
    )
  endif()

  if(NOT TARGET MKL::mkl_core)
    add_library(MKL::mkl_core SHARED IMPORTED)
    set_target_properties(MKL::mkl_core PROPERTIES
      IMPORTED_LOCATION "${MKL_CORE_LIB}"
    )
  endif()

  # Decide threading: use Intel OpenMP if available, else sequential
  set(_use_threaded FALSE)
  if(MKL_INTEL_THREAD_LIB AND IOMP5_LIB)
    set(_use_threaded TRUE)
  endif()

  if(_use_threaded)
    message(STATUS "MKL: Using threaded MKL with Intel OpenMP")

    if(NOT TARGET MKL::mkl_intel_thread)
      add_library(MKL::mkl_intel_thread SHARED IMPORTED)
      set_target_properties(MKL::mkl_intel_thread PROPERTIES
        IMPORTED_LOCATION "${MKL_INTEL_THREAD_LIB}"
      )
    endif()

    if(NOT TARGET MKL::iomp5)
      add_library(MKL::iomp5 SHARED IMPORTED)
      set_target_properties(MKL::iomp5 PROPERTIES
        IMPORTED_LOCATION "${IOMP5_LIB}"
      )
    endif()

    # Create the main MKL::MKL interface target
    add_library(MKL::MKL INTERFACE IMPORTED)
    set_target_properties(MKL::MKL PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${_mklroot}/include"
      INTERFACE_LINK_LIBRARIES "MKL::mkl_intel_lp64;MKL::mkl_intel_thread;MKL::mkl_core;MKL::iomp5;Threads::Threads;m;dl"
    )
  else()
    message(STATUS "MKL: Using sequential MKL (Intel OpenMP not found)")

    if(NOT TARGET MKL::mkl_sequential)
      add_library(MKL::mkl_sequential SHARED IMPORTED)
      set_target_properties(MKL::mkl_sequential PROPERTIES
        IMPORTED_LOCATION "${MKL_SEQUENTIAL_LIB}"
      )
    endif()

    # Create the main MKL::MKL interface target
    add_library(MKL::MKL INTERFACE IMPORTED)
    set_target_properties(MKL::MKL PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${_mklroot}/include"
      INTERFACE_LINK_LIBRARIES "MKL::mkl_intel_lp64;MKL::mkl_sequential;MKL::mkl_core;Threads::Threads;m;dl"
    )
  endif()

  # Need Threads
  find_package(Threads QUIET)

  # Export canonical targets
  foreach(tgt mkl_intel_lp64 mkl_core mkl_intel_thread mkl_sequential iomp5)
    if(TARGET MKL::${tgt})
      message(STATUS "MKL target: MKL::${tgt}")
    endif()
  endforeach()

  set(SPS_MKL_FOUND TRUE PARENT_SCOPE)
endfunction()

#[==[
sps_target_link_mkl(<target>)

Links MKL to target and enables Eigen MKL integration.
Adds EIGEN_USE_MKL_ALL compile definition.
#]==]
function(sps_target_link_mkl target)
  # Find MKL if not already done
  sps_find_mkl()

  if(NOT TARGET MKL::MKL)
    message(FATAL_ERROR "sps_target_link_mkl: MKL not found. Set MKLROOT environment variable.")
  endif()

  target_link_libraries(${target} PRIVATE MKL::MKL)
  target_compile_definitions(${target} PRIVATE EIGEN_USE_MKL_ALL)

  message(STATUS "MKL linked to target: ${target}")
endfunction()
