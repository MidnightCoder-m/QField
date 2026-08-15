#!/bin/bash
# Build QField for WebAssembly.
#
#   ./scripts/build-for-wasm.sh                    build
#   ./scripts/build-for-wasm.sh --serve            build, then serve on :8080
#   ./scripts/build-for-wasm.sh --serve-only       serve what is already built
#
# Arguments after --serve or --serve-only go to scripts/serve-wasm.py.
#
# QFIELD_BUILD_JOBS caps the parallelism, for a machine that has to stay usable.
set -e

ROOT=$(git rev-parse --show-toplevel)
BUILD_DIR="${ROOT}/build-wasm32-emscripten"
# Qt 6.10 names the Emscripten it was built against; another version gives ABI errors.
EMSDK_VERSION=4.0.7

if [ "${1:-}" = "--serve-only" ]; then
	exec python3 "${ROOT}/scripts/serve-wasm.py" "${BUILD_DIR}/output/bin" "${@:2}"
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

# vcpkg suffixes its caches per triplet, so a native build can share this checkout.
DEPS_DIR="${QFIELD_VCPKG_DEPS:-}"
if [ -z "${DEPS_DIR}" ]; then
	if [ -d "${ROOT}/build-x64-linux/_deps/vcpkg-src" ]; then
		DEPS_DIR="${ROOT}/build-x64-linux/_deps"
		echo "--- reusing the vcpkg checkout in ${DEPS_DIR}"
	else
		DEPS_DIR="${BUILD_DIR}/_deps"
	fi
fi

# In manifest mode vcpkg builds the ports during configure, so the cap has to be
# in the environment by then; ninja takes it again for QField's own targets.
NINJA_JOBS=()
if [ -n "${QFIELD_BUILD_JOBS:-}" ]; then
	export VCPKG_MAX_CONCURRENCY="${QFIELD_BUILD_JOBS}"
	NINJA_JOBS=(-j "${QFIELD_BUILD_JOBS}")
	echo "--- capped at ${QFIELD_BUILD_JOBS} parallel jobs"
fi

# vcpkg keys its binary cache on the host compiler: set CC and CXX as the native build did.
# The triplet names the chainload toolchain for the ports; QField itself needs it here too.
nice -n 10 cmake -S "${ROOT}" -B "${BUILD_DIR}" -GNinja \
	-DWITH_VCPKG=ON \
	-DVCPKG_TARGET_TRIPLET=wasm32-emscripten \
	-DVCPKG_HOST_TRIPLET="${VCPKG_HOST_TRIPLET:-x64-linux}" \
	-DVCPKG_CHAINLOAD_TOOLCHAIN_FILE="${ROOT}/cmake/EmscriptenToolchain.cmake" \
	-DFETCHCONTENT_BASE_DIR="${DEPS_DIR}" \
	-DCMAKE_BUILD_TYPE=Release

nice -n 10 cmake --build "${BUILD_DIR}" -- "${NINJA_JOBS[@]}"

echo
echo "Built ${BUILD_DIR}/output/bin/qfield.wasm"

if [ "${1:-}" = "--serve" ]; then
	exec python3 "${ROOT}/scripts/serve-wasm.py" "${BUILD_DIR}/output/bin" "${@:2}"
fi

echo "Serve it with: ./scripts/build-for-wasm.sh --serve-only"
