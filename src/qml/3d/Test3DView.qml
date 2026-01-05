import QtQuick
import QtQuick3D
import QtQuick3D.Helpers

/**
 * Test3DView - Minimal 3D scene to verify QtQuick3D integration
 * Phase 0: Foundation test
 *
 * This component creates a simple 3D scene with:
 * - A camera looking at the origin
 * - Basic lighting
 * - A simple cube for visualization
 * - Mouse/touch orbit controls
 */
Item {
  id: root

  // Public properties
  property bool debugMode: true
  property color backgroundColor: "#1a1a2e"

  View3D {
    id: view3d
    anchors.fill: parent

    environment: SceneEnvironment {
      id: sceneEnvironment
      clearColor: root.backgroundColor
      backgroundMode: SceneEnvironment.Color
      antialiasingMode: SceneEnvironment.MSAA
      antialiasingQuality: SceneEnvironment.High
    }

    // Camera setup
    PerspectiveCamera {
      id: camera
      position: Qt.vector3d(300, 200, 300)
      eulerRotation: Qt.vector3d(-25, 45, 0)
      clipNear: 1
      clipFar: 10000
    }

    // Lighting
    DirectionalLight {
      id: mainLight
      eulerRotation: Qt.vector3d(-45, 45, 0)
      brightness: 1.0
      ambientColor: Qt.rgba(0.2, 0.2, 0.2, 1.0)
    }

    // Ground plane (simple terrain placeholder)
    Model {
      id: groundPlane
      source: "#Rectangle"
      scale: Qt.vector3d(5, 5, 1)
      eulerRotation: Qt.vector3d(-90, 0, 0)
      position: Qt.vector3d(0, 0, 0)

      materials: PrincipledMaterial {
        id: groundMaterial
        baseColor: "#2d5016"
        roughness: 0.8
      }
    }

    // Test cube (building placeholder)
    Model {
      id: testCube
      source: "#Cube"
      position: Qt.vector3d(0, 25, 0)
      scale: Qt.vector3d(0.5, 0.5, 0.5)

      materials: PrincipledMaterial {
        id: cubeMaterial
        baseColor: "#e94560"
        roughness: 0.3
        metalness: 0.1
      }
    }

    // Second test cube
    Model {
      id: testCube2
      source: "#Cube"
      position: Qt.vector3d(80, 40, -50)
      scale: Qt.vector3d(0.4, 0.8, 0.4)

      materials: PrincipledMaterial {
        baseColor: "#0f3460"
        roughness: 0.4
      }
    }

    // Third test cube (smaller)
    Model {
      id: testCube3
      source: "#Cube"
      position: Qt.vector3d(-60, 15, 40)
      scale: Qt.vector3d(0.3, 0.3, 0.3)

      materials: PrincipledMaterial {
        baseColor: "#f1c40f"
        roughness: 0.5
      }
    }

    // Origin point for camera orbit
    Node {
      id: originNode
      position: Qt.vector3d(0, 50, 0)
    }
  }

  // Simple orbit camera controller
  OrbitCameraController {
    id: cameraController
    anchors.fill: parent
    origin: originNode
    camera: camera
  }

  // Debug overlay
  Rectangle {
    visible: root.debugMode
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.margins: 10
    width: debugText.width + 20
    height: debugText.height + 20
    color: "#80000000"
    radius: 5

    Text {
      id: debugText
      anchors.centerIn: parent
      color: "white"
      font.pixelSize: 12
      font.family: "monospace"
      text: "QField 3D Test\n" + "Camera pos: (" + camera.position.x.toFixed(0) + ", " + camera.position.y.toFixed(0) + ", " + camera.position.z.toFixed(0) + ")\n" + "Drag to orbit | Pinch to zoom"
    }
  }

  // Status indicator
  Rectangle {
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.margins: 20
    width: statusText.width + 30
    height: statusText.height + 16
    color: "#4CAF50"
    radius: height / 2

    Text {
      id: statusText
      anchors.centerIn: parent
      color: "white"
      font.pixelSize: 14
      font.bold: true
      text: "✓ QtQuick3D Working!"
    }
  }
}
