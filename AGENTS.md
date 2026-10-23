# Wine on native FreeBSD

## Project contract

Read `README.freebsd.md` before changing host integration. This project is an independently maintained native FreeBSD Wine fork. Delivery is determined by actual application behavior on FreeBSD; acceptance into Wine mainline is not a delivery requirement. The initial execution target is FreeBSD amd64 running Win64 PE binaries. WoW64 follows separately.

Keep Wine's Windows API implementation and reusable POSIX code. Implement missing host behavior directly with FreeBSD interfaces. Linux-specific host paths are replacement candidates; existing native FreeBSD paths should be verified and extended where appropriate. Preserve upstream authorship and licensing.

The supported execution path must not require Linuxulator, Linux ELF userland, Linux syscall or ioctl translation, linprocfs/linsysfs, or a Linux-to-FreeBSD API emulation library. Native FreeBSD APIs with a similar purpose or naming are acceptable when their actual ABI and implementation are verified. Disabling an optional feature is an explicit bring-up limitation, not completed parity.

## Maintenance and acceptance principles

- Continue integrating relevant upstream fixes, including correctness, security, and compatibility fixes. Wine 11.20 is the initial source version, not a permanent version ceiling. For each integration, identify the upstream revision, review interactions with local backends, and validate affected behavior. Upstream integration does not require publishing local changes upstream and is not a scheduled automation by itself.
- Organize native changes into coherent subsystem batches, such as loading/memory, signals/threads, synchronization, filesystem notifications, and devices/graphics/audio. Keep unrelated refactoring separate so regressions can be bisected, performance compared, and upstream merge conflicts resolved locally. Retain enough provenance to identify imported fixes and local adaptations.
- Preserve working native FreeBSD implementations and reusable Wine/POSIX code. Replace actual Linux-specific dependencies and missing host behavior; do not rewrite shared code merely because it also supports Linux or has Linux-oriented names.
- Accept functionality through named application workloads on FreeBSD. State the application/version, exercised workflow, FreeBSD release, hardware, build settings, and native backend. Report supported features, compatibility limitations, known failures, and untested scope separately. Performance claims require comparable measurements of the same workload and environment, including variation and instrumentation limits. A build, unit test, or headless smoke check alone does not establish application support.

## Development

Use rapid development for local changes: locate the behavior, implement minimally, run focused checks, and review the diff. Escalate to reviewed work for public ABI, loader/wineserver ownership, persistence, concurrency, memory safety, untrusted input, or unverified external behavior. Release validation requires an explicit request.

Edit Wine in its existing source directories. `freebsd/` owns workspace tooling; build outputs and Wine prefixes live in the ignored directories named in `.gitignore`. Use `freebsd/dev.sh` for the initial native profile. It deliberately retains Wine's upstream build system.

Do not automatically create OpenSpec changes, feedback, development tracking, baselines, backups, branches, worktrees, commits, or pushes. OpenSpec skills require explicit invocation; apply requires approval of the specific Draft; archive requires an explicit request after merge. English documentation is authoritative. Maintain affected Chinese translations with stable contract changes. The task owner writes documentation directly; use Claude only if explicitly requested. Follow `/Users/zhufeng/.claude/rules/documentation-writing.md` when available, with this ownership rule taking precedence.

One agent owns project-code writes. Delegate only genuinely independent, scoped, read-heavy research/review/CI work. Tests must exercise program behavior, not migration history or the absence of deleted files. State separately what was source-inspected, compiled, executed on FreeBSD, and tested through a Windows program. A macOS check is not FreeBSD runtime evidence.

## Commit quality for this fork

Adopt Wine's per-commit engineering discipline as a local maintenance rule. Upstream contribution eligibility, review approval, and submission procedures are separate and do not gate local development or delivery.

### Required engineering rules

- **Every commit must build and keep tests passing.** Wine maintainer Dmitry Timoshkov explicitly requires that Wine compile and pass `make test` after each separate patch. Do not submit a sequence with broken intermediate commits and rely on the final commit to repair it. Keep source additions/removals, their build integration, and required callers together; avoid disconnected dead code. This preserves useful bisection. See the [maintainer's statement](https://www.mail-archive.com/wine-devel@winehq.org/msg68162.html).
- **Verify each proposed commit, not only the series tip.** As this workspace's enforcement of that rule, compare relevant conformance results on the unchanged base and at every proposed commit using a consistent environment. Distinguish existing failures from newly introduced failures; an existing failure is not permission for another regression. Report commands, platforms, skips, and failures accurately. An unavailable FreeBSD host leaves FreeBSD validation outstanding. Missing Windows reference results leave the corresponding compatibility claim unverified, rather than blocking unrelated local work. Focus validation on affected behavior and widen it for actual risk; this requirement does not automatically request a full release matrix, a saved baseline artifact, or tests after every unsaved edit.
- **Keep commits atomic and relevant.** Include closely related changes only, normally within one component unless a cross-component change is needed for correctness. Do not add speculative interfaces or unused functionality. Fix significant compiler warnings introduced by the change before submission. Follow the surrounding Wine style and portable-code guidance. See [Submitting Patches: Making your changes](https://gitlab.winehq.org/wine/wine/-/wikis/Submitting-Patches#making-your-changes).
- **Conformance tests must describe Windows behavior.** New or modified Windows API conformance tests must use Windows behavior as their reference, not merely agree with this fork's implementation. Run the relevant Wine tests and obtain Windows reference results when needed to establish the changed semantics; local Windows testing can provide that evidence without a TestBot upload. FreeBSD host tests and actual application runs complement these tests. Never delete assertions, broaden expected values, or add skips/`todo_wine` just to hide a regression. See [Conformance Tests](https://gitlab.winehq.org/wine/wine/-/wikis/Conformance-Tests).
- **New optional dependencies must remain optional in practice.** The patch must still compile and preserve the supported configuration's behavior when the optional library is absent, with unavailable capabilities stated explicitly. Wine's submission guide states its dependency rule for added Linux libraries; adopt the same principle for optional FreeBSD backend dependencies. See [Introducing new dependencies](https://gitlab.winehq.org/wine/wine/-/wikis/Submitting-Patches#introducing-new-dependencies).
- **Resolve review findings while preserving useful history.** Keep a proposed, unpublished series coherent and independently valid. Recheck affected commits after incorporating corrections. Do not rewrite shared or published history automatically; history rewriting and publishing remain subject to the user's authorization. Preserve original authorship and licensing when importing upstream changes, and identify local adaptations.

### Optional Wine upstream contributions

This subsection applies only when the user explicitly requests preparation or submission of a Wine upstream contribution. It does not constrain the fork's use of AI-assisted development or make upstream acceptance a local delivery condition. Continue respecting applicable licenses and attribution in all local work.

- Wine accepts GitLab MRs. Refresh the relevant upstream base and check current submission rules before preparing one. Upstream expects review fixes incorporated into the original commits rather than appended fixups, and normally requires all assigned reviewers' approval. New CI build-environment changes belong in a separate MR and take effect only after the environment is manually updated. See [Submitting Patches](https://gitlab.winehq.org/wine/wine/-/wikis/Submitting-Patches).
- Upstream's conformance policy rejects new failures on the maintainer's Wine environment and test changes that fail its Windows TestBot runs. Obtain the applicable results before claiming upstream readiness; these upstream checks do not replace this fork's FreeBSD application acceptance.
- **Preserve contribution identity and provenance.** Upstream requires the contributor's real name in Git and the WineHQ GitLab profile, a correctly configured author email, and account verification when required. Preserve an original patch author's attribution. Do not invent identities, sign-offs, approvals, or test results. Inspect the current submission rules before publishing; do not change global Git configuration as a side effect.
- **Respect upstream clean-room eligibility.** Wine's [Clean Room Guidelines](https://gitlab.winehq.org/wine/wine/-/wikis/Clean-Room-Guidelines) prohibit generating contribution code with LLM tools. They also exclude disassembly of Microsoft code, inspection of its debug symbols, ReactOS code/headers, and incompatible Microsoft source; the guide permits appropriately attributed Microsoft code under an LGPL-compatible license. It also disallows `+relay` tracing with native Microsoft components and tests that dump internal tables. Do not represent AI-generated or otherwise ineligible code as acceptable upstream material. Local AI-assisted work authorized by the user is distinct from upstream eligibility; human review alone is not an exception stated by Wine. Resolve eligibility before offering such code for upstream submission.

### Upstream recommendations and format boundaries

Wine recommends putting a regression test before its fix in a separate commit, using narrowly justified `todo_wine` markers for the known Wine failure and removing them with the fix. The guide explicitly allows exceptions for tests that crash or hang, cases where `todo_wine` is unsuitable, new features, and trivial fixes. This is a preferred submission structure, not an unconditional two-commit requirement. Likewise, approximately five or fewer commits per MR is a reviewability guideline, not a hard numerical limit.

Upstream commit subjects use `component: Imperative summary.`; explanatory paragraphs describe the reason and mechanism and wrap at 72 characters. A `Wine-Bug:` URL is recommended for related Bugzilla reports, and the bug number should not appear in the subject. See [The commit message](https://gitlab.winehq.org/wine/wine/-/wikis/Submitting-Patches#the-commit-message). The user's local `[type]` format below remains authoritative for this fork. Prepare Wine-formatted messages when explicitly preparing an upstream submission; do not silently rewrite local history or claim the local format matches Wine's format.

These rules do not authorize commits, rebases, pushes, MR creation, TestBot uploads, or messages to maintainers by themselves. Perform external submission actions only within the user's explicit task authorization. Consult the linked official guides again when preparing a real upstream submission, since contribution policies can change.

## Host and skills

Use `.agents/skills/wine-freebsd-analysis/SKILL.md` for FreeBSD availability, Wine debugging, or performance work. The `freebsdpc`, `linuxpc`, and `winpc` SSH aliases select identities for one multiboot machine. Verify the actual OS before platform work. Keep pinned host keys; do not switch boot targets or disturb another project's run as part of setup or profiling.

## Commit messages

Only commit when requested. Inspect the staged diff first. If nothing is staged, inspect the working tree and say the proposed message is based on unstaged changes. Use one primary type from `add`, `fix`, `docs`, `chore`, `refactor`, `test`, `perf`, `style`; write an imperative summary, preferably under 72 characters.

```text
[type] concise summary

Main changes:
- High-level change

Files:
- path/to/file: what changed and why

Traceability:
- Motivation: bug, feature, cleanup, or documentation purpose
- Impact: user-visible behavior, API, build, tests, or no runtime impact
- Tests: actual commands run, or Not run: reason
- Risk: low/medium/high and why
```

Mention breaking changes under Impact. Group large changes by area and identify generated files, lockfiles, and assets. Never invent test results.
