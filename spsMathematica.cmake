#[==[.rst:
**************
spsMathematica
**************

Module for finding and configuring Wolfram Mathematica.
Wraps the FindMathematica module with platform-specific installation detection.

Usage::

    include(spsMathematica)

This will:

- Check common installation paths for Mathematica on each platform
- Only call find_package(Mathematica) if installation is likely present
- Set MATHEMATICA_FOUND to TRUE or FALSE

After including::

    if(MATHEMATICA_FOUND)
      # Mathematica is available
    endif()

#]==]

set(MATHEMATICA_FOUND FALSE)
set(_sps_mathematica_search ON)

# Platform-specific installation detection
if(WIN32)
  # Windows: Check Program Files locations
  set(_sps_mathematica_hints
    "C:/Program Files/Wolfram Research"
    "$ENV{ProgramFiles}/Wolfram Research"
    "C:/Program Files (x86)/Wolfram Research"
    "$ENV{ProgramFiles(x86)}/Wolfram Research")

  set(_sps_mathematica_search OFF)
  foreach(_hint ${_sps_mathematica_hints})
    if(EXISTS "${_hint}")
      set(_sps_mathematica_search ON)
      message(STATUS "Found potential Mathematica installation at: ${_hint}")
      break()
    endif()
  endforeach()

elseif(APPLE)
  # macOS: Check /Applications
  set(_sps_mathematica_hints
    "/Applications/Mathematica.app"
    "/Applications/Wolfram Mathematica.app"
    "$ENV{HOME}/Applications/Mathematica.app")

  set(_sps_mathematica_search OFF)
  foreach(_hint ${_sps_mathematica_hints})
    if(EXISTS "${_hint}")
      set(_sps_mathematica_search ON)
      message(STATUS "Found potential Mathematica installation at: ${_hint}")
      break()
    endif()
  endforeach()

else()
  # Linux: Check common install locations
  set(_sps_mathematica_hints
    "/usr/local/Wolfram"
    "/opt/Wolfram"
    "/opt/mathematica"
    "$ENV{HOME}/Wolfram"
    "$ENV{HOME}/.Mathematica")

  set(_sps_mathematica_search OFF)
  foreach(_hint ${_sps_mathematica_hints})
    if(EXISTS "${_hint}")
      set(_sps_mathematica_search ON)
      message(STATUS "Found potential Mathematica installation at: ${_hint}")
      break()
    endif()
  endforeach()
endif()

# Try to find Mathematica if installation detected
if(_sps_mathematica_search)
  # The FindMathematica module can have issues on some platforms
  # Use QUIET to suppress errors
  find_package(Mathematica QUIET)

  if(MATHEMATICA_FOUND)
    message(STATUS "Mathematica found:")
    if(DEFINED Mathematica_VERSION)
      message(STATUS "   Version: ${Mathematica_VERSION}")
    endif()
    if(DEFINED Mathematica_ROOT_DIR)
      message(STATUS "   Root: ${Mathematica_ROOT_DIR}")
    endif()
  else()
    message(STATUS "Mathematica installation detected but FindMathematica failed")
  endif()
else()
  message(STATUS "Mathematica not detected (install locations not found)")
endif()

# Cleanup internal variables
unset(_sps_mathematica_search)
unset(_sps_mathematica_hints)
