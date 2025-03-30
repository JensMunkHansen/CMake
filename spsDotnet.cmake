#[==[.rst:
*********
spsDotnet
*********
#
#]==]
#

# Targeted Framework Moniker
# see: https://docs.microsoft.com/en-us/dotnet/standard/frameworks
# see: https://learn.microsoft.com/en-us/dotnet/standard/net-standard
set(DOTNET_LANG "8.0" CACHE STRING "Specify the C# language version (default \"8.0\")")
message(STATUS ".Net C# language version: ${DOTNET_LANG}")

option(USE_DOTNET_46 "Use .Net Framework 4.6 support" OFF)
message(STATUS ".Net: Use .Net Framework 4.6 support: ${USE_DOTNET_46}")
option(USE_DOTNET_461 "Use .Net Framework 4.6.1 support" OFF)
message(STATUS ".Net: Use .Net Framework 4.6.1 support: ${USE_DOTNET_461}")
option(USE_DOTNET_462 "Use .Net Framework 4.6.2 support" OFF)
message(STATUS ".Net: Use .Net Framework 4.6.2 support: ${USE_DOTNET_462}")

option(USE_DOTNET_48 "Use .Net Framework 4.8 support" OFF)
message(STATUS ".Net: Use .Net Framework 4.8 support: ${USE_DOTNET_48}")

option(USE_DOTNET_STD_20 "Use .Net Standard 2.0 support" OFF)
message(STATUS ".Net: Use .Net Framework 2.0 support: ${USE_DOTNET_STD_20}")

option(USE_DOTNET_STD_21 "Use .Net Standard 2.1 support" OFF)
message(STATUS ".Net: Use .Net Framework 2.1 support: ${USE_DOTNET_STD_21}")

# .Net Core 3.1 LTS is not available for osx arm64
if(APPLE AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)")
  set(USE_DOTNET_CORE_31 OFF)
else()
  option(USE_DOTNET_CORE_31 "Use .Net Core 3.1 LTS support" OFF)
endif()
message(STATUS ".Net: Use .Net Core 3.1 LTS support: ${USE_DOTNET_CORE_31}")

# Default is .NET 6
option(USE_DOTNET_6 "Use .Net 6 LTS support" OFF)
message(STATUS ".Net: Use .Net 6 LTS support: ${USE_DOTNET_6}")

option(USE_DOTNET_7 "Use .Net 7.0 support" OFF)
message(STATUS ".Net: Use .Net 7.0 support: ${USE_DOTNET_7}")

option(USE_DOTNET_8 "Use .Net 8.0 LTS support" ON)
message(STATUS ".Net: Use .Net 8.0 TS support: ${USE_DOTNET_8}")

# Find dotnet cli
find_program(DOTNET_EXECUTABLE NAMES dotnet)
if(NOT DOTNET_EXECUTABLE)
  message(FATAL_ERROR "Check for dotnet Program: not found")
else()
  message(STATUS "Found dotnet Program: ${DOTNET_EXECUTABLE}")
endif()


function(spsSetupDotnetProject)
  cmake_parse_arguments(DOTNET
    ""
    "COMPANY_NAME;PROJECT_NAME"
    ""
    ${ARGN}
  )

  if(NOT DOTNET_COMPANY_NAME OR NOT DOTNET_PROJECT_NAME)
    message(FATAL_ERROR "COMPANY_NAME and PROJECT_NAME must be provided.")
  endif()

  set(DOTNET_PROJECT "${DOTNET_COMPANY_NAME}.${DOTNET_PROJECT_NAME}" PARENT_SCOPE)
  message(STATUS ".Net project: ${DOTNET_PROJECT}")

  set(DOTNET_PROJECT_DIR "${PROJECT_BINARY_DIR}/dotnet/${DOTNET_PROJECT}" PARENT_SCOPE)
  message(STATUS ".Net project build path: ${DOTNET_PROJECT_DIR}")

  if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)")
    set(DOTNET_PLATFORM arm64)
  else()
    set(DOTNET_PLATFORM x64)
  endif()

  if(APPLE)
    set(DOTNET_RID "osx-${DOTNET_PLATFORM}")
  elseif(UNIX)
    set(DOTNET_RID "linux-${DOTNET_PLATFORM}")
  elseif(WIN32)
    set(DOTNET_RID "win-${DOTNET_PLATFORM}")
  else()
    message(FATAL_ERROR "Unsupported system!")
  endif()

  set(DOTNET_RID "${DOTNET_RID}" PARENT_SCOPE)
  message(STATUS ".Net RID: ${DOTNET_RID}")

  set(DOTNET_PACKAGES_DIR "${PROJECT_BINARY_DIR}/dotnet/packages" PARENT_SCOPE)

  # Targeted Framework Moniker
  # see: https://docs.microsoft.com/en-us/dotnet/standard/frameworks
  # see: https://learn.microsoft.com/en-us/dotnet/standard/net-standard
  if(USE_DOTNET_46)
    list(APPEND TFM "net46")
  endif()
  if(USE_DOTNET_461)
    list(APPEND TFM "net461")
  endif()
  if(USE_DOTNET_462)
    list(APPEND TFM "net462")
  endif()
  if(USE_DOTNET_48)
    list(APPEND TFM "net48")
  endif()
  if(USE_DOTNET_STD_20)
    list(APPEND TFM "netstandard2.0")
  endif()
  if(USE_DOTNET_STD_21)
    list(APPEND TFM "netstandard2.1")
  endif()
  if(USE_DOTNET_CORE_31)
    list(APPEND TFM "netcoreapp3.1")
  endif()
  if(USE_DOTNET_6)
    list(APPEND TFM "net6.0")
  endif()
  if(USE_DOTNET_7)
    list(APPEND TFM "net7.0")
  endif()
  if(USE_DOTNET_8)
    list(APPEND TFM "net8.0")
  endif()


  list(LENGTH TFM TFM_LENGTH)
  if(TFM_LENGTH EQUAL "0")
    message(FATAL_ERROR "No .Net SDK selected !")
  endif()

  string(JOIN ";" DOTNET_TFM ${TFM})
  message(STATUS ".Net TFM: ${DOTNET_TFM}")
  if(TFM_LENGTH GREATER "1")
    string(CONCAT DOTNET_TFM "<TargetFrameworks>" "${DOTNET_TFM}" "</TargetFrameworks>")
  else()
    string(CONCAT DOTNET_TFM "<TargetFramework>" "${DOTNET_TFM}" "</TargetFramework>")
  endif()
  set(DOTNET_TFM "${DOTNET_TFM}" PARENT_SCOPE)
endfunction()



