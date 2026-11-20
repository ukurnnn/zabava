pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import QtQml.Models

QtObject {
    id: root

    // Список уведомлений (новые сверху)
    property ListModel history: ListModel {}

    // Включён ли режим "Не беспокоить"
    property bool dnd: false

    // Счётчик для ID
    property int nextId: 1

    function addNotification(notif) {
        if (dnd) return

        var item = {
            id: root.nextId++,
            appName: notif.appName || "",
            summary: notif.summary || "",
            body: notif.body || "",
            urgency: notif.urgency,
            timestamp: new Date(),
            actions: notif.actions || []
        }

        root.history.insert(0, item)

        // Ограничиваем историю 50 записями
        while (root.history.count > 50) {
            root.history.remove(root.history.count - 1)
        }
    }

    function dismiss(id) {
        for (var i = 0; i < root.history.count; i++) {
            if (root.history.get(i).id === id) {
                root.history.remove(i)
                return
            }
        }
    }

    function dismissAll() {
        root.history.clear()
    }

    function toggleDnd() {
        root.dnd = !root.dnd
    }
}
