cmake_minimum_required(VERSION 3.28)

project(
    SlotMap
    VERSION 0.1.0
    LANGUAGES CXX
)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Build options
option(SLOTMAP_BUILD_TESTS "Build SlotMap unit tests" ON)
option(SLOTMAP_BUILD_DOCS "Enable documentation targets" ON)
option(SLOTMAP_ENABLE_WARNINGS_AS_ERRORS "Treat warnings as errors" ON)

# LTO options
option(SLOTMAP_ENABLE_LTO "Enable Link Time Optimization" OFF)
option(SLOTMAP_ENABLE_THIN_LTO "Use ThinLTO instead of full LTO" ON)

# Static analysis options
option(SLOTMAP_ENABLE_CLANG_TIDY "Enable clang-tidy static analysis" OFF)
option(SLOTMAP_ENABLE_IWYU "Enable include-what-you-use" OFF)

# BOLT profiling options
option(SLOTMAP_ENABLE_BOLT_INSTRUMENTATION "Build with BOLT instrumentation" OFF)
option(SLOTMAP_ENABLE_BOLT_OPTIMIZATION "Build with BOLT optimization (requires profile data)" OFF)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Configure LTO
if(SLOTMAP_ENABLE_LTO)
    include(CheckIPOSupported)
    check_ipo_supported(RESULT lto_supported OUTPUT lto_error)
    if(lto_supported)
        set(CMAKE_INTERPROCEDURAL_OPTIMIZATION ON)
        if(SLOTMAP_ENABLE_THIN_LTO AND CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
            # ThinLTO provides faster link times with similar optimization benefits
            add_compile_options(-flto=thin)
            add_link_options(-flto=thin)
            message(STATUS "ThinLTO enabled")
        else()
            message(STATUS "Full LTO enabled")
        endif()
    else()
        message(WARNING "LTO requested but not supported: ${lto_error}")
    endif()
endif()

# Configure clang-tidy
if(SLOTMAP_ENABLE_CLANG_TIDY)
    find_program(CLANG_TIDY_EXE NAMES clang-tidy-21 clang-tidy)
    if(CLANG_TIDY_EXE)
        set(CMAKE_CXX_CLANG_TIDY
            ${CLANG_TIDY_EXE}
            --config-file=${CMAKE_SOURCE_DIR}/.clang-tidy
        )
        message(STATUS "clang-tidy enabled: ${CLANG_TIDY_EXE}")
    else()
        message(WARNING "clang-tidy requested but not found")
    endif()
endif()

# Configure include-what-you-use
if(SLOTMAP_ENABLE_IWYU)
    find_program(IWYU_EXE NAMES include-what-you-use iwyu)
    if(IWYU_EXE)
        set(CMAKE_CXX_INCLUDE_WHAT_YOU_USE
            ${IWYU_EXE}
            -Xiwyu --mapping_file=${CMAKE_SOURCE_DIR}/.iwyu.imp
            -Xiwyu --no_fwd_decls
            -Xiwyu --cxx17ns
        )
        message(STATUS "include-what-you-use enabled: ${IWYU_EXE}")
    else()
        message(WARNING "include-what-you-use requested but not found")
    endif()
endif()

# Configure BOLT instrumentation
if(SLOTMAP_ENABLE_BOLT_INSTRUMENTATION)
    # BOLT requires relocation information for rewriting
    # -Wl,--emit-relocs preserves relocations in the binary for BOLT
    # -fno-function-sections ensures functions aren't split (BOLT requirement)
    add_link_options(-Wl,--emit-relocs -Wl,-znow)
    message(STATUS "BOLT instrumentation enabled - binary will be ready for llvm-bolt")
    message(STATUS "  After building, run: llvm-bolt-21 <binary> -instrument -o <binary>.instr")
    message(STATUS "  Then run instrumented binary to generate profile data")
    message(STATUS "  Finally: llvm-bolt-21 <binary> -o <binary>.bolt -data=<profile.fdata>")
endif()

# Configure BOLT optimization (applied via external tool, this just documents the workflow)
if(SLOTMAP_ENABLE_BOLT_OPTIMIZATION)
    message(STATUS "BOLT optimization mode - ensure profile data exists at ${CMAKE_BINARY_DIR}/bolt.fdata")
endif()

# clang-format target for code formatting
find_program(CLANG_FORMAT_EXE NAMES clang-format-21 clang-format)
if(CLANG_FORMAT_EXE)
    file(GLOB_RECURSE ALL_SOURCE_FILES
        ${CMAKE_SOURCE_DIR}/include/*.hpp
        ${CMAKE_SOURCE_DIR}/include/*.h
        ${CMAKE_SOURCE_DIR}/src/*.cpp
        ${CMAKE_SOURCE_DIR}/src/*.hpp
        ${CMAKE_SOURCE_DIR}/tests/*.cpp
        ${CMAKE_SOURCE_DIR}/tests/*.hpp
    )

    add_custom_target(format
        COMMAND ${CLANG_FORMAT_EXE} -i -style=file ${ALL_SOURCE_FILES}
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Running clang-format on all source files"
        VERBATIM
    )

    add_custom_target(format-check
        COMMAND ${CLANG_FORMAT_EXE} --dry-run --Werror -style=file ${ALL_SOURCE_FILES}
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Checking code formatting with clang-format"
        VERBATIM
    )

    message(STATUS "clang-format enabled: ${CLANG_FORMAT_EXE}")
    message(STATUS "  Use 'cmake --build <build-dir> --target format' to format code")
    message(STATUS "  Use 'cmake --build <build-dir> --target format-check' to check formatting")
endif()

add_library(slotmap INTERFACE)
target_include_directories(
    slotmap
    INTERFACE
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
)
target_compile_features(slotmap INTERFACE cxx_std_23)

set(common_warnings
    -Wall
    -Wextra
    -Wshadow
    -Wconversion
    -Wpedantic
    -Wnon-virtual-dtor
    -Wold-style-cast
    -Woverloaded-virtual
    -Wnull-dereference
    -Wdouble-promotion
    -Wformat=2
)

if(CMAKE_CXX_COMPILER_ID STREQUAL "Clang" OR CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    target_compile_options(slotmap INTERFACE ${common_warnings})
    if(SLOTMAP_ENABLE_WARNINGS_AS_ERRORS)
        target_compile_options(slotmap INTERFACE -Werror)
    endif()
elseif(MSVC)
    target_compile_options(slotmap INTERFACE /W4)
    if(SLOTMAP_ENABLE_WARNINGS_AS_ERRORS)
        target_compile_options(slotmap INTERFACE /WX)
    endif()
endif()

target_compile_definitions(
    slotmap
    INTERFACE
        $<$<CONFIG:Debug>:SLOTMAP_DEBUG=1>
)

if(SLOTMAP_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()

if(SLOTMAP_BUILD_DOCS)
    find_program(MRDOCS_EXECUTABLE NAMES mrdocs REQUIRED)
    find_program(DOXYGEN_EXECUTABLE NAMES doxygen REQUIRED)

    add_custom_target(
        docs
        COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/scripts/generate_docs.sh
            --source ${CMAKE_CURRENT_SOURCE_DIR}
            --build ${CMAKE_BINARY_DIR}/docs
            --mrdocs ${MRDOCS_EXECUTABLE}
            --doxygen ${DOXYGEN_EXECUTABLE}
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        COMMENT "Generating SlotMap reference documentation"
        VERBATIM
    )
endif()
