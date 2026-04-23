import QtQuick
import QtQuick.Shapes
import org.qfield
import Theme

Item {
  id: root

  property double relativeBearing: 0.0

  readonly property bool pointsLeft: relativeBearing < 0
  readonly property double intensity: Math.min(1.0, Math.abs(relativeBearing) / 90.0)
  readonly property color arrowColor: Theme.navigationColor

  Shape {
    id: leftArrow
    visible: pointsLeft
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.leftMargin: leftArrow.animatedMargin
    width: 40 + intensity * 15
    height: 60 + intensity * 20
    opacity: 0.6 + intensity * 0.4

    property double animatedMargin: 16

    ShapePath {
      strokeWidth: 2
      strokeColor: arrowColor
      fillColor: Qt.rgba(arrowColor.r, arrowColor.g, arrowColor.b, 0.25)
      startX: leftArrow.width; startY: 0
      PathLine { x: 0; y: leftArrow.height / 2 }
      PathLine { x: leftArrow.width; y: leftArrow.height }
      PathLine { x: leftArrow.width; y: 0 }
    }

    SequentialAnimation on animatedMargin {
      loops: Animation.Infinite
      running: leftArrow.visible
      NumberAnimation { from: 16; to: 6; duration: 500; easing.type: Easing.OutQuad }
      NumberAnimation { from: 6; to: 16; duration: 500; easing.type: Easing.InQuad }
    }
  }

  Shape {
    visible: pointsLeft
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.leftMargin: leftArrow.animatedMargin + leftArrow.width * 0.4
    width: leftArrow.width * 0.7
    height: leftArrow.height * 0.7
    opacity: leftArrow.opacity * 0.4

    ShapePath {
      strokeWidth: 1.5
      strokeColor: arrowColor
      fillColor: Qt.rgba(arrowColor.r, arrowColor.g, arrowColor.b, 0.1)
      startX: parent.width; startY: 0
      PathLine { x: 0; y: parent.height / 2 }
      PathLine { x: parent.width; y: parent.height }
      PathLine { x: parent.width; y: 0 }
    }
  }

  Rectangle {
    visible: pointsLeft
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: 60
    opacity: intensity * 0.3

    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: arrowColor }
      GradientStop { position: 1.0; color: "transparent" }
    }
  }

  Shape {
    id: rightArrow
    visible: !pointsLeft
    anchors.verticalCenter: parent.verticalCenter
    anchors.right: parent.right
    anchors.rightMargin: rightArrow.animatedMargin
    width: 40 + intensity * 15
    height: 60 + intensity * 20
    opacity: 0.6 + intensity * 0.4

    property double animatedMargin: 16

    ShapePath {
      strokeWidth: 2
      strokeColor: arrowColor
      fillColor: Qt.rgba(arrowColor.r, arrowColor.g, arrowColor.b, 0.25)
      startX: 0; startY: 0
      PathLine { x: rightArrow.width; y: rightArrow.height / 2 }
      PathLine { x: 0; y: rightArrow.height }
      PathLine { x: 0; y: 0 }
    }

    SequentialAnimation on animatedMargin {
      loops: Animation.Infinite
      running: rightArrow.visible
      NumberAnimation { from: 16; to: 6; duration: 500; easing.type: Easing.OutQuad }
      NumberAnimation { from: 6; to: 16; duration: 500; easing.type: Easing.InQuad }
    }
  }

  Shape {
    visible: !pointsLeft
    anchors.verticalCenter: parent.verticalCenter
    anchors.right: parent.right
    anchors.rightMargin: rightArrow.animatedMargin + rightArrow.width * 0.4
    width: rightArrow.width * 0.7
    height: rightArrow.height * 0.7
    opacity: rightArrow.opacity * 0.4

    ShapePath {
      strokeWidth: 1.5
      strokeColor: arrowColor
      fillColor: Qt.rgba(arrowColor.r, arrowColor.g, arrowColor.b, 0.1)
      startX: 0; startY: 0
      PathLine { x: parent.width; y: parent.height / 2 }
      PathLine { x: 0; y: parent.height }
      PathLine { x: 0; y: 0 }
    }
  }

  Rectangle {
    visible: !pointsLeft
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: 60
    opacity: intensity * 0.3

    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: "transparent" }
      GradientStop { position: 1.0; color: arrowColor }
    }
  }

  Rectangle {
    anchors.horizontalCenter: pointsLeft ? leftArrow.horizontalCenter : rightArrow.horizontalCenter
    anchors.top: pointsLeft ? leftArrow.bottom : rightArrow.bottom
    anchors.topMargin: 8
    width: bearingRow.width + 16
    height: bearingRow.height + 8
    radius: height / 2
    color: "#cc000000"
    border.width: 1
    border.color: Qt.rgba(arrowColor.r, arrowColor.g, arrowColor.b, 0.3)
    visible: Math.abs(relativeBearing) > 15

    Row {
      id: bearingRow
      anchors.centerIn: parent
      spacing: 4

      Text {
        text: pointsLeft ? "◀" : ""
        font.pixelSize: 10
        color: arrowColor
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: Math.round(Math.abs(relativeBearing)) + "°"
        font: Theme.strongTipFont
        color: arrowColor
      }
      Text {
        text: pointsLeft ? "" : "▶"
        font.pixelSize: 10
        color: arrowColor
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }
}
