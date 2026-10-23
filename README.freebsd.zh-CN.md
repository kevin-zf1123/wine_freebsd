# FreeBSD 原生 Wine

[English（权威文档）](README.freebsd.md) · [Wine 上游 README](README.md)

本项目定位为独立维护的 FreeBSD 原生 Wine fork，首先面向 FreeBSD amd64 和 Win64 程序。交付以 FreeBSD 上的实际应用行为为准，不以合入 Wine 主线为要求。项目保留 Wine 的 Windows API 实现和通用 POSIX 代码，用 FreeBSD 原生实现补齐依赖 Linux 的宿主行为。仓库包含 Wine 源码和初始无图形开发配置，目前并不代表原生后端重写完成。

## 维护原则

持续吸收上游的正确性、安全性和兼容性修复。Wine 11.20 是初始源码版本，不是永久停留的版本上限。每次集成明确对应的上游 revision，验证受影响的原生路径，并保留本地适配的来源。维护本 fork 不要求把改动贡献到上游。

按职责明确的子系统分批改造，将无关重构与行为变化分开。每个提交都保持可编译及已有测试通过，便于二分定位回归、比较性能，并在明确范围内解决上游合并冲突。保留已有可用的 FreeBSD 实现和通用代码，重点替换实际的 Linux 专属依赖，不因名称或来源重写共享代码。

通过 FreeBSD 上明确命名的应用工作负载验收功能，记录应用版本、实际操作流程，以及 FreeBSD 版本、硬件、构建配置和所选后端。明确功能覆盖、兼容性限制、已知失败和未测试范围。性能结论必须来自相同工作负载的可比运行，区分结果波动与分析工具开销。构建、单元测试和无图形冒烟检查用于支撑验收，不能单独证明应用可用。

仅在明确要求向 Wine 上游贡献时适用其贡献政策；这些政策不作为本 fork 本地 AI 辅助开发或交付的门槛。所有工作仍须遵守适用许可证并保留署名；逐提交质量要求与独立的上游投稿规则见 `AGENTS.md`。

## 原生执行契约

Wine 的宿主可执行文件和 Unix 库使用 FreeBSD ABI、动态链接器、libc 和线程实现。Windows 程序与 DLL 保持 PE 格式。Wine 与 wineserver 沿用 Wine 协议；Windows 对象和句柄语义仍由 wineserver 管理，改变这项归属必须单独审核。

目标执行路径不依赖 Linuxulator、Linux ELF 库、Linux 系统调用或 ioctl 转译、linprocfs/linsysfs，也不使用 Linux 到 FreeBSD 的 API 仿真库。允许复用 POSIX 代码，以及原生 FreeBSD 图形、音频和设备库。仅凭头文件名称或 `linux_*` 函数名无法判定实际执行 ABI，应检查参与编译的路径及接收请求的内核接口。

FreeBSD 原生 NTSYNC 与其 Linux ABI 兼容模块应分别评估。初始配置禁用 Wine 的 Linux NTSYNC 头文件探测，使用上游 server 同步机制。禁用功能只代表启动阶段的限制，不代表已实现原生替代或达到兼容性目标。

## 工作区

| 路径 | 用途 |
| --- | --- |
| `dlls/`、`server/`、`loader/`、`include/`、`tools/` | Wine 源码，在所属子系统内实现宿主改动 |
| `freebsd/dev.sh` | 环境检查、原生配置、构建、运行和进程退出冒烟检查 |
| `freebsd/upstream.txt` | 源码来源及版本身份 |
| `.agents/skills/wine-freebsd-analysis/` | 本项目的平台可用性、调试和性能分析技能 |
| `build-freebsd/win64-headless/` | 已忽略的源码外构建目录 |
| `prefix-freebsd/win64-headless/` | 已忽略的专用 Wine prefix |
| `local-freebsd/`、`profiles-freebsd/` | 已忽略的本地安装目录和用户明确要求的分析产物 |

本 fork 的开发分支为 `main`。`origin` 指向本 fork，`upstream` 指向 Wine 镜像。使用浅克隆时，应在比较提交关系或处理上游改动前，获取本次集成或调查所需的历史。

## 开发命令

只读检查编辑机或执行机：

```sh
./freebsd/dev.sh doctor
```

在 FreeBSD amd64 上配置和编译，需要原生 C/C++ 编译器、GNU make、flex、bison、Perl、pkg-config，以及提供 Clang PE 头文件和 `lld-link` 的 ports LLVM。FreeBSD wine-devel port 声明 LLVM 至少为 17；具体安装版本仍须通过所选 Wine 的 configure 检查。`LLVM_ROOT` 必须指向实际存在的安装：

```sh
export LLVM_ROOT=/usr/local/llvm22
./freebsd/dev.sh configure
JOBS=2 ./freebsd/dev.sh build
./freebsd/dev.sh smoke
./freebsd/dev.sh run /absolute/path/to/program.exe
```

`LLVM_ROOT` 控制 PE 编译。`CC` 和 `CXX` 选择原生宿主编译器，每个变量只能是单个可执行文件名或路径；编译参数使用 `CFLAGS` 和 `CXXFLAGS`。配置和构建应使用一致的编译器设置。脚本不安装依赖，也不执行 `make install`。构建保留上游测试目标，但 `build` 不运行测试套件。

初始配置使用 `--enable-win64 --enable-archs=x86_64 --disable-win16`，禁用可选图形、音频、媒体、设备和网络安全库。它用于初始加载器、进程和控制台工作，不覆盖桌面、声音、Vulkan、TLS 或设备功能。它同时禁用 inotify、epoll 头文件探测和 Linux NTSYNC 入口。核心的普通 socket 功能仍然保留。

`smoke` 在 120 秒内初始化专用 prefix，仅在该命令中禁用 Mono/Gecko 加载，再验证 Windows `cmd.exe /d /c "exit /b 37"` 在 30 秒内返回 37。这会经过内置 PE 程序加载和进程退出状态传播，不证明同步、异常、内存语义、应用兼容性，也不证明所有间接 Linux 依赖都已排除。`run` 使用相同构建和 prefix，保留程序参数。Wine prefix 是普通应用状态，不是安全沙箱。

## 宿主接口位置

以下是源码入口，不是运行支持矩阵。

| 范围 | 源码及可见边界 | 原生实现和验证边界 |
| --- | --- | --- |
| 加载与地址空间 | `dlls/ntdll/unix/loader.c:pre_exec`、`virtual.c:anon_mmap_tryfixed` 已含 FreeBSD 路径，包括 `MAP_FIXED \| MAP_EXCL` | 在目标内核上验证映射冲突、保留/提交/保护和 PE 加载 |
| 信号、TLS 与异常 | `dlls/ntdll/unix/signal_x86_64.c` 包含 FreeBSD 机器上下文和平台分支 | 用 PE 测试验证 Windows 异常、栈展开和线程行为 |
| server 就绪通知 | `server/fd.c` 可选择 `HAVE_KQUEUE` 实现，仍使用 `init_epoll` 等辅助函数名 | 保持描述符生命周期与就绪语义；名字不代表依赖 epoll |
| 线程唤醒与 NT 对象 | `dlls/ntdll/unix/sync.c` 有 kqueue 线程唤醒；快速 NT 对象路径和 `server/inproc_sync.c` 包含 `linux/ntsync.h` | 启动阶段使用 server 同步；启用加速前核对 FreeBSD 原生 NTSYNC ABI 和对象归属 |
| 目录变更通知 | `server/change.c` 使用 inotify，再回退到 dnotify；它与 server fd 就绪通知不同 | 原生实现需保持名称、重命名配对、子树变更、取消和溢出语义 |
| 系统与文件系统信息 | `dlls/ntdll/unix/system.c` 和 `file.c` 同时包含 FreeBSD 分支与 Linux `/proc` 代码 | 按实际调用逐项追踪，存在 FreeBSD 分支不代表所有信息类已实现 |
| 设备与桌面 | `dlls/winebus.sys/bus_udev.c`、`dlls/mountmgr.sys/`、显示与音频驱动 | 逐项使用经过验证的 FreeBSD 后端恢复能力；无图形配置本身没有实现这些替代 |

每个后端的验收同时要求正确的原生宿主路径和相应 Windows 可见行为。项目完整验收还要求检查依赖和 ABI，并在不使用 Linux 兼容服务的 FreeBSD 主机上运行。每次相关验证结果应记录实际 FreeBSD 版本、CPU、编译器和配置；本次初始化尚未确定最低支持的 FreeBSD 版本。

## 依据

- [Wine 11.20 源码](https://github.com/wine-mirror/wine/tree/wine-11.20) 对应上面的入口，检出身份见 `freebsd/upstream.txt`。
- [FreeBSD wine-devel port](https://cgit.freebsd.org/ports/tree/emulators/wine-devel/Makefile) 提供原生构建参考；本配置没有复制其可选 Linux API 头文件配置。
- [FreeBSD 原生 NTSYNC 头文件](https://cgit.freebsd.org/src/tree/sys/dev/ntsync/ntsync.h) 和 [FreeBSD NTSYNC 项目报告](https://www.freebsd.org/status/report-2026-04-2026-06/ntsync/) 区分原生接口与兼容模块；需在实际目标版本上核验可用性。
