if (TARGET build)
  if (EMSCRIPTEN)
    target_compile_options(build
      INTERFACE
        -O3 -msimd128 -ffast-math -mllvm -vectorize-loops)
  else()
    target_compile_options(build
      INTERFACE
       $<$<CXX_COMPILER_ID:GNU>:-O3 -march=native -mtune=native -flto -fuse-linker-plugin -ftree-vectorize -fopt-info-vec>
       $<$<CXX_COMPILER_ID:Clang>:-O3 -march=native -Rpass=loop-vectorize -Rpass-missed=loop-vectorize>
       $<$<CXX_COMPILER_ID:MSVC>:/O2 /GL /fp:fast /Qvec /Qpar /arch:AVX2>)
  endif()
  target_compile_features(build INTERFACE cxx_std_20)
  target_link_options(build INTERFACE
      $<$<CXX_COMPILER_ID:Clang>:-fuse-ld=lld -flto>)
endif ()

