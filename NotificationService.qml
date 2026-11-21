pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: root

    property var history: []
    property bool dnd: false
    property int nextId: 1
    property int maxHistory: 50

    function _emit() { history = history.slice() }

    function normalizeActions(actions) {
        var out = []
        if (!actions) return out
        var arr = []
        if (actions.length !== undefined) {
            for (var k = 0; k < actions.length; k++) arr.push(actions[k])
        } else if (actions.forEach) {
            try { actions.forEach(function(a) { arr.push(a) }) } catch (e) {}
        }
        for (var i = 0; i < arr.length; i++) {
            var a = arr[i]
            if (!a) continue
            var id = a.identifier !== undefined ? a.identifier : (a.id !== undefined ? a.id : "")
            var text = a.text !== undefined ? a.text : (a.label !== undefined ? a.label : String(id))
            if (id === "" || text === "") continue
            out.push({ identifier: String(id), text: String(text), _obj: a })
        }
        return out
    }

    function addNotification(notif) {
        if (dnd) return
        var app = (notif && notif.appName) ? String(notif.appName) : "Приложение"
        var summary = (notif && notif.summary) ? String(notif.summary) : ""
        var body = (notif && notif.body) ? String(notif.body) : ""
        var urgency = (notif && notif.urgency !== undefined) ? notif.urgency : 1
        var actions = normalizeActions(notif ? notif.actions : null)

        for (var i = 0; i < history.length; i++) {
            var it = history[i]
            if (it.appName === app && it.summary === summary && it.body === body) {
                it.timestamp = new Date()
                it.count = (it.count || 1) + 1
                it.urgency = urgency
                it.actions = actions.length ? actions : it.actions
                // move to top
                history.splice(i, 1)
                history.unshift(it)
                _emit()
                return
            }
        }

        history.unshift({
            id: root.nextId++,
            appName: app, summary: summary, body: body,
            urgency: urgency, timestamp: new Date(),
            actions: actions, count: 1
        })
        while (history.length > root.maxHistory) history.pop()
        _emit()
    }

    function dismiss(id) {
        var idx = -1
        for (var i = 0; i < history.length; i++) if (history[i].id === id) { idx = i; break }
        if (idx >= 0) { history.splice(idx, 1); _emit() }
    }

    function dismissApp(appName) {
        var changed = false
        for (var i = history.length - 1; i >= 0; i--) {
            if (history[i].appName === appName) { history.splice(i, 1); changed = true }
        }
        if (changed) _emit()
    }

    function dismissAll() { history = [] }

    function invokeAction(id, actionId) {
        for (var i = 0; i < history.length; i++) {
            var it = history[i]
            if (it.id !== id) continue
            var acts = it.actions || []
            for (var j = 0; j < acts.length; j++) {
                var a = acts[j]
                if (String(a.identifier) !== String(actionId)) continue
                var obj = a._obj
                try {
                    if (obj && obj.invoke) obj.invoke()
                    else if (obj && obj.trigger) obj.trigger()
                } catch (e) {}
                dismiss(id)
                return
            }
        }
    }

    function toggleDnd() { root.dnd = !root.dnd }
}
