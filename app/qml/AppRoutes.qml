pragma Singleton
import QtQuick
import FluentUI
import bbhouse

// 窄屏把登录、点播和直播留在主窗口；宽屏仍打开原来的窗口。
QtObject {
    signal playerRequested()
    signal liveRequested()
    signal loginRequested()

    function openPlayer() {
        if (AppFormFactor.compact) playerRequested()
        else FluRouter.navigate("/player")
    }
    function openLive() {
        if (AppFormFactor.compact) liveRequested()
        else FluRouter.navigate("/live-player")
    }
    function openLogin() {
        if (AppFormFactor.compact) loginRequested()
        else FluRouter.navigate("/login")
    }
}
