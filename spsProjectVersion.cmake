#[==[.rst:
*****************
spsProjectVersion
*****************

.. cmake:command:: sps_set_project_version

  Sets project version from git tag or uses a default fallback.
  Must be called BEFORE project() command.

  sps_set_project_version(
    DEFAULT_VERSION <version>    # Fallback version (e.g., "1.0.0")
    OUT_VERSION <var>            # Output variable for version string
  )

  The version format is MAJOR.MINOR.PATCH.TWEAK where:
  - With git tag: TWEAK = commits since tag
  - Without git tag: TWEAK = total commit count

  Example:
  .. code-block:: cmake
    sps_set_project_version(DEFAULT_VERSION "1.0.0" OUT_VERSION PROJECT_VER)
    project(MyProject VERSION ${PROJECT_VER} LANGUAGES CXX)
#]==]

function(sps_set_project_version)
  set(one_value_args DEFAULT_VERSION OUT_VERSION)
  cmake_parse_arguments(SPV "" "${one_value_args}" "" ${ARGN})

  if(NOT SPV_DEFAULT_VERSION)
    message(FATAL_ERROR "sps_set_project_version: DEFAULT_VERSION is required")
  endif()
  if(NOT SPV_OUT_VERSION)
    message(FATAL_ERROR "sps_set_project_version: OUT_VERSION is required")
  endif()

  include(spsGitVersion)
  sps_get_git_version(
    OUT_TAG _GIT_TAG
    OUT_HAS_TAG _GIT_HAS_TAG
    OUT_COUNT_SINCE_TAG _GIT_COMMITS_SINCE_TAG
    OUT_COUNT_TOTAL _GIT_COMMIT_COUNT
  )

  if(_GIT_HAS_TAG)
    sps_extract_version_from_tag(
      TAG "${_GIT_TAG}"
      OUT_MAJOR _VERSION_MAJOR
      OUT_MINOR _VERSION_MINOR
      OUT_PATCH _VERSION_PATCH
      ALLOW_MISSING
    )
    set(_VERSION_TWEAK "${_GIT_COMMITS_SINCE_TAG}")
    set(_VERSION "${_VERSION_MAJOR}.${_VERSION_MINOR}.${_VERSION_PATCH}.${_VERSION_TWEAK}")
    set(_VERSION_SOURCE "git tag: ${_GIT_TAG}, +${_GIT_COMMITS_SINCE_TAG} commits")
  else()
    set(_VERSION "${SPV_DEFAULT_VERSION}.${_GIT_COMMIT_COUNT}")
    set(_VERSION_SOURCE "default, ${_GIT_COMMIT_COUNT} total commits")
  endif()

  set(${SPV_OUT_VERSION} "${_VERSION}" PARENT_SCOPE)
  set(${SPV_OUT_VERSION}_SOURCE "${_VERSION_SOURCE}" PARENT_SCOPE)
endfunction()
