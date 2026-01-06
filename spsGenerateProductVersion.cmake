#[==[.rst:
*************************
spsGenerateProductVersion
*************************

.. cmake:command:: sps_generate_product_version

  Generates version resource files for Windows DLLs and executables.
  On non-Windows platforms, this function does nothing but sets empty output.

  sps_generate_product_version(
    <output_variable>
    NAME <product_name>
    [ICON <icon_path>]
    [VERSION_MAJOR <major>]
    [VERSION_MINOR <minor>]
    [VERSION_PATCH <patch>]
    [VERSION_REVISION <revision>]
    [COMPANY_NAME <company>]
    [FILE_DESCRIPTION <description>]
    [COPYRIGHT <copyright>]
  )

  The function sets <output_variable> to the list of generated files
  that should be added to the target's sources.

  Example:
  .. code-block:: cmake
    sps_generate_product_version(VERSION_RC
      NAME GridSearch
      VERSION_MAJOR ${PROJECT_VERSION_MAJOR}
      VERSION_MINOR ${PROJECT_VERSION_MINOR}
      VERSION_PATCH ${PROJECT_VERSION_PATCH}
      VERSION_REVISION ${PROJECT_VERSION_TWEAK}
      COMPANY_NAME "Jens Munk Hansen"
      FILE_DESCRIPTION "High-performance ray-grid intersection library"
      COPYRIGHT "Copyright © 2025 Jens Munk Hansen"
    )
    target_sources(GridSearch PRIVATE ${VERSION_RC})
#]==]

include_guard(GLOBAL)

function(sps_generate_product_version output_var)
  set(options)
  set(oneValueArgs
    NAME
    ICON
    VERSION_MAJOR
    VERSION_MINOR
    VERSION_PATCH
    VERSION_REVISION
    COMPANY_NAME
    FILE_DESCRIPTION
    COPYRIGHT
  )
  set(multiValueArgs)

  cmake_parse_arguments(PRODUCT "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  # Set defaults
  if(NOT DEFINED PRODUCT_VERSION_MAJOR)
    set(PRODUCT_VERSION_MAJOR 1)
  endif()
  if(NOT DEFINED PRODUCT_VERSION_MINOR)
    set(PRODUCT_VERSION_MINOR 0)
  endif()
  if(NOT DEFINED PRODUCT_VERSION_PATCH)
    set(PRODUCT_VERSION_PATCH 0)
  endif()
  if(NOT DEFINED PRODUCT_VERSION_REVISION)
    set(PRODUCT_VERSION_REVISION 0)
  endif()
  if(NOT DEFINED PRODUCT_NAME)
    set(PRODUCT_NAME "${PROJECT_NAME}")
  endif()
  if(NOT DEFINED PRODUCT_COMPANY_NAME)
    set(PRODUCT_COMPANY_NAME "")
  endif()
  if(NOT DEFINED PRODUCT_FILE_DESCRIPTION)
    set(PRODUCT_FILE_DESCRIPTION "${PRODUCT_NAME}")
  endif()
  if(NOT DEFINED PRODUCT_COPYRIGHT)
    set(PRODUCT_COPYRIGHT "")
  endif()

  # Only generate version resources on Windows
  if(WIN32)
    # Create version string
    set(PRODUCT_VERSION_STRING "${PRODUCT_VERSION_MAJOR}.${PRODUCT_VERSION_MINOR}.${PRODUCT_VERSION_PATCH}.${PRODUCT_VERSION_REVISION}")

    # Generate a unique filename based on product name
    string(MAKE_C_IDENTIFIER "${PRODUCT_NAME}" PRODUCT_NAME_ID)
    set(VERSION_RC_FILE "${CMAKE_CURRENT_BINARY_DIR}/${PRODUCT_NAME_ID}_version.rc")

    # Handle icon
    set(ICON_RC_CONTENT "")
    if(PRODUCT_ICON AND EXISTS "${PRODUCT_ICON}")
      set(ICON_RC_CONTENT "IDI_ICON1 ICON \"${PRODUCT_ICON}\"")
    endif()

    # Generate the .rc file content
    # Use code_page(65001) to tell rc.exe the file is UTF-8 (for © symbol)
    file(WRITE "${VERSION_RC_FILE}"
"#pragma code_page(65001)
// Auto-generated version resource file
#include <winver.h>

${ICON_RC_CONTENT}

VS_VERSION_INFO VERSIONINFO
  FILEVERSION ${PRODUCT_VERSION_MAJOR},${PRODUCT_VERSION_MINOR},${PRODUCT_VERSION_PATCH},${PRODUCT_VERSION_REVISION}
  PRODUCTVERSION ${PRODUCT_VERSION_MAJOR},${PRODUCT_VERSION_MINOR},${PRODUCT_VERSION_PATCH},${PRODUCT_VERSION_REVISION}
  FILEFLAGSMASK VS_FFI_FILEFLAGSMASK
#ifdef _DEBUG
  FILEFLAGS VS_FF_DEBUG
#else
  FILEFLAGS 0x0L
#endif
  FILEOS VOS_NT_WINDOWS32
  FILETYPE VFT_DLL
  FILESUBTYPE VFT2_UNKNOWN
BEGIN
  BLOCK \"StringFileInfo\"
  BEGIN
    BLOCK \"040904b0\"
    BEGIN
      VALUE \"CompanyName\", \"${PRODUCT_COMPANY_NAME}\"
      VALUE \"FileDescription\", \"${PRODUCT_FILE_DESCRIPTION}\"
      VALUE \"FileVersion\", \"${PRODUCT_VERSION_STRING}\"
      VALUE \"InternalName\", \"${PRODUCT_NAME}\"
      VALUE \"LegalCopyright\", \"${PRODUCT_COPYRIGHT}\"
      VALUE \"OriginalFilename\", \"${PRODUCT_NAME}\"
      VALUE \"ProductName\", \"${PRODUCT_NAME}\"
      VALUE \"ProductVersion\", \"${PRODUCT_VERSION_STRING}\"
    END
  END
  BLOCK \"VarFileInfo\"
  BEGIN
    VALUE \"Translation\", 0x409, 1200
  END
END
")

    set(${output_var} "${VERSION_RC_FILE}" PARENT_SCOPE)
  else()
    # On non-Windows platforms, return empty list
    set(${output_var} "" PARENT_SCOPE)
  endif()
endfunction()
