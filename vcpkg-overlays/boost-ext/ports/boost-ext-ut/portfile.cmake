set(SOURCE_PATH ${CURRENT_PORT_DIR}/files)

file(INSTALL
    ${SOURCE_PATH}/include
    DESTINATION ${CURRENT_PACKAGES_DIR}
)

file(MAKE_DIRECTORY ${CURRENT_PACKAGES_DIR}/share/${PORT})

# Create CMake config file for find_package support
file(WRITE ${CURRENT_PACKAGES_DIR}/share/${PORT}/boost-ext-ut-config.cmake
[=[
if(NOT TARGET boost-ext-ut::ut)
    add_library(boost-ext-ut::ut INTERFACE IMPORTED)
    set_target_properties(boost-ext-ut::ut PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${_VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/include"
    )
endif()
]=])

configure_file(
    ${CURRENT_PORT_DIR}/usage
    ${CURRENT_PACKAGES_DIR}/share/${PORT}/usage
    @ONLY
)

# Skip copyright check since this is BSL-1.0 embedded in header
set(VCPKG_POLICY_SKIP_COPYRIGHT_CHECK enabled)
