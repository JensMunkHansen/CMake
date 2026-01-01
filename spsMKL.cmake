#[==[.rst:
********
spsMKL
********
Intel MKL setup with multiple detection methods:
 - Uses Intel oneAPI CMake config if available (preferred)
 - Falls back to MKLROOT environment variable / common install paths
 - Creates imported targets that model Windows runtime DLLs correctly:
     - MKL::mkl_rt   (mkl_rt.lib + mkl_rt.dll)    [Windows, dynamic MKL]
     - MKL::iomp5    (libiomp5md.lib + libiomp5md.dll) [Windows, threaded]
   so consumers can copy runtimes elsewhere using named targets.

 - Creates MKL::MKL umbrella INTERFACE target for linking.

Threading:
 - Uses threaded MKL if Intel OpenMP is found
 - Falls back to sequential MKL if Intel OpenMP is not found

Exports (kept for external use):
 - IOMP5_LIB       (import library path)
 - IOMP5_LIB_DIR   (directory of import library)

Optional exports (for convenience):
 - IOMP5_DLL / IOMP5_DLL_DIR (Windows runtime DLL)
 - MKL_DLL / MKL_DLL_DIR     (Windows runtime DLL)

#]==]

# Guard against multiple includes
if(DEFINED _SPS_MKL_INCLUDED)
  return()
endif()
set(_SPS_MKL_INCLUDED TRUE)

# -----------------------------
# Options
# -----------------------------
option(SPS_MKL_DYNAMIC "Manual fallback: use MKL dynamic runtime (mkl_rt) on Windows" ON)

# -----------------------------
# Helpers
# -----------------------------
function(_sps_add_imported_shared tgt implib dll)
  if(NOT TARGET ${tgt})
    add_library(${tgt} SHARED IMPORTED GLOBAL)
  endif()

  set_target_properties(${tgt} PROPERTIES
    IMPORTED_IMPLIB "${implib}"
    IMPORTED_LOCATION "${dll}"
    # multi-config friendliness
    MAP_IMPORTED_CONFIG_RELWITHDEBINFO Release
    MAP_IMPORTED_CONFIG_MINSIZEREL Release
  )
endfunction()

#[==[
_sps_find_iomp5(<mklroot>)

Find Intel OpenMP import library.
Exports IOMP5_LIB and IOMP5_LIB_DIR in CACHE (used outside this file).

NOTE: On Windows, we prefer libiomp5md (DLL runtime import lib).
#]==]
function(_sps_find_iomp5 mklroot)
  if(WIN32)
    # Prefer DLL-based runtime import lib
    set(_iomp5_names libiomp5md)
    set(_compiler_paths
      "${mklroot}/../../compiler/latest/lib"
      "${mklroot}/../../compiler/latest/windows/compiler/lib/intel64_win"
    )
  else()
    set(_iomp5_names iomp5)

    # oneAPI layouts vary; include the common subdirs.
    set(_oneapi_guess "${mklroot}/../..") # .../oneapi
    set(_compiler_root_candidates
      "${_oneapi_guess}/compiler/latest"
      "/opt/intel/oneapi/compiler/latest"
      "$ENV{ONEAPI_ROOT}/compiler/latest"
    )

    set(_compiler_paths "")
    foreach(_cr ${_compiler_root_candidates})
      if(EXISTS "${_cr}")
        list(APPEND _compiler_paths
          "${_cr}/lib"
          "${_cr}/lib/intel64"
          "${_cr}/lib/intel64_lin"
          "${_cr}/linux/compiler/lib/intel64_lin"
          "${_cr}/compiler/lib/intel64_lin"
          "${_cr}/lib/x64"
        )
      endif()
    endforeach()
  endif()

  find_library(_iomp5_lib NAMES ${_iomp5_names}
    PATHS ${_compiler_paths}
    NO_DEFAULT_PATH
  )

  if(_iomp5_lib)
    get_filename_component(_iomp5_dir "${_iomp5_lib}" DIRECTORY)
    set(IOMP5_LIB "${_iomp5_lib}" CACHE FILEPATH "Intel OpenMP library" FORCE)
    set(IOMP5_LIB_DIR "${_iomp5_dir}" CACHE PATH "Intel OpenMP library directory" FORCE)
    message(STATUS "  iomp5: ${IOMP5_LIB}")
  else()
    message(STATUS "  iomp5: not found (searched: ${_compiler_paths})")
  endif()

  unset(_iomp5_lib CACHE)
endfunction()

#[==[
_sps_find_iomp5_dll(<mklroot>)

Windows-only: locate libiomp5md.dll so MKL::iomp5 can model a real runtime DLL.
Exports IOMP5_DLL and IOMP5_DLL_DIR in CACHE (optional).
#]==]
function(_sps_find_iomp5_dll mklroot)
  if(NOT WIN32)
    return()
  endif()

  # Common oneAPI compiler redist locations (vary between installs)
  set(_candidates
    "${mklroot}/../../compiler/latest/windows/redist/intel64_win/compiler"
    "${mklroot}/../../compiler/latest/redist/intel64_win/compiler"
    "${mklroot}/../../compiler/latest/bin"
    "${IOMP5_LIB_DIR}"
  )

  find_file(_iomp5_dll NAMES libiomp5md.dll
    PATHS ${_candidates}
    NO_DEFAULT_PATH
  )

  if(_iomp5_dll)
    get_filename_component(_dll_dir "${_iomp5_dll}" DIRECTORY)
    set(IOMP5_DLL "${_iomp5_dll}" CACHE FILEPATH "Intel OpenMP runtime DLL" FORCE)
    set(IOMP5_DLL_DIR "${_dll_dir}" CACHE PATH "Intel OpenMP runtime DLL directory" FORCE)
    message(STATUS "  iomp5 runtime dll: ${IOMP5_DLL}")
  endif()

  unset(_iomp5_dll CACHE)
endfunction()

#[==[
sps_find_mkl()

Finds Intel MKL and creates:
 - MKL::MKL (umbrella INTERFACE target to link)
 - Windows dynamic fallback:
     - MKL::mkl_rt (SHARED IMPORTED, has .dll location)
     - MKL::iomp5  (SHARED IMPORTED, has .dll location, only if threaded)

Also preserves IOMP5_LIB / IOMP5_LIB_DIR exports used elsewhere.
#]==]
function(sps_find_mkl)
  # Already found?
  if(TARGET MKL::MKL)
    set(SPS_MKL_FOUND TRUE PARENT_SCOPE)
    return()
  endif()

  message(STATUS "=== MKL SEARCH ===")

  find_package(Threads QUIET)

  # ------------------------------------------------------------
  # Method 1: Intel oneAPI CMake config package (preferred)
  # ------------------------------------------------------------
  find_package(MKL CONFIG QUIET)
  if(MKL_FOUND)
    message(STATUS "MKL: found via oneAPI CMake config")
    message(STATUS "  MKL_THREADING: ${MKL_THREADING}")

    if(MKL_THREADING STREQUAL "intel_thread" OR MKL_THREADING STREQUAL "tbb_thread" OR MKL_THREADING STREQUAL "gnu_thread")
      set(SPS_MKL_THREADED TRUE CACHE BOOL "MKL uses threaded backend" FORCE)
      message(STATUS "  MKL mode: threaded")

      # IMPORTANT: export iomp5 paths for consumers (esp. Ceres) when using intel_thread.
      if(MKL_THREADING STREQUAL "intel_thread")
        if(MKL_ROOT)
          _sps_export_iomp5_for_consumers("${MKL_ROOT}")
        elseif(DEFINED ENV{MKLROOT})
          _sps_export_iomp5_for_consumers("$ENV{MKLROOT}")
        else()
          # best-effort: try a typical location
          _sps_export_iomp5_for_consumers("/opt/intel/oneapi/mkl/latest")
        endif()
      endif()
    else()
      set(SPS_MKL_THREADED FALSE CACHE BOOL "MKL uses threaded backend" FORCE)
      message(STATUS "  MKL mode: sequential")
    endif()

    set(SPS_MKL_FOUND TRUE PARENT_SCOPE)
    return()
  endif()

  # ------------------------------------------------------------
  # Method 2: MKLROOT environment variable or common paths
  # ------------------------------------------------------------
  set(_mklroot "")
  if(DEFINED ENV{MKLROOT})
    set(_mklroot "$ENV{MKLROOT}")
  else()
    if(WIN32)
      set(_mkl_search_paths
        "$ENV{ONEAPI_ROOT}/mkl/latest"
        "C:/Program Files (x86)/Intel/oneAPI/mkl/latest"
      )
    else()
      set(_mkl_search_paths
        /opt/intel/oneapi/mkl/latest
        /opt/intel/mkl
        $ENV{HOME}/intel/oneapi/mkl/latest
      )
    endif()

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

  if(NOT EXISTS "${_mklroot}/include/mkl.h")
    message(WARNING "MKLROOT set but mkl.h not found at ${_mklroot}/include")
    set(SPS_MKL_FOUND FALSE PARENT_SCOPE)
    return()
  endif()

  # Determine lib paths
  if(WIN32)
    set(_mkl_lib_paths "${_mklroot}/lib/intel64" "${_mklroot}/lib")
  else()
    set(_mkl_lib_paths "${_mklroot}/lib")
  endif()

  # Find component libs (needed for non-Windows and for static/manual)
  foreach(_pair
      "INTEL_ILP64:mkl_intel_ilp64"
      "CORE:mkl_core"
      "INTEL_THREAD:mkl_intel_thread"
      "SEQUENTIAL:mkl_sequential")
    string(REPLACE ":" ";" _parts "${_pair}")
    list(GET _parts 0 _suffix)
    list(GET _parts 1 _name)
    find_library(MKL_${_suffix}_LIB
      NAMES ${_name}
      PATHS ${_mkl_lib_paths}
      NO_DEFAULT_PATH
    )
  endforeach()

  # Find iomp5 import lib + (Windows) dll, exporting your cache vars
  _sps_find_iomp5("${_mklroot}")
  _sps_find_iomp5_dll("${_mklroot}")

  # Decide threading: use Intel OpenMP if available, else sequential
  set(_use_threaded FALSE)
  if(MKL_INTEL_THREAD_LIB AND IOMP5_LIB)
    set(_use_threaded TRUE)
  endif()

  # Platform system libs
  if(WIN32)
    set(_sys_libs "Threads::Threads")
  else()
    set(_sys_libs "Threads::Threads;m;dl")
  endif()

  # ------------------------------------------------------------
  # Create targets
  # ------------------------------------------------------------

  # --- Windows dynamic fallback: create MKL::mkl_rt and optional MKL::iomp5 ---
  if(WIN32 AND SPS_MKL_DYNAMIC)
    set(_mkl_rt_implib "${_mklroot}/lib/intel64/mkl_rt.lib")
    set(_mkl_rt_dll    "${_mklroot}/redist/intel64/mkl_rt.dll")

    if(NOT EXISTS "${_mkl_rt_implib}")
      message(FATAL_ERROR "MKL: mkl_rt import library not found: ${_mkl_rt_implib}")
    endif()
    if(NOT EXISTS "${_mkl_rt_dll}")
      message(FATAL_ERROR "MKL: mkl_rt runtime DLL not found: ${_mkl_rt_dll}")
    endif()

    # Export (optional convenience)
    get_filename_component(_mkl_dll_dir "${_mkl_rt_dll}" DIRECTORY)
    set(MKL_DLL "${_mkl_rt_dll}" CACHE FILEPATH "MKL runtime DLL" FORCE)
    set(MKL_DLL_DIR "${_mkl_dll_dir}" CACHE PATH "MKL runtime DLL directory" FORCE)

    _sps_add_imported_shared(MKL::mkl_rt "${_mkl_rt_implib}" "${_mkl_rt_dll}")

    if(_use_threaded)
      message(STATUS "MKL: Using threaded MKL with Intel OpenMP")
      set(SPS_MKL_THREADED TRUE CACHE BOOL "MKL uses threaded backend" FORCE)

      # Only create MKL::iomp5 as a runtime-carrying target if we found the DLL.
      if(IOMP5_LIB AND IOMP5_DLL)
        _sps_add_imported_shared(MKL::iomp5 "${IOMP5_LIB}" "${IOMP5_DLL}")
      else()
        message(WARNING "MKL: Threaded MKL requested but iomp5 runtime DLL not found; MKL::iomp5 target will not be created (runtime copy via targets may miss it).")
      endif()
    else()
      message(STATUS "MKL: Using sequential MKL (Intel OpenMP not found)")
      set(SPS_MKL_THREADED FALSE CACHE BOOL "MKL uses threaded backend" FORCE)
    endif()

    add_library(MKL::MKL INTERFACE IMPORTED)
    if(_use_threaded AND TARGET MKL::iomp5)
      set_target_properties(MKL::MKL PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${_mklroot}/include"
        INTERFACE_COMPILE_DEFINITIONS "MKL_ILP64"
        INTERFACE_LINK_LIBRARIES "MKL::mkl_rt;MKL::iomp5;${_sys_libs}"
      )
    else()
      set_target_properties(MKL::MKL PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${_mklroot}/include"
        INTERFACE_COMPILE_DEFINITIONS "MKL_ILP64"
        INTERFACE_LINK_LIBRARIES "MKL::mkl_rt;${_sys_libs}"
      )
    endif()

  else()
    # --- Non-Windows (and/or Windows manual static): component libraries ---
    if(NOT MKL_INTEL_ILP64_LIB OR NOT MKL_CORE_LIB)
      message(WARNING "MKL: Could not find required libraries in ${_mklroot}/lib")
      set(SPS_MKL_FOUND FALSE PARENT_SCOPE)
      return()
    endif()

    if(NOT TARGET MKL::mkl_intel_ilp64)
      add_library(MKL::mkl_intel_ilp64 UNKNOWN IMPORTED)
      set_target_properties(MKL::mkl_intel_ilp64 PROPERTIES
        IMPORTED_LOCATION "${MKL_INTEL_ILP64_LIB}"
        INTERFACE_COMPILE_DEFINITIONS "MKL_ILP64"
      )
    endif()

    if(NOT TARGET MKL::mkl_core)
      add_library(MKL::mkl_core UNKNOWN IMPORTED)
      set_target_properties(MKL::mkl_core PROPERTIES
        IMPORTED_LOCATION "${MKL_CORE_LIB}"
      )
    endif()

    if(_use_threaded)
      message(STATUS "MKL: Using threaded MKL with Intel OpenMP")
      set(SPS_MKL_THREADED TRUE CACHE BOOL "MKL uses threaded backend" FORCE)

      if(NOT TARGET MKL::mkl_intel_thread)
        add_library(MKL::mkl_intel_thread UNKNOWN IMPORTED)
        set_target_properties(MKL::mkl_intel_thread PROPERTIES
          IMPORTED_LOCATION "${MKL_INTEL_THREAD_LIB}"
        )
      endif()

      if(NOT TARGET MKL::iomp5)
        add_library(MKL::iomp5 UNKNOWN IMPORTED)
        set_target_properties(MKL::iomp5 PROPERTIES
          IMPORTED_LOCATION "${IOMP5_LIB}"
        )
      endif()

      add_library(MKL::MKL INTERFACE IMPORTED)
      set_target_properties(MKL::MKL PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${_mklroot}/include"
        INTERFACE_COMPILE_DEFINITIONS "MKL_ILP64"
        INTERFACE_LINK_LIBRARIES "MKL::mkl_intel_ilp64;MKL::mkl_intel_thread;MKL::mkl_core;MKL::iomp5;${_sys_libs}"
      )
    else()
      message(STATUS "MKL: Using sequential MKL (Intel OpenMP not found)")
      set(SPS_MKL_THREADED FALSE CACHE BOOL "MKL uses threaded backend" FORCE)

      if(NOT TARGET MKL::mkl_sequential)
        add_library(MKL::mkl_sequential UNKNOWN IMPORTED)
        set_target_properties(MKL::mkl_sequential PROPERTIES
          IMPORTED_LOCATION "${MKL_SEQUENTIAL_LIB}"
        )
      endif()

      add_library(MKL::MKL INTERFACE IMPORTED)
      set_target_properties(MKL::MKL PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${_mklroot}/include"
        INTERFACE_COMPILE_DEFINITIONS "MKL_ILP64"
        INTERFACE_LINK_LIBRARIES "MKL::mkl_intel_ilp64;MKL::mkl_sequential;MKL::mkl_core;${_sys_libs}"
      )
    endif()
  endif()

  foreach(tgt mkl_rt iomp5 mkl_intel_ilp64 mkl_core mkl_intel_thread mkl_sequential)
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
  sps_find_mkl()

  if(NOT TARGET MKL::MKL)
    message(FATAL_ERROR "sps_target_link_mkl: MKL not found. Set MKLROOT environment variable.")
  endif()

  target_link_libraries(${target} PRIVATE MKL::MKL)
  target_compile_definitions(${target} PRIVATE EIGEN_USE_MKL_ALL)

  message(STATUS "MKL linked to target: ${target}")
endfunction()

# Returns a list variable name filled with OpenMP-disabling args when
# using threaded MKL (Intel OpenMP). Intended for ExternalProject_Add CMAKE_ARGS.
function(sps_ep_args_disable_openmp out_var)
  set(_args "")
  if(USE_MKL AND SPS_MKL_THREADED)
    # Prevent projects from finding GCC OpenMP (libgomp) and mixing runtimes.
    list(APPEND _args
      "-DCMAKE_DISABLE_FIND_PACKAGE_OpenMP:BOOL=TRUE"
    )
  endif()
  set(${out_var} "${_args}" PARENT_SCOPE)
endfunction()


function(sps_mkl_verify_no_mixed_openmp_ldd target)
  if(NOT UNIX OR APPLE)
    return()
  endif()

  if(NOT TARGET ${target})
    message(FATAL_ERROR "sps_mkl_verify_no_mixed_openmp_ldd: '${target}' is not a target")
  endif()

  get_target_property(_type ${target} TYPE)
  if(NOT _type STREQUAL "EXECUTABLE" AND NOT _type STREQUAL "SHARED_LIBRARY" AND NOT _type STREQUAL "MODULE_LIBRARY")
    return()
  endif()

  add_custom_command(TARGET ${target} POST_BUILD
    COMMAND /bin/sh -c
      "set -eu;
       f=\"$<TARGET_FILE:${target}>\";
       out=\"\$(ldd \"$f\" 2>/dev/null || true)\";

       # Pull out resolved paths from ldd lines like:
       #   libiomp5.so => /opt/intel/.../libiomp5.so (0x...)
       #   libgomp.so.1 => /lib/.../libgomp.so.1 (0x...)
       # Also handle direct paths lines like:
       #   /lib64/ld-linux-x86-64.so.2 (0x...)
       paths=\"\$(printf '%s\n' \"$out\" | awk '
         /=>/ { print $3; next }
         $1 ~ /^\\// { print $1; next }
       ' | sort -u)\";

       has_iomp=0; has_gomp=0;

       # Check the main ldd output (names) and also resolved paths.
       printf '%s\n' \"$out\"   | grep -q 'libiomp5\\.so' && has_iomp=1 || true;
       printf '%s\n' \"$out\"   | grep -q 'libgomp\\.so'  && has_gomp=1 || true;
       printf '%s\n' \"$paths\" | grep -q 'libiomp5\\.so' && has_iomp=1 || true;
       printf '%s\n' \"$paths\" | grep -q 'libgomp\\.so'  && has_gomp=1 || true;

       if [ \"\$has_iomp\" -eq 1 ] && [ \"\$has_gomp\" -eq 1 ]; then
         echo 'ERROR: Mixed OpenMP runtimes detected (libiomp5 + libgomp) for:' \"$f\" 1>&2;
         echo '--- ldd ---' 1>&2;
         echo \"$out\" 1>&2;
         echo '--- resolved deps ---' 1>&2;
         echo \"$paths\" 1>&2;
         exit 1;
       fi"
    VERBATIM
  )
endfunction()

function(sps_mkl_verify_no_mixed_openmp_for_dir dir)
  if(NOT UNIX OR APPLE)
    return()
  endif()

  add_custom_target(verify_openmp_plugins ALL
    COMMAND /bin/sh -c
      "set -eu;
       for f in ${dir}/*.so; do
         [ -e \"$f\" ] || continue;
         out=\"\$(ldd \"$f\" 2>/dev/null || true)\";
         echo \"$out\" | grep -q 'libiomp5\\.so' && has_iomp=1 || has_iomp=0;
         echo \"$out\" | grep -q 'libgomp\\.so'  && has_gomp=1 || has_gomp=0;
         if [ \$has_iomp -eq 1 ] && [ \$has_gomp -eq 1 ]; then
           echo \"ERROR: Mixed OpenMP runtimes in plugin: $f\" 1>&2;
           echo \"$out\" 1>&2;
           exit 1;
         fi;
       done"
    VERBATIM
  )
endfunction()
