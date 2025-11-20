#[==[.rst:
*********
spsTesting
*********
  Include this for enabling the Catch2 test framework.
#]==]

include(spsSBOM)
sps_get_version(CATCH2_VERSION "3.5.2")

if (BUILD_TESTING)
  include(CTest)
  find_package(Catch2 ${CATCH2_VERSION} QUIET)
  if (Catch2_FOUND)
    message(STATUS "✅ Catch2 found at: ${Catch2_DIR}")
    message(STATUS "   Catch2 version: ${Catch2_VERSION}")
    message(STATUS "   Catch2 include: ${Catch2_INCLUDE_DIRS}")

    # Add RPATH for external Catch2 shared libraries
    if (BUILD_SHARED_LIBS AND TARGET Catch2::Catch2)
      # Get the path to Catch2 shared libraries
      get_target_property(CATCH2_LOCATION Catch2::Catch2 LOCATION)
      if(CATCH2_LOCATION)
        get_filename_component(CATCH2_LIB_DIR ${CATCH2_LOCATION} DIRECTORY)
        message(STATUS "   Adding Catch2 RPATH: ${CATCH2_LIB_DIR}")

        # Add Catch2 library directory to global RPATH for all test targets
        set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_RPATH}:${CATCH2_LIB_DIR}")
      endif()
    endif()
  else()
    message(STATUS "❌ Catch2 NOT found - will use FetchContent")
    message(STATUS "   Searched in: ${CMAKE_PREFIX_PATH}")
    message(STATUS "   Looking for: Catch2Config.cmake or catch2-config.cmake")

    # Backup BUILD_TESTING to prevent Catch2 from building its own tests
    set(SPS_BACKUP_BUILD_TESTING ${BUILD_TESTING})
    set(BUILD_TESTING OFF CACHE BOOL "Build tests (disabled for dependencies)" FORCE)

    include(FetchContent)

    FetchContent_Declare(
      catch2
      GIT_REPOSITORY https://github.com/catchorg/Catch2.git
      GIT_TAG v${CATCH2_VERSION}
    )
    FetchContent_MakeAvailable(catch2)
    message(STATUS "✅ Catch2 downloaded via FetchContent")

    # Restore original BUILD_TESTING value
    set(BUILD_TESTING ${SPS_BACKUP_BUILD_TESTING} CACHE BOOL "Build tests" FORCE)
  endif()
  include(Catch)
  enable_testing()
endif()

