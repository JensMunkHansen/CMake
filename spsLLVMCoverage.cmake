# spsLLVMCoverage.cmake
# LLVM source-based coverage support (better for templates/inline functions than gcov)
#
# Usage:
#   include(spsLLVMCoverage)
#   sps_enable_llvm_coverage()  # Call after project() but before add_executable/library
#
# Then build and run:
#   cmake --preset linux-clang -DSPS_LLVM_COVERAGE=ON
#   cmake --build build/linux-clang --config Debug
#   cmake --build build/linux-clang --target coverage-llvm

# Find LLVM tools (support versioned names like llvm-cov-19)
function(_sps_find_llvm_tools)
  if(NOT LLVM_PROFDATA)
    find_program(LLVM_PROFDATA
      NAMES llvm-profdata llvm-profdata-19 llvm-profdata-18 llvm-profdata-17 llvm-profdata-16
    )
  endif()
  if(NOT LLVM_COV)
    find_program(LLVM_COV
      NAMES llvm-cov llvm-cov-19 llvm-cov-18 llvm-cov-17 llvm-cov-16
    )
  endif()
endfunction()

# Enable LLVM coverage flags
function(sps_enable_llvm_coverage)
  if(NOT CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    message(WARNING "LLVM coverage requires Clang compiler")
    return()
  endif()

  _sps_find_llvm_tools()

  if(NOT LLVM_PROFDATA OR NOT LLVM_COV)
    message(WARNING "LLVM coverage tools not found (llvm-profdata, llvm-cov)")
    return()
  endif()

  message(STATUS "LLVM coverage enabled")
  message(STATUS "  llvm-profdata: ${LLVM_PROFDATA}")
  message(STATUS "  llvm-cov: ${LLVM_COV}")

  # Set coverage flags
  set(LLVM_COV_FLAGS "-fprofile-instr-generate -fcoverage-mapping")

  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${LLVM_COV_FLAGS}" PARENT_SCOPE)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${LLVM_COV_FLAGS}" PARENT_SCOPE)
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fprofile-instr-generate" PARENT_SCOPE)

  # Apply to all configurations
  foreach(config DEBUG RELWITHDEBINFO MINSIZEREL RELEASE)
    string(TOUPPER "${config}" config_upper)
    set(CMAKE_C_FLAGS_${config_upper} "${CMAKE_C_FLAGS_${config_upper}} ${LLVM_COV_FLAGS}" PARENT_SCOPE)
    set(CMAKE_CXX_FLAGS_${config_upper} "${CMAKE_CXX_FLAGS_${config_upper}} ${LLVM_COV_FLAGS}" PARENT_SCOPE)
  endforeach()
endfunction()

# Add coverage-llvm target
# Usage: sps_add_llvm_coverage_target(TARGET_NAME test_executable [SOURCE_DIR dir] [EXCLUDE pattern...])
function(sps_add_llvm_coverage_target target_name test_target)
  cmake_parse_arguments(COV "" "SOURCE_DIR" "EXCLUDE" ${ARGN})

  _sps_find_llvm_tools()

  if(NOT LLVM_PROFDATA OR NOT LLVM_COV)
    message(WARNING "Cannot create coverage target: LLVM tools not found")
    return()
  endif()

  if(NOT COV_SOURCE_DIR)
    set(COV_SOURCE_DIR ${CMAKE_SOURCE_DIR})
  endif()

  # Build ignore regex from EXCLUDE patterns
  set(IGNORE_REGEX "")
  foreach(pattern ${COV_EXCLUDE})
    if(IGNORE_REGEX)
      set(IGNORE_REGEX "${IGNORE_REGEX}|${pattern}")
    else()
      set(IGNORE_REGEX "${pattern}")
    endif()
  endforeach()

  if(IGNORE_REGEX)
    set(IGNORE_ARG "-ignore-filename-regex=${IGNORE_REGEX}")
  else()
    set(IGNORE_ARG "")
  endif()

  add_custom_target(${target_name}
    # Run tests to generate profile data
    COMMAND ${CMAKE_COMMAND} -E env LLVM_PROFILE_FILE=${CMAKE_BINARY_DIR}/coverage.profraw
            $<TARGET_FILE:${test_target}>

    # Merge profile data
    COMMAND ${LLVM_PROFDATA} merge -sparse
            ${CMAKE_BINARY_DIR}/coverage.profraw
            -o ${CMAKE_BINARY_DIR}/coverage.profdata

    # Generate text report
    COMMAND ${LLVM_COV} report
            $<TARGET_FILE:${test_target}>
            -instr-profile=${CMAKE_BINARY_DIR}/coverage.profdata
            ${IGNORE_ARG}

    # Generate HTML report
    COMMAND ${LLVM_COV} show
            $<TARGET_FILE:${test_target}>
            -instr-profile=${CMAKE_BINARY_DIR}/coverage.profdata
            -format=html
            -output-dir=${CMAKE_BINARY_DIR}/coverage-llvm-html
            ${IGNORE_ARG}

    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Running tests and generating LLVM coverage report"
    DEPENDS ${test_target}
    VERBATIM
  )

  message(STATUS "Coverage target '${target_name}' created")
  message(STATUS "  HTML report will be at: ${CMAKE_BINARY_DIR}/coverage-llvm-html/index.html")
endfunction()
