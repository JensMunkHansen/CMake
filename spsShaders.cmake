# spsShaders.cmake — Shader compiler discovery (glslang)
#
# Finds glslang for runtime GLSL → SPIR-V compilation.
# Provides targets:
#   glslang::glslang                         — frontend (TShader, TProgram)
#   glslang::SPIRV                           — SPIR-V codegen (GlslangToSpv)
#   glslang::glslang-default-resource-limits — GetDefaultResources()
#
# System package: glslang-dev (Debian/Ubuntu) or Vulkan SDK (Windows/macOS).
# Cross-platform — same CMake targets on all platforms.

find_package(glslang REQUIRED)
message(STATUS "glslang: found (targets: glslang::glslang, glslang::SPIRV)")
