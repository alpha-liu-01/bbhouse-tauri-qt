import QtQuick
import FluentUI
import bbhouse

// 独立点播窗口。画面在 PlayerView，窄屏由主窗口装载同一视图。
FluWindow {
    id: window

    width: 1200
    height: 720
    minimumWidth: 880
    minimumHeight: 560
    CompactWindowLimits { id: window_limits; host: window }
    launchMode: FluWindowType.SingleTask
    title: PlayerController.currentTitle.length > 0 ? PlayerController.currentTitle
                                                    : qsTr("播放器")
    Component.onCompleted: window_limits.captureDesktopFloor()
    onWidthChanged: window_limits.sync()
    onHeightChanged: window_limits.sync()
    onVisibleChanged: if (visible) player_view.attach()

    PlayerView {
        id: player_view
        anchors.fill: parent
        host: window
        onDismiss: window.close()
    }

    closeListener: function (event) {
        player_view.releasePlayback()
        PlayerController.closeRequested()
        if (window.autoDestroy) FluRouter.removeWindow(window)
        else {
            window.visibility = Window.Hidden
            event.accepted = false
        }
    }
}
