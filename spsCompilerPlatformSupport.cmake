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

# Restore original flags
set(CMAKE_REQUIRED_FLAGS "${_old_flags}")
