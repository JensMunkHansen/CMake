find_package(benchmark QUIET)

# If not found, use FetchContent
if (NOT benchmark_FOUND)
  include(FetchContent)
  message(STATUS "Google Benchmark not found, using FetchContent...")

  FetchContent_Declare(
    benchmark
    GIT_REPOSITORY https://github.com/google/benchmark.git
    GIT_TAG v1.8.3  # Update to the latest stable version if needed
  )

  # Disable tests to speed up build
  set(BENCHMARK_ENABLE_TESTING OFF CACHE BOOL "Disable benchmark tests" FORCE)

  # Fetch and make it available
  FetchContent_MakeAvailable(benchmark)
else()
  message(STATUS "Using system benchmark")
endif()
