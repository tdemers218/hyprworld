import QtQuick
import QtQuick.Controls
import qs.Commons

Column {
    id: root
    required property var field
    required property var preferences
    signal edited(string key, var value)
    spacing: 8
    readonly property var current: preferences[field.key]
    Row {
        width: parent.width; spacing: 10
        Text { width: parent.width - (root.field.type === "toggle" ? 54 : 0); text: root.field.title; color: Color.foreground; font.pixelSize: 13; wrapMode: Text.Wrap; anchors.verticalCenter: parent.verticalCenter }
        SettingsSwitch {
            visible: root.field.type === "toggle"; width: 44; height: 28
            checked: root.current === true
            onToggled: root.edited(root.field.key, checked)
            Accessible.name: root.field.title
        }
    }
    Row {
        width: parent.width; spacing: 12; visible: root.field.type === "range"
        SettingsSlider {
            width: parent.width - 106; height: 30
            from: root.field.min || 0; to: root.field.max || 1; stepSize: root.field.step || 1
            value: Number(root.current) || 0
            onMoved: root.edited(root.field.key, Number(value.toFixed(3)))
            Accessible.name: root.field.title
        }
        SettingsTextField {
            width: 94; height: 32; text: String(root.current)
            color: Color.foreground; horizontalAlignment: Text.AlignRight
            validator: DoubleValidator { bottom: root.field.min || 0; top: root.field.max || 1 }
            onEditingFinished: {
                if (acceptableInput) root.edited(root.field.key, Number(text))
                else text=String(root.current)
            }
            ToolTip.visible: hovered; ToolTip.text: root.field.unit || "Value"
            Accessible.name: root.field.title + " " + (root.field.unit || "value")
            background: Rectangle { radius: 6; color: Util.alpha(Color.foreground,.06); border.color: parent.activeFocus ? Color.accent : Util.alpha(Color.foreground,.15) }
        }
    }
    Row {
        visible:root.field.type === "color"; width:parent.width;spacing:12
        Rectangle {width:30;height:30;radius:6;color:root.current || Color.accent;border.color:Color.muted}
        SettingsTextField {width:parent.width-42;height:32;text:root.current || "";placeholderText:"Theme default · or #rrggbb";Accessible.name:root.field.title
            validator:RegularExpressionValidator {regularExpression:/^(#[0-9a-fA-F]{6})?$/}
            onEditingFinished:if(acceptableInput)root.edited(root.field.key,text)
        }
    }
    Flow {
        width: parent.width; spacing: 6; visible: root.field.type === "choice"
        Repeater {
            model: root.field.options || []
            SettingsButton {
                required property string modelData
                text: modelData.replace(/-/g," ")
                checked: root.current === modelData; checkable: true
                onClicked: root.edited(root.field.key,modelData)
                Accessible.name: root.field.title + ": " + text
            }
        }
    }
}
