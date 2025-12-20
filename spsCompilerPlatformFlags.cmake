# Clear flags for RelWithDebInfo
set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "")

if (TARGET build)
  if (MSVC)
    set(IS_MSVC_OR_CLANG_CL FALSE)
    set(IS_REAL_MSVC FALSE)
    if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
      set(IS_MSVC_OR_CLANG_CL TRUE)
      set(IS_REAL_MSVC TRUE)
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND MSVC)
      set(IS_MSVC_OR_CLANG_CL TRUE)
    endif()
  endif()

  # MSVC or Microsofts Clang version
  if(IS_MSVC_OR_CLANG_CL)
    # Prevent Windows.h min/max macros from conflicting with std::min/max
    target_compile_definitions(build INTERFACE NOMINMAX)

    # Architecture flags - propagate to consumers (needed for SIMD headers)
    target_compile_options(build INTERFACE /arch:AVX2)

    # Build-specific flags - do NOT propagate to consumers (common to MSVC and clang-cl)
    target_compile_options(build INTERFACE
      $<BUILD_INTERFACE:/EHsc>  # Enable C++ stack unwinding and assume extern "C" functions never throw
      $<BUILD_INTERFACE:$<$<CONFIG:Release>:/O2 /fp:fast>>
      $<BUILD_INTERFACE:$<$<CONFIG:Debug>:/Od /Zi>>
      $<BUILD_INTERFACE:$<$<CONFIG:Asan>:/Od /Zi>>
      $<BUILD_INTERFACE:$<$<CONFIG:RelWithDebInfo>:/O1 /Zi>>
    )

    # MSVC-only flags (not supported by clang-cl)
    if(IS_REAL_MSVC)
      target_compile_options(build INTERFACE
        $<BUILD_INTERFACE:$<$<CONFIG:Release>:/GL /Qpar>>
      )
      # Linker flags needed by Microsoft (build-specific)
      set(CMAKE_STATIC_LINKER_FLAGS "${CMAKE_STATIC_LINKER_FLAGS} /LTCG")
    endif()

    # Compatibility flags - propagate to consumers (needed for correct __cplusplus value)
    target_compile_options(build INTERFACE
      $<$<CXX_COMPILER_ID:MSVC>:/Zc:__cplusplus>
    )    
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
    
    # Architecture flags - propagate to consumers (needed for SIMD headers)
    target_compile_options(build INTERFACE
      $<$<CXX_COMPILER_ID:GNU>:${_ARCH_FLAGS}>
      $<$<CXX_COMPILER_ID:Clang>:${_ARCH_FLAGS_CLANG}>
    )

    # Build-specific flags - do NOT propagate to consumers
    target_compile_options(build INTERFACE
      # GNU flags
      $<BUILD_INTERFACE:$<$<AND:$<CXX_COMPILER_ID:GNU>,$<CONFIG:Release>>:-O3 -ffast-math>>
      $<BUILD_INTERFACE:$<$<AND:$<CXX_COMPILER_ID:GNU>,$<CONFIG:Debug>>:-O0 -g>>
      $<BUILD_INTERFACE:$<$<AND:$<CXX_COMPILER_ID:GNU>,$<CONFIG:RelWithDebInfo>>:-Og -g>>
      $<BUILD_INTERFACE:$<$<AND:$<CXX_COMPILER_ID:GNU>,$<CONFIG:Asan>>:-O3>>

      # Clang flags
      $<BUILD_INTERFACE:$<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:Release>>:-O3 -ffast-math>>
      $<BUILD_INTERFACE:$<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:Debug>>:-O0 -g>>
      $<BUILD_INTERFACE:$<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:RelWithDebInfo>>:-Og -g>>
      $<BUILD_INTERFACE:$<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:Asan>>:-O3>>
    )
    
    # Add explicit AVX-512 disable flags if requested (GCC/Clang only, not MSVC)
    if(SPS_DISABLE_AVX512)
      # Architecture flags - propagate to consumers
      target_compile_options(build INTERFACE
        $<$<CXX_COMPILER_ID:GNU>:-mno-avx512f -mno-avx512dq -mno-avx512bw -mno-avx512vl -mno-avx512cd>
        $<$<CXX_COMPILER_ID:Clang>:-mno-avx512f -mno-avx512dq -mno-avx512bw -mno-avx512vl -mno-avx512cd>
      )
      # Debug format flags - build-specific, do NOT propagate
      target_compile_options(build INTERFACE
        $<BUILD_INTERFACE:$<$<AND:$<CXX_COMPILER_ID:GNU>,$<CONFIG:Debug>>:-gdwarf-4>>
        $<BUILD_INTERFACE:$<$<AND:$<CXX_COMPILER_ID:GNU>,$<CONFIG:RelWithDebInfo>>:-gdwarf-4>>
        $<BUILD_INTERFACE:$<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:Debug>>:-gdwarf-4>>
        $<BUILD_INTERFACE:$<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:RelWithDebInfo>>:-gdwarf-4>>
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
    -flto=auto                                           # Link-time optimization (auto-parallelize)
    -fuse-linker-plugin>                                 # Compiler and linker communicated more efficenly
  )
  if (NOT MSVC)
    # Check if LLD is available for Clang
    if(NOT DEFINED SPS_HAS_LLD)
      find_program(SPS_LLD_EXECUTABLE NAMES lld ld.lld)
      if(SPS_LLD_EXECUTABLE)
        set(SPS_HAS_LLD TRUE CACHE INTERNAL "LLD linker available")
      else()
        set(SPS_HAS_LLD FALSE CACHE INTERNAL "LLD linker not available")
      endif()
    endif()

    if(SPS_HAS_LLD)
      target_link_options(${target} PRIVATE
        $<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:Release>>:-fuse-ld=lld -flto>)
    else()
      target_link_options(${target} PRIVATE
        $<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:Release>>:-flto>)
    endif()
  else()
    target_link_options(${target} PRIVATE
      $<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:Release>>:/LTCG>)
  endif()
endfunction()
