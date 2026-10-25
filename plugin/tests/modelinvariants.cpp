#include <qfile.h>
#include <qqmlcomponent.h>
#include <qqmlengine.h>
#include <qstandarditemmodel.h>
#include <qtemporarydir.h>
#include <qtest.h>

#include "animatedrepeater.hpp"
#include "filesystemmodel.hpp"

class c_model_invariants_test : public QObject {
    Q_OBJECT

private slots:
    void repeater_notifies_updated_count_after_removal() {
        QQmlEngine engine;
        QQmlComponent delegate(&engine);
        delegate.setData("import QtQuick\nItem {}", QUrl());
        QVERIFY2(delegate.isReady(), qPrintable(delegate.errorString()));
        QStandardItemModel model(3, 1);
        caelestia::components::AnimatedRepeater repeater;
        repeater.setDelegate(&delegate);
        repeater.setModel(QVariant::fromValue(&model));
        repeater.componentComplete();
        QList<int> notified_counts;
        connect(&repeater, &caelestia::components::AnimatedRepeater::countChanged, this, [&] {
            notified_counts.append(repeater.count());
        });
        QVERIFY(model.removeRow(1));
        QCOMPARE(repeater.count(), 2);
        QCOMPARE(notified_counts, QList<int>{ 2 });
    }

    void filesystem_reverse_sort_reorders_existing_entries() {
        const QTemporaryDir directory;
        QVERIFY(directory.isValid());
        for (const auto& name : { QStringLiteral("a.txt"), QStringLiteral("c.txt"), QStringLiteral("d.txt") }) {
            QFile file(directory.filePath(name));
            QVERIFY(file.open(QIODevice::WriteOnly));
        }
        caelestia::models::FileSystemModel model;
        model.setPath(directory.path());
        QTRY_COMPARE(model.rowCount(), 3);
        QCOMPARE(model.data(model.index(0, 0), Qt::UserRole).value<caelestia::models::FileSystemEntry*>()->name(), QStringLiteral("a.txt"));
        model.setSortReverse(true);
        QTRY_COMPARE(model.data(model.index(0, 0), Qt::UserRole).value<caelestia::models::FileSystemEntry*>()->name(), QStringLiteral("d.txt"));
        QCOMPARE(model.data(model.index(2, 0), Qt::UserRole).value<caelestia::models::FileSystemEntry*>()->name(), QStringLiteral("a.txt"));
        QFile added_file(directory.filePath(QStringLiteral("b.txt")));
        QVERIFY(added_file.open(QIODevice::WriteOnly));
        added_file.close();
        QTRY_COMPARE(model.rowCount(), 4);
        QCOMPARE(model.data(model.index(2, 0), Qt::UserRole).value<caelestia::models::FileSystemEntry*>()->name(), QStringLiteral("b.txt"));
        model.setSortReverse(false);
        QTRY_COMPARE(model.data(model.index(0, 0), Qt::UserRole).value<caelestia::models::FileSystemEntry*>()->name(), QStringLiteral("a.txt"));
    }
};

QTEST_MAIN(c_model_invariants_test)
#include "modelinvariants.moc"
