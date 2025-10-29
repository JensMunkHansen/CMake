if (BUILD_TESTING)
  find_package(Catch2 QUIET)
  if (Catch2_FOUND)
    message(STATUS "✅ Catch2 found at: ${Catch2_DIR}")
    message(STATUS "   Catch2 version: ${Catch2_VERSION}")
    message(STATUS "   Catch2 include: ${Catch2_INCLUDE_DIRS}")
  else()
    message(STATUS "❌ Catch2 NOT found - will use FetchContent")
    message(STATUS "   Searched in: ${CMAKE_PREFIX_PATH}")
    message(STATUS "   Looking for: Catch2Config.cmake or catch2-config.cmake")

    include(FetchContent)

    include(CTest)
    FetchContent_Declare(
      catch2
      GIT_REPOSITORY https://github.com/catchorg/Catch2.git
      GIT_TAG v3.5.2
    )
    FetchContent_MakeAvailable(catch2)
    message(STATUS "✅ Catch2 downloaded via FetchContent")
  endif()
  include(Catch)
  enable_testing()

  include(CTest)

endif()

