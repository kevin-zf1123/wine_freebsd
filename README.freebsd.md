# Wine on native FreeBSD

[中文](README.freebsd.zh-CN.md) · [Upstream Wine README](README.md)

This project is an independently maintained native FreeBSD Wine fork, initially targeting FreeBSD amd64 and Win64 programs. Delivery is judged by actual application behavior on FreeBSD; merging into Wine mainline is not a delivery requirement. The project retains Wine's Windows API implementation and shared POSIX code while replacing missing Linux-specific host behavior with native FreeBSD implementations. The repository contains Wine source and an initial headless development profile; it is not a completed native-backend rewrite.

## Maintenance principles

Continue absorbing relevant upstream correctness, security, and compatibility fixes. Wine 11.20 identifies the initial source version, not a permanent version ceiling. Each integration identifies its upstream revision and validates the affected native paths; local adaptations retain their provenance. Maintaining the fork does not require contributing its changes upstream.

Modify one coherent subsystem at a time, separating unrelated refactoring from behavior changes. Keep commits buildable and preserve passing tests at each step so regressions can be bisected, performance compared, and conflicts with upstream changes resolved within a clear scope. Preserve working FreeBSD implementations and reusable code; replace actual Linux-specific dependencies rather than rewriting shared code because of its name or origin.

Accept features through named application workloads on FreeBSD, with application versions and exercised workflows recorded alongside the FreeBSD release, hardware, build configuration, and selected backends. Describe functional coverage, compatibility limits, known failures, and untested cases explicitly. Performance claims require comparable runs of the same workload, with variation and profiling overhead distinguished. Builds, unit tests, and the headless smoke check support this process but do not establish application support by themselves.

Wine's upstream contribution policies apply when an upstream contribution is explicitly requested. They do not gate this fork's local AI-assisted development or delivery. Licensing and attribution remain applicable to all work; see `AGENTS.md` for commit discipline and the separate upstream submission requirements.

## Native execution contract

Wine's host executables and Unix libraries use the FreeBSD ABI, runtime linker, libc, and threading implementation. Guest executables and Windows DLLs remain PE binaries. Wine and wineserver communicate through Wine's existing protocol; wineserver retains ownership of Windows objects and handle semantics unless a separately reviewed change alters that contract.

The target execution path excludes Linuxulator, Linux ELF libraries, Linux syscall/ioctl translation, linprocfs/linsysfs, and Linux-to-FreeBSD API emulation libraries. Shared POSIX code and native FreeBSD graphics, audio, and device libraries are permitted. A header name or a function called `linux_*` alone does not establish the actual execution ABI; inspect the compiled path and the receiving kernel interface.

FreeBSD-native NTSYNC can be considered separately from its Linux ABI compatibility shim. The initial profile disables Wine's Linux NTSYNC header detection and uses upstream server synchronization. A disabled feature is a bring-up limitation, not a native implementation or a compatibility claim.

## Workspace

| Path | Purpose |
| --- | --- |
| `dlls/`, `server/`, `loader/`, `include/`, `tools/` | Wine source; implement host changes in the owning subsystem |
| `freebsd/dev.sh` | Host inspection, native configuration, build, run, and process-exit smoke check |
| `freebsd/upstream.txt` | Source origin and release identity |
| `.agents/skills/wine-freebsd-analysis/` | Project-specific availability, debugging, and performance guidance |
| `build-freebsd/win64-headless/` | Ignored out-of-tree build |
| `prefix-freebsd/win64-headless/` | Ignored dedicated Wine prefix |
| `local-freebsd/`, `profiles-freebsd/` | Ignored local installation and explicitly requested profiling outputs |

The fork's development branch is `main`. Use `origin` for the fork and `upstream` for the Wine mirror. In a shallow checkout, fetch the history needed for a specific integration or investigation before comparing ancestry or resolving upstream changes.

## Development commands

Inspect the editing or execution host without changing it:

```sh
./freebsd/dev.sh doctor
```

Configure and build on FreeBSD amd64 with a native C/C++ compiler, GNU make, flex, bison, Perl, pkg-config, and a ports LLVM installation providing Clang's PE headers and `lld-link`. The FreeBSD wine-devel port declares LLVM 17 or newer; the selected Wine configure checks remain authoritative for the installed version. Set `LLVM_ROOT` to an installation that actually exists:

```sh
export LLVM_ROOT=/usr/local/llvm22
./freebsd/dev.sh configure
JOBS=2 ./freebsd/dev.sh build
./freebsd/dev.sh smoke
./freebsd/dev.sh run /absolute/path/to/program.exe
```

`LLVM_ROOT` controls PE compilation. `CC` and `CXX` select native host compilers and must each be a single executable name or path; compiler flags belong in `CFLAGS` and `CXXFLAGS`. Use consistent compiler settings for configure and build. The script neither installs dependencies nor performs `make install`. Builds include the upstream test targets, but `build` does not run the test suite.

The initial profile uses `--enable-win64 --enable-archs=x86_64 --disable-win16` and disables optional graphics, audio, media, device, and network-security libraries. It is suitable for initial loader, process, and console work; it does not provide desktop, sound, Vulkan, TLS, or device-feature coverage. It disables inotify and epoll header selection as well as the Linux NTSYNC entry point. Normal sockets remain part of the core.

`smoke` initializes the dedicated prefix with a 120-second timeout, disables Mono/Gecko loading for that command, then checks that Windows `cmd.exe /d /c "exit /b 37"` returns 37 within 30 seconds. This exercises loading a built-in PE program and process exit propagation. It does not certify synchronization, exceptions, memory semantics, application compatibility, or absence of every indirect Linux dependency. `run` uses the same build and prefix and preserves program arguments. A Wine prefix is ordinary application state, not a security sandbox.

## Host integration map

These are source entry points, not a runtime support matrix.

| Area | Source and observed boundary | Native work and validation boundary |
| --- | --- | --- |
| Loading and address space | `dlls/ntdll/unix/loader.c:pre_exec`, `virtual.c:anon_mmap_tryfixed` contain FreeBSD paths, including `MAP_FIXED \| MAP_EXCL` | Exercise mapping conflicts, reserve/commit/protect, and PE loading on the target kernel |
| Signals, TLS, and exceptions | `dlls/ntdll/unix/signal_x86_64.c` contains FreeBSD machine-context and platform branches | Validate Windows exception, unwind, and thread behavior through PE tests |
| Server readiness | `server/fd.c` selects a `HAVE_KQUEUE` implementation despite helper names such as `init_epoll` | Preserve descriptor lifetime and readiness semantics; naming is not an epoll dependency |
| Thread alerts and NT objects | `dlls/ntdll/unix/sync.c` has kqueue thread alerts; its fast NT-object path and `server/inproc_sync.c` include `linux/ntsync.h` | Keep server synchronization for bring-up; evaluate the native FreeBSD NTSYNC ABI and object ownership before enabling acceleration |
| Directory notifications | `server/change.c` uses inotify, then a dnotify fallback; this is distinct from server fd readiness | A FreeBSD notification implementation must preserve names, rename pairs, subtree changes, cancellation, and overflow semantics |
| System and filesystem information | `dlls/ntdll/unix/system.c` and `file.c` contain FreeBSD branches alongside Linux `/proc` code | Trace each invoked query; a FreeBSD branch does not imply every information class is implemented |
| Devices and desktop | `dlls/winebus.sys/bus_udev.c`, `dlls/mountmgr.sys/`, display and audio drivers | Reintroduce capabilities with verified FreeBSD backends; the headless profile does not implement replacements |

For each implemented backend, acceptance requires both the correct native host path and the affected Windows-visible behavior. Full project acceptance also requires dependency/ABI inspection and execution without Linux compatibility services on a FreeBSD host. Pin the actual FreeBSD release, CPU, compiler, and configuration in each relevant validation result; no minimum supported FreeBSD release is established by this setup.

## Sources

- [Wine 11.20 source](https://github.com/wine-mirror/wine/tree/wine-11.20) supplies the source paths above; see `freebsd/upstream.txt` for the checkout identity.
- [FreeBSD wine-devel port](https://cgit.freebsd.org/ports/tree/emulators/wine-devel/Makefile) provides native build context. Its optional Linux API header configuration is not copied into this profile.
- [FreeBSD native NTSYNC header](https://cgit.freebsd.org/src/tree/sys/dev/ntsync/ntsync.h) and [FreeBSD NTSYNC project report](https://www.freebsd.org/status/report-2026-04-2026-06/ntsync/) distinguish the native interface from the compatibility shim. Availability must be checked on the actual target release.
