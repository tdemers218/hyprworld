import QtQuick
import QtQuick.Controls
import qs.Commons
Slider {
    id:root
    implicitHeight:30;opacity:enabled?1:.4
    background:Rectangle {x:root.leftPadding;y:(root.height-height)/2;width:root.availableWidth;height:4;radius:2;color:Util.alpha(Color.foreground,.12)
        Rectangle {width:root.visualPosition*parent.width;height:parent.height;radius:2;color:Color.accent}
    }
    handle:Rectangle {x:root.leftPadding+root.visualPosition*(root.availableWidth-width);y:(root.height-height)/2;width:14;height:14;radius:7;color:Color.accent;border.width:root.activeFocus?2:0;border.color:Color.foreground}
}
