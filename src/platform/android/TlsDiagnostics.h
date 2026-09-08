// Android TLS 基础设施诊断接口：由诊断 APK 的 main.cpp 调用，结果写入 logcat。
// 通过 Qt Network 检查运行库和一次 HTTPS 请求；不依赖登录、Cookie 或播放器服务。
// 仅使用跨平台 Qt API，以便在主机上测试错误分类；正式应用默认不编译这个模块。
#pragma once

#include <QNetworkReply>

namespace AndroidTlsDiagnostics {

// 记录不同协议阶段的证据，避免仅根据 errorString 或 HTTP 状态推断 TLS 是否成功。
struct HttpsResult {
    bool tlsAvailable = false;
    bool encrypted = false;
    bool certificateError = false;
    bool timedOut = false;
    int httpStatus = 0;
    QNetworkReply::NetworkError networkError = QNetworkReply::NoError;
};

const char *outcome(const HttpsResult &result);
void start(QObject *lifetimeOwner);

} // namespace AndroidTlsDiagnostics
