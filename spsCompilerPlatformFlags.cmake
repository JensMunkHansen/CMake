# Clear flags for RelWithDebInfo
set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "")

if (TARGET build)
  if (MSVC)
    set(IS_MSVC_OR_CLANG_CL FALSE)
    if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
      set(IS_MSVC_OR_CLANG_CL TRUE)
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND MSVC)
      set(IS_MSVC_OR_CLANG_CL TRUE)
    endif()
  endif()

  # MSVC or Microsofts Clang version
  if(IS_MSVC_OR_CLANG_CL)
    target_compile_options(build INTERFACE
      $<$<CONFIG:Release>:/O2 /GL /fp:fast /Qpar /arch:AVX2>
      $<$<CONFIG:Debug>:/Od /Zi /arch:AVX2>
      $<$<CONFIG:Asan>:/Od /GL /arch:AVX2>
      $<$<CONFIG:RelWithDebInfo>:/O1 /Zi /arch:AVX2>
      $<$<CXX_COMPILER_ID:MSVC>:/Zc:__cplusplus>
    )

    # Linker flags needed by Microsoft
    set(CMAKE_STATIC_LINKER_FLAGS "${CMAKE_STATIC_LINKER_FLAGS} /LTCG")    
  else()
    # Determine architecture flags based on SPS_DISABLE_AVX512 option
    if(SPS_DISABLE_AVX512)
      set(_ARCH_FLAGS "-march=skylake;-mtune=native")  # Skylake has AVX2 but no AVX-512
      set(_ARCH_FLAGS_CLANG "-march=skylake")
      message(STATUS "AVX-512 disabled - using Skylake architecture (AVX2 max)")
    else()
      set(_ARCH_FLAGS "-march=native;-mtune=native")
      set(_ARCH_FLAGS_CLANG "-march=native")
    endif()
    
    # Linux build
    target_compile_options(build
      INTERFACE
      # GNU flags
      $<$<AND:$<CXX_COMPILER_ID:GNU>,$<CONFIG:Release>>:-O3 ${_ARCH_FLAGS} -ffast-math>
      $<$<AND:$<CXX_COMPILER_ID:GNU>,$<CONFIG:Debug>>:-O0 -g ${_ARCH_FLAGS}>
      $<$<AND:$<CXX_COMPILER_ID:GNU>,$<CONFIG:RelWithDebInfo>>:-Og -g ${_ARCH_FLAGS}>
      $<$<AND:$<CXX_COMPILER_ID:GNU>,$<CONFIG:Asan>>:-O3 ${_ARCH_FLAGS}>
      
      # Clang flags for Release
      $<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:Release>>:-O3 ${_ARCH_FLAGS_CLANG} -ffast-math>
      $<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:Debug>>:-O0 -g ${_ARCH_FLAGS_CLANG}>
      $<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:RelWithDebInfo>>: -Og ${_ARCH_FLAGS_CLANG} -g>
      $<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:Asan>>:-O3 ${_ARCH_FLAGS_CLANG}>
    )
    
    # Add explicit AVX-512 disable flags if requested
    if(SPS_DISABLE_AVX512)
      target_compile_options(build INTERFACE
        -mno-avx512f -mno-avx512dq -mno-avx512bw -mno-avx512vl -mno-avx512cd
        # Use DWARF-4 debug format for better Valgrind compatibility
        $<$<CONFIG:Debug>:-gdwarf-4>
        $<$<CONFIG:RelWithDebInfo>:-gdwarf-4>
      )
    endif()      
  endif()

  # Set C++ target version
  target_compile_features(build INTERFACE cxx_std_20)
endif()

function(sps_link_optimization target)
  target_compile_options(${target} PRIVATE
    $<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:Release>>:
    -flto=full>
  )
  # We add this again in case the flag is not set transitively
  target_compile_options(${target} INTERFACE
    $<$<CXX_COMPILER_ID:MSVC>:/Zc:__cplusplus>
  )  
  target_compile_options(${target} PRIVATE
    $<$<AND:$<CXX_COMPILER_ID:GNU>,$<CONFIG:Release>>:
    -flto                                                # Link-time optimization
    -fuse-linker-plugin>                                 # Compiler and linker communicated more efficenly
  )
  if (NOT MSVC)
    target_link_options(${target} PRIVATE
      # This requires at least Clang17++
      $<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:Release>>:-fuse-ld=lld -flto>) # Can tigger floating point NaN errors.
  else()
    target_link_options(${target} PRIVATE
      $<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:Release>>:/LTCG>)
  endif()
endfunction()
