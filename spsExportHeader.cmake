get_filename_component(_ExportHeader_dir "${CMAKE_CURRENT_LIST_FILE}" DIRECTORY)

function(sps_generate_custom_export_header TARGET_NAME)
    if(NOT TARGET ${TARGET_NAME})
        message(FATAL_ERROR "Target '${TARGET_NAME}' does not exist!")
    endif()

    # Determine target type
    get_target_property(TARGET_TYPE ${TARGET_NAME} TYPE)

    set(visibility PUBLIC)
    if(TARGET_TYPE STREQUAL "INTERFACE_LIBRARY")
      set(visibility INTERFACE)
    endif()

    # Determine if we're building a WASM side module
    if(TARGET_TYPE STREQUAL "EXECUTABLE")
        set(IS_WASM TRUE)
    else()
        set(IS_WASM FALSE)
    endif()

    # Platform-specific export macros
    if(IS_WASM)
        set(EXPORT_MACRO "EMSCRIPTEN_KEEPALIVE")
        set(IMPORT_MACRO "EMSCRIPTEN_KEEPALIVE")
        set(EXTERN_C "extern \"C\"")
    elseif(WIN32)
        set(EXPORT_MACRO "__declspec(dllexport)")
        set(IMPORT_MACRO "__declspec(dllimport)")
        set(EXTERN_C "")
    else()
        # Linux/macOS use visibility attributes
        set(EXPORT_MACRO "__attribute__((visibility(\"default\")))")
        set(IMPORT_MACRO "")
        set(EXTERN_C "")
    endif()

    # Lowercase version of the target name for consistency
    string(TOLOWER "${TARGET_NAME}" TARGET_NAME_LOWER)

    # Handle Multi-Configuration Generators (e.g., Visual Studio, Ninja Multi-Config)
    if(CMAKE_CONFIGURATION_TYPES)
        # Multi-config generators: generate header per configuration
        foreach(CONFIG ${CMAKE_CONFIGURATION_TYPES})
            set(EXPORT_HEADER "${CMAKE_CURRENT_BINARY_DIR}/${CONFIG}/${TARGET_NAME_LOWER}_exports.h")
            configure_file(
                ${_ExportHeader_dir}/export_template.h.in
                ${EXPORT_HEADER}
                @ONLY)
        endforeach()
        # Use the build directory as include path
        target_include_directories(${TARGET_NAME} ${visibility} "$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/$<CONFIG>>")
    else()
        # Single-config generators
        set(EXPORT_HEADER "${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME_LOWER}_exports.h")
        configure_file(
          ${_ExportHeader_dir}/export_template.h.in
          ${EXPORT_HEADER}
          @ONLY)
        target_include_directories(${TARGET_NAME} ${visibility} ${CMAKE_CURRENT_BINARY_DIR})
    endif()

    message(STATUS "Generated export header for ${TARGET_NAME}: ${EXPORT_HEADER}")
endfunction()
