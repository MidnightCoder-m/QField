# Chainloaded by the wasm32-emscripten triplet: every port needs these exact flags to link together.

if(NOT DEFINED ENV{EMSDK})
  message(FATAL_ERROR "EMSDK is not set. Source the emsdk_env.sh of an Emscripten SDK first, or use scripts/build-for-wasm.sh.")
endif()

set(EMSCRIPTEN_ROOT "$ENV{EMSDK}/upstream/emscripten")

# draco's portfile blanks this before configuring, so exporting it from the shell does not survive.
set(ENV{EMSCRIPTEN} "${EMSCRIPTEN_ROOT}")

include("${EMSCRIPTEN_ROOT}/cmake/Modules/Platform/Emscripten.cmake")

set(_qfield_wasm_flags "-pthread -fwasm-exceptions -sSUPPORT_LONGJMP=wasm")
string(APPEND CMAKE_C_FLAGS_INIT " ${_qfield_wasm_flags}")
string(APPEND CMAKE_CXX_FLAGS_INIT " ${_qfield_wasm_flags}")
