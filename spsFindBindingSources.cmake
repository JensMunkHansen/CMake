function(find_embinding_modules top_folder out_var)
    file(GLOB_RECURSE embinding_files
        RELATIVE "${top_folder}"
        "${top_folder}/**/vtk*Embinding.cxx"
    )

    set(result "")

    foreach(rel_path IN LISTS embinding_files)
        # Clear values before loop iteration
        unset(binding_name)
        unset(module_name)
        unset(abs_path)

        get_filename_component(dir_path "${rel_path}" DIRECTORY)
        get_filename_component(file_name "${rel_path}" NAME)

        message(STATUS "Checking: ${rel_path}")
        message(STATUS "  Dir path: ${dir_path}")
        message(STATUS "  File name: ${file_name}")

        string(REGEX MATCH "^vtk(.+)Embinding\\.cxx$" _ "${file_name}")
        if(NOT CMAKE_MATCH_1)
            message(WARNING "  --> File did not match vtkXXXEmbinding.cxx")
            continue()
        endif()

        set(binding_name "${CMAKE_MATCH_1}")
        message(STATUS "  --> Matched binding name: ${binding_name}")

        if(dir_path STREQUAL "")
            message(WARNING "  --> Skipping: no subdirectory")
            continue()
        endif()

        string(REPLACE "/" "" module_name "${dir_path}")
	# string(REPLACE "/" "_" module_name "${dir_path}")	
        get_filename_component(abs_path "${top_folder}/${rel_path}" ABSOLUTE)

        message(STATUS "  --> Module name: ${module_name}")
        message(STATUS "  --> ABSOLUTE PATH: ${abs_path}")

        list(APPEND result "${binding_name}" "${module_name}")
    endforeach()
    
    set(${out_var} "${result}" PARENT_SCOPE)
endfunction()


function(list_classes embindings module_name out_var)
    set(info "${${embindings}}")
    set(classes "")

    list(LENGTH info count)
    math(EXPR pair_count "${count} / 2")

    foreach(i RANGE 0 ${pair_count})
        math(EXPR name_index "${i} * 2")
        math(EXPR module_index "${name_index} + 1")

        if(module_index GREATER_EQUAL count)
            break()
        endif()

        list(GET info ${name_index} class_name)
        list(GET info ${module_index} mod_name)

        if("${mod_name}" STREQUAL "${module_name}")
            list(APPEND classes "vtk${class_name}")
        endif()
    endforeach()

    set(${out_var} "${classes}" PARENT_SCOPE)
endfunction()


function(class_module_lookup embindings class_name out_module_var)
    set(info "${${embindings}}")
    string(REGEX REPLACE "^vtk" "" class_key "${class_name}")

    list(LENGTH info count)
    math(EXPR pair_count "${count} / 2")

    foreach(i RANGE 0 ${pair_count})
        math(EXPR name_index "${i} * 2")
        math(EXPR module_index "${name_index} + 1")
        if(module_index GREATER_EQUAL count)
            break()
        endif()

        list(GET info ${name_index} name)
        list(GET info ${module_index} module)

        if("${name}" STREQUAL "${class_key}")
            set(${out_module_var} "${module}" PARENT_SCOPE)
            return()
        endif()
    endforeach()

    # If not found
    message(WARNING "Class ${class_name} not found in embinding info")
    set(${out_module_var} "" PARENT_SCOPE)
endfunction()
