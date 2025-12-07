vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO intel/cpp-std-extensions
    REF 2377309abaafaa8801c5410c3ffbb3fe8d0e026c
    SHA512 7443ab0c52f1e87db42324db28ab8f45329c8473f9573f517e6a192886ae24d80593dbc6beb0f4df9522e858a8c3785bc18ccaf7b68494dbe4b8aff48daab981
    HEAD_REF main
)

# Header-only library - just install the include directory
file(INSTALL "${SOURCE_PATH}/include/" DESTINATION "${CURRENT_PACKAGES_DIR}/include")

file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
