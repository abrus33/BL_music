# Android Iteration 1：Qt for Android 构建

本文属于开发环境与构建层，供开发者在 Linux 上生成当前项目的 Android 调试 APK。
它记录工具链的分工、构建命令和实际验证结果，避免依赖 Qt Creator 中未记录的本机配置。
开发者调用 Qt 的 `qt-cmake`，再由 CMake/Ninja 调用 NDK、`androiddeployqt` 和 Gradle；
这些工具编译并打包现有 `src/`、`qml/` 和 `icon/`，不替换 Qt/C++ 业务层。

## 范围

本次目标是生成 **arm64-v8a Debug APK**。复用现有 CMake 和 Qt 自带 Android 模板，
暂不创建自定义 `android/`、AndroidManifest、Java/Kotlin 或 JNI 桥接代码。
不处理手机布局、后台播放、系统媒体控制或发布签名；不执行设备安装。

桌面版本已由用户运行验证，本次不重复 desktop baseline / Iteration 0。

## 已安装的工具链

以下为本机检查结果。Qt Android 套件与主机 Qt 均使用 6.10.2，避免混用版本。

| 工具 | 版本 / 本机位置 | 职责 |
| --- | --- | --- |
| Qt Android | `~/Qt6/6.10.2/android_arm64_v8a` | 提供针对 Android ARM64 编译的 Qt 库和 CMake 工具链 |
| Qt Host | `~/Qt6/6.10.2/gcc_64` | 在 Linux 上运行 moc、rcc、QML 编译/扫描和打包工具 |
| Android SDK | `~/Android/Sdk`，Platform 36 | 提供 Android 平台接口与打包工具 |
| Build Tools | `36.0.0` | 编译 Android 资源、处理字节码、对齐和签名 APK |
| Android NDK | `27.2.12479018`，r27c | 提供 Clang、Android C/C++ 头文件及系统库，用于交叉编译 |
| JDK | OpenJDK 21，`/usr/lib/jvm/java-21-openjdk-amd64` | 运行 Gradle 并编译 Qt 提供的 Java 代码 |
| Ninja | 1.12.1，`~/Qt6/Tools/Ninja/ninja` | 执行 CMake 生成的构建任务 |
| CMake | 系统命令为 3.28.3；`qt-cmake` 使用 Qt 附带的 3.30.5 | 配置项目、组织编译及 APK 构建目标 |
| Gradle / Android Gradle Plugin | Qt 模板指定 8.14.3 / 8.10.1 | 下载依赖并完成 Android 包构建，无需全局安装 Gradle |

项目使用的 Quick、QuickControls2、Network、Multimedia、Svg Android 模块均已安装。
SDK 36、Build Tools 36.0.0、NDK 27.2.12479018 和 JDK 17 以上是
[Qt 6.10 文档中的配置要求](https://doc.qt.io/qt-6.10/android-getting-started.html)。

`arm64-v8a` 是此次选择的 ABI，即 ARM64 平台上的二进制接口约定。
它决定编译出的机器代码适用于哪种 CPU/运行环境，不代表已经检测过用户手机。

## 构建命令

在仓库根目录执行以下命令。路径变量只作用于当前终端；在其他机器上按安装位置调整。

```bash
export BL_QT_ROOT="$HOME/Qt6/6.10.2"
export BL_ANDROID_SDK="$HOME/Android/Sdk"
export BL_NINJA="$HOME/Qt6/Tools/Ninja/ninja"
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export GRADLE_USER_HOME="$PWD/build/gradle-home"

env -u LD_LIBRARY_PATH "$BL_QT_ROOT/android_arm64_v8a/bin/qt-cmake" \
  -S . -B build/android-arm64-debug -G Ninja \
  -DCMAKE_MAKE_PROGRAM="$BL_NINJA" \
  -DCMAKE_BUILD_TYPE=Debug \
  -DQT_HOST_PATH="$BL_QT_ROOT/gcc_64" \
  -DANDROID_SDK_ROOT="$BL_ANDROID_SDK" \
  -DANDROID_NDK_ROOT="$BL_ANDROID_SDK/ndk/27.2.12479018" \
  -DANDROID_ABI=arm64-v8a \
  -DBUILD_TESTING=OFF

env -u LD_LIBRARY_PATH cmake --build build/android-arm64-debug \
  --target apk --parallel 4

env -u LD_LIBRARY_PATH cmake --build build/android-arm64-debug \
  --target appcursor_music_qmllint
```

- 必须使用 **Android 套件**的 `qt-cmake`，它会加载 Qt 工具链并链接 NDK 工具链。
  仅将桌面 Qt 的构建目录换个名字，不能完成交叉编译。
- `QT_HOST_PATH` 指向同版本 Linux Qt：交叉编译时，生成代码的工具仍需在开发电脑上运行。
- `env -u LD_LIBRARY_PATH` 只为这条命令移除旧 Qt 库路径，不修改 shell 配置。
- `BUILD_TESTING=OFF` 只关闭这个 Android 构建目录的测试目标。现有 CTest 用例通过直接运行
  测试程序以及桌面 `offscreen` 环境执行，本次不配置 Android 设备测试；没有删除任何测试。
- `GRADLE_USER_HOME` 将下载缓存放在已忽略的 `build/` 中。清理该目录后需要重新下载依赖。
- `apk` 是 Qt 生成的打包目标；它不含 `adb install` 或设备启动操作。

预期产物位置（必须以构建成功和实际文件检查为准）：

```text
build/android-arm64-debug/libappcursor_music_arm64-v8a.so
build/android-arm64-debug/android-build/appcursor_music.apk
```

不提交 `build/`、APK、NDK/SDK、Gradle 缓存或调试密钥。

## 本次环境问题及证据

### 1. 主机 Qt 库版本冲突

首次配置报错：`libQt6Core.so.6: version 'Qt_6.10' not found`。
失败程序是 6.10.2 的 `qmlimportscanner`，但环境变量 `LD_LIBRARY_PATH` 指向
`~/Qt/6.9.3/gcc_64/lib`。使用 `env -u LD_LIBRARY_PATH ldd <qmlimportscanner路径>`
确认移除变量后加载的是 6.10.2 库，再用相同方式重试配置，配置通过。
这属于主机工具的动态库搜索路径问题，无需修改 QML 或 C++。

### 2. Gradle 下载与 Java 代理

首次打包时 C++ 已链接成功，但 Java 下载 Gradle 报 `Operation not permitted`，
原因是执行环境禁止联网。取得联网执行许可后，错误变为 `Read timed out`。
使用现有 HTTP 代理访问官方 Gradle 地址，重定向链最终返回 HTTP 200。

Java/Gradle 的代理应通过 Java 系统属性配置；不能仅依赖终端的 `HTTPS_PROXY`。
参见 [Gradle 网络配置](https://docs.gradle.org/current/userguide/networking.html)。
仅当本机确实运行该代理时，在 APK 构建前设置下面的参数（本机代理端口为 7897）：

```bash
export JAVA_TOOL_OPTIONS='-Dhttp.proxyHost=127.0.0.1 -Dhttp.proxyPort=7897 -Dhttps.proxyHost=127.0.0.1 -Dhttps.proxyPort=7897'
```

然后重试上面的 `apk` 目标。此变量也会传递到 Gradle 启动的 Java 进程。
它只是本机网络设置，不应写入共享 CMake 或 Qt 安装目录，也不应通过关闭 TLS 校验解决下载问题。

### 3. 下载中断导致 ZIP 校验失败

代理可访问之后，Gradle Wrapper 报 `zip END header not found` 和 SHA-256 不一致。
独立 curl 下载也报 `Transferred a partial file`，说明至少存在传输中断。
检查官方地址的 Range 响应为 HTTP 206，并核对 `Content-Range` 后，可以分段重试下载，
按顺序拼接，再核验整个 ZIP。仅检查文件存在或大小接近预期并不足够。

Gradle 8.14.3 的 `-bin.zip` 应为 137393837 字节，官方 SHA-256 为：

```text
bd71102213493060956ec229d946beee57158dbd89d0e62b91bca0fa2c5f3531
```

校验值来源：[Gradle 官方发行校验表](https://gradle.org/release-checksums/)。
校验通过的 ZIP 可放回失败日志中 `Download Location` 指向的 Wrapper 缓存位置，
再重试 `apk` 目标；不修改 Qt 模板的版本、下载地址或校验设置。

首次解析 Android Gradle Plugin 的依赖时，还遇到两个 Maven JAR 的 TLS 握手中断。
这类错误应先检查网络并利用缓存重试，不能据此修改 C++ 或降低 HTTPS 校验。
日志中的 Kotlin 标准库来自构建工具依赖，不意味着项目新增了 Kotlin 业务代码。

## 构建与运行调用链

```text
Android qt-cmake → CMake/Ninja → NDK Clang
  → libappcursor_music_arm64-v8a.so（包含原有 C++ 与 QML 资源）
  → androiddeployqt（收集 Qt 库、插件、资源，生成 Android 打包目录）
  → Gradle / Android Gradle Plugin → APK
```

Qt 的默认模板提供 `QtActivity`。Activity 是 Android Framework 管理的界面入口，
系统通过它管理应用界面生命周期；本项目暂由 QtActivity 承接系统启动及生命周期回调，
并通过 Qt 加载原生应用库，进入现有 `main()`，不自行实现生命周期函数。
APK 构建通过只证明构建链可运行，不能证明该启动链已经在真机上执行成功。

原有应用调用链保持为：

```text
main → QGuiApplication + QQmlApplicationEngine + ApplicationContext
  → initialize：加载 Cookie、配置网络 CookieJar、预热会话、按需检查登录
  → setInitialProperties：向 Main 注入 appContext
  → loadFromModule("cursor_music", "Main") → Qt 事件循环
```

Qt 默认打包配置为 `minSdkVersion=28`、`targetSdkVersion=36`、`compileSdk=36`。
`minSdkVersion` 是安装所需的最低系统 API；`targetSdkVersion` 告诉系统应用面向的行为版本；
`compileSdk` 决定编译 Java/Android 资源时使用的 API 集合。本次沿用 Qt 默认值。
默认包名为 `org.qtproject.example.appcursor_music`，后续独立迭代再处理正式包配置。
模板机制见 [Qt Android 部署文档](https://doc.qt.io/qt-6.10/deployment-android.html)。

## 验证记录

2026-09-07：**构建验证通过，等待真机验证**。

| 检查 | 实际结果 |
| --- | --- |
| 桌面构建 / desktop baseline | 本次未重复执行；沿用用户已验证的桌面状态 |
| Android CMake configure | 通过，Qt 6.10.2 / NDK r27c / arm64-v8a / Debug |
| Android C++ / QML 编译及链接 | 通过，原有源码生成 AArch64 ELF 共享库 |
| APK 打包 | 通过，Gradle `BUILD SUCCESSFUL`，33 个任务执行完成 |
| qmllint | 通过，`appcursor_music_qmllint` 退出码 0，无诊断信息 |
| APK ZIP 完整性和关键库 | 通过，包含主库、Qt Core/Quick/Multimedia、Manifest 和 classes.dex |
| APK 签名检查 | `apksigner verify --verbose` 通过，APK v2 签名有效 |
| APK 对齐检查 | `zipalign -c -P 16 -v 4` 通过；不等同于真机运行验证 |
| CTest / Qt Quick tests 运行 | 本次未运行；Android 构建设置为 `BUILD_TESTING=OFF`，未配置设备测试 |
| 真机安装 / 真机运行 / 功能测试 | 均未测试；未执行 adb 设备检查或部署 |

已生成 `build/android-arm64-debug/android-build/appcursor_music.apk`，约 79 MiB。
`aapt dump badging` 确认 ABI 为 `arm64-v8a`、最低 API 28、目标 API 36、
包名 `org.qtproject.example.appcursor_music`，启动入口为 QtActivity。
本次 APK SHA-256（重新构建或更换调试签名后可能变化）：

```text
539967612009a4c4054d9d4dbe6b4a1a40be8c2bbe0b40cf78c2ba877dcd7c5b
```

本地证据保存在 `build/android-arm64-debug/` 的 `apk-build.log`、`qmllint.log`、
`apk-badging.txt` 和 `zipalign.log`。这些构建产物与日志被 Git 忽略。
本次项目差异仅为本文档，没有修改 CMake、C++、QML 或现有测试。

保存构建准备记录使用中间提交 `build(android): prepare initial device deployment`。
它只表示 APK 构建准备就绪，不表示真机验证成功，不合并主分支或自动开始下一迭代。

已观察到的非阻断提示：CMake 提示 `Theme.js` 没有 `.pragma library`；打包扫描提示
无法解析 Windows/macOS/iOS 控件风格；Qt 模板使用的 Java source/target 8 在 JDK 21 下
有弃用提示，Gradle 也提示模板使用了将于 Gradle 9 不兼容的功能。
本次固定使用 Qt 模板的 Gradle 8.14.3，构建成功。保留日志，不据此修改界面或业务逻辑。

## 真机人工检查点

生成 APK 后停在构建验证阶段，不自动进入后续功能开发或设备部署。
后续首次部署只验证安装、启动、Main.qml 显示以及是否立即崩溃。
用户需用数据线连接手机，在开发者选项中开启 USB 调试，保持解锁，并允许电脑的调试授权。
开发者选项入口因品牌不同而异，找不到时先按手机品牌提供指导。
只有用户明确回复“手机连接好了”后，才运行 `adb devices`，确认设备与授权状态，
随后部署并根据 `adb logcat` 获取运行证据。未经真机验证不声称 Android 功能完成。
