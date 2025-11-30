#[==[.rst:
*********
spsClangCLWarnings
*********
  Known ClangCL warning flags (no runtime checking needed).
  ClangCL uses Clang frontend with MSVC backend, requiring /clang: prefix for Clang-style flags.
#]==]

set(_SPS_CLANGCL_KNOWN_FLAGS
  # Enabling warnings
  -Wall
  -Wextra
  -Wshadow                                  # Critical for threading code
  -Wnull-dereference
  -Wabsolute-value
  -Wunreachable-code
  -Wunused-but-set-variable
  -Wunused-function
  -Wunused-local-typedef
  -Wunused-parameter
  -Wunused-variable
  -Wsign-compare
  -Wmissing-field-initializers
  -Wold-style-cast                          # Enforce C++ style casts
  -Woverloaded-virtual                      # Virtual function hiding
  -Wsuggest-override                        # Missing override keywords
  -Winconsistent-missing-destructor-override
  -Wnon-virtual-dtor
  -Wpessimizing-move
  -Wrange-loop-bind-reference
  -Wreorder-ctor
  -Wunused-lambda-capture
  -Wunused-private-field
  # Suppressing warnings
  -Wno-extra-semi                           # Semicolons after macros improve IDE behavior
  -Wno-c++98-compat-pedantic
  -Wno-c++98-compat
  -Wno-c++98-c++11-compat-binary-literal    # Binary literals (0b...)
  -Wno-c++98-compat-bind-to-temporary-copy  # Catch2 compatibility
  -Wno-pre-c++17-compat
  -Wno-reserved-macro-identifier
  -Wno-reserved-identifier                  # __prefixed identifiers
  -Wno-undef                                # HAS_CXXABI_H and other platform macros
  -Wno-documentation                        # Pre-existing doxygen issues
  -Wno-float-equal                          # Float comparison with ==
  -Wno-header-hygiene                       # using namespace in headers
  -Wno-missing-prototypes
  -Wno-nonportable-system-include-path      # Windows include paths
  -Wno-sign-conversion                      # int to size_t conversions
  -Wno-unsafe-buffer-usage                  # Raw pointer/array access (essential for SIMD)
  -Wno-shorten-64-to-32                     # int64_t to int32_t truncation (intentional)
  -Wno-switch-default
  -Wno-nan-infinity-disabled                # Fast-math mode NaN/infinity
  -Wno-padded
)
