# spsRenderDoc.cmake — Locate the RenderDoc in-application API header.
#
# The RenderDoc API is consumed entirely through a single MIT-licensed header
# (renderdoc_app.h). At runtime the application loads librenderdoc.so /
# renderdoc.dll via dlsym/GetProcAddress; nothing needs to link against
# RenderDoc, so this module only resolves an include path.
#
# Hints (in priority order):
#   - RENDERDOC_PATH  — CMake or environment variable pointing to a RenderDoc
#                       install root (containing include/renderdoc_app.h).
#   - Common Windows install locations (Program Files).
#   - Common Linux locations (/usr/include, /usr/local/include).
#
# Provides:
#   VKWAVE_HAVE_RENDERDOC      — TRUE when the header was found.
#   vkwave::renderdoc_headers  — INTERFACE target exposing the include path.
#                                Only defined when the header is found.

if(NOT DEFINED RENDERDOC_PATH AND DEFINED ENV{RENDERDOC_PATH})
  set(RENDERDOC_PATH "$ENV{RENDERDOC_PATH}")
endif()

set(_renderdoc_hints "")
if(RENDERDOC_PATH)
  list(APPEND _renderdoc_hints "${RENDERDOC_PATH}/include" "${RENDERDOC_PATH}")
endif()
if(WIN32)
  list(APPEND _renderdoc_hints
    "C:/Program Files/RenderDoc"
    "C:/Program Files/RenderDoc/include"
    "C:/Program Files (x86)/RenderDoc"
    "C:/Program Files (x86)/RenderDoc/include")
endif()

# Linux: the qrenderdoc tarball typically extracts to /opt/renderdoc_<version>
# (e.g. /opt/renderdoc_1.42). Glob for any such directory so the header is
# found out-of-the-box without requiring RENDERDOC_PATH.
if(UNIX AND NOT APPLE)
  file(GLOB _renderdoc_opt_dirs "/opt/renderdoc_*" "/opt/renderdoc")
  foreach(_d IN LISTS _renderdoc_opt_dirs)
    list(APPEND _renderdoc_hints "${_d}/include" "${_d}")
  endforeach()
  unset(_renderdoc_opt_dirs)
endif()

find_path(RENDERDOC_INCLUDE_DIR
  NAMES renderdoc_app.h
  HINTS ${_renderdoc_hints}
  PATHS /usr/include /usr/local/include
  DOC "Directory containing renderdoc_app.h (the RenderDoc in-application API header)")

if(RENDERDOC_INCLUDE_DIR)
  set(VKWAVE_HAVE_RENDERDOC TRUE)
  add_library(vkwave_renderdoc_headers INTERFACE)
  add_library(vkwave::renderdoc_headers ALIAS vkwave_renderdoc_headers)
  target_include_directories(vkwave_renderdoc_headers INTERFACE "${RENDERDOC_INCLUDE_DIR}")
  message(STATUS "RenderDoc: found header at ${RENDERDOC_INCLUDE_DIR}/renderdoc_app.h")
else()
  set(VKWAVE_HAVE_RENDERDOC FALSE)
  message(STATUS "RenderDoc: header not found — programmatic captures disabled. "
                 "Set RENDERDOC_PATH to enable.")
endif()

unset(_renderdoc_hints)
