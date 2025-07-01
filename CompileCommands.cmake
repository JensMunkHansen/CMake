# File: CopyCompileCommands.cmake
if(EXISTS "${SOURCE}")
  file(COPY "${SOURCE}" DESTINATION "${DESTINATION_DIR}")
else()
  message(WARNING "compile_commands.json not found at ${SOURCE}")
endif()
