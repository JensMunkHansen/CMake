# spsShaders.cmake — Shader compiler discovery (glslang)
#
# Provides targets:
#   glslang::glslang                         — frontend (TShader, TProgram)
#   glslang::SPIRV                           — SPIR-V codegen (GlslangToSpv)
#   glslang::glslang-default-resource-limits — GetDefaultResources()
#
# On Linux, find_package(glslang CONFIG) finds system packages directly.
# On Windows, the Vulkan SDK's glslang config files have broken relative paths
# (PACKAGE_PREFIX_DIR resolves to the wrong directory), so we find the libraries
# directly from $VULKAN_SDK/Lib and create the targets manually.

find_package(glslang CONFIG QUIET)

if(glslang_FOUND)
  message(STATUS "glslang: found via config-mode (targets: glslang::glslang, glslang::SPIRV)")
else()
  # Config-mode failed (expected on Windows).  Find libraries directly in the Vulkan SDK.
  if(NOT DEFINED ENV{VULKAN_SDK})
    message(FATAL_ERROR
      "glslang not found via config-mode and VULKAN_SDK is not set.\n"
      "Install glslang-dev (Linux) or set VULKAN_SDK to your Vulkan SDK root (Windows).")
  endif()

  set(_sdk "$ENV{VULKAN_SDK}")

  # glslang core libraries
  find_library(GLSLANG_LIB                NAMES glslang                         HINTS "${_sdk}/Lib" REQUIRED)
  find_library(GLSLANG_SPIRV_LIB          NAMES SPIRV                           HINTS "${_sdk}/Lib" REQUIRED)
  find_library(GLSLANG_RESOURCE_LIMITS_LIB NAMES glslang-default-resource-limits HINTS "${_sdk}/Lib" REQUIRED)
  find_library(GLSLANG_MACHINE_INDEPENDENT NAMES MachineIndependent             HINTS "${_sdk}/Lib" REQUIRED)
  find_library(GLSLANG_OS_DEPENDENT        NAMES OSDependent                    HINTS "${_sdk}/Lib" REQUIRED)
  find_library(GLSLANG_GENERIC_CODEGEN     NAMES GenericCodeGen                 HINTS "${_sdk}/Lib" REQUIRED)

  # SPIRV-Tools (transitive dependency of glslang::SPIRV)
  find_library(SPIRV_TOOLS_OPT_LIB NAMES SPIRV-Tools-opt HINTS "${_sdk}/Lib" REQUIRED)
  find_library(SPIRV_TOOLS_LIB     NAMES SPIRV-Tools     HINTS "${_sdk}/Lib" REQUIRED)

  # glslang::glslang — the frontend
  add_library(glslang::glslang STATIC IMPORTED)
  set_target_properties(glslang::glslang PROPERTIES
    IMPORTED_LOCATION "${GLSLANG_LIB}"
    INTERFACE_INCLUDE_DIRECTORIES "${_sdk}/Include"
    INTERFACE_LINK_LIBRARIES
      "${GLSLANG_MACHINE_INDEPENDENT};${GLSLANG_OS_DEPENDENT};${GLSLANG_GENERIC_CODEGEN}")

  # glslang::SPIRV — GlslangToSpv codegen
  add_library(glslang::SPIRV STATIC IMPORTED)
  set_target_properties(glslang::SPIRV PROPERTIES
    IMPORTED_LOCATION "${GLSLANG_SPIRV_LIB}"
    INTERFACE_INCLUDE_DIRECTORIES "${_sdk}/Include"
    INTERFACE_LINK_LIBRARIES
      "glslang::glslang;${SPIRV_TOOLS_OPT_LIB};${SPIRV_TOOLS_LIB}")

  # glslang::glslang-default-resource-limits — GetDefaultResources()
  add_library(glslang::glslang-default-resource-limits STATIC IMPORTED)
  set_target_properties(glslang::glslang-default-resource-limits PROPERTIES
    IMPORTED_LOCATION "${GLSLANG_RESOURCE_LIMITS_LIB}"
    INTERFACE_INCLUDE_DIRECTORIES "${_sdk}/Include")

  message(STATUS "glslang: found in Vulkan SDK at ${_sdk}")
endif()
