#include <qcoreevent.h>
#include <qjsonarray.h>
#include <qjsondocument.h>
#include <qlocalserver.h>
#include <qpointer.h>
#include <qregularexpression.h>
#include <qset.h>
#include <qtemporarydir.h>
#include <qtest.h>

#include "hyprdevices.hpp"
#include "hyprextras.hpp"

using caelestia::shell::services::hypr::HyprExtras;

class c_hypr_request_test : public QObject {
    Q_OBJECT

private:
    QTemporaryDir m_directory;
    QLocalServer m_server;
    HyprExtras* m_extras{};

private slots:
    void init() {
        QVERIFY(m_directory.isValid());
        QVERIFY(m_server.listen(m_directory.filePath(QStringLiteral("request.sock"))));
        qunsetenv("HYPRLAND_INSTANCE_SIGNATURE");
        QTest::ignoreMessage(QtWarningMsg, "$HYPRLAND_INSTANCE_SIGNATURE is unset. Unable to connect to Hyprland socket.");
        m_extras = new HyprExtras;
        m_extras->m_requestSocket = m_server.fullServerName();
    }

    void cleanup() {
        delete m_extras;
        m_extras = nullptr;
        m_server.close();
        QCoreApplication::sendPostedEvents(nullptr, QEvent::DeferredDelete);
    }

    void fragmented_json_response() {
        int callbacks = 0;
        bool success = false;
        QJsonDocument response;
        m_extras->makeRequestJson(QStringLiteral("devices"), [&](bool completed, const QJsonDocument& document) {
            callbacks++;
            success = completed;
            response = document;
        });
        QTRY_VERIFY(m_server.hasPendingConnections());
        auto* peer = m_server.nextPendingConnection();
        QTRY_VERIFY(peer->bytesAvailable() > 0);
        QCOMPARE(peer->readAll(), QByteArray("j/devices"));
        peer->write("{\"keyboards\":[\"");
        peer->flush();
        QTest::qWait(30);
        QCOMPARE(callbacks, 0);
        const QByteArray keyboard_name(256 * 1024, 'k');
        peer->write(keyboard_name);
        peer->write("\"]}");
        peer->disconnectFromServer();
        QTRY_COMPARE(callbacks, 1);
        QVERIFY(success);
        QCOMPARE(response.object().value(QStringLiteral("keyboards")).toArray().at(0).toString(), QString::fromLatin1(keyboard_name));
    }

    void completed_socket_is_destroyed() {
        int callbacks = 0;
        bool success = false;
        QByteArray response;
        const QPointer<QLocalSocket> request = m_extras->makeRequest(QStringLiteral("message"), [&](bool completed, const QByteArray& data) {
            callbacks++;
            success = completed;
            response = data;
        }).data();
        QTRY_VERIFY(m_server.hasPendingConnections());
        auto* peer = m_server.nextPendingConnection();
        peer->write("ok");
        peer->disconnectFromServer();
        QTRY_COMPARE(callbacks, 1);
        QVERIFY(success);
        QCOMPARE(response, QByteArray("ok"));
        QTRY_VERIFY(request.isNull());
        QTest::qWait(20);
        QCOMPARE(callbacks, 1);
    }

    void connection_error_completes_once() {
        int callbacks = 0;
        bool success = true;
        m_extras->m_requestSocket = m_directory.filePath(QStringLiteral("missing.sock"));
        QTest::ignoreMessage(QtWarningMsg, QRegularExpression(QStringLiteral("makeRequest: error making request:.*")));
        const QPointer<QLocalSocket> request = m_extras->makeRequest(QStringLiteral("message"), [&](bool completed, const QByteArray&) {
            callbacks++;
            success = completed;
        }).data();
        QTRY_COMPARE(callbacks, 1);
        QVERIFY(!success);
        QTRY_VERIFY(request.isNull());
        QTest::qWait(20);
        QCOMPARE(callbacks, 1);
    }

    void invalid_json_is_unsuccessful() {
        int callbacks = 0;
        bool success = true;
        m_extras->makeRequestJson(QStringLiteral("devices"), [&](bool completed, const QJsonDocument&) {
            callbacks++;
            success = completed;
        });
        QTRY_VERIFY(m_server.hasPendingConnections());
        auto* peer = m_server.nextPendingConnection();
        peer->write("{broken");
        peer->disconnectFromServer();
        QTRY_COMPARE(callbacks, 1);
        QVERIFY(!success);
    }

    void replacing_refresh_cancels_old_request() {
        m_extras->refreshDevices();
        const QPointer<QLocalSocket> first_request = m_extras->m_devicesRefresh.data();
        QTRY_VERIFY(m_server.hasPendingConnections());
        auto* first_peer = m_server.nextPendingConnection();
        QTRY_VERIFY(first_peer->bytesAvailable() > 0);
        first_peer->readAll();
        m_extras->refreshDevices();
        const QPointer<QLocalSocket> second_request = m_extras->m_devicesRefresh.data();
        QTRY_VERIFY(m_server.hasPendingConnections());
        auto* second_peer = m_server.nextPendingConnection();
        QTRY_VERIFY(first_request.isNull());
        QCOMPARE(m_extras->m_devicesRefresh.data(), second_request.data());
        second_peer->write("{\"keyboards\":[{\"address\":\"0x123\",\"name\":\"new keyboard\",\"layout\":\"us\",\"active_keymap\":\"English (US)\",\"capsLock\":false,\"numLock\":false,\"main\":true}]}");
        second_peer->disconnectFromServer();
        QTRY_VERIFY(m_extras->m_devicesRefresh.isNull());
        auto keyboards = m_extras->devices()->keyboards();
        QCOMPARE(keyboards.count(&keyboards), 1);
        QCOMPARE(keyboards.at(&keyboards, 0)->name(), QStringLiteral("new keyboard"));
        QTRY_VERIFY(second_request.isNull());
    }

    void fragmented_events_wait_for_newline_data() {
        QTest::addColumn<int>("first_fragment_size");
        QTest::newRow("split-event-name") << 5;
        QTest::newRow("split-event-payload") << 20;
    }

    void fragmented_events_wait_for_newline() {
        QFETCH(int, first_fragment_size);
        QLocalServer event_server;
        QVERIFY(event_server.listen(m_directory.filePath(QStringLiteral("events.sock"))));
        m_extras->m_socket = new QLocalSocket(m_extras);
        connect(m_extras->m_socket, &QLocalSocket::readyRead, m_extras, &HyprExtras::readEvent);
        m_extras->m_socket->connectToServer(event_server.fullServerName(), QIODevice::ReadOnly);
        QTRY_VERIFY(event_server.hasPendingConnections());
        auto* event_peer = event_server.nextPendingConnection();
        const QByteArray event("activelayout>>keyboard,English (US)\n");
        event_peer->write(event.left(first_fragment_size));
        event_peer->flush();
        QTest::qWait(30);
        QVERIFY(!m_server.hasPendingConnections());
        QVERIFY(m_extras->m_devicesRefresh.isNull());
        event_peer->write(event.mid(first_fragment_size));
        event_peer->flush();
        QTRY_VERIFY(m_server.hasPendingConnections());
        auto* first_peer = m_server.nextPendingConnection();
        QTRY_VERIFY(first_peer->bytesAvailable() > 0);
        QCOMPARE(first_peer->readAll(), QByteArray("j/devices"));
        first_peer->write("{\"keyboards\":[]}");
        first_peer->disconnectFromServer();
        QTRY_VERIFY(m_extras->m_devicesRefresh.isNull());
        QTest::qWait(20);
        QVERIFY(!m_server.hasPendingConnections());
        event_peer->write("activelayout>>keyboard,English (US)\nconfigreloaded>>\n");
        event_peer->flush();
        QSet<QByteArray> requests;
        for (int i = 0; i < 2; i++) {
            QTRY_VERIFY(m_server.hasPendingConnections());
            auto* peer = m_server.nextPendingConnection();
            QTRY_VERIFY(peer->bytesAvailable() > 0);
            const QByteArray request = peer->readAll();
            QVERIFY(request == "j/devices" || request == "j/descriptions");
            requests.insert(request);
            peer->write(request == "j/devices" ? "{\"keyboards\":[]}" : "[]");
            peer->disconnectFromServer();
        }
        QCOMPARE(requests.size(), 2);
        QTRY_VERIFY(m_extras->m_devicesRefresh.isNull());
        QTRY_VERIFY(m_extras->m_optionsRefresh.isNull());
        QTest::qWait(20);
        QVERIFY(!m_server.hasPendingConnections());
    }

    void service_destruction_cancels_request() {
        int callbacks = 0;
        const QPointer<QLocalSocket> request = m_extras->makeRequest(QStringLiteral("message"), [&](bool, const QByteArray&) {
            callbacks++;
        }).data();
        QTRY_VERIFY(m_server.hasPendingConnections());
        delete m_extras;
        m_extras = nullptr;
        QVERIFY(request.isNull());
        QCoreApplication::processEvents();
        QCOMPARE(callbacks, 0);
    }
};

QTEST_GUILESS_MAIN(c_hypr_request_test)
#include "hyprrequests.moc"
