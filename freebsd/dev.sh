#!/bin/sh
# SPDX-License-Identifier: LGPL-2.1-or-later
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
build="$root/build-freebsd/win64-headless"
prefix="$root/prefix-freebsd/win64-headless"

fail() { printf '%s\n' "$*" >&2; exit 1; }
usage()
{
    cat <<'EOF'
Usage: ./freebsd/dev.sh {doctor|configure|build|smoke|run PROGRAM [ARG...]}

doctor     Report host and tool availability without creating build files.
configure  Configure a native FreeBSD amd64, Win64-only, headless build.
build      Build the configured tree with GNU make (JOBS defaults to 2).
smoke      Run built-in Windows cmd.exe and check its process exit status.
run        Run a Windows program using this build and its dedicated prefix.

Set LLVM_ROOT to a FreeBSD ports LLVM prefix, e.g. /usr/local/llvm22.
CC and CXX may name native compilers; PE compilation uses LLVM_ROOT/bin/clang.
Build and runtime actions require FreeBSD amd64. No packages are installed.
EOF
}

native_host()
{
    [ "$(uname -s)" = FreeBSD ] || fail 'Native execution requires FreeBSD; this host is for editing only.'
    [ "$(uname -m)" = amd64 ] || fail 'This profile requires FreeBSD amd64.'
}

need() { command -v "$1" >/dev/null 2>&1 || fail "Missing tool: $1"; }

toolchain()
{
    [ -n "${LLVM_ROOT:-}" ] || fail 'Set LLVM_ROOT to an installed FreeBSD ports LLVM prefix (LLVM 17 or later).'
    case "$LLVM_ROOT" in /*) ;; *) fail 'LLVM_ROOT must be an absolute path.' ;; esac
    [ -x "$LLVM_ROOT/bin/clang" ] || fail 'LLVM_ROOT/bin/clang is not executable.'
    [ -x "$LLVM_ROOT/bin/lld-link" ] || fail 'LLVM_ROOT/bin/lld-link is not executable.'
    PATH="$LLVM_ROOT/bin:/usr/local/bin:$PATH"
    export PATH
    CC=${CC:-cc}
    CXX=${CXX:-c++}
    export CC CXX
    need "$CC"
    need "$CXX"
    for tool in gmake flex bison perl pkg-config; do need "$tool"; done
    for compiler in "$CC" "$CXX"; do
        case "$("$compiler" -dumpmachine)" in
            x86_64-*-freebsd*|amd64-*-freebsd*) ;;
            *) fail "$compiler must target native FreeBSD amd64." ;;
        esac
    done
}

runtime()
{
    [ -x "$build/wine" ] || fail 'Build Wine before running this command.'
    [ -x "$build/server/wineserver" ] || fail 'The matching wineserver is missing.'
    # Resolve all Wine components from this checkout, independent of shell setup.
    unset WINELOADER WINEDLLPATH WINESERVERSOCKET WINELOADERNOEXEC
    WINEPREFIX=$prefix
    WINEARCH=win64
    WINESERVER="$build/server/wineserver"
    export WINEPREFIX WINEARCH WINESERVER
    mkdir -p "$root/prefix-freebsd"
}

command=${1:-help}
[ "$#" -eq 0 ] || shift
case "$command" in
    help|-h|--help) usage; exit 0 ;;
    doctor|configure|build|smoke) [ "$#" -eq 0 ] || fail 'Unexpected arguments; see --help.' ;;
    run) [ "$#" -gt 0 ] || fail 'run requires a Windows program.' ;;
    *) usage >&2; exit 2 ;;
esac

case "$command" in
    doctor)
        uname -srm
        if [ "$(uname -s)" = FreeBSD ]; then freebsd-version -ku; fi
        for tool in cc c++ gmake flex bison perl pkg-config lldb truss pmcstat dtrace; do
            if tool_path=$(command -v "$tool"); then
                printf '%s: %s\n' "$tool" "$tool_path"
            else
                printf '%s: unavailable\n' "$tool"
            fi
        done
        printf 'LLVM_ROOT: %s\n' "${LLVM_ROOT:-unset}"
        printf 'Build directory: %s\n' "$build"
        if [ "$(uname -s)" != FreeBSD ] || [ "$(uname -m)" != amd64 ]; then
            printf '%s\n' 'Editing host only; native FreeBSD amd64 build/run unavailable.'
        fi
        ;;
    configure)
        native_host
        toolchain
        mkdir -p "$build"
        cd "$build"
        # Use native server synchronization until a FreeBSD NTSYNC backend exists.
        # Also prevent optional Linux API headers from selecting compatibility paths.
        ac_cv_header_linux_ntsync_h=no
        ac_cv_header_sys_epoll_h=no
        ac_cv_header_sys_inotify_h=no
        export ac_cv_header_linux_ntsync_h ac_cv_header_sys_epoll_h ac_cv_header_sys_inotify_h
        exec "$root/configure" \
            --prefix="$root/local-freebsd/win64-headless" \
            --libdir="$root/local-freebsd/win64-headless/lib" \
            --enable-win64 --enable-archs=x86_64 --disable-win16 \
            --with-mingw="$LLVM_ROOT/bin/clang" --with-pthread \
            --without-alsa --without-capi --without-coreaudio --without-cups \
            --without-dbus --without-ffmpeg --without-fontconfig --without-freetype \
            --without-gettext --without-gettextpo --without-gphoto --without-gnutls \
            --without-gssapi --without-gstreamer --without-hwloc --without-inotify \
            --without-krb5 --without-netapi --without-opencl --without-opengl \
            --without-oss --without-pcap --without-pcsclite --without-pulse \
            --without-sane --without-sdl --without-udev --without-usb \
            --without-v4l2 --without-va --without-vulkan --without-wayland --without-x
        ;;
    build)
        native_host
        toolchain
        [ -f "$build/Makefile" ] || fail 'Run configure first.'
        jobs=${JOBS:-2}
        case "$jobs" in ''|*[!0-9]*) fail 'JOBS must be a positive integer.' ;; esac
        [ "$jobs" -gt 0 ] 2>/dev/null || fail 'JOBS must be a positive integer.'
        exec gmake -C "$build" -j "$jobs"
        ;;
    smoke)
        native_host
        runtime
        need timeout
        # Keep prefix initialization/download prompts outside the exit-code check.
        WINEDLLOVERRIDES='mscoree,mshtml='
        export WINEDLLOVERRIDES
        timeout 120 "$build/wine" wineboot -u
        result=0
        timeout 30 "$build/wine" cmd /d /c 'exit /b 37' || result=$?
        [ "$result" -eq 37 ] || fail "Win64 cmd exit propagation failed: expected 37, got $result."
        printf '%s\n' 'Win64 cmd.exe exit propagation passed (37).'
        ;;
    run)
        native_host
        runtime
        exec "$build/wine" "$@"
        ;;
esac
