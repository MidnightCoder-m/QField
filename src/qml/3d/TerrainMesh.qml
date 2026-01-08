import QtQuick
import QtQuick3D
import org.qfield 1.0

/**
 * TerrainMesh - 3D terrain mesh using custom geometry
 *
 * Uses QgsQuick3DTerrainGeometry C++ class for efficient mesh generation.
 * Supports both procedural and DEM-based terrain.
 * Can use satellite/aerial imagery texture when available.
 */
Node {
  id: root

  // Terrain properties
  property int resolution: 64
  property real terrainSize: 1000
  property real heightScale: 100
  property color baseColor: "#4a7c4e"
  property real roughness: 0.85
  property var heightData: []

  // Generate procedural terrain on load
  property bool proceduralOnLoad: true

  // External texture for satellite/aerial imagery
  property var satelliteTexture: null
  property bool satelliteTextureReady: false  // Set by parent when texture is actually ready
  property bool useSatelliteTexture: satelliteTexture !== null && satelliteTextureReady

  onSatelliteTextureReadyChanged: {
    if (satelliteTextureReady && satelliteTexture) {
      terrainMaterial.baseColorMap = satelliteTexture;
    }
  }

  // Procedural grass texture (generated at runtime)
  Texture {
    id: grassTexture
    sourceItem: Canvas {
      id: grassCanvas
      width: 256
      height: 256

      onPaint: {
        var ctx = getContext("2d");

        // Base green gradient
        var gradient = ctx.createLinearGradient(0, 0, 256, 256);
        gradient.addColorStop(0.0, "#3d6b3d");
        gradient.addColorStop(0.3, "#4a7c4e");
        gradient.addColorStop(0.6, "#5a8a5a");
        gradient.addColorStop(1.0, "#4a7c4e");
        ctx.fillStyle = gradient;
        ctx.fillRect(0, 0, 256, 256);

        // Add noise/variation
        for (var i = 0; i < 500; i++) {
          var x = Math.random() * 256;
          var y = Math.random() * 256;
          var size = Math.random() * 3 + 1;
          var brightness = Math.random() * 40 - 20;
          var r = 74 + brightness;
          var g = 124 + brightness;
          var b = 78 + brightness;
          ctx.fillStyle = "rgb(" + Math.floor(r) + "," + Math.floor(g) + "," + Math.floor(b) + ")";
          ctx.beginPath();
          ctx.arc(x, y, size, 0, Math.PI * 2);
          ctx.fill();
        }

        // Add some darker patches
        for (var j = 0; j < 20; j++) {
          var px = Math.random() * 256;
          var py = Math.random() * 256;
          var pr = Math.random() * 20 + 10;
          ctx.fillStyle = "rgba(40, 60, 40, 0.3)";
          ctx.beginPath();
          ctx.arc(px, py, pr, 0, Math.PI * 2);
          ctx.fill();
        }
      }

      Component.onCompleted: requestPaint()
    }
    scaleU: 10
    scaleV: 10
    tilingModeHorizontal: Texture.Repeat
    tilingModeVertical: Texture.Repeat
  }

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

    materials: [
      PrincipledMaterial {
        id: terrainMaterial
        baseColorMap: root.useSatelliteTexture ? root.satelliteTexture : grassTexture
        roughness: root.useSatelliteTexture ? 0.9 : root.roughness
        metalness: 0.0
        normalStrength: root.useSatelliteTexture ? 0.0 : 0.3
      }
    ]
  }

  // Update height data when changed
  onHeightDataChanged: {
    if (heightData.length > 0) {
      terrainGeometry.heightData = heightData;
    }
  }

  onProceduralOnLoadChanged: {
    if (proceduralOnLoad) {
      terrainGeometry.generateProceduralTerrain();
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
