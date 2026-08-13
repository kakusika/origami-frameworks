#include "app_bootstrap.h"

#include <QtQml/QQmlApplicationEngine>
#include <QtQml/QQmlContext>
#include <QtQuick/QQuickWindow>
#include <QtCore/QUrl>
#include <QtCore/QDebug>

#include <QtQml/qqmldebug.h>

extern "C" {

uint64_t createEngine()
{
    auto* engine = new QQmlApplicationEngine();
    return reinterpret_cast<uint64_t>(engine);
}

bool loadQml(uint64_t enginePtr, const char* qmlUrlUtf8)
{
    if (enginePtr == 0 || qmlUrlUtf8 == nullptr) {
        qWarning() << "loadQml: invalid engine or QML URL";
        return false;
    }

    auto* engine = reinterpret_cast<QQmlApplicationEngine*>(enginePtr);
    engine->load(QUrl(QString::fromUtf8(qmlUrlUtf8)));

    if (engine->rootObjects().isEmpty()) {
        qWarning() << "loadQml: QML load failed (no root objects created)";
        return false;
    }

    return true;
}

uint64_t rootWindowOf(uint64_t enginePtr)
{
    if (enginePtr == 0) {
        return 0;
    }
    auto* engine = reinterpret_cast<QQmlApplicationEngine*>(enginePtr);
    if (engine->rootObjects().isEmpty()) {
        return 0;
    }
    auto* window = qobject_cast<QQuickWindow*>(engine->rootObjects().first());
    if (window == nullptr) {
        qWarning() << "rootWindowOf: root object is not a QQuickWindow";
        return 0;
    }
    return reinterpret_cast<uint64_t>(window);
}

void destroyEngine(uint64_t enginePtr)
{
    if (enginePtr == 0) {
        return;
    }
    delete reinterpret_cast<QQmlApplicationEngine*>(enginePtr);
}

} // extern "C"
