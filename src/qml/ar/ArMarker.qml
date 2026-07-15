import QtQuick
import QtQuick.Shapes
import org.qfield
import Theme

/**
 * A single augmented reality marker: a callout showing the feature name and
 * its live distance, its tail pointing down at the projected feature location.
 * Positions come exclusively from the marker model's per-frame updates; adding
 * animations or behaviors here would double-smooth and lag. Tapping the callout
 * opens the feature's form, mirroring a feature tap on the map.
 * \ingroup qml
 */
Item {
  id: marker

  required property string displayName
  required property real distanceMeters
  required property string distanceText
  required property point screenPosition
  required property bool withinView
  required property var featureId
  required property string layerId

  signal clicked

  readonly property real tailWidth: 14
  readonly property real tailHeight: 8
  readonly property real maximumLabelWidth: 180

  width: pill.width
  height: pill.height + tailHeight - 1
  // The tail tip rests on the projected feature location
  x: screenPosition.x - width / 2
  y: screenPosition.y - height
  // Nearer markers (smaller distance) sit on top and receive taps first
  z: -distanceMeters
  visible: withinView

  Item {
    id: callout
    anchors.fill: parent

    layer.enabled: true
    layer.effect: QfDropShadow {
      transparentBorder: true
      samples: 16
      color: Theme.darkGraySemiOpaque
      horizontalOffset: 0
      verticalOffset: 0
    }

    Rectangle {
      id: pill
      anchors.top: parent.top
      anchors.horizontalCenter: parent.horizontalCenter
      width: labelColumn.width + 24
      height: labelColumn.height + 14
      radius: 10
      color: Theme.darkGray

      Column {
        id: labelColumn
        anchors.centerIn: parent
        spacing: 1

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          width: Math.min(implicitWidth, marker.maximumLabelWidth)
          text: marker.displayName
          elide: Text.ElideRight
          horizontalAlignment: Text.AlignHCenter
          color: Theme.light
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

    Shape {
      id: tail
      anchors.top: pill.bottom
      anchors.topMargin: -1
      anchors.horizontalCenter: parent.horizontalCenter
      width: marker.tailWidth
      height: marker.tailHeight
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        strokeWidth: 0
        fillColor: Theme.darkGray
        startX: 0
        startY: 0
        PathLine {
          x: marker.tailWidth
          y: 0
        }
        PathLine {
          x: marker.tailWidth / 2
          y: marker.tailHeight
        }
        PathLine {
          x: 0
          y: 0
        }
      }
    }
  }

  TapHandler {
    onTapped: marker.clicked()
  }
}
