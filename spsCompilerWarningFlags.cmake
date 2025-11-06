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

option(SPS_ENABLE_EXTRA_BUILD_WARNINGS "Enable extra build warnings" ON)
mark_as_advanced(SPS_ENABLE_EXTRA_BUILD_WARNINGS)

check_compiler_flag(C "-Weverything" sps_have_compiler_flag_Weverything)
include(CMakeDependentOption)
cmake_dependent_option(SPS_ENABLE_EXTRA_BUILD_WARNINGS_EVERYTHING "Enable *all* warnings (except known problems)" OFF
  "SPS_ENABLE_EXTRA_BUILD_WARNINGS;sps_have_compiler_flag_Weverything" OFF)
mark_as_advanced(SPS_ENABLE_EXTRA_BUILD_WARNINGS_EVERYTHING)

# MSVC
# Disable flags about `dll-interface` of inherited classes.
_sps_add_flag(-wd4251 CXX)
# Enable C++ stack unwinding and that C functions never throw C++
# exceptions.
_sps_add_flag(-EHsc CXX)

if (SPS_ENABLE_EXTRA_BUILD_WARNINGS_EVERYTHING)
  set(langs C CXX)
  _sps_add_flag(-Weverything ${langs})

  # Instead of enabling warnings, this mode *disables* warnings.
  _sps_add_flag(-Weverything ${langs})
  _sps_add_flag(-Wno-c++98-compat-pedantic ${langs})
  _sps_add_flag(-Wno-padded ${langs})
  _sps_add_flag(-Wno-float-equal ${langs})
  _sps_add_flag(-Wno-extra-semi ${langs})

elseif (SPS_ENABLE_EXTRA_BUILD_WARNINGS)
  # === FOUNDATION: Essential baseline warnings ===
  set(langs C CXX)
  _sps_add_flag(-Wall ${langs})
  _sps_add_flag(-Wextra ${langs})
  _sps_add_flag(-Wshadow ${langs})  # Critical for threading code - catches variable shadowing

  # === LOGIC/BUG DETECTION ===
  _sps_add_flag(-Wduplicated-cond ${langs})      # Duplicated if conditions (GCC)
  _sps_add_flag(-Wduplicated-branches ${langs})  # Identical if/else branches (GCC)
  _sps_add_flag(-Wlogical-op ${langs})           # Suspicious logical operations (GCC)
  _sps_add_flag(-Wnull-dereference ${langs})     # Potential null dereferences (GCC 6+)

  # === C++ SPECIFIC: Modern practices ===
  set(langs CXX)
  _sps_add_flag(-Wold-style-cast ${langs})       # Enforce C++ style casts
  _sps_add_flag(-Woverloaded-virtual ${langs})   # Virtual function hiding
  _sps_add_flag(-Wsuggest-override ${langs})     # Missing override keywords (GCC)
  # Note: -Wextra-semi disabled - semicolons after macros improve IDE behavior with/without clang-tidy

  # === C++ SPECIFIC: Destructor/Virtual/Move warnings ===
  _sps_add_flag(-Winconsistent-missing-destructor-override ${langs})
  _sps_add_flag(-Wnon-virtual-dtor ${langs})
  _sps_add_flag(-Wpessimizing-move ${langs})
  _sps_add_flag(-Wrange-loop-bind-reference ${langs})
  _sps_add_flag(-Wreorder-ctor ${langs})
  _sps_add_flag(-Wunused-lambda-capture ${langs})
  _sps_add_flag(-Wunused-private-field ${langs})

  # === C++ SPECIFIC: Type safety and casting ===
  _sps_add_flag(-Wuseless-cast ${langs})         # Unnecessary casts (GCC)
  _sps_add_flag(-Wcast-qual ${langs})            # Casts removing qualifiers

  # === C AND C++: Unused code detection ===
  set(langs C CXX)
  _sps_add_flag(-Wabsolute-value ${langs})
  _sps_add_flag(-Wunreachable-code ${langs})
  _sps_add_flag(-Wunused-but-set-variable ${langs})
  _sps_add_flag(-Wunused-function ${langs})
  _sps_add_flag(-Wunused-local-typedef ${langs})
  _sps_add_flag(-Wunused-parameter ${langs})
  _sps_add_flag(-Wunused-variable ${langs})

  # === C AND C++: Type conversions and comparisons ===
  _sps_add_flag(-Wsign-compare ${langs})
  # Note: -Wconversion, -Wsign-conversion, and -Wfloat-conversion are too noisy for template/container code
  # Consider enabling them for specific files if needed

  # === C AND C++: Additional hygiene ===
  _sps_add_flag(-Wmissing-field-initializers ${langs})  # Incomplete struct initialization
  _sps_add_flag(-Wundef ${langs})                       # Undefined macros in #if

endif ()
