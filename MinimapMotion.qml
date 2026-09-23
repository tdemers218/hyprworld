import QtQuick

QtObject {
    id: motion
    property var targetFrame: ({width:1,height:1,tiles:{}})
    property string workspace: ""
    property string previousWorkspace: ""
    property var frame: ({width:1,height:1,tiles:{}})
    property var fromFrame: frame
    property var destination: frame
    property string signature: ""
    property real progress: 1
    property int duration: 300
    property NumberAnimation animation: NumberAnimation {
        target: motion; property: "progress"; from: 0; to: 1
        duration: motion.duration; easing.type: Easing.OutCubic
    }
    function blend(a,b,p) { return a+(b-a)*p }
    function render() {
        var tiles={}
        Object.keys(destination.tiles).forEach(function(address) {
            var b=destination.tiles[address], a=fromFrame.tiles[address] || b
            tiles[address]={x:blend(a.x,b.x,progress),y:blend(a.y,b.y,progress),
                w:blend(a.w,b.w,progress),h:blend(a.h,b.h,progress)}
        })
        frame={width:blend(fromFrame.width,destination.width,progress),
            height:blend(fromFrame.height,destination.height,progress),tiles:tiles}
    }
    function update() {
        var nextSignature=JSON.stringify(targetFrame)
        if (signature===nextSignature && previousWorkspace===workspace) return
        animation.stop()
        fromFrame=frame
        destination=targetFrame
        var snap=duration<=0 || !signature || previousWorkspace!==workspace
        signature=nextSignature; previousWorkspace=workspace
        progress=snap ? 1 : 0
        render()
        if (!snap) animation.start()
    }
    onProgressChanged: render()
    onDurationChanged: if (duration<=0) { animation.stop(); progress=1; render() }
    onTargetFrameChanged: Qt.callLater(update)
    onWorkspaceChanged: Qt.callLater(update)
}
