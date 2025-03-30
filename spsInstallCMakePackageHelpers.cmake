function (_sps_package_append_variables)
  set(_sps_package_variables)
  foreach (var IN LISTS ARGN)
    if (NOT DEFINED "${var}")
      continue ()
    endif ()

    get_property(type_is_set CACHE "${var}"
      PROPERTY TYPE SET)
    if (type_is_set)
      get_property(type CACHE "${var}"
        PROPERTY TYPE)
    else ()
      set(type UNINITIALIZED)
    endif ()

    string(APPEND _sps_package_variables
      "if (NOT DEFINED \"${var}\" OR NOT ${var})
  set(\"${var}\" \"${${var}}\" CACHE ${type} \"Third-party helper setting from \${CMAKE_FIND_PACKAGE_NAME}\")
endif ()
")
  endforeach ()

  set(sps_find_package_code
    "${sps_find_package_code}${_sps_package_variables}"
    PARENT_SCOPE)
endfunction ()

get_property(_sps_packages GLOBAL
  PROPERTY _sps_module_find_packages_SPS)
if (_sps_packages)
  list(REMOVE_DUPLICATES _sps_packages)
endif ()

# Per-package variable forwarding goes here.
set(Python3_find_package_vars
  Python3_EXECUTABLE
  Python3_INCLUDE_DIR
  Python3_LIBRARY)

set(sps_find_package_code)
foreach (_sps_package IN LISTS _sps_packages)
  _sps_package_append_variables(
    # Standard CMake `find_package` mechanisms.
    "${_sps_package}_DIR"
    "${_sps_package}_ROOT"

    # Per-package custom variables.
    ${${_sps_package}_find_package_vars})
endforeach ()

file(GENERATE
  OUTPUT  "${sps_cmake_build_dir}/sps-find-package-helpers.cmake"
  CONTENT "${sps_find_package_code}")
