import QtQuick

QtObject {
    id: motion
    property var targetFrame: ({x:0,y:0,w:1,h:1,scale:1,visible:false})
    property var frame: targetFrame
    property var origin: frame
    property var destination: frame
    property int duration: 300
    property real progress: 1
    property bool initialized: false
    property NumberAnimation animation: NumberAnimation {
        target: motion; property: "progress"; from: 0; to: 1
        duration: motion.duration; easing.type: Easing.OutCubic
    }
    function render() {
        var result = {visible:destination.visible}
        var keys = ["x","y","w","h","scale"]
        keys.forEach(function(key) {
            result[key] = origin[key]+(destination[key]-origin[key])*progress
        })
        frame = result
    }
    function update() {
        animation.stop()
        origin = frame; destination = targetFrame
        var snap = !initialized || duration <= 0
        initialized = true; progress = snap ? 1 : 0
        render()
        if (!snap) animation.start()
    }
    onTargetFrameChanged: Qt.callLater(update)
    onProgressChanged: render()
    onDurationChanged: if (duration <= 0) { animation.stop(); progress=1; render() }
}
