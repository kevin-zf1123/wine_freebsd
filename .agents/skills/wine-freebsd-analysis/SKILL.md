---
name: wine-freebsd-analysis
description: Inspect FreeBSD target availability and diagnose Wine loader, wineserver, synchronization, syscall, or performance problems in this workspace. Use for native FreeBSD runtime debugging and comparable performance measurements.
---

# Wine FreeBSD analysis

Read the workspace `AGENTS.md` and `README.freebsd.md`. Choose availability, debugging, or performance work according to the request. Initialization or a source audit does not authorize a benchmark campaign, package installation, or changing the running OS.

## Establish the execution host

The user's `freebsdpc`, `linuxpc`, and `winpc` aliases select SSH identities for one multiboot machine. Use strict host-key checks and verify `uname` before issuing platform commands. A key mismatch is a stop condition for that alias, not permission to remove a pinned key or disable verification. The machine may be running another project's Linux workload; do not reboot it, change its next boot, or stop that workload.

For a remote FreeBSD task, begin with this read-only check:

```sh
ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=yes freebsdpc \
  'uname -srm; if [ "$(uname -s)" = FreeBSD ]; then freebsd-version -ku; fi'
```

If unreachable or the identity/OS is wrong, complete useful local source analysis and report that FreeBSD execution is unavailable. Do not reinterpret a macOS or Linux result as FreeBSD validation. An explicitly requested Linux comparison requires the same checks using `linuxpc` and a separate native Linux build.

Read [references/freebsd-tools.md](references/freebsd-tools.md) when probing tools or selecting a tracing method. Discover installed compiler versions and tool permissions; LLVM 22 was used by the reference Photospider workflow, but is not a live availability guarantee.

## Trace the Windows operation to the host

Start with a reproducible Windows program, workload, or failing Wine test. Record the source revision and local modifications, FreeBSD version/architecture, host and PE compiler versions, configure flags, workload inputs, relevant Wine settings, and prefix initialization state. Record only what the current investigation needs; create persistent reports or trace artifacts when requested or necessary for that investigation.

Follow the actual path from the PE API through Wine's Unix boundary and, where applicable, the wineserver request to the host implementation. Distinguish the Wine client from wineserver and from unrelated processes. Identify the configured backend from `include/config.h`, the implementation, and runtime observations. `server/fd.c` uses helpers named `*_epoll` for kqueue as well; Linux-looking names are not ABI evidence.

The initial headless profile disables Linux NTSYNC and several optional features. Missing display, media, device, or security functionality under that profile is not automatically a defect in the corresponding Wine implementation. Conversely, disabling a dependency does not implement a native replacement.

## Debug a failure

Minimize the trigger before altering code. Use narrowly selected `WINEDEBUG` channels for the subsystem, LLDB for thread stacks and host state, and truss for host calls. Separate loader failure, missing dependencies, Windows exceptions, server waits, and an unsupported backend. Wine handles some Unix signals intentionally; inspect the signal's role before treating every debugger stop as a crash or changing signal delivery.

For a hang, capture both the affected client's and wineserver's stacks and wait state. Correlate thread IDs, Wine handles, Unix descriptors, and request ownership. For exceptions, retain module identity, address, and available PE/Unix symbols; host symbols alone may not resolve guest frames. Inspect matching source and the exact loaded binary.

Use the smallest relevant Windows-visible regression: for example wait-any versus wait-all, abandoned mutexes, cancellation during close, mapping conflicts, or directory rename notifications. Run the affected upstream Wine tests where applicable. Source presence, successful configuration, or a native primitive microtest does not prove the public Windows API path.

## Analyze performance

Establish correctness before timing. Keep uninstrumented wall-clock/CPU timing separate from instrumented tracing and verbose Wine logging. Use the same PE workload, inputs, compiler flags, prefix state, synchronization backend, and display/audio conditions for comparisons. Separate first-run prefix creation, cold caches, steady state, and application work; use repeated measurements and report variation.

Use native FreeBSD facilities: `time -l` for basic cost, `pmcstat` for CPU samples and counters, truss for syscall diagnosis, and DTrace for targeted latency or scheduling analysis. Select an available PMC event from `pmcstat -L`; do not copy Linux `perf` event names or assume PMCs/DTrace work in a VM. Sample the process that owns the suspected cost, including wineserver where relevant. Capture kernel involvement only when the hypothesis requires it.

Determine whether the bottleneck is PE/user CPU, Unix host code, server serialization, context switches, kernel waits, page faults, I/O, or device work. Report unresolved symbols, lost samples, unavailable kernel events, and tracing overhead. Microbenchmarks and VM results are separate from application behavior and physical-host performance. Optimize one supported hypothesis, then repeat the same correctness check and comparable measurements.

## Native ABI verification and delivery

Inspect host executable format and dynamic dependencies with `file`, `readelf`, and `ldd`, and loaded libraries with `procstat` when appropriate. Account for libraries loaded with `dlopen`; an `ldd` listing alone is incomplete. Kernel traces and the receiving interface distinguish direct FreeBSD execution from Linux compatibility routes. The presence of unrelated Linux modules is not proof that Wine used them; a claim of compatibility-free operation requires a controlled target and observed execution. Do not unload modules supporting another workload to manufacture that condition.

Report the concrete finding, relevant `file:line`/symbol, reproduction, actual tool result, changes if authorized, and untested scope. Keep source inspection, native build, PE behavior, and performance evidence separate. Never label the headless smoke check as full application support.

The tool selection and separation of benchmark timing from tracing are adapted from the user's Photospider `.codex/skills/performance/SKILL.md`. This skill is self-contained and does not require access to that repository.
