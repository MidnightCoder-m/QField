import QtQuick
import QtQuick.Controls
import QtMultimedia
import org.qfield
import Theme

/**
 * A location-based augmented reality view: the live camera feed overlaid with
 * markers for the nearest features of the project's visible vector layers.
 * \ingroup qml
 */
Item {
  id: arView
  objectName: "arView"

  readonly property real portraitHorizontalFieldOfView: 46.0
  readonly property real landscapeHorizontalFieldOfView: 66.0
  readonly property int nearestFeatureCount: 10
  readonly property real featureSearchRadius: 1000.0

  property alias positioningSource: arMarkerModel.positioningSource
  property bool entrancePlayed: false

  signal closeRequested
  signal featureFormRequested(string layerId, var featureId)

  focus: true

  Keys.onReleased: event => {
    if (event.key === Qt.Key_Back || event.key === Qt.Key_Escape) {
      event.accepted = true;
      arView.closeRequested();
    }
  }

  Component.onCompleted: {
    forceActiveFocus();
    playEntranceAnimation();
    if (cameraPermission.status === Qt.PermissionStatus.Undetermined) {
      cameraPermission.request();
    }
  }

  onHeightChanged: playEntranceAnimation()

  function playEntranceAnimation() {
    if (!entrancePlayed && height > 0) {
      entrancePlayed = true;
      entranceTranslation.y = height;
      entranceAnimation.restart();
    }
  }

  transform: Translate {
    id: entranceTranslation
    y: 0
  }

  NumberAnimation {
    id: entranceAnimation
    target: entranceTranslation
    property: "y"
    to: 0
    duration: 250
    easing.type: Easing.OutQuart
  }

  QfCameraPermission {
    id: cameraPermission
  }

  Rectangle {
    id: cameraBackground
    anchors.fill: parent
    color: Theme.darkGray
  }

  MediaDevices {
    id: mediaDevices
  }

  CaptureSession {
    id: captureSession

    camera: Camera {
      id: camera
      active: arView.visible && cameraPermission.status === Qt.PermissionStatus.Granted
      cameraDevice: {
        for (const device of mediaDevices.videoInputs) {
          if (device.position === CameraDevice.BackFace) {
            return device;
          }
        }
        return mediaDevices.defaultVideoInput;
      }
    }

    videoOutput: videoOutput
  }

  VideoOutput {
    id: videoOutput
    anchors.fill: parent
    fillMode: VideoOutput.PreserveAspectCrop
  }

  ArMarkerModel {
    id: arMarkerModel
    active: arView.visible
    project: qgisProject
    viewportSize: Qt.size(markersContainer.width, markersContainer.height)
    horizontalFieldOfView: markersContainer.width < markersContainer.height ? arView.portraitHorizontalFieldOfView : arView.landscapeHorizontalFieldOfView
    maximumMarkerCount: arView.nearestFeatureCount
    maximumMarkerDistance: arView.featureSearchRadius
  }

  FrameAnimation {
    id: frameSynchronizedUpdater
    running: arView.visible && arMarkerModel.active
    onTriggered: arMarkerModel.advanceFrame()
  }

  Item {
    id: markersContainer
    anchors.fill: parent

    Repeater {
      id: markersRepeater
      model: arMarkerModel
      delegate: ArMarker {
        id: markerDelegate
        onClicked: arView.featureFormRequested(markerDelegate.layerId, markerDelegate.featureId)
      }
    }
  }

  Rectangle {
    id: headerBackground
    anchors.top: parent.top
    anchors.topMargin: mainWindow.sceneTopMargin + 8
    anchors.horizontalCenter: parent.horizontalCenter
    width: headerLabel.width + 32
    height: headerLabel.height + 16
    radius: height / 2
    color: Theme.darkGraySemiOpaque

    Text {
      id: headerLabel
      anchors.centerIn: parent
      text: {
        if (!arMarkerModel.attitudeAvailable || !arMarkerModel.positionAvailable) {
          return qsTr("AR view");
        }
        return arMarkerModel.count > 0 ? qsTr("Displaying %1 nearest features").arg(arMarkerModel.count) : qsTr("No features within %1 m").arg(arView.featureSearchRadius);
      }
      color: Theme.light
      font: Theme.strongTipFont
    }
  }

  Text {
    id: headingLabel
    anchors.top: headerBackground.bottom
    anchors.topMargin: 4
    anchors.horizontalCenter: parent.horizontalCenter
    visible: !isNaN(arMarkerModel.currentHeading)
    text: qsTr("Heading %1°").arg(Math.round(arMarkerModel.currentHeading))
    color: Theme.light
    font: Theme.tipFont
  }

  Column {
    id: statusColumn
    anchors.centerIn: parent
    width: Math.min(parent.width - 48, 410)
    spacing: 16

    Text {
      id: cameraPermissionText
      visible: cameraPermission.status !== Qt.PermissionStatus.Granted
      width: parent.width
      text: qsTr("The AR view needs access to the camera")
      color: Theme.light
      font: Theme.defaultFont
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
    }

    QfButton {
      id: cameraPermissionButton
      visible: cameraPermission.status !== Qt.PermissionStatus.Granted
      anchors.horizontalCenter: parent.horizontalCenter
      text: qsTr("Grant camera permission")
      onClicked: cameraPermission.request()
    }

    Text {
      id: positioningDisabledText
      visible: arView.positioningSource && !arView.positioningSource.active
      width: parent.width
      text: qsTr("Positioning is disabled")
      color: Theme.light
      font: Theme.defaultFont
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
    }

    QfButton {
      id: enablePositioningButton
      visible: arView.positioningSource && !arView.positioningSource.active
      anchors.horizontalCenter: parent.horizontalCenter
      text: qsTr("Enable positioning")
      onClicked: arView.positioningSource.active = true
    }

    Text {
      id: waitingForPositionText
      visible: arView.positioningSource && arView.positioningSource.active && !arMarkerModel.positionAvailable
      width: parent.width
      text: qsTr("Waiting for a position fix…")
      color: Theme.light
      font: Theme.defaultFont
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
    }

    Text {
      id: attitudeUnavailableText
      visible: !arMarkerModel.attitudeAvailable
      width: parent.width
      text: qsTr("This device does not provide the orientation sensors required by the AR view")
      color: Theme.light
      font: Theme.defaultFont
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
    }
  }

  QfButton {
    id: closeButton
    objectName: "arViewCloseButton"
    anchors.bottom: parent.bottom
    anchors.bottomMargin: mainWindow.sceneBottomMargin + 12
    anchors.horizontalCenter: parent.horizontalCenter
    width: Math.min(parent.width - 48, 200)
    text: qsTr("Close")
    onClicked: arView.closeRequested()
  }
}
