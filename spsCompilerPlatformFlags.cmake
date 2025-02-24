if (TARGET build)
  if (EMSCRIPTEN)
    target_compile_options(build
      INTERFACE
      -O3 -msimd128 -ffast-math -mllvm -vectorize-loops)
  else()
    target_compile_options(build
      INTERFACE
      # GNU flags for Release
      $<$<AND:$<CXX_COMPILER_ID:GNU>,$<CONFIG:Release>>:-O3 -march=native -mtune=native -flto -fuse-linker-plugin -ftree-vectorize -fopt-info-vec>
      # GNU flags for Debug
      $<$<AND:$<CXX_COMPILER_ID:GNU>,$<CONFIG:Debug>>:-O0 -g>

      # Clang flags for Release
      $<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:Release>>:-O3 -march=native -Rpass=loop-vectorize -Rpass-missed=loop-vectorize>
      # Clang flags for Debug
      $<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:Debug>>:-O0 -g>
      
      # MSVC flags for Release
      $<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:Release>>:/O2 /GL /fp:fast /Qvec /Qpar /arch:AVX2>
      # MSVC flags for Debug
      $<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:Debug>>:/Od /Zi>)
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

