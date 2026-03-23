import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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

  height: hudColumn.implicitHeight + 20

  Rectangle {
    anchors.fill: parent
    color: "#aa000000"
  }

  ColumnLayout {
    id: hudColumn
    anchors.fill: parent
    anchors.margins: 10
    spacing: 4

    Text {
      Layout.fillWidth: true
      text: root.destinationName || qsTr("Navigation target")
      font: Theme.strongFont
      color: "#ffffff"
      elide: Text.ElideRight
      horizontalAlignment: Text.AlignHCenter
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 20

      Item { Layout.fillWidth: true }

      ColumnLayout {
        spacing: 2

        Text {
          text: qsTr("Distance")
          font: Theme.tipFont
          color: "#aaaaaa"
          Layout.alignment: Qt.AlignHCenter
        }
        Text {
          text: UnitTypes.formatDistance(root.distance, 2, root.distanceUnits)
          font: Theme.strongTipFont
          color: root.proximityLevel > 0.8 ? "#4caf50" : "#ffffff"
          Layout.alignment: Qt.AlignHCenter
        }
      }

      ColumnLayout {
        spacing: 2

        Text {
          text: qsTr("Bearing")
          font: Theme.tipFont
          color: "#aaaaaa"
          Layout.alignment: Qt.AlignHCenter
        }
        Text {
          text: !isNaN(root.bearing) ? Math.round(root.bearing) + "°" : "—"
          font: Theme.strongTipFont
          color: "#ffffff"
          Layout.alignment: Qt.AlignHCenter
        }
      }

      ColumnLayout {
        spacing: 2
        visible: !isNaN(root.verticalDistance)

        Text {
          text: qsTr("V.Dist")
          font: Theme.tipFont
          color: "#aaaaaa"
          Layout.alignment: Qt.AlignHCenter
        }
        Text {
          text: !isNaN(root.verticalDistance) ? UnitTypes.formatDistance(Math.abs(root.verticalDistance), 2, root.distanceUnits) + (root.verticalDistance > 0 ? " ↑" : " ↓") : "—"
          font: Theme.strongTipFont
          color: "#ffffff"
          Layout.alignment: Qt.AlignHCenter
        }
      }

      Item { Layout.fillWidth: true }
    }
  }
}
