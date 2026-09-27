import QtQuick
import FluentUI
import bbhouse

// 独立直播窗口。画面在 LivePlayerView，窄屏由主窗口装载同一视图。
FluWindow {
    id: window

    width: 1100
    height: 700
    minimumWidth: 720
    minimumHeight: 460
    CompactWindowLimits { id: window_limits; host: window }
    launchMode: FluWindowType.SingleTask
    title: LivePlayerController.title || qsTr("直播播放器")
    Component.onCompleted: window_limits.captureDesktopFloor()
    onWidthChanged: window_limits.sync()
    onHeightChanged: window_limits.sync()

    LivePlayerView {
        id: live_view
        anchors.fill: parent
        host: window
        onDismiss: window.close()
    }

    closeListener: function (event) {
        live_view.releasePlayback()
        LivePlayerController.closeRequested()
        if (window.autoDestroy) FluRouter.removeWindow(window)
        else {
            window.visibility = Window.Hidden
            event.accepted = false
        }
    }
}
