#[==[.rst:
**********
spsDotNet
**********

  Provides functions for building .NET/NuGet packages from native C/C++ libraries
  and creating .NET test projects that consume them.

  Overview:
    This module enables CMake projects to create NuGet packages containing native
    libraries with P/Invoke bindings, using CMake's ``file(GET_RUNTIME_DEPENDENCIES)``
    to automatically discover and include shared library dependencies.

  Output Structure (aligned with CMake multi-config):
    For a Release CMake build with Release .NET config:
      build/Release/bin/              - Native libraries
      build/Release/bin/Release/      - .NET config
        net8.0/linux-x64/             - TFM and RID
          GridSearch.dll              - Managed assembly + native deps
      build/Release/packages/         - NuGet packages

  Usage:
    include(spsDotNet)

    sps_add_dotnet_library(
      NAME GridSearch
      NATIVE_TARGETS GridSearch
      SOURCES GridSearch.cs
    )

    sps_add_dotnet_test(
      NAME GridSearchTest
      SOURCES GridSearchTest.cs
      PACKAGE_REF GridSearch
      DEPENDS GridSearch_dotnet_pack
    )

  Then build with: cmake --build build --target GridSearchTest_build

#]==]

include_guard(GLOBAL)

# Global property to track .NET projects for solution generation
define_property(GLOBAL PROPERTY SPS_DOTNET_PROJECTS
  BRIEF_DOCS "List of .NET projects for solution generation"
  FULL_DOCS "Each entry is: NAME;CSPROJ_PATH;GUID"
)
set_property(GLOBAL PROPERTY SPS_DOTNET_PROJECTS "")

#[==[
  sps_find_dotnet - Find .NET CLI and configure runtime identifier

  Sets the following variables in parent scope:
    SPS_DOTNET_EXECUTABLE - Path to dotnet executable
    SPS_DOTNET_RID        - Runtime identifier (e.g., linux-x64, win-x64, osx-arm64)
    SPS_DOTNET_FOUND      - TRUE if dotnet was found

  Example:
    sps_find_dotnet()
    if(SPS_DOTNET_FOUND)
      message(STATUS "Found .NET for ${SPS_DOTNET_RID}")
    endif()
#]==]
function(sps_find_dotnet)
  find_program(SPS_DOTNET_EXECUTABLE NAMES dotnet)

  if(NOT SPS_DOTNET_EXECUTABLE)
    message(STATUS ".NET CLI not found - .NET targets disabled")
    set(SPS_DOTNET_FOUND FALSE PARENT_SCOPE)
    return()
  endif()

  # Query Runtime Identifier (RID) from dotnet itself
  # https://docs.microsoft.com/en-us/dotnet/core/rid-catalog
  execute_process(
    COMMAND ${SPS_DOTNET_EXECUTABLE} --info
    OUTPUT_VARIABLE _DOTNET_INFO
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
  )

  # Parse RID from "dotnet --info" output (line format: " RID:         linux-x64")
  if(_DOTNET_INFO MATCHES "RID:[ \t]+([a-zA-Z0-9_\\-]+)")
    set(_RID "${CMAKE_MATCH_1}")
  else()
    # Fallback: compute RID from platform info
    message(WARNING "Could not parse RID from 'dotnet --info', using fallback")
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64|ARM64)")
      set(_PLATFORM "arm64")
    else()
      set(_PLATFORM "x64")
    endif()
    if(APPLE)
      set(_RID "osx-${_PLATFORM}")
    elseif(UNIX)
      set(_RID "linux-${_PLATFORM}")
    elseif(WIN32)
      set(_RID "win-${_PLATFORM}")
    else()
      set(_RID "unknown")
    endif()
  endif()

  # Use CACHE variables for visibility across add_subdirectory() calls
  set(SPS_DOTNET_EXECUTABLE "${SPS_DOTNET_EXECUTABLE}" CACHE FILEPATH ".NET CLI executable")
  set(SPS_DOTNET_RID "${_RID}" CACHE STRING ".NET Runtime Identifier")
  set(SPS_DOTNET_FOUND TRUE CACHE BOOL ".NET found")

  message(STATUS "Found .NET CLI: ${SPS_DOTNET_EXECUTABLE}")
  message(STATUS ".NET Runtime ID: ${_RID}")
endfunction()

#[==[
  sps_add_dotnet_library - Create a NuGet package from native library

  Creates targets for building a .NET library and NuGet package that wraps
  native C/C++ libraries. Runtime dependencies are automatically discovered
  using CMake's file(GET_RUNTIME_DEPENDENCIES).

  Arguments:
    NAME           - Name of the .NET project and NuGet package (required)
    NATIVE_TARGETS - List of native library targets to include (required)
    SOURCES        - List of C# source files (required)
    TFM            - Target Framework Moniker (default: net8.0)
    VERSION        - Package version (default: ${PROJECT_VERSION})
    AUTHORS        - Package authors (default: ${PROJECT_NAME} Authors)
    DESCRIPTION    - Package description (optional)

  Creates targets:
    ${NAME}_collect_deps  - Collect native dependencies
    ${NAME}_dotnet_build  - Build the .NET library
    ${NAME}_dotnet_pack   - Create NuGet package

  Output:
    NuGet package is created in ${SPS_DOTNET_PACKAGES_DIR}

  Example:
    sps_add_dotnet_library(
      NAME GridSearch
      NATIVE_TARGETS GridSearch
      SOURCES GridSearch.cs
      DESCRIPTION "Ray-grid intersection library"
    )
#]==]
function(sps_add_dotnet_library)
  cmake_parse_arguments(DOTNET
    ""
    "NAME;TFM;VERSION;AUTHORS;DESCRIPTION"
    "NATIVE_TARGETS;SOURCES"
    ${ARGN}
  )

  # Validate required arguments
  if(NOT DOTNET_NAME)
    message(FATAL_ERROR "sps_add_dotnet_library: NAME is required")
  endif()
  if(NOT DOTNET_NATIVE_TARGETS)
    message(FATAL_ERROR "sps_add_dotnet_library: NATIVE_TARGETS is required")
  endif()
  if(NOT DOTNET_SOURCES)
    message(FATAL_ERROR "sps_add_dotnet_library: SOURCES is required")
  endif()

  # Set defaults
  if(NOT DOTNET_TFM)
    set(DOTNET_TFM "net8.0")
  endif()
  if(NOT DOTNET_VERSION)
    set(DOTNET_VERSION "${PROJECT_VERSION}")
  endif()
  if(NOT DOTNET_AUTHORS)
    set(DOTNET_AUTHORS "${PROJECT_NAME} Authors")
  endif()
  if(NOT DOTNET_DESCRIPTION)
    set(DOTNET_DESCRIPTION "${DOTNET_NAME} native library bindings")
  endif()

  # Ensure dotnet is available
  if(NOT SPS_DOTNET_FOUND)
    sps_find_dotnet()
    if(NOT SPS_DOTNET_FOUND)
      message(WARNING "sps_add_dotnet_library: .NET not found, skipping ${DOTNET_NAME}")
      return()
    endif()
  endif()

  # Set PREFIX "" on all native targets for cross-platform P/Invoke compatibility
  foreach(_TARGET ${DOTNET_NATIVE_TARGETS})
    set_target_properties(${_TARGET} PROPERTIES PREFIX "")
  endforeach()

  # Use first target as the primary P/Invoke target
  list(GET DOTNET_NATIVE_TARGETS 0 _PRIMARY_TARGET)

  # Output structure aligned with CMake multi-config:
  #   ${CMAKE_BINARY_DIR}/$<CONFIG>/bin/           - Base output (managed + native)
  #   ${CMAKE_BINARY_DIR}/$<CONFIG>/packages/      - NuGet packages
  #   ${CMAKE_BINARY_DIR}/$<CONFIG>/dotnet-src/    - Project files (intermediate)
  set(_CONFIG_DIR "${CMAKE_BINARY_DIR}/$<CONFIG>")
  set(_PROJECT_DIR "${_CONFIG_DIR}/dotnet-src/${DOTNET_NAME}")
  set(_BIN_DIR "${_CONFIG_DIR}/${CMAKE_INSTALL_BINDIR}")
  set(_PACKAGES_DIR "${_CONFIG_DIR}/packages")
  set(_NATIVE_DIR "${_PROJECT_DIR}/native")

  # Scripts directory (config-independent, file(WRITE) doesn't support genex)
  set(_SCRIPTS_DIR "${CMAKE_BINARY_DIR}/dotnet-scripts")
  file(MAKE_DIRECTORY "${_SCRIPTS_DIR}")

  # Generate CMake script to collect runtime dependencies at build time
  set(_COLLECT_SCRIPT "${_SCRIPTS_DIR}/${DOTNET_NAME}_collect_deps.cmake")
  file(WRITE "${_COLLECT_SCRIPT}"
"# Collect runtime dependencies for ${DOTNET_NAME}
# Generated by spsDotNet.cmake - do not edit
cmake_minimum_required(VERSION 3.16)

set(NATIVE_LIB \"\${NATIVE_LIB_PATH}\")
set(OUTPUT_DIR \"\${OUTPUT_DIR}\")
set(PINVOKE_NAME \"\${PINVOKE_NAME}\")

file(MAKE_DIRECTORY \${OUTPUT_DIR})

# Get runtime dependencies using CMake's built-in mechanism
file(GET_RUNTIME_DEPENDENCIES
  LIBRARIES \${NATIVE_LIB}
  RESOLVED_DEPENDENCIES_VAR RESOLVED_DEPS
  UNRESOLVED_DEPENDENCIES_VAR UNRESOLVED_DEPS
  POST_EXCLUDE_REGEXES
    # Linux system libraries
    \"^/lib/\" \"^/usr/lib\" \"^/lib64/\" \"^/usr/lib64/\"
    # Windows system libraries (handle both / and \\ path separators)
    \"[Cc]:[/\\\\][Ww][Ii][Nn][Dd][Oo][Ww][Ss][/\\\\]\"
    \"^api-ms-\" \"^ext-ms-\"
    # Common Windows system DLLs by name
    \"kernel32\\\\.dll$\" \"ntdll\\\\.dll$\" \"user32\\\\.dll$\" \"gdi32\\\\.dll$\"
    \"advapi32\\\\.dll$\" \"shell32\\\\.dll$\" \"ole32\\\\.dll$\" \"oleaut32\\\\.dll$\"
    \"msvcrt\\\\.dll$\" \"ws2_32\\\\.dll$\" \"crypt32\\\\.dll$\" \"secur32\\\\.dll$\"
)

# Copy main library and create P/Invoke symlink
get_filename_component(LIB_NAME \${NATIVE_LIB} NAME)

# Determine P/Invoke filename based on platform
if(CMAKE_HOST_SYSTEM_NAME STREQUAL \"Windows\")
  set(PINVOKE_FILE \"\${PINVOKE_NAME}.dll\")
elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL \"Darwin\")
  set(PINVOKE_FILE \"\${PINVOKE_NAME}.dylib\")
else()
  set(PINVOKE_FILE \"\${PINVOKE_NAME}.so\")
endif()

# Copy and rename library to P/Invoke-compatible name
file(COPY \${NATIVE_LIB} DESTINATION \${OUTPUT_DIR})
if(NOT \"\${LIB_NAME}\" STREQUAL \"\${PINVOKE_FILE}\")
  file(RENAME \"\${OUTPUT_DIR}/\${LIB_NAME}\" \"\${OUTPUT_DIR}/\${PINVOKE_FILE}\")
  message(STATUS \"Copied: \${LIB_NAME} -> \${PINVOKE_FILE}\")
else()
  message(STATUS \"Copied: \${LIB_NAME}\")
endif()

# Copy PDB file if it exists (Windows only)
if(CMAKE_HOST_SYSTEM_NAME STREQUAL \"Windows\")
  get_filename_component(LIB_DIR \${NATIVE_LIB} DIRECTORY)
  get_filename_component(LIB_NAME_WE \${NATIVE_LIB} NAME_WE)
  set(PDB_FILE \"\${LIB_DIR}/\${LIB_NAME_WE}.pdb\")
  if(EXISTS \${PDB_FILE})
    file(COPY \${PDB_FILE} DESTINATION \${OUTPUT_DIR})
    message(STATUS \"Copied PDB: \${LIB_NAME_WE}.pdb\")
  endif()
endif()

# Copy resolved dependencies (project libraries only)
foreach(DEP \${RESOLVED_DEPS})
  get_filename_component(DEP_NAME \${DEP} NAME)
  file(COPY \${DEP} DESTINATION \${OUTPUT_DIR})
  message(STATUS \"Copied dependency: \${DEP_NAME}\")
endforeach()

if(UNRESOLVED_DEPS)
  message(STATUS \"Unresolved (system libs, ignored): \${UNRESOLVED_DEPS}\")
endif()
")

  # Generate .csproj file
  # BaseOutputPath controls where bin/ goes - .NET adds $<DOTNET_CONFIG>/${TFM}/${RID}/
  set(_CSPROJ_CONTENT
"<Project Sdk=\"Microsoft.NET.Sdk\">

  <PropertyGroup>
    <TargetFramework>${DOTNET_TFM}</TargetFramework>
    <RuntimeIdentifier>${SPS_DOTNET_RID}</RuntimeIdentifier>
    <ImplicitUsings>disable</ImplicitUsings>
    <Nullable>disable</Nullable>
    <AllowUnsafeBlocks>true</AllowUnsafeBlocks>

    <!-- Output aligned with CMake multi-config structure -->
    <BaseOutputPath>${_BIN_DIR}/</BaseOutputPath>
    <BaseIntermediateOutputPath>${_PROJECT_DIR}/obj/</BaseIntermediateOutputPath>

    <!-- NuGet Package Properties -->
    <PackageId>${DOTNET_NAME}</PackageId>
    <Version>${DOTNET_VERSION}</Version>
    <Authors>${DOTNET_AUTHORS}</Authors>
    <Description>${DOTNET_DESCRIPTION}</Description>
    <PackageOutputPath>${_PACKAGES_DIR}</PackageOutputPath>
  </PropertyGroup>

  <ItemGroup>
    <!-- Native libraries (main target and all dependencies) -->
    <Content Include=\"${_NATIVE_DIR}/*\">
      <PackagePath>runtimes/${SPS_DOTNET_RID}/native/%(Filename)%(Extension)</PackagePath>
      <Pack>true</Pack>
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
    </Content>
  </ItemGroup>

</Project>
")

  # Use file(GENERATE) for config-specific .csproj
  # _PROJECT_DIR already contains $<CONFIG>, so just use it directly
  file(GENERATE
    OUTPUT "${_PROJECT_DIR}/${DOTNET_NAME}.csproj"
    CONTENT "${_CSPROJ_CONTENT}"
  )

  # Copy C# sources to project directory (config-specific)
  foreach(_SOURCE ${DOTNET_SOURCES})
    get_filename_component(_SOURCE_NAME "${_SOURCE}" NAME)
    file(GENERATE
      OUTPUT "${_PROJECT_DIR}/${_SOURCE_NAME}"
      INPUT "${CMAKE_CURRENT_SOURCE_DIR}/${_SOURCE}"
    )
  endforeach()

  # Target to collect native dependencies
  add_custom_target(${DOTNET_NAME}_collect_deps
    COMMAND ${CMAKE_COMMAND}
      -DNATIVE_LIB_PATH=$<TARGET_FILE:${_PRIMARY_TARGET}>
      -DOUTPUT_DIR=${_NATIVE_DIR}
      -DPINVOKE_NAME=${DOTNET_NAME}
      -P "${_COLLECT_SCRIPT}"
    DEPENDS ${DOTNET_NATIVE_TARGETS}
    COMMENT "Collecting native dependencies for ${DOTNET_NAME}"
  )

  # Target to build the .NET library
  add_custom_target(${DOTNET_NAME}_dotnet_build
    COMMAND ${SPS_DOTNET_EXECUTABLE} build -c $<CONFIG> ${DOTNET_NAME}.csproj
    DEPENDS ${DOTNET_NAME}_collect_deps
    WORKING_DIRECTORY "${_PROJECT_DIR}"
    COMMENT "Building ${DOTNET_NAME} .NET library"
  )

  # Target to create NuGet package (ALL so it builds with regular build)
  add_custom_target(${DOTNET_NAME}_dotnet_pack ALL
    COMMAND ${SPS_DOTNET_EXECUTABLE} pack -c $<CONFIG> --no-build ${DOTNET_NAME}.csproj
    DEPENDS ${DOTNET_NAME}_dotnet_build
    WORKING_DIRECTORY "${_PROJECT_DIR}"
    COMMENT "Creating ${DOTNET_NAME} NuGet package"
  )

  # Register project for solution generation
  string(UUID _PROJECT_GUID NAMESPACE "6BA7B810-9DAD-11D1-80B4-00C04FD430C8"
    NAME "${DOTNET_NAME}" TYPE SHA1 UPPER)
  set_property(GLOBAL APPEND PROPERTY SPS_DOTNET_PROJECTS
    "${DOTNET_NAME}|${_PROJECT_DIR}/${DOTNET_NAME}.csproj|{${_PROJECT_GUID}}"
  )

  message(STATUS "Configured .NET library: ${DOTNET_NAME}")
  message(STATUS "  Targets: ${DOTNET_NAME}_dotnet_build, ${DOTNET_NAME}_dotnet_pack")
  message(STATUS "  Output: \${CMAKE_BINARY_DIR}/\$<CONFIG>/bin/\$<DOTNET_CONFIG>/${DOTNET_TFM}/${SPS_DOTNET_RID}/")
  message(STATUS "  NuGet: \${CMAKE_BINARY_DIR}/\$<CONFIG>/packages/")
endfunction()

#[==[
  sps_add_dotnet_test - Create a .NET test project

  Creates a .NET console application that references a local NuGet package
  for testing P/Invoke bindings. Integrates with CTest.

  Arguments:
    NAME         - Name of the test project (required)
    SOURCES      - List of C# source files (required)
    PACKAGE_REF  - Name of NuGet package to reference (required)
    DEPENDS      - CMake target dependencies (typically ${PACKAGE_REF}_dotnet_pack)
    TFM          - Target Framework Moniker (default: net8.0)

  Creates targets:
    ${NAME}_create - Create test project and add package reference
    ${NAME}_build  - Build the test project
    ${NAME}_run    - Run the test (also registered with CTest)

  Example:
    sps_add_dotnet_test(
      NAME GridSearchTest
      SOURCES GridSearchTest.cs
      PACKAGE_REF GridSearch
      DEPENDS GridSearch_dotnet_pack
    )
#]==]
function(sps_add_dotnet_test)
  cmake_parse_arguments(TEST
    ""
    "NAME;PACKAGE_REF;TFM"
    "SOURCES;DEPENDS"
    ${ARGN}
  )

  # Validate required arguments
  if(NOT TEST_NAME)
    message(FATAL_ERROR "sps_add_dotnet_test: NAME is required")
  endif()
  if(NOT TEST_SOURCES)
    message(FATAL_ERROR "sps_add_dotnet_test: SOURCES is required")
  endif()
  if(NOT TEST_PACKAGE_REF)
    message(FATAL_ERROR "sps_add_dotnet_test: PACKAGE_REF is required")
  endif()

  # Set defaults
  if(NOT TEST_TFM)
    set(TEST_TFM "net8.0")
  endif()

  # Ensure dotnet is available
  if(NOT SPS_DOTNET_FOUND)
    sps_find_dotnet()
    if(NOT SPS_DOTNET_FOUND)
      message(WARNING "sps_add_dotnet_test: .NET not found, skipping ${TEST_NAME}")
      return()
    endif()
  endif()

  # Test output aligned with CMake multi-config structure
  set(_CONFIG_DIR "${CMAKE_BINARY_DIR}/$<CONFIG>")
  set(_TEST_DIR "${_CONFIG_DIR}/dotnet-src/tests/${TEST_NAME}")
  set(_PACKAGES_DIR "${_CONFIG_DIR}/packages")

  # Get first source file for Program.cs
  list(GET TEST_SOURCES 0 _MAIN_SOURCE)
  get_filename_component(_MAIN_SOURCE_ABS "${_MAIN_SOURCE}" ABSOLUTE
    BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")

  # Generate Directory.Build.props to set BaseIntermediateOutputPath early
  # This prevents MSB3539 warning about property being modified after use
  set(_DIR_BUILD_PROPS
"<Project>
  <PropertyGroup>
    <BaseIntermediateOutputPath>$(MSBuildProjectDirectory)/obj/</BaseIntermediateOutputPath>
  </PropertyGroup>
</Project>
")
  file(GENERATE
    OUTPUT "${_TEST_DIR}/Directory.Build.props"
    CONTENT "${_DIR_BUILD_PROPS}"
  )

  # Target to create and configure test project
  add_custom_target(${TEST_NAME}_create
    COMMAND ${CMAKE_COMMAND} -E make_directory "${_TEST_DIR}"
    COMMAND ${SPS_DOTNET_EXECUTABLE} new console
      --force
      --framework ${TEST_TFM}
      --output "${_TEST_DIR}"
    COMMAND ${CMAKE_COMMAND} -E copy
      "${_MAIN_SOURCE_ABS}"
      "${_TEST_DIR}/Program.cs"
    COMMAND ${SPS_DOTNET_EXECUTABLE} add "${_TEST_DIR}" package
      ${TEST_PACKAGE_REF}
      --source "${_PACKAGES_DIR}"
    DEPENDS ${TEST_DEPENDS}
    COMMENT "Creating test project ${TEST_NAME}"
  )

  # Target to build test (ALL so it builds with regular build)
  add_custom_target(${TEST_NAME}_build ALL
    COMMAND ${SPS_DOTNET_EXECUTABLE} build "${_TEST_DIR}" -c $<CONFIG>
    DEPENDS ${TEST_NAME}_create
    COMMENT "Building ${TEST_NAME}"
  )

  # Target to run test
  add_custom_target(${TEST_NAME}_run
    COMMAND ${SPS_DOTNET_EXECUTABLE} run --project "${_TEST_DIR}" -c $<CONFIG>
    DEPENDS ${TEST_NAME}_build
    COMMENT "Running ${TEST_NAME}"
  )

  # Register with CTest
  add_test(
    NAME ${TEST_NAME}
    COMMAND ${SPS_DOTNET_EXECUTABLE} run --project "${_TEST_DIR}" -c $<CONFIG>
  )

  # Register project for solution generation
  string(UUID _PROJECT_GUID NAMESPACE "6BA7B810-9DAD-11D1-80B4-00C04FD430C8"
    NAME "${TEST_NAME}" TYPE SHA1 UPPER)
  set_property(GLOBAL APPEND PROPERTY SPS_DOTNET_PROJECTS
    "${TEST_NAME}|${_TEST_DIR}/${TEST_NAME}.csproj|{${_PROJECT_GUID}}"
  )

  message(STATUS "Configured .NET test: ${TEST_NAME}")
  message(STATUS "  Targets: ${TEST_NAME}_build, ${TEST_NAME}_run")
endfunction()

#[==[
  sps_add_dotnet_executable - Create a .NET console executable

  Creates a .NET console application that references a local NuGet package.
  Unlike sps_add_dotnet_test, this does not register with CTest and supports
  additional options like unsafe code.

  Arguments:
    NAME         - Name of the executable project (required)
    SOURCES      - List of C# source files (required)
    PACKAGE_REF  - Name of NuGet package to reference (required)
    DEPENDS      - CMake target dependencies (typically ${PACKAGE_REF}_dotnet_pack)
    TFM          - Target Framework Moniker (default: net8.0)
    ALLOW_UNSAFE - Enable unsafe code blocks (default: OFF)

  Creates targets:
    ${NAME}_create - Create project and add package reference
    ${NAME}_build  - Build the executable
    ${NAME}_run    - Run the executable

  Example:
    sps_add_dotnet_executable(
      NAME GridSearchBenchmark
      SOURCES GridSearchBenchmark.cs
      PACKAGE_REF GridSearch
      DEPENDS GridSearch_dotnet_pack
      ALLOW_UNSAFE
    )
#]==]
function(sps_add_dotnet_executable)
  cmake_parse_arguments(EXE
    "ALLOW_UNSAFE"
    "NAME;PACKAGE_REF;TFM"
    "SOURCES;DEPENDS"
    ${ARGN}
  )

  # Validate required arguments
  if(NOT EXE_NAME)
    message(FATAL_ERROR "sps_add_dotnet_executable: NAME is required")
  endif()
  if(NOT EXE_SOURCES)
    message(FATAL_ERROR "sps_add_dotnet_executable: SOURCES is required")
  endif()
  if(NOT EXE_PACKAGE_REF)
    message(FATAL_ERROR "sps_add_dotnet_executable: PACKAGE_REF is required")
  endif()

  # Set defaults
  if(NOT EXE_TFM)
    set(EXE_TFM "net8.0")
  endif()

  # Ensure dotnet is available
  if(NOT SPS_DOTNET_FOUND)
    sps_find_dotnet()
    if(NOT SPS_DOTNET_FOUND)
      message(WARNING "sps_add_dotnet_executable: .NET not found, skipping ${EXE_NAME}")
      return()
    endif()
  endif()

  # Output aligned with CMake multi-config structure
  set(_CONFIG_DIR "${CMAKE_BINARY_DIR}/$<CONFIG>")
  set(_EXE_DIR "${_CONFIG_DIR}/dotnet-src/executables/${EXE_NAME}")
  set(_PACKAGES_DIR "${_CONFIG_DIR}/packages")

  # Build options
  set(_BUILD_OPTIONS "")
  if(EXE_ALLOW_UNSAFE)
    set(_BUILD_OPTIONS "-p:AllowUnsafeBlocks=true")
  endif()

  # Get first source file for Program.cs
  list(GET EXE_SOURCES 0 _MAIN_SOURCE)
  get_filename_component(_MAIN_SOURCE_ABS "${_MAIN_SOURCE}" ABSOLUTE
    BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")

  # Generate Directory.Build.props to set BaseIntermediateOutputPath early
  # This prevents MSB3539 warning about property being modified after use
  if(EXE_ALLOW_UNSAFE)
    set(_UNSAFE_PROP "\n    <AllowUnsafeBlocks>true</AllowUnsafeBlocks>")
  else()
    set(_UNSAFE_PROP "")
  endif()
  set(_DIR_BUILD_PROPS
"<Project>
  <PropertyGroup>
    <BaseIntermediateOutputPath>$(MSBuildProjectDirectory)/obj/</BaseIntermediateOutputPath>${_UNSAFE_PROP}
  </PropertyGroup>
</Project>
")
  file(GENERATE
    OUTPUT "${_EXE_DIR}/Directory.Build.props"
    CONTENT "${_DIR_BUILD_PROPS}"
  )

  # Target to create and configure executable project
  add_custom_target(${EXE_NAME}_create
    COMMAND ${CMAKE_COMMAND} -E make_directory "${_EXE_DIR}"
    COMMAND ${SPS_DOTNET_EXECUTABLE} new console
      --force
      --framework ${EXE_TFM}
      --output "${_EXE_DIR}"
    COMMAND ${CMAKE_COMMAND} -E copy
      "${_MAIN_SOURCE_ABS}"
      "${_EXE_DIR}/Program.cs"
    COMMAND ${SPS_DOTNET_EXECUTABLE} add "${_EXE_DIR}" package
      ${EXE_PACKAGE_REF}
      --source "${_PACKAGES_DIR}"
    DEPENDS ${EXE_DEPENDS}
    COMMENT "Creating executable project ${EXE_NAME}"
  )

  # Target to build executable
  add_custom_target(${EXE_NAME}_build ALL
    COMMAND ${SPS_DOTNET_EXECUTABLE} build "${_EXE_DIR}" -c $<CONFIG> ${_BUILD_OPTIONS}
    DEPENDS ${EXE_NAME}_create
    COMMENT "Building ${EXE_NAME}"
  )

  # Target to run executable
  add_custom_target(${EXE_NAME}_run
    COMMAND ${SPS_DOTNET_EXECUTABLE} run --project "${_EXE_DIR}" -c $<CONFIG>
    DEPENDS ${EXE_NAME}_build
    COMMENT "Running ${EXE_NAME}"
  )

  # Register project for solution generation
  string(UUID _PROJECT_GUID NAMESPACE "6BA7B810-9DAD-11D1-80B4-00C04FD430C8"
    NAME "${EXE_NAME}" TYPE SHA1 UPPER)
  set_property(GLOBAL APPEND PROPERTY SPS_DOTNET_PROJECTS
    "${EXE_NAME}|${_EXE_DIR}/${EXE_NAME}.csproj|{${_PROJECT_GUID}}"
  )

  message(STATUS "Configured .NET executable: ${EXE_NAME}")
  message(STATUS "  Targets: ${EXE_NAME}_build, ${EXE_NAME}_run")
endfunction()

#[==[
  sps_generate_dotnet_solution - Generate a Visual Studio solution for .NET projects

  Creates a .sln file at build time that references all .NET projects added via
  sps_add_dotnet_library, sps_add_dotnet_test, and sps_add_dotnet_executable.
  The solution file is placed in ${CMAKE_BINARY_DIR}/$<CONFIG>/.

  This function should be called AFTER all sps_add_dotnet_* calls, typically
  at the end of the top-level CMakeLists.txt.

  Arguments:
    NAME    - Name of the solution file (default: ${PROJECT_NAME}DotNet)
    DEPENDS - Additional target dependencies (optional)

  Creates targets:
    ${NAME}_sln - Generates the .sln file

  Example:
    sps_generate_dotnet_solution(NAME GridSearchDotNet)
#]==]
function(sps_generate_dotnet_solution)
  cmake_parse_arguments(SLN
    ""
    "NAME"
    "DEPENDS"
    ${ARGN}
  )

  if(NOT SLN_NAME)
    set(SLN_NAME "${PROJECT_NAME}DotNet")
  endif()

  # Ensure dotnet was found
  if(NOT SPS_DOTNET_FOUND)
    message(STATUS "sps_generate_dotnet_solution: .NET not found, skipping")
    return()
  endif()

  # Get registered projects
  get_property(_PROJECTS GLOBAL PROPERTY SPS_DOTNET_PROJECTS)
  if(NOT _PROJECTS)
    message(STATUS "sps_generate_dotnet_solution: No .NET projects registered, skipping")
    return()
  endif()

  # Solution output path (config-specific)
  set(_SLN_PATH "${CMAKE_BINARY_DIR}/$<CONFIG>/${SLN_NAME}.sln")

  # Scripts directory
  set(_SCRIPTS_DIR "${CMAKE_BINARY_DIR}/dotnet-scripts")
  file(MAKE_DIRECTORY "${_SCRIPTS_DIR}")

  # Build the project list - pass to script for runtime processing
  # Use @@ as separator since paths may contain semicolons on Windows
  set(_PROJECT_LIST "")
  foreach(_PROJECT ${_PROJECTS})
    string(REPLACE "|" ";" _PROJECT_PARTS "${_PROJECT}")
    list(GET _PROJECT_PARTS 0 _NAME)
    list(GET _PROJECT_PARTS 1 _CSPROJ)
    list(GET _PROJECT_PARTS 2 _GUID)
    list(APPEND _PROJECT_LIST "${_NAME}@@${_CSPROJ}@@${_GUID}")
  endforeach()
  # Join with ;; to preserve list structure
  string(REPLACE ";" ";;" _PROJECT_LIST_STR "${_PROJECT_LIST}")

  # Generate script that creates the .sln file
  set(_GEN_SCRIPT "${_SCRIPTS_DIR}/${SLN_NAME}_gen_sln.cmake")
  file(WRITE "${_GEN_SCRIPT}" [=[
# Generate Visual Studio solution for .NET projects
# Generated by spsDotNet.cmake - do not edit
cmake_minimum_required(VERSION 3.16)

# Inputs: SLN_PATH, BUILD_CONFIG, PROJECT_LIST_STR

# Parse project list (separated by ;;)
string(REPLACE ";;" ";" PROJECT_LIST "${PROJECT_LIST_STR}")

# C# project type GUID
set(TYPE_GUID "FAE04EC0-301F-11D3-BF4B-00C04F79EFBC")

# Build project entries and config entries
set(PROJECT_ENTRIES "")
set(CONFIG_ENTRIES "")

foreach(PROJECT ${PROJECT_LIST})
  # Parse NAME@@CSPROJ@@GUID
  string(REPLACE "@@" ";" PROJECT_PARTS "${PROJECT}")
  list(GET PROJECT_PARTS 0 NAME)
  list(GET PROJECT_PARTS 1 CSPROJ)
  list(GET PROJECT_PARTS 2 GUID)

  # Replace $<CONFIG> with actual config
  string(REPLACE "$<CONFIG>" "${BUILD_CONFIG}" CSPROJ "${CSPROJ}")

  # Build Project line
  string(APPEND PROJECT_ENTRIES "Project(\"{${TYPE_GUID}}\") = \"${NAME}\", \"${CSPROJ}\", \"${GUID}\"\nEndProject\n")

  # Build config entries
  string(APPEND CONFIG_ENTRIES "\t\t${GUID}.Debug|Any CPU.ActiveCfg = Debug|Any CPU\n")
  string(APPEND CONFIG_ENTRIES "\t\t${GUID}.Debug|Any CPU.Build.0 = Debug|Any CPU\n")
  string(APPEND CONFIG_ENTRIES "\t\t${GUID}.Release|Any CPU.ActiveCfg = Release|Any CPU\n")
  string(APPEND CONFIG_ENTRIES "\t\t${GUID}.Release|Any CPU.Build.0 = Release|Any CPU\n")
endforeach()

# Build complete solution content
set(SLN_CONTENT "Microsoft Visual Studio Solution File, Format Version 12.00
# Visual Studio Version 17
VisualStudioVersion = 17.0.0.0
MinimumVisualStudioVersion = 10.0.40219.1
${PROJECT_ENTRIES}Global
\tGlobalSection(SolutionConfigurationPlatforms) = preSolution
\t\tDebug|Any CPU = Debug|Any CPU
\t\tRelease|Any CPU = Release|Any CPU
\tEndGlobalSection
\tGlobalSection(ProjectConfigurationPlatforms) = postSolution
${CONFIG_ENTRIES}\tEndGlobalSection
EndGlobal
")

file(WRITE "${SLN_PATH}" "${SLN_CONTENT}")
message(STATUS "Generated: ${SLN_PATH}")
]=])

  # Collect dependencies - all _build targets for .NET projects
  set(_ALL_DEPS ${SLN_DEPENDS})
  foreach(_PROJECT ${_PROJECTS})
    string(REPLACE "|" ";" _PROJECT_PARTS "${_PROJECT}")
    list(GET _PROJECT_PARTS 0 _NAME)
    # Check if it's a library (has _dotnet_build) or test/exe (has _build)
    if(TARGET ${_NAME}_dotnet_build)
      list(APPEND _ALL_DEPS ${_NAME}_dotnet_build)
    elseif(TARGET ${_NAME}_build)
      list(APPEND _ALL_DEPS ${_NAME}_build)
    endif()
  endforeach()

  # Target to generate the solution file
  add_custom_target(${SLN_NAME}_sln ALL
    COMMAND ${CMAKE_COMMAND}
      -DSLN_PATH=${_SLN_PATH}
      -DBUILD_CONFIG=$<CONFIG>
      "-DPROJECT_LIST_STR=${_PROJECT_LIST_STR}"
      -P "${_GEN_SCRIPT}"
    DEPENDS ${_ALL_DEPS}
    COMMENT "Generating ${SLN_NAME}.sln"
    VERBATIM
  )

  # Utility target to clear NuGet cache (useful when debugging cache issues)
  add_custom_target(NuGetClearCache
    COMMAND ${SPS_DOTNET_EXECUTABLE} nuget locals all --clear
    COMMENT "Clearing NuGet local cache"
    VERBATIM
  )

  message(STATUS "Configured .NET solution: ${SLN_NAME}")
  message(STATUS "  Target: ${SLN_NAME}_sln")
  message(STATUS "  Utility: NuGetClearCache (clears local NuGet cache)")
  message(STATUS "  Output: \${CMAKE_BINARY_DIR}/\$<CONFIG>/${SLN_NAME}.sln")
endfunction()
