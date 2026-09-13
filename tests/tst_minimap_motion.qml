import QtQuick
import QtTest
import ".."

TestCase {
    name: "MinimapMotion"
    when: windowShown
    MinimapMotion { id: motion }
    function target(x,width) {
        return {width:width,height:100,tiles:{a:{x:x,y:0,w:20,h:30}}}
    }
    function test_intermediate_frames_and_retarget() {
        motion.workspace="test:1"
        motion.targetFrame=target(0,100)
        wait(30)
        compare(motion.frame.tiles.a.x,0)
        motion.targetFrame=target(100,200)
        wait(80)
        verify(motion.frame.tiles.a.x>0 && motion.frame.tiles.a.x<100,"tile must have an intermediate position")
        verify(motion.frame.width>100 && motion.frame.width<200,"bounds must animate with tiles")
        var before=motion.frame.tiles.a.x
        motion.targetFrame=target(200,300)
        wait(1)
        verify(motion.frame.tiles.a.x<200,"retarget must not snap")
        verify(motion.frame.tiles.a.x>=before,"retarget must preserve current frame")
        wait(380)
        compare(motion.frame.tiles.a.x,200)
        compare(motion.frame.width,300)
    }
}
