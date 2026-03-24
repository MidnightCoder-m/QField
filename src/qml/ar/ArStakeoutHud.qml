import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import org.qfield
import Theme

Item {
  id: root

  property double distance: 0.0
  property int distanceUnits: 0
  property double bearing: 0.0
  property double verticalDistance: 0.0
  property string destinationName: ""
  property double proximityLevel: 0.0

  height: hudColumn.implicitHeight + 24

  Rectangle {
    anchors.fill: parent
    color: "#cc111111"
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.08)

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: 2

      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 0.3; color: Qt.rgba(1 - root.proximityLevel, root.proximityLevel, 0.3, 0.6) }
        GradientStop { position: 0.7; color: Qt.rgba(1 - root.proximityLevel, root.proximityLevel, 0.3, 0.6) }
        GradientStop { position: 1.0; color: "transparent" }
      }
    }
  }

  ColumnLayout {
    id: hudColumn
    anchors.fill: parent
    anchors.margins: 10
    spacing: 6

    Text {
      Layout.fillWidth: true
      text: "◉  " + (root.destinationName || qsTr("Navigation target")) + "  ◉"
      font: Theme.strongFont
      color: "#ffffff"
      elide: Text.ElideRight
      horizontalAlignment: Text.AlignHCenter
      opacity: 0.9
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 0

      Item { Layout.fillWidth: true }

      Rectangle {
        Layout.preferredWidth: distCol.implicitWidth + 24
        Layout.preferredHeight: distCol.implicitHeight + 12
        radius: 6
        color: root.proximityLevel > 0.8 ? Qt.rgba(0.1, 0.5, 0.1, 0.4) : Qt.rgba(1, 1, 1, 0.06)
        border.width: root.proximityLevel > 0.8 ? 1 : 0
        border.color: "#4caf50"

        ColumnLayout {
          id: distCol
          anchors.centerIn: parent
          spacing: 1

          Text {
            text: qsTr("Distance")
            font: Theme.tipFont
            color: "#888888"
            Layout.alignment: Qt.AlignHCenter
          }
          Text {
            text: UnitTypes.formatDistance(root.distance, 2, root.distanceUnits)
            font: Theme.strongTipFont
            color: root.proximityLevel > 0.8 ? "#4caf50" : "#ffffff"
            Layout.alignment: Qt.AlignHCenter
          }
        }
      }

      Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: 30
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        color: Qt.rgba(1, 1, 1, 0.1)
      }

      Rectangle {
        Layout.preferredWidth: bearCol.implicitWidth + 24
        Layout.preferredHeight: bearCol.implicitHeight + 12
        radius: 6
        color: Qt.rgba(1, 1, 1, 0.06)

        ColumnLayout {
          id: bearCol
          anchors.centerIn: parent
          spacing: 1

          Text {
            text: qsTr("Bearing")
            font: Theme.tipFont
            color: "#888888"
            Layout.alignment: Qt.AlignHCenter
          }
          Text {
            text: !isNaN(root.bearing) ? Math.round(root.bearing) + "°" : "—"
            font: Theme.strongTipFont
            color: "#ffffff"
            Layout.alignment: Qt.AlignHCenter
          }
        }
      }

      Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: 30
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        color: Qt.rgba(1, 1, 1, 0.1)
        visible: !isNaN(root.verticalDistance)
      }

      Rectangle {
        Layout.preferredWidth: vdistCol.implicitWidth + 24
        Layout.preferredHeight: vdistCol.implicitHeight + 12
        radius: 6
        color: Qt.rgba(1, 1, 1, 0.06)
        visible: !isNaN(root.verticalDistance)

        ColumnLayout {
          id: vdistCol
          anchors.centerIn: parent
          spacing: 1

          Text {
            text: qsTr("V.Dist")
            font: Theme.tipFont
            color: "#888888"
            Layout.alignment: Qt.AlignHCenter
          }
          Text {
            text: !isNaN(root.verticalDistance) ? UnitTypes.formatDistance(Math.abs(root.verticalDistance), 2, root.distanceUnits) + (root.verticalDistance > 0 ? " ↑" : " ↓") : "—"
            font: Theme.strongTipFont
            color: root.verticalDistance > 0 ? "#ff9800" : "#2196f3"
            Layout.alignment: Qt.AlignHCenter
          }
        }
      }

      Item { Layout.fillWidth: true }
    }
  }
}
