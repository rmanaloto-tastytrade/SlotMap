vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO intel/compile-time-init-build
    REF 2c5032296d164c75565d3151159ca2a946337630
    SHA512 d3b82b93ea2274b4f7a6ca3e562283533c8ad5fdc51909b85f6ed9e33ac7deadbd77f975c15ebe029e074f62e71727d9aef5ee1ee55b9a08e059a29329b4cf00
    HEAD_REF main
)

# Header-only library - install the include directory
file(INSTALL "${SOURCE_PATH}/include/" DESTINATION "${CURRENT_PACKAGES_DIR}/include")

# Install Python tools for string catalog generation
file(INSTALL "${SOURCE_PATH}/tools/gen_str_catalog.py"
     DESTINATION "${CURRENT_PACKAGES_DIR}/tools"
     FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)

file(INSTALL "${SOURCE_PATH}/tools/gen_str_catalog_test.py"
     DESTINATION "${CURRENT_PACKAGES_DIR}/tools")

file(INSTALL "${SOURCE_PATH}/tools/requirements.txt"
     DESTINATION "${CURRENT_PACKAGES_DIR}/tools")

# Install CMake modules for string catalog integration
file(INSTALL "${SOURCE_PATH}/cmake/string_catalog.cmake"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/cmake")

file(INSTALL "${SOURCE_PATH}/cmake/debug_flow.cmake"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/cmake")

# Create a CMake config file that consumers can use
file(WRITE "${CURRENT_PACKAGES_DIR}/share/${PORT}/compile-time-init-build-config.cmake" "
# compile-time-init-build CMake configuration
include(\${CMAKE_CURRENT_LIST_DIR}/cmake/string_catalog.cmake)
include(\${CMAKE_CURRENT_LIST_DIR}/cmake/debug_flow.cmake)

# Set path to Python tools
set(GEN_STR_CATALOG \${CMAKE_CURRENT_LIST_DIR}/../../tools/gen_str_catalog.py CACHE FILEPATH \"Location of string catalog generator\")
")

file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
