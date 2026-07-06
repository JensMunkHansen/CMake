function (sps_set_intersection setA setB OutVariable)
  list(APPEND A_minus_B ${setA})
  list(REMOVE_ITEM A_minus_B ${setB})
  list(APPEND B_minus_A ${setB})
  list(REMOVE_ITEM B_minus_A ${setA})
  
  # Symmetric difference
  list(APPEND A_sym_B ${B_minus_A} ${A_minus_B})
  list(REMOVE_DUPLICATES A_sym_B)

  # Union
  list(APPEND A_or_B ${setA} ${setB})
  list(REMOVE_DUPLICATES A_or_B)

  # Intersection
  set(result)
  list(APPEND result ${A_or_B})
  list(REMOVE_ITEM result ${A_sym_B})

  if ("${${OutVariable}}" STREQUAL "")
    set(${OutVariable} ${result} PARENT_SCOPE)
  else()
    set(${OutVariable} "${${OutVariable}}" "${result}" PARENT_SCOPE)
  endif ()
endfunction()
