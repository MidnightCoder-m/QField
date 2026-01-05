import QtQuick
import QtQuick3D
import org.qfield 1.0

/**
 * TerrainMesh - 3D terrain mesh using custom geometry
 *
 * Uses QgsQuick3DTerrainGeometry C++ class for efficient mesh generation.
 * Supports both procedural and DEM-based terrain.
 */
Node {
  id: root

  // Terrain properties
  property int resolution: 64
  property real terrainSize: 1000
  property real heightScale: 100
  property color baseColor: "#4a7c4e"
  property real roughness: 0.9
  property var heightData: []

  // Generate procedural terrain on load
  property bool proceduralOnLoad: true

  Model {
    id: terrainModel

    geometry: QgsQuick3DTerrainGeometry {
      id: terrainGeometry
      resolution: root.resolution
      terrainSize: root.terrainSize
      heightScale: root.heightScale

      Component.onCompleted: {
        if (root.proceduralOnLoad) {
          generateProceduralTerrain();
        }
      }
    }

    materials: PrincipledMaterial {
      id: terrainMaterial
      baseColor: root.baseColor
      roughness: root.roughness
      metalness: 0.0
    }
  }

  // Update height data when changed
  onHeightDataChanged: {
    if (heightData.length > 0) {
      terrainGeometry.heightData = heightData;
    }
  }

  // Public functions
  function regenerateProcedural() {
    terrainGeometry.generateProceduralTerrain();
  }

  function setFlat(height) {
    terrainGeometry.generateFlatTerrain(height);
  }
}
