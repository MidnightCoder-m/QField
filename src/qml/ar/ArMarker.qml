import QtQuick
import org.qfield
import Theme

/**
 * A single augmented reality marker: a label with the feature name and its
 * live distance.
 * \ingroup qml
 */
Item {
  id: marker

  required property string displayName
  required property real distanceMeters
  required property string distanceText
  required property point screenPosition
  required property bool withinView

  readonly property real stemHeight: 14
  readonly property real anchorDotSize: 10
  readonly property real maximumLabelWidth: 160

  width: labelBackground.width
  height: labelBackground.height + stemHeight + anchorDotSize
  x: screenPosition.x - width / 2
  y: screenPosition.y - height + anchorDotSize / 2
  z: -distanceMeters
  visible: withinView

  Rectangle {
    id: labelBackground
    anchors.horizontalCenter: parent.horizontalCenter
    width: labelColumn.width + 20
    height: labelColumn.height + 12
    radius: 8
    color: "#bf000000"
    border.color: "#40ffffff"
    border.width: 1

    Column {
      id: labelColumn
      anchors.centerIn: parent

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(implicitWidth, marker.maximumLabelWidth)
        text: marker.displayName
        elide: Text.ElideRight
        color: "white"
        font: Theme.strongTipFont
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: marker.distanceText
        color: Theme.mainColor
        font: Theme.tipFont
      }
    }
  }

  Rectangle {
    id: stem
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: labelBackground.bottom
    width: 2
    height: marker.stemHeight
    color: "#bfffffff"
  }

  Rectangle {
    id: anchorDot
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    width: marker.anchorDotSize
    height: marker.anchorDotSize
    radius: marker.anchorDotSize / 2
    color: Theme.mainColor
    border.color: "white"
    border.width: 1
  }
}
