import QtQuick
import QtQuick.Controls
import qs.Commons
Switch {
    id:root
    implicitHeight:34;implicitWidth:contentItem.implicitWidth+54
    indicator:Rectangle {x:0;y:(root.height-height)/2;width:36;height:20;radius:10;color:root.checked?Color.accent:Util.alpha(Color.foreground,.2);border.color:root.activeFocus?Color.foreground:"transparent"
        Rectangle {x:root.checked?18:3;y:3;width:14;height:14;radius:7;color:root.checked?Color.background:Color.foreground;Behavior on x {NumberAnimation{duration:100}}}
    }
    contentItem:Text {leftPadding:root.indicator.width+10;text:root.text;color:Color.foreground;font.pixelSize:12;verticalAlignment:Text.AlignVCenter;wrapMode:Text.Wrap}
    Accessible.name:text
}
