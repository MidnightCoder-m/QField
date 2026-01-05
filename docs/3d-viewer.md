# QField 3D Viewer

## Overview

A 3D terrain visualization feature for QField that displays DEM (Digital Elevation Model) data from QGIS projects using QtQuick3D.

## Features (Phase 2 - Complete)

- ✅ Real DEM terrain loading from QGIS project
- ✅ Automatic CRS transformation (Project CRS → Layer CRS)
- ✅ Touch-friendly camera controls (orbit, pan, pinch-zoom)
- ✅ Procedural grass texture
- ✅ DEM extent auto-detection
- ✅ Height normalization and scaling

## Architecture

### QML Components (`src/qml/3d/`)

- **Map3DView.qml** - Main 3D viewer component
- **TerrainMesh.qml** - Terrain mesh with procedural texture
- **TouchCameraController.qml** - Touch/mouse camera controls
- **ProceduralTerrain.qml** - Legacy procedural terrain (unused)
- **Test3DView.qml** - Test component

### C++ Classes (`src/core/sketquick3d/`)

- **QgsQuick3DTerrainProvider** - Reads DEM from QGIS project, handles CRS transform
- **QgsQuick3DTerrainGeometry** - Custom QtQuick3D geometry for terrain mesh

## Usage

1. Load a QGIS project with terrain configured (Project → Properties → Terrain)
2. Press the 3D button to toggle the 3D view
3. Controls:
   - Single finger/mouse drag: Orbit camera
   - Two finger drag: Pan
   - Pinch/scroll: Zoom
   - Double tap: Reset view

## Future Phases (Planned)

- [ ] Drape satellite/aerial imagery on terrain
- [ ] Hillshade texture generation
- [ ] Mini-map overlay
- [ ] Improved touch controls
