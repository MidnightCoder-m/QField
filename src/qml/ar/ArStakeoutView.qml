import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import QtMultimedia
import org.qfield
import Theme

Item {
  id: arStakeout
  focus: true

  property Navigation navigation
  property Positioning positionSource

  signal closed

  ArStakeoutController {
    id: controller
    bearing: navigation.bearing
    deviceOrientation: !isNaN(positionSource.orientation) ? positionSource.orientation : 0
    distance: navigation.distance
    proximityThreshold: navigation.proximityAlarmThreshold > 0 ? navigation.proximityAlarmThreshold : 5.0
    cameraHorizontalFov: 60
    cameraVerticalFov: 45
  }

  QfCameraPermission {
    id: cameraPermission
  }

  Component.onCompleted: {
    if (cameraPermission.status === Qt.PermissionStatus.Undetermined) {
      cameraPermission.request();
    }
  }

  Rectangle {
    anchors.fill: parent
    color: "#000000"
  }

  Loader {
    id: cameraLoader
    anchors.fill: parent
    active: arStakeout.visible && cameraPermission.status === Qt.PermissionStatus.Granted
    asynchronous: true

    sourceComponent: Component {
      Item {
        anchors.fill: parent
        property alias camera: arCamera

        VideoOutput {
          id: arVideoOutput
          anchors.fill: parent
        }

        CaptureSession {
          camera: Camera {
            id: arCamera
            active: arStakeout.visible && cameraPermission.status === Qt.PermissionStatus.Granted
          }
          videoOutput: arVideoOutput
        }
      }
    }

    onLoaded: {
      item.camera.cameraDevice = MediaDevices.defaultVideoInput;
    }
  }

  ArDirectionHint {
    id: directionHint
    anchors.fill: parent
    relativeBearing: controller.relativeBearing
    visible: !controller.isOnScreen && !isNaN(controller.relativeBearing)
  }

  ArStakeoutMarker {
    id: marker
    x: controller.markerPosition.x * parent.width - width / 2
    y: controller.markerPosition.y * parent.height - height / 2
    visible: controller.isOnScreen
    proximityLevel: controller.proximityLevel
    distance: navigation.distance
    distanceUnits: navigation.distanceUnits
  }

  ArStakeoutHud {
    id: hud
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: mainWindow.sceneTopMargin

    distance: navigation.distance
    distanceUnits: navigation.distanceUnits
    bearing: navigation.bearing
    verticalDistance: navigation.verticalDistance
    destinationName: navigation.destinationName
    proximityLevel: controller.proximityLevel
  }

  QfToolButton {
    id: closeButton
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    anchors.margins: 20

    round: true
    iconSource: Theme.getThemeVectorIcon("ic_close_white_24dp")
    iconColor: "#ffffff"
    bgcolor: "#88000000"

    onClicked: arStakeout.closed()
  }
}
