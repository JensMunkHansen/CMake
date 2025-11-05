#[==[.rst:
*********
spsEigen
*********
 Eigen3 library setup with simple find/fallback:
  - Try to find Eigen3 using CONFIG with NO_CMAKE_PACKAGE_REGISTRY
  - Falls back to FetchContent if not found
  - Applies patch to disable unnecessary components
#]==]

set(SPS_EIGEN3_VERSION "3.4.0")

message(STATUS "=== EIGEN3 SEARCH ===")

# Try to find Eigen3, avoiding user registry
find_package(Eigen3 ${SPS_EIGEN3_VERSION} QUIET CONFIG NO_MODULE NO_CMAKE_PACKAGE_REGISTRY)

if(Eigen3_FOUND)
    message(STATUS "✅ Eigen3 ${Eigen3_VERSION} found successfully!")
    message(STATUS "   Location: ${Eigen3_DIR}")
    message(STATUS "   Include dirs: ${Eigen3_INCLUDE_DIRS}")
else()
    message(STATUS "❌ Eigen3 NOT FOUND")
    message(STATUS "🔨 Building Eigen3 ${SPS_EIGEN3_VERSION} from source...")

    # Backup BUILD_TESTING to prevent Eigen3 from building its own tests
    set(SPS_BACKUP_BUILD_TESTING ${BUILD_TESTING})
    set(BUILD_TESTING OFF CACHE BOOL "Build tests (disabled for dependencies)" FORCE)

    include(FetchContent)

    # Get the patch file path
    set(_eigen_patch_file "${CMAKE_CURRENT_LIST_DIR}/spsEigen.patch")

    FetchContent_Declare(
        eigen3
        GIT_REPOSITORY https://gitlab.com/libeigen/eigen.git
        GIT_TAG ${SPS_EIGEN3_VERSION}
        PATCH_COMMAND git apply "${_eigen_patch_file}"
        CMAKE_ARGS
            -DCMAKE_Fortran_COMPILER:FILEPATH=   # Disable Fortran to avoid MSVC/MinGW conflicts
            -DEIGEN_TESTING=OFF
            -DEIGEN_BUILD_DOC=OFF
    )

    # Ignore deprecation warning for FetchContent_Populate
    cmake_policy(SET CMP0169 OLD)
    FetchContent_MakeAvailable(eigen3)

    # Restore original BUILD_TESTING value
    set(BUILD_TESTING ${SPS_BACKUP_BUILD_TESTING} CACHE BOOL "Build tests" FORCE)

    message(STATUS "✅ Eigen3 ${SPS_EIGEN3_VERSION} built and configured successfully!")
    message(STATUS "   Location: ${eigen3_SOURCE_DIR}")
endif()
