#[==[.rst:
*********
spsUBSan
*********
Address sanitizer for any product. Include for convenience

-fsanitize=alignment: Detects misaligned memory accesses.
-fsanitize=integer-divide-by-zero: Detects division by zero.
-fsanitize=shift: Detects invalid bit shifts.
-fsanitize=null

#]==]

get_property(isMultiConfig GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)

if(isMultiConfig)
  if(NOT "UBsan" IN_LIST CMAKE_CONFIGURATION_TYPES)
    list(APPEND CMAKE_CONFIGURATION_TYPES UBsan)
  endif()
else()
  set(allowedBuildTypes Usan Debug Release RelWithDebInfo MinSizeRel)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "${allowedBuildTypes}")

  if(CMAKE_BUILD_TYPE AND NOT CMAKE_BUILD_TYPE IN_LIST allowedBuildTypes)
    message(FATAL_ERROR "Invalid build type: ${CMAKE_BUILD_TYPE}")
  endif()
endif()

set(CMAKE_C_FLAGS_UBSAN
  "${CMAKE_C_FLAGS_DEBUG} -fsanitize=undefined,alignment,integer-divide-by-zero,shift,null -fno-omit-frame-pointer" CACHE STRING
  "Flags used by the C compiler for Asan build type or configuration." FORCE)

set(CMAKE_CXX_FLAGS_UBSAN
  "${CMAKE_CXX_FLAGS_DEBUG} -fsanitize=undefined,alignment,integer-divide-by-zero,shift,null -fno-omit-frame-pointer" CACHE STRING
  "Flags used by the C++ compiler for Asan build type or configuration." FORCE)

set(CMAKE_EXE_LINKER_FLAGS_UBSAN
  "${CMAKE_SHARED_LINKER_FLAGS_DEBUG} -fsanitize=undefined,alignment,integer-divide-by-zero,shift,null" CACHE STRING
  "Linker flags to be used to create executables for Asan build type." FORCE)

set(CMAKE_SHARED_LINKER_FLAGS_UBSAN
  "${CMAKE_SHARED_LINKER_FLAGS_DEBUG} -fsanitize=undefined,alignment,integer-divide-by-zero,shift,null" CACHE STRING
  "Linker lags to be used to create shared libraries for Asan build type." FORCE)

# For single-config generators, apply the flags directly
if(NOT isMultiConfig AND CMAKE_BUILD_TYPE STREQUAL "UBsan")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS_UBSAN}")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS_UBSAN}")
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS_UBSAN}")
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS_UBSAN}")
endif()
