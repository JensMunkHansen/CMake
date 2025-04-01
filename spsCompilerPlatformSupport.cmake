include(CheckCXXSourceCompiles)

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
set(${PROJECT_NAME}_ATOMIC_SHARED_PTR ${SPS_ATOMIC_SHARED_PTR} PARENT_SCOPE)

if(${PROJECT_NAME}_ATOMIC_SHARED_PTR)
  message(STATUS "Compiler supports std::atomic<std::shared_ptr<T>>")
else()
  message(WARNING "Compiler does NOT support std::atomic<std::shared_ptr<T>>")
endif()
