# boost-int128: Header-only C++ 128-bit integer library from C++ Alliance
# https://github.com/cppalliance/int128

vcpkg_check_linkage(ONLY_HEADER_LIBRARY)

# Clone from GitHub
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO cppalliance/int128
    REF 80fa4ae5266e8f2db641d0e1bdbf3b65ee400e65
    SHA512 de5d23126f288e15beabd6877b1fd9eb179c3edf25d4ea5da8a5318c6939cff46282544e1aa81e22811300a1e2716e42e041d3bd258323d2ba67825b674ff496
    HEAD_REF master
)

# Install the header file
file(INSTALL "${SOURCE_PATH}/include/"
    DESTINATION "${CURRENT_PACKAGES_DIR}/include"
    FILES_MATCHING PATTERN "*.hpp"
)

# Install license
file(INSTALL "${SOURCE_PATH}/LICENSE"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
    RENAME copyright
)
