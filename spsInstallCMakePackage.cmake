if (NOT (DEFINED sps_cmake_dir AND
         DEFINED sps_cmake_build_dir AND
         DEFINED sps_cmake_destination AND
         DEFINED sps_modules))
  message(FATAL_ERROR
    "vtkSpsInstallCMakePackage is missing input variables.")
endif ()

set(sps_all_components)
foreach (sps_module IN LISTS sps_modules)
  list(APPEND sps_all_components
    "${sps_component}")
endforeach ()

# message("SPS_LIBRARIES: ${sps_all_components}")

# Creates the variable vtk_module_import_prefix variable
_vtk_module_write_import_prefix("${sps_cmake_build_dir}/sps-prefix.cmake" "${sps_cmake_destination}")

set(sps_python_version "")
if (SPS_WRAP_PYTHON)
  set(sps_python_version "${VTK_PYTHON_VERSION}")
endif()
# message("SPS_PYTHON_VERSION: ${sps_python_version}")

configure_file(
  "${sps_cmake_dir}/sps-config.cmake.in"
  "${sps_cmake_build_dir}/sps-config.cmake"
  @ONLY)

configure_file(
  "${sps_cmake_dir}/sps-config.cmake.in"
  "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/sps-config.cmake"
  @ONLY)

include(CMakePackageConfigHelpers)
write_basic_package_version_file("${sps_cmake_build_dir}/sps-config-version.cmake"
  VERSION "${SPS_MAJOR_VERSION}.${SPS_MINOR_VERSION}.${SPS_PATH_VERSION}"
  COMPATIBILITY AnyNewerVersion)

# For convenience, a package is written to the top of the build tree. At some
# point, this should probably be deprecated and warn when it is used.
file(GENERATE
  OUTPUT  "${CMAKE_BINARY_DIR}/sps-config.cmake"
  CONTENT "include(\"${sps_cmake_build_dir}/sps-config.cmake\")\n")
configure_file(
  "${sps_cmake_build_dir}/sps-config-version.cmake"
  "${CMAKE_BINARY_DIR}/sps-config-version.cmake"
  COPYONLY)

# Any packages needed by this
set(sps_cmake_module_files
#   FindITK.cmake # Consider writing and adding this
)

# Patch files (if any)
set(sps_cmake_patch_files
)

set(sps_cmake_files_to_install)
foreach (sps_cmake_module_file IN LISTS sps_cmake_module_files sps_cmake_patch_files)
  configure_file(
    "${sps_cmake_dir}/${sps_cmake_module_file}"
    "${sps_cmake_build_dir}/${sps_cmake_module_file}"
    COPYONLY)
  list(APPEND sps_cmake_files_to_install
    "${sps_cmake_module_file}")
endforeach ()

# message("sps_cmake_files_to_install: ${sps_cmake_files_to_install}")

include(spsInstallCMakePackageHelpers)

# message("SPS_RELOCATABLE_INSTALL: ${SPS_RELOCATABLE_INSTALL}")

if (NOT SPS_RELOCATABLE_INSTALL)
  list(APPEND sps_cmake_files_to_install
    "${sps_cmake_build_dir}/sps-find-package-helpers.cmake")
endif ()

foreach (sps_cmake_file IN LISTS sps_cmake_files_to_install)
  if (IS_ABSOLUTE "${sps_cmake_file}")
    file(RELATIVE_PATH sps_cmake_subdir_root "${sps_cmake_build_dir}" "${sps_cmake_file}")
    get_filename_component(sps_cmake_subdir "${sps_cmake_subdir_root}" DIRECTORY)
    set(sps_cmake_original_file "${sps_cmake_file}")
  else ()
    get_filename_component(sps_cmake_subdir "${sps_cmake_file}" DIRECTORY)
    set(sps_cmake_original_file "${sps_cmake_dir}/${sps_cmake_file}")
  endif ()
  install(
    FILES       "${sps_cmake_original_file}"
    DESTINATION "${sps_cmake_destination}/${sps_cmake_subdir}"
    COMPONENT   "development")
endforeach ()

install(
  FILES       "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/sps-config.cmake"
              "${sps_cmake_build_dir}/sps-config-version.cmake"
              "${sps_cmake_build_dir}/sps-prefix.cmake"
  DESTINATION "${sps_cmake_destination}"
  COMPONENT   "development")

vtk_module_export_find_packages(
  CMAKE_DESTINATION "${sps_cmake_destination}"
  FILE_NAME         "sps-vtk-module-find-packages.cmake"
  MODULES           ${sps_modules})
