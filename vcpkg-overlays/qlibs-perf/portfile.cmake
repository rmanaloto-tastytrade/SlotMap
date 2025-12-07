vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO qlibs/perf
    REF d7647442cac441d0d8b2198b67a083e17c920828
    SHA512 4c7f71a5e81fc784bb0e42be5338e2a1d540308de0f92e3cd555805a23a838d702777a4561e600cef24a7a54113fa5e106eaccfc779d9d549ac9733b5ed8793e
    HEAD_REF main
)

vcpkg_check_linkage(ONLY_HEADER_LIBRARY)

# Install the header file
file(INSTALL "${SOURCE_PATH}/perf"
    DESTINATION "${CURRENT_PACKAGES_DIR}/include"
)

# Install the C++20 module file if it exists
if(EXISTS "${SOURCE_PATH}/perf.cppm")
    file(INSTALL "${SOURCE_PATH}/perf.cppm"
        DESTINATION "${CURRENT_PACKAGES_DIR}/include"
    )
endif()

# Install license
file(INSTALL "${SOURCE_PATH}/LICENSE"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
     RENAME copyright)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
