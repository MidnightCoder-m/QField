#!/bin/bash
set -e

ROOT=$(git rev-parse --show-toplevel)
BUILD_DIR="${ROOT}/build-wasm32-emscripten"
source "${EMSDK:?point EMSDK at an emsdk with 4.0.7 activated}/emsdk_env.sh"

DEPS_DIR="${BUILD_DIR}/_deps"
if [ -d "${ROOT}/build-x64-linux/_deps/vcpkg-src" ]; then
	DEPS_DIR="${ROOT}/build-x64-linux/_deps"
fi

cmake -S "${ROOT}" -B "${BUILD_DIR}" -GNinja \
	-DWITH_VCPKG=ON \
	-DVCPKG_TARGET_TRIPLET=wasm32-emscripten \
	-DVCPKG_HOST_TRIPLET="${VCPKG_HOST_TRIPLET:-x64-linux}" \
	-DVCPKG_CHAINLOAD_TOOLCHAIN_FILE="${ROOT}/cmake/EmscriptenToolchain.cmake" \
	-DFETCHCONTENT_BASE_DIR="${DEPS_DIR}" \
	-DCMAKE_BUILD_TYPE=Release

cmake --build "${BUILD_DIR}"

if [ "${1:-}" = "--serve" ]; then
	exec emrun --no-browser --hostname localhost --port 8080 "${BUILD_DIR}/output/bin/qfield.html"
fi
