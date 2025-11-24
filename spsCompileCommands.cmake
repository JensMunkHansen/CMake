if(CMAKE_EXPORT_COMPILE_COMMANDS)
  add_custom_command(
    OUTPUT "${${PROJECT_NAME}_SOURCE_DIR}/compile_commands.json"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${${PROJECT_NAME}_BINARY_DIR}/compile_commands.json"
            "${${PROJECT_NAME}_SOURCE_DIR}/compile_commands.json"
    DEPENDS "${${PROJECT_NAME}_BINARY_DIR}/compile_commands.json"
    COMMENT "Copying compile_commands.json"
  )
  
  add_custom_target(copy_compile_commands ALL
    DEPENDS "${${PROJECT_NAME}_BINARY_DIR}/compile_commands.json"
  )
endif()
