#[==[.rst:
*********
spsGTest
*********
  Module for setting up Google Test (GTest) framework.
  Supports both finding an existing installation and fetching via FetchContent.

  Usage:
    include(spsGTest)

  This will:
  - Try to find an existing GTest installation
  - Fall back to FetchContent if not found
  - Enable CTest
  - Provide the sps_add_gtest() helper function
#]==]

include(spsSBOM)
sps_get_version(GTEST_VERSION "1.14.0")

# Check if any testing is enabled
set(_SPS_TESTING_ENABLED OFF)
if(BUILD_TESTING OR BUILD_FNM_TEST OR BUILD_SPS_TEST OR BUILD_GL_TEST)
  set(_SPS_TESTING_ENABLED ON)
endif()

if(_SPS_TESTING_ENABLED)
  include(CTest)

  # Platform-specific GTest root hints
  if(WIN32)
    # Common Windows installation paths
    set(_GTEST_HINTS
      "C:/Program Files/googletest-distribution"
      "C:/Program Files (x86)/googletest-distribution"
      "$ENV{GTEST_ROOT}"
      "$ENV{ProgramFiles}/googletest-distribution")

    # Set GTEST_ROOT if not already set
    if(NOT DEFINED GTEST_ROOT AND NOT DEFINED ENV{GTEST_ROOT})
      foreach(_hint ${_GTEST_HINTS})
        if(EXISTS "${_hint}")
          set(GTEST_ROOT "${_hint}")
          break()
        endif()
      endforeach()
    endif()
  endif()

  find_package(GTest ${GTEST_VERSION} QUIET)

  if(GTest_FOUND)
    message(STATUS "GTest found at: ${GTest_DIR}")
    message(STATUS "   GTest version: ${GTest_VERSION}")

    # Add RPATH for external GTest shared libraries (Linux/macOS)
    if(BUILD_SHARED_LIBS AND TARGET GTest::gtest)
      get_target_property(GTEST_LOCATION GTest::gtest LOCATION)
      if(GTEST_LOCATION)
        get_filename_component(GTEST_LIB_DIR ${GTEST_LOCATION} DIRECTORY)
        message(STATUS "   Adding GTest RPATH: ${GTEST_LIB_DIR}")
        set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_RPATH}:${GTEST_LIB_DIR}")
      endif()
    endif()
  else()
    message(STATUS "GTest NOT found - will use FetchContent")
    message(STATUS "   Searched in: ${CMAKE_PREFIX_PATH}")
    if(GTEST_ROOT)
      message(STATUS "   GTEST_ROOT: ${GTEST_ROOT}")
    endif()

    include(FetchContent)

    # Backup BUILD_TESTING to prevent GTest from building its own tests
    set(_SPS_BACKUP_BUILD_TESTING ${BUILD_TESTING})
    set(BUILD_TESTING OFF CACHE BOOL "Build tests (disabled for dependencies)" FORCE)

    # Prevent GTest from installing alongside our project
    set(INSTALL_GTEST OFF CACHE BOOL "" FORCE)

    FetchContent_Declare(
      googletest
      GIT_REPOSITORY https://github.com/google/googletest.git
      GIT_TAG v${GTEST_VERSION}
    )

    # For Windows: Prevent overriding the parent project's compiler/linker settings
    # This is critical for MSVC to avoid CRT mismatch issues
    set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)

    # Disable GMock if not needed (optional)
    # set(BUILD_GMOCK OFF CACHE BOOL "" FORCE)

    FetchContent_MakeAvailable(googletest)
    message(STATUS "GTest downloaded via FetchContent")

    # Restore original BUILD_TESTING value
    set(BUILD_TESTING ${_SPS_BACKUP_BUILD_TESTING} CACHE BOOL "Build tests" FORCE)

    # Create alias targets to match find_package naming convention
    if(NOT TARGET GTest::GTest)
      add_library(GTest::GTest ALIAS gtest)
    endif()
    if(NOT TARGET GTest::Main)
      add_library(GTest::Main ALIAS gtest_main)
    endif()
    if(TARGET gmock AND NOT TARGET GTest::gmock)
      add_library(GTest::gmock ALIAS gmock)
    endif()
    if(TARGET gmock_main AND NOT TARGET GTest::gmock_main)
      add_library(GTest::gmock_main ALIAS gmock_main)
    endif()
  endif()

  enable_testing()
endif()

#[==[.rst:

.. cmake:command:: sps_add_gtest

  Helper function to create a GTest executable with standard configuration.

  sps_add_gtest(<name> <sources>...
    [LIBRARIES <libs>...]
    [INCLUDE_DIRS <dirs>...])

  Arguments:
    name         - Name of the test executable
    sources      - Source files for the test
    LIBRARIES    - Additional libraries to link (optional)
    INCLUDE_DIRS - Additional include directories (optional)

  Creates an executable target linked with GTest::GTest, GTest::Main, and Threads::Threads.
  Automatically adds the test to CTest.
  If the 'build' interface target exists, it is also linked.

  Example:
    sps_add_gtest(my_test my_test.cpp
      LIBRARIES mylib
      INCLUDE_DIRS ${CMAKE_CURRENT_SOURCE_DIR})

#]==]
function(sps_add_gtest name)
  set(options)
  set(oneValueArgs)
  set(multiValueArgs LIBRARIES INCLUDE_DIRS)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  # Create the test executable
  add_executable(${name} ${ARG_UNPARSED_ARGUMENTS})

  # Find threads
  find_package(Threads QUIET)

  # Link required libraries
  target_link_libraries(${name} PRIVATE
    GTest::GTest
    GTest::Main)

  if(Threads_FOUND)
    target_link_libraries(${name} PRIVATE Threads::Threads)
  endif()

  # Link to build interface for compiler flags if available
  if(TARGET build)
    target_link_libraries(${name} PRIVATE build)
  endif()

  # Link additional libraries
  if(ARG_LIBRARIES)
    target_link_libraries(${name} PRIVATE ${ARG_LIBRARIES})
  endif()

  # Add include directories
  if(ARG_INCLUDE_DIRS)
    target_include_directories(${name} PRIVATE ${ARG_INCLUDE_DIRS})
  endif()

  # Platform-specific link libraries
  if(UNIX AND NOT APPLE)
    target_link_libraries(${name} PRIVATE dl)
  endif()

  # Register the test with CTest
  add_test(NAME ${name} COMMAND ${name})

  # Set test properties for better output
  set_tests_properties(${name} PROPERTIES
    TIMEOUT 60
    LABELS "unit")
endfunction()

#[==[.rst:

.. cmake:command:: sps_add_gmock

  Helper function to create a GMock-enabled test executable.

  sps_add_gmock(<name> <sources>...
    [LIBRARIES <libs>...]
    [INCLUDE_DIRS <dirs>...])

  Same as sps_add_gtest but also links GTest::gmock.

#]==]
function(sps_add_gmock name)
  set(options)
  set(oneValueArgs)
  set(multiValueArgs LIBRARIES INCLUDE_DIRS)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  # Use sps_add_gtest as base
  sps_add_gtest(${name} ${ARG_UNPARSED_ARGUMENTS}
    LIBRARIES ${ARG_LIBRARIES}
    INCLUDE_DIRS ${ARG_INCLUDE_DIRS})

  # Add GMock
  if(TARGET GTest::gmock)
    target_link_libraries(${name} PRIVATE GTest::gmock)
  elseif(TARGET gmock)
    target_link_libraries(${name} PRIVATE gmock)
  else()
    message(WARNING "GMock not available for target ${name}")
  endif()
endfunction()
