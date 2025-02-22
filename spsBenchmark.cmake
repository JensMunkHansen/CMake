find_package(benchmark QUIET)

# If not found, use FetchContent
if (NOT benchmark_FOUND OR EMSCRIPTEN)
  include(FetchContent)
  message(STATUS "Google Benchmark not found, using FetchContent...")

  if (EMSCRIPTEN)
    set(CMAKE_CXX_FLAGS "-matomics -mbulk-memory")
    set(CMAKE_C_FLAGS "-matomics -mbulk-memory")
  endif()

  FetchContent_Declare(benchmark
    GIT_REPOSITORY https://github.com/google/benchmark.git
    GIT_TAG v1.8.3
    GIT_SHALLOW ON
    GIT_PROGRESS ON
    FIND_PACKAGE_ARGS 1.8.3
  )

  # Disable tests to speed up build
  set(BENCHMARK_ENABLE_TESTING OFF CACHE BOOL "Disable benchmark tests" FORCE)

  # Fetch and make it available
  FetchContent_MakeAvailable(benchmark)
else()
  message(STATUS "Using system benchmark")
endif()
