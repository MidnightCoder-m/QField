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

  readonly property double markerSize: 40 + 24 * proximityLevel
  readonly property color markerColor: Qt.rgba(1.0 - proximityLevel, proximityLevel, 0.2, 0.9)

  width: outerScanRing.width
  height: outerScanRing.height + distanceBg.height + 12

  Rectangle {
    id: outerScanRing
    anchors.horizontalCenter: parent.horizontalCenter
    y: 0
    width: markerSize * 2.4
    height: width
    radius: width / 2
    color: "transparent"
    border.width: 1
    border.color: Qt.rgba(markerColor.r, markerColor.g, markerColor.b, 0.15)
  }

  Shape {
    id: radarSweep
    anchors.centerIn: outerScanRing
    width: outerScanRing.width
    height: outerScanRing.height

    ShapePath {
      strokeWidth: 2
      strokeColor: Qt.rgba(markerColor.r, markerColor.g, markerColor.b, 0.6)
      fillColor: "transparent"

      PathAngleArc {
        centerX: outerScanRing.width / 2
        centerY: outerScanRing.height / 2
        radiusX: outerScanRing.width / 2 - 2
        radiusY: outerScanRing.height / 2 - 2
        startAngle: radarSweep.sweepAngle
        sweepAngle: 60
      }
    }

    property double sweepAngle: 0
    NumberAnimation on sweepAngle {
      from: 0; to: 360
      duration: 2000
      loops: Animation.Infinite
      running: root.visible
    }
  }

  Repeater {
    model: 3

    Rectangle {
      anchors.centerIn: outerScanRing
      width: markerSize * (0.8 + index * 0.5)
      height: width
      radius: width / 2
      color: "transparent"
      border.width: 0.5
      border.color: Qt.rgba(markerColor.r, markerColor.g, markerColor.b, 0.12 - index * 0.03)
    }
  }

  Rectangle {
    id: pulseRing
    anchors.centerIn: outerScanRing
    width: markerSize * 1.6
    height: width
    radius: width / 2
    color: "transparent"
    border.width: 2
    border.color: Qt.rgba(markerColor.r, markerColor.g, markerColor.b, 0.5 * (1.0 - pulseRing.pulseScale))

    property double pulseScale: 0.8

    SequentialAnimation on pulseScale {
      loops: Animation.Infinite
      running: root.visible

      NumberAnimation { from: 0.8; to: 1.5; duration: 1200; easing.type: Easing.OutQuad }
      NumberAnimation { from: 1.5; to: 0.8; duration: 1200; easing.type: Easing.InQuad }
    }

    scale: pulseScale
  }

  Rectangle {
    id: pulseRing2
    anchors.centerIn: outerScanRing
    width: markerSize * 1.6
    height: width
    radius: width / 2
    color: "transparent"
    border.width: 1.5
    border.color: Qt.rgba(markerColor.r, markerColor.g, markerColor.b, 0.3 * (1.0 - pulseRing2.pulseScale2))

    property double pulseScale2: 1.0

    SequentialAnimation on pulseScale2 {
      loops: Animation.Infinite
      running: root.visible

      PauseAnimation { duration: 400 }
      NumberAnimation { from: 0.8; to: 1.5; duration: 1200; easing.type: Easing.OutQuad }
      NumberAnimation { from: 1.5; to: 0.8; duration: 1200; easing.type: Easing.InQuad }
    }

    scale: pulseScale2
  }

  Rectangle {
    id: innerMarker
    anchors.centerIn: outerScanRing
    width: markerSize
    height: width
    radius: width / 2
    border.width: 2
    border.color: "#ffffff"

    gradient: Gradient {
      GradientStop { position: 0.0; color: Qt.rgba(markerColor.r, markerColor.g, markerColor.b, 0.95) }
      GradientStop { position: 0.5; color: Qt.lighter(markerColor, 1.2) }
      GradientStop { position: 1.0; color: markerColor }
    }

    Rectangle {
      anchors.centerIn: parent
      width: parent.width * 0.55
      height: 1.5
      color: "#ffffff"
      opacity: 0.9
    }
    Rectangle {
      anchors.centerIn: parent
      width: 1.5
      height: parent.height * 0.55
      color: "#ffffff"
      opacity: 0.9
    }
    Rectangle {
      anchors.centerIn: parent
      width: 6
      height: 6
      radius: 3
      color: "#ffffff"
    }
  }

  Rectangle {
    visible: proximityLevel > 0.8
    anchors.centerIn: outerScanRing
    width: markerSize + 12
    height: width
    radius: width / 2
    color: "transparent"
    border.width: 2
    border.color: "#4caf50"

    SequentialAnimation on opacity {
      loops: Animation.Infinite
      running: proximityLevel > 0.8

      NumberAnimation { from: 1.0; to: 0.3; duration: 400 }
      NumberAnimation { from: 0.3; to: 1.0; duration: 400 }
    }
  }

  Rectangle {
    id: distanceBg
    anchors.horizontalCenter: parent.horizontalCenter
    y: outerScanRing.height + 8
    width: distanceRow.width + 20
    height: distanceRow.height + 10
    radius: height / 2
    color: "#cc000000"
    border.width: 1
    border.color: Qt.rgba(markerColor.r, markerColor.g, markerColor.b, 0.3)

    Row {
      id: distanceRow
      anchors.centerIn: parent
      spacing: 6

      Text {
        text: "⎯"
        font.pixelSize: 10
        color: markerColor
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        id: distanceLabel
        text: UnitTypes.formatDistance(root.distance, 2, root.distanceUnits)
        font: Theme.strongTipFont
        color: markerColor
      }
      Text {
        text: "⎯"
        font.pixelSize: 10
        color: markerColor
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }
}
