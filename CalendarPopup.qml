import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: root
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    visible: false
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-calendar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property date viewDate: new Date()
    property date today: new Date()

    readonly property var monthNames: [
        "Январь", "Февраль", "Март", "Апрель", "Май", "Июнь",
        "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"
    ]

    readonly property var monthNamesGen: [
        "января", "февраля", "марта", "апреля", "мая", "июня",
        "июля", "августа", "сентября", "октября", "ноября", "декабря"
    ]

    readonly property var dayNames: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    readonly property var weekdayFull: ["Воскресенье", "Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота"]

    function refreshToday() {
        root.today = new Date()
    }

    function todayLabel() {
        var d = root.today
        return weekdayFull[d.getDay()] + ", " + d.getDate() + " " + monthNamesGen[d.getMonth()]
    }

    function firstWeekday(year, month) {
        var d = new Date(year, month, 1).getDay()
        return (d + 6) % 7
    }

    function daysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate()
    }

    function isToday(day) {
        return day === today.getDate()
            && viewDate.getMonth() === today.getMonth()
            && viewDate.getFullYear() === today.getFullYear()
    }

    function prevMonth() {
        var d = new Date(viewDate.getFullYear(), viewDate.getMonth() - 1, 1)
        viewDate = d
    }

    function nextMonth() {
        var d = new Date(viewDate.getFullYear(), viewDate.getMonth() + 1, 1)
        viewDate = d
    }

    function goToday() {
        refreshToday()
        viewDate = new Date(today.getFullYear(), today.getMonth(), 1)
    }

    Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refreshToday()
    }

    onVisibleChanged: {
        if (visible) root.refreshToday()
    }

    IpcHandler {
        target: "calendar"
        function toggle(): void { root.visible = !root.visible }
    }

    CloseHandler {
        target: root
    }

    Rectangle {
        id: calendarBox
        anchors.horizontalCenter: parent.horizontalCenter
        width: 336
        height: 372
        radius: 16
        color: Theme.bg
        border.color: Theme.surface
        border.width: 1

        y: root.visible ? 38 : -height - 20

        Behavior on y {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "󰃭"
                    color: Theme.accent
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                }

                Text {
                    Layout.fillWidth: true
                    text: root.monthNames[root.viewDate.getMonth()] + " " + root.viewDate.getFullYear()
                    color: Theme.fg
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    font.bold: true
                    elide: Text.ElideRight
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 8
                    color: prevArea.containsMouse ? Theme.surface : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰅁"
                        color: prevArea.containsMouse ? Theme.accent : Theme.fgMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: prevArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.prevMonth()
                    }
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 8
                    color: nextArea.containsMouse ? Theme.surface : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰅂"
                        color: nextArea.containsMouse ? Theme.accent : Theme.fgMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: nextArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.nextMonth()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.todayLabel()
                color: Theme.fgMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 7
                columnSpacing: 2
                rowSpacing: 4

                Repeater {
                    model: root.dayNames

                    delegate: Text {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: index >= 5 ? Theme.accent : Theme.fgMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        font.bold: true
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 7
                columnSpacing: 2
                rowSpacing: 2

                Repeater {
                    model: root.firstWeekday(root.viewDate.getFullYear(), root.viewDate.getMonth())

                    delegate: Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                    }
                }

                Repeater {
                    model: root.daysInMonth(root.viewDate.getFullYear(), root.viewDate.getMonth())

                    delegate: Rectangle {
                        required property int index
                        property int dayNum: index + 1
                        property bool isCurrentDay: root.isToday(dayNum)

                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        radius: 8
                        color: isCurrentDay ? Theme.accent : (dayArea.containsMouse ? Theme.surface : "transparent")

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: parent.dayNum
                            color: parent.isCurrentDay ? Theme.bg : Theme.fg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            font.bold: parent.isCurrentDay
                        }

                        MouseArea {
                            id: dayArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 120
                Layout.preferredHeight: 30
                radius: 8
                color: todayArea.containsMouse ? Theme.accent : Theme.surface
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "Сегодня"
                    color: todayArea.containsMouse ? Theme.bg : Theme.fg
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                }

                MouseArea {
                    id: todayArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.goToday()
                }
            }
        }
    }
}
