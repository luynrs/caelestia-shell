#include <qcoreapplication.h>
#include <qcoreevent.h>
#include <qnetworkaccessmanager.h>
#include <qnetworkreply.h>
#include <qpointer.h>
#include <qtemporarydir.h>

#include "lyrics.hpp"
#include "core/toaster.hpp"
#include "audioprovider.hpp"

#include <cstdio>
#include <cstdlib>

class c_offline_reply : public QNetworkReply {
public:
    explicit c_offline_reply(QObject* parent)
        : QNetworkReply(parent) {}

    void abort() override {
        if (isFinished()) {
            return;
        }
        setError(QNetworkReply::OperationCanceledError, QStringLiteral("Cancelled"));
        setFinished(true);
        emit finished();
    }

protected:
    qint64 readData(char*, qint64) override {
        return -1;
    }
};

class c_offline_manager : public QNetworkAccessManager {
public:
    explicit c_offline_manager(QObject* parent)
        : QNetworkAccessManager(parent) {}

    int request_count = 0;

protected:
    QNetworkReply* createRequest(Operation, const QNetworkRequest&, QIODevice*) override {
        request_count++;
        return new c_offline_reply(this);
    }
};

class c_audio_processor : public caelestia::services::AudioProcessor {
    void process() override {}
};

class c_service : public caelestia::services::Service {
    void start() override {}
    void stop() override {}
};

class c_reference_source : public QObject {
public:
    int destroy_receiver_count() const {
        return receivers(SIGNAL(destroyed(QObject*)));
    }
};

int main(int argc, char** argv) {
    const QTemporaryDir directory;
    if (!directory.isValid()) {
        return EXIT_FAILURE;
    }
    qputenv("XDG_CONFIG_HOME", directory.path().toUtf8());
    qputenv("XDG_STATE_HOME", directory.path().toUtf8());
    qputenv("XDG_CACHE_HOME", directory.path().toUtf8());
    const QCoreApplication application(argc, argv);

    if (argc > 1 && QString::fromLocal8Bit(argv[1]) == QStringLiteral("connections")) {
        c_service service;
        c_reference_source source;
        for (int i = 0; i < 100; i++) {
            service.ref(&source);
            service.unref(&source);
        }
        if (source.destroy_receiver_count() != 1) {
            fprintf(stderr, "Service reference cycles must not accumulate destruction connections\n");
            return EXIT_FAILURE;
        }
        return EXIT_SUCCESS;
    }

    if (argc > 1 && QString::fromLocal8Bit(argv[1]) == QStringLiteral("audio")) {
        auto* processor = new c_audio_processor;
        processor->start();
        delete processor;
        QCoreApplication::sendPostedEvents(nullptr, QEvent::MetaCall);
        return EXIT_SUCCESS;
    }

    if (argc > 1 && QString::fromLocal8Bit(argv[1]) == QStringLiteral("toast")) {
        caelestia::Toast toast(QStringLiteral("Title"), QStringLiteral("Message"), {}, caelestia::Toast::Type::Info, 0);
        QCoreApplication::processEvents();
        if (toast.closed() || toast.timeout() != 5000) {
            fprintf(stderr, "A defaulted toast timeout must keep the toast open for its resolved duration\n");
            return EXIT_FAILURE;
        }
        return EXIT_SUCCESS;
    }

    caelestia::services::Lyrics lyrics;
    delete lyrics.m_nam;
    auto* network = new c_offline_manager(&lyrics);
    lyrics.m_nam = network;
    lyrics.tryLrclib(lyrics.m_currentRequestId);
    lyrics.m_pendingReplies[lyrics.m_currentRequestId].reserve(8);
    if (argc > 1 && QString::fromLocal8Bit(argv[1]) == QStringLiteral("replace")) {
        lyrics.setTrack(QStringLiteral("Other artist"), QStringLiteral("Other track"));
        if (lyrics.m_pendingReplies.isEmpty() && network->request_count == 1) {
            return EXIT_SUCCESS;
        }
        fprintf(stderr, "Replacing a track must cancel its old requests before the load debounce\n");
        return EXIT_FAILURE;
    }

    lyrics.clearTrack();
    if (network->request_count != 1 || lyrics.loading() || lyrics.hasLyrics()) {
        fprintf(stderr, "Cancelling lyrics must not launch fallback requests from aborted callbacks\n");
        return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;
}
