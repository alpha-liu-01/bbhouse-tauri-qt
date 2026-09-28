pragma Singleton
import QtQuick

// 窄屏形态只由主窗口宽度决定。600 到 839 保持上一次的值。
QtObject {
    property bool compact: false
    // 触摸屏由启动时的设备枚举写入；窄屏没有检测到触摸屏时仍按手指处理。
    property bool touchScreen: false
    readonly property bool coarsePointer: touchScreen || compact

    function noteWidth(width) {
        if (width <= 0) return
        if (width < 600) compact = true
        else if (width >= 840) compact = false
    }
}
