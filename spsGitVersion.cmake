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


# Usage:
#   get_git_version(
#     OUT_HASH OUT_DATETIME OUT_COUNT_TOTAL OUT_TAG OUT_DIRTY
#     OUT_COUNT_SINCE_TAG OUT_DESCRIBE OUT_HAS_TAG
#   )
#
# Any of the OUT_* names can be "" if you don't care about that value.

function(get_git_version out_hash out_datetime out_count_total out_tag out_dirty out_count_since_tag out_describe out_has_tag)
  find_package(Git QUIET)
  if (NOT Git_FOUND OR NOT EXISTS "${CMAKE_SOURCE_DIR}/.git")
    string(TIMESTAMP now "%Y%m%d_%H%M%S" UTC)
    if (NOT "${out_hash}" STREQUAL "")            set(${out_hash}     "unknown"            PARENT_SCOPE) endif()
    if (NOT "${out_datetime}" STREQUAL "")        set(${out_datetime} "${now}"             PARENT_SCOPE) endif()
    if (NOT "${out_count_total}" STREQUAL "")     set(${out_count_total} "0"               PARENT_SCOPE) endif()
    if (NOT "${out_tag}" STREQUAL "")             set(${out_tag}      "${PROJECT_VERSION}" PARENT_SCOPE) endif()
    if (NOT "${out_dirty}" STREQUAL "")           set(${out_dirty}    "0"                  PARENT_SCOPE) endif()
    if (NOT "${out_count_since_tag}" STREQUAL "") set(${out_count_since_tag} "0"           PARENT_SCOPE) endif()
    if (NOT "${out_describe}" STREQUAL "")        set(${out_describe} ""                   PARENT_SCOPE) endif()
    if (NOT "${out_has_tag}" STREQUAL "")         set(${out_has_tag}  "0"                  PARENT_SCOPE) endif()
    return()
  endif()

  # Short hash
  execute_process(
    COMMAND "${GIT_EXECUTABLE}" -C "${CMAKE_SOURCE_DIR}" rev-parse --short=12 HEAD
    OUTPUT_VARIABLE GIT_HASH
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_VARIABLE _ignored)

  # Commit datetime (commit time, stable per commit)
  execute_process(
    COMMAND "${GIT_EXECUTABLE}" -C "${CMAKE_SOURCE_DIR}"
            show -s --format=%cd --date=format:%Y%m%d_%H%M%S HEAD
    OUTPUT_VARIABLE GIT_DATETIME
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_VARIABLE _ignored)

  # Total commit count
  execute_process(
    COMMAND "${GIT_EXECUTABLE}" -C "${CMAKE_SOURCE_DIR}" rev-list --count HEAD
    OUTPUT_VARIABLE GIT_COUNT_TOTAL
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_VARIABLE _ignored)

  # Latest tag (if any)
  execute_process(
    COMMAND "${GIT_EXECUTABLE}" -C "${CMAKE_SOURCE_DIR}" describe --tags --abbrev=0
    OUTPUT_VARIABLE GIT_TAG
    RESULT_VARIABLE TAG_OK
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_VARIABLE _ignored)
  if (TAG_OK EQUAL 0 AND NOT GIT_TAG STREQUAL "")
    set(GIT_HAS_TAG "1")
  else()
    set(GIT_HAS_TAG "0")
    set(GIT_TAG "")
  endif()

  # Long describe (works with/without tags)
  execute_process(
    COMMAND "${GIT_EXECUTABLE}" -C "${CMAKE_SOURCE_DIR}" describe --tags --long --always
    OUTPUT_VARIABLE GIT_DESCRIBE
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_VARIABLE _ignored)

  # Commits since last tag
  if (GIT_HAS_TAG STREQUAL "1")
    execute_process(
      COMMAND "${GIT_EXECUTABLE}" -C "${CMAKE_SOURCE_DIR}" rev-list --count "${GIT_TAG}..HEAD"
      OUTPUT_VARIABLE GIT_COMMITS_SINCE_TAG
      OUTPUT_STRIP_TRAILING_WHITESPACE
      ERROR_VARIABLE _ignored)
  else()
    set(GIT_COMMITS_SINCE_TAG "0")
  endif()

  # Dirty (tracked changes only; untracked ignored so build dirs don't trip it)
  execute_process(
    COMMAND "${GIT_EXECUTABLE}" -C "${CMAKE_SOURCE_DIR}" status --porcelain --untracked-files=no
    OUTPUT_VARIABLE GIT_STATUS
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_VARIABLE _ignored)
  if (GIT_STATUS STREQUAL "")
    set(GIT_DIRTY "0")
  else()
    set(GIT_DIRTY "1")
  endif()

  # Write only the outputs the caller asked for
  if (NOT "${out_hash}" STREQUAL "")
    set(${out_hash} "${GIT_HASH}" PARENT_SCOPE)
  endif()
  if (NOT "${out_datetime}" STREQUAL "")
    set(${out_datetime} "${GIT_DATETIME}" PARENT_SCOPE)
  endif()
  if (NOT "${out_count_total}" STREQUAL "")
    set(${out_count_total} "${GIT_COUNT_TOTAL}" PARENT_SCOPE)
  endif()
  if (NOT "${out_tag}" STREQUAL "")
    set(${out_tag} "${GIT_TAG}" PARENT_SCOPE)
  endif()
  if (NOT "${out_dirty}" STREQUAL "")
    set(${out_dirty} "${GIT_DIRTY}" PARENT_SCOPE)
  endif()
  if (NOT "${out_count_since_tag}" STREQUAL "")
    set(${out_count_since_tag} "${GIT_COMMITS_SINCE_TAG}" PARENT_SCOPE)
  endif()
  if (NOT "${out_describe}" STREQUAL "")
    set(${out_describe} "${GIT_DESCRIBE}" PARENT_SCOPE)
  endif()
  if (NOT "${out_has_tag}" STREQUAL "")
    set(${out_has_tag} "${GIT_HAS_TAG}" PARENT_SCOPE)
  endif()
endfunction()
