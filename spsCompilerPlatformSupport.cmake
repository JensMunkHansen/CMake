include(CheckCXXSourceCompiles)

# Save the original flags
set(_old_flags "${CMAKE_REQUIRED_FLAGS}")

# Check for specific C++20 features
set(CMAKE_REQUIRED_FLAGS "-std=c++20")

check_cxx_source_compiles("
  #include <memory>
  #include <atomic>

  void test() {
    std::shared_ptr<int> ptr = std::make_shared<int>(42);
    std::atomic<std::shared_ptr<int>> atomic_ptr(ptr);
  }

  int main() {
    test();
    return 0;
  }
" SPS_ATOMIC_SHARED_PTR)
set(${PROJECT_NAME}_ATOMIC_SHARED_PTR ${SPS_ATOMIC_SHARED_PTR})

if(${PROJECT_NAME}_ATOMIC_SHARED_PTR)
  message(STATUS "Compiler supports std::atomic<std::shared_ptr<T>>")
else()
  message(WARNING "Compiler does NOT support std::atomic<std::shared_ptr<T>>")
endif()

set(_old_libraries "${CMAKE_REQUIRED_LIBRARIES}")

# Check for specific C++20 features
set(CMAKE_REQUIRED_LIBRARIES "stdc++")

check_cxx_source_compiles("
  #include <format>
  #include <string>
  int main() {
    auto s = std::format(\"{}\", 42);
    return 0;
  }
" HAS_STD_FORMAT)

set(${PROJECT_NAME}_STD_FORMAT} ${HAS_STD_FORMAT})

if(HAS_STD_FORMAT)
  message(STATUS "Compiler supports std::format")
else()
  message(WARNING "Compiler does NOT support std::format")
endif()

if (HAS_STD_FORMAT)
  target_compile_definitions(build INTERFACE USE_STD_FORMAT=1)
else()
  find_package(fmt QUIET)
  if (FMT_FOUND)
    message(STATUS "Library fmt::fmt is available")
    set(${PROJECT_NAME}_HAS_FORMAT TRUE)
    target_link_libraries(build INTERFACE fmt::fmt)
  else()
    message(WARNING "Library fmt::fmt not available - using fallback")
    set(${PROJECT_NAME}_HAS_FORMAT FALSE)
  endif()
endif()

# Restore original flags
set(CMAKE_REQUIRED_FLAGS "${_old_flags}")
set(CMAKE_REQUIRED_LIBRARIES "${_old_libraries}")
