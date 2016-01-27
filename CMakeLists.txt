cmake_minimum_required(VERSION 2.8)

#///////////////////////////////////////////////////////////////////#
#                              PROJECT                              #
#///////////////////////////////////////////////////////////////////#

set(CLAN_VERSION_MAJOR 0)
set(CLAN_VERSION_MINOR 7)
set(CLAN_VERSION_PATCH 1)
set(PACKAGE_VERSION
    ${CLAN_VERSION_MAJOR}.${CLAN_VERSION_MINOR}.${CLAN_VERSION_PATCH})

project(clan
  LANGUAGES C CXX)

# Default to Debug build
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Debug) # Set "Release" otherwise
  message(STATUS "No building type advertised, default to Debug")
endif()

#///////////////////////////////////////////////////////////////////#
#                           DEPENDENCIES                            #
#///////////////////////////////////////////////////////////////////#

# Check functions avaliability
include(cmake/config-dep.cmake)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules")

find_package(OSL QUIET)
if(NOT OSL_FOUND)
  message (WARNING "Osl library not installed on your system\n"
    "Fallback by trying to clone the repository from source")
  find_package(Git REQUIRED)
  execute_process(COMMAND
    ${GIT_EXECUTABLE} submodule update --init --recursive
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    RESULT_VARIABLE OSL_SUBMODULE_UPDATE)
  if(NOT OSL_SUBMODULE_UPDATE EQUAL 0)
    message(FATAL_ERROR "Unable to clone osl, dependency not met")
  else()
    message(STATUS "OSL successfully cloned, configuring")
    add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/osl)
  endif()
else()
  message(STATUS "Found OSL ${OSL_VERSION}")
  if (NOT TARGET osl)
    add_library(osl INTERFACE IMPORTED)
    set_property(TARGET osl PROPERTY INTERFACE_INCLUDE_DIRECTORIES
      ${OSL_INCLUDE_DIRS})
    set_property(TARGET osl PROPERTY INTERFACE_LINK_LIBRARIES
      ${OSL_LIBRARIES})
  endif()
endif()

find_package(BISON REQUIRED)
find_package(FLEX REQUIRED)
set(BISON_EXTRA_COMPILE_FLAGS "-L c")
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/autogen/source)
BISON_TARGET(clan_parser
  source/parser.y ${CMAKE_CURRENT_BINARY_DIR}/autogen/source/parser.c
  COMPILE_FLAGS ${BISON_EXTRA_COMPILE_FLAGS})
FLEX_TARGET(clan_scanner
  source/scanner.l ${CMAKE_CURRENT_BINARY_DIR}/autogen/source/scanner.c)
ADD_FLEX_BISON_DEPENDENCY(clan_scanner clan_parser)
include_directories(${CMAKE_CURRENT_BINARY_DIR}/autogen)

#///////////////////////////////////////////////////////////////////#
#                        COMPILATION OPTIONS                        #
#///////////////////////////////////////////////////////////////////#

set(COMMON_C_FLAGS "-Wall -Wextra -std=c99 -pedantic")

set(CMAKE_C_FLAGS_RELEASE "${COMMON_C_FLAGS} -O3")
set(CMAKE_C_FLAGS_DEBUG "${COMMON_C_FLAGS} -O0 -g3")

# Use full RPATH on build tree
set(CMAKE_SKIP_BUILD_RPATH FALSE)
# Do not build with install RPATH
set(CMAKE_BUILD_WITH_INSTALL_RPATH FALSE)
# Set the RPATH when install
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
# Only set RPATH if the installation directory is not a system directory
LIST(FIND
  CMAKE_PLATFORM_IMPLICIT_LINK_DIRECTORIES "${CMAKE_INSTALL_PREFIX}/lib"
  isSystemDir)
if("${isSystemDir}" STREQUAL "-1")
  set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib")
else()
  set(CMAKE_INSTALL_RPATH "")
endif()

#///////////////////////////////////////////////////////////////////#
#                             SOURCES                               #
#///////////////////////////////////////////////////////////////////#

list(APPEND CURRENT_INCLUDE_DIRECTORIES
  "include/"
  "${CMAKE_CURRENT_BINARY_DIR}/autogen/include")

configure_file("${CMAKE_CURRENT_SOURCE_DIR}/include/clan/macros.h.in"
  "${CMAKE_CURRENT_BINARY_DIR}/autogen/include/clan/macros.h")

list(APPEND CLAN_LIBRARY_C_FILES
  ${CMAKE_CURRENT_SOURCE_DIR}/source/domain.c
  ${CMAKE_CURRENT_SOURCE_DIR}/source/options.c
  ${CMAKE_CURRENT_SOURCE_DIR}/source/relation.c
  ${CMAKE_CURRENT_SOURCE_DIR}/source/relation_list.c
  ${CMAKE_CURRENT_SOURCE_DIR}/source/scop.c
  ${CMAKE_CURRENT_SOURCE_DIR}/source/statement.c
  ${CMAKE_CURRENT_SOURCE_DIR}/source/symbol.c
  ${CMAKE_CURRENT_SOURCE_DIR}/source/vector.c)

list(APPEND CLAN_EXECUTABLE_C_FILES
  ${CMAKE_CURRENT_SOURCE_DIR}/source/clan.c)

#///////////////////////////////////////////////////////////////////#
#                             LIBRARIES                             #
#///////////////////////////////////////////////////////////////////#

add_library(clan
  SHARED
  ${CLAN_LIBRARY_C_FILES}
  ${BISON_clan_parser_OUTPUTS}
  ${FLEX_clan_scanner_OUTPUTS})
target_link_libraries(clan PUBLIC osl)
target_include_directories(clan
  PUBLIC
    include/
    "${CMAKE_CURRENT_BINARY_DIR}/autogen/include")
target_compile_definitions(clan
  PUBLIC
    _POSIX_C_SOURCE=200809L)

add_library(clan_static
  STATIC
  ${CLAN_LIBRARY_C_FILES}
  ${BISON_clan_parser_OUTPUTS}
  ${FLEX_clan_scanner_OUTPUTS})
set_target_properties(clan_static PROPERTIES OUTPUT_NAME "clan")
target_link_libraries(clan_static PUBLIC osl)
message(STATUS
  "Add clan library (static)"
  " ${CMAKE_STATIC_LIBRARY_PREFIX}clan${CMAKE_STATIC_LIBRARY_SUFFIX}")
target_include_directories(clan_static
  PUBLIC
    include/
    "${CMAKE_CURRENT_BINARY_DIR}/autogen/include")
target_compile_definitions(clan_static
  PUBLIC
    _POSIX_C_SOURCE=200809L)

#///////////////////////////////////////////////////////////////////#
#                            EXECUTABLE                             #
#///////////////////////////////////////////////////////////////////#

add_executable(clan_exe ${CLAN_EXECUTABLE_C_FILES})
set_target_properties(clan_exe PROPERTIES OUTPUT_NAME "clan")
target_link_libraries(clan_exe clan)

#///////////////////////////////////////////////////////////////////#
#                           DOCUMENTATION                           #
#///////////////////////////////////////////////////////////////////#

find_package(Doxygen)
if(DOXYGEN_FOUND)
  if(NOT TARGET doxygen)
    add_custom_target(doxygen)
  endif()
  set(top_srcdir "${CMAKE_CURRENT_SOURCE_DIR}")
  configure_file("${CMAKE_CURRENT_SOURCE_DIR}/doc/Doxyfile.in"
    "${CMAKE_CURRENT_BINARY_DIR}/autogen/Doxyfile")
  add_custom_target(
    clan-doxygen
    ${DOXYGEN_EXECUTABLE} ${CMAKE_CURRENT_BINARY_DIR}/autogen/Doxyfile
    WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
    COMMENT "Generating API documentation with Doxygen" VERBATIM)
  add_dependencies(doxygen clan-doxygen)
else()
  message (STATUS "Doxygen not found :( API documentation can not be built")
endif()

find_program(texi2pdf_exe texi2pdf)
if(texi2pdf_exe)
  if(NOT TARGET doc)
    add_custom_target(doc)
  endif()
  add_custom_target(
    clan-doc
    ${texi2pdf_exe} ${CMAKE_CURRENT_SOURCE_DIR}/doc/clan.texi
    --output=${CMAKE_CURRENT_BINARY_DIR}/clan.pdf
    WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
    COMMENT "Generating documentation (pdf) (with texi2pdf)" VERBATIM)
  add_dependencies(doc clan-doc)
else()
  message (STATUS "texi2pdf not found :( Documentation can not be built")
endif()

find_program(pdflatex_exe pdflatex)
if(pdflatex_exe)
  file(COPY ${CMAKE_CURRENT_SOURCE_DIR}/doc/reference_card DESTINATION ${CMAKE_CURRENT_BINARY_DIR})
  add_custom_target(
    ref_card
    ${pdflatex_exe} ${CMAKE_CURRENT_BINARY_DIR}/reference_card/reference_card.tex
    WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/reference_card"
    COMMENT "Generating Clan reference card (pdf) (with pdflatex)" VERBATIM)
else()
  message (STATUS "pdflatex not found =( Clan reference card can not be built")
endif()

#///////////////////////////////////////////////////////////////////#
#                               TEST                                #
#///////////////////////////////////////////////////////////////////#

find_package(PythonInterp 2 QUIET)
if (PYTHONINTERP_FOUND)

  enable_testing()

  file(
    GLOB_RECURSE
    TEST_FILES
    tests/*.c)

  foreach(test ${TEST_FILES})
    if("${test}" MATCHES "autoscop")
      add_test(
        ${test}
        "${CMAKE_CURRENT_SOURCE_DIR}/tests/check_source_result.py"
        "${test}"
        "${test}.scop"
        "${CMAKE_CURRENT_BINARY_DIR}/clan"
        "-autoscop")
    else()
      add_test(
        ${test}
        "${CMAKE_CURRENT_SOURCE_DIR}/tests/check_source_result.py"
        "${test}"
        "${test}.scop"
        "${CMAKE_CURRENT_BINARY_DIR}/clan")
    endif()
  endforeach()
endif()

#///////////////////////////////////////////////////////////////////#
#                             INSTALL                               #
#///////////////////////////////////////////////////////////////////#

install(TARGETS clan LIBRARY DESTINATION lib)
install(TARGETS clan_static ARCHIVE DESTINATION lib)
install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/include/"
  DESTINATION include FILES_MATCHING PATTERN "*.h")
install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/autogen/include/"
  DESTINATION include FILES_MATCHING PATTERN "*.h")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/autogen/source/parser.h" DESTINATION include/clan)
install(FILES clan-config.cmake DESTINATION lib/clan)
install(TARGETS clan_exe RUNTIME DESTINATION bin)

#///////////////////////////////////////////////////////////////////#
#                           USER INFOS                              #
#///////////////////////////////////////////////////////////////////#

message(STATUS "")
message(STATUS "************************* CLAN *************************")
message(STATUS "")
message(STATUS "Configuration done.")
if (CMAKE_BUILD_TYPE MATCHES Release)
  message(STATUS "Build type is Release")
  message(STATUS "C compiler = ${CMAKE_C_COMPILER}")
  message(STATUS "C flags    = ${CMAKE_C_FLAGS_RELEASE}")
else()
  message(STATUS "Build type is Debug (default see CMAKE_BUILD_TYPE)")
  message(STATUS "C compiler = ${CMAKE_C_COMPILER}")
  message(STATUS "C flags    = ${CMAKE_C_FLAGS_DEBUG}")
endif()

message(STATUS "")
message(STATUS "You can execute:")
message(STATUS "    make          # To compile clan library & clan")
if (PYTHONINTERP_FOUND)
  message(STATUS "    make test     # To execute tests")
endif()
message(STATUS "    make install  # To install library, include and CMake module")
message(STATUS "                  # If you need root access:")
message(STATUS "                  #     sudo make install")
message(STATUS "                  #     su -c \"make install\"")
if(DOXYGEN_FOUND)
  message(STATUS "    make doxygen  # To generate the Doxygen")
endif()
if(texi2pdf_exe)
  message(STATUS "    make doc      # To generate the documentation")
endif()
if(pdflatex_exe)
  message(STATUS "    make ref_card # To generate Clan reference card")
endif()
message(STATUS "")
message(STATUS "******************************************************")
message(STATUS "")
