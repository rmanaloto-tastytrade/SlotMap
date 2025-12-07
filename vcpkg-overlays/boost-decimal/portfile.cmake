# boost-decimal: Header-only C++14 IEEE 754 Decimal Floating Point library from C++ Alliance
# https://github.com/cppalliance/decimal

vcpkg_check_linkage(ONLY_HEADER_LIBRARY)

# Clone from GitHub
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO cppalliance/decimal
    REF a600e8339265c475edc6df90fecb2eae5bb3dddc
    SHA512 f406a11111ee1e6e9d53ce5e8d0d1130e46f7f6c027f6de283e13467bff4d2486e856e1f42cbea60dc9f3e399e38e029f5f3ceb6e093f737a00db0e19bc00d4f
    HEAD_REF master
)

# Install the header files
file(INSTALL "${SOURCE_PATH}/include/"
    DESTINATION "${CURRENT_PACKAGES_DIR}/include"
    FILES_MATCHING PATTERN "*.hpp"
)

# Install license
file(INSTALL "${SOURCE_PATH}/LICENSE"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
    RENAME copyright
)
