message(WARNING "qtkeychain is a third-party extension to Qt and is not affiliated with The Qt Company")

if(VCPKG_TARGET_IS_IOS)
    vcpkg_from_github(
        OUT_SOURCE_PATH SOURCE_PATH
        REPO frankosterfeld/qtkeychain
        REF "0.14.3"
        SHA512 d1d87553db94bf54da1373016a847476e6cd608db6d427ed72532658e2272501daf45d7c9976efdde2f26ab3810ba9dbfec2518d46dee5a76ecaa369bfee2e4a
        HEAD_REF master
    )
else()
    # QtKeychain treats emscripten as a plain unix and demands Qt6DBus, and has no backend for it.
    if(VCPKG_TARGET_IS_EMSCRIPTEN)
        set(QTKEYCHAIN_PATCHES emscripten.patch)
    endif()

    vcpkg_from_github(
        OUT_SOURCE_PATH SOURCE_PATH
        REPO frankosterfeld/qtkeychain
        REF "${VERSION}"
        SHA512 b1068ae513d5eab8f300186497ddcce4075e11a2a569deddbc949177efaa27970ed7bdce0b1aff61a021144540e942f60c9259b975601a92c60b8a742754624a
        HEAD_REF master
        PATCHES ${QTKEYCHAIN_PATCHES}
    )

    if(VCPKG_TARGET_IS_EMSCRIPTEN)
        file(COPY "${CMAKE_CURRENT_LIST_DIR}/keychain_emscripten.cpp" DESTINATION "${SOURCE_PATH}/qtkeychain")
    endif()
endif()

if(VCPKG_CROSSCOMPILING)
   list(APPEND QTKEYCHAIN_OPTIONS -DQT_HOST_PATH=${CURRENT_HOST_INSTALLED_DIR})
   list(APPEND QTKEYCHAIN_OPTIONS -DQT_HOST_PATH_CMAKE_DIR:PATH=${CURRENT_HOST_INSTALLED_DIR}/share)
   # remove when https://github.com/microsoft/vcpkg/pull/16111 is merged
   if(VCPKG_TARGET_ARCHITECTURE STREQUAL arm64 AND VCPKG_TARGET_IS_WINDOWS)
       list(APPEND QTKEYCHAIN_OPTIONS -DCMAKE_CROSSCOMPILING=ON -DCMAKE_SYSTEM_PROCESSOR:STRING=ARM64 -DCMAKE_SYSTEM_NAME:STRING=Windows)
   endif()
endif()

list(APPEND QTKEYCHAIN_OPTIONS -DBUILD_TEST_APPLICATION:BOOL=OFF)

if(VCPKG_TARGET_IS_EMSCRIPTEN)
    # include(CTest) builds the autotests anyway, and they fail on embind's _emval_* symbols.
    list(APPEND QTKEYCHAIN_OPTIONS -DBUILD_TESTING:BOOL=OFF)
endif()
list(APPEND QTKEYCHAIN_OPTIONS -DLIBSECRET_SUPPORT:BOOL=OFF)

# FIXME: Why does build translations fail on arm64-windows?
if (VCPKG_TARGET_IS_WINDOWS AND VCPKG_TARGET_ARCHITECTURE STREQUAL arm64)
     list(APPEND QTKEYCHAIN_OPTIONS -DBUILD_TRANSLATIONS:BOOL=OFF)
else()
     list(APPEND QTKEYCHAIN_OPTIONS -DBUILD_TRANSLATIONS:BOOL=ON)
endif()

vcpkg_cmake_configure(
    DISABLE_PARALLEL_CONFIGURE
    SOURCE_PATH ${SOURCE_PATH}
    OPTIONS
        -DBUILD_WITH_QT6=ON
         ${QTKEYCHAIN_OPTIONS}
)
vcpkg_cmake_install()

vcpkg_copy_pdbs()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/Qt6Keychain PACKAGE_NAME Qt6Keychain)

# Remove unneeded dirs
file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

# Handle copyright
file(INSTALL "${SOURCE_PATH}/COPYING" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
