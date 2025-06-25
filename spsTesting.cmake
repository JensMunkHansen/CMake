if (BUILD_TESTING)
  find_package(Catch2 QUIET)
  if (NOT Catch2_FOUND)
    include(FetchContent)

    include(CTest)
    FetchContent_Declare(
      catch2
      GIT_REPOSITORY https://github.com/catchorg/Catch2.git
      GIT_TAG v3.5.2
    )
    FetchContent_MakeAvailable(catch2)
  endif()
  include(Catch)
  enable_testing()
endif()
