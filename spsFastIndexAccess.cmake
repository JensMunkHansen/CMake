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
#  - ClangCL - verified working (inherits MSVC semantics)
#
# Disabled for:
#  - Other compilers without -fno-strict-aliasing support
#
# Note: If older ClangCL versions fail, set SPS_SUPPORTS_FAST_INDEX_ACCESS=0
# or enable SPS_NEEDS_CLANGCL_NO_STRICT_ALIASING=1 for explicit flag.
#
# Exports: SPS_SUPPORTS_FAST_INDEX_ACCESS (0 or 1) to parent scope

function(sps_check_fast_index_access)
    set(SPS_SUPPORTS_FAST_INDEX_ACCESS 0)

    if(MSVC)
        # Windows builds: MSVC or ClangCL
        if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
            # Native MSVC: Safe due to lenient aliasing semantics
            set(SPS_SUPPORTS_FAST_INDEX_ACCESS 1)
            message(STATUS "FAST_INDEX_ACCESS: Enabled (MSVC)")

        elseif(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
            # ClangCL: Verified working - inherits MSVC's lenient aliasing semantics
            # No explicit flag needed for modern ClangCL versions
            set(SPS_SUPPORTS_FAST_INDEX_ACCESS 1)
            message(STATUS "FAST_INDEX_ACCESS: Enabled (ClangCL)")

            # For older ClangCL versions that fail, uncomment to add explicit flag:
            # set(SPS_NEEDS_CLANGCL_NO_STRICT_ALIASING 1)
            # This will add: /clang:-fno-strict-aliasing
        endif()

    else()
        # Unix-like platforms: GCC, Clang, etc.
        include(CheckCXXCompilerFlag)
        check_cxx_compiler_flag("-fno-strict-aliasing" HAS_NO_STRICT_ALIASING)

        if(HAS_NO_STRICT_ALIASING)
            if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
                set(SPS_SUPPORTS_FAST_INDEX_ACCESS 1)
                set(SPS_NEEDS_NO_STRICT_ALIASING 1)
                message(STATUS "FAST_INDEX_ACCESS: Enabled (Clang with -fno-strict-aliasing)")

            elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
                set(SPS_SUPPORTS_FAST_INDEX_ACCESS 1)
                set(SPS_NEEDS_NO_STRICT_ALIASING 1)
                message(STATUS "FAST_INDEX_ACCESS: Enabled (GCC with -fno-strict-aliasing)")
            else()
                message(STATUS "FAST_INDEX_ACCESS: Disabled (unknown compiler: ${CMAKE_CXX_COMPILER_ID})")
            endif()
        else()
            message(STATUS "FAST_INDEX_ACCESS: Disabled (-fno-strict-aliasing not supported)")
        endif()
    endif()

    # Export to parent scope
    set(SPS_SUPPORTS_FAST_INDEX_ACCESS ${SPS_SUPPORTS_FAST_INDEX_ACCESS} PARENT_SCOPE)
    set(SPS_NEEDS_NO_STRICT_ALIASING ${SPS_NEEDS_NO_STRICT_ALIASING} PARENT_SCOPE)
    set(SPS_NEEDS_CLANGCL_NO_STRICT_ALIASING ${SPS_NEEDS_CLANGCL_NO_STRICT_ALIASING} PARENT_SCOPE)
endfunction()

# Run the check
sps_check_fast_index_access()
