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

option(SPS_ENABLE_EXTRA_BUILD_WARNINGS "Enable extra build warnings" OFF)
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
  _sps_add_flag(-Wno-cast-align ${langs})
  _sps_add_flag(-Wno-cast-function-type-strict ${langs})
  _sps_add_flag(-Wno-cast-qual ${langs})
  _sps_add_flag(-Wno-conversion ${langs})
  _sps_add_flag(-Wno-covered-switch-default ${langs})
  _sps_add_flag(-Wno-declaration-after-statement ${langs})
  _sps_add_flag(-Wno-direct-ivar-access ${langs})
  _sps_add_flag(-Wno-disabled-macro-expansion ${langs})
  _sps_add_flag(-Wno-documentation ${langs})
  _sps_add_flag(-Wno-documentation-unknown-command ${langs})
  _sps_add_flag(-Wno-double-promotion ${langs})
  _sps_add_flag(-Wno-exit-time-destructors ${langs})
  _sps_add_flag(-Wno-extra-semi ${langs})
  _sps_add_flag(-Wno-extra-semi-stmt ${langs})
  _sps_add_flag(-Wno-float-equal ${langs})
  _sps_add_flag(-Wno-format-nonliteral ${langs})
  _sps_add_flag(-Wno-format-pedantic ${langs})
  _sps_add_flag(-Wno-global-constructors ${langs})
  _sps_add_flag(-Wno-long-long ${langs})
  _sps_add_flag(-Wno-missing-noreturn ${langs})
  _sps_add_flag(-Wno-missing-prototypes ${langs})
  _sps_add_flag(-Wno-missing-variable-declarations ${langs})
  _sps_add_flag(-Wno-objc-interface-ivars ${langs})
  _sps_add_flag(-Wno-padded ${langs})
  _sps_add_flag(-Wno-reserved-id-macro ${langs})
  _sps_add_flag(-Wno-shorten-64-to-32 ${langs})
  _sps_add_flag(-Wno-sign-conversion ${langs})
  _sps_add_flag(-Wno-strict-prototypes ${langs})
  _sps_add_flag(-Wno-switch-enum ${langs})
  _sps_add_flag(-Wno-undef ${langs})
  _sps_add_flag(-Wno-unused-macros ${langs})
  _sps_add_flag(-Wno-vla ${langs})
  _sps_add_flag(-Wno-vla-extension ${langs})

  set(langs CXX)
  _sps_add_flag(-Wno-c++98-compat-pedantic ${langs})
  _sps_add_flag(-Wno-inconsistent-missing-override ${langs})
  _sps_add_flag(-Wno-old-style-cast ${langs})
  _sps_add_flag(-Wno-return-std-move-in-c++11 ${langs})
  _sps_add_flag(-Wno-signed-enum-bitfield ${langs})
  _sps_add_flag(-Wno-undefined-func-template ${langs})
  _sps_add_flag(-Wno-unused-member-function ${langs})
  _sps_add_flag(-Wno-weak-template-vtables ${langs})
  _sps_add_flag(-Wno-weak-vtables ${langs})
  _sps_add_flag(-Wno-zero-as-null-pointer-constant ${langs})
  _sps_add_flag(-Wno-unsafe-buffer-usage ${langs})

  # These should be fixed at some point prior to next version
  _sps_add_flag(-Wno-deprecated-copy-dtor ${langs})
  _sps_add_flag(-Wno-deprecated-copy ${langs})
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

  # Fortran flags.
elseif (SPS_PEDANTIC_BUILD_WARNINGS)
  set(langs CXX)
  _sps_add_flag(-Weverything ${langs})
  # Instead of enabling warnings, this mode *disables* warnings.
  _sps_add_flag(-Wno-c++98-compat-pedantic ${langs})
  _sps_add_flag(-Wno-padded ${langs})
  _sps_add_flag(-Wno-float-equal ${langs})
endif ()
