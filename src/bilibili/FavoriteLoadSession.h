#pragma once

#include <QJsonArray>
#include <QtGlobal>

class FavoriteLoadSession
{
public:
    quint64 begin(qint64 mediaId)
    {
        ++m_generation;
        m_mediaId = mediaId;
        m_items = {};
        m_active = true;
        return m_generation;
    }

    bool accepts(quint64 generation) const
    {
        return m_active && generation == m_generation;
    }

    bool append(quint64 generation, const QJsonArray &items)
    {
        if (!accepts(generation))
            return false;

        for (const QJsonValue &item : items)
            m_items.append(item);
        return true;
    }

    void finish(quint64 generation)
    {
        if (accepts(generation))
            m_active = false;
    }

    qint64 mediaId() const
    {
        return m_mediaId;
    }

    const QJsonArray &items() const
    {
        return m_items;
    }

private:
    quint64 m_generation = 0;
    qint64 m_mediaId = 0;
    bool m_active = false;
    QJsonArray m_items;
};
