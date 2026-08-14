#!/bin/bash
# Build QField for WebAssembly and, with --serve, run it.
#
#   ./scripts/build-for-wasm.sh                 build
#   ./scripts/build-for-wasm.sh --serve         build, then serve on :8080
#   ./scripts/build-for-wasm.sh --serve-only    serve what is already built
#
# Needs an Emscripten SDK. Point EMSDK at one, or let this install a private
# copy under .emsdk in the build directory. The version is not a preference:
# Qt 6.10 states which Emscripten it was built against, and mismatching gives
# obscure ABI and link errors rather than a clear message.
set -e

ROOT=$(git rev-parse --show-toplevel)
BUILD_DIR="${ROOT}/build-wasm32-emscripten"
EMSDK_VERSION=4.0.7

if [ "${1:-}" = "--serve-only" ]; then
	exec python3 "${ROOT}/scripts/serve-wasm.py" "${BUILD_DIR}/output/bin"
fi

if [ -z "${EMSDK:-}" ]; then
	EMSDK="${BUILD_DIR}/.emsdk"
	if [ ! -d "${EMSDK}" ]; then
		echo "--- installing Emscripten ${EMSDK_VERSION} into ${EMSDK}"
		git clone --depth 1 https://github.com/emscripten-core/emsdk.git "${EMSDK}"
		"${EMSDK}/emsdk" install "${EMSDK_VERSION}"
		"${EMSDK}/emsdk" activate "${EMSDK_VERSION}"
	fi
	export EMSDK
fi

# shellcheck disable=SC1091
source "${EMSDK}/emsdk_env.sh"

# A second vcpkg checkout costs 3 GB and a full host-tool bootstrap for nothing:
# buildtrees, packages and downloads are all suffixed per triplet, so a native
# build and this one share them without colliding. Set QFIELD_VCPKG_DEPS to
# choose a different one, or to this build's own directory to keep them apart.
DEPS_DIR="${QFIELD_VCPKG_DEPS:-}"
if [ -z "${DEPS_DIR}" ]; then
	if [ -d "${ROOT}/build-x64-linux/_deps/vcpkg-src" ]; then
		DEPS_DIR="${ROOT}/build-x64-linux/_deps"
		echo "--- reusing the vcpkg checkout in ${DEPS_DIR}"
	else
		DEPS_DIR="${BUILD_DIR}/_deps"
	fi
fi

# If the host compiler is a gcc pre-release, host-side ports can fail with an
# internal compiler error; CC and CXX are honoured here as everywhere else.
cmake -S "${ROOT}" -B "${BUILD_DIR}" -GNinja \
	-DWITH_VCPKG=ON \
	-DVCPKG_TARGET_TRIPLET=wasm32-emscripten \
	-DVCPKG_HOST_TRIPLET="${VCPKG_HOST_TRIPLET:-x64-linux}" \
	-DFETCHCONTENT_BASE_DIR="${DEPS_DIR}" \
	-DCMAKE_BUILD_TYPE=Release

cmake --build "${BUILD_DIR}"

echo
echo "Built ${BUILD_DIR}/output/bin/qfield.wasm"

if [ "${1:-}" = "--serve" ]; then
	exec python3 "${ROOT}/scripts/serve-wasm.py" "${BUILD_DIR}/output/bin"
fi

echo "Serve it with: ./scripts/build-for-wasm.sh --serve-only"
