# Android Iteration 5：后台事件链与跨曲连续播放验证

## 范围与 Git 基线

2026-09-26，从 `65cb274` 创建 `test/android-background-transition`。
上一轮已经 Reviewer 审查及真机验证；经用户明确授权，先确认工作区干净、
`main == origin/main == df835c5`，再以 fast-forward 合并并推送 `main → 65cb274`。
保留 `test/android-lifecycle-baseline`，没有制造 merge commit。

本轮只添加默认关闭的 Android Debug 事件诊断，验证原有业务链。
不调整 Manifest/background_running、播放策略或对象所有权，不加入 Service、MediaSession、
通知、Audio Focus、Media3、WakeLock、WifiLock 或电池白名单。

## 源码链与所有权

```text
FavoritesPage.onMediaActivated
→ PlaylistService::createPlaylist / playAt
→ resolveAndPlayCurrentItem
→ MediaResolver::resolve → resolveInternal

QMediaPlayer::mediaStatusChanged(EndOfMedia)
→ PlayerController::onMediaStatusChanged
→ trackFinished
→ PlaylistService::onTrackFinished（m_isResolving / 空队列门控）
→ next → computeNextIndex → 更新 m_currentIndex / 通知 QML
→ resolveAndPlayCurrentItem → resolve(id, type, bvid, 0)

视频 type=2：getVideoCid → getVideoPlayUrl → getWbiKeys → getJson
→ HttpClient::networkManager()->get → 独立 reply.finished 回调
音频 type=12：getAudioStreamUrl → HttpClient::get → sendRequest / handleReply
→ reply.finished → HttpClient::requestFinished → 音频 URL 回调

→ MediaResolver::mediaResolved → PlaylistService::onMediaResolved
→ PlayerController::setSource(url) + play()
→ 独立 m_nam->get（完整媒体下载）→ reply.finished → readAll
→ new QBuffer(this) → setData → open(ReadOnly)
→ QMediaPlayer::setSourceDevice(buffer, 空 URL)
→ m_pendingPlay = true
→ mediaStatusChanged(LoadedMedia) → onMediaStatusChanged → QMediaPlayer::play
→ playbackStateChanged → onStateChanged → stateChanged → QML
```

ApplicationContext 是 main 栈对象，拥有 PlayerController、PlaylistService、MediaResolver 和 HttpClient。
PlayerController 拥有 QMediaPlayer、QAudioOutput、媒体下载 QNetworkAccessManager 和当前 QBuffer。
HttpClient 拥有 API 请求 QNetworkAccessManager；网络管理器管理 reply，回调通过 deleteLater 释放。
切源时先断开、取消旧下载并 deleteLater；旧 QBuffer 先从播放器解除关联，再删除。
下载局部 QByteArray 通过 setData 留存在 QBuffer 内，不因回调返回而悬空。
PlaylistService 借用控制器、Resolver 和 settings，不另建播放器。
后台生命周期不会改变这些 QObject 父子关系，但回调及延迟删除的执行时间必须实测。

已有风险只记录，不修复：

- m_resolveGen 递增但 onMediaResolved 不校验响应编号，日志中的 currentGeneration 不代表匹配成功。
- m_pendingPlay=true 位于 setSourceDevice 之后，保留顺序并记录前后值。
- 音频 URL 分支使用共享 requestFinished，不能把并发响应归属当成已经验证安全。
- index / title 早于解析完成更新，UI 显示下一首不等于下一首实际 Playing。

## 事件证据设计

复用 `BL_ANDROID_LIFECYCLE_DIAGNOSTICS`（默认 OFF，CMake 仅 Android Debug 编译实现及宏）。
关闭时宏不求值参数；不把新增日志保留在 Release 正常输出中。
`[TransitionProbe]` 带进程内递增 seq、单调 elapsedMs、Qt application state 和 JSON 字段。

| 事件 | 证明的边界 |
| --- | --- |
| MEDIA_STATUS_RECEIVED | 业务槽入口收到的原始 status，在任何同步 next/切源之前记录 |
| MEDIA_STATUS_SIGNAL | 观测器收到的 signal 参数与当时 getter，二者可能因重入不同 |
| TRACK_END / TRACK_FINISHED_RECEIVED | 控制器发送自然结束及队列接收；接收行包含 resolving 门控 |
| NEXT_TRACK_REQUEST / NEXT_INDEX | next 被调用及索引计算结果 |
| PLAYLIST_RESOLVE_START / RESOLVE_START | 队列项、generation，以及独立解析编号 |
| NETWORK_START / NETWORK_FINISH | reply 独立请求号、请求 URL 指纹、HTTPS 标志、HTTP 状态和网络错误枚举 |
| RESOLVE_FINISH / PLAYLIST_RESOLVE_FINISH | 捕获的解析编号、结果、source 指纹及队列接收时状态 |
| DOWNLOAD_CALLBACK / DOWNLOAD_FINISH | 媒体下载业务回调进入、成功读取字节数 |
| DOWNLOAD_CANCEL | 原有切源取消路径；该路径 disconnect 会移除 finished 监听，不能误判成网络卡死 |
| SOURCE_DEVICE_SET / SOURCE_READY | 缓冲已打开/大小及 setSourceDevice 返回后的设备关联 |
| PENDING_PLAY_SET / PLAY_REQUEST / MEDIA_PLAY_CALL | 待播放标志、控制器请求、真正调用底层 play 的位置 |
| PLAYER_STATE_SIGNAL | 实际 playbackStateChanged 参数；Playing 与 source 指纹关联 |

原有低频 LifecycleProbe 快照增加 index，供前后台返回一致性核对；没有增加定时轮询频率。
新日志不记录完整 URL、Cookie、token、响应正文或错误正文。既有业务日志可能包含媒体信息，
原始 logcat 留在被忽略的 build 目录，不纳入 Git。

## 验证进度

- 桌面构建：通过；5 项 CTest（含 Qt Quick）：通过。
- Android ARM64 原生编译、APK 打包、qmllint：通过。
- APK 签名、zipalign、OpenSSL ELF 检查：通过。
- APK SHA-256：`2742b2d10bfb117dd8c11563c23934e77c71367c2f65ce6fa53085b5702f1514`。
- 只读 Reviewer：未发现 Blocker / Major。
- 真机安装、启动、前台自然 A→B 对照：通过。
- Case A Home 后台自然跨曲：实验完成，行为失败；回前台后才继续下一曲。
- Case B 锁屏跨曲：未测试；按要求，Case A 已发现明确阻断，不机械继续矩阵。

构建复用上一轮 Qt 6.10.2 / ARM64 / NDK 27.2.12479018 / SDK36 / OpenSSL 工具链，
目录 `build/android-arm64-lifecycle-debug`，开关 lifecycle=ON、TLS probe=OFF。
构建和本轮真机原始证据目录：`build/android-arm64-lifecycle-debug/device-transition/`。

设备初检遇到 Linux USB 节点无写权限。用户为当前节点添加临时 ACL 后，
adb 从 no permissions 变为 unauthorized；用户允许 USB 调试后已恢复 device 状态。
安装命令随后触发 vivo 外部来源应用确认；用户允许后安装 Success，启动成功。
不将设备连接问题解释为应用缺陷。

## 实验顺序

准备真实两曲顺序队列 A、B，验证前台播放与 seek；保存前置状态。
Case A：A 距结尾约 10–20 秒 → Home → 保持后台等待自然结束，记录全链及 PID。
先在后台判定 B 是否 Playing；需听感时人工确认，然后才回前台检查 index、position、状态与 QML。
Case A 若明确失败，先定位最后一个已收到的业务事件，不机械执行锁屏实验。
Case B 仅在 A 通过后执行同一链路的锁屏版本；安全解锁由用户完成。

最终结论必须区分：后台未投递 EndOfMedia、队列门控、Resolver/API、媒体下载、source/loading、
Playing 但无声等边界。单独缺少 QTimer tick 不足以判定事件循环停止。
本轮不修改策略，以下结果用于下一 Iteration 的架构决策。


## 2026-09-26 真机结果

设备 V2417A / Android 16 / ARM64；整个实验 PID 21309，Qt 主线程 TID 21544。
沿用已有 404 项队列，选择相邻 index 0/1，不更换业务播放器或注入假请求。
A 实际 duration=242218 ms，B duration=230570 ms，均为 type=2 视频音频流。
用户本轮确认的实际输出是**扬声器**，与上一轮耳机测试分开记录。

### 前台自然跨曲对照

21:07:18.111，经现有 Slider → seek(222033)，距 A 自然结束约 20.2 秒。
保持前台，无手动 next：

| 设备时间 | 真实事件 |
| --- | --- |
| 21:07:38.373 | MEDIA_STATUS_RECEIVED status=6（EndOfMedia）→ TRACK_END → TRACK_FINISHED_RECEIVED，resolving=false |
| 21:07:38.395 | NEXT_TRACK_REQUEST，NEXT_INDEX=1 |
| 21:07:38.421 | PLAYLIST_RESOLVE_START / RESOLVE_START，resolve=3 |
| 21:07:38.422–38.682 | API 请求 11/12：HTTPS=true，HTTP200，networkError=0 |
| 21:07:38.686 | RESOLVE_FINISH success=true，随后队列接收 |
| 21:07:38.689–39.274 | 媒体请求 13：HTTPS=true，HTTP200，networkError=0 |
| 21:07:39.277 | DOWNLOAD_FINISH bytes=3739641；QBuffer open=true |
| 21:07:39.278–39.285 | SOURCE_READY attached=true → LoadedMedia → MEDIA_PLAY_CALL → PLAYER_STATE_SIGNAL state=1 |

证据：`foreground-B-app-logcat.txt` seq69–104。B position 后续持续增加。
这证明前台真实链路和事件诊断可工作；既有 Resolver/队列假对象测试不能替代此实验。

### Case A：Home 后台

重新通过队列 playAt(0) 播放 A，然后使用同一进度条位置：

- 21:08:50.697：seek=222033，duration=242218。
- 21:08:51.129：Inactive；21:08:52.111：Suspended，最后 position=222421、index=0。
- 21:09:27：后台等待约 35 秒后，PID 仍为 21309，前台为 Launcher。
  没有新的 EndOfMedia / TRACK_END / next / B resolve / B 网络请求。
- 用户保持桌面，确认“没有自动播放”。此时没有把 App 拉回前台来冒充后台成功。
- 后续后台线程采样中，所有列出的应用线程（包括 qtMainLoopThread、QNetworkAccessManager、
  QFFmpeg 和 AudioTrack）wchan 均为 `do_freezer_trap`。
- 同一进程 dumpsys 中厂商扩展的末尾字段为 `isFrozen=true / allowFreeze=true`。
  注意同一段还有标准 optimizer 状态行 `isFrozen=false`，不能只看这一行否认厂商冻结；
  两处字段及线程等待点均保留在原始证据中。

证据：`A-before-*`、`A-home-*`、`A-background-*`、`A-thread-wchan.txt`、`A-processes.txt`。
此处定位到 **EndOfMedia 尚未交付到 PlayerController 业务槽之前**。
它不是“EndOfMedia 已到但 next 被 m_isResolving 拦截”，也不是后台 Resolver/CDN 请求失败：
这些下一曲请求当时根本没有发起。

### 回前台对照与状态一致性

21:10:35 执行 am start 返回原 Activity，未重启进程、未点击 next。

- 21:10:35.408：首次收到延迟的 EndOfMedia（seq140），随后 TRACK_END / 队列接收。
- 21:10:35.448：index=1；21:10:35.461：resolve=5 开始。
- API 请求 17/18、媒体请求 19 均为 HTTPS、HTTP200、networkError=0。
- 21:10:36.597：下载 3739641 字节，QBuffer 已打开，SOURCE_READY attached=true。
- 21:10:36.603：B 实际进入 Playing，duration=230570；后续 position=4181、9386、14400 ms。
- 返回截图显示暂停按钮和 00:19 / 03:50；队列截图中第 2 项 B 高亮，与 index=1 一致。
- 用户确认回前台后 B 已从扬声器恢复出声。
- 回前台 Qt 主线程等待点恢复为 `do_sys_poll`，进程状态为 top-activity；同 PID 持续运行。

**不能把回前台初期的 app=Suspended 行计作后台成功。**
seq139–148 虽然还读到旧 Qt 状态，但发生在 am start 恢复阶段；Android Activity 恢复与
Qt applicationStateChanged 通知不是一个原子操作，随后日志才显示 Active。
判断必须结合命令时间、Activity 状态和事件序列，不能只筛选 app=Suspended 字符串。

证据：`A-return-launch.txt`、`A-return-immediate-*`、`A-return-*`、`A-return.png`、
`A-return-queue.png`、`A-return-main-wchan.txt`、`A-return-processes.txt`。

## 结论、限制和下一阶段

1. **本次后台期间 C++ 未收到媒体结束事件**，业务跨曲链受实际影响，已经超出 QTimer 日志间断。
2. **next、Resolver、API、下载、QBuffer、新曲 Playing 均未在该后台窗口执行**；
   恢复前台后全部执行成功。后台网络能力本身标记为“未到达/未验证”，不能写成网络失败或通过。
   B 的重新播放实际发出了新的网络请求，不是缓存掩盖了网络调用。
3. **直接观察到后台进程冻结**，但没有采到冻结开始的精确时刻，也没有 Qt backend 产生事件的底层时间戳。
   因而不能断言“底层从未产生 EndOfMedia”，也不能证明冻结是初始事件延迟的唯一因素。
   能确定的是后台事件交付/执行受阻，而非已有证据指向播放器数据丢失或生命周期悬空。
4. 本次 APK Manifest 未设置 `android.app.background_running`；Qt 文档说明其默认 false，
   与挂起时事件循环策略相关。这仍是待对照的 Qt 层因素，不能把它代替真机冻结证据。
   参见 [Qt Android Manifest 配置](https://doc.qt.io/qt-6.10/android-manifest-file-configuration.html#qt-specific-meta-data)。
5. **下一 Iteration 可以进入最小 Foreground Service 方案的设计与验证**，保留 C++ PlayerController/QMediaPlayer，
   目标是给持续播放明确的 Android 后台执行身份，并重跑本次跨曲证据链。
   同时必须单独核对 Qt 事件循环挂起策略：增加 Service 不自动证明 Qt 回调会运行，
   更不承诺厂商强制清理后继续播放。本轮没有实现该方案或开启任何保活开关。

本轮完成标准是获取行为及失败边界，不是让后台跨曲一定成功。
锁屏跨曲、后台网络独立可用性、长期后台、Doze、划卡继续播放均未验证。
保留最小事件诊断，以便后续在相同业务链上对照；不修改两处尚未复现的竞态行为。
