import QtQuick
import qs.Commons
import "Settings.js" as Settings

// Editable animation curve: drag the two bezier control points, or pick a
// named curve. Elastic and bounce have no control points and are drawn only.
Row {
    id: root
    property string value: "out-cubic"
    // The slider edits a duration in ms, or a speed multiplier for the
    // general curve; `duration` is also how long the preview dot takes.
    property int duration: 300
    property real sliderValue: duration
    property real sliderFrom: 0
    property real sliderTo: 1500
    property real sliderStep: 10
    property string sliderText: duration + " ms"
    property var options: Settings.curveNames()
    signal curveEdited(string value)
    signal sliderEdited(real value)
    spacing: 16

    readonly property var points: Settings.curvePoints(value)
    readonly property bool editable: !!points && value !== "elastic" && value !== "bounce"
    readonly property string label: Settings.customPoints(value) ? "custom" : value.replace(/-/g, " ")

    Item {
        id: graph
        width: 180; height: 140
        // The unit square plus headroom for overshooting curves.
        readonly property real pad: 12
        readonly property real yMin: -0.4
        readonly property real yMax: 1.4
        function px(x) { return pad + x * (width - 2*pad) }
        function py(y) { return pad + (1 - (y - yMin) / (yMax - yMin)) * (height - 2*pad) }
        function fromPx(x, y) {
            return {x: Math.max(0, Math.min(1, (x - pad) / (width - 2*pad))),
                y: Math.max(yMin, Math.min(yMax, yMin + (1 - (y - pad) / (height - 2*pad)) * (yMax - yMin)))}
        }
        Rectangle {
            anchors.fill: parent; radius: 8
            color: Util.alpha(Color.foreground, .04); border.color: Util.alpha(Color.foreground, .15)
        }
        Canvas {
            id: plot
            anchors.fill: parent
            property string curve: root.value
            onCurveChanged: requestPaint()
            onWidthChanged: requestPaint()
            function rgba(c, a) { return "rgba(" + Math.round(c.r*255) + "," + Math.round(c.g*255) + "," + Math.round(c.b*255) + "," + a + ")" }
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.lineWidth = 1
                ctx.strokeStyle = rgba(Color.foreground, .18)
                ctx.strokeRect(graph.px(0), graph.py(1), graph.px(1) - graph.px(0), graph.py(0) - graph.py(1))
                ctx.setLineDash([3, 4])
                ctx.beginPath(); ctx.moveTo(graph.px(0), graph.py(0)); ctx.lineTo(graph.px(1), graph.py(1)); ctx.stroke()
                ctx.setLineDash([])
                if (root.editable) {
                    ctx.strokeStyle = rgba(Color.foreground, .45)
                    ctx.beginPath(); ctx.moveTo(graph.px(0), graph.py(0)); ctx.lineTo(graph.px(root.points[0]), graph.py(root.points[1])); ctx.stroke()
                    ctx.beginPath(); ctx.moveTo(graph.px(1), graph.py(1)); ctx.lineTo(graph.px(root.points[2]), graph.py(root.points[3])); ctx.stroke()
                }
                ctx.lineWidth = 2.5
                ctx.strokeStyle = rgba(Color.accent, 1)
                ctx.beginPath()
                for (var i = 0; i <= 80; i++) {
                    var t = i / 80, y = Settings.curveAt(root.value, t)
                    if (i === 0) ctx.moveTo(graph.px(t), graph.py(y)); else ctx.lineTo(graph.px(t), graph.py(y))
                }
                ctx.stroke()
            }
        }
        Repeater {
            model: root.editable ? [0, 1] : []
            delegate: Rectangle {
                id: handle
                required property int modelData
                readonly property real pointX: root.points[modelData*2]
                readonly property real pointY: root.points[modelData*2 + 1]
                width: 14; height: 14; radius: 7
                x: graph.px(pointX) - width/2; y: graph.py(pointY) - height/2
                color: drag.pressed || drag.containsMouse ? Color.accent : Color.background
                border.width: 2; border.color: Color.accent
                MouseArea {
                    id: drag
                    anchors.fill: parent; anchors.margins: -6
                    hoverEnabled: true; cursorShape: Qt.SizeAllCursor
                    preventStealing: true
                    onPositionChanged: function(mouse) {
                        if (!pressed) return
                        var local = mapToItem(graph, mouse.x, mouse.y), p = graph.fromPx(local.x, local.y)
                        var next = root.points.slice()
                        next[handle.modelData*2] = p.x; next[handle.modelData*2 + 1] = p.y
                        root.curveEdited(Settings.curveValue(next))
                    }
                    onReleased: preview.play()
                }
                Accessible.name: "Curve control point " + (modelData + 1)
            }
        }
    }
    Column {
        width: parent.width - graph.width - root.spacing
        spacing: 10
        Row {
            spacing: 10
            Text { text: root.label; color: Color.foreground; font.pixelSize: 13; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            SettingsButton { text: "▶"; onClicked: preview.play(); Accessible.name: "Preview curve" }
        }
        Item {
            id: preview
            width: parent.width; height: 14
            function play() { dot.x = 0; motion.restart() }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 2; radius: 1; color: Util.alpha(Color.foreground, .15) }
            Rectangle {
                id: dot
                width: 14; height: 14; radius: 7; color: Color.accent
                NumberAnimation {
                    id: motion
                    target: dot; property: "x"; from: 0; to: preview.width - dot.width
                    duration: Math.max(1, root.duration)
                    easing.type: root.value === "elastic" ? Easing.OutElastic : root.value === "bounce" ? Easing.OutBounce : Easing.BezierSpline
                    easing.bezierCurve: Settings.bezier(root.value)
                }
            }
        }
        Row {
            width: parent.width; spacing: 10
            SettingsSlider {
                width: parent.width - 90; height: 28
                from: root.sliderFrom; to: root.sliderTo; stepSize: root.sliderStep
                value: root.sliderValue
                onMoved: root.sliderEdited(Number(value.toFixed(2)))
                Accessible.name: "Duration"
            }
            Text { text: root.sliderText; color: Color.foreground; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
        }
        Flow {
            width: parent.width; spacing: 4
            Repeater {
                model: root.options
                SettingsButton {
                    required property string modelData
                    text: modelData.replace(/-/g, " ")
                    checked: root.value === modelData; checkable: true
                    implicitHeight: 26
                    onClicked: { root.curveEdited(modelData); preview.play() }
                }
            }
        }
    }
}
