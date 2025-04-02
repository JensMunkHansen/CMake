if(CMAKE_EXPORT_COMPILE_COMMANDS)
  execute_process(COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${CMAKE_BINARY_DIR}/compile_commands.json"
    "${CMAKE_SOURCE_DIR}/compile_commands.json")
endif()
