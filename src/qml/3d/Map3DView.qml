import QtQuick
import QtQuick3D
import QtQuick3D.Helpers

/**
 * Map3DView - Main 3D map viewer component
 * Phase 1: Procedural terrain with touch controls
 */
Item {
  id: root

  // Public properties
  property bool debugMode: true
  property color skyColor: "#87CEEB"
  property color groundColor: "#4a7c4e"
  property real terrainSize: 1000
  property real terrainHeight: 100
  property real verticalExaggeration: 1.5

  View3D {
    id: view3d
    anchors.fill: parent

    environment: SceneEnvironment {
      id: sceneEnvironment
      clearColor: root.skyColor
      backgroundMode: SceneEnvironment.Color
      antialiasingMode: SceneEnvironment.MSAA
      antialiasingQuality: SceneEnvironment.High
    }

    // Main camera
    PerspectiveCamera {
      id: camera
      position: Qt.vector3d(0, 400, 600)
      eulerRotation: Qt.vector3d(-30, 0, 0)
      clipNear: 1
      clipFar: 10000
      fieldOfView: 60
    }

    // Sun light
    DirectionalLight {
      id: sunLight
      eulerRotation: Qt.vector3d(-45, -45, 0)
      brightness: 1.0
      ambientColor: Qt.rgba(0.3, 0.3, 0.35, 1.0)
      castsShadow: false
    }

    // Fill light (softer, from opposite side)
    DirectionalLight {
      id: fillLight
      eulerRotation: Qt.vector3d(-30, 135, 0)
      brightness: 0.3
      castsShadow: false
    }

    // Real terrain mesh (C++ geometry)
    TerrainMesh {
      id: terrainMesh
      position: Qt.vector3d(0, -50, 0)  // Lower the terrain base
      resolution: 64
      terrainSize: root.terrainSize
      heightScale: root.terrainHeight * root.verticalExaggeration * 0.5  // Reduce height
      baseColor: root.groundColor
      proceduralOnLoad: true
    }

    // Legacy procedural terrain (QML-only, for fallback)
    ProceduralTerrain {
      id: proceduralTerrain
      visible: false  // Disabled, using TerrainMesh instead
      terrainSize: root.terrainSize
      terrainHeight: root.terrainHeight * root.verticalExaggeration
      gridResolution: 64
      baseColor: root.groundColor
    }

    // Sample buildings on terrain
    Node {
      id: buildingsNode
      position: Qt.vector3d(0, 20, 0)  // Raise buildings above terrain

      // Building 1 - tall
      Model {
        source: "#Cube"
        position: Qt.vector3d(100, 35, -50)
        scale: Qt.vector3d(0.4, 0.7, 0.4)
        materials: PrincipledMaterial {
          baseColor: "#e74c3c"
          roughness: 0.7
        }
      }

      // Building 2 - medium
      Model {
        source: "#Cube"
        position: Qt.vector3d(-80, 25, 100)
        scale: Qt.vector3d(0.5, 0.5, 0.5)
        materials: PrincipledMaterial {
          baseColor: "#3498db"
          roughness: 0.6
        }
      }

      // Building 3 - wide
      Model {
        source: "#Cube"
        position: Qt.vector3d(50, 20, 150)
        scale: Qt.vector3d(0.8, 0.4, 0.6)
        materials: PrincipledMaterial {
          baseColor: "#f39c12"
          roughness: 0.5
        }
      }

      // Building 4 - small
      Model {
        source: "#Cube"
        position: Qt.vector3d(-150, 15, -100)
        scale: Qt.vector3d(0.3, 0.3, 0.3)
        materials: PrincipledMaterial {
          baseColor: "#9b59b6"
          roughness: 0.6
        }
      }

      // Building 5
      Model {
        source: "#Cube"
        position: Qt.vector3d(200, 30, 50)
        scale: Qt.vector3d(0.6, 0.6, 0.4)
        materials: PrincipledMaterial {
          baseColor: "#1abc9c"
          roughness: 0.5
        }
      }
    }

    // Point markers (trees as cones)
    Node {
      id: treesNode
      position: Qt.vector3d(0, 20, 0)  // Raise trees above terrain

      Repeater3D {
        model: 20
        Model {
          source: "#Cone"
          position: Qt.vector3d(Math.sin(index * 1.3) * 300, 12, Math.cos(index * 1.7) * 300)
          scale: Qt.vector3d(0.15, 0.25, 0.15)
          materials: PrincipledMaterial {
            baseColor: "#27ae60"
            roughness: 0.8
          }
        }
      }
    }

    // Road (as a stretched cube for now)
    Model {
      source: "#Cube"
      position: Qt.vector3d(0, 22, 0)  // Raise road above terrain
      scale: Qt.vector3d(5, 0.02, 0.15)
      materials: PrincipledMaterial {
        baseColor: "#34495e"
        roughness: 0.9
      }
    }

    // Origin marker for camera controller
    Node {
      id: originNode
      position: Qt.vector3d(0, 50, 0)
    }
  }

  // Custom touch-friendly camera controller
  TouchCameraController {
    id: cameraController
    anchors.fill: parent
    camera: camera
    target: Qt.vector3d(0, 50, 0)
    distance: 800
    pitch: -30
    yaw: 0
    minDistance: 50
    maxDistance: 3000
  }

  // Debug overlay
  Rectangle {
    visible: root.debugMode
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.margins: 10
    width: debugColumn.width + 20
    height: debugColumn.height + 20
    color: "#CC000000"
    radius: 8

    Column {
      id: debugColumn
      anchors.centerIn: parent
      spacing: 4

      Text {
        color: "#4CAF50"
        font.pixelSize: 16
        font.bold: true
        text: "🗺️ QField 3D Viewer"
      }

      Text {
        color: "white"
        font.pixelSize: 11
        font.family: "monospace"
        text: "Camera: (" + camera.position.x.toFixed(0) + ", " + camera.position.y.toFixed(0) + ", " + camera.position.z.toFixed(0) + ")"
      }

      Text {
        color: "#aaa"
        font.pixelSize: 10
        text: "1 finger: orbit | 2 fingers: pan+zoom | Double tap: reset"
      }
    }
  }

  // Close button
  Rectangle {
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: 10
    width: 44
    height: 44
    radius: 22
    color: "#CC000000"

    Text {
      anchors.centerIn: parent
      text: "✕"
      color: "white"
      font.pixelSize: 20
      font.bold: true
    }

    MouseArea {
      anchors.fill: parent
      onClicked: {
        mainWindow.show3DView = false;
      }
    }
  }

  // Info panel
  Rectangle {
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.margins: 20
    width: infoText.width + 40
    height: infoText.height + 20
    color: "#CC000000"
    radius: height / 2

    Text {
      id: infoText
      anchors.centerIn: parent
      color: "white"
      font.pixelSize: 13
      text: "🏔️ Phase 1: Procedural Terrain Demo"
    }
  }
}
