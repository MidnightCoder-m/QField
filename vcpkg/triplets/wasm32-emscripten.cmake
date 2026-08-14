set(VCPKG_TARGET_ARCHITECTURE wasm32)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_CMAKE_SYSTEM_NAME Emscripten)
set(VCPKG_BUILD_TYPE release)
set(VCPKG_MAKE_BUILD_TRIPLET "--host=wasm32-unknown-emscripten")
set(VCPKG_ENV_PASSTHROUGH_UNTRACKED EMSDK EMSCRIPTEN PATH)

# Ports that build with make take CC and CXX from the environment, host values included.
if(DEFINED ENV{EMSDK})
  set(ENV{CC} "$ENV{EMSDK}/upstream/emscripten/emcc")
  set(ENV{CXX} "$ENV{EMSDK}/upstream/emscripten/em++")
endif()

# Replaces vcpkg's own emscripten toolchain, so the compile flags live there too.
set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${CMAKE_CURRENT_LIST_DIR}/../../cmake/EmscriptenToolchain.cmake")
