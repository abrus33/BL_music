# Android Iteration 4：生命周期与前后台播放行为基线

本文记录 BL_music 在 Android 真机上的生命周期观察，属于测试与架构分析层。
开发者构建 Debug 诊断 APK，通过 adb 触发前后台/息屏动作，观测器读取原有 C++ 播放器状态。
不实现后台 Service、MediaSession、通知、Audio Focus 或新的播放器。

## 起点与证据范围

起始提交 `df835c5`，分支 `test/android-lifecycle-baseline`，开始时工作区干净。
沿用 Qt 6.10.2、NDK 27.2.12479018、SDK 36、JDK 21、ARM64 与已经验证的 OpenSSL 运行库。
已有构建/TLS 文档见 [构建记录](android-build.md)、[TLS 记录](android-tls.md)。
用户在本轮输入中确认登录、Cookie 链路和真机前台播放已通过；这些是用户提供的前置确认，
不伪造额外 Iteration 3 提交或旧测试日志。本轮只重新确认播放未被观测代码破坏。

当前状态：2026-09-08 已完成 A–E 真机观察及必要的耳机听感确认。
本 Iteration 的行为基线已建立，不代表正式后台播放能力已经实现。

## 对象所有权与真实调用链

```text
main 栈
├─ QGuiApplication app（先构造、后析构）
├─ QQmlApplicationEngine engine
└─ ApplicationContext applicationContext（覆盖 app.exec()）
   ├─ PlayerController
   │  ├─ QMediaPlayer
   │  ├─ QAudioOutput
   │  ├─ QNetworkAccessManager
   │  └─ 播放时创建的 QBuffer
   ├─ MediaResolver
   └─ PlaylistService（借用上述 controller/resolver，不拥有它们）
```

`PlayerController` 构造函数用 `new QMediaPlayer(this)` 和 `new QAudioOutput(this)` 创建二者。
`ApplicationContext` 用 `new PlayerController(this)` 拥有控制器。
控制器生命周期基本覆盖 Qt Application 的正常运行期；正常 `app.exec()` 返回后，
栈上的 ApplicationContext 析构，再按 QObject 父子关系释放控制器及媒体对象。
系统直接杀进程时不能假设会执行这些 C++ 析构。

收藏夹/队列播放链：

```text
QML → PlaylistService::createPlaylist / playAt
  → MediaResolver::resolve → BilibiliApiClient
  → PlaylistService::onMediaResolved
  → PlayerController::setSource + play
  → QNetworkAccessManager 下载完整媒体
  → QBuffer → QMediaPlayer::setSourceDevice(buffer, 空URL)
  → LoadedMedia + pendingPlay → QMediaPlayer::play → QAudioOutput
```

首页还存在 `resolveForOwner → HomePage::handleMediaResolved → controller.source/play` 路径。
QML 的 Main 用 `StackLayout` 放置三页，并向页面及常驻播放栏注入同一个控制器。
页面切换只改变当前页和过渡动画，没有销毁控制器，也没有隐藏即 pause/stop 的连接。
播放栏绑定控制器的 playbackState、position、duration，按钮调用 play/pause，进度条调用 seek。
本轮未修改这些路径。

两个源码细节影响基线解释：

- `QMediaPlayer::source()` 在本项目可以为空，因为实际输入是 QBuffer；需同时观察 sourceDevice。
- PlaylistService 的恢复分支虽然不显式调用 play，但 PlayerController 下载完成后仍设置 pendingPlay，
  LoadedMedia 回调会启动播放。不能仅凭“恢复时不自动播放”的旧注释判断实际行为。
  此外恢复位置使用 500 ms 单次定时器，媒体未及时加载就可能不 seek；本轮记录，不顺手修持久化。

## Activity、Process、Qt Application 与 Player

- **Activity** 是 Android Framework 管理的界面入口。本项目使用 QtActivity，继承 Kit 中 QtActivityBase；
  系统在界面失去前台、不可见或结束时调用生命周期方法，项目没有自定义 Java/Kotlin Activity。
- **Process** 是 Android 调度与回收的进程容器，包含 Java 与 C++ 对象。退后台不等于进程退出；
  进程被杀也不保证先调用 Activity.onDestroy 或 Qt aboutToQuit。
- **Qt Application** 是 `main` 中的 QGuiApplication，负责 Qt 事件循环，并非 Android Activity 对象。
- **Qt Application State** 是 Qt 平台层向应用提供的活动/可见性状态；不是播放器状态，也不是对象存活标志。
- **Player** 是控制器拥有的 QMediaPlayer，只有实际信号、快照与销毁/进程证据才能证明其状态。

本轮查询的本机 Qt6Android.jar 字节码显示：QtActivityBase 的 onResume 报告 Active(4)，
普通非多窗口 onPause 报告 Inactive(2)，onStop 报告 Suspended(0)。
非保留实例的 onDestroy 调用 terminateQt、退出 QtThread 和 System.exit；
保留非配置实例的分支不同。因此不能把 onPause、onStop 与真正销毁 Activity 混为一谈。
Qt 平台层还可能产生中间状态，最终以本轮 applicationStateChanged 日志为准。

Qt 的四个状态：Active（可交互）、Inactive（不处于活动交互状态）、Hidden（不可见）、
Suspended（挂起状态通知）。收到 Suspended 不足以证明进程已经冻结或音乐已停止。
应用原来没有 applicationStateChanged / Android 生命周期监听，本轮才增加只读观测。

依据：[Qt QGuiApplication](https://doc.qt.io/qt-6.10/qguiapplication.html#applicationStateChanged)、
[Qt ApplicationState](https://doc.qt.io/qt-6.10/qt.html#ApplicationState-enum)、
[Android Activity 生命周期](https://developer.android.com/guide/components/activities/activity-lifecycle)。
在线 Qt 6.10 文档可能显示较新的补丁版本；具体 API 与生命周期分支另由本机 6.10.2 头文件/JAR 核对。

## 最小观测方案

`src/platform/android/LifecycleDiagnostics.*` 是集中、只读的 Qt 观测器。
main 在 ApplicationContext 建好后挂载它，观测器由 app 拥有，通过弱引用读取现有播放器，
不会移动播放器、重设源、调整音量、自动恢复播放或创建后台保活对象。
通过已核对的 QObject 直接子对象关系找到唯一的一对 QMediaPlayer/QAudioOutput；
如果未来结构不再满足条件，则明确报告 attachment failed，不静默观察错误对象。

`[LifecycleProbe]` 记录状态切换、mediaStatus、错误、音频输出配置变化及每 5 秒的快照。
快照包括：单调 elapsedMs、application state、playbackState、mediaStatus、position、duration、
source 指纹/host/空状态、底层 source URL 空状态、sourceDevice 是否存在、audioOutput 关联、
device 空状态、volume、muted 和错误枚举。指纹用于同次播放关联，不输出完整 CDN 签名 URL。
对象销毁只记录名称，绝不在 destroyed 回调读取被析构对象的业务字段。

QAudioOutput 没有可用来证明真实出声的“正在输出声音”状态；volume/muted/设备关联只是配置证据。
定时器在后台可能延迟，缺少 tick 不能单独证明对象销毁。
Release 即使打开选项也不编入观测器；默认 OFF，不污染正常版本输出。

## 可复现构建与验证

在仓库根目录执行，依赖路径按已有 TLS 文档准备：

```bash
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export GRADLE_USER_HOME="$PWD/build/gradle-home"
env -u LD_LIBRARY_PATH "$HOME/Qt6/6.10.2/android_arm64_v8a/bin/qt-cmake" \
  -S . -B build/android-arm64-lifecycle-debug -G Ninja \
  -DCMAKE_MAKE_PROGRAM="$HOME/Qt6/Tools/Ninja/ninja" -DCMAKE_BUILD_TYPE=Debug \
  -DQT_HOST_PATH="$HOME/Qt6/6.10.2/gcc_64" \
  -DANDROID_SDK_ROOT="$HOME/Android/Sdk" \
  -DANDROID_NDK_ROOT="$HOME/Android/Sdk/ndk/27.2.12479018" \
  -DANDROID_ABI=arm64-v8a -DBUILD_TESTING=OFF \
  -DBL_ANDROID_OPENSSL_DIR="$PWD/build/android-tls-deps/openssl-3.5.8/arm64-v8a" \
  -DBL_ANDROID_LIFECYCLE_DIAGNOSTICS=ON -DBL_ANDROID_TLS_DIAGNOSTICS=OFF
env -u LD_LIBRARY_PATH cmake --build build/android-arm64-lifecycle-debug --target apk --parallel 4
env -u LD_LIBRARY_PATH cmake --build build/android-arm64-lifecycle-debug --target appcursor_music_qmllint
python3 scripts/check-android-elf.py build/android-arm64-lifecycle-debug/android-build/appcursor_music.apk
```

需要代理时沿用已有 Java 代理设置，不写入共享项目配置。
本次 APK SHA-256：`0bedb7eee5bdf01e3cb3f7edf1f42dcd6304bd384fb337dad78357bd4c966956`。
Android 构建、qmllint、APK 签名、ZIP 对齐、TLS ELF 检查通过；桌面构建与 5 个 CTest 目标通过。

## 真机矩阵与证据

按更新后的 AGENTS.md：能可靠自动执行的 adb 操作由 AI 执行，授权、声音、厂商手势等才请求人工。
不清空全局 logcat，不修改系统电池策略、音量或锁屏安全配置。
设备 V2417A / Android 16 / ARM64，本次进程 PID 2768。
安装 Success；冷启动 COLD、TotalTime 286 ms。初始播放持续 position 递增，
PlayingState / BufferedMedia，duration 2416342 ms，sourceDevice=true，audioAttached=true，NoError。
用户确认实际能听到音乐，输出来自耳机（纠正此前误选的“扬声器”）。

| Case | 自动动作 | 日志/进程证据 | 人工证据 |
| --- | --- | --- | --- |
| A Home 后台/回前台 | 22:11:31 Home，约 15 秒后返回 | 同 PID；Active→Inactive→Suspended→Active；230435 ms → 返回后 250683 ms | 用户确认耳机连续无中断 |
| B App 切换 | 22:12:11 系统设置，约 15 秒后返回 | 同 PID；相同 Qt 状态序列；270187 ms → 返回后 290691 ms | 用户确认耳机连续无中断 |
| C 锁屏/解锁 | 22:13:15 SLEEP，10 秒后检查；约 30 秒后 WAKEUP，用户解锁 | keyguard showing=true、secure=true；PID 2768 存活；22:13:51 回前台 Active，334042 ms → 首个 tick 370173 ms | 用户正常解锁，确认耳机连续 |
| D 短时息屏 | 同次锁屏延长至约 30 秒，于 10 秒/30 秒采样 | 两次均 Asleep，同 PID；Qt 最后一次通知为 Suspended；解锁后仍 Playing/Buffered | 用户确认该区间耳机连续 |
| E 最近任务移除 | 22:15:46 用 APP_SWITCH 打开最近任务，用户只划掉 BL_music 卡片 | 22:16:09 PID 2768 被 single-cleaner 结束；后续两次 pidof 为空，任务/Activity 移除 | 用户确认已划掉，耳机音乐停止 |

position 使用退出前的状态事件与返回后的定时快照，采样点包含返回后的几秒，不把增量当成精确后台时长。
A/B 的 sourceId 始终为 `ef70c2697fb1d585`，duration 2416342 ms，sourceDevice/audioAttached 为 true，
PlayingState、BufferedMedia、NoError，未观察到停止、源丢失、重置或对象销毁。
两次后台期间没有 5 秒 tick，返回瞬间的 Qt 状态事件仍带着旧 position，随后快照更新到继续前进的位置。
这说明主线程观测有间断，不能仅凭日志声称后台每一时刻正常；连续出声由用户听感补足。
本次未观察到 Hidden 信号，不能为了凑齐枚举而填写不存在的状态。

Case C/D 共享同一次 30 秒安全锁屏窗口：C 检查锁屏状态与随后解锁，D 检查息屏持续区间。
安全锁需要用户正常解锁，未修改锁屏配置或尝试输入凭据。
自动唤醒后的 22:13:49 采样仍保持安全锁；22:13:51 日志记录回前台，首个 tick 的 position 为 370173 ms。
稍后收到用户确认并采集的 22:15:27 快照为 464678 ms，其中包含解锁后的前台等待时间，
不能把它全部算成 30 秒息屏时间。回前台截图显示暂停图标与 07:46 / 40:16 的进度，
与附近的 Playing/position 快照相符，证明该采样时刻 QML 已刷新到实际播放状态。

Case E 最后一次 Inactive / Suspended 快照仍为 Playing，position 485924 ms。
`dumpsys activity exit-info` 中与本次 PID 对应的退出记录为：

```text
timestamp=2026-09-08 22:16:09.485 pid=2768
reason=10 (USER REQUESTED) subreason=21 (FORCE STOP) status=0
description=stop org.qtproject.example.appcursor_music due to single-cleaner
```

这是实际厂商划卡动作触发的系统清理结果，AI 没有执行 `am force-stop` 来代替划卡。
22:17:08 和 22:17:52 两次检查均无应用进程，后续 task/activity 记录也不再包含该任务，未观察到自动重启。
本次 PID 的退出前日志没有 aboutToQuit / destroyed 或致命异常记录；
不能据此认定对象仍存活，也不能推断本次执行了 QtActivity.onDestroy。
系统直接结束进程后，其中的 C++ 播放器和音频资源随进程消失；用户确认音乐停止。

后台定时器间断还有一个明确的配置线索：本次生成的 AndroidManifest 没有设置
`android.app.background_running`，也没有声明 Service；项目源码未设置
`QT_BLOCK_EVENT_LOOPS_WHEN_SUSPENDED`。
Qt 6.10 文档说明该 meta-data 默认 false，true 对应不阻塞挂起时的事件循环。
这与本轮 Suspended 期间没有 tick 的观察一致，但本轮未做开关对照实验，
不把一致性线索当作排除了系统调度因素的根因证明。
参见 [Qt Android Manifest 配置](https://doc.qt.io/qt-6.10/android-manifest-file-configuration.html#qt-specific-meta-data)。

所有时间以实际设备 logcat 和命令记录为准。
证据保存在被忽略的 `build/android-arm64-lifecycle-debug/device-baseline/`，不提交账号信息或截图。
主要索引：`install.txt`、`launch.txt`、`A-*/B-*`、`C-locked-*`、`D-screenoff-*`、
`CD-return-app-logcat.txt`、`CD-return.png`、`E-final-app-logcat.txt`、`E-exit-info.txt`、
`E-after-*`、`E-confirm-*`、`E-recents.txt`；Kit 生命周期字节码另存于 `qt-activity-lifecycle-bytecode.txt`。

## 架构判断与下一步建议

**1. 当前能否短时后台播放？** 能。在这台设备、本次已完整缓冲曲目、Home/设置约 15 秒以及
锁屏息屏约 30 秒的窗口内，原 QMediaPlayer 持续出声，回前台 position 前进、源和对象保持一致。
划掉任务卡片后厂商清理进程，声音停止；本阶段只记录该行为。

**2. 能否据此作为正式后台播放器？** 不能。后台期间 Qt 观测事件出现间断，
本轮没有覆盖曲目结束、自动下一曲、后台下载或队列定时保存。
进程调度、回收和后台执行限制仍由系统控制，也未覆盖长期 Doze、内存压力和厂商电池策略。
参见 [Android 进程生命周期](https://developer.android.com/guide/components/activities/process-lifecycle)。

**3. 播放器是否继续留在 C++？** 建议保留。当前对象所有权和短时播放结果没有要求
把 QMediaPlayer 搬出 PlayerController。
方案 A 保留现有 C++ Player，由 Android Service 承担平台后台执行与系统集成；
能复用媒体解析、QBuffer 下载路径、队列和 QML 状态绑定，但必须验证 Qt backend 在后台的实际限制。
Service 是 Android Framework 管理的无界面组件；未来可用于表达持续播放任务，
它本身不自动接管 C++ 对象，也不能保证本 ROM 的用户强制清理后继续播放。
方案 B 使用 Service 拥有的 Media3 Player，会迁移媒体输入与播放状态管理并增加 Qt 桥接，
尤其要重新处理当前带 Header 下载到 QBuffer 的路径，成本明显更大；目前没有证据要求此迁移。

**4. 下一 Iteration 最小目标？** 建议先验证“Qt 后台事件循环与跨曲衔接”：
沿用当前诊断，围绕已观察到的 tick 间断核查实际 Qt 挂起机制，
必要时以最小 Android package 配置做对照，检查后台定时器、EndOfMedia 和下一曲解析/下载是否能执行，
并验证回前台 QML 正常。Qt 文档提示挂起后绘制存在风险，不能只开启开关而不验证界面路径。
这一步为后续方案 A 的最小 Foreground Service 集成划清职责；若加入 Service，
还须显式处理 Activity 结束与 Qt 运行期的关系，不能仅声明一个 Service 就认为对象已独立。
本轮没有修改 Manifest、后台执行策略或实现上述下一阶段功能。

保留默认关闭、仅 Debug 编译的集中观测器，便于下一轮对照同一组状态；
删除它会失去已验证的采样工具，而当前门控使正常版本不产生这些输出。

## 当前验证与 Git

桌面构建和 5 个测试通过，Android APK 构建/签名/qmllint/TLS ELF 检查通过。
Release 配置即使开启观测选项，生成的 compile_commands 也不含观测源码与宏；
此项是配置检查，不声称已经构建 Release APK。
桌面 CTest 包括 Qt Quick 回归测试，但不执行 Android 专用观测器；后者由诊断 APK 构建与本轮真机覆盖。
真机安装、冷启动、QML 返回显示、前台播放回归和 A–E 行为观察全部完成。
其中任务移除导致停止是有效基线结果，不是“划掉后继续播放”功能通过。
只读代码复核未发现阻塞问题。分支 `test/android-lifecycle-baseline`，
本次提交主题为 `test(android): document lifecycle playback behavior`；不自动合并或推送。
AGENTS.md 已按用户要求更新自动化规则，但该文件沿用已有 Git 忽略设置，只在本地保存；
测试自动化原则也在本文记录，纳入本迭代提交。
