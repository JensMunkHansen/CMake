option(SPS_USE_CUDA "Enable CUDA support" OFF)

if(SPS_USE_CUDA)
  message(STATUS "CUDA language enabled")
  # CUDA configuration
  # Auto-detect CUDA toolkit root from nvcc location, fallback to /usr/local/cuda
  find_program(NVCC_EXECUTABLE nvcc)
  if(NVCC_EXECUTABLE)
    get_filename_component(_nvcc_dir "${NVCC_EXECUTABLE}" DIRECTORY)
    get_filename_component(_cuda_root "${_nvcc_dir}" DIRECTORY)
    set(CUDA_TOOLKIT_ROOT "${_cuda_root}" CACHE PATH "CUDA toolkit root")
  else()
    set(CUDA_TOOLKIT_ROOT "/usr/local/cuda" CACHE PATH "CUDA toolkit root")
  endif()
  set(CMAKE_CUDA_ARCHITECTURES "86" CACHE STRING "CUDA architectures" FORCE)
endif()
