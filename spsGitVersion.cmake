#[==[.rst:
*************
spsGitVersion
*************
#
#]==]

#[==[.rst:

.. cmake:command:: sps_get_git_version

  The :cmake:command:`sps_get_git_version` function is provided to
  extract version information from git using a keyword-style API:

    sps_get_git_version(
      OUT_HASH <var>            # short hash (12)
      OUT_DATETIME <var>        # commit datetime (formatted)
      OUT_COUNT_TOTAL <var>     # total commits on HEAD
      OUT_TAG <var>             # latest tag (empty if none)
      OUT_DIRTY <var>           # "0" or "1" (tracked changes only by default)
      OUT_COUNT_SINCE_TAG <var> # commits since latest tag (0 if none)
      OUT_DESCRIBE <var>        # git describe --tags --long --always
      OUT_HAS_TAG <var>         # "1" if repo has any tag, else "0"

    Options:
      SOURCE_DIR <path>           # default: CMAKE_SOURCE_DIR
      DATE_FORMAT <fmt>           # default: %Y%m%d_%H%M%S
      INCLUDE_UNTRACKED           # count untracked files as "dirty"
      QUIET                       # suppress status messages (currently none)

    Eample:
    .. code-block:: cmake
      sps_get_git_version(OUT_HASH GIT_HASH OUT_TAG GIT_TAG OUT_DIRTY GIT_DIRTY)
 ]==]
function(sps_get_git_version)
  set(options INCLUDE_UNTRACKED QUIET)
  set(one_value_args
    OUT_HASH OUT_DATETIME OUT_COUNT_TOTAL OUT_TAG OUT_DIRTY
    OUT_COUNT_SINCE_TAG OUT_DESCRIBE OUT_HAS_TAG
    SOURCE_DIR DATE_FORMAT
  )
  set(multi_value_args)
  cmake_parse_arguments(GGV "${options}" "${one_value_args}" "${multi_value_args}" ${ARGV})

  # Defaults
  if (NOT GGV_SOURCE_DIR)
    set(GGV_SOURCE_DIR "${CMAKE_SOURCE_DIR}")
  endif()
  if (NOT GGV_DATE_FORMAT)
    set(GGV_DATE_FORMAT "%Y%m%d_%H%M%S")
  endif()

  find_package(Git QUIET)

  if (NOT Git_FOUND OR NOT EXISTS "${GGV_SOURCE_DIR}/.git")
    string(TIMESTAMP now "${GGV_DATE_FORMAT}" UTC)
    set(_HASH "unknown")
    set(_DT   "${now}")
    set(_COUNT_TOTAL "0")
    set(_TAG "")
    set(_HAS_TAG "0")
    set(_SINCE_TAG "0")
    set(_DESCRIBE "")
    set(_DIRTY "0")
  else()
    # Short hash
    execute_process(
      COMMAND "${GIT_EXECUTABLE}" -C "${GGV_SOURCE_DIR}" rev-parse --short=12 HEAD
      OUTPUT_VARIABLE _HASH OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_VARIABLE _ig
    )
    # Commit datetime (stable per commit)
    execute_process(
      COMMAND "${GIT_EXECUTABLE}" -C "${GGV_SOURCE_DIR}" show -s --format=%cd --date=format:${GGV_DATE_FORMAT} HEAD
      OUTPUT_VARIABLE _DT OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_VARIABLE _ig
    )
    # Total commits
    execute_process(
      COMMAND "${GIT_EXECUTABLE}" -C "${GGV_SOURCE_DIR}" rev-list --count HEAD
      OUTPUT_VARIABLE _COUNT_TOTAL OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_VARIABLE _ig
    )
    # Latest tag (if any)
    execute_process(
      COMMAND "${GIT_EXECUTABLE}" -C "${GGV_SOURCE_DIR}" describe --tags --abbrev=0
      OUTPUT_VARIABLE _TAG RESULT_VARIABLE _TAG_OK
      OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_VARIABLE _ig
    )
    if (_TAG_OK EQUAL 0 AND NOT _TAG STREQUAL "")
      set(_HAS_TAG "1")
    else()
      set(_TAG "")
      set(_HAS_TAG "0")
    endif()
    # Commits since tag
    if (_HAS_TAG STREQUAL "1")
      execute_process(
        COMMAND "${GIT_EXECUTABLE}" -C "${GGV_SOURCE_DIR}" rev-list --count "${_TAG}..HEAD"
        OUTPUT_VARIABLE _SINCE_TAG OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_VARIABLE _ig
      )
    else()
      set(_SINCE_TAG "0")
    endif()
    # Describe (works w/ or w/o tags)
    execute_process(
      COMMAND "${GIT_EXECUTABLE}" -C "${GGV_SOURCE_DIR}" describe --tags --long --always
      OUTPUT_VARIABLE _DESCRIBE OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_VARIABLE _ig
    )
    # Dirty: tracked-only by default; include untracked if requested
    if (GGV_INCLUDE_UNTRACKED)
      set(_uno_arg "--untracked-files=all")
    else()
      set(_uno_arg "--untracked-files=no")
    endif()
    execute_process(
      COMMAND "${GIT_EXECUTABLE}" -C "${GGV_SOURCE_DIR}" status --porcelain ${_uno_arg}
      OUTPUT_VARIABLE _STATUS OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_VARIABLE _ig
    )
    if (_STATUS STREQUAL "")  # clean
      set(_DIRTY "0")
    else()
      set(_DIRTY "1")
    endif()
  endif()

  # Helper to set parent scope only if caller provided an OUT_* var
  macro(_gv_set out_key value)
    if (GGV_${out_key})
      set(${GGV_${out_key}} "${value}" PARENT_SCOPE)
    endif()
  endmacro()

  _gv_set(OUT_HASH            "${_HASH}")
  _gv_set(OUT_DATETIME        "${_DT}")
  _gv_set(OUT_COUNT_TOTAL     "${_COUNT_TOTAL}")
  _gv_set(OUT_TAG             "${_TAG}")
  _gv_set(OUT_DIRTY           "${_DIRTY}")
  _gv_set(OUT_COUNT_SINCE_TAG "${_SINCE_TAG}")
  _gv_set(OUT_DESCRIBE        "${_DESCRIBE}")
  _gv_set(OUT_HAS_TAG         "${_HAS_TAG}")
endfunction()

#[==[.rst:

.. cmake:command:: sps_extract_version_from_tag

  The :cmake:command:`sps_extract_version_from_tag` function is provided to
  extract major, minor and patch version from a git tag

  sps_extract_version_from_tag(TAG <tag_string>
    OUT_MAJOR <var>
    OUT_MINOR <var>
    OUT_PATCH <var>
    [ALLOW_MISSING] )  # If set, missing components become 0

   Eamples
   .. code-block:: cmake
     extract_version_from_tag(TAG "v1.2.3" OUT_MAJOR MAJOR OUT_MINOR MINOR OUT_PATCH PATCH)
     -> MAJOR=1, MINOR=2, PATCH=3

     extract_version_from_tag(TAG "1.2" OUT_MAJOR M OUT_MINOR m OUT_PATCH p ALLOW_MISSING)
     -> M=1, m=2, p=0

     extract_version_from_tag(TAG "release-5.7.0")
     -> M=5, m=7, p=0
 ]==]
function(sps_extract_version_from_tag)
  set(options ALLOW_MISSING)
  set(one_value_args TAG OUT_MAJOR OUT_MINOR OUT_PATCH)
  set(multi_value_args)
  cmake_parse_arguments(EVT "${options}" "${one_value_args}" "${multi_value_args}" ${ARGV})

  if (NOT EVT_TAG)
    message(FATAL_ERROR "extract_version_from_tag: TAG argument is required")
  endif()

  # Strip leading 'v' or non-digit prefix
  string(REGEX REPLACE "^[^0-9]*" "" _ver "${EVT_TAG}")

  # Split into components
  string(REPLACE "." ";" _parts "${_ver}")

  # Default values
  set(_maj 0)
  set(_min 0)
  set(_pat 0)

  list(LENGTH _parts _len)

  if (_len GREATER 0)
    list(GET _parts 0 _maj)
  endif()
  if (_len GREATER 1)
    list(GET _parts 1 _min)
  elseif (NOT EVT_ALLOW_MISSING)
    set(_min 0)
  endif()
  if (_len GREATER 2)
    list(GET _parts 2 _pat)
  elseif (NOT EVT_ALLOW_MISSING)
    set(_pat 0)
  endif()

  # Validate numeric
  foreach(val IN ITEMS _maj _min _pat)
    if (NOT "${${val}}" MATCHES "^[0-9]+$")
      message(FATAL_ERROR
        "extract_version_from_tag: Invalid numeric in tag '${EVT_TAG}' (parsed '${${val}}')")
    endif()
  endforeach()

  if (EVT_OUT_MAJOR)
    set(${EVT_OUT_MAJOR} "${_maj}" PARENT_SCOPE)
  endif()
  if (EVT_OUT_MINOR)
    set(${EVT_OUT_MINOR} "${_min}" PARENT_SCOPE)
  endif()
  if (EVT_OUT_PATCH)
    set(${EVT_OUT_PATCH} "${_pat}" PARENT_SCOPE)
  endif()
endfunction()
