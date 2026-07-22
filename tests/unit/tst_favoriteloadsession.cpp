#include <QtTest>

#include "bilibili/FavoriteLoadSession.h"

class FavoriteLoadSessionTest : public QObject
{
    Q_OBJECT

private slots:
    void newLoadInvalidatesOldGeneration();
    void appendAcceptsOnlyCurrentGeneration();
    void newLoadClearsAccumulatedItems();
    void finishingOldGenerationKeepsCurrentGenerationActive();
    void finishingCurrentGenerationRejectsFurtherAppend();
};

void FavoriteLoadSessionTest::newLoadInvalidatesOldGeneration()
{
    FavoriteLoadSession session;
    const quint64 first = session.begin(11);
    const quint64 second = session.begin(22);

    QVERIFY(!session.accepts(first));
    QVERIFY(session.accepts(second));
    QCOMPARE(session.mediaId(), 22);
}

void FavoriteLoadSessionTest::appendAcceptsOnlyCurrentGeneration()
{
    FavoriteLoadSession session;
    const quint64 oldGeneration = session.begin(11);
    const quint64 currentGeneration = session.begin(22);
    const QJsonArray oldItems{QJsonObject{{"id", 1}}};
    const QJsonArray currentItems{QJsonObject{{"id", 2}},
                                  QJsonObject{{"id", 3}}};

    QVERIFY(!session.append(oldGeneration, oldItems));
    QVERIFY(session.items().isEmpty());
    QVERIFY(session.append(currentGeneration, currentItems));
    QCOMPARE(session.items(), currentItems);
}

void FavoriteLoadSessionTest::newLoadClearsAccumulatedItems()
{
    FavoriteLoadSession session;
    const quint64 first = session.begin(11);

    QVERIFY(session.append(first, QJsonArray{QJsonObject{{"id", 1}}}));
    QCOMPARE(session.items().size(), 1);

    session.begin(22);

    QVERIFY(session.items().isEmpty());
}

void FavoriteLoadSessionTest::finishingOldGenerationKeepsCurrentGenerationActive()
{
    FavoriteLoadSession session;
    const quint64 first = session.begin(11);
    const quint64 second = session.begin(22);
    const QJsonArray items{QJsonObject{{"id", 2}}};

    session.finish(first);

    QVERIFY(session.accepts(second));
    QVERIFY(session.append(second, items));
    QCOMPARE(session.items(), items);
}

void FavoriteLoadSessionTest::finishingCurrentGenerationRejectsFurtherAppend()
{
    FavoriteLoadSession session;
    const quint64 second = session.begin(22);
    const QJsonArray items{QJsonObject{{"id", 2}}};

    session.finish(second);

    QVERIFY(!session.accepts(second));
    QVERIFY(!session.append(second, items));
    QVERIFY(session.items().isEmpty());
}

QTEST_APPLESS_MAIN(FavoriteLoadSessionTest)

#include "tst_favoriteloadsession.moc"
