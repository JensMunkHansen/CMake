# spsVulkan.cmake — Centralized Vulkan SDK discovery
#
# Finds Vulkan core + shaderc (shader compilation).
# Provides:
#   Vulkan::Vulkan   — main Vulkan loader
#   Vulkan::Headers  — headers-only (for dynamic loading)
#   vkwave::shaderc  — shaderc for runtime GLSL→SPIR-V compilation
#
# Strategy for shaderc:
#   1. Prefer the shared library (libshaderc.so) — it bundles glslang/SPIRV-Tools
#      internally and links cleanly into both shared and static consumers.
#   2. Fall back to the Vulkan SDK's shaderc_combined static archive with
#      WHOLE_ARCHIVE wrapping.

find_package(Vulkan REQUIRED)
message(STATUS "Vulkan: ${Vulkan_VERSION}")

# --- shaderc discovery ---
if(NOT TARGET vkwave::shaderc)
  # Try shared library first — works on all platforms without WHOLE_ARCHIVE issues.
  # Debian/Ubuntu: libshaderc-dev provides libshaderc.so
  find_library(_SHADERC_SHARED NAMES shaderc_shared shaderc)

  if(_SHADERC_SHARED AND NOT IS_SYMLINK_TO_STATIC)
    # Verify it's actually a shared library (not a .a)
    get_filename_component(_SHADERC_EXT "${_SHADERC_SHARED}" LAST_EXT)
    if(_SHADERC_EXT STREQUAL ".a")
      set(_SHADERC_SHARED "")
    endif()
  endif()

  if(_SHADERC_SHARED)
    message(STATUS "shaderc: ${_SHADERC_SHARED} (shared)")
    add_library(vkwave_shaderc INTERFACE)
    target_link_libraries(vkwave_shaderc INTERFACE "${_SHADERC_SHARED}")

    # Ensure shaderc headers are available (usually via Vulkan SDK or system)
    find_path(_SHADERC_INC shaderc/shaderc.hpp)
    if(_SHADERC_INC)
      target_include_directories(vkwave_shaderc INTERFACE "${_SHADERC_INC}")
    endif()
  else()
    # Fall back to Vulkan SDK's shaderc_combined (static archive).
    # Requires CMake 3.24 WHOLE_ARCHIVE to pull in glslang/SPIRV-Tools symbols.
    find_package(Vulkan REQUIRED COMPONENTS shaderc_combined)
    if(NOT TARGET Vulkan::shaderc_combined)
      message(FATAL_ERROR
        "shaderc not found. Install libshaderc-dev (Debian/Ubuntu) or the Vulkan SDK.")
    endif()
    message(STATUS "shaderc: ${Vulkan_shaderc_combined_LIBRARY} (static, WHOLE_ARCHIVE)")
    add_library(vkwave_shaderc INTERFACE)
    target_link_libraries(vkwave_shaderc INTERFACE
      $<LINK_LIBRARY:WHOLE_ARCHIVE,Vulkan::shaderc_combined>
    )
  endif()

  add_library(vkwave::shaderc ALIAS vkwave_shaderc)
  unset(_SHADERC_EXT)
endif()
