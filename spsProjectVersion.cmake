#[==[.rst:
*****************
spsProjectVersion
*****************

.. cmake:command:: sps_set_project_version

  Sets project version from git tag or uses a default fallback.
  Must be called BEFORE project() command.

  sps_set_project_version(
    DEFAULT_VERSION <version>    # Fallback version (e.g., "1.0.0")
    OUT_VERSION <var>            # Output variable for CMake version (4-part numeric)
    [PRERELEASE_ID <id>]         # Pre-release identifier (default: "alpha")
  )

  MinVer-compatible versioning behavior:
  - On exact tag commit: produces clean version (e.g., "1.2.3")
  - After tag: auto-increments patch, adds pre-release suffix (e.g., "1.2.4-alpha.0.5")
  - Without tag: uses default version with pre-release suffix

  Output variables (set in PARENT_SCOPE):
  - <OUT_VERSION>: CMake-compatible 4-part version (MAJOR.MINOR.PATCH.TWEAK)
  - <OUT_VERSION>_SEMVER: MinVer-style semantic version string
  - <OUT_VERSION>_SOURCE: Description of version source

  Example:
  .. code-block:: cmake
    sps_set_project_version(DEFAULT_VERSION "1.0.0" OUT_VERSION PROJECT_VER)
    project(MyProject VERSION ${PROJECT_VER} LANGUAGES CXX)
    # PROJECT_VER = "1.2.4.5" (for CMake)
    # PROJECT_VER_SEMVER = "1.2.4-alpha.0.5" (for NuGet/display)
#]==]

function(sps_set_project_version)
  set(one_value_args DEFAULT_VERSION OUT_VERSION PRERELEASE_ID)
  cmake_parse_arguments(SPV "" "${one_value_args}" "" ${ARGN})

  if(NOT SPV_DEFAULT_VERSION)
    message(FATAL_ERROR "sps_set_project_version: DEFAULT_VERSION is required")
  endif()
  if(NOT SPV_OUT_VERSION)
    message(FATAL_ERROR "sps_set_project_version: OUT_VERSION is required")
  endif()
  if(NOT SPV_PRERELEASE_ID)
    set(SPV_PRERELEASE_ID "alpha")
  endif()

  include(spsGitVersion)
  sps_get_git_version(
    OUT_TAG _GIT_TAG
    OUT_HAS_TAG _GIT_HAS_TAG
    OUT_COUNT_SINCE_TAG _GIT_COMMITS_SINCE_TAG
    OUT_COUNT_TOTAL _GIT_COMMIT_COUNT
    OUT_HASH _GIT_HASH
    OUT_DIRTY _GIT_DIRTY
  )

  if(_GIT_HAS_TAG)
    sps_extract_version_from_tag(
      TAG "${_GIT_TAG}"
      OUT_MAJOR _VERSION_MAJOR
      OUT_MINOR _VERSION_MINOR
      OUT_PATCH _VERSION_PATCH
      ALLOW_MISSING
    )

    if(_GIT_COMMITS_SINCE_TAG EQUAL 0)
      # Exact tag commit: clean release version (MinVer behavior)
      set(_VERSION "${_VERSION_MAJOR}.${_VERSION_MINOR}.${_VERSION_PATCH}.0")
      set(_VERSION_SEMVER "${_VERSION_MAJOR}.${_VERSION_MINOR}.${_VERSION_PATCH}")
      set(_VERSION_SOURCE "git tag: ${_GIT_TAG} (release)")
    else()
      # Commits after tag: increment patch, add pre-release suffix (MinVer behavior)
      math(EXPR _NEXT_PATCH "${_VERSION_PATCH} + 1")
      set(_VERSION "${_VERSION_MAJOR}.${_VERSION_MINOR}.${_NEXT_PATCH}.${_GIT_COMMITS_SINCE_TAG}")
      set(_VERSION_SEMVER "${_VERSION_MAJOR}.${_VERSION_MINOR}.${_NEXT_PATCH}-${SPV_PRERELEASE_ID}.0.${_GIT_COMMITS_SINCE_TAG}")
      set(_VERSION_SOURCE "git tag: ${_GIT_TAG}, +${_GIT_COMMITS_SINCE_TAG} commits (pre-release)")
    endif()
  else()
    # No tag: use default version with pre-release suffix
    # Parse default version
    string(REPLACE "." ";" _DEFAULT_PARTS "${SPV_DEFAULT_VERSION}")
    list(LENGTH _DEFAULT_PARTS _DEFAULT_LEN)
    list(GET _DEFAULT_PARTS 0 _VERSION_MAJOR)
    if(_DEFAULT_LEN GREATER 1)
      list(GET _DEFAULT_PARTS 1 _VERSION_MINOR)
    else()
      set(_VERSION_MINOR 0)
    endif()
    if(_DEFAULT_LEN GREATER 2)
      list(GET _DEFAULT_PARTS 2 _VERSION_PATCH)
    else()
      set(_VERSION_PATCH 0)
    endif()

    set(_VERSION "${_VERSION_MAJOR}.${_VERSION_MINOR}.${_VERSION_PATCH}.${_GIT_COMMIT_COUNT}")
    set(_VERSION_SEMVER "${_VERSION_MAJOR}.${_VERSION_MINOR}.${_VERSION_PATCH}-${SPV_PRERELEASE_ID}.0.${_GIT_COMMIT_COUNT}")
    set(_VERSION_SOURCE "default: ${SPV_DEFAULT_VERSION}, ${_GIT_COMMIT_COUNT} total commits (pre-release)")
  endif()

  set(${SPV_OUT_VERSION} "${_VERSION}" PARENT_SCOPE)
  set(${SPV_OUT_VERSION}_SEMVER "${_VERSION_SEMVER}" PARENT_SCOPE)
  set(${SPV_OUT_VERSION}_SOURCE "${_VERSION_SOURCE}" PARENT_SCOPE)

  # Export git information for Config.h generation
  set(${SPV_OUT_VERSION}_GIT_HASH "${_GIT_HASH}" PARENT_SCOPE)
  set(${SPV_OUT_VERSION}_GIT_TAG "${_GIT_TAG}" PARENT_SCOPE)
  set(${SPV_OUT_VERSION}_GIT_DIRTY "${_GIT_DIRTY}" PARENT_SCOPE)
endfunction()
