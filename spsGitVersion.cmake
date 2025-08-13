function(sps_get_git_version out_hash out_datetime out_count out_tag out_dirty)
  find_package(Git QUIET)
  if (NOT Git_FOUND OR NOT EXISTS "${CMAKE_SOURCE_DIR}/.git")
    # Fallbacks for non-git trees / tarballs
    string(TIMESTAMP now "%Y%m%d_%H%M%S" UTC)
    set(${out_hash}     "unknown"         PARENT_SCOPE)
    set(${out_datetime} "${now}"          PARENT_SCOPE)
    set(${out_count}    "0"               PARENT_SCOPE)
    set(${out_tag}      "${PROJECT_VERSION}" PARENT_SCOPE)
    set(${out_dirty}    "0"               PARENT_SCOPE)
    return()
  endif()

  execute_process(
    COMMAND "${GIT_EXECUTABLE}" -C "${CMAKE_SOURCE_DIR}" rev-parse --short=12 HEAD
    OUTPUT_VARIABLE GIT_HASH
    OUTPUT_STRIP_TRAILING_WHITESPACE)

  execute_process(
    COMMAND "${GIT_EXECUTABLE}" -C "${CMAKE_SOURCE_DIR}" show -s --format=%cd --date=format:%Y%m%d_%H%M%S HEAD
    OUTPUT_VARIABLE GIT_DATETIME
    OUTPUT_STRIP_TRAILING_WHITESPACE)

  execute_process(
    COMMAND "${GIT_EXECUTABLE}" -C "${CMAKE_SOURCE_DIR}" rev-list --count HEAD
    OUTPUT_VARIABLE GIT_COUNT
    OUTPUT_STRIP_TRAILING_WHITESPACE)

  # Prefer latest tag; fallback to commit hash if no tags
  execute_process(
    COMMAND "${GIT_EXECUTABLE}" -C "${CMAKE_SOURCE_DIR}" describe --tags --abbrev=0
    OUTPUT_VARIABLE GIT_TAG
    RESULT_VARIABLE TAG_OK
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if (NOT TAG_OK EQUAL 0 OR GIT_TAG STREQUAL "")
    set(GIT_TAG "${GIT_HASH}")
  endif()

  # Dirty flag (1 if there are uncommitted changes)
  execute_process(
    COMMAND "${GIT_EXECUTABLE}" -C "${CMAKE_SOURCE_DIR}" status --porcelain
    OUTPUT_VARIABLE GIT_STATUS
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if (GIT_STATUS STREQUAL "")
    set(GIT_DIRTY "0")
  else()
    set(GIT_DIRTY "1")
  endif()

  set(${out_hash}     "${GIT_HASH}"     PARENT_SCOPE)
  set(${out_datetime} "${GIT_DATETIME}" PARENT_SCOPE)
  set(${out_count}    "${GIT_COUNT}"    PARENT_SCOPE)
  set(${out_tag}      "${GIT_TAG}"      PARENT_SCOPE)
  set(${out_dirty}    "${GIT_DIRTY}"    PARENT_SCOPE)
endfunction()


# get_git_version(...)
# Keyword-style API:
#   get_git_version(
#     OUT_HASH <var>            # short hash (12)
#     OUT_DATETIME <var>        # commit datetime (formatted)
#     OUT_COUNT_TOTAL <var>     # total commits on HEAD
#     OUT_TAG <var>             # latest tag (empty if none)
#     OUT_DIRTY <var>           # "0" or "1" (tracked changes only by default)
#     OUT_COUNT_SINCE_TAG <var> # commits since latest tag (0 if none)
#     OUT_DESCRIBE <var>        # git describe --tags --long --always
#     OUT_HAS_TAG <var>         # "1" if repo has any tag, else "0"
#
# Options:
#   SOURCE_DIR <path>           # default: CMAKE_SOURCE_DIR
#   DATE_FORMAT <fmt>           # default: %Y%m%d_%H%M%S
#   INCLUDE_UNTRACKED           # count untracked files as "dirty"
#   QUIET                       # suppress status messages (currently none)
#
# Example:
#   get_git_version(OUT_HASH GIT_HASH OUT_TAG GIT_TAG OUT_DIRTY GIT_DIRTY)

function(get_git_version)
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
