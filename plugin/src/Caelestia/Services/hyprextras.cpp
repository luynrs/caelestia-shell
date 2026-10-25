#include "hyprextras.hpp"

#include <qdir.h>
#include <qjsonarray.h>
#include <qlocalsocket.h>
#include <qloggingcategory.h>
#include <qvariant.h>

#include "hyprdevices.hpp"

namespace {

Q_LOGGING_CATEGORY(lcHypr, "caelestia.services.hypr", QtInfoMsg)

} // namespace

namespace caelestia::services::hypr {

using Qt::StringLiterals::operator""_s;

HyprExtras::HyprExtras(QObject* parent)
    : QObject(parent)
    , m_socket(nullptr)
    , m_socketValid(false)
    , m_devices(new HyprDevices(this)) {
    const auto his = qEnvironmentVariable("HYPRLAND_INSTANCE_SIGNATURE");
    if (his.isEmpty()) {
        qCWarning(lcHypr) << "$HYPRLAND_INSTANCE_SIGNATURE is unset. Unable to connect to Hyprland socket.";
        return;
    }

    auto hyprDir = u"%1/hypr/%2"_s.arg(qEnvironmentVariable("XDG_RUNTIME_DIR"), his);
    if (!QDir(hyprDir).exists()) {
        hyprDir = u"/tmp/hypr/"_s + his;

        if (!QDir(hyprDir).exists()) {
            qCWarning(lcHypr) << "Hyprland socket directory does not exist. Unable to connect to Hyprland socket.";
            return;
        }
    }

    m_requestSocket = hyprDir + u"/.socket.sock"_s;
    m_eventSocket = hyprDir + u"/.socket2.sock"_s;

    refreshOptions();
    refreshDevices();

    m_socket = new QLocalSocket(this);

    QObject::connect(m_socket, &QLocalSocket::errorOccurred, this, &HyprExtras::socketError);
    QObject::connect(m_socket, &QLocalSocket::stateChanged, this, &HyprExtras::socketStateChanged);
    QObject::connect(m_socket, &QLocalSocket::readyRead, this, &HyprExtras::readEvent);

    m_socket->connectToServer(m_eventSocket, QLocalSocket::ReadOnly);
}

QVariantHash HyprExtras::options() const {
    return m_options;
}

HyprDevices* HyprExtras::devices() const {
    return m_devices;
}

void HyprExtras::message(const QString& message) {
    if (message.isEmpty()) {
        return;
    }

    makeRequest(message, [](bool success, const QByteArray& res) {
        if (!success) {
            qCWarning(lcHypr) << "message: request error:" << QString::fromUtf8(res);
        }
    });
}

void HyprExtras::batchMessage(const QStringList& messages) {
    if (messages.isEmpty()) {
        return;
    }

    makeRequest(u"[[BATCH]]"_s + messages.join(u";"_s), [](bool success, const QByteArray& res) {
        if (!success) {
            qCWarning(lcHypr) << "batchMessage: request error:" << QString::fromUtf8(res);
        }
    });
}

void HyprExtras::applyOptions(const QVariantHash& options) {
    if (options.isEmpty()) {
        return;
    }

    QString request;
    request.reserve(12 + options.size() * 40);
    request += u"[[BATCH]]"_s;
    for (auto it = options.constBegin(); it != options.constEnd(); ++it) {
        if (!m_usingLua) {
            request += u"keyword "_s + it.key() + u' ' + it.value().toString() + u';';
        } else {
            auto parts = it.key().split(u':');
            request += u"eval hl.config({ "_s + parts.join(u" = { "_s) + u" = "_s + it.value().toString() +
                       u" }"_s.repeated(parts.size() - 1) + u" });"_s;
        }
    }

    makeRequest(request, [this](bool success, const QByteArray& res) {
        if (success) {
            refreshOptions();
        } else {
            qCWarning(lcHypr) << "applyOptions: request error" << QString::fromUtf8(res);
        }
    });
}

void HyprExtras::refreshOptions() {
    if (!m_optionsRefresh.isNull()) {
        QObject::disconnect(m_optionsRefresh.data(), nullptr, this, nullptr);
        m_optionsRefresh->abort();
        m_optionsRefresh->deleteLater();
    }

    m_optionsRefresh = makeRequestJson(u"descriptions"_s, [this](bool success, const QJsonDocument& response) {
        m_optionsRefresh.clear();
        if (!success) {
            return;
        }

        const auto options = response.array();
        bool dirty = false;

        for (const auto& o : std::as_const(options)) {
            const auto obj = o.toObject();
            const auto key = obj.value(u"value"_s).toString();
            const auto value = obj.value(u"data"_s).toObject().value(u"current"_s).toVariant();
            if (m_options.value(key) != value) {
                dirty = true;
                m_options.insert(key, value);
            }
        }

        if (dirty) {
            emit optionsChanged();
        }
    });
}

void HyprExtras::refreshDevices() {
    if (!m_devicesRefresh.isNull()) {
        QObject::disconnect(m_devicesRefresh.data(), nullptr, this, nullptr);
        m_devicesRefresh->abort();
        m_devicesRefresh->deleteLater();
    }

    m_devicesRefresh = makeRequestJson(u"devices"_s, [this](bool success, const QJsonDocument& response) {
        m_devicesRefresh.clear();
        if (success) {
            m_devices->updateLastIpcObject(response.object());
        }
    });
}

void HyprExtras::socketError(QLocalSocket::LocalSocketError error) const {
    if (!m_socketValid) {
        qCWarning(lcHypr) << "socketError: unable to connect to Hyprland event socket:" << error;
    } else {
        qCWarning(lcHypr) << "socketError: Hyprland event socket error:" << error;
    }
}

void HyprExtras::socketStateChanged(QLocalSocket::LocalSocketState state) {
    if (state == QLocalSocket::UnconnectedState && m_socketValid) {
        qCWarning(lcHypr) << "socketStateChanged: Hyprland event socket disconnected.";
    }

    m_socketValid = state == QLocalSocket::ConnectedState;
}

void HyprExtras::readEvent() {
    while (m_socket->canReadLine()) {
        auto rawEvent = m_socket->readLine();
        rawEvent.truncate(rawEvent.length() - 1); // Remove trailing \n
        const auto sep = rawEvent.indexOf(">>");
        if (sep < 0) {
            qCWarning(lcHypr) << "readEvent: malformed event (no >> separator):" << rawEvent;
            continue;
        }
        handleEvent(QString::fromUtf8(QByteArrayView(rawEvent.data(), sep)));
    }
}

void HyprExtras::handleEvent(const QString& event) {
    if (event == u"configreloaded"_s) {
        refreshOptions();
    } else if (event == u"activelayout"_s) {
        refreshDevices();
    }
}

HyprExtras::SocketPtr HyprExtras::makeRequestJson(
    const QString& request, const std::function<void(bool, QJsonDocument)>& callback) {
    return makeRequest(u"j/"_s + request, [callback](bool success, const QByteArray& response) {
        const auto document = QJsonDocument::fromJson(response);
        callback(success && !document.isNull(), document);
    });
}

HyprExtras::SocketPtr HyprExtras::makeRequest(
    const QString& request, const std::function<void(bool, QByteArray)>& callback) {
    if (m_requestSocket.isEmpty()) {
        return {};
    }

    auto* socket = new QLocalSocket(this);

    QObject::connect(socket, &QLocalSocket::connected, this, [socket, request]() {
        socket->write(request.toUtf8());
        socket->flush();
    });

    QObject::connect(socket, &QLocalSocket::disconnected, this, [this, socket, callback]() {
        QObject::disconnect(socket, nullptr, this, nullptr);
        socket->deleteLater();
        callback(true, socket->readAll());
    });

    QObject::connect(socket, &QLocalSocket::errorOccurred, this, [this, socket, request, callback](QLocalSocket::LocalSocketError err) {
        if (err == QLocalSocket::PeerClosedError)
            return;

        qCWarning(lcHypr) << "makeRequest: error making request:" << err << "| request:" << request;
        QObject::disconnect(socket, nullptr, this, nullptr);
        socket->abort();
        socket->deleteLater();
        callback(false, {});
    });

    socket->connectToServer(m_requestSocket);

    return socket;
}

} // namespace caelestia::services::hypr
