find_package(benchmark QUIET)

set(USE_FETCH_CONTENT FALSE) # Try this to avoid benchmark is cleaned when rebuilding
# set(USE_FETCH_CONTENT TRUE)

# If not found, use FetchContent
if (NOT benchmark_FOUND OR EMSCRIPTEN)
  if (USE_FETCH_CONTENT)
    include(FetchContent)
    message(STATUS "Google Benchmark not found, using FetchContent...")
  
    if (EMSCRIPTEN)
      set(CMAKE_CXX_FLAGS "-matomics -mbulk-memory")
      set(CMAKE_C_FLAGS "-matomics -mbulk-memory")
    endif()
    
    set(CONTENT_BASE_DIR "${PROJECT_SOURCE_DIR}/../cmake-dependencies")
    file(MAKE_DIRECTORY "${CONTENT_BASE_DIR}")
    set(FETCHCONTENT_BASE_DIR "${CONTENT_BASE_DIR}")
  
    FetchContent_Declare(benchmark
      GIT_REPOSITORY https://github.com/google/benchmark.git
      GIT_TAG v1.8.3
      GIT_SHALLOW ON
      GIT_PROGRESS ON
      FIND_PACKAGE_ARGS 1.8.3
    )
  
    # Disable tests to speed up build
    set(BENCHMARK_ENABLE_TESTING OFF CACHE BOOL "Disable benchmark tests" FORCE)
    set(BENCHMARK_ENABLE_GTEST_TESTS OFF CACHE BOOL "Disable benchmark gtests" FORCE)
    # Fetch and make it available
    FetchContent_MakeAvailable(benchmark)
  else()
    # Define external directories outside the main build directory.
    set(EXTERNAL_DIR "${PROJECT_SOURCE_DIR}/../external_deps")
    set(BENCHMARK_SRC_DIR "${EXTERNAL_DIR}/benchmark/src")
    set(BENCHMARK_BUILD_DIR "${EXTERNAL_DIR}/benchmark/build")
    set(BENCHMARK_INSTALL_DIR "${EXTERNAL_DIR}/benchmark/install")

    # Define repository information.
    set(BENCHMARK_REPO "https://github.com/google/benchmark.git")
    set(BENCHMARK_TAG "v1.8.3")

    find_package(benchmark
      PATHS "${BENCHMARK_INSTALL_DIR}/lib/cmake/benchmark"
      QUIET)

    if (NOT benchmark_FOUND)
      # Fetch the source if it doesn't exist.
      if(NOT EXISTS "${BENCHMARK_SRC_DIR}")
        message(STATUS "Cloning Google Benchmark repository...")
        file(MAKE_DIRECTORY "${EXTERNAL_DIR}/benchmark")
        execute_process(
      	  COMMAND git clone --branch ${BENCHMARK_TAG} --depth 1 ${BENCHMARK_REPO} "${BENCHMARK_SRC_DIR}"
      	  WORKING_DIRECTORY "${EXTERNAL_DIR}/benchmark"
      	  RESULT_VARIABLE GIT_CLONE_RESULT
        )
        if(NOT GIT_CLONE_RESULT EQUAL 0)
      	  message(FATAL_ERROR "Failed to clone Google Benchmark repository")
        endif()
      endif()
      
      # Create build and install directories.
      file(MAKE_DIRECTORY "${BENCHMARK_BUILD_DIR}")
      file(MAKE_DIRECTORY "${BENCHMARK_INSTALL_DIR}")
      message(${BENCHMARK_INSTALL_DIR})
      # Configure Google Benchmark.
      message(STATUS "Configuring Google Benchmark...")
      execute_process(
        COMMAND ${CMAKE_COMMAND} -S "${BENCHMARK_SRC_DIR}" -B "${BENCHMARK_BUILD_DIR}"
            -DCMAKE_INSTALL_PREFIX=${BENCHMARK_INSTALL_DIR}
	    -DCMAKE_CONFIGURATION_TYPES="Debug;Release"	
            -DBENCHMARK_ENABLE_TESTING=OFF
            -DBENCHMARK_ENABLE_GTEST_TESTS=OFF
      	  RESULT_VARIABLE CONFIG_RESULT
      )
      if(NOT CONFIG_RESULT EQUAL 0)
        message(FATAL_ERROR "Failed to configure Google Benchmark")
      endif()

      # Build and install Debug configuration.
      message(STATUS "Building and installing Google Benchmark (Debug)...")
      execute_process(
	COMMAND ${CMAKE_COMMAND} --build "${BENCHMARK_BUILD_DIR}" --target install --config Debug
	RESULT_VARIABLE BUILD_RESULT_DEBUG
      )
      if(NOT BUILD_RESULT_DEBUG EQUAL 0)
	message(FATAL_ERROR "Failed to build/install Google Benchmark (Debug)")
      endif()

      # Build and install Release configuration.
      message(STATUS "Building and installing Google Benchmark (Release)...")
      execute_process(
	COMMAND ${CMAKE_COMMAND} --build "${BENCHMARK_BUILD_DIR}" --target install --config Release
	RESULT_VARIABLE BUILD_RESULT_RELEASE
      )
      if(NOT BUILD_RESULT_RELEASE EQUAL 0)
	message(FATAL_ERROR "Failed to build/install Google Benchmark (Release)")
      endif()

      # Now you can use find_package to import benchmark.
      # Note: Depending on how Benchmark installs its package configuration files,
      # you might have configuration-specific subdirectories.
      set(benchmark_DIR "${BENCHMARK_INSTALL_DIR}/lib/cmake/benchmark")
      find_package(benchmark CONFIG REQUIRED)
    endif()
  endif()
else()
  message(STATUS "Using system benchmark")
endif()
