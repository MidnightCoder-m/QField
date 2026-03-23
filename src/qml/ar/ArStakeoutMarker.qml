import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import org.qfield
import Theme

Item {
  id: root

  property double proximityLevel: 0.0
  property double distance: 0.0
  property int distanceUnits: 0

  width: markerSize
  height: markerSize + distanceLabel.height + 8

  readonly property double markerSize: 32 + 32 * proximityLevel
  readonly property color markerColor: Qt.rgba(
    1.0 - proximityLevel,
    proximityLevel,
    0.2,
    0.9
  )

  Rectangle {
    id: pulseRing
    anchors.horizontalCenter: parent.horizontalCenter
    y: 0
    width: markerSize * 1.6
    height: width
    radius: width / 2
    color: "transparent"
    border.width: 2
    border.color: Qt.rgba(markerColor.r, markerColor.g, markerColor.b, 0.4)

    SequentialAnimation on scale {
      loops: Animation.Infinite
      running: root.visible

      NumberAnimation {
        from: 0.8
        to: 1.3
        duration: 1200
        easing.type: Easing.InOutQuad
      }
      NumberAnimation {
        from: 1.3
        to: 0.8
        duration: 1200
        easing.type: Easing.InOutQuad
      }
    }
  }

  Rectangle {
    id: innerMarker
    anchors.horizontalCenter: parent.horizontalCenter
    y: (markerSize * 1.6 - markerSize) / 2
    width: markerSize
    height: width
    radius: width / 2
    color: markerColor
    border.width: 2
    border.color: "#ffffff"

    Rectangle {
      anchors.centerIn: parent
      width: parent.width * 0.5
      height: 2
      color: "#ffffff"
      opacity: 0.8
    }
    Rectangle {
      anchors.centerIn: parent
      width: 2
      height: parent.height * 0.5
      color: "#ffffff"
      opacity: 0.8
    }
  }

  Rectangle {
    id: distanceBg
    anchors.horizontalCenter: parent.horizontalCenter
    y: markerSize * 1.6 + 4
    width: distanceLabel.contentWidth + 16
    height: distanceLabel.contentHeight + 8
    radius: height / 2
    color: "#cc000000"

    Text {
      id: distanceLabel
      anchors.centerIn: parent
      text: UnitTypes.formatDistance(root.distance, 2, root.distanceUnits)
      font: Theme.tipFont
      color: markerColor
    }
  }
}
