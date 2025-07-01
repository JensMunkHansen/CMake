if(CMAKE_EXPORT_COMPILE_COMMANDS)
  add_custom_target(copy_compile_commands ALL
    COMMAND ${CMAKE_COMMAND}
      -DSOURCE="${${PROJECT_NAME}_BINARY_DIR}/compile_commands.json"
      -DDESTINATION_DIR="${${PROJECT_NAME}_SOURCE_DIR}/compile_commands.json"
      -P ${CMAKE_CURRENT_LIST_DIR}/CopyCompileCommands.cmake
    COMMENT "Copying compile_commands.json to source dir"
    VERBATIM
  )
endif()
