# spsFFTW.cmake - Modern FFTW3 find module with imported targets
#
# This module finds the FFTW3 library and creates imported targets.
#
# Usage:
#   find_package(FFTW REQUIRED COMPONENTS FLOAT_LIB DOUBLE_LIB)
#   target_link_libraries(mytarget FFTW::Float FFTW::Double)
#
# Components:
#   FLOAT_LIB       - Single precision (fftw3f)
#   DOUBLE_LIB      - Double precision (fftw3)
#   LONG_DOUBLE_LIB - Long double precision (fftw3l)
#
# Imported Targets:
#   FFTW::Float      - Single precision library
#   FFTW::Double     - Double precision library
#   FFTW::LongDouble - Long double precision library
#
# Variables:
#   FFTW_FOUND       - True if FFTW found
#   FFTW_INCLUDES    - Include directories
#   FFTW_LIBRARIES   - All requested libraries

include(FindPackageHandleStandardArgs)

# Find the include directory
find_path(FFTW_INCLUDE_DIR
  NAMES fftw3.h
  PATHS
    /usr/include
    /usr/local/include
    /opt/local/include
    "C:/Program Files/fftw-3.3.5"
    "$ENV{FFTW_ROOT}/include"
)

# Platform-specific library names
if(WIN32)
  set(_FFTW_FLOAT_NAMES libfftw3f-3 fftw3f-3 libfftw3f fftw3f)
  set(_FFTW_DOUBLE_NAMES libfftw3-3 fftw3-3 libfftw3 fftw3)
  set(_FFTW_LONG_DOUBLE_NAMES libfftw3l-3 fftw3l-3 libfftw3l fftw3l)
else()
  set(_FFTW_FLOAT_NAMES fftw3f)
  set(_FFTW_DOUBLE_NAMES fftw3)
  set(_FFTW_LONG_DOUBLE_NAMES fftw3l)
endif()

# Find individual libraries
find_library(FFTW_FLOAT_LIB
  NAMES ${_FFTW_FLOAT_NAMES}
  PATHS
    /usr/lib
    /usr/local/lib
    /opt/local/lib
    "C:/Program Files/fftw-3.3.5"
    "$ENV{FFTW_ROOT}/lib"
  PATH_SUFFIXES i386 x86_64
)

find_library(FFTW_DOUBLE_LIB
  NAMES ${_FFTW_DOUBLE_NAMES}
  PATHS
    /usr/lib
    /usr/local/lib
    /opt/local/lib
    "C:/Program Files/fftw-3.3.5"
    "$ENV{FFTW_ROOT}/lib"
  PATH_SUFFIXES i386 x86_64
)

find_library(FFTW_LONG_DOUBLE_LIB
  NAMES ${_FFTW_LONG_DOUBLE_NAMES}
  PATHS
    /usr/lib
    /usr/local/lib
    /opt/local/lib
    "C:/Program Files/fftw-3.3.5"
    "$ENV{FFTW_ROOT}/lib"
  PATH_SUFFIXES i386 x86_64
)

# Handle components
set(FFTW_LIBRARIES "")
set(_FFTW_REQUIRED_VARS FFTW_INCLUDE_DIR)

foreach(_comp ${FFTW_FIND_COMPONENTS})
  if(_comp STREQUAL "FLOAT_LIB")
    list(APPEND _FFTW_REQUIRED_VARS FFTW_FLOAT_LIB)
    if(FFTW_FLOAT_LIB)
      list(APPEND FFTW_LIBRARIES ${FFTW_FLOAT_LIB})
    endif()
  elseif(_comp STREQUAL "DOUBLE_LIB")
    list(APPEND _FFTW_REQUIRED_VARS FFTW_DOUBLE_LIB)
    if(FFTW_DOUBLE_LIB)
      list(APPEND FFTW_LIBRARIES ${FFTW_DOUBLE_LIB})
    endif()
  elseif(_comp STREQUAL "LONG_DOUBLE_LIB")
    list(APPEND _FFTW_REQUIRED_VARS FFTW_LONG_DOUBLE_LIB)
    if(FFTW_LONG_DOUBLE_LIB)
      list(APPEND FFTW_LIBRARIES ${FFTW_LONG_DOUBLE_LIB})
    endif()
  endif()
endforeach()

# If no components specified, find all available
if(NOT FFTW_FIND_COMPONENTS)
  if(FFTW_FLOAT_LIB)
    list(APPEND FFTW_LIBRARIES ${FFTW_FLOAT_LIB})
  endif()
  if(FFTW_DOUBLE_LIB)
    list(APPEND FFTW_LIBRARIES ${FFTW_DOUBLE_LIB})
  endif()
  if(FFTW_LONG_DOUBLE_LIB)
    list(APPEND FFTW_LIBRARIES ${FFTW_LONG_DOUBLE_LIB})
  endif()
  # Require at least one library
  if(FFTW_LIBRARIES)
    set(_FFTW_REQUIRED_VARS FFTW_INCLUDE_DIR)
  else()
    set(_FFTW_REQUIRED_VARS FFTW_INCLUDE_DIR FFTW_DOUBLE_LIB)
  endif()
endif()

# Standard find_package handling
find_package_handle_standard_args(FFTW
  REQUIRED_VARS ${_FFTW_REQUIRED_VARS}
  HANDLE_COMPONENTS
)

# Set legacy variable
set(FFTW_INCLUDES ${FFTW_INCLUDE_DIR})

# Create imported targets
if(FFTW_FOUND)
  if(FFTW_FLOAT_LIB AND NOT TARGET FFTW::Float)
    add_library(FFTW::Float UNKNOWN IMPORTED)
    set_target_properties(FFTW::Float PROPERTIES
      IMPORTED_LOCATION "${FFTW_FLOAT_LIB}"
      INTERFACE_INCLUDE_DIRECTORIES "${FFTW_INCLUDE_DIR}"
    )
  endif()

  if(FFTW_DOUBLE_LIB AND NOT TARGET FFTW::Double)
    add_library(FFTW::Double UNKNOWN IMPORTED)
    set_target_properties(FFTW::Double PROPERTIES
      IMPORTED_LOCATION "${FFTW_DOUBLE_LIB}"
      INTERFACE_INCLUDE_DIRECTORIES "${FFTW_INCLUDE_DIR}"
    )
  endif()

  if(FFTW_LONG_DOUBLE_LIB AND NOT TARGET FFTW::LongDouble)
    add_library(FFTW::LongDouble UNKNOWN IMPORTED)
    set_target_properties(FFTW::LongDouble PROPERTIES
      IMPORTED_LOCATION "${FFTW_LONG_DOUBLE_LIB}"
      INTERFACE_INCLUDE_DIRECTORIES "${FFTW_INCLUDE_DIR}"
    )
  endif()
endif()

mark_as_advanced(
  FFTW_INCLUDE_DIR
  FFTW_FLOAT_LIB
  FFTW_DOUBLE_LIB
  FFTW_LONG_DOUBLE_LIB
)
