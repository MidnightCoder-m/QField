# Chainloaded by the wasm32-emscripten triplet: every port needs these exact flags to link together.

if(NOT DEFINED ENV{EMSDK})
  message(FATAL_ERROR "EMSDK is not set. Source the emsdk_env.sh of an Emscripten SDK first, or use scripts/build-for-wasm.sh.")
endif()

set(EMSCRIPTEN_ROOT "$ENV{EMSDK}/upstream/emscripten")

# draco's portfile blanks this before configuring, so exporting it from the shell does not survive.
set(ENV{EMSCRIPTEN} "${EMSCRIPTEN_ROOT}")

if(DEFINED ENV{PKG_CONFIG_LIBDIR})
  set(_qfield_pkg_config_libdir "$ENV{PKG_CONFIG_LIBDIR}")
endif()

include("${EMSCRIPTEN_ROOT}/cmake/Modules/Platform/Emscripten.cmake")

# This sets PKG_CONFIG_LIBDIR to the wasm sysroot. vcpkg installs from inside QField's own
# configure, so its host ports would inherit that and miss the system libraries.
# CMakeLists.txt puts it back after project().
get_filename_component(_qfield_source_dir "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
if(CMAKE_SOURCE_DIR STREQUAL _qfield_source_dir)
  set(QFIELD_EMSCRIPTEN_PKG_CONFIG_LIBDIR "$ENV{PKG_CONFIG_LIBDIR}")
  if(DEFINED _qfield_pkg_config_libdir)
    set(ENV{PKG_CONFIG_LIBDIR} "${_qfield_pkg_config_libdir}")
  else()
    unset(ENV{PKG_CONFIG_LIBDIR})
  endif()
endif()

set(_qfield_wasm_flags "-pthread -fwasm-exceptions -sSUPPORT_LONGJMP=wasm")
string(APPEND CMAKE_C_FLAGS_INIT " ${_qfield_wasm_flags}")
string(APPEND CMAKE_CXX_FLAGS_INIT " ${_qfield_wasm_flags}")
