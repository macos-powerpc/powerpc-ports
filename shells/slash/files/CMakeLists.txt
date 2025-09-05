cmake_minimum_required(VERSION 3.16)
project(slash VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(PkgConfig REQUIRED)
find_package(OpenSSL REQUIRED)

pkg_check_modules(LIBGIT2 REQUIRED libgit2)

find_package(Boost REQUIRED COMPONENTS regex)

find_package(nlohmann_json REQUIRED)

add_executable(slash
    src/main.cpp
    src/core/exiter.h
    src/core/exiter.cpp
    src/core/jobs.cpp
    src/core/jobs.h
    src/builtin-cmds/help.h
    src/builtin-cmds/help.cpp
    src/builtin-cmds/jobs.h
    src/core/cnf.h
    src/core/cnf.cpp
    src/builtin-cmds/jobs.cpp
    src/builtin-cmds/slash-greeting.h
    src/builtin-cmds/slash-greeting.cpp
    src/core/execution.h
    src/core/execution.cpp
    src/core/prompt.cpp
    src/core/prompt.h
    src/core/startup.h
    src/core/startup.cpp
    src/abstractions/definitions.h
    src/abstractions/iofuncs.cpp
    src/abstractions/iofuncs.h
    src/abstractions/info.cpp
    src/abstractions/info.h
    src/abstractions/json.cpp
    src/abstractions/json.h
    src/git/git.cpp
    src/git/git.h
    src/builtin-cmds/cd.cpp
    src/builtin-cmds/cd.h
    src/core/parser.cpp
    src/core/parser.h
    src/builtin-cmds/var.cpp
    src/builtin-cmds/var.h
    src/builtin-cmds/alias.cpp
    src/builtin-cmds/alias.h
    src/cmd_highlighter.h
    src/cmd_highlighter.cpp
    src/help_helper.cpp
    src/help_helper.h
)

target_link_libraries(slash PRIVATE
    git2
    Boost::regex
    nlohmann_json::nlohmann_json
)

target_include_directories(slash PRIVATE
    ${LIBGIT2_INCLUDE_DIRS}
)

target_compile_options(slash PRIVATE ${LIBGIT2_CFLAGS_OTHER})

set(SLASHUTILS_SOURCES
    src/abstractions/iofuncs.cpp
    src/abstractions/info.cpp
    src/help_helper.cpp
    src/cmd_highlighter.cpp
    src/abstractions/json.cpp
    src/tui/tui.cpp
    src/git/git.cpp
)

add_library(slashutils SHARED ${SLASHUTILS_SOURCES})

target_link_libraries(slashutils PRIVATE
    git2
    OpenSSL::SSL
    OpenSSL::Crypto
    nlohmann_json::nlohmann_json
)

target_include_directories(slashutils PRIVATE
    ${LIBGIT2_INCLUDE_DIRS}
)

target_compile_options(slashutils PRIVATE ${LIBGIT2_CFLAGS_OTHER})

if(APPLE)
    set_target_properties(slashutils PROPERTIES
        INSTALL_NAME_DIR "${CMAKE_INSTALL_PREFIX}/lib/slash"
        MACOSX_RPATH ON
    )
endif()

# listen.cpp dropped due to linuxisms
set(SLASH_UTILS_LIST
    acart ansi cmsh datetime dump eol move perms
    ascii create del echo fnd ls clear csv disku encode
    mkdir pager sumcheck textmt netinfo ren rf srch md
)

set(SLASH_UTILS_TO_INSTALL)

foreach(util ${SLASH_UTILS_LIST})
    set(util_source "${CMAKE_CURRENT_SOURCE_DIR}/src/slash-utils/${util}.cpp")

    if(EXISTS "${util_source}")
        add_executable(${util} ${util_source})

        target_link_libraries(${util} PRIVATE slashutils)

        if(${util} STREQUAL "ls" OR ${util} STREQUAL "rf")
            target_link_libraries(${util} PRIVATE git2)
        endif()

        if(${util} STREQUAL "sumcheck")
            target_link_libraries(${util} PRIVATE OpenSSL::SSL OpenSSL::Crypto)
        endif()

        if(APPLE)
            set_target_properties(${util} PROPERTIES
                INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib/slash"
                MACOSX_RPATH ON
                BUILD_WITH_INSTALL_RPATH FALSE
            )
        else()
            set_target_properties(${util} PROPERTIES
                INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib/slash"
                BUILD_WITH_INSTALL_RPATH FALSE
            )
        endif()

        target_include_directories(${util} PRIVATE
            ${CMAKE_CURRENT_SOURCE_DIR}/src
            ${LIBGIT2_INCLUDE_DIRS}
        )

        target_compile_options(${util} PRIVATE ${LIBGIT2_CFLAGS_OTHER})

        list(APPEND SLASH_UTILS_TO_INSTALL ${util})

        message(STATUS "Added slash-utils executable: ${util}")
    else()
        message(WARNING "Source file for utility ${util} not found at ${util_source}, skipping...")
    endif()
endforeach()

if(SLASH_UTILS_TO_INSTALL)
    add_dependencies(${SLASH_UTILS_TO_INSTALL} slashutils)
endif()

install(TARGETS slash
    RUNTIME DESTINATION bin
    COMPONENT main
)

install(TARGETS slashutils
    LIBRARY DESTINATION lib/slash
    COMPONENT libraries
)

if(SLASH_UTILS_TO_INSTALL)
    install(TARGETS ${SLASH_UTILS_TO_INSTALL}
        RUNTIME DESTINATION libexec/slash
        COMPONENT utilities
    )

    message(STATUS "Will install ${list_length} slash-utils: ${SLASH_UTILS_TO_INSTALL}")
endif()

install(CODE "
    message(STATUS \"Slash installation completed!\")
    message(STATUS \"Main binary installed to: \${CMAKE_INSTALL_PREFIX}/bin/\")
    message(STATUS \"Utilities library installed to: \${CMAKE_INSTALL_PREFIX}/lib/slash/\")
    message(STATUS \"Utilities installed to: \${CMAKE_INSTALL_PREFIX}/libexec/slash/\")
    message(STATUS \"\")
    message(STATUS \"To complete setup, a user should run:\")
    message(STATUS \"  \${CMAKE_INSTALL_PREFIX}/share/slash/slash\")
    message(STATUS \"\")
    message(STATUS \"Add \${CMAKE_INSTALL_PREFIX}/libexec/slash to your PATH to use slash utilities.\")
")
