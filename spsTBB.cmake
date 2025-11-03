#[==[.rst:
*********
spsTBB
*********
 Cross-platform TBB setup:
  - On Linux, uses system TBB for STL parallel algorithms.
  - On Windows, fetches and builds TBB via FetchContent.
  - Provides targets: TBB::tbb, TBB::tbbmalloc, TBB::tbbmalloc_proxy
  - Ensures RPATH or DLLs are set correctly for runtime.
#]==]

include(FetchContent)

if(WIN32)
    # If TBB_DIR is already set, use it directly
    if(DEFINED TBB_DIR AND EXISTS "${TBB_DIR}")
        message(STATUS "🎯 Using provided TBB_DIR: ${TBB_DIR}")
        find_package(TBB 2021.0 QUIET CONFIG)
    else()
        find_package(TBB 2021.0 QUIET CONFIG)
    endif()

    if (TBB_FOUND)
      message(STATUS "✅ TBB found at: ${TBB_DIR}")
      set(USE_INSTALLED_TBB TRUE)

      get_filename_component(_tbb_install_prefix "${TBB_DIR}/../../.." ABSOLUTE)

      set(_tbb_lib_dir "${_tbb_install_prefix}/lib")
      set(_tbb_bin_dir "${_tbb_install_prefix}/bin")

      set_target_properties(TBB::tbb PROPERTIES
        IMPORTED_IMPLIB_RELEASE   "${_tbb_lib_dir}/tbb12.lib"
        IMPORTED_LOCATION_RELEASE "${_tbb_bin_dir}/tbb12.dll"
        IMPORTED_IMPLIB_DEBUG     "${_tbb_lib_dir}/tbb12_debug.lib"
        IMPORTED_LOCATION_DEBUG   "${_tbb_bin_dir}/tbb12_debug.dll"
      )      
    else()
      message(STATUS "❌ TBB NOT found - will use FetchContent")
      message(STATUS "   Searched in: ${CMAKE_PREFIX_PATH}")
      message(STATUS "   Looking for: TBBConfig.cmake or TBB-config.cmake")
      
      # Disable tests and examples
      set(TBB_TEST OFF CACHE BOOL "" FORCE)
      set(TBB_EXAMPLES OFF CACHE BOOL "" FORCE)
      set(TBB_STRICT OFF CACHE BOOL "" FORCE)
      set(TBB_VERSION "2021.13.0")
      
      FetchContent_Declare(
          oneTBB
          GIT_REPOSITORY https://github.com/oneapi-src/oneTBB.git
          GIT_TAG v${TBB_VERSION}
          CMAKE_ARGS
              -DBUILD_SHARED_LIBS=ON
              -DTBB_TEST=OFF
              -DTBB_EXAMPLES=OFF
      )
      
      FetchContent_MakeAvailable(oneTBB)
      
      # The targets exported by oneTBB
      foreach(tgt tbb tbbmalloc tbbmalloc_proxy)
          if(NOT TARGET TBB::${tgt} AND TARGET ${tgt})
              add_library(TBB::${tgt} ALIAS ${tgt})
          endif()
          message(STATUS "TBB target exists: ${tgt}")
          message(STATUS " - TYPE = $<TARGET_PROPERTY:${tgt},TYPE>")
          message(STATUS " - TARGET_FILE generator = $<TARGET_FILE:${tgt}>")
      endforeach()
    endif()
else()
    # Linux / macOS: try to find system TBB
    # If TBB_DIR is already set, use it directly
    if(DEFINED TBB_DIR AND EXISTS "${TBB_DIR}")
        message(STATUS "🎯 Using provided TBB_DIR: ${TBB_DIR}")
        find_package(TBB 2021.0 QUIET CONFIG)
    else()
        find_package(TBB 2021.0 QUIET CONFIG)
    endif()

    if(TBB_FOUND)
      set(USE_INSTALLED_TBB TRUE)      
      message(STATUS "✅ System TBB found at: ${TBB_LIBRARIES}")
      # Export canonical targets
      foreach(tgt tbb tbbmalloc tbbmalloc_proxy)
        if(NOT TARGET TBB::${tgt} AND TARGET ${tgt})
          add_library(TBB::${tgt} ALIAS ${tgt})
        endif()
      endforeach()
    else()
        message(WARNING "System TBB not found. You may need to install libtbb-dev or equivalent.")
    endif()
endif()
