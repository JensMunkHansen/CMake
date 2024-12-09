# Define a reusable function for getting processor count and other hardware info
function(sps_get_processor_count OUTPUT_VAR MAX_CONCURRENCY_VAR)
  if (UNIX)
    # Execute a system command to get the processor count
    execute_process(COMMAND nproc OUTPUT_VARIABLE PROCESSOR_COUNT OUTPUT_STRIP_TRAILING_WHITESPACE)

    # Fallback if the result is empty
    if (PROCESSOR_COUNT STREQUAL "")
      message(WARNING "Processor count could not be determined. Defaulting to 1.")
      set(PROCESSOR_COUNT 1)
    endif()
    
    message(STATUS "Detected ${PROCESSOR_COUNT} processors.")
  else()
    include(ProcessorCount)

    # Get the processor count
    ProcessorCount(PROCESSOR_COUNT)

    # Check if processor count was successfully retrieved
    if (PROCESSOR_COUNT EQUAL 0)
      message(WARNING "Processor count could not be determined. Defaulting to 1.")
      set(PROCESSOR_COUNT 1)
    else()
      message(STATUS "Detected ${PROCESSOR_COUNT} processors.")
    endif()
  endif()

  # Assign outputs to the provided variables
  set(${OUTPUT_VAR} ${PROCESSOR_COUNT} PARENT_SCOPE)
  set(${MAX_CONCURRENCY_VAR} ${PROCESSOR_COUNT} PARENT_SCOPE)
endfunction()
