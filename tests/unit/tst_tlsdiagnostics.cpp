// 验证 Android HTTPS 诊断不会把 HTTP 错误、证书错误或未加密响应误报为 TLS 成功。
// 只测试结果分类，不访问网络；真正的 Android TLS 初始化仍由人工真机检查点验收。
#include <QtTest>
#include "platform/android/TlsDiagnostics.h"

class TlsDiagnosticsTest : public QObject
{
    Q_OBJECT
private slots:
    void distinguishesFailureStages()
    {
        using namespace AndroidTlsDiagnostics;
        using Error = QNetworkReply::NetworkError;
        const struct {
            HttpsResult result;
            const char *expected;
        } cases[] = {
            {{false, false, false, false, 0, Error::SslHandshakeFailedError}, "tls-unavailable"},
            {{true, false, true, false, 0, Error::SslHandshakeFailedError}, "certificate-error"},
            {{true, false, false, false, 0, Error::SslHandshakeFailedError}, "tls-handshake-error"},
            {{true, false, false, true, 0, Error::OperationCanceledError}, "timeout"},
            {{true, false, false, false, 0, Error::TimeoutError}, "timeout"},
            {{true, false, false, false, 0, Error::HostNotFoundError}, "dns-error"},
            {{true, false, false, false, 0, Error::ConnectionRefusedError}, "network-error"},
            {{true, true, false, false, 404, Error::ContentNotFoundError}, "http-status-error"},
            {{true, true, false, false, 503, Error::ServiceUnavailableError}, "http-status-error"},
            {{true, true, false, false, 301, Error::NoError}, "http-status-error"},
            {{true, true, false, false, 200, Error::RemoteHostClosedError}, "network-error"},
            {{true, false, false, false, 200, Error::NoError}, "unencrypted-response"},
            {{true, true, false, false, 0, Error::NoError}, "http-status-error"},
            {{true, true, false, false, 200, Error::NoError}, "ok"},
            {{true, true, false, false, 204, Error::NoError}, "ok"},
        };
        for (const auto &test : cases)
            QCOMPARE(QString::fromLatin1(outcome(test.result)), QString::fromLatin1(test.expected));
    }
};

QTEST_APPLESS_MAIN(TlsDiagnosticsTest)
#include "tst_tlsdiagnostics.moc"
