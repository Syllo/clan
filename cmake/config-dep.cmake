include(CheckSymbolExists)
include(CheckFunctionExists)

set(CMAKE_REQUIRED_DEFINITIONS "-D_POSIX_C_SOURCE=200809L")

check_symbol_exists("fileno" "stdio.h" HAVE_FILENO)
check_symbol_exists("strdup" "string.h" HAVE_STRDUP)


check_function_exists("fileno" HAVE_FUN_FILENO)
check_function_exists("strdup" HAVE_FUN_STRDUP)

if(NOT HAVE_FILENO OR NOT HAVE_FUN_FILENO)
  message(FATAL_ERROR "Function fileno() required")
endif()

if(NOT HAVE_STRDUP OR NOT HAVE_FUN_STRDUP )
  message(FATAL_ERROR "Function open_memstream() required")
endif()
