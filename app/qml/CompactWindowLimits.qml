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
    property bool fullscreenSuspended: false
    property bool restoringGeometry: false
    property rect savedGeometry: Qt.rect(0, 0, 0, 0)

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
        if (fullscreenSuspended || restoringGeometry || host.visibility === Window.FullScreen) return
        if (AppFormFactor.compact) {
            loosen()
            return
        }
        if (host.width >= desktopMinWidth && host.height >= desktopMinHeight) {
            host.minimumWidth = desktopMinWidth
            host.minimumHeight = desktopMinHeight
        }
    }

    // 全屏会把窗口拉到屏幕尺寸。这段尺寸不能拿来退出 compact，也不能锁回桌面下限。
    function suspendForFullscreen() {
        if (!host || fullscreenSuspended) return
        savedGeometry = Qt.rect(host.x, host.y, host.width, host.height)
        fullscreenSuspended = true
        settle.stop()
    }
    function resumeFromFullscreen() {
        if (!host) return
        var geometry = savedGeometry
        fullscreenSuspended = false
        if (geometry.width <= 0 || geometry.height <= 0) {
            sync()
            return
        }
        restoringGeometry = true
        host.setGeometry(geometry.x, geometry.y, geometry.width, geometry.height)
        trackedWidth = geometry.width
        if (followShrink) AppFormFactor.noteWidth(geometry.width)
        restoreHold.restart()
        sync()
    }
    function reapplySavedGeometry() {
        if (!host) return
        var geometry = savedGeometry
        if (geometry.width <= 0 || geometry.height <= 0) return
        if (Math.abs(host.width - geometry.width) <= 2 && Math.abs(host.height - geometry.height) <= 2
                && Math.abs(host.x - geometry.x) <= 2 && Math.abs(host.y - geometry.y) <= 2) return
        host.setGeometry(geometry.x, geometry.y, geometry.width, geometry.height)
    }

    // 主窗口变窄时立刻放开下限，否则 880 的下限会挡住通向 600 的拖拽。
    // 松手后再决定是否锁回桌面下限。
    function noteHostWidth(width) {
        if (!captured || width <= 0 || !host) return
        if (restoringGeometry) {
            settle.stop()
            reapplySavedGeometry()
            return
        }
        if (fullscreenSuspended || host.visibility === Window.FullScreen) {
            settle.stop()
            return
        }
        if (followShrink && trackedWidth > 0 && width < trackedWidth) loosen()
        trackedWidth = width
        if (followShrink) AppFormFactor.noteWidth(width)
        settle.restart()
    }

    property Timer settle: Timer {
        interval: 200
        onTriggered: limits.sync()
    }
    property Timer restoreHold: Timer {
        interval: 400
        onTriggered: {
            limits.reapplySavedGeometry()
            limits.restoringGeometry = false
            if (!limits.host || !limits.captured) return
            var width = limits.savedGeometry.width > 0 ? limits.savedGeometry.width : limits.host.width
            limits.trackedWidth = width
            if (limits.followShrink) AppFormFactor.noteWidth(width)
            limits.sync()
        }
    }
    property bool compactState: AppFormFactor.compact
    onCompactStateChanged: sync()
}
