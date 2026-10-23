# Selecting FreeBSD tools

Probe the actual FreeBSD host as the regular user. Discover tools before proposing installation or tracing commands:

```sh
uname -srm
freebsd-version -ku
for tool in cc clang clang22 gmake bison flex pkg-config file readelf ldd procstat lldb truss pmcstat dtrace; do
    command -v "$tool" || :
done
cc --version
kldstat
```

`freebsd/dev.sh doctor` provides a small local inventory. Check installed ports LLVM prefixes explicitly when selecting `LLVM_ROOT`; do not assume an unversioned `clang` has the PE headers required by Wine. Use GNU make. A tool's presence establishes availability of its executable, not permission or successful kernel instrumentation.

## Process and library inspection

For a known Wine client or wineserver PID, consult the installed tool's help/man page and select the required `procstat` view: `-b` for executable identity, `-v` for mapped memory/libraries, `-f` for descriptors, and `-t` for threads. Use the matching checkout and build paths. Inspect both initial dynamic linkage and libraries loaded after program startup.

The build-tree entry point `build-freebsd/win64-headless/wine` loads Wine's Unix ntdll. The matching server is `build-freebsd/win64-headless/server/wineserver`. Upstream source is authoritative if these paths change. Select a dedicated prefix and avoid mixing an installed system Wine server with the local build.

## Timing and syscall tracing

Run a small workload once for correctness and to initialize the prefix before measuring steady-state execution. `/usr/bin/time -l` can report elapsed time, CPU, memory, and scheduling counters for the measured command. Child/server attribution must be understood; an already-running wineserver is not automatically charged to the measured client.

Use `truss -f` for a bounded reproduction when child processes matter. Follow only the relevant workload; attaching to one client does not automatically include a wineserver that was already running. Syscall traces can contain paths, arguments, and application data. Save traces under `profiles-freebsd/` when the investigation needs an artifact, and avoid logging unrelated workloads. Trace timings include instrumentation overhead.

## PMC and DTrace availability

Use `pmcstat -L` to enumerate supported hardware events. Select counting or sampling and user/kernel scope from the installed `pmcstat` manual. Correlate samples with the matching binary and symbols before drawing conclusions. Hybrid CPU types, VM restrictions, permissions, and event support can limit comparability.

`hwpmc` supplies PMC support; DTrace may require `dtraceall` or specific provider modules. Inspect `kldstat` and tool errors first. Loading kernel modules, installing packages, or changing privilege/sysctl/boot settings requires authorization for that mutation; availability probing itself is read-only. If access is unavailable, report the limit and use timing, regular-user debugging, or syscall traces as appropriate. Do not prescribe universal `sudo kldload` commands as part of every analysis.

Inspect available DTrace providers and probes before writing a bounded query. Kernel function names and probe sets vary by release. Restrict the query to the relevant process or operation and separate scheduling latency from actual CPU execution.

## LLDB

Use a debug-symbol build with production-representative optimization when investigating performance. LLDB can attach to the known client/server PID or launch the host executable after setting the dedicated Wine environment. Inspect all relevant threads with `thread backtrace all`. Attaching may stop the target; use the reproduction process owned by this investigation, not another project's running workload.

Wine uses signals as part of its exception implementation. Inspect why a signal occurred before changing LLDB's signal policy; do not suppress delivery wholesale. Preserve the distinction between PE guest addresses and Unix host addresses, and match both symbol sets to the binaries being executed.
