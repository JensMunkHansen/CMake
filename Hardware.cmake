# Include CMake module for processor count
include(ProcessorCount)

# Get the processor count
ProcessorCount(PROCESSOR_COUNT)

# Check if processor count was successfully retrieved
if(PROCESSOR_COUNT EQUAL 0)
    message(WARNING "Processor count could not be determined. Defaulting to 1.")
    set(PROCESSOR_COUNT 1)
else()
    message(STATUS "Detected ${PROCESSOR_COUNT} processors.")
endif()

# Use PROCESSOR_COUNT in your build process
set(MAX_CONCURRENCY ${PROCESSOR_COUNT})

if (0)
  include(ProcessorCount)
  
  # Execute a system command to get the processor count
  execute_process(COMMAND nproc OUTPUT_VARIABLE PROCESSOR_COUNT OUTPUT_STRIP_TRAILING_WHITESPACE)
  
  # Fallback if the result is empty
  if(PROCESSOR_COUNT STREQUAL "")
    message(WARNING "Processor count could not be determined. Defaulting to 1.")
    set(PROCESSOR_COUNT 1)
  endif()
  
  message(STATUS "Detected ${PROCESSOR_COUNT} processors.")
  
  # Use PROCESSOR_COUNT in your build process
  set(MAX_CONCURRENCY ${PROCESSOR_COUNT})
endif()
