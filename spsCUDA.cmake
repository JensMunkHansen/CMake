option(SPS_USE_CUDA "Enable CUDA support" OFF)

if(SPS_USE_CUDA)
  message(STATUS "CUDA support enabled")

  # Auto-detect CUDA toolkit root from nvcc location
  find_program(NVCC_EXECUTABLE nvcc)
  if(NVCC_EXECUTABLE)
    get_filename_component(_nvcc_dir "${NVCC_EXECUTABLE}" DIRECTORY)
    get_filename_component(_cuda_root "${_nvcc_dir}" DIRECTORY)
    set(CUDA_TOOLKIT_ROOT "${_cuda_root}" CACHE PATH "CUDA toolkit root")
    # Set CMAKE_CUDA_COMPILER to the actual found path (includes .exe on Windows)
    set(CMAKE_CUDA_COMPILER "${NVCC_EXECUTABLE}" CACHE FILEPATH "CUDA compiler")
  else()
    # Fallback paths
    if(WIN32)
      file(GLOB _cuda_dirs "C:/Program Files/NVIDIA GPU Computing Toolkit/CUDA/v*")
      if(_cuda_dirs)
        list(SORT _cuda_dirs ORDER DESCENDING)
        list(GET _cuda_dirs 0 _cuda_root)
        set(CUDA_TOOLKIT_ROOT "${_cuda_root}" CACHE PATH "CUDA toolkit root")
        set(CMAKE_CUDA_COMPILER "${_cuda_root}/bin/nvcc.exe" CACHE FILEPATH "CUDA compiler")
      endif()
    else()
      set(CUDA_TOOLKIT_ROOT "/usr/local/cuda" CACHE PATH "CUDA toolkit root")
      set(CMAKE_CUDA_COMPILER "/usr/local/cuda/bin/nvcc" CACHE FILEPATH "CUDA compiler")
    endif()
  endif()

  message(STATUS "  CUDA toolkit: ${CUDA_TOOLKIT_ROOT}")
  message(STATUS "  CUDA compiler: ${CMAKE_CUDA_COMPILER}")

  # Auto-detect CUDA architecture if not specified
  # - "native": detect GPU at configure time (CMake 3.24+, requires GPU present)
  # - "all-major": build for all major architectures (larger binary, portable)
  # - Specific arch like "86" or "89" for targeted builds
  if(NOT DEFINED CMAKE_CUDA_ARCHITECTURES OR CMAKE_CUDA_ARCHITECTURES STREQUAL "")
    if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.24")
      # Try native detection first; fall back to all-major if no GPU present
      set(CMAKE_CUDA_ARCHITECTURES "native" CACHE STRING "CUDA architectures")
    else()
      # Older CMake: use a reasonable default
      set(CMAKE_CUDA_ARCHITECTURES "70;75;80;86;89;90" CACHE STRING "CUDA architectures")
    endif()
  endif()
  message(STATUS "  CUDA architectures: ${CMAKE_CUDA_ARCHITECTURES}")
endif()
