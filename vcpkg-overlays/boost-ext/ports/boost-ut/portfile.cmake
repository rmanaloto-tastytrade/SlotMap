vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO boost-ext/ut
    REF v2.3.1
    SHA512 068ab84a28a41dfef27ad97b9be89ecacf4bdac7357fa865f5e7eecedbe9c4a1a8ced2e795b40943ec85d49a0427d8fc270582eba1b544bb9ecc261f95163a2b
    HEAD_REF master
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DBOOST_UT_BUILD_BENCHMARKS=OFF
        -DBOOST_UT_BUILD_EXAMPLES=OFF
        -DBOOST_UT_BUILD_TESTS=OFF
        -DBOOST_UT_ENABLE_INSTALL=ON
        -DBOOST_UT_DISABLE_MODULE=ON
)

vcpkg_cmake_install()

vcpkg_cmake_config_fixup(
    PACKAGE_NAME ut
    CONFIG_PATH lib/cmake/ut
)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")

vcpkg_install_copyright(
    FILE_LIST "${SOURCE_PATH}/LICENSE"
)
