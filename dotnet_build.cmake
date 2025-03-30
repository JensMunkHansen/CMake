# Args:
#   -DPROJ=...         path to .csproj
#   -DCONFIG=...       Debug / Release
#   -DOUTPUT=...       output directory

if(NOT DEFINED PROJ OR NOT DEFINED CONFIG OR NOT DEFINED OUTPUT)
  message(FATAL_ERROR "Missing required arguments")
endif()

# Optional: use project-local NuGet cache for isolation or reproducibility
set(NUGET_CACHE "${CMAKE_BINARY_DIR}/.nuget")

# execute_process(
#   COMMAND dotnet build "${PROJ}"
#           --configuration "${CONFIG}"
#           --output "${OUTPUT}"
#           --no-restore
#           -p:RestorePackagesPath=${NUGET_CACHE}
#   RESULT_VARIABLE result
# )
execute_process(
  COMMAND dotnet build "${PROJ}"
          --configuration "${CONFIG}"
          --output "${OUTPUT}"
  RESULT_VARIABLE result
)

# execute_process(
#   COMMAND dotnet build "${PROJ}" --configuration "${CONFIG}" --output "${OUTPUT}"
#   RESULT_VARIABLE result
# )

if(NOT result EQUAL 0)
  message(FATAL_ERROR "dotnet build failed with exit code ${result}")
endif()
