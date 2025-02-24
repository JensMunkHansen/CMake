if (TARGET build)
  if (EMSCRIPTEN)
    target_compile_options(build
      INTERFACE
      -O3 -msimd128 -ffast-math -mllvm -vectorize-loops)
  else()
    target_compile_options(build
      INTERFACE
      # GNU flags for Release
      $<$<AND:$<CXX_COMPILER_ID:GNU>,$<CONFIG:Release>>:-O3
      -march=native # Current CPU
      -mtune=native # Compatibility with older CPUs
      -funroll-loops
      # -funroll-loops-threshold=1000 # More unrolling
      -ffast-math
      -flto # Link-time optimization
      -fuse-linker-plugin # Compiler and linker communicated more efficenly
      # -fprefetch-loop-arrays # Helps memory-bound loops
      -ftree-vectorize # auto-vectorization
      # -falign-loops=32 # ensure loops starts on aligned boundaries
      # -falign-functions=32 -falign-jumps=32 # Instruction cache efficiency
      -fopt-info-vec           # To see if vectorization is done succesfully
      # -fopt-info-vec-optimized # To see which loops were optimizated for vectorization (more details)
      >
      # GNU flags for Debug
      $<$<AND:$<CXX_COMPILER_ID:GNU>,$<CONFIG:Debug>>:-O0 -g>

      # Clang flags for Release
      $<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:Release>>:
      -O3 -march=native -mtune=native -flto=full -funroll-loops
      # -mavx512f -mavx512bw -mavx512dq -mfma
      -ffast-math -ffp-contract=fast -fassociative-math -freciprocal-math  # Matches GCC's -ffast-math  
      -Rpass=loop-vectorize # Show succesfull vectorized loops
      # -Rpass-missed=loop-vectorize # Show why certain loops not vectorized
      # -Rpass-analysis=loop-vectorize> # Print analysis of loop vectorization
      # -fwhole-program-vtables
      # -fprefetch-loop-arrays
      # -mllvm -enable-loop-flatten
      # -mllvm -enable-epilogue-vectorization
      # -mllvm -enable-slp-vectorization

      $<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:Debug>>:-O0 -g>
      
      # MSVC flags for Release
      $<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:Release>>:/O2 /GL /fp:fast /Qvec /Qpar /arch:AVX2>
      # MSVC flags for Debug
      $<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:Debug>>:/Od /Zi>)

      # TODO: Profile-Guided Optimization (PGO) (10-30%)
      #       Binary Optimization Layout Tool (BOLT) on the final binary (5-20% faster)
      #       bolt binary optimized_binary
      # Clang flags for Debug
  endif()
  target_compile_features(build INTERFACE cxx_std_17)
  target_link_options(build INTERFACE
    # This requires Clang17
    $<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:Release>>:-fuse-ld=lld -flto>
    $<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:Release>>:/LTCG>
  )
  if (MSVC)
    set(CMAKE_STATIC_LINKER_FLAGS "${CMAKE_STATIC_LINKER_FLAGS} /LTCG")    
  endif()
  
endif ()

