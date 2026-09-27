import QtQuick
import FluentUI
import bbhouse
import "controls"
import "js/Format.js" as Format

// 点播画面。独立窗口与窄屏主窗口共用同一棵控件树。
Item {
    id: view

    property Window host
    property bool embedded: false
    signal dismiss()

    readonly property bool offscreen: Qt.platform.pluginName === "offscreen"
    property bool panelExpanded: true
    readonly property int panelWidth: PlayerController.seasonMode ? 0
                                                                  : (panelExpanded ? 300 : 0)
    readonly property bool fullscreenActive: host && host.visibility === Window.FullScreen
    onFullscreenActiveChanged: {
        panelExpanded = false
        pokeControls()
    }
    property int prevVisibility: Window.Windowed
    property int prevAppBarHeight: 48
    property bool controlsShown: true
    readonly property bool cursorHidden: !controlsShown && !controlsLocked && video_click.containsMouse
    readonly property bool controlsLocked: playback_controls.interacting || top_hover.hovered
                                          || top_bar.activeFocus || entitlement_dialog.visible || download_dialog.visible
                                          || PlayerController.paused || PlayerController.loading
                                          || PlayerController.buffering
    onControlsLockedChanged: {
        pokeControls()
        if (!controlsLocked && !video_click.containsMouse) scheduleQuickHide()
    }
    onWidthChanged: if (width < 1080) panelExpanded = false

    function attach() {
        if (!offscreen && host) PlayerController.attachMediaWindow(host)
    }
    Component.onCompleted: attach()
    onHostChanged: attach()

    function pokeControls() {
        controlsShown = true
        quick_hide.stop()
        hide_timer.restart()
    }
    function scheduleQuickHide() {
        if (!controlsLocked) {
            hide_timer.stop()
            quick_hide.restart()
        }
    }
    function toggleFullscreen() {
        if (!host) return
        if (fullscreenActive) {
            if (!embedded && host.appBar) {
                host.appBar.visible = true
                host.appBar.height = prevAppBarHeight
            }
            host.visibility = prevVisibility === Window.Maximized ? Window.Maximized
                                                                  : Window.Windowed
            if (embedded && host.resumeFromFullscreen) host.resumeFromFullscreen()
        } else {
            prevVisibility = host.visibility
            if (embedded && host.suspendForFullscreen) host.suspendForFullscreen()
            if (!embedded && host.appBar) {
                prevAppBarHeight = host.appBar.height > 0 ? host.appBar.height : 48
                host.appBar.visible = false
                host.appBar.height = 0
            }
            host.visibility = Window.FullScreen
        }
        pokeControls()
    }
    function unmountItems() {
        if (PlayerController.videoItem) PlayerController.videoItem.parent = null
        if (PlayerController.danmakuItem) PlayerController.danmakuItem.parent = null
    }
    function releasePlayback() {
        playback_controls.cancelInteraction()
        unmountItems()
    }
    Component.onDestruction: unmountItems()

    DownloadDialog { id: download_dialog }
    Connections {
        target: DownloadController
        function onErrorChanged() {
            if (host && host.visible && DownloadController.error !== "")
                host.showError(DownloadController.error, 6000)
        }
    }

    Timer {
        id: hide_timer

        interval: 3000
        onTriggered: {
            if (!view.controlsLocked) view.controlsShown = false
        }
    }

    Timer {
        id: quick_hide

        interval: 600
        onTriggered: {
            if (!view.controlsLocked) view.controlsShown = false
        }
    }

    FluContentDialog {
        id: entitlement_dialog

        title: qsTr("无法播放")
        message: ""
        buttonFlags: FluContentDialogType.PositiveButton
        positiveText: qsTr("知道了")
        onPositiveClicked: {
            // 确认后移除该条目;移除后列表为空 → 关闭窗口,非空 → 停留无源不自动续播
            PlayerController.removeAt(PlayerController.currentIndex)
            if (PlayerController.playlist.length === 0) dismiss()
        }
    }

    Item {
        id: root

        anchors.fill: parent
        focus: true

        // 键盘快捷键:焦点不在消费按键的控件(列表/按钮)时生效
        // (事件自焦点控件沿父链冒泡,列表导航/按钮空格先行消费,天然不抢占)
        Keys.onPressed: function (event) {
            if (playback_controls.menuOpen || entitlement_dialog.visible) {
                event.accepted = false
                return
            }
            switch (event.key) {
            case Qt.Key_Space:
                PlayerController.togglePlayPause()
                event.accepted = true
                break
            case Qt.Key_Left:
                PlayerController.seek(PlayerController.position - 5)
                event.accepted = true
                break
            case Qt.Key_Right:
                PlayerController.seek(PlayerController.position + 5)
                event.accepted = true
                break
            case Qt.Key_Up:
                PlayerController.setVolumePercent(PlayerController.volumePercent + 5)
                event.accepted = true
                break
            case Qt.Key_Down:
                PlayerController.setVolumePercent(PlayerController.volumePercent - 5)
                event.accepted = true
                break
            case Qt.Key_F:
                view.toggleFullscreen()
                event.accepted = true
                break
            case Qt.Key_Escape:
                if (view.fullscreenActive) view.toggleFullscreen()
                event.accepted = true
                break
            case Qt.Key_M:
                playback_controls.toggleMute()
                event.accepted = true
                break
            case Qt.Key_N:
                if ((event.modifiers & Qt.ShiftModifier) && playback_controls.hasNext) {
                    PlayerController.playNext()
                    event.accepted = true
                }
                break
            case Qt.Key_D:
                PlayerController.toggleDanmaku()
                event.accepted = true
                break
            case Qt.Key_S:
                PlayerController.toggleSubtitle()
                event.accepted = true
                break
            }
            if (event.accepted) view.pokeControls()
        }

        // 视频区(右侧留出播放列表面板)
        Item {
            id: video_holder

            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                rightMargin: view.panelWidth
            }
            clip: true

            Rectangle {
                z: 2
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: view.controlsShown ? playback_controls.height + 24 : 28
                width: Math.min(subtitle_label.implicitWidth + 24, video_holder.width - 40)
                height: subtitle_label.implicitHeight + 12
                radius: 4
                color: "#b3000000"
                visible: PlayerController.subtitleText.length > 0
                Text {
                    id: subtitle_label
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, video_holder.width - 64)
                    text: PlayerController.subtitleText
                    textFormat: Text.PlainText
                    color: "white"
                    font.pixelSize: Math.max(18, Math.min(30, video_holder.width / 32))
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Component.onCompleted: {
                // C++ 创建的项挂载到窗口(offscreen 冒烟跳过 GL 视频项,避免无头渲染)
                if (!view.offscreen && PlayerController.videoItem) {
                    PlayerController.videoItem.z = 0
                    PlayerController.videoItem.parent = video_holder
                    PlayerController.videoItem.anchors.fill = video_holder
                    PlayerController.videoItem.visible = true
                }
                if (PlayerController.danmakuItem) {
                    PlayerController.danmakuItem.z = 1
                    PlayerController.danmakuItem.parent = video_holder
                    PlayerController.danmakuItem.anchors.fill = video_holder
                    PlayerController.danmakuItem.visible = true
                }
            }
        }

        // 画面点击:切换播放/暂停 + 呼出控制栏;指针移动重置自动隐藏计时
        MouseArea {
            id: video_click

            z: 2
            anchors.fill: video_holder
            hoverEnabled: true
            cursorShape: view.cursorHidden ? Qt.BlankCursor : Qt.ArrowCursor
            onEntered: view.pokeControls()
            onClicked: {
                PlayerController.togglePlayPause()
                root.forceActiveFocus()
                view.pokeControls()
            }
            onPositionChanged: {
                view.pokeControls()
            }
            onExited: {
                view.scheduleQuickHide()
            }
        }

        // 缓冲状态指示:解析中 / paused-for-cache 时中央显示;不拦截指针交互
        Item {
            z: 3
            anchors.fill: video_holder
            visible: PlayerController.buffering || PlayerController.loading

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.35)
            }
            Column {
                spacing: 12
                anchors.centerIn: parent
                FluProgressRing {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 48
                    height: 48
                    indeterminate: true
                }
                FluText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Qt.rgba(1, 1, 1, 1)
                    text: PlayerController.loading ? qsTr("正在解析播放地址...")
                                                   : qsTr("正在缓冲")
                }
            }
        }

        // 覆盖层只在顶部/底部命中，中央画面保持可点击。
        Item {
            id: overlay
            z: 4
            anchors.fill: video_holder
            opacity: view.controlsShown ? 1 : 0
            visible: opacity > 0.01
            enabled: view.controlsShown
            Behavior on opacity { NumberAnimation { duration: 200 } }

            FocusScope {
                id: top_bar
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 72
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#b8000000" }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }
                MouseArea { anchors.fill: parent; onClicked: view.pokeControls() }
                HoverHandler {
                    id: top_hover
                    onPointChanged: view.pokeControls()
                }
                PlayerControlButton {
                    id: back_button
                    x: 12; y: 10
                    iconSource: FluentIcons.Back
                    contentDescription: qsTr("返回")
                    onClicked: dismiss()
                }
                FluText {
                    anchors { left: back_button.right; right: top_actions.left; top: parent.top
                        leftMargin: 10; rightMargin: 16; topMargin: 16 }
                    text: PlayerController.currentTitle || qsTr("播放器")
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    color: "#f5f5f5"
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                Row {
                    id: top_actions
                    anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: 10 }
                    spacing: 4
                    PlayerControlButton {
                        objectName: "playerDownloadButton"
                        iconSource: FluentIcons.Download
                        contentDescription: qsTr("下载")
                        visible: !PlayerController.localMedia
                        enabled: !PlayerController.loading && PlayerController.currentIndex >= 0
                        onClicked: {
                            download_dialog.showFor(PlayerController.playlist[PlayerController.currentIndex])
                            view.pokeControls()
                        }
                    }
                    PlayerControlButton {
                        iconSource: FluentIcons.Camera
                        contentDescription: qsTr("截图")
                        onClicked: { PlayerController.screenshot(); root.forceActiveFocus(); view.pokeControls() }
                    }
                    PlayerControlButton {
                        iconSource: FluentIcons.ChromeClose
                        contentDescription: qsTr("关闭")
                        onClicked: dismiss()
                    }
                }
            }

            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: playback_controls.height + 44
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 0.45; color: "#73000000" }
                    GradientStop { position: 1; color: "#e0000000" }
                }
            }
            PlayerControls {
                id: playback_controls
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                    leftMargin: 16; rightMargin: 16; bottomMargin: 8 }
                height: implicitHeight
                fullscreen: view.fullscreenActive
                playlistExpanded: view.panelExpanded
                popupMaxHeight: Math.max(120, Math.min(360, video_holder.height - height - 84))
                onActivity: view.pokeControls()
                onActionTriggered: { root.forceActiveFocus(); view.pokeControls() }
                onFullscreenRequested: view.toggleFullscreen()
                onPlaylistRequested: view.panelExpanded = !view.panelExpanded
            }
        }

        // 右侧会话播放列表，折叠后不占用画面宽度。
        // 番剧剧集模式下整体隐藏(playlist 即分集表,选集走底部菜单)
        Rectangle {
            id: playlist_panel

            z: 5
            visible: !PlayerController.seasonMode && width > 0
            enabled: view.panelExpanded && !PlayerController.seasonMode
            clip: true
            width: view.panelWidth
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }
            color: "#181818"

            Behavior on width {
                NumberAnimation {
                    duration: 140
                }
            }

            Column {
                anchors.fill: parent
                visible: view.panelExpanded

                Item {
                    id: playlist_header

                    width: parent.width
                    height: 44

                    FluText {
                        text: qsTr("播放列表") + " (" + PlayerController.playlist.length + ")"
                        color: "#f5f5f5"
                        font: FluTextStyle.BodyStrong
                        anchors {
                            left: parent.left
                            leftMargin: 12
                            verticalCenter: parent.verticalCenter
                        }
                    }
                    Row {
                        spacing: 2
                        anchors {
                            right: parent.right
                            rightMargin: 4
                            verticalCenter: parent.verticalCenter
                        }

                        // 定位正在播放(瞄准)
                        PlayerControlButton {
                            width: 30
                            height: 30
                            iconSize: 14
                            iconSource: FluentIcons.Location
                            contentDescription: qsTr("定位正在播放")
                            onClicked: {
                                if (PlayerController.currentIndex >= 0) {
                                    playlist_view.positionViewAtIndex(PlayerController.currentIndex, ListView.Contain)
                                }
                            }
                        }
                    }
                }

                ListView {
                    id: playlist_view

                    width: parent.width
                    height: parent.height - playlist_header.height
                    clip: true
                    model: PlayerController.playlist
                    currentIndex: PlayerController.currentIndex
                    highlightMoveDuration: 120

                    delegate: Item {
                        id: playlist_item

                        required property int index
                        required property var modelData

                        width: playlist_view.width
                        height: 72

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: 6
                            color: playlist_item.index === PlayerController.currentIndex
                                       ? "#28ff4d4f"
                                       : playlist_mouse.containsMouse ? "#18ffffff"
                                                                      : Qt.rgba(0, 0, 0, 0)
                            border.color: playlist_item.index === PlayerController.currentIndex
                                              ? "#ff4d4f"
                                              : Qt.rgba(0, 0, 0, 0)
                            border.width: 1
                        }
                        Item {
                            anchors { fill: parent; margins: 8 }
                            clip: true
                            Image {
                                id: playlist_cover
                                width: 96
                                height: 56
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                source: Format.cardCoverThumbnailUrl(playlist_item.modelData.coverUrl)
                                sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
                                fillMode: Image.PreserveAspectCrop
                                clip: true
                                asynchronous: true
                                Rectangle {
                                    anchors.fill: parent
                                    color: Qt.rgba(0, 0, 0, 0.08)
                                }
                            }
                            Item {
                                anchors {
                                    left: playlist_cover.right
                                    leftMargin: 8
                                    right: parent.right
                                    top: parent.top
                                    bottom: parent.bottom
                                }
                                clip: true
                                FluText {
                                    id: playlist_title
                                    anchors { left: parent.left; right: parent.right; top: parent.top }
                                    height: Math.max(0, parent.height
                                            - (playlist_subtitle.visible ? playlist_subtitle.height + 4 : 0))
                                    text: String(playlist_item.modelData.title || "")
                                    textFormat: Text.PlainText
                                    font: playlist_item.index === PlayerController.currentIndex ? FluTextStyle.BodyStrong
                                                                                                : FluTextStyle.Body
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.WrapAnywhere
                                    color: playlist_item.index === PlayerController.currentIndex ? "#ff7779"
                                                                                                 : "#eeeeee"
                                }
                                FluText {
                                    id: playlist_subtitle
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        top: playlist_title.bottom
                                        topMargin: 4
                                    }
                                    text: String(playlist_item.modelData.subtitle || "").replace(/[\r\n\u2028\u2029]+/g, " ")
                                    textFormat: Text.PlainText
                                    color: "#aaaaaa"
                                    font: FluTextStyle.Caption
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                    maximumLineCount: 1
                                    opacity: 0.7
                                    visible: text.length > 0
                                }
                            }
                        }
                        MouseArea {
                            id: playlist_mouse

                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                PlayerController.playByIndex(playlist_item.index)
                            }
                        }
                    }

                    FluScrollBar {
                        anchors {
                            right: parent.right
                            top: parent.top
                            bottom: parent.bottom
                        }
                    }
                }
            }

        }

        Connections {
            target: PlayerController

            function onPausedChanged() {
                view.pokeControls()
                if (!PlayerController.paused && !playback_controls.menuOpen) root.forceActiveFocus()
            }
            // 播放进入"正在播放"状态时焦点回归播放区(快捷键不再落在列表等控件上)
            function onCurrentChanged() {
                if (PlayerController.currentIndex < 0) return
                root.forceActiveFocus()
                host.clearAllInfo()
                host.showInfo(qsTr("正在加载弹幕..."), 3000)
            }
            function onDanmakuLoaded(entries) {
                if (PlayerController.danmakuItem) {
                    PlayerController.danmakuItem.loadEntries(entries)
                }
                host.clearAllInfo()
            }
            function onDanmakuLoadFailed(message) {
                // 过程性提示不滞留:失败提示自动关闭,播放不受影响
                host.clearAllInfo()
                host.showWarning(message, 3000)
            }
            function onErrorOccurred(message) {
                host.clearAllInfo()
                host.showError(message, 4000)
            }
            function onFallbackChanged(fallback) {
                if (fallback) {
                    host.showInfo(qsTr("已回落到单流兼容模式播放"), 4000)
                }
            }
            function onKernelRecoveredNotice(message) {
                host.showWarning(message, 5000)
            }
            function onEntitlementRejected(message) {
                entitlement_dialog.message = message
                entitlement_dialog.open()
            }
            function onScreenshotSaved(path) {
                host.showSuccess(path, 4000)
            }
            function onScreenshotFailed(message) {
                host.showError(message, 4000)
            }
        }
    }
}
