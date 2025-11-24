# spsFastIndexAccess.cmake
#
# Determines if direct memory access via reinterpret_cast is safe for SIMD vector indexing.
# This optimization allows vec[i] to use direct pointer arithmetic instead of the slow
# store-to-array + index + reload-from-array fallback sequence.
#
# Performance: ~20x faster than the fallback path when enabled.
#
# Enabled when:
#  - GCC with -fno-strict-aliasing flag available
#  - Clang (non-Windows) with -fno-strict-aliasing flag available
#  - MSVC (native cl.exe) - lenient aliasing by default
#
# Disabled for:
#  - ClangCL - needs testing on CI to verify MSVC semantics compatibility
#  - Other compilers without -fno-strict-aliasing support
#
# Exports: SUPPORTS_FAST_INDEX_ACCESS (0 or 1) to parent scope

function(sps_check_fast_index_access)
    set(SUPPORTS_FAST_INDEX_ACCESS 0)

    if(MSVC)
        # Windows builds: MSVC or ClangCL
        if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
            # Native MSVC: Safe due to lenient aliasing semantics
            set(SUPPORTS_FAST_INDEX_ACCESS 1)
            message(STATUS "FAST_INDEX_ACCESS: Enabled (MSVC)")

        elseif(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
            # ClangCL: Should work like MSVC (inherits lenient aliasing semantics)
            # If flag is needed, use: /clang:-fno-strict-aliasing (Microsoft-style to pass to Clang)
            # Disabled pending testing - to enable, change this to 1
            set(SUPPORTS_FAST_INDEX_ACCESS 0)
            message(STATUS "FAST_INDEX_ACCESS: Disabled (ClangCL - needs testing on CI)")

            # To test on CI, uncomment these lines:
            # set(SUPPORTS_FAST_INDEX_ACCESS 1)
            # message(STATUS "FAST_INDEX_ACCESS: Enabled (ClangCL - assuming MSVC semantics)")

            # If reinterpret_cast fails, try adding this flag:
            # set(NEEDS_CLANGCL_NO_STRICT_ALIASING 1)
        endif()

    else()
        # Unix-like platforms: GCC, Clang, etc.
        include(CheckCXXCompilerFlag)
        check_cxx_compiler_flag("-fno-strict-aliasing" HAS_NO_STRICT_ALIASING)

        if(HAS_NO_STRICT_ALIASING)
            if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
                set(SUPPORTS_FAST_INDEX_ACCESS 1)
                set(NEEDS_NO_STRICT_ALIASING 1)
                message(STATUS "FAST_INDEX_ACCESS: Enabled (Clang with -fno-strict-aliasing)")

            elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
                set(SUPPORTS_FAST_INDEX_ACCESS 1)
                set(NEEDS_NO_STRICT_ALIASING 1)
                message(STATUS "FAST_INDEX_ACCESS: Enabled (GCC with -fno-strict-aliasing)")
            else()
                message(STATUS "FAST_INDEX_ACCESS: Disabled (unknown compiler: ${CMAKE_CXX_COMPILER_ID})")
            endif()
        else()
            message(STATUS "FAST_INDEX_ACCESS: Disabled (-fno-strict-aliasing not supported)")
        endif()
    endif()

    # Export to parent scope
    set(SUPPORTS_FAST_INDEX_ACCESS ${SUPPORTS_FAST_INDEX_ACCESS} PARENT_SCOPE)
    set(NEEDS_NO_STRICT_ALIASING ${NEEDS_NO_STRICT_ALIASING} PARENT_SCOPE)
    set(NEEDS_CLANGCL_NO_STRICT_ALIASING ${NEEDS_CLANGCL_NO_STRICT_ALIASING} PARENT_SCOPE)
endfunction()

# Run the check
sps_check_fast_index_access()
