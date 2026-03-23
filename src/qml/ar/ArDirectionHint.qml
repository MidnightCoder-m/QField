import QtQuick
import QtQuick.Shapes
import org.qfield
import Theme

Item {
  id: root

  property double relativeBearing: 0.0

  readonly property bool pointsLeft: relativeBearing < 0
  readonly property double arrowOpacity: Math.min(1.0, Math.abs(relativeBearing) / 90.0)

  Shape {
    id: leftArrow
    visible: pointsLeft
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.leftMargin: 16
    width: 40
    height: 60
    opacity: arrowOpacity

    ShapePath {
      strokeWidth: 3
      strokeColor: Theme.navigationColor
      fillColor: Qt.rgba(Theme.navigationColor.r, Theme.navigationColor.g, Theme.navigationColor.b, 0.3)
      startX: 40
      startY: 0

      PathLine { x: 0; y: 30 }
      PathLine { x: 40; y: 60 }
      PathLine { x: 40; y: 0 }
    }

    SequentialAnimation on anchors.leftMargin {
      loops: Animation.Infinite
      running: leftArrow.visible

      NumberAnimation {
        from: 16
        to: 8
        duration: 600
        easing.type: Easing.InOutQuad
      }
      NumberAnimation {
        from: 8
        to: 16
        duration: 600
        easing.type: Easing.InOutQuad
      }
    }
  }

  Shape {
    id: rightArrow
    visible: !pointsLeft
    anchors.verticalCenter: parent.verticalCenter
    anchors.right: parent.right
    anchors.rightMargin: 16
    width: 40
    height: 60
    opacity: arrowOpacity

    ShapePath {
      strokeWidth: 3
      strokeColor: Theme.navigationColor
      fillColor: Qt.rgba(Theme.navigationColor.r, Theme.navigationColor.g, Theme.navigationColor.b, 0.3)
      startX: 0
      startY: 0

      PathLine { x: 40; y: 30 }
      PathLine { x: 0; y: 60 }
      PathLine { x: 0; y: 0 }
    }

    SequentialAnimation on anchors.rightMargin {
      loops: Animation.Infinite
      running: rightArrow.visible

      NumberAnimation {
        from: 16
        to: 8
        duration: 600
        easing.type: Easing.InOutQuad
      }
      NumberAnimation {
        from: 8
        to: 16
        duration: 600
        easing.type: Easing.InOutQuad
      }
    }
  }

  Rectangle {
    anchors.horizontalCenter: pointsLeft ? leftArrow.horizontalCenter : rightArrow.horizontalCenter
    anchors.top: pointsLeft ? leftArrow.bottom : rightArrow.bottom
    anchors.topMargin: 8
    width: bearingText.contentWidth + 12
    height: bearingText.contentHeight + 6
    radius: 4
    color: "#cc000000"
    visible: Math.abs(relativeBearing) > 15

    Text {
      id: bearingText
      anchors.centerIn: parent
      text: Math.round(Math.abs(relativeBearing)) + "°"
      font: Theme.tipFont
      color: Theme.navigationColor
    }
  }
}
