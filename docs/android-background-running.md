# Android Iteration 6 Phase A：Qt 后台事件循环策略对照

## 目标和 Git 基线

仅开启 `android.app.background_running=true`，对照 Iteration 5 的默认 false。
不加入 Service、通知、MediaSession、Audio Focus 或锁；不修改 C++ 播放链及诊断事件。
`66a82e7` 已经 Reviewer 审查，无 Blocker / Major；工作区干净，提交父节点与
main/origin/main 同为 `65cb274`。fetch 后远端未前进，fast-forward 合并并推送 main，
从 `66a82e7` 创建 `test/android-background-running`，保留旧分支。

## 配置机制与单变量控制

当前 Kit 为 Qt 6.10.2 Android ARM64。基于其默认模板新增 android/AndroidManifest.xml，
保留部署占位符，由 CMake 的 QT_ANDROID_PACKAGE_SOURCE_DIR 指向该目录。
androiddeployqt 填充模板，Gradle 合并后打包为最终 APK binary manifest。

`android.app.background_running` 是 Qt-specific metadata，不是 Android Framework 保活开关。
本机 Qt6Android.jar 的 QtLoader 字节码确认：isBackgroundRunningBlocked 读取此 metadata，
为字符串 true 时返回 0，否则返回 1；loader 用返回值设置
`QT_BLOCK_EVENT_LOOPS_WHEN_SUSPENDED`。项目本身没有覆盖该环境变量。
0 表示 Qt 不因 Suspended 主动阻塞事件循环，并非阻止 Android/厂商冻结或杀死进程。
这是部署配置和 loader 实现证据，不冒充进程内 getenv 实测。

参见 [Qt 6.10 Manifest 文档](https://doc.qt.io/qt-6.10/android-manifest-file-configuration.html#qt-specific-meta-data)。
文档同时提醒挂起后绘制可能有风险，因此必须检查恢复后的 QML 和实际运行状态。

最终 APK 的 aapt xmltree 对比排除 XML 行号后，唯一语义差异为新增
android.app.background_running 布尔 true（type 0x12 / 0xffffffff）。
两份 APK 中 91 个 native library 内容逐字节相同；没有更换 Qt、OpenSSL 或业务二进制。
两者 minSdk=28、targetSdk=36、包名相同，没有 Service 声明。

## 构建与产物

证据目录：`build/android-background-running-evidence/`（忽略，不提交原始日志/账号上下文）。
构建复用 `build/android-arm64-lifecycle-debug`，lifecycle=ON、TLS probe=OFF。
在覆盖构建产物前单独保存原 APK：

| 产物 | 配置 | SHA-256 |
| --- | --- | --- |
| baseline-false.apk | metadata 缺省，Qt 默认 false | 2742b2d10bfb117dd8c11563c23934e77c71367c2f65ce6fa53085b5702f1514 |
| phase-a-true.apk | metadata=true | 6e28439e4ea8b91e5d96dd2d68e84c3061302542f7f1daf29c805f0d3869f829 |

桌面构建、5 项 CTest（含 Qt Quick）、Android configure/build、qmllint 通过。
APK 签名、zipalign 16 KiB 检查及两个 OpenSSL ELF 段检查通过。
以上均不等价于后台跨曲验证成功。

## Home 后台实验：完整链路成功

2026-09-26，V2417A / Android 16 / ARM64，PID 25927，Qt 主线程 TID 25971。
用户允许 vivo 安装确认后安装 Success，冷启动成功（646 ms）。
准备阶段用户曾手动拖动进度条/切歌，已明确确认停止操作；该段不计入实验。
重新从原 404 项队列选择 A(index=0)，确认 Playing、duration=242218，再开始干净对照。
A 为 BY2《凑热闹》，B 为 By2《爱丫爱丫》（index=1、duration=230570）。

| 设备时间 | Phase A 实际事件 |
| --- | --- |
| 21:37:21.728 | seek(222033)，与 Iteration 5 相同，距结束约 20.2 秒；随后 adb Home |
| 21:37:22.826 | Qt ApplicationSuspended；Launcher 为前台 |
| 21:37:41.986 | MEDIA_STATUS_RECEIVED 原始 status=6 → TRACK_END → TRACK_FINISHED_RECEIVED(index=0,resolving=false) |
| 21:37:42.011 | NEXT_TRACK_REQUEST → NEXT_INDEX=1 |
| 21:37:42.017 | resolve=10 开始 |
| 21:37:42.020–42.290 | API 请求 31/32 均为 HTTPS，HTTP200、networkError=0 |
| 21:37:42.304 | RESOLVE_FINISH success=true |
| 21:37:42.313–43.012 | 媒体请求 33，HTTPS、HTTP200、networkError=0 |
| 21:37:43.017–43.019 | 下载 3739641 字节，QBuffer open=true，SOURCE_READY attached=true |
| 21:37:43.026–43.029 | MEDIA_PLAY_CALL → PLAYER_STATE_SIGNAL state=1 |
| 21:37:47.046 | B position=3648；后台继续播放 |
| 21:38:37.045 | B position=53653，仍 Suspended；此时尚未返回 App |
| 21:38:41.178 | 自动回前台，Active / index=1 / Playing / position=57706 |

用户在保持手机桌面时确认“听到下一首，来自扬声器”。
返回截图显示 00:59 / 03:50、暂停图标；队列第 2 项 B 高亮，与 C++ 状态一致。
这不是恢复时补交：整条 seq488–523 发生在返回命令之前，且前后 dumpsys 均为 Launcher。

21:37:23 / 21:37:49 / 21:38:40 三次后台采样均无 do_freezer_trap；
前两次分别枚举 52 / 54 个线程，Qt 主线程等待点为 do_sys_poll，保存了内核 stack。
进程记录仍 allowFreeze=true，未观察到该进程 isFrozen=true；不解释为冻结能力已被关闭。
原始证据：Home-start/after-end/late 的 logcat、threads、processes、activity 状态，
Home-system-logcat.txt，以及 Home-return 截图与日志。

Baseline（Iteration 5，false）在 Home 后没有交付 EndOfMedia，后续采样 48 个线程均
为 do_freezer_trap，回前台才恢复下一曲。Phase A（true）在 Home 后交付了事件并完成真实
解析、网络下载和播放；本窗口内没有采到冻结。
两轮没有完全相同的厂商调度时序，不能据此断言 Qt 配置关闭了系统 freezer 或保证永久运行。

## 锁屏跨曲

同一 PID 和 A/B 队列，21:39:52.844 seek(222033) 后 adb KEYCODE_SLEEP。
21:39:53.001 Qt Suspended，21:39:54 系统 Asleep、keyguard showing=true / secure=true。

| 设备时间 | 锁屏期间事件 |
| --- | --- |
| 21:40:13.087 | 原始 status=6 → TRACK_END → TRACK_FINISHED_RECEIVED |
| 21:40:13.105–13.110 | NEXT_INDEX=1 → resolve=12 |
| 21:40:13.294 / 13.421 | API 请求 37/38 返回 HTTP200、networkError=0 |
| 21:40:13.426 | 解析完成 |
| 21:40:14.196 | 媒体请求 39 返回 HTTP200、networkError=0 |
| 21:40:14.197–14.198 | 下载 3739641 字节，QBuffer/source ready |
| 21:40:14.201–14.203 | MEDIA_PLAY_CALL → B Playing |
| 21:40:21 | 再次确认仍 Asleep、安全锁显示，未恢复前台 |
| 21:41:24.885 | 用户解锁后 Qt Active，index=1、Playing、position=70336 |

API 和媒体请求均为 HTTPS，真实发起并完成，不依赖假请求或媒体缓存。
用户确认“能听到自动切换，已解锁”。21:42:02 返回采样 index=1、position=107626，
截图约 01:48 / 03:50、暂停图标，队列 B 高亮。后者含解锁后的前台时间，不算锁屏时长。
21:39:55 / 21:40:21 枚举 53 / 55 个线程，均未见 do_freezer_trap，保存了 stack/wchan。
证据为 Lock-start/after-end/return 及相应截图、Lock-system-logcat.txt。
系统日志筛选未发现本次 PID/包名相关冻结行；这只表示未捕获该日志，不代替线程采样。

## 因果结论与限制

1. 本次单变量对照与 Qt suspend policy 参与原事件交付阻塞的解释一致；
   尚未单独隔离它与厂商调度/freezer 的因果关系。
   开启后 Home 和安全锁屏期间均可完成 EndOfMedia → trackFinished → next/index →
   MediaResolver → HTTPS callback → 媒体下载 → QBuffer/source → QMediaPlayer::play → Playing。
   不再仅凭 QTimer 判断：真实业务事件和用户听感相互印证。
2. 本次五次后台线程采样未见 freezer；不证明系统/厂商 freezer 被禁用，
   也没有证明 baseline 的全部冻结机制或最初冻结时刻。allowFreeze 仍为 true。
3. 没有加入或验证 Foreground Service，因此不能回答它是否改变当前设备行为。
   本轮结果为 Phase A 成功，按要求不执行 Phase B。
4. 现有 C++ QMediaPlayer 可以继续作为唯一播放器核心；本次无证据要求迁移。
5. 已验证的是这台设备在当前短时、USB 连接条件下的两次跨曲；长期后台、Doze、
   内存压力、断开 USB、电池策略变化均未测试。Qt metadata 只取消 Qt 自身阻塞，
   正式持续播放仍可能需要 mediaPlayback FGS 向系统表达持续任务及其用户可见性。
   下一轮应先评估正式后台执行身份和生命周期，再决定 MediaSession/通知集成，
   不能直接宣称正式后台播放器已经完成。

## 验证汇总

桌面构建：通过；5 项测试：通过；qmllint：通过；Android configure/build/APK：通过。
APK 真机安装、冷启动、前台 A 播放、Home 后台跨曲、锁屏跨曲、返回 QML 一致性：通过。
用户两次确认自动切歌实际声音；Home 明确来自扬声器。
构建中的其他平台 QML style 导入警告沿用既有情况，没有新增构建失败。
既有 m_resolveGen 和 m_pendingPlay 时序风险没有在本实验复现，未修改。


## 范围与后续

配置改动已通过只读 Reviewer，无 Blocker / Major。
无论 Phase A 成功、失败或部分成功，本轮都不自动进入 Foreground Service Phase B。
