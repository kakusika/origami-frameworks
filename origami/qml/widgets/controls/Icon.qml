import QtQuick
import QtQuick.Controls.impl as CI

CI.IconImage {
    id: root
    property alias source: root.name

    width: 16
    height: 16
    sourceSize.width: width
    sourceSize.height: height
}
