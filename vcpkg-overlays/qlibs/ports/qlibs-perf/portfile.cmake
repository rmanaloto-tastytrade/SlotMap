set(SOURCE_PATH ${CURRENT_PORT_DIR}/files)

file(INSTALL
    ${SOURCE_PATH}/include
    DESTINATION ${CURRENT_PACKAGES_DIR}
)

file(MAKE_DIRECTORY ${CURRENT_PACKAGES_DIR}/share/${PORT})

# Create CMake config file for find_package support
file(WRITE ${CURRENT_PACKAGES_DIR}/share/${PORT}/qlibs-perf-config.cmake
[=[
if(NOT TARGET qlibs::perf)
    add_library(qlibs::perf INTERFACE IMPORTED)
    set_target_properties(qlibs::perf PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${_VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/include"
    )
endif()
]=])

configure_file(
    ${CURRENT_PORT_DIR}/usage
    ${CURRENT_PACKAGES_DIR}/share/${PORT}/usage
    @ONLY
)

# Skip copyright check since license is embedded in header
set(VCPKG_POLICY_SKIP_COPYRIGHT_CHECK enabled)
