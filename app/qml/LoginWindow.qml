import QtQuick
import FluentUI
import bbhouse

FluWindow {
    id: window
    width: 640
    height: 780
    minimumWidth: 520
    minimumHeight: 600
    CompactWindowLimits { id: window_limits; host: window }
    launchMode: FluWindowType.SingleTask
    Component.onCompleted: window_limits.captureDesktopFloor()
    onWidthChanged: window_limits.sync()
    onHeightChanged: window_limits.sync()
    title: qsTr("登录")
    Component.onDestruction: LoginController.cancel()
    LoginPage {
        anchors.fill: parent
        onCompleted: {
            FluRouter.navigate("/")
            window.close()
        }
    }
}
