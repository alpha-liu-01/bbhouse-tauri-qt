import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import FluentUI
import bbhouse
import "controls"

// 直播画面。独立窗口与窄屏主窗口共用同一棵控件树。
Item {
    id: view

    property Window host
    property bool embedded: false
    signal dismiss()

    readonly property bool offscreen: Qt.platform.pluginName === "offscreen"
    readonly property bool fullscreenActive: host && host.visibility === Window.FullScreen
    property int prevVisibility: Window.Windowed
    property int prevAppBarHeight: 48
    property bool controlsShown: true
    property bool cursorHidden: false
    readonly property bool controlsLocked: top_hover.hovered || bottom_hover.hovered
        || top_bar.activeFocus || bottom_bar.activeFocus || volume_slider.pressed
        || quality_menu.visible || LivePlayerController.paused || LivePlayerController.loading
        || LivePlayerController.buffering || LivePlayerController.errorMessage !== ""
        || LivePlayerController.roomId === ""
    onControlsLockedChanged: {
        pokeControls()
        if (!controlsLocked && !video_click.containsMouse) scheduleQuickHide()
    }

    function pokeControls() {
        controlsShown = true
        cursorHidden = false
        quick_hide.stop()
        hide_timer.restart()
        cursor_timer.restart()
    }
    function finishAction() {
        root.forceActiveFocus()
        pokeControls()
    }
    function scheduleQuickHide() {
        cursorHidden = false
        cursor_timer.stop()
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
            host.visibility = prevVisibility
            if (embedded && host.resumeFromFullscreen) host.resumeFromFullscreen()
        } else {
            prevVisibility = host.visibility === Window.Maximized ? Window.Maximized : Window.Windowed
            if (embedded && host.suspendForFullscreen) host.suspendForFullscreen()
            if (!embedded && host.appBar) {
                prevAppBarHeight = host.appBar.height
                host.appBar.visible = false
                host.appBar.height = 0
            }
            host.visibility = Window.FullScreen
        }
        finishAction()
    }
    function unmount() {
        if (LivePlayerController.videoItem) LivePlayerController.videoItem.parent = null
    }
    function releasePlayback() {
        quality_menu.close()
        unmount()
    }
    Component.onDestruction: unmount()

    Timer {
        id: hide_timer
        interval: 3000
        onTriggered: if (!view.controlsLocked) view.controlsShown = false
    }
    Timer {
        id: quick_hide
        interval: 600
        onTriggered: if (!view.controlsLocked) view.controlsShown = false
    }
    Timer {
        id: cursor_timer
        interval: 5000
        onTriggered: if (!AppFormFactor.coarsePointer && !view.controlsLocked && video_click.containsMouse)
                         view.cursorHidden = true
    }
    Connections {
        target: LivePlayerController
        function onRoomChanged() { view.finishAction() }
    }

    Item {
        id: root
        anchors.fill: parent
        focus: true
        // 未被菜单/滑块/按钮消费的按键才作为播放快捷键，与标准窗口一致。
        Keys.onPressed: function(event) {
            if (quality_menu.visible) return
            switch (event.key) {
            case Qt.Key_F:
                view.toggleFullscreen()
                event.accepted = true
                break
            case Qt.Key_Escape:
                if (view.fullscreenActive) view.toggleFullscreen()
                event.accepted = true
                break
            case Qt.Key_Space:
                LivePlayerController.togglePlayPause()
                event.accepted = true
                break
            }
            if (event.accepted) view.pokeControls()
        }
        Rectangle {
            id: video_holder
            anchors.fill: parent
            color: "black"
            clip: true
            Component.onCompleted: {
                if (Qt.platform.pluginName !== "offscreen") {
                    LivePlayerController.videoItem.z = 0
                    LivePlayerController.videoItem.parent = video_holder
                    LivePlayerController.videoItem.anchors.fill = video_holder
                    LivePlayerController.videoItem.visible = true
                }
                view.pokeControls()
            }
        }
        MouseArea {
            id: video_click
            z: 1
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: view.cursorHidden ? Qt.BlankCursor : Qt.ArrowCursor
            onClicked: {
                if (!AppFormFactor.coarsePointer) {
                    view.finishAction()
                    return
                }
                if (!view.controlsShown) view.pokeControls()
                else {
                    LivePlayerController.togglePlayPause()
                    view.pokeControls()
                }
            }
            onDoubleClicked: view.toggleFullscreen()
            onPositionChanged: if (!AppFormFactor.coarsePointer) view.pokeControls()
            onExited: if (!AppFormFactor.coarsePointer) view.scheduleQuickHide()
        }
        Column {
            z: 2
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 560)
            spacing: 14
            visible: LivePlayerController.loading || LivePlayerController.buffering
                     || LivePlayerController.errorMessage !== "" || LivePlayerController.roomId === ""
            FluProgressRing {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: LivePlayerController.loading || LivePlayerController.buffering
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: "white"
                text: LivePlayerController.errorMessage || LivePlayerController.statusText || qsTr("选择直播间开始播放")
            }
            FluButton {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: LivePlayerController.errorMessage !== ""
                text: qsTr("重新连接")
                onClicked: { LivePlayerController.retry(); view.finishAction() }
            }
        }
        Item {
            id: overlay
            z: 3
            anchors.fill: parent
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
                MouseArea { anchors.fill: parent; onClicked: view.finishAction() }
                HoverHandler { id: top_hover; onPointChanged: view.pokeControls() }
                RowLayout {
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                    spacing: 12
                    PlayerControlButton {
                        visible: view.embedded
                        iconSource: FluentIcons.Back
                        contentDescription: qsTr("返回")
                        onClicked: view.dismiss()
                    }
                    Rectangle { width: 8; height: 8; radius: 4; color: "#e13b73" }
                    FluText {
                        Layout.fillWidth: true
                        text: LivePlayerController.authorName || qsTr("直播")
                        elide: Text.ElideRight
                        font.bold: true
                        color: "#f5f5f5"
                    }
                    FluText {
                        text: LivePlayerController.roomId ? qsTr("房间 %1").arg(LivePlayerController.roomId) : ""
                        font.pixelSize: 12
                        color: "#eeeeee"
                    }
                    PlayerControlButton {
                        caption: qsTr("浏览器打开")
                        contentDescription: caption
                        enabled: LivePlayerController.roomId !== ""
                        onClicked: {
                            Qt.openUrlExternally("https://live.bilibili.com/" + LivePlayerController.roomId)
                            view.finishAction()
                        }
                    }
                }
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: bottom_bar.height + 44
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 0.45; color: "#73000000" }
                    GradientStop { position: 1; color: "#e0000000" }
                }
            }
            FocusScope {
                id: bottom_bar
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                    leftMargin: 16; rightMargin: 16; bottomMargin: 8 }
                height: 74
                MouseArea { anchors.fill: parent; onClicked: view.finishAction() }
                HoverHandler { id: bottom_hover; onPointChanged: view.pokeControls() }
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        FluText {
                            Layout.fillWidth: true
                            text: LivePlayerController.statusText
                            elide: Text.ElideRight
                            font.pixelSize: 12
                            color: "#eeeeee"
                        }
                        FluText {
                            text: qsTr("直播无进度条 · 重新连接可返回最新画面")
                            font.pixelSize: 12
                            color: "#eeeeee"
                            visible: view.width >= 880
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        PlayerControlButton {
                            iconSource: LivePlayerController.paused ? FluentIcons.Play : FluentIcons.Pause
                            contentDescription: LivePlayerController.paused ? qsTr("播放") : qsTr("暂停")
                            enabled: LivePlayerController.roomId !== "" && !LivePlayerController.loading
                                     && LivePlayerController.errorMessage === ""
                            onClicked: { LivePlayerController.togglePlayPause(); view.finishAction() }
                        }
                        PlayerControlButton {
                            iconSource: FluentIcons.Refresh
                            contentDescription: qsTr("重新连接 / 回到直播")
                            enabled: LivePlayerController.roomId !== "" && !LivePlayerController.loading
                            onClicked: { LivePlayerController.retry(); view.finishAction() }
                        }
                        PlayerControlButton {
                            iconSource: LivePlayerController.volumePercent === 0 ? FluentIcons.Mute : FluentIcons.Volume
                            contentDescription: qsTr("静音")
                            property int savedVolume: 80
                            onClicked: {
                                if (LivePlayerController.volumePercent > 0) {
                                    savedVolume = LivePlayerController.volumePercent
                                    LivePlayerController.setVolumePercent(0)
                                } else LivePlayerController.setVolumePercent(savedVolume)
                                view.finishAction()
                            }
                        }
                        FluSlider {
                            id: volume_slider
                            Layout.preferredWidth: 100
                            from: 0; to: 100
                            focusPolicy: Qt.TabFocus
                            Binding {
                                target: volume_slider
                                property: "value"
                                value: LivePlayerController.volumePercent
                                when: !volume_slider.pressed
                                restoreMode: Binding.RestoreNone
                            }
                            onMoved: {
                                LivePlayerController.setVolumePercent(Math.round(value))
                                view.pokeControls()
                            }
                            onPressedChanged: if (!pressed) view.finishAction()
                            Accessible.name: qsTr("音量")
                            background: Rectangle {
                                x: volume_slider.leftPadding + 5
                                y: (volume_slider.height - height) / 2
                                width: Math.max(0, volume_slider.availableWidth - 10)
                                height: 3; radius: 2; color: "#40ffffff"
                                Rectangle { width: volume_slider.position * parent.width; height: 3; radius: 2; color: "white" }
                            }
                            handle: Rectangle {
                                width: 10; height: 10; radius: 5; color: "white"
                                x: volume_slider.leftPadding + volume_slider.visualPosition * (volume_slider.availableWidth - width)
                                y: (volume_slider.height - height) / 2
                            }
                        }
                        Item { Layout.fillWidth: true }
                        PlayerControlButton {
                            id: quality_button
                            width: 140
                            caption: LivePlayerController.qualityLabel || qsTr("清晰度")
                            contentDescription: qsTr("清晰度")
                            enabled: LivePlayerController.qualities.length > 0 && !LivePlayerController.loading
                            onClicked: { view.pokeControls(); quality_menu.open() }
                        }
                        PlayerControlButton {
                            iconSource: view.fullscreenActive ? FluentIcons.BackToWindow : FluentIcons.FullScreen
                            contentDescription: view.fullscreenActive ? qsTr("退出全屏") : qsTr("全屏")
                            onClicked: view.toggleFullscreen()
                        }
                    }
                }
                FluMenu {
                    id: quality_menu
                    parent: bottom_bar
                    width: 224
                    padding: 6
                    x: Math.max(0, Math.min(bottom_bar.width - width, quality_button.mapToItem(bottom_bar, quality_button.width, 0).x - width))
                    y: -height - 10
                    height: Math.min(implicitHeight, Math.max(100, root.height - bottom_bar.height - top_bar.height - 24))
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                    contentItem: ListView {
                        implicitHeight: contentHeight
                        model: quality_menu.contentModel
                        currentIndex: quality_menu.currentIndex
                        clip: true
                        interactive: contentHeight > height
                        ScrollBar.vertical: FluScrollBar {}
                    }
                    background: Rectangle { radius: 12; color: "#fa202020"; border.color: "#33ffffff" }
                    onOpened: view.pokeControls()
                    onClosed: view.finishAction()
                    Repeater {
                        model: LivePlayerController.qualities
                        FluMenuItem {
                            id: quality_item
                            required property var modelData
                            implicitHeight: 36
                            text: modelData.label
                            checkable: true
                            checked: modelData.qn === LivePlayerController.currentQn
                            contentItem: FluText {
                                text: quality_item.text
                                font.pixelSize: 13
                                color: quality_item.checked ? "#ff4d4f" : "#f5f5f5"
                                leftPadding: 26; rightPadding: 8
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                            indicator: FluIcon {
                                x: 10
                                anchors.verticalCenter: parent.verticalCenter
                                iconSource: FluentIcons.CheckMark
                                iconSize: 13
                                iconColor: "#ff4d4f"
                                visible: quality_item.checked
                            }
                            background: Rectangle {
                                radius: 8
                                color: quality_item.highlighted || quality_item.hovered ? "#26ffffff"
                                    : quality_item.checked ? "#20ff4d4f" : "transparent"
                            }
                            onTriggered: LivePlayerController.setQuality(modelData.qn)
                        }
                    }
                }
            }
        }
    }
}
