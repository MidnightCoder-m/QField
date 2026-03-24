import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Particles
import QtMultimedia
import org.qfield
import Theme

Item {
  id: arStakeout
  focus: true

  property Navigation navigation
  property Positioning positionSource

  signal closed

  readonly property double proximityLevel: controller.proximityLevel
  readonly property double markerScreenX: controller.markerPosition.x * width
  readonly property double markerScreenY: controller.markerPosition.y * height

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

  Shape {
    id: pathTrail
    anchors.fill: parent
    visible: controller.isOnScreen
    opacity: 0.7

    ShapePath {
      strokeWidth: 2
      strokeColor: Qt.rgba(1.0 - proximityLevel, proximityLevel, 0.3, 0.8)
      strokeStyle: ShapePath.DashLine
      dashPattern: [8, 6]
      fillColor: "transparent"
      startX: arStakeout.width / 2
      startY: arStakeout.height

      PathQuad {
        x: markerScreenX
        y: markerScreenY
        controlX: (arStakeout.width / 2 + markerScreenX) / 2
        controlY: markerScreenY + (arStakeout.height - markerScreenY) * 0.3
      }
    }

    ShapePath {
      strokeWidth: 1
      strokeColor: Qt.rgba(1.0 - proximityLevel, proximityLevel, 0.4, 0.3)
      strokeStyle: ShapePath.DashLine
      dashPattern: [4, 8]
      fillColor: "transparent"
      startX: arStakeout.width / 2 - 6
      startY: arStakeout.height

      PathQuad {
        x: markerScreenX - 4
        y: markerScreenY
        controlX: (arStakeout.width / 2 + markerScreenX) / 2 - 10
        controlY: markerScreenY + (arStakeout.height - markerScreenY) * 0.35
      }
    }

    ShapePath {
      strokeWidth: 1
      strokeColor: Qt.rgba(1.0 - proximityLevel, proximityLevel, 0.4, 0.3)
      strokeStyle: ShapePath.DashLine
      dashPattern: [4, 8]
      fillColor: "transparent"
      startX: arStakeout.width / 2 + 6
      startY: arStakeout.height

      PathQuad {
        x: markerScreenX + 4
        y: markerScreenY
        controlX: (arStakeout.width / 2 + markerScreenX) / 2 + 10
        controlY: markerScreenY + (arStakeout.height - markerScreenY) * 0.35
      }
    }
  }

  Shape {
    id: scanLines
    anchors.fill: parent
    opacity: 0.06

    Repeater {
      model: Math.floor(arStakeout.height / 20)

      Shape {
        width: arStakeout.width
        height: 1
        y: index * 20

        ShapePath {
          strokeWidth: 0.5
          strokeColor: Qt.rgba(0.3, 1.0, 0.5, 0.5)
          fillColor: "transparent"
          startX: 0; startY: 0
          PathLine { x: arStakeout.width; y: 0 }
        }
      }
    }
  }

  Rectangle {
    id: scanSweep
    anchors.left: parent.left
    anchors.right: parent.right
    height: 2
    color: Qt.rgba(0.3, 1.0, 0.5, 0.15)
    y: 0

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      height: 30
      anchors.bottom: parent.bottom
      gradient: Gradient {
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 1.0; color: Qt.rgba(0.3, 1.0, 0.5, 0.08) }
      }
    }

    SequentialAnimation on y {
      loops: Animation.Infinite
      running: arStakeout.visible

      NumberAnimation {
        from: 0
        to: arStakeout.height
        duration: 3000
        easing.type: Easing.Linear
      }
      PauseAnimation { duration: 500 }
    }
  }

  Shape {
    id: compassRing
    anchors.fill: parent
    opacity: 0.5

    readonly property double compassRotation: !isNaN(positionSource.orientation) ? -positionSource.orientation : 0

    Repeater {
      model: ["N", "E", "S", "W"]

      Text {
        readonly property double angle: index * 90 + compassRing.compassRotation
        readonly property double rad: angle * Math.PI / 180
        readonly property double cx: arStakeout.width / 2
        readonly property double cy: arStakeout.height / 2
        readonly property double rx: Math.min(cx, cy) - 20

        x: cx + rx * Math.sin(rad) - width / 2
        y: cy - rx * Math.cos(rad) - height / 2

        text: modelData
        font.pixelSize: modelData === "N" ? 18 : 14
        font.bold: modelData === "N"
        color: modelData === "N" ? "#ff4444" : Qt.rgba(1, 1, 1, 0.6)
        style: Text.Outline
        styleColor: "#000000"
      }
    }

    Repeater {
      model: 36

      Rectangle {
        readonly property double angle: index * 10 + compassRing.compassRotation
        readonly property double rad: angle * Math.PI / 180
        readonly property double cx: arStakeout.width / 2
        readonly property double cy: arStakeout.height / 2
        readonly property double rx: Math.min(cx, cy) - 8
        readonly property bool isMajor: index % 9 === 0

        x: cx + rx * Math.sin(rad) - width / 2
        y: cy - rx * Math.cos(rad) - height / 2
        width: isMajor ? 3 : 1
        height: isMajor ? 12 : 6
        color: Qt.rgba(1, 1, 1, isMajor ? 0.7 : 0.3)
        rotation: angle
        transformOrigin: Item.Center
      }
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
    x: markerScreenX - width / 2
    y: markerScreenY - height / 2
    visible: controller.isOnScreen
    proximityLevel: controller.proximityLevel
    distance: navigation.distance
    distanceUnits: navigation.distanceUnits
  }

  ParticleSystem {
    id: celebrationParticles
    running: proximityLevel > 0.85
  }

  ImageParticle {
    anchors.fill: parent
    system: celebrationParticles
    source: "qrc:///particleresources/star.png"
    sizeTable: "qrc:///images/sparkleSize.png"
    alpha: 0.8
    colorVariation: 0.2
    color: "#4caf50"
  }

  Emitter {
    id: celebrationEmitter
    system: celebrationParticles
    x: markerScreenX
    y: markerScreenY
    emitRate: proximityLevel > 0.95 ? 80 : 30
    lifeSpan: 1000
    size: 30
    sizeVariation: 15
    enabled: proximityLevel > 0.85

    velocity: AngleDirection {
      angle: 0
      angleVariation: 360
      magnitude: 80
      magnitudeVariation: 40
    }
  }

  Rectangle {
    id: proximityPulse
    anchors.fill: parent
    color: "transparent"
    border.width: proximityLevel > 0.9 ? 8 : 0
    border.color: Qt.rgba(0.3, 1.0, 0.3, pulseOpacity)
    radius: 0
    visible: proximityLevel > 0.7

    property double pulseOpacity: 0.0

    SequentialAnimation on pulseOpacity {
      loops: Animation.Infinite
      running: proximityLevel > 0.7

      NumberAnimation {
        from: 0.0
        to: proximityLevel > 0.9 ? 0.6 : 0.3
        duration: proximityLevel > 0.9 ? 300 : 600
        easing.type: Easing.OutQuad
      }
      NumberAnimation {
        from: proximityLevel > 0.9 ? 0.6 : 0.3
        to: 0.0
        duration: proximityLevel > 0.9 ? 300 : 600
        easing.type: Easing.InQuad
      }
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: 4
      color: "transparent"
      border.width: proximityLevel > 0.9 ? 2 : 0
      border.color: Qt.rgba(0.3, 1.0, 0.3, parent.pulseOpacity * 0.5)
    }
  }

  Rectangle {
    id: cornerTL
    width: 40; height: 40
    anchors.top: parent.top; anchors.left: parent.left
    anchors.margins: 12
    color: "transparent"
    Rectangle { width: 20; height: 2; color: Qt.rgba(1,1,1,0.4); anchors.top: parent.top; anchors.left: parent.left }
    Rectangle { width: 2; height: 20; color: Qt.rgba(1,1,1,0.4); anchors.top: parent.top; anchors.left: parent.left }
  }
  Rectangle {
    id: cornerTR
    width: 40; height: 40
    anchors.top: parent.top; anchors.right: parent.right
    anchors.margins: 12
    color: "transparent"
    Rectangle { width: 20; height: 2; color: Qt.rgba(1,1,1,0.4); anchors.top: parent.top; anchors.right: parent.right }
    Rectangle { width: 2; height: 20; color: Qt.rgba(1,1,1,0.4); anchors.top: parent.top; anchors.right: parent.right }
  }
  Rectangle {
    id: cornerBL
    width: 40; height: 40
    anchors.bottom: parent.bottom; anchors.left: parent.left
    anchors.margins: 12
    color: "transparent"
    Rectangle { width: 20; height: 2; color: Qt.rgba(1,1,1,0.4); anchors.bottom: parent.bottom; anchors.left: parent.left }
    Rectangle { width: 2; height: 20; color: Qt.rgba(1,1,1,0.4); anchors.bottom: parent.bottom; anchors.left: parent.left }
  }
  Rectangle {
    id: cornerBR
    width: 40; height: 40
    anchors.bottom: parent.bottom; anchors.right: parent.right
    anchors.margins: 12
    color: "transparent"
    Rectangle { width: 20; height: 2; color: Qt.rgba(1,1,1,0.4); anchors.bottom: parent.bottom; anchors.right: parent.right }
    Rectangle { width: 2; height: 20; color: Qt.rgba(1,1,1,0.4); anchors.bottom: parent.bottom; anchors.right: parent.right }
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
