#[==[.rst:
********
spsMKL
********
Intel MKL setup with multiple detection methods:
 - Uses Intel oneAPI CMake config if available (preferred)
 - Falls back to MKLROOT environment variable
 - Creates MKL::MKL imported target if not already defined
 - Provides sps_target_link_mkl() for easy Eigen+MKL integration

Usage::

  include(spsMKL)

  # Option 1: Just find MKL
  sps_find_mkl()
  target_link_libraries(myapp PRIVATE MKL::MKL)

  # Option 2: Add MKL to an Eigen target (includes EIGEN_USE_MKL_ALL)
  sps_target_link_mkl(myapp)

Requirements:
  source /opt/intel/oneapi/setvars.sh  (before running cmake)

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

  # Method 1: MKLROOT environment variable (if setvars.sh was sourced)
  if(DEFINED ENV{MKLROOT})
    set(MKLROOT "$ENV{MKLROOT}")
    message(STATUS "✅ MKL found via MKLROOT environment")
    message(STATUS "   MKLROOT: ${MKLROOT}")

    # Verify key files exist
    if(NOT EXISTS "${MKLROOT}/include/mkl.h")
      message(WARNING "MKLROOT set but mkl.h not found at ${MKLROOT}/include")
      set(SPS_MKL_FOUND FALSE PARENT_SCOPE)
      return()
    endif()

    # Create imported target
    add_library(MKL::MKL INTERFACE IMPORTED)

    set_target_properties(MKL::MKL PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${MKLROOT}/include"
    )

    # Determine library names based on platform and threading
    # Using LP64 interface with Intel OpenMP threading (most common)
    if(WIN32)
      set(_mkl_libs
        "${MKLROOT}/lib/mkl_intel_lp64.lib"
        "${MKLROOT}/lib/mkl_intel_thread.lib"
        "${MKLROOT}/lib/mkl_core.lib"
      )
    else()
      set(_mkl_libs
        "${MKLROOT}/lib/libmkl_intel_lp64.so"
        "${MKLROOT}/lib/libmkl_intel_thread.so"
        "${MKLROOT}/lib/libmkl_core.so"
      )
    endif()

    # Add OpenMP runtime and system libs
    set_target_properties(MKL::MKL PROPERTIES
      INTERFACE_LINK_LIBRARIES "${_mkl_libs};iomp5;pthread;m;dl"
    )

    set(SPS_MKL_FOUND TRUE PARENT_SCOPE)
    return()
  endif()

  # Method 2: Search common installation paths
  set(_mkl_search_paths
    /opt/intel/oneapi/mkl/latest
    /opt/intel/mkl
    $ENV{HOME}/intel/oneapi/mkl/latest
    "C:/Program Files (x86)/Intel/oneAPI/mkl/latest"
  )

  foreach(_path ${_mkl_search_paths})
    if(EXISTS "${_path}/include/mkl.h")
      set(MKLROOT "${_path}")
      message(STATUS "✅ MKL found at common path")
      message(STATUS "   MKLROOT: ${MKLROOT}")

      # Create imported target
      add_library(MKL::MKL INTERFACE IMPORTED)
      set_target_properties(MKL::MKL PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${MKLROOT}/include"
      )

      if(WIN32)
        set(_mkl_libs
          "${MKLROOT}/lib/mkl_intel_lp64.lib"
          "${MKLROOT}/lib/mkl_intel_thread.lib"
          "${MKLROOT}/lib/mkl_core.lib"
        )
      else()
        set(_mkl_libs
          "${MKLROOT}/lib/libmkl_intel_lp64.so"
          "${MKLROOT}/lib/libmkl_intel_thread.so"
          "${MKLROOT}/lib/libmkl_core.so"
        )
        # Find OpenMP runtime - check oneAPI compiler location
        if(EXISTS "/opt/intel/oneapi/compiler/latest/lib/libiomp5.so")
          list(APPEND _mkl_libs "/opt/intel/oneapi/compiler/latest/lib/libiomp5.so")
        else()
          list(APPEND _mkl_libs "iomp5")
        endif()
      endif()

      set_target_properties(MKL::MKL PROPERTIES
        INTERFACE_LINK_LIBRARIES "${_mkl_libs};pthread;m;dl"
      )

      set(SPS_MKL_FOUND TRUE PARENT_SCOPE)
      return()
    endif()
  endforeach()

  # Method 3: Intel oneAPI CMake config (fallback - often broken)
  find_package(MKL CONFIG QUIET)
  if(MKL_FOUND)
    message(STATUS "✅ MKL found via oneAPI CMake config")
    message(STATUS "   MKL_ROOT: ${MKL_ROOT}")
    set(SPS_MKL_FOUND TRUE PARENT_SCOPE)
    return()
  endif()

  # Not found
  message(STATUS "❌ MKL NOT FOUND")
  message(STATUS "   Install Intel oneAPI MKL or set MKLROOT environment variable")
  set(SPS_MKL_FOUND FALSE PARENT_SCOPE)
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
    message(FATAL_ERROR "sps_target_link_mkl: MKL not found. Run: source /opt/intel/oneapi/setvars.sh")
  endif()

  target_link_libraries(${target} PRIVATE MKL::MKL)
  target_compile_definitions(${target} PRIVATE EIGEN_USE_MKL_ALL)

  message(STATUS "MKL linked to target: ${target}")
endfunction()
