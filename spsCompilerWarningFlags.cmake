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
  # C flags.
  set(langs C)

  # C++ flags.
  set(langs CXX)
  _sps_add_flag(-Winconsistent-missing-destructor-override ${langs})
  _sps_add_flag(-Wnon-virtual-dtor ${langs})
  _sps_add_flag(-Wpessimizing-move ${langs})
  _sps_add_flag(-Wrange-loop-bind-reference ${langs})
  _sps_add_flag(-Wreorder-ctor ${langs})
  _sps_add_flag(-Wunused-lambda-capture ${langs})
  _sps_add_flag(-Wunused-private-field ${langs})

  # C and C++ flags.
  set(langs C CXX)
  _sps_add_flag(-Wabsolute-value ${langs})
  _sps_add_flag(-Wsign-compare ${langs})
  _sps_add_flag(-Wunreachable-code ${langs})
  _sps_add_flag(-Wunused-but-set-variable ${langs})
  _sps_add_flag(-Wunused-function ${langs})
  _sps_add_flag(-Wunused-local-typedef ${langs})
  _sps_add_flag(-Wunused-parameter ${langs})
  _sps_add_flag(-Wunused-variable ${langs})

endif ()
