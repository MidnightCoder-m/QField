import QtQuick
import QtQuick3D
import QtQuick3D.Helpers
import org.qfield 1.0

/**
 * Map3DView - Main 3D map viewer component
 * Phase 2.5: Real DEM terrain with satellite/aerial imagery draping
 */
Item {
  id: root

  // Ensure this item captures all input when visible
  focus: true

  Component.onCompleted:
  // 3D view initialized
  {
  }

  // Public properties
  property bool debugMode: true
  property color skyColor: "#87CEEB"
  property color groundColor: "#4a7c4e"
  property real terrainSize: 2000
  property real terrainHeight: 100
  property real verticalExaggeration: 0.1  // Reduced for real DEM data

  // QGIS project for real terrain data
  property var qgisProject: null

  // Whether to use real DEM or procedural terrain
  property bool useRealTerrain: qgisProject !== null && terrainProvider.hasTerrainData

  // Whether satellite texture is ready
  property bool hasSatelliteTexture: textureGenerator.ready

  // Map texture generator for draping satellite/aerial imagery
  QgsQuick3DMapTextureGenerator {
    id: textureGenerator
    project: root.qgisProject
    textureSize: 2048  // High quality texture

    onReadyChanged: {
      if (ready) {
        console.log("3D: Satellite texture ready! Loading from file:", textureFilePath);
        // Load texture from file instead of image provider (more reliable for 3D)
        satelliteTexture.source = "file://" + textureFilePath;
      }
    }

    onRenderError: function (error) {
      console.log("3D: Texture render error:", error);
    }
  }

  // Satellite texture loaded from file
  Texture {
    id: satelliteTexture
    source: ""

    onSourceChanged: {
      console.log("3D: Texture source changed to:", source);
    }
  }

  // Terrain data provider (reads from QGIS project)
  QgsQuick3DTerrainProvider {
    id: terrainProvider
    project: root.qgisProject
    resolution: 64
    verticalExaggeration: root.verticalExaggeration

    // extent is automatically set to demExtent internally
    onTerrainDataReady: {
      if (hasTerrainData) {
        Qt.callLater(loadRealTerrain);
      }
    }
  }

  // Function to load real terrain data (called async)
  function loadRealTerrain() {
    try {
      var heights = terrainProvider.sampleHeightGrid();
      if (heights.length === 0) {
        return;
      }

      // Find min/max to normalize heights
      var minH = Number.MAX_VALUE;
      var maxH = Number.MIN_VALUE;
      for (var i = 0; i < heights.length; i++) {
        if (heights[i] < minH)
          minH = heights[i];
        if (heights[i] > maxH)
          maxH = heights[i];
      }
      var heightRange = maxH - minH;

      // Normalize heights for display (scale to fit in view)
      // Keep terrainSize at 2000 for consistent camera behavior
      // Scale heights proportionally
      if (heightRange > 0) {
        var normalizedHeights = [];
        // Target height should be visible but not overwhelming
        // Use 30% of terrainSize as max height
        var targetMaxHeight = root.terrainSize * 0.3;
        var scale = targetMaxHeight / heightRange;
        for (var j = 0; j < heights.length; j++) {
          normalizedHeights.push((heights[j] - minH) * scale);
        }
        heights = normalizedHeights;
      }
      terrainMesh.heightData = heights;
      terrainMesh.proceduralOnLoad = false;

      // Update internal cache for display
      internal.minHeight = minH;
      internal.maxHeight = maxH;

      // Log terrain info for camera positioning
      console.log("=== TERRAIN LOADED ===");
      console.log("  terrainSize:", root.terrainSize);
      console.log("  heightRange (original):", heightRange.toFixed(1), "m (", minH.toFixed(1), "-", maxH.toFixed(1), ")");
      console.log("  targetMaxHeight (scaled):", (root.terrainSize * 0.3).toFixed(1));
      console.log("  terrain bounds: X=[", (-root.terrainSize / 2).toFixed(0), ",", (root.terrainSize / 2).toFixed(0), "]");
      console.log("                  Z=[", (-root.terrainSize / 2).toFixed(0), ",", (root.terrainSize / 2).toFixed(0), "]");
      console.log("                  Y=[0,", (root.terrainSize * 0.3).toFixed(0), "]");

      // Auto-position camera to view terrain from above
      positionCameraForTerrain();

      // Trigger satellite texture rendering with DEM extent
      var demExt = terrainProvider.demExtent;
      console.log("3D: DEM extent for texture:", demExt);
      if (demExt && demExt.width > 0 && demExt.height > 0) {
        textureGenerator.extent = demExt;
        Qt.callLater(function () {
            textureGenerator.render();
          });
      }
    } catch (e) {
      console.log("3D ERROR:", e);
    }
  }

  // Auto-position camera to get a good view of the terrain
  function positionCameraForTerrain() {
    // Calculate good viewing distance based on terrain size
    var terrainDiagonal = Math.sqrt(2) * root.terrainSize;  // Diagonal of terrain
    var targetHeight = root.terrainSize * 0.3;  // Max terrain height

    // Camera should be far enough to see the whole terrain
    // Distance = terrain diagonal * 0.8 gives a good overview
    var viewDistance = terrainDiagonal * 0.8;

    // Position camera above and behind terrain center
    // Looking down at ~45 degree angle
    var cameraHeight = viewDistance * 0.6;  // 60% of distance as height
    var cameraZ = viewDistance * 0.7;       // 70% of distance behind

    // Update camera controller parameters
    cameraController.distance = viewDistance;
    cameraController.pitch = 40;  // 40 degrees above horizon (positive = above target)
    cameraController.yaw = 0;
    cameraController.target = Qt.vector3d(0, targetHeight * 0.3, 0);  // Look at terrain center, slightly above base
    console.log("=== CAMERA POSITIONED ===");
    console.log("  viewDistance:", viewDistance.toFixed(0));
    console.log("  target:", cameraController.target);
    console.log("  pitch:", cameraController.pitch);
  }

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
      position: Qt.vector3d(0, 1500, 2000)  // Will be overridden by controller
      eulerRotation: Qt.vector3d(-40, 0, 0)
      clipNear: 1
      clipFar: 50000
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
      position: Qt.vector3d(0, 0, 0)
      resolution: 64
      terrainSize: root.terrainSize
      heightScale: 1.0  // Heights are already normalized in loadRealTerrain()
      baseColor: root.groundColor
      proceduralOnLoad: true
      satelliteTexture: satelliteTexture
      satelliteTextureReady: textureGenerator.ready  // Only use texture when it's actually rendered
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
    target: Qt.vector3d(0, 100, 0)
    distance: 2200  // Good starting distance for terrainSize=2000
    pitch: 40       // 40 degrees above horizon (positive = camera above target)
    yaw: 0
    minDistance: 500   // Don't allow zooming into terrain (keep distance)
    maxDistance: 10000
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
        color: root.useRealTerrain ? "#4CAF50" : "#FFC107"
        font.pixelSize: 11
        text: "Terrain: " + (root.useRealTerrain ? "DEM (" + terrainProvider.terrainType + ")" : "Procedural")
      }

      Text {
        color: root.hasSatelliteTexture ? "#4CAF50" : "#FFC107"
        font.pixelSize: 11
        text: "Texture: " + (root.hasSatelliteTexture ? "Satellite/Aerial" : "Procedural Grass")
      }

      Text {
        visible: root.useRealTerrain
        color: "#aaa"
        font.pixelSize: 10
        text: "Heights: " + internal.minHeight.toFixed(0) + " - " + internal.maxHeight.toFixed(0) + " m"
      }

      Text {
        color: "#aaa"
        font.pixelSize: 10
        text: "1 finger: orbit | 2 fingers: pan+zoom | Double tap: reset"
      }
    }
  }

  // Internal state to cache terrain stats (avoid calling every frame)
  QtObject {
    id: internal
    property real minHeight: 0
    property real maxHeight: 0
  }

  Connections {
    target: terrainProvider
    function onTerrainDataReady() {
      var stats = terrainProvider.terrainStats();
      internal.minHeight = stats.minHeight || 0;
      internal.maxHeight = stats.maxHeight || 0;
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
      z: 1000  // Ensure it's on top
      onClicked: {
        console.log("3D: Close button clicked!");
        mainWindow.show3DView = false;
      }
      onPressed: {
        console.log("3D: Close button pressed");
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
      text: root.hasSatelliteTexture ? "🛰️ Phase 2.5: Satellite Imagery on DEM" : (root.useRealTerrain ? "🗺️ Phase 2: Real DEM Terrain" : "🏔️ Phase 1: Procedural Terrain Demo")
    }
  }
}
