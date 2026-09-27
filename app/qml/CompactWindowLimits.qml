import QtQuick
import bbhouse

// 桌面下限在启动后记下（含 Windows 无边框标题栏加上的高度）。
// compact 时降到 360。写回下限前先确认窗口已经不小于该值，避免被突然撑大。
QtObject {
    id: limits

    property Window host
    property bool followShrink: false
    property int floor: 360
    property int desktopMinWidth: 0
    property int desktopMinHeight: 0
    property bool captured: false
    property real trackedWidth: -1

    function captureDesktopFloor() {
        desktopMinWidth = host.minimumWidth
        desktopMinHeight = host.minimumHeight
        captured = true
        if (host.width > 0) trackedWidth = host.width
        if (followShrink && host.width > 0) AppFormFactor.noteWidth(host.width)
        sync()
    }

    function loosen() {
        host.minimumWidth = floor
        host.minimumHeight = floor
    }

    function sync() {
        if (!captured || !host) return
        if (AppFormFactor.compact) {
            loosen()
            return
        }
        if (host.width >= desktopMinWidth && host.height >= desktopMinHeight) {
            host.minimumWidth = desktopMinWidth
            host.minimumHeight = desktopMinHeight
        }
    }

    // 主窗口变窄时立刻放开下限，否则 880 的下限会挡住通向 600 的拖拽。
    // 松手后再决定是否锁回桌面下限。
    function noteHostWidth(width) {
        if (!captured || width <= 0) return
        if (followShrink && trackedWidth > 0 && width < trackedWidth) loosen()
        trackedWidth = width
        if (followShrink) AppFormFactor.noteWidth(width)
        settle.restart()
    }

    property Timer settle: Timer {
        interval: 200
        onTriggered: limits.sync()
    }
    property bool compactState: AppFormFactor.compact
    onCompactStateChanged: sync()
}
