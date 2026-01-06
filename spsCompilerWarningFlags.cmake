#[==[.rst:
***********************
spsCompilerWarningFlags
***********************
  Compiler warnings for cross-platform builds. Appends to the interface target 'build' (if present).

  Platforms:
  - Linux GCC/Clang: Uses check_compiler_flag to validate flags
  - Windows MSVC: Only MSVC-style flags (/W3, -wd4251), no -W flags
  - Windows ClangCL: Uses known flag list with /clang: prefix, no runtime checking
#]==]

include(CheckCompilerFlag)
include(CMakeDependentOption)
include(spsClangCLWarnings)

# Options
option(SPS_ENABLE_EXTRA_BUILD_WARNINGS "Enable extra build warnings" ON)
mark_as_advanced(SPS_ENABLE_EXTRA_BUILD_WARNINGS)

check_compiler_flag(C "-Weverything" sps_have_compiler_flag_Weverything)
cmake_dependent_option(SPS_ENABLE_EXTRA_BUILD_WARNINGS_EVERYTHING "Enable *all* warnings (except known problems)" OFF
  "SPS_ENABLE_EXTRA_BUILD_WARNINGS;sps_have_compiler_flag_Weverything" OFF)
mark_as_advanced(SPS_ENABLE_EXTRA_BUILD_WARNINGS_EVERYTHING)

#[==[.rst:
.. cmake:command:: _sps_add_warning_flag

  Unified function for adding compiler warning flags across all platforms.

  Usage: _sps_add_warning_flag(<flag> [CLANGCL_ONLY] <lang>...)

  Options:
  - CLANGCL_ONLY: Only apply this flag to ClangCL (skip Linux and native MSVC)

  Platform behavior:
  - MSVC native: Only accepts MSVC-style flags (starting with / or -wd)
  - ClangCL: MSVC flags pass through, -W flags use /clang: prefix (from known list)
  - Linux GCC/Clang: Uses check_compiler_flag for validation
#]==]
function(_sps_add_warning_flag flag)
  if (NOT TARGET build)
    return()
  endif()

  cmake_parse_arguments(ARG "CLANGCL_ONLY" "" "" ${ARGN})
  set(langs ${ARG_UNPARSED_ARGUMENTS})

  foreach (lang IN LISTS langs)
    # MSVC Compier
    if (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
      # Native MSVC: only MSVC-style flags, no checking is made (too slow)
      if (NOT ARG_CLANGCL_ONLY AND flag MATCHES "^(/|-wd)")
        target_compile_options(build INTERFACE
          "$<BUILD_INTERFACE:$<$<COMPILE_LANGUAGE:${lang}>:${flag}>>")
      endif()
    elseif (CMAKE_CXX_COMPILER_ID MATCHES "Clang" AND MSVC)
      # ClangCL Microsfts frontend to clang
      # - MSVC flags are passed through
      # - -W flags use /clang: prefix (needed)
      if (NOT ARG_CLANGCL_ONLY AND flag MATCHES "^(/|-wd)")
        # Microsoft flags
        target_compile_options(build INTERFACE
          "$<BUILD_INTERFACE:$<$<COMPILE_LANGUAGE:${lang}>:${flag}>>")
      elseif (flag IN_LIST _SPS_CLANGCL_KNOWN_FLAGS)
        # ClangCL specific flags
        target_compile_options(build INTERFACE
          "$<BUILD_INTERFACE:$<$<COMPILE_LANGUAGE:${lang}>:/clang:${flag}>>")
      endif()

    else()
      # Linux GCC/Clang
      # - use check_compiler_flag (testing existing of flags - slow on windows)
      if (NOT ARG_CLANGCL_ONLY)
        check_compiler_flag("${lang}" "${flag}" "sps_have_flag-${lang}-${flag}")
        if (sps_have_flag-${lang}-${flag})
          target_compile_options(build INTERFACE
            "$<BUILD_INTERFACE:$<$<COMPILE_LANGUAGE:${lang}>:${flag}>>")
        endif()
      endif()
    endif()
  endforeach()
endfunction()

# MSVC: Disable warning about `dll-interface` of inherited classes
_sps_add_warning_flag(-wd4251 CXX)

if (SPS_ENABLE_EXTRA_BUILD_WARNINGS_EVERYTHING)
  set(langs C CXX)
  _sps_add_warning_flag(-Weverything ${langs})

  # Suppressions for -Weverything mode
  _sps_add_warning_flag(-Wno-c++98-compat-pedantic ${langs})
  _sps_add_warning_flag(-Wno-c++98-compat ${langs})
  _sps_add_warning_flag(-Wno-pre-c++17-compat ${langs})
  _sps_add_warning_flag(-Wno-reserved-macro-identifier ${langs})
  _sps_add_warning_flag(-Wno-reserved-identifier ${langs})
  _sps_add_warning_flag(-Wno-unsafe-buffer-usage ${langs})
  _sps_add_warning_flag(-Wno-missing-prototypes ${langs})
  _sps_add_warning_flag(-Wno-padded ${langs})
  _sps_add_warning_flag(-Wno-float-equal ${langs})
  _sps_add_warning_flag(-Wno-extra-semi ${langs})

elseif (SPS_ENABLE_EXTRA_BUILD_WARNINGS)
  # === C AND C++: Foundation warnings ===
  set(langs C CXX)
  _sps_add_warning_flag(-Wall ${langs})
  _sps_add_warning_flag(-Wextra ${langs})
  _sps_add_warning_flag(-Wshadow ${langs})
  _sps_add_warning_flag(-Wnull-dereference ${langs})
  _sps_add_warning_flag(-Wabsolute-value ${langs})
  _sps_add_warning_flag(-Wunreachable-code ${langs})
  _sps_add_warning_flag(-Wunused-but-set-variable ${langs})
  _sps_add_warning_flag(-Wunused-function ${langs})
  _sps_add_warning_flag(-Wunused-local-typedef ${langs})
  _sps_add_warning_flag(-Wunused-parameter ${langs})
  _sps_add_warning_flag(-Wunused-variable ${langs})
  _sps_add_warning_flag(-Wsign-compare ${langs})
  _sps_add_warning_flag(-Wmissing-field-initializers ${langs})

  # === MSVC: Warning level ===
  _sps_add_warning_flag(/W3 CXX)

  # === C++: Modern practices and type safety ===
  set(langs CXX)
  _sps_add_warning_flag(-Wold-style-cast ${langs})
  _sps_add_warning_flag(-Woverloaded-virtual ${langs})
  _sps_add_warning_flag(-Wsuggest-override ${langs})
  _sps_add_warning_flag(-Winconsistent-missing-destructor-override ${langs})
  _sps_add_warning_flag(-Wnon-virtual-dtor ${langs})
  _sps_add_warning_flag(-Wpessimizing-move ${langs})
  _sps_add_warning_flag(-Wrange-loop-bind-reference ${langs})
  _sps_add_warning_flag(-Wreorder-ctor ${langs})
  _sps_add_warning_flag(-Wunused-lambda-capture ${langs})
  _sps_add_warning_flag(-Wunused-private-field ${langs})

  # === Suppressions ===
  _sps_add_warning_flag(-Wno-extra-semi ${langs})

  # === ClangCL-only suppressions ===
  _sps_add_warning_flag(-Wno-c++98-compat-pedantic CLANGCL_ONLY ${langs})
  _sps_add_warning_flag(-Wno-c++98-compat CLANGCL_ONLY ${langs})
  _sps_add_warning_flag(-Wno-c++98-c++11-compat-binary-literal CLANGCL_ONLY ${langs})
  _sps_add_warning_flag(-Wno-c++98-compat-bind-to-temporary-copy CLANGCL_ONLY ${langs})
  _sps_add_warning_flag(-Wno-pre-c++17-compat CLANGCL_ONLY ${langs})
  _sps_add_warning_flag(-Wno-reserved-macro-identifier CLANGCL_ONLY ${langs})
  _sps_add_warning_flag(-Wno-reserved-identifier CLANGCL_ONLY ${langs})
  _sps_add_warning_flag(-Wno-undef CLANGCL_ONLY ${langs})
  _sps_add_warning_flag(-Wno-documentation CLANGCL_ONLY ${langs})
  _sps_add_warning_flag(-Wno-float-equal CLANGCL_ONLY ${langs})
  _sps_add_warning_flag(-Wno-header-hygiene CLANGCL_ONLY ${langs})
  _sps_add_warning_flag(-Wno-missing-prototypes CLANGCL_ONLY ${langs})
  _sps_add_warning_flag(-Wno-nonportable-system-include-path CLANGCL_ONLY ${langs})
  _sps_add_warning_flag(-Wno-sign-conversion CLANGCL_ONLY ${langs})
  _sps_add_warning_flag(-Wno-unsafe-buffer-usage CLANGCL_ONLY ${langs})
  _sps_add_warning_flag(-Wno-shorten-64-to-32 CLANGCL_ONLY ${langs})
  _sps_add_warning_flag(-Wno-switch-default CLANGCL_ONLY ${langs})
  _sps_add_warning_flag(-Wno-nan-infinity-disabled CLANGCL_ONLY ${langs})

endif()

if (TARGET build)
  # === Warnings as Errors ===
  # Only apply during build of this project, not when consumed by downstream projects
  option(SPS_WARNINGS_AS_ERRORS "Treat compiler warnings as errors" ON)
  if(SPS_WARNINGS_AS_ERRORS AND TARGET build)
    if(MSVC)
      target_compile_options(build INTERFACE $<BUILD_INTERFACE:/WX>)
      message(STATUS "Warnings as errors enabled (MSVC: /WX)")
    else()
      target_compile_options(build INTERFACE $<BUILD_INTERFACE:-Werror>)
      message(STATUS "Warnings as errors enabled (GCC/Clang: -Werror)")
    endif()
  endif()
endif()
