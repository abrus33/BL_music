# Android Iteration 2：TLS / HTTPS 基础能力

本文属于 Android 构建与诊断层，记录开发者如何编译、部署和验证 Qt TLS 运行库。
构建脚本调用现有 NDK 与 OpenSSL 构建系统，CMake 把产物交给 androiddeployqt；
可选诊断模块由 main.cpp 调用 Qt Network，不替代 HttpClient 或任何业务服务。

**当前阶段：Iteration 2 真机验证通过。修订 APK 已正常启动并完成一次有效 HTTPS 请求。**

## 原始证据与根因

调查基于 Iteration 1 的实际 APK、Qt Kit 和首次真机日志，没有把电脑的 OpenSSL 状态
当作手机状态。原始日志保存在被忽略的
`build/android-arm64-debug/device-validation-2026-09-08/app-logcat.txt`：

```text
49:  qt.multimedia.symbolsresolver: Couldn't load ssl library
75:  qt.tlsbackend.ossl: Failed to load libssl/libcrypto.
76:  qt.network.ssl: No functional TLS backend was found
143: qt.network.ssl: QSslSocket::connectToHostEncrypted: TLS initialization failed
```

第 73–74 行还记录系统 `/system/lib/libcrypto.so` 不允许从应用的 native library namespace
加载。Android 将应用能访问的原生库限定在其加载命名空间中，应用不能依靠系统私有加密库。

| 检查对象 | 实际发现 |
| --- | --- |
| Qt Kit | Qt 6.10.2 `android_arm64_v8a`，Host Qt 6.10.2 `gcc_64` |
| 工具链 | NDK 27.2.12479018、SDK 36、JDK 21，与 Iteration 1 相同 |
| CMake | 已链接 `Qt6::Network`，不是遗漏 Qt Network 模块 |
| 旧 APK | 含 `libQt6Network_arm64-v8a.so` 和 `libplugins_tls_qopensslbackend_arm64-v8a.so` |
| 旧 APK 的 OpenSSL | 没有真正的 `libssl*.so` / `libcrypto*.so`；FFmpegStub 是加载转接层，不提供加密实现 |
| Kit backend | OpenSSL 插件；构建版本字符串为 OpenSSL 3.0.7，实际插件与 APK 中的哈希一致 |
| Qt 源码 | Qt 6.10.2 的 `qsslsocket_openssl_symbols.cpp` 在 Android 默认使用 `_3` 后缀动态加载 OpenSSL 3 |
| 权限 | 旧 APK 已有 INTERNET 权限，不需要修改 Manifest |
| Qt Creator 配置 | 指向不存在的 `~/Android/Sdk/android_openssl`，不能给当前 APK 提供运行库 |

结论是 **APK 缺少当前 OpenSSL backend 所需的 Android 运行库**。
插件存在不等于插件能够初始化；实际 activeBackend、supportsSsl 和 runtimeVersion
仍需要本次诊断 APK 的真机日志确认。

## 谁负责 HTTPS 中的 TLS

```text
ApplicationContext::initialize → BilibiliApiClient::warmUp
  → HttpClient → QNetworkAccessManager → QSslSocket
  → Qt OpenSSL TLS backend → libssl_3.so → libcrypto_3.so
```

`QNetworkAccessManager` 管理请求和 HTTP，`QSslSocket` 提供 Qt 的 TLS socket 接口。
TLS backend/plugin 是接口的具体实现；本 Kit 的 OpenSSL backend 调用 OpenSSL，
由 `libssl` 执行 TLS 握手等操作，`libcrypto` 提供加密和证书相关基础能力。

`.so` 是 shared library，即运行时加载的共享机器码库。Android ABI 决定机器码与调用约定，
此次必须使用 `arm64-v8a` Android 库；Linux 桌面库不能复制到手机使用。
桌面能通过系统库路径找到 OpenSSL，并不意味着 APK 已打包 Android 版本。
Qt Android deployment 会收集 Qt 库与插件，但外部 OpenSSL 运行库需要显式提供。

使用 [Qt Android OpenSSL 部署说明](https://doc.qt.io/qt-6.10/android-openssl-support.html)
和 [QT_ANDROID_EXTRA_LIBS](https://doc.qt.io/qt-6.10/cmake-target-property-qt-android-extra-libs.html)
所述方法，将两库装入 APK 并由 Qt 启动加载。通过 OpenSSL 的 `shlib_variant` 构建扩展，
让链接器直接生成一致的文件名、SONAME（库的身份）和 NEEDED（库的依赖名），
避免 Android loader 再寻找系统 `libcrypto.so`。不在 ELF 链接完成后用 patchelf 改名。
沿用 Qt 默认 `_3` 后缀，不额外设置 `ANDROID_OPENSSL_SUFFIX` 或强制切换 backend。

## 编译固定来源的运行库

选择官方 OpenSSL **3.5.8 LTS** 源码，用现有 NDK 构建，而非替换本机系统库。
Qt 的 build-time 版本保持 3.0.7；OpenSSL 的相同主版本兼容策略允许使用较新的 3.x 运行库，
最终兼容性仍通过 APK 和真机检查确认。来源与支持策略：
[OpenSSL source](https://openssl-library.org/source/)、
[OpenSSL release strategy](https://openssl-library.org/policies/releasestrat/)。

固定下载地址：
[openssl-3.5.8.tar.gz](https://github.com/openssl/openssl/releases/download/openssl-3.5.8/openssl-3.5.8.tar.gz)。
官方 SHA-256：

```text
a8f84a39918ec6415ce765d9b429d313ba97b8143169c172e734b9514464f5b2
```

脚本需要 Linux 上的 Bash、Perl、Make、curl、tar、sha256sum，静态检查工具需要 Python 3。
脚本不执行 `make install`，也不再依赖 patchelf。

```bash
export BL_ANDROID_NDK="$HOME/Android/Sdk/ndk/27.2.12479018"
bash scripts/build-android-openssl.sh
# 若已经取得并校验源码，可把本地 tar.gz 的绝对路径作为唯一参数；脚本仍会校验 SHA-256。
```

如果网络中断留下残缺包，删除那个下载缓存文件后重新运行，或传入重新取得的完整归档；
不要绕过哈希验证。
本次代理下载出现中断，分段取得后对完整归档校验通过。
生成目录为 `build/android-tls-deps/openssl-3.5.8/arm64-v8a`。
脚本固定 ARM64、API 28 和 16 KiB ELF 段对齐；`no-module` 保留内置 default provider，
不依赖额外 provider 模块文件。`no-apps/no-docs/no-tests` 只控制依赖库构建内容，
不删除本项目测试，也不代表运行过 OpenSSL 自身的 Android 测试。
本地配置继承 OpenSSL 的 `android-arm64` target，仅设置 `shlib_variant="_3"`，
通过 `OPENSSL_LOCAL_CONFIG_DIR` 加载，不修改校验过的源码。该选项也改变导出符号的版本命名空间，
ssl 和 crypto 成对构建；当前 Qt backend 使用未版本化的函数名动态解析符号。
机制见源码 `Configurations/README.md` 中的 `shlib_variant` 说明，
以及 [OpenSSL 配置说明](https://github.com/openssl/openssl/blob/openssl-3.5.8/Configurations/README.md)。
许可证由 `LICENSES/OpenSSL.txt` 保留，并编入 APK 的 `:/licenses/OpenSSL.txt` 资源。

## 构建诊断 APK

从仓库根目录执行，沿用 Iteration 1 的 Kit、SDK、NDK 和 Gradle 缓存。
新目录保留了原始失败 APK 和日志，便于比较。

```bash
export BL_QT_ROOT="$HOME/Qt6/6.10.2"
export BL_ANDROID_SDK="$HOME/Android/Sdk"
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export GRADLE_USER_HOME="$PWD/build/gradle-home"

env -u LD_LIBRARY_PATH "$BL_QT_ROOT/android_arm64_v8a/bin/qt-cmake" \
  -S . -B build/android-arm64-tls-debug -G Ninja \
  -DCMAKE_MAKE_PROGRAM="$HOME/Qt6/Tools/Ninja/ninja" \
  -DCMAKE_BUILD_TYPE=Debug \
  -DQT_HOST_PATH="$BL_QT_ROOT/gcc_64" \
  -DANDROID_SDK_ROOT="$BL_ANDROID_SDK" \
  -DANDROID_NDK_ROOT="$BL_ANDROID_SDK/ndk/27.2.12479018" \
  -DANDROID_ABI=arm64-v8a -DBUILD_TESTING=OFF \
  -DBL_ANDROID_OPENSSL_DIR="$PWD/build/android-tls-deps/openssl-3.5.8/arm64-v8a" \
  -DBL_ANDROID_TLS_DIAGNOSTICS=ON

env -u LD_LIBRARY_PATH cmake --build build/android-arm64-tls-debug --target apk --parallel 4
env -u LD_LIBRARY_PATH cmake --build build/android-arm64-tls-debug --target appcursor_music_qmllint
python3 scripts/check-android-elf.py build/android-arm64-tls-debug/android-build/appcursor_music.apk
```

如果 Gradle 需要本机代理，参照 [已有构建文档](android-build.md) 的 Java 代理配置。
普通 Android 构建仍需提供 OpenSSL 目录，但省略诊断开关（默认 OFF）即可不编入探针。
关闭诊断不会关闭部署修复；本次将诊断作为可选验证工具保留，不把输出散入业务类。

## 诊断与真机人工检查点

诊断 APK 在 QML 创建成功后发起一次独立 `https://www.qt.io/robots.txt` 请求。
独立 manager 不共享业务 Cookie/缓存/连接，不记录正文或认证信息，不跟随重定向，
保留默认服务器证书与主机名验证，30 秒到期终止并单独报告超时。
原有应用启动预热流程保持原样；无需用户进行登录或播放操作。

`[AndroidTlsProbe]` 日志包括：

- `supportsSsl`、`availableBackends`、`activeBackend`；
- `buildVersion`、`runtimeVersion`；
- TLS `encrypted` 信号；
- 最终 `result`、HTTP 状态、Qt 网络错误枚举、字节数与错误说明。

| result | 含义 |
| --- | --- |
| tls-unavailable | backend/运行库初始化失败；未开始请求 |
| certificate-error / tls-handshake-error | 已有 TLS 能力，但本次证书验证或握手失败 |
| dns-error / network-error / timeout | 名称解析、socket/传输或截止时间问题 |
| http-status-error | HTTP 非 2xx（包括重定向）或缺少状态码；不能等同于 TLS 初始化失败 |
| unencrypted-response | 没有本次 TLS 连接证据，不能作为成功 |
| ok | 本次有加密连接、HTTP 2xx 且 Qt 网络错误为 NoError |

探针使用静态文本地址，不涉及业务 API。业务层错误不纳入本阶段判断。

**默认在 APK 构建成功后停止，等待用户确认手机连接与 USB 调试授权。**
本次用户随后明确授权：当前 Iteration 内如再出现问题，修复和重新构建后可直接真机复测，
无需重复等待回复。该授权仅适用于本 Iteration，且每次部署仍需检查实际设备状态。
本次只检查安装、冷启动/QML、TLS 初始化和一次 HTTPS。用户保持手机解锁并联网，
不需要操作登录或播放。确认后先 `adb devices`，再执行安装、冷启动、PID 与截图检查；
采集按当前应用 PID 过滤的 `adb logcat -d --pid=<PID> -v threadtime`，保存完整日志后检索
`AndroidTlsProbe|qt.tlsbackend|qt.network.ssl|linker|FATAL EXCEPTION|Fatal signal`。
不清空用户设备全局日志。证据保存在当前构建目录，不提交截图或运行日志。

通过条件：安装成功、正常启动/QML、`supportsSsl=true`、有效的 OpenSSL runtime/backend、
`encrypted=true`、最小 HTTPS 请求 `result=ok`，且本次日志无原来的 TLS 初始化失败。
验收前预期运行库版本为 3.5.8；实际真机结果见文末成功记录。
如果失败，依据错误阶段及原始日志定位，再作最小修改。

## 验证记录

2026-09-08：

| 检查 | 实际结果 |
| --- | --- |
| OpenSSL 交叉编译 | 通过，官方源码 SHA-256 校验通过，现有 NDK / ARM64 / API 28 |
| 桌面配置、构建 | 通过，Qt 6.10.2；应用未开启诊断 |
| CTest / Qt Quick | 5 个目标全部通过，包含诊断的 15 种结果分类场景；不是设备网络测试 |
| Android configure / C++ / QML / APK | 通过，诊断开关 ON，Gradle BUILD SUCCESSFUL，33 个任务完成 |
| qmllint | 通过，退出码 0 |
| APK 内容 | ZIP CRC 通过；包含 Qt Network、OpenSSL backend 和两个 ARM64 运行库 |
| 运行库来源一致性 | 两库与本次 NDK 产物执行 `llvm-strip --strip-unneeded` 后逐字节相同 |
| 修订 APK 的 ELF | 两库 SONAME 正确；ssl 依赖 crypto_3，其余仅 libc/libdl；LOAD 段大小、偏移与地址同余检查通过 |
| APK 签名 / 对齐 | apksigner v2 验证通过；zipalign `-c -P 16 -v 4` 通过 |
| 静态检查 / 复核 | `git diff --check`、`bash -n` 通过；部署及诊断代码只读复核未发现阻塞问题 |

APK 位于 `build/android-arm64-tls-debug/android-build/appcursor_music.apk`，89,646,666 字节。
SHA-256：

```text
79c8b74a8a35216556265d696ec30e555dff4a5cc3327b59f2b5152832323171
```

`androiddeployqt` 生成的部署设置已包含 crypto、ssl 两库，并按该顺序注册启动加载。
Gradle 的 `stripDebugDebugSymbols` 会剥离符号，因此 APK 中库的哈希与未剥离产物不同。
已用同一 NDK 重现转换，修订 APK 的两库逐字节匹配，且完整段布局检查通过。
单纯匹配 strip 后哈希不能证明 ELF 可加载：首次失败正是 strip 后布局错误，详见下方记录。
实际包名、minSdk 28、targetSdk 36 和 ABI 与 Iteration 1 一致。
构建仍有原来的 Theme.js / 平台控件风格 / Java 8 弃用提示，未因此修改业务或 QML。
OpenSSL 构建有 `__ANDROID_API__` 重定义提示；实际编译器为 `aarch64-linux-android28-clang`，
显式 API 值也为 28。没有通过改版本或关闭证书校验消除提示。

修订构建证据位于 `build/android-arm64-tls-debug/` 中的 `apk-build-qt3.log`、`qmllint.log`、
`apk-inspection-qt3.txt`、`apksigner-qt3.log`、`zipalign-qt3.log`；包配置未变。
桌面测试见 `build/tls-host-tests/ctest.log`，修订依赖构建见 `build/android-tls-deps/openssl-build-qt3.log`。

### 首次诊断 APK 的真机失败与最小修订

用户明确确认手机连接后，`adb devices -l` 确认 V2417A 状态为 `device`。
安装 SHA-256 为 `d60df0354fd5b748c3226d69fd200f54f7f8714bc972097bb35d82fae03f270c`
的首个诊断 APK，`adb install -r` 返回 `Success`。
冷启动命令返回 `Status: ok`，但 PID 随即消失。原始日志显示 PID 28832 在 Qt 加载原生库时崩溃：

```text
FATAL EXCEPTION: qtMainLoopThread
java.lang.UnsatisfiedLinkError: dlopen failed: cannot find "ateKey_bio"
from verneed[0] in DT_NEEDED list for ".../libcrypto_3.so"
```

这发生在 HTTPS 探针运行之前，不能归类为 DNS、证书或 HTTP 错误。
对比原始、patchelf 后和 APK 剥离后的 ELF，发现 libcrypto 最后一个 LOAD 段：

| 阶段 | 文件偏移 p_offset | 虚拟地址 p_vaddr | p_align |
| --- | --- | --- | --- |
| patchelf 后 | 0x650000 | 0x580000 | 0x10000 |
| Gradle / NDK strip 后 | 0x567660 | 0x580000 | 0x10000 |

ELF 加载不仅要求 p_align 达标，还要求 `p_offset % p_align == p_vaddr % p_align`。
第二行不满足，Android 按内存页映射后无法正确读取动态字符串表。
此前的静态检查只查看 p_align 和节表内容，漏掉这个条件；APK ZIP 对齐检查也不检查 ELF 内部布局。

修订仅调整 OpenSSL 构建脚本，改为链接时原生生成 `_3` 名称，取消后处理 ELF 的 patchelf 步骤。
新增 `scripts/check-android-elf.py` 检查 ELF64/AArch64、LOAD 地址/偏移同余和边界。
同一检查在失败 APK 上返回失败，在修订 APK 两库上通过，构成针对实际缺陷的回归验证。
工具的 APK 模式明确只检查本迭代两个 TLS 运行库，也可传入单个 `.so` 检查。

扩展检查另发现旧 APK 的 `libavformat.so` 也有段偏移问题；其在 Iteration 1 与首个诊断 APK
中的 SHA-256 均为 `ff49c28d5245d3cd6733300f789683e67ab46b7de4a2921742cf1c9388dae3a5`。
这是已有多媒体产物的独立问题，保留为后续播放迭代的调查线索，本次不修改。
因此本次 TLS 库检查通过不能表述为 APK 内所有原生库均通过 ELF 检查。

失败证据保存在 `build/android-arm64-tls-debug/device-validation-2026-09-08/`：
`failed-startup.apk`、`startup-system-logcat.txt`、`launch.txt`、`failed-apk-inspection.txt`。
本次没有检查登录、播放或后台行为，没有清空用户手机全局日志。

该次检查结束时：首个诊断 APK 安装通过、启动失败；修订 APK 构建与静态检查通过，
等待用户确认设备。随后实际复测结果见下一节，保留本节作为失败与修订的证据链。

### 修订 APK 的真机成功记录

2026-09-08，用户再次确认设备并授权本 Iteration 连续复测后：

| 验收条件 | 实际证据 |
| --- | --- |
| 设备与授权 | `adb devices -l`：V2417A 为 `device`；Android 16 / ARM64 |
| 安装 | `adb install -r` 返回 `Success`，APK SHA-256 为上文的 `79c8b74a…` |
| 冷启动 | `am start -W` 返回 `Status: ok`、`LaunchState: COLD`、`TotalTime: 286` ms |
| QML / 进程 | 实际截图显示登录页、播放器区域和导航栏；两次 PID 均为 30176，复查前台为本项目 QtActivity |
| SSL 支持 | `QSslSocket::supportsSsl() = true` |
| backend | `availableBackends = [openssl]`，`activeBackend = openssl` |
| 编译时 SSL | `OpenSSL 3.0.7 1 Nov 2022` |
| 运行时 SSL | `OpenSSL 3.5.8 25 Aug 2026` |
| HTTPS | `https://www.qt.io/robots.txt` 完成 encrypted 信号，HTTP 200，NoError，254 字节，result=ok |
| 原错误复查 | 本次 PID 日志未出现 Failed to load libssl/libcrypto、No functional TLS backend、TLS initialization failed 或 dlopen failed |
| 启动崩溃复查 | 本次 PID 日志无 FATAL EXCEPTION / Fatal signal，观察期间应用持续存活 |
| 登录 / 收藏夹 / 播放 / 后台行为 | 本 Iteration 未进行专项验证，不据截图或启动过程推断其测试通过 |

实际探针日志：

```text
21:32:29.774 supportsSsl= true availableBackends= QList("openssl") activeBackend= "openssl"
             buildVersion= "OpenSSL 3.0.7 1 Nov 2022" runtimeVersion= "OpenSSL 3.5.8 25 Aug 2026"
21:32:29.950 encrypted=true
21:32:30.127 result= ok httpStatus= 200 networkError= QNetworkReply::NoError encrypted= true bytes= 254
```

Qt 在 NoError 情况下的 `errorString()` 仍返回默认文字 `Unknown error`；
这不是请求失败证据，应结合错误枚举、HTTP 状态和 encrypted 结果判断，本次均满足成功条件。

本次设备证据保存在 `build/android-arm64-tls-debug/device-validation-2026-09-08-qt3/`：
`install.txt`、`launch.txt`、`app-logcat.txt`、`screen.png`。日志和截图不提交 Git。

诊断模块作为默认 OFF 的可选验证工具保留，便于未来 Qt/NDK 变更后复核 TLS 基础设施；
普通 Android 构建不编入探针，不自动访问诊断站点。已安装的本次测试 APK 显式开启诊断。

分支：`fix/android-tls`，基于 `31aa0b6`。真机通过后以单一职责提交
`fix(android): restore HTTPS TLS support` 保存构建、诊断、验证工具和文档，不自动合并或进入下一 Iteration。
