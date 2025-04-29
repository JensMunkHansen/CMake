# Clear flags for RelWithDebInfo
set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "")

if (TARGET build)
  if (EMSCRIPTEN)
    target_compile_options(build
      INTERFACE
      -O3 -msimd128 -ffast-math -mllvm -vectorize-loops)
  elseif(NOT MSVC)
    # Microsft has screwed up their Clang support to only support MSVC flags!!!!
    target_compile_options(build
      INTERFACE
      # GNU flags for Release
      $<$<AND:$<CXX_COMPILER_ID:GNU>,$<CONFIG:Release>>:-O3
      -march=native                           # Current CPU
      -mtune=native                           # Compatibility with older CPUs
      -funroll-loops
      # -funroll-loops-threshold=1000         # More unrolling
      -ffast-math
      #-flto                                   # Link-time optimization
      #-fuse-linker-plugin                     # Compiler and linker communicated more efficenly
      # -fprefetch-loop-arrays                # Helps memory-bound loops
      -ftree-vectorize                        # auto-vectorization
      # -falign-loops=32                      # ensure loops starts on aligned boundaries
      # -falign-functions=32 -falign-jumps=32 # Instruction cache efficiency
      -fopt-info-vec                          # To see if vectorization is done succesfully
      # -fopt-info-vec-optimized              # To see which loops were optimizated for vectorization (more details)
      >
      
      # GNU flags for Debug
      $<$<AND:$<CXX_COMPILER_ID:GNU>,$<CONFIG:Debug>>:-O0 -g>
      $<$<AND:$<CXX_COMPILER_ID:GNU>,$<CONFIG:RelWithDebInfo>>:-Og -g>

      # Clang flags for Release
      $<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:Release>>:-O3
      -march=native
      -mtune=native

                                              # TODO: Move optimization to real and not interface targets
      # -flto=full                              # Can give issue with IR in static libraries
      -funroll-loops
      # -mavx512f -mavx512bw -mavx512dq -mfma # -march=native covers maximum available
      -ffast-math
      -ffp-contract=fast                      # Extra to match GCC's -ffast-math  
      -fassociative-math                      # Extra to match GCC's -ffast-math  
      -freciprocal-math                       # Extra to match GCC's -ffast-math  
      -Rpass=loop-vectorize                   # Show succesfull vectorized loops
      # -Rpass-missed=loop-vectorize          # Show why certain loops not vectorized
      # -Rpass-analysis=loop-vectorize>       # Print analysis of loop vectorization
      # -fwhole-program-vtables
      # -fprefetch-loop-arrays
      # -mllvm -enable-loop-flatten
      # -mllvm -enable-epilogue-vectorization
      # -mllvm -enable-slp-vectorization
      >

      # Clang flags for Debug
      $<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:Debug>>:-O0 -g>
      $<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:RelWithDebInfo>>:
      -Og
      -gdwarf-4                            # Use older version of DWARF for compatibility with valgrind
      # -fno-omit-frame-pointer            # Keep frame pointer intact in every function
      # -fno-inline                        # No inlining (not working)
      -g
      >
      
      # MSVC flags for Release
      $<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:Release>>:/O2 /GL /fp:fast /Qvec /Qpar /arch:AVX2>
      # MSVC flags for Debug
      $<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:Debug>>:/Od /Zi>
      # MSVC flags for RelWithDebInfo    
      $<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:RelWithDebInfo>>:/O1 /Zi>)

      # TODO: Profile-Guided Optimization (PGO) (10-30%)
      #       Binary Optimization Layout Tool (BOLT) on the final binary (5-20% faster)
      #       bolt binary optimized_binary
      # Clang flags for Debug
      # L1: 32 kB (10 kB), some have 48 kB (16 kB)
      # L2: 1.25 MB
      # _mm_prefetch((const char*)&A[i], _MM_HINT_T0);
      # _mm_prefetch((const char*)&A[i], _MM_HINT_T1);
      # _mm_prefetch((const char*)&A[i], _MM_HINT_T2);
      # _mm_prefetch((const char*)&A[i], _MM_HINT_NTA);
  endif()

  # Microsoft has screwed up Clang support
  if (MSVC)

  set(IS_MSVC_OR_CLANG_CL FALSE)
  if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
    set(IS_MSVC_OR_CLANG_CL TRUE)
  elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND MSVC)
    set(IS_MSVC_OR_CLANG_CL TRUE)
  endif()

  if(IS_MSVC_OR_CLANG_CL)
  target_compile_options(build INTERFACE
    $<$<CONFIG:Release>:/O2 /GL /fp:fast /Qpar /arch:AVX2>
    $<$<CONFIG:Debug>:/Od /Zi>
    $<$<CONFIG:RelWithDebInfo>:/O1 /Zi>
  )
  endif()
    
  endif()

  target_compile_features(build INTERFACE cxx_std_20)
  # Visual lies about __cplusplus
  target_compile_options(build INTERFACE
    $<$<CXX_COMPILER_ID:MSVC>:/Zc:__cplusplus>
  )
# Check for MSVC or clang-cl
  if (CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND CMAKE_CXX_SIMULATE_ID STREQUAL "MSVC")
    target_compile_options(build INTERFACE /Zc:__cplusplus)
  endif()
  
  
#   target_link_options(build INTERFACE
#     # This requires Clang17++
#     $<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:Release>>:-fuse-ld=lld -flto>  # Don't use this on static libraries
#     $<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:Release>>:/LTCG>
#   )
  if (MSVC)
    set(CMAKE_STATIC_LINKER_FLAGS "${CMAKE_STATIC_LINKER_FLAGS} /LTCG")    
  endif()
  # TODO: Try this
#  target_compile_options(build INTERFACE 
#    "$<$<AND:$<CXX_COMPILER_ID:Clang>,$<CXX_SIMULATE_ID:MSVC>>:/Zc:__cplusplus>"
#  )
  
endif()

function(sps_link_optimization target)
  target_compile_options(${target} PRIVATE
    $<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:Release>>:
    -flto=full>
  )
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
      # This requires Clang17++
      $<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:Release>>:-fuse-ld=lld -flto>)
  else()
    target_link_options(${target} PRIVATE
      $<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:Release>>:/LTCG>)
  endif()
endfunction()
