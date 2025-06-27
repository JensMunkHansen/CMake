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
    # Linker flags need for MSVC
    set(CMAKE_STATIC_LINKER_FLAGS "${CMAKE_STATIC_LINKER_FLAGS} /LTCG")    
  endif()

  # MSVC or Microsofts Clang version
  if(IS_MSVC_OR_CLANG_CL)
    target_compile_options(build INTERFACE
      $<$<CONFIG:Release>:/O2 /GL /fp:fast /Qpar /arch:AVX2>
      $<$<CONFIG:Debug>:/Od /Zi /arch:AVX2>
      $<$<CONFIG:Asan>:/Od /GL /arch:AVX2>
      $<$<CONFIG:RelWithDebInfo>:/O1 /Zi /arch:AVX2>
    )

    # Microsoft report old c++ version from 1997, if not set
    target_compile_options(build INTERFACE
      $<$<CXX_COMPILER_ID:MSVC>:/Zc:__cplusplus>
    )
    # Linker flags needed by Microsoft
    set(CMAKE_STATIC_LINKER_FLAGS "${CMAKE_STATIC_LINKER_FLAGS} /LTCG")    
  else()
    # Linux build
    target_compile_options(build
      INTERFACE
      # GNU flags
      $<$<AND:$<CXX_COMPILER_ID:GNU>,$<CONFIG:Release>>:-O3 -march=native -mtune=native -ffast-math>
      $<$<AND:$<CXX_COMPILER_ID:GNU>,$<CONFIG:Debug>>:-O0 -g -march=native>
      $<$<AND:$<CXX_COMPILER_ID:GNU>,$<CONFIG:RelWithDebInfo>>:-Og -g -march=native>
      $<$<AND:$<CXX_COMPILER_ID:GNU>,$<CONFIG:Asan>>:-O3 -march=native>
      
      # Clang flags for Release
      $<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:Release>>:-O3 -march=native -ffast-math>
      $<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:Debug>>:-O0 -g -march=native>
      $<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:RelWithDebInfo>>: -Og -march=native -g>
      $<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:Asan>>:-O3 -march=native>
    )      
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
      $<$<AND:$<CXX_COMPILER_ID:Clang>,$<CONFIG:Release>>:-fuse-ld=lld -flto>)
  else()
    target_link_options(${target} PRIVATE
      $<$<AND:$<CXX_COMPILER_ID:MSVC>,$<CONFIG:Release>>:/LTCG>)
  endif()
endfunction()
