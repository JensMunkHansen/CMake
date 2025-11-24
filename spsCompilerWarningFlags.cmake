#[==[.rst:
*********
spsCompilerWarnings
*********
  Compiler warnings for cross-platform builds. Appends to the interface target sps_build (if present)
#]==]

# TODO: Enforce synchronization

# This module requires CMake 3.19 features (the `CheckCompilerFlag`
# module). Just skip it for older CMake versions.
if (CMAKE_VERSION VERSION_LESS "3.19")
  return ()
endif ()

include(CheckCompilerFlag)

#[==[.rst:

.. cmake:command:: _sps_add_flag

#]==]
function (_sps_add_flag flag)
  foreach (lang IN LISTS ARGN)
    # Skip GCC/Clang-style warning flags on native MSVC (they get misinterpreted)
    # For example, -Wall becomes /Wall which enables ALL warnings including very noisy ones
    # ClangCL is handled separately via _sps_add_clangcl_flag()
    if (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC" AND flag MATCHES "^-W")
      # Skip this flag for native MSVC
      continue()
    endif()

    check_compiler_flag("${lang}" "${flag}" "sps_have_compiler_flag-${lang}-${flag}")
    if (sps_have_compiler_flag-${lang}-${flag})
      if (TARGET build)
	target_compile_options(build
          INTERFACE
          "$<BUILD_INTERFACE:$<$<COMPILE_LANGUAGE:${lang}>:${flag}>>")
      endif ()
    endif()
  endforeach ()
endfunction ()

#[==[.rst:

.. cmake:command:: _sps_add_clangcl_flag

  Apply Clang-style warning flags to ClangCL using /clang: prefix.
  ClangCL supports Clang warning flags but requires Microsoft command-line syntax.
  This function bypasses check_compiler_flag since /clang: prefix doesn't work with it.

#]==]
function (_sps_add_clangcl_flag flag)
  foreach (lang IN LISTS ARGN)
    if (CMAKE_CXX_COMPILER_ID MATCHES "Clang" AND MSVC)
      if (TARGET build)
        target_compile_options(build
          INTERFACE
          "$<BUILD_INTERFACE:$<$<COMPILE_LANGUAGE:${lang}>:/clang:${flag}>>")
      endif ()
    endif()
  endforeach ()
endfunction ()

#[==[.rst:

.. cmake:command:: _sps_add_flag_all

  Apply warning flags to all platforms: Unix (GCC/Clang) and Windows (ClangCL).
  This is a convenience wrapper that calls both _sps_add_flag() and _sps_add_clangcl_flag().

#]==]
function (_sps_add_flag_all flag)
  _sps_add_flag(${flag} ${ARGN})
  _sps_add_clangcl_flag(${flag} ${ARGN})
endfunction ()

option(SPS_ENABLE_EXTRA_BUILD_WARNINGS "Enable extra build warnings" ON)
mark_as_advanced(SPS_ENABLE_EXTRA_BUILD_WARNINGS)

check_compiler_flag(C "-Weverything" sps_have_compiler_flag_Weverything)
include(CMakeDependentOption)
cmake_dependent_option(SPS_ENABLE_EXTRA_BUILD_WARNINGS_EVERYTHING "Enable *all* warnings (except known problems)" OFF
  "SPS_ENABLE_EXTRA_BUILD_WARNINGS;sps_have_compiler_flag_Weverything" OFF)
mark_as_advanced(SPS_ENABLE_EXTRA_BUILD_WARNINGS_EVERYTHING)

# MSVC: Disable warning about `dll-interface` of inherited classes
_sps_add_flag(-wd4251 CXX)

if (SPS_ENABLE_EXTRA_BUILD_WARNINGS_EVERYTHING)
  set(langs C CXX)
  _sps_add_flag_all(-Weverything ${langs})

  # Instead of enabling warnings, this mode *disables* warnings.
  _sps_add_flag_all(-Weverything ${langs})
  _sps_add_flag_all(-Wno-c++98-compat-pedantic ${langs})
  _sps_add_flag_all(-Wno-c++98-compat ${langs})
  _sps_add_flag_all(-Wno-pre-c++17-compat ${langs})
  _sps_add_flag_all(-Wno-reserved-macro-identifier ${langs})
  _sps_add_flag_all(-Wno-reserved-identifier ${langs})       # Allow __ prefixed identifiers in macros
  _sps_add_flag_all(-Wno-unsafe-buffer-usage ${langs})       # Allow raw pointer/array access (essential for SIMD)
  _sps_add_flag_all(-Wno-missing-prototypes ${langs})        # Anonymous namespaces provide internal linkage
  _sps_add_flag_all(-Wno-padded ${langs})
  _sps_add_flag_all(-Wno-float-equal ${langs})
  _sps_add_flag_all(-Wno-extra-semi ${langs})

elseif (SPS_ENABLE_EXTRA_BUILD_WARNINGS)
  # === C AND C++: Foundation warnings ===
  set(langs C CXX)
  _sps_add_flag_all(-Wall ${langs})
  _sps_add_flag_all(-Wextra ${langs})
  _sps_add_flag_all(-Wshadow ${langs})                       # Critical for threading code - catches variable shadowing
  _sps_add_flag_all(-Wduplicated-cond ${langs})              # Duplicated if conditions
  _sps_add_flag_all(-Wduplicated-branches ${langs})          # Identical if/else branches
  _sps_add_flag_all(-Wlogical-op ${langs})                   # Suspicious logical operations
  _sps_add_flag_all(-Wnull-dereference ${langs})             # Potential null dereferences
  _sps_add_flag_all(-Wabsolute-value ${langs})               # Clang-only
  _sps_add_flag_all(-Wunreachable-code ${langs})             # Clang-only
  _sps_add_flag_all(-Wunused-but-set-variable ${langs})
  _sps_add_flag_all(-Wunused-function ${langs})
  _sps_add_flag_all(-Wunused-local-typedef ${langs})         # Clang-only
  _sps_add_flag_all(-Wunused-parameter ${langs})
  _sps_add_flag_all(-Wunused-variable ${langs})
  _sps_add_flag_all(-Wsign-compare ${langs})
  _sps_add_flag_all(-Wmissing-field-initializers ${langs})   # Incomplete struct initialization
  # Note: -Wconversion, -Wsign-conversion, and -Wfloat-conversion are too noisy for template/container code

  # === C++ SPECIFIC: Modern practices and type safety ===
  set(langs CXX)
  _sps_add_flag_all(-Wold-style-cast ${langs})               # Enforce C++ style casts
  _sps_add_flag_all(-Woverloaded-virtual ${langs})           # Virtual function hiding
  _sps_add_flag_all(-Wsuggest-override ${langs})             # Missing override keywords
  _sps_add_flag_all(-Winconsistent-missing-destructor-override ${langs})  # Clang-only
  _sps_add_flag_all(-Wnon-virtual-dtor ${langs})
  _sps_add_flag_all(-Wpessimizing-move ${langs})             # Clang-only
  _sps_add_flag_all(-Wrange-loop-bind-reference ${langs})    # Clang-only
  _sps_add_flag_all(-Wreorder-ctor ${langs})                 # Clang-only
  _sps_add_flag_all(-Wunused-lambda-capture ${langs})        # Clang-only
  _sps_add_flag_all(-Wunused-private-field ${langs})         # Clang-only
  _sps_add_flag_all(-Wuseless-cast ${langs})                 # Unnecessary casts
  _sps_add_flag_all(-Wno-extra-semi ${langs})                # Semicolons after macros improve IDE behavior
  _sps_add_clangcl_flag(-Wno-c++98-compat ${langs})          # Suppress C++98 compatibility warnings
  _sps_add_clangcl_flag(-Wno-pre-c++17-compat ${langs})      # Suppress pre-C++17 compatibility warnings
  _sps_add_clangcl_flag(-Wno-reserved-macro-identifier ${langs})

endif ()
