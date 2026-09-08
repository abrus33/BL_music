#!/usr/bin/env bash
# Android 构建基础设施：由开发者调用，以现有 NDK 编译 Qt TLS backend 缺少的运行库。
# 调用链：本脚本 → OpenSSL Configure/make → ARM64 .so → CMake QT_ANDROID_EXTRA_LIBS → APK。
# 所有源码和产物留在已忽略的 build/；不安装或替换 Linux 系统 OpenSSL，不修改业务代码。
set -euo pipefail

BL_PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BL_DEPS="$BL_PROJECT_ROOT/build/android-tls-deps"
BL_VERSION=3.5.8
BL_SHA256=a8f84a39918ec6415ce765d9b429d313ba97b8143169c172e734b9514464f5b2
BL_ARCHIVE="${1:-$BL_DEPS/source/openssl-$BL_VERSION.tar.gz}"
BL_NDK="${BL_ANDROID_NDK:-$HOME/Android/Sdk/ndk/27.2.12479018}"
BL_OUTPUT="$BL_DEPS/openssl-$BL_VERSION/arm64-v8a"
BL_BUILD="$BL_DEPS/openssl-$BL_VERSION/build-arm64-qt3"

for BL_TOOL in perl make sha256sum tar; do
    command -v "$BL_TOOL" >/dev/null || { echo "Missing tool: $BL_TOOL" >&2; exit 1; }
done
if ! grep -Eq '^Pkg.Revision[[:space:]]*=[[:space:]]*27\.2\.12479018[[:space:]]*$' "$BL_NDK/source.properties"; then
    echo "Expected the existing NDK 27.2.12479018; set BL_ANDROID_NDK to its directory." >&2
    exit 1
fi
mkdir -p "$BL_DEPS/source" "$BL_OUTPUT" "$BL_BUILD"
if [[ ! -f "$BL_ARCHIVE" ]]; then
    # 只接受官方固定版本，网络中断或校验失败立即停止，不能把残缺文件当成可用源码。
    curl --fail --location --retry 3 --output "$BL_ARCHIVE" \
        "https://github.com/openssl/openssl/releases/download/openssl-$BL_VERSION/openssl-$BL_VERSION.tar.gz"
fi
printf '%s  %s\n' "$BL_SHA256" "$BL_ARCHIVE" | sha256sum --check -
tar -xzf "$BL_ARCHIVE" -C "$BL_DEPS/source"

# Android ABI 决定机器码和系统接口；这里固定 arm64-v8a，不能使用电脑的 x86_64 .so。
# API 28 与当前 APK minSdk 一致；16 KiB ELF 段对齐用于兼容采用大内存页的 Android 设备。
export ANDROID_NDK_ROOT="$BL_NDK"
export PATH="$BL_NDK/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH"
unset LD_LIBRARY_PATH
cd "$BL_BUILD"
# OpenSSL 的本地 target 扩展让链接器直接生成 _3 库名、SONAME 和依赖，保持源码归档原样。
# 不能事后用 patchelf 搬移段再交给当前 Gradle/NDK strip：真机发现该组合破坏了 LOAD 偏移对齐。
mkdir -p qt-config
cat > qt-config/99-bl-android.conf <<'EOF'
my %targets = (
    "bl-android-arm64" => {
        inherit_from => [ "android-arm64" ],
        shlib_variant => "_3",
    },
);
EOF
export OPENSSL_LOCAL_CONFIG_DIR="$BL_BUILD/qt-config"
perl "$BL_DEPS/source/openssl-$BL_VERSION/Configure" bl-android-arm64 shared \
    -D__ANDROID_API__=28 -Wl,-z,max-page-size=16384 \
    no-apps no-docs no-tests no-module
make -j"${BL_BUILD_JOBS:-4}" build_libs

# Qt 6.10.2 的 OpenSSL 插件在 Android 默认寻找 _3 后缀。
# SONAME 是共享库的运行时身份，NEEDED 是依赖名称；上面的 variant 让链接器统一生成这三处名称。
# variant 也改变符号版本命名空间，两库成对构建；Qt backend 按未版本化的函数名动态解析。
# no-module 保留内置 default provider，避免依赖 APK 外额外的 OpenSSL provider 模块。
cp libcrypto_3.so "$BL_OUTPUT/libcrypto_3.so"
cp libssl_3.so "$BL_OUTPUT/libssl_3.so"
cp "$BL_DEPS/source/openssl-$BL_VERSION/LICENSE.txt" "$BL_OUTPUT/LICENSE.txt"
sha256sum "$BL_OUTPUT/libcrypto_3.so" "$BL_OUTPUT/libssl_3.so"
printf 'BL_ANDROID_OPENSSL_DIR=%s\n' "$BL_OUTPUT"
