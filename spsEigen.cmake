#[==[.rst:
*********
spsEigen
*********
 Eigen3 library setup with configurable version and smart search:
  - Searches for Eigen3 using CMAKE_PREFIX_PATH
  - Supports configurable version requirement
  - Provides clear status messages about found location
  - Falls back gracefully if not found
  - Sets Eigen3_DIR relative to CMAKE_PREFIX_PATH for reliable finding
#]==]

# Default version requirement
set(SPS_EIGEN3_DEFAULT_VERSION "3.4.0")
set(SPS_EIGEN3_VERSION "${SPS_EIGEN3_DEFAULT_VERSION}" CACHE STRING "Eigen3 version requirement")

message(STATUS "=== EIGEN3 SEARCH ===")
message(STATUS "Required version: ${SPS_EIGEN3_VERSION}")
message(STATUS "CMAKE_PREFIX_PATH: ${CMAKE_PREFIX_PATH}")

# Function to find and configure Eigen3
function(find_spseigen3)
    # Try to set Eigen3_DIR relative to CMAKE_PREFIX_PATH if available
    if(DEFINED CMAKE_PREFIX_PATH AND EXISTS "${CMAKE_PREFIX_PATH}")
        set(_eigen_search_paths "${CMAKE_PREFIX_PATH}")

        # Check each CMAKE_PREFIX_PATH entry
        foreach(_prefix ${CMAKE_PREFIX_PATH})
            set(_candidate_eigen_dir "${_prefix}/share/eigen3/cmake")
            if(EXISTS "${_candidate_eigen_dir}/Eigen3Config.cmake")
                set(Eigen3_DIR "${_candidate_eigen_dir}")
                message(STATUS "🎯 Found Eigen3Config.cmake at: ${_candidate_eigen_dir}")
                break()
            endif()
        endforeach()
    endif()

    # If Eigen3_DIR is set, use it directly
    if(DEFINED Eigen3_DIR AND EXISTS "${Eigen3_DIR}/Eigen3Config.cmake")
        message(STATUS "✅ Using provided Eigen3_DIR: ${Eigen3_DIR}")
        set(Eigen3_DIR "${Eigen3_DIR}" PARENT_SCOPE)
    else()
        message(STATUS "🔍 Searching for Eigen3 in standard paths...")
    endif()

    # Try to find Eigen3
    find_package(Eigen3 ${SPS_EIGEN3_VERSION} QUIET CONFIG)

    if(Eigen3_FOUND)
        message(STATUS "✅ Eigen3 ${Eigen3_VERSION} found successfully!")
        message(STATUS "   Location: ${Eigen3_DIR}")
        message(STATUS "   Include dirs: ${Eigen3_INCLUDE_DIRS}")

        # Set parent scope variables
        set(Eigen3_FOUND "${Eigen3_FOUND}" PARENT_SCOPE)
        set(Eigen3_VERSION "${Eigen3_VERSION}" PARENT_SCOPE)
        set(Eigen3_DIR "${Eigen3_DIR}" PARENT_SCOPE)
        set(Eigen3_INCLUDE_DIRS "${Eigen3_INCLUDE_DIRS}" PARENT_SCOPE)

    else()
        message(STATUS "❌ Eigen3 ${SPS_EIGEN3_VERSION} NOT FOUND")
        message(STATUS "   Tried CMAKE_PREFIX_PATH: ${CMAKE_PREFIX_PATH}")
        message(STATUS "   Searched for Eigen3Config.cmake in share/eigen3/cmake/")
        message(STATUS "")
        message(STATUS "💡 Solutions:")
        message(STATUS "   1. Install Eigen3 with: build-dependencies.sh")
        message(STATUS "   2. Set CMAKE_PREFIX_PATH to your install directory")
        message(STATUS "   3. Install system Eigen3: sudo apt install libeigen3-dev")
        message(STATUS "")

        # Set parent scope variables
        set(Eigen3_FOUND FALSE PARENT_SCOPE)
        set(Eigen3_VERSION "" PARENT_SCOPE)
        set(Eigen3_DIR "" PARENT_SCOPE)
        set(Eigen3_INCLUDE_DIRS "" PARENT_SCOPE)
    endif()
endfunction()

# Main execution
find_spseigen3()