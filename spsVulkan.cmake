# spsVulkan.cmake — Centralized Vulkan SDK discovery
#
# Finds Vulkan core.
# Provides:
#   Vulkan::Vulkan   — main Vulkan loader
#   Vulkan::Headers  — headers-only (for dynamic loading)
#
# Shader compiler discovery is in spsShaders.cmake.

find_package(Vulkan REQUIRED)
message(STATUS "Vulkan: ${Vulkan_VERSION}")
