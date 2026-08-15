#!/bin/bash
# Build QField for WebAssembly and check that the result is what it should be.
# Every check names what it looked at, so a failure points at a file.
#
#   ./scripts/verify-wasm-build.sh                build, then check
#   ./scripts/verify-wasm-build.sh --no-build     check what is already built
#   ./scripts/verify-wasm-build.sh --no-browser   skip the headless run
#
# The browser stage uses a throwaway Chrome profile: QSettings lives in
# localStorage, and a reused profile is how a fixed build keeps looking broken.
set -u

ROOT=$(git rev-parse --show-toplevel)
BUILD_DIR="${ROOT}/build-wasm32-emscripten"
BIN="${BUILD_DIR}/output/bin"
BUILD=1
BROWSER=1
CHROME_PROFILE=""

for argument in "$@"; do
	case "${argument}" in
	--no-build) BUILD=0 ;;
	--no-browser) BROWSER=0 ;;
	*)
		echo "unknown argument: ${argument}"
		exit 2
		;;
	esac
done

passed=0
failed=0

cleanup() {
	[ -n "${SERVER_PID:-}" ] && kill "${SERVER_PID}" 2>/dev/null
	[ -n "${CHROME_PID:-}" ] && kill "${CHROME_PID}" 2>/dev/null
	[ -n "${CHROME_PROFILE}" ] && rm -rf "${CHROME_PROFILE}"
	wait 2>/dev/null
	return 0
}
trap cleanup EXIT

check() { # check <name> <command...>
	local name=$1
	shift
	if "$@" >/dev/null 2>&1; then
		echo "  ok    ${name}"
		passed=$((passed + 1))
	else
		echo "  FAIL  ${name}"
		failed=$((failed + 1))
	fi
}

section() {
	echo
	echo "=== $1"
}

# ---------------------------------------------------------------- preflight

section "preflight"

echo "  branch  $(git -C "${ROOT}" rev-parse --abbrev-ref HEAD)"
echo "  head    $(git -C "${ROOT}" log -1 --format='%h %s')"
echo "  tree    $(git -C "${ROOT}" status --porcelain | wc -l) modified files"
echo "  cc      ${CC:-<unset>} / ${CXX:-<unset>}"
echo "  free    $(df -h --output=avail "${ROOT}" | tail -1 | tr -d ' ')"

if [ -z "${CC:-}" ]; then
	echo
	echo "  NOTE: CC/CXX are unset. vcpkg hashes the host compiler into every"
	echo "        package, so the wrong one restores nothing from the binary"
	echo "        cache and starts with a 45 minute qtbase."
fi

# ---------------------------------------------------------------- patches

section "emscripten port patches still apply"

# vcpkg keeps one extracted tree per patch set, so several are lying around and
# only the unpatched one can answer the question. Try them all.
check_patch() { # check_patch <name> <patch> <clean-source-glob>
	local name=$1 patch=$2
	# shellcheck disable=SC2206  # the glob is the point
	local matches=(${3})
	local scratch found=""
	for source in "${matches[@]}"; do
		[ -d "${source}" ] || continue
		scratch=$(mktemp -d)
		cp -r "${source}"/. "${scratch}"/ 2>/dev/null
		rm -rf "${scratch}/.git"
		if (cd "${scratch}" && git apply --check --ignore-whitespace "${patch}") 2>/dev/null; then
			found="${source}"
		fi
		rm -rf "${scratch}"
		[ -n "${found}" ] && break
	done
	if [ -n "${found}" ]; then
		echo "  ok    ${name}  (against $(basename "${found}"))"
		passed=$((passed + 1))
	elif [ ${#matches[@]} -eq 0 ] || [ ! -d "${matches[0]:-}" ]; then
		echo "  skip  ${name} (no extracted source to test against)"
	else
		echo "  FAIL  ${name} applies to none of the extracted sources"
		failed=$((failed + 1))
	fi
}

BUILDTREES="${ROOT}/build-x64-linux/_deps/vcpkg-src/buildtrees"
check_patch "qtkeychain emscripten.patch" \
	"${ROOT}/vcpkg/ports/qtkeychain-qt6/emscripten.patch" \
	"${BUILDTREES}/qtkeychain-qt6/src/0.15.0-*.clean"
check_patch "qtpositioning emscripten.patch" \
	"${ROOT}/vcpkg/ports/qtpositioning/emscripten.patch" \
	"${BUILDTREES}/qtpositioning/src/*.clean"

# ---------------------------------------------------------------- build

if [ "${BUILD}" = 1 ]; then
	section "build"
	echo "  logging to /tmp/qfield-wasm-build.log"
	echo "  ~15 minutes on a warm cache, but vcpkg hashes the triplet and the"
	echo "  chainload toolchain into every package, so editing either one misses"
	echo "  the whole cache and rebuilds the stack from source."
	if ! "${ROOT}/scripts/build-for-wasm.sh" >/tmp/qfield-wasm-build.log 2>&1; then
		echo "  BUILD FAILED"
		grep -nE "error:|Error |FAILED|CMake Error" /tmp/qfield-wasm-build.log | tail -30
		exit 1
	fi
	echo "  ok    build finished"
else
	section "build skipped"
fi

# ---------------------------------------------------------------- artifacts

section "artifacts"

for file in qfield.wasm qfield.js qfield.data qfield.html qtloader.js; do
	check "${file} exists" test -f "${BIN}/${file}"
done
[ -f "${BIN}/qfield.wasm" ] && echo "  size    qfield.wasm $(du -h "${BIN}/qfield.wasm" | cut -f1), qfield.data $(du -h "${BIN}/qfield.data" 2>/dev/null | cut -f1)"

# Qt writes its loader into a directory named after an unevaluated generator
# expression unless CMAKE_RUNTIME_OUTPUT_DIRECTORY drops the $<0:>.
check 'no directory named $<0:>' test ! -d "${BIN}/\$<0:>"

# ---------------------------------------------------------------- the shell

section "QField's shell, not Qt's"

check "has QField's overlay" grep -q 'id="overlay"' "${BIN}/qfield.html"
check "not Qt's stock shell" bash -c "! grep -q 'qtspinner' '${BIN}/qfield.html'"
check "waits for a sized container" grep -q "getBoundingClientRect" "${BIN}/qfield.html"
check "reads ?project= from the URL" grep -q "URLSearchParams" "${BIN}/qfield.html"
check "target name substituted" grep -q "window.qfield_entry" "${BIN}/qfield.html"
check "no placeholder left behind" bash -c "! grep -q 'QFIELD_WASM_TARGET' '${BIN}/qfield.html'"

# ---------------------------------------------------------------- link flags

section "link flags landed"

NINJA="${BUILD_DIR}/build.ninja"
check "build.ninja exists" test -f "${NINJA}"
check "-sPTHREAD_POOL_SIZE=8" grep -q -- "-sPTHREAD_POOL_SIZE=8" "${NINJA}"
check "-sINITIAL_MEMORY=1GB" grep -q -- "-sINITIAL_MEMORY=1GB" "${NINJA}"
check "--preload-file <share>@/share" grep -q -- "@/share" "${NINJA}"

# ---------------------------------------------------------------- options

section "options resolved as intended"

CACHE="${BUILD_DIR}/CMakeCache.txt"
cached() { grep -q "^$1:BOOL=$2$" "${CACHE}"; }
check "cache exists" test -f "${CACHE}"
for option in WITH_BLUETOOTH WITH_SERIALPORT WITH_NFC WITH_WEBVIEW; do
	check "${option}=OFF" cached "${option}" OFF
done
check "WITH_3D=ON" cached WITH_3D ON

# WITH_WEBVIEW off means the two web view files must not reach the QML module.
QMLDIR=$(find "${BUILD_DIR}" -name qmldir -path "*qfield*gui*" 2>/dev/null | head -1)
if [ -n "${QMLDIR}" ]; then
	check "QfWebView.qml absent from qmldir" bash -c "! grep -q 'QfWebView' '${QMLDIR}'"
	check "QfHtmlWebView.qml absent from qmldir" bash -c "! grep -q 'QfHtmlWebView' '${QMLDIR}'"
else
	echo "  skip  qmldir not found"
fi

# ---------------------------------------------------------------- packaged data

section "runtime data packaged"

for entry in proj/proj.db qgis/resources gdal cacert.pem; do
	check "share/${entry} staged" test -e "${BUILD_DIR}/output/share/${entry}"
done
check "proj.db reachable at /share" grep -q "/share/proj" "${BIN}/qfield.js"

# ---------------------------------------------------------------- browser

if [ "${BROWSER}" = 0 ]; then
	section "browser stage skipped"
elif ! command -v google-chrome >/dev/null 2>&1 || ! command -v node >/dev/null 2>&1; then
	section "browser stage skipped"
	echo "  skip  needs google-chrome and node on PATH"
else
	section "headless boot (fresh profile, empty localStorage)"

	python3 "${ROOT}/scripts/serve-wasm.py" "${BIN}" >/tmp/qfield-wasm-serve.log 2>&1 &
	SERVER_PID=$!

	CHROME_PROFILE=$(mktemp -d /tmp/qfield-wasm-profile.XXXXXX)
	# SwiftShader: headless has no GPU, and without a software GL fallback any
	# failure would be about the environment rather than about QField.
	nice -n 10 google-chrome \
		--headless=new \
		--remote-debugging-port=9222 \
		--no-sandbox \
		--enable-unsafe-swiftshader \
		--use-angle=swiftshader \
		--user-data-dir="${CHROME_PROFILE}" \
		--window-size=800,600 \
		about:blank >/tmp/qfield-wasm-chrome.log 2>&1 &
	CHROME_PID=$!

	for _ in $(seq 40); do
		curl -sf http://localhost:9222/json/version >/dev/null 2>&1 && break
		sleep 0.25
	done

	node "${ROOT}/scripts/wasm-headless.js" "http://localhost:8080/qfield.html" 40 \
		>/tmp/qfield-wasm-run.log 2>&1

	RUN=/tmp/qfield-wasm-run.log
	echo "  console and DOM in ${RUN}, screenshot in /tmp/qfield-wasm.png"

	check "a canvas exists" grep -qE '"canvasCount": [1-9]' "${RUN}"
	check "canvas has a webgl2 context" grep -q '"ctx": "webgl2"' "${RUN}"
	check "container has a size" bash -c "! grep -q '\"screenSize\": \"0x0\"' '${RUN}'"
	check "no uncaught exception" bash -c "! grep -q '\[EXCEPTION\]' '${RUN}'"
	check "no SharedArrayBuffer complaint" bash -c "! grep -qi 'SharedArrayBuffer' '${RUN}'"
	check "no nested event loop abort" bash -c "! grep -q 'WaitForMoreEvents is not supported' '${RUN}'"
	check "proj found its data" bash -c "! grep -q 'Proj path: \"/\\.\\./share\"' '${RUN}'"

	echo
	echo "  --- first console lines ---"
	grep -E "^\[" "${RUN}" | head -12 | sed 's/^/  /'
fi

# ---------------------------------------------------------------- verdict

section "verdict"
echo "  ${passed} passed, ${failed} failed"
if [ "${failed}" -gt 0 ]; then
	echo
	echo "  Logs: /tmp/qfield-wasm-build.log /tmp/qfield-wasm-run.log"
	exit 1
fi
echo
echo "  Look at it yourself:"
echo "    ./scripts/build-for-wasm.sh --serve-only"
echo "    http://localhost:8080/qfield.html"
exit 0
