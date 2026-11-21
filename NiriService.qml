pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    property var allWorkspaces: []

    // Индекс текущей раскладки (приходит из event-stream, без поллинга)
    property int keyboardLayoutIdx: 0

    // Начальное состояние
    Process {
        id: initialFetch
        command: ["niri", "msg", "--json", "-j", "workspaces"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(this.text)
                    list.sort((a, b) => a.idx - b.idx)
                    root.allWorkspaces = list
                } catch (e) {
                }
            }
        }
    }

    // Одна выборка списка раскладок (имена статичны, дальше только события)
    Process {
        id: layoutsFetch
        command: ["niri", "msg", "-j", "keyboard-layouts"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const layouts = JSON.parse(this.text)
                    root.keyboardLayoutIdx = layouts.current_idx
                } catch (e) {
                    // ignore
                }
            }
        }
    }

    // Поток событий в JSON
    Process {
        id: eventStream
        command: ["niri", "msg", "--json", "event-stream"]
        running: true

        stdout: SplitParser {
            onRead: line => {
                try {
                    const event = JSON.parse(line)
                    root.handleNiriEvent(event)
                } catch (e) {
                    // игнорируем не-JSON строки (например, "Started reading events.")
                }
            }
        }

        onExited: (code, status) => {
            restartTimer.running = true
        }
    }

    Timer {
        id: restartTimer
        interval: 1000
        repeat: false
        onTriggered: eventStream.running = true
    }

    function handleNiriEvent(event) {
        if (event.WorkspacesChanged) {
            const list = event.WorkspacesChanged.workspaces
            list.sort((a, b) => a.idx - b.idx)
            root.allWorkspaces = list
        }
        else if (event.KeyboardLayoutsChanged) {
            root.keyboardLayoutIdx = event.KeyboardLayoutsChanged.keyboard_layouts.current_idx
        }
        else if (event.KeyboardLayoutSwitched) {
            root.keyboardLayoutIdx = event.KeyboardLayoutSwitched.idx
        }
        else if (event.WorkspaceActivated) {
            const id = event.WorkspaceActivated.id
            const focused = event.WorkspaceActivated.focused
            const arr = root.allWorkspaces.map(w => {
                const copy = Object.assign({}, w)
                if (w.id === id) {
                    copy.is_active = true
                    if (focused) copy.is_focused = true
                } else if (w.output === root.getOutputOf(id)) {
                    copy.is_active = false
                    copy.is_focused = false
                }
                return copy
            })
            root.allWorkspaces = arr
        }
        else if (event.WorkspaceUrgencyChanged) {
            const id = event.WorkspaceUrgencyChanged.id
            const urgent = event.WorkspaceUrgencyChanged.urgent
            root.allWorkspaces = root.allWorkspaces.map(w => {
                if (w.id === id) {
                    const copy = Object.assign({}, w)
                    copy.is_urgent = urgent
                    return copy
                }
                return w
            })
        }
    }

    function getOutputOf(id) {
        const ws = root.allWorkspaces.find(w => w.id === id)
        return ws ? ws.output : ""
    }

    function focusWorkspace(idx) {
        Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(idx)])
    }
}

