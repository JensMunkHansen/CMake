# Toolchain file for cross-compiling to 64-bit ARM (aarch64) Linux with Clang.
# Uses the Debian/Ubuntu GCC cross toolchain's sysroot and libstdc++
# (apt install g++-aarch64-linux-gnu) and runs tests under user-mode qemu
# (apt install qemu-user).

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(CMAKE_C_COMPILER clang)
set(CMAKE_CXX_COMPILER clang++)
set(CMAKE_C_COMPILER_TARGET aarch64-linux-gnu)
set(CMAKE_CXX_COMPILER_TARGET aarch64-linux-gnu)

# Where the cross libc/libstdc++ live on Debian/Ubuntu
set(CMAKE_FIND_ROOT_PATH /usr/aarch64-linux-gnu)

# Search programs on the host; libraries/headers/packages only in the target sysroot
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Run cross-compiled binaries (tests) through user-mode qemu.
# -L points qemu at the target dynamic loader and libraries.
find_program(SPS_QEMU_AARCH64 qemu-aarch64)
if(SPS_QEMU_AARCH64)
  set(CMAKE_CROSSCOMPILING_EMULATOR "${SPS_QEMU_AARCH64};-L;/usr/aarch64-linux-gnu")
endif()
