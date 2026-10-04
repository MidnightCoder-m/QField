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
	if [ ! -x "${EMSDK}/emsdk" ]; then
		rm -rf "${EMSDK}"
		git clone --depth 1 https://github.com/emscripten-core/emsdk.git "${EMSDK}"
	fi
	# Checked on every run, so an interrupted install or a version bump gets finished.
	if [ ! -f "${EMSDK}/.emscripten" ] ||
		! grep -qx "\"${EMSDK_VERSION}\"" "${EMSDK}/upstream/emscripten/emscripten-version.txt" 2>/dev/null; then
		echo "--- installing Emscripten ${EMSDK_VERSION} into ${EMSDK}"
		"${EMSDK}/emsdk" install "${EMSDK_VERSION}"
		"${EMSDK}/emsdk" activate "${EMSDK_VERSION}"
	fi
	export EMSDK
fi

if [ ! -f "${EMSDK}/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake" ]; then
	echo "No Emscripten in ${EMSDK}: run '${EMSDK}/emsdk install ${EMSDK_VERSION}' and activate it." >&2
	exit 1
fi

# shellcheck disable=SC1091
source "${EMSDK}/emsdk_env.sh"

# vcpkg suffixes its caches per triplet, so a native build can share this checkout.
DEPS_DIR="${QFIELD_VCPKG_DEPS:-}"
if [ -z "${DEPS_DIR}" ]; then
	if [ -d "${ROOT}/build-x64-linux/_deps/vcpkg-src" ]; then
		DEPS_DIR="${ROOT}/build-x64-linux/_deps"
		echo "--- reusing the vcpkg checkout in ${DEPS_DIR}"
		# vcpkg keys its binary cache on the host compiler, so take the one the native build used.
		NATIVE_CACHE="${ROOT}/build-x64-linux/CMakeCache.txt"
		if [ -z "${CC:-}${CXX:-}" ] && [ -f "${NATIVE_CACHE}" ]; then
			CC=$(sed -n 's/^CMAKE_C_COMPILER:FILEPATH=//p' "${NATIVE_CACHE}")
			CXX=$(sed -n 's/^CMAKE_CXX_COMPILER:FILEPATH=//p' "${NATIVE_CACHE}")
			if [ -n "${CC}" ] && [ -n "${CXX}" ]; then
				export CC CXX
				echo "--- host compiler from the native build: ${CC}, ${CXX}"
			else
				unset CC CXX
			fi
		fi
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
