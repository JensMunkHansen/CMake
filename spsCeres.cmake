#[==[.rst:
*********
spsCeres
*********
Detects Ceres Solver capabilities and creates configuration for available features.

Usage::

  include(spsCeres)
  sps_detect_ceres_features()

Sets the following variables:
  - SPS_CERES_HAS_SUITESPARSE  - SuiteSparse support available
  - SPS_CERES_HAS_CUDA         - CUDA support available
  - SPS_CERES_HAS_LAPACK       - LAPACK support available

Also sets cache variables for use in Config.h.in:
  - ICP_HAS_SPARSE_CHOLESKY
  - ICP_HAS_CUDA_SOLVER

#]==]

if(DEFINED _SPS_CERES_INCLUDED)
  return()
endif()
set(_SPS_CERES_INCLUDED TRUE)

#[==[
sps_detect_ceres_features()

Detects what features Ceres was built with by checking its config.
#]==]
function(sps_detect_ceres_features)
  if(NOT TARGET Ceres::ceres)
    find_package(Ceres REQUIRED)
  endif()

  message(STATUS "=== Ceres Feature Detection ===")

  # Get Ceres include directory to find its config
  get_target_property(_ceres_includes Ceres::ceres INTERFACE_INCLUDE_DIRECTORIES)

  # Check for SuiteSparse by looking for the compile definition or config
  set(_has_suitesparse FALSE)
  set(_has_cuda FALSE)
  set(_has_lapack FALSE)

  # Method 1: Check Ceres compile definitions
  get_target_property(_ceres_defs Ceres::ceres INTERFACE_COMPILE_DEFINITIONS)
  if(_ceres_defs)
    if("CERES_USE_SUITESPARSE" IN_LIST _ceres_defs OR
       "CERES_NO_SUITESPARSE" IN_LIST _ceres_defs STREQUAL FALSE)
      set(_has_suitesparse TRUE)
    endif()
  endif()

  # Method 2: Try to find SuiteSparse directly (if Ceres was built with it, it should be findable)
  if(NOT _has_suitesparse)
    find_package(SuiteSparse QUIET)
    if(SuiteSparse_FOUND OR TARGET SuiteSparse::CHOLMOD)
      set(_has_suitesparse TRUE)
    endif()
  endif()

  # Method 3: Check for CHOLMOD specifically
  if(NOT _has_suitesparse)
    find_library(_cholmod_lib NAMES cholmod PATHS
      ${CMAKE_PREFIX_PATH}/lib
      /usr/lib
      /usr/local/lib
    )
    if(_cholmod_lib)
      set(_has_suitesparse TRUE)
    endif()
  endif()

  # Check for CUDA support
  if(TARGET Ceres::ceres)
    get_target_property(_ceres_libs Ceres::ceres INTERFACE_LINK_LIBRARIES)
    if(_ceres_libs)
      string(FIND "${_ceres_libs}" "cuda" _cuda_pos)
      if(NOT _cuda_pos EQUAL -1)
        set(_has_cuda TRUE)
      endif()
    endif()
  endif()

  # Also check if CUDA toolkit is available
  if(NOT _has_cuda)
    find_package(CUDAToolkit QUIET)
    if(CUDAToolkit_FOUND)
      set(_has_cuda TRUE)
    endif()
  endif()

  # Check for LAPACK
  find_package(LAPACK QUIET)
  if(LAPACK_FOUND)
    set(_has_lapack TRUE)
  endif()

  # Report findings
  if(_has_suitesparse)
    message(STATUS "  SuiteSparse: FOUND")
  else()
    message(STATUS "  SuiteSparse: NOT FOUND (SPARSE_NORMAL_CHOLESKY unavailable)")
  endif()

  if(_has_cuda)
    message(STATUS "  CUDA: FOUND")
  else()
    message(STATUS "  CUDA: NOT FOUND (GPU solvers unavailable)")
  endif()

  if(_has_lapack)
    message(STATUS "  LAPACK: FOUND")
  else()
    message(STATUS "  LAPACK: NOT FOUND")
  endif()

  # Set parent scope variables
  set(SPS_CERES_HAS_SUITESPARSE ${_has_suitesparse} PARENT_SCOPE)
  set(SPS_CERES_HAS_CUDA ${_has_cuda} PARENT_SCOPE)
  set(SPS_CERES_HAS_LAPACK ${_has_lapack} PARENT_SCOPE)

  # Set cache variables for Config.h generation
  set(ICP_HAS_SPARSE_CHOLESKY ${_has_suitesparse} CACHE BOOL "SuiteSparse available for sparse Cholesky" FORCE)
  set(ICP_HAS_CUDA_SOLVER ${_has_cuda} CACHE BOOL "CUDA available for GPU solvers" FORCE)
  set(ICP_HAS_LAPACK ${_has_lapack} CACHE BOOL "LAPACK available" FORCE)

endfunction()

#[==[
sps_get_available_linear_solvers(<output_var>)

Returns a list of available linear solver types based on detected features.
#]==]
function(sps_get_available_linear_solvers output_var)
  set(_solvers
    DenseQR
    DenseSchur
  )

  if(SPS_CERES_HAS_SUITESPARSE)
    list(APPEND _solvers SparseSchur SparseNormalCholesky)
  endif()

  if(SPS_CERES_HAS_CUDA)
    list(APPEND _solvers CudaDenseCholesky)
    if(SPS_CERES_HAS_SUITESPARSE)
      list(APPEND _solvers CudaSparseCholesky)
    endif()
  endif()

  set(${output_var} ${_solvers} PARENT_SCOPE)
endfunction()
