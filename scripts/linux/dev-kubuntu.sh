#!/usr/bin/env bash
# Local Kubuntu/Ubuntu 26.04 build and run. Does not package or touch user data.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
build_dir="${root}/build/linux"
binary="${build_dir}/bin/bbhouse-qt"

usage() {
    cat <<'EOF'
Usage: scripts/linux/dev-kubuntu.sh <deps|build|test|run>

  deps   Install Ubuntu 26.04 Qt 6, libmpv, and media tool packages.
  build  Configure with the system Qt and compile bbhouse-qt.
  test   Build regression programs and run CTest.
  run    Start the local binary. Does not read or write credentials.
EOF
}

require_2604() {
    # shellcheck disable=SC1091
    . /etc/os-release
    if [[ "${VERSION_ID:-}" != "26.04" ]]; then
        echo "This script only supports Ubuntu/Kubuntu 26.04 (VERSION_ID=${VERSION_ID:-unknown})." >&2
        exit 1
    fi
}

cmd_deps() {
    require_2604
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        qt6-base-dev \
        qt6-declarative-dev \
        qt6-declarative-dev-tools \
        qt6-l10n-tools \
        qt6-tools-dev \
        qt6-svg-dev \
        libmpv-dev \
        zlib1g-dev \
        libx11-dev \
        cmake \
        ninja-build \
        g++ \
        pkg-config \
        libmpv2 \
        qml6-module-qtquick-controls \
        qml6-module-qtquick-layouts \
        qml6-module-qtquick-window \
        qml6-module-qtquick-effects \
        qt6-image-formats-plugins \
        libqt6sql6-sqlite \
        ffmpeg \
        aria2 \
        curl
}

cmd_build() {
    require_2604
    cmake -S "${root}" -B "${build_dir}" -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo
    cmake --build "${build_dir}"
}

cmd_test() {
    require_2604
    if [[ ! -f "${build_dir}/CMakeCache.txt" ]]; then
        echo "Build directory is not configured. Run: scripts/linux/dev-kubuntu.sh build" >&2
        exit 1
    fi
    cmake --build "${build_dir}" --target regression-tests
    ctest --test-dir "${build_dir}" --output-on-failure
}

cmd_run() {
    require_2604
    if [[ ! -x "${binary}" ]]; then
        echo "Binary not found. Run: scripts/linux/dev-kubuntu.sh build" >&2
        exit 1
    fi
    exec "${binary}"
}

case "${1:-}" in
    deps) cmd_deps ;;
    build) cmd_build ;;
    test) cmd_test ;;
    run) cmd_run ;;
    *) usage >&2; exit 1 ;;
esac
