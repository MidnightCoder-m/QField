import QtQuick
import QtQuick3D

/**
 * ProceduralTerrain - Generates a terrain mesh with hills using sine waves
 * Phase 1: Pure QML procedural generation
 */
Node {
  id: root

  // Configuration
  property real terrainSize: 1000
  property real terrainHeight: 100
  property int gridResolution: 64
  property color baseColor: "#4a7c4e"

  // Internal
  property int vertexCount: gridResolution * gridResolution
  property int triangleCount: (gridResolution - 1) * (gridResolution - 1) * 2

  Model {
    id: terrainModel
    source: "#Rectangle"
    scale: Qt.vector3d(terrainSize / 100, terrainSize / 100, 1)
    eulerRotation: Qt.vector3d(-90, 0, 0)
    position: Qt.vector3d(0, 0, 0)

    materials: PrincipledMaterial {
      id: terrainMaterial
      baseColor: root.baseColor
      roughness: 0.85
      metalness: 0.0
    }
  }

  // Hills using multiple scaled cubes with different heights
  // This creates a "low-poly" terrain effect
  Node {
    id: hillsContainer

    // Generate hills procedurally
    Repeater3D {
      id: hillRepeater
      model: 25

      Model {
        id: hill
        source: "#Sphere"

        property real hillX: (Math.sin(index * 2.5) * 0.8) * (terrainSize * 0.4)
        property real hillZ: (Math.cos(index * 1.7) * 0.8) * (terrainSize * 0.4)
        property real hillHeight: (Math.abs(Math.sin(index * 0.7)) * 0.6 + 0.2) * terrainHeight
        property real hillRadius: (Math.abs(Math.cos(index * 0.5)) * 0.4 + 0.3) * terrainSize * 0.15

        position: Qt.vector3d(hillX, hillHeight * 0.3, hillZ)
        scale: Qt.vector3d(hillRadius / 50, hillHeight / 50, hillRadius / 50)

        materials: PrincipledMaterial {
          baseColor: {
            // Vary color slightly based on height
            var heightFactor = hill.hillHeight / terrainHeight;
            if (heightFactor > 0.7) {
              return "#6b8e6b"; // Lighter green for high
            } else if (heightFactor > 0.4) {
              return "#4a7c4e"; // Base green
            } else {
              return "#3d6b40"; // Darker green for low
            }
          }
          roughness: 0.9
        }
      }
    }
  }

  // Ridge line (mountain range effect)
  Node {
    id: ridgeContainer

    Repeater3D {
      model: 8
      Model {
        source: "#Cone"
        property real ridgeX: (index - 4) * (terrainSize * 0.12)
        property real peakHeight: (Math.sin(index * 0.8) * 0.3 + 0.7) * terrainHeight * 1.5

        position: Qt.vector3d(ridgeX, peakHeight * 0.4, -terrainSize * 0.35)
        scale: Qt.vector3d(terrainSize * 0.001 * (6 + index % 3), peakHeight / 50, terrainSize * 0.001 * (5 + index % 4))
        eulerRotation: Qt.vector3d(0, index * 15, 0)

        materials: PrincipledMaterial {
          baseColor: "#5d7a5d"
          roughness: 0.85
        }
      }
    }
  }

  // Valley (lower area)
  Model {
    source: "#Cylinder"
    position: Qt.vector3d(terrainSize * 0.2, -5, terrainSize * 0.15)
    scale: Qt.vector3d(terrainSize * 0.003, 0.1, terrainSize * 0.002)
    eulerRotation: Qt.vector3d(0, 30, 0)

    materials: PrincipledMaterial {
      baseColor: "#3a5f3a"
      roughness: 0.95
    }
  }

  // Water body (lake)
  Model {
    id: lake
    source: "#Cylinder"
    position: Qt.vector3d(-terrainSize * 0.25, 1, terrainSize * 0.2)
    scale: Qt.vector3d(terrainSize * 0.0015, 0.02, terrainSize * 0.001)

    materials: PrincipledMaterial {
      baseColor: "#4a90a4"
      roughness: 0.1
      metalness: 0.3
    }
  }

  // River (simple line)
  Model {
    source: "#Cube"
    position: Qt.vector3d(-terrainSize * 0.1, 2, 0)
    scale: Qt.vector3d(0.08, 0.02, terrainSize * 0.008)
    eulerRotation: Qt.vector3d(0, 20, 0)

    materials: PrincipledMaterial {
      baseColor: "#5ba3b8"
      roughness: 0.2
      metalness: 0.2
    }
  }
}
