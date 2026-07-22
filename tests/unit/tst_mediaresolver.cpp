#include <QtTest>

#include "bilibili/BilibiliApiClient.h"
#include "player/MediaResolver.h"

class FakeBilibiliApiClient final : public BilibiliApiClient
{
public:
    using AudioCallback = std::function<void(bool, QString, QString)>;
    using CidCallback = std::function<void(bool, qint64, QString)>;
    using VideoCallback = std::function<void(bool, QString, QString)>;

    FakeBilibiliApiClient()
        : BilibiliApiClient(nullptr)
    {
    }

    void getAudioStreamUrl(qint64 audioId, AudioCallback callback) override
    {
        lastAudioId = audioId;
        audioCallback = std::move(callback);
    }

    void getVideoCid(const QString &bvid, CidCallback callback) override
    {
        lastBvid = bvid;
        cidCallback = std::move(callback);
    }

    void getVideoPlayUrl(const QString &bvid, qint64 cid,
                         VideoCallback callback) override
    {
        lastBvid = bvid;
        lastCid = cid;
        videoCallback = std::move(callback);
    }

    qint64 lastAudioId = 0;
    QString lastBvid;
    qint64 lastCid = 0;
    AudioCallback audioCallback;
    CidCallback cidCallback;
    VideoCallback videoCallback;
};

class MediaResolverTest : public QObject
{
    Q_OBJECT

private slots:
    void legacyAsyncSuccessEmitsOnlyLegacySignal();
    void taggedAsyncSuccessAndFailureEmitOnlyTaggedSignal();
    void taggedVideoBranchesPreserveOwnerAndIsolation();
    void suppliedVideoCidBypassesCidLookup();
    void zeroVideoCidStillUsesCidLookup();
    void synchronousErrorsUseTheSelectedSignalFamily();
    void nullApiErrorsUseTheSelectedSignalFamily();
    void callbacksAfterResolverDestructionAreSafe();
};

void MediaResolverTest::legacyAsyncSuccessEmitsOnlyLegacySignal()
{
    FakeBilibiliApiClient api;
    MediaResolver resolver(&api);
    QSignalSpy legacySpy(&resolver, &MediaResolver::mediaResolved);
    QSignalSpy taggedSpy(&resolver, &MediaResolver::mediaResolvedForOwner);

    resolver.resolve(42, 12);
    QCOMPARE(api.lastAudioId, 42);
    QVERIFY(api.audioCallback);
    api.audioCallback(true, QStringLiteral("legacy-url"), QString());

    QCOMPARE(legacySpy.count(), 1);
    QCOMPARE(taggedSpy.count(), 0);
    QCOMPARE(legacySpy.takeFirst().at(1).toString(), QStringLiteral("legacy-url"));
}

void MediaResolverTest::taggedAsyncSuccessAndFailureEmitOnlyTaggedSignal()
{
    FakeBilibiliApiClient api;
    MediaResolver resolver(&api);
    QSignalSpy legacySpy(&resolver, &MediaResolver::mediaResolved);
    QSignalSpy taggedSpy(&resolver, &MediaResolver::mediaResolvedForOwner);

    resolver.resolveForOwner(QStringLiteral("home-owner"), 7, 12);
    QVERIFY(api.audioCallback);
    api.audioCallback(true, QStringLiteral("tagged-url"), QString());

    QCOMPARE(legacySpy.count(), 0);
    QCOMPARE(taggedSpy.count(), 1);
    QList<QVariant> success = taggedSpy.takeFirst();
    QCOMPARE(success.at(0).toString(), QStringLiteral("home-owner"));
    QCOMPARE(success.at(1).toBool(), true);
    QCOMPARE(success.at(2).toString(), QStringLiteral("tagged-url"));

    resolver.resolveForOwner(QStringLiteral("home-owner"), 8, 12);
    QVERIFY(api.audioCallback);
    api.audioCallback(false, QString(), QStringLiteral("audio failure"));

    QCOMPARE(legacySpy.count(), 0);
    QCOMPARE(taggedSpy.count(), 1);
    QList<QVariant> failure = taggedSpy.takeFirst();
    QCOMPARE(failure.at(0).toString(), QStringLiteral("home-owner"));
    QCOMPARE(failure.at(1).toBool(), false);
    QCOMPARE(failure.at(6).toString(), QStringLiteral("audio failure"));
}

void MediaResolverTest::taggedVideoBranchesPreserveOwnerAndIsolation()
{
    FakeBilibiliApiClient api;
    MediaResolver resolver(&api);
    QSignalSpy legacySpy(&resolver, &MediaResolver::mediaResolved);
    QSignalSpy taggedSpy(&resolver, &MediaResolver::mediaResolvedForOwner);

    resolver.resolveForOwner(QStringLiteral("video-owner"), 5, 2,
                             QStringLiteral("BV1test"));
    QVERIFY(api.cidCallback);
    api.cidCallback(false, 0, QStringLiteral("cid failure"));
    QCOMPARE(taggedSpy.count(), 1);
    QCOMPARE(taggedSpy.takeFirst().at(6).toString(), QStringLiteral("cid failure"));
    QCOMPARE(legacySpy.count(), 0);

    resolver.resolveForOwner(QStringLiteral("video-owner"), 5, 2,
                             QStringLiteral("BV1test"));
    api.cidCallback(true, 99, QString());
    QCOMPARE(api.lastCid, 99);
    QVERIFY(api.videoCallback);
    api.videoCallback(false, QString(), QStringLiteral("play failure"));
    QCOMPARE(taggedSpy.count(), 1);
    QCOMPARE(taggedSpy.takeFirst().at(6).toString(), QStringLiteral("play failure"));
    QCOMPARE(legacySpy.count(), 0);

    resolver.resolveForOwner(QStringLiteral("video-owner"), 5, 2,
                             QStringLiteral("BV1test"));
    api.cidCallback(true, 100, QString());
    api.videoCallback(true, QStringLiteral("video-url"), QString());
    QCOMPARE(taggedSpy.count(), 1);
    const QList<QVariant> success = taggedSpy.takeFirst();
    QCOMPARE(success.at(0).toString(), QStringLiteral("video-owner"));
    QCOMPARE(success.at(2).toString(), QStringLiteral("video-url"));
    QCOMPARE(legacySpy.count(), 0);
}

void MediaResolverTest::suppliedVideoCidBypassesCidLookup()
{
    FakeBilibiliApiClient api;
    MediaResolver resolver(&api);
    QSignalSpy taggedSpy(&resolver, &MediaResolver::mediaResolvedForOwner);

    resolver.resolveForOwner(QStringLiteral("video-owner"), 5, 2,
                             QStringLiteral("BV1test"), 2468);

    QVERIFY(!api.cidCallback);
    QCOMPARE(api.lastBvid, QStringLiteral("BV1test"));
    QCOMPARE(api.lastCid, 2468);
    QVERIFY(api.videoCallback);
    api.videoCallback(true, QStringLiteral("direct-url"), QString());
    QCOMPARE(taggedSpy.count(), 1);
    QCOMPARE(taggedSpy.takeFirst().at(2).toString(), QStringLiteral("direct-url"));
}

void MediaResolverTest::zeroVideoCidStillUsesCidLookup()
{
    FakeBilibiliApiClient api;
    MediaResolver resolver(&api);

    resolver.resolve(5, 2, QStringLiteral("BV1test"), 0);

    QVERIFY(api.cidCallback);
    QCOMPARE(api.lastCid, 0);
}

void MediaResolverTest::synchronousErrorsUseTheSelectedSignalFamily()
{
    FakeBilibiliApiClient api;
    MediaResolver resolver(&api);
    QSignalSpy legacySpy(&resolver, &MediaResolver::mediaResolved);
    QSignalSpy taggedSpy(&resolver, &MediaResolver::mediaResolvedForOwner);

    resolver.resolve(1, 2);
    QCOMPARE(legacySpy.count(), 1);
    QCOMPARE(taggedSpy.count(), 0);

    resolver.resolveForOwner(QStringLiteral("sync-owner"), 1, 2);
    QCOMPARE(legacySpy.count(), 1);
    QCOMPARE(taggedSpy.count(), 1);
    QCOMPARE(taggedSpy.takeFirst().at(0).toString(), QStringLiteral("sync-owner"));

    resolver.resolveForOwner(QStringLiteral("sync-owner"), 1, 99);
    QCOMPARE(legacySpy.count(), 1);
    QCOMPARE(taggedSpy.count(), 1);
    QCOMPARE(taggedSpy.takeFirst().at(0).toString(), QStringLiteral("sync-owner"));
}

void MediaResolverTest::nullApiErrorsUseTheSelectedSignalFamily()
{
    MediaResolver resolver(nullptr);
    QSignalSpy legacySpy(&resolver, &MediaResolver::mediaResolved);
    QSignalSpy taggedSpy(&resolver, &MediaResolver::mediaResolvedForOwner);

    resolver.resolve(1, 12);
    QCOMPARE(legacySpy.count(), 1);
    QCOMPARE(taggedSpy.count(), 0);

    resolver.resolveForOwner(QStringLiteral("null-owner"), 1, 12);
    QCOMPARE(legacySpy.count(), 1);
    QCOMPARE(taggedSpy.count(), 1);
    QCOMPARE(taggedSpy.takeFirst().at(0).toString(), QStringLiteral("null-owner"));
}

void MediaResolverTest::callbacksAfterResolverDestructionAreSafe()
{
    FakeBilibiliApiClient api;
    auto *resolver = new MediaResolver(&api);

    resolver->resolveForOwner(QStringLiteral("gone-owner"), 7, 12);
    QVERIFY(api.audioCallback);
    delete resolver;

    api.audioCallback(true, QStringLiteral("late-url"), QString());
}

QTEST_APPLESS_MAIN(MediaResolverTest)

#include "tst_mediaresolver.moc"
