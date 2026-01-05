import QtQuick
import QtQuick3D

/**
 * TouchCameraController - Custom touch-friendly camera controller
 *
 * Controls:
 * - Single finger drag: Orbit around target
 * - Two finger drag: Pan camera
 * - Pinch: Zoom in/out
 * - Double tap: Reset view
 */
Item {
  id: root

  // Camera to control
  required property PerspectiveCamera camera

  // Target point to orbit around
  property vector3d target: Qt.vector3d(0, 0, 0)

  // Camera constraints
  property real minDistance: 100
  property real maxDistance: 2000
  property real minPitch: -89  // degrees
  property real maxPitch: 89   // degrees

  // Sensitivity
  property real orbitSensitivity: 0.3
  property real panSensitivity: 1.0
  property real zoomSensitivity: 0.005

  // Current camera state (spherical coordinates)
  property real distance: 800
  property real yaw: 0      // horizontal angle (degrees)
  property real pitch: -30  // vertical angle (degrees)

  // Animation
  property bool animating: false

  // Internal state
  QtObject {
    id: internal
    property point lastPos: Qt.point(0, 0)
    property point lastPos2: Qt.point(0, 0)
    property real lastPinchDistance: 0
    property bool isPanning: false
    property int touchCount: 0
  }

  Component.onCompleted: {
    updateCameraPosition();
  }

  // Update camera position from spherical coordinates
  function updateCameraPosition() {
    var pitchRad = pitch * Math.PI / 180;
    var yawRad = yaw * Math.PI / 180;
    var x = target.x + distance * Math.cos(pitchRad) * Math.sin(yawRad);
    var y = target.y + distance * Math.sin(pitchRad);
    var z = target.z + distance * Math.cos(pitchRad) * Math.cos(yawRad);
    camera.position = Qt.vector3d(x, y, z);
    camera.lookAt(target);
  }

  // Reset view to default
  function resetView() {
    yaw = 0;
    pitch = -30;
    distance = 800;
    target = Qt.vector3d(0, 0, 0);
    updateCameraPosition();
  }

  // Zoom to fit
  function zoomToFit(center, radius) {
    target = center;
    distance = radius * 2.5;
    updateCameraPosition();
  }

  // Multi-touch handler
  MultiPointTouchArea {
    id: touchArea
    anchors.fill: parent
    minimumTouchPoints: 1
    maximumTouchPoints: 2
    mouseEnabled: true

    touchPoints: [
      TouchPoint {
        id: touch1
      },
      TouchPoint {
        id: touch2
      }
    ]

    onPressed: function (touchPoints) {
      internal.touchCount = touchPoints.length;
      if (touchPoints.length >= 1) {
        internal.lastPos = Qt.point(touchPoints[0].x, touchPoints[0].y);
      }
      if (touchPoints.length >= 2) {
        internal.lastPos2 = Qt.point(touchPoints[1].x, touchPoints[1].y);
        internal.lastPinchDistance = calculateDistance(touchPoints[0].x, touchPoints[0].y, touchPoints[1].x, touchPoints[1].y);
        internal.isPanning = true;
      }
    }

    onUpdated: function (touchPoints) {
      if (touchPoints.length === 0)
        return;
      if (touchPoints.length === 1 && !internal.isPanning) {
        // Single finger: orbit
        var dx = touchPoints[0].x - internal.lastPos.x;
        var dy = touchPoints[0].y - internal.lastPos.y;
        root.yaw += dx * root.orbitSensitivity;
        root.pitch = Math.max(root.minPitch, Math.min(root.maxPitch, root.pitch - dy * root.orbitSensitivity));
        internal.lastPos = Qt.point(touchPoints[0].x, touchPoints[0].y);
        updateCameraPosition();
      } else if (touchPoints.length === 2) {
        // Two fingers: pan + pinch zoom
        var currentDistance = calculateDistance(touchPoints[0].x, touchPoints[0].y, touchPoints[1].x, touchPoints[1].y);

        // Pinch zoom
        if (internal.lastPinchDistance > 0) {
          var pinchDelta = currentDistance - internal.lastPinchDistance;
          root.distance = Math.max(root.minDistance, Math.min(root.maxDistance, root.distance - pinchDelta * root.zoomSensitivity * root.distance));
        }

        // Pan (average movement of both fingers)
        var centerX = (touchPoints[0].x + touchPoints[1].x) / 2;
        var centerY = (touchPoints[0].y + touchPoints[1].y) / 2;
        var lastCenterX = (internal.lastPos.x + internal.lastPos2.x) / 2;
        var lastCenterY = (internal.lastPos.y + internal.lastPos2.y) / 2;
        var panDx = (centerX - lastCenterX) * root.panSensitivity;
        var panDy = (centerY - lastCenterY) * root.panSensitivity;

        // Calculate pan direction based on camera orientation
        var yawRad = root.yaw * Math.PI / 180;
        var rightX = Math.cos(yawRad);
        var rightZ = -Math.sin(yawRad);
        var forwardX = Math.sin(yawRad);
        var forwardZ = Math.cos(yawRad);
        root.target = Qt.vector3d(root.target.x - panDx * rightX - panDy * forwardX, root.target.y, root.target.z - panDx * rightZ - panDy * forwardZ);
        internal.lastPos = Qt.point(touchPoints[0].x, touchPoints[0].y);
        internal.lastPos2 = Qt.point(touchPoints[1].x, touchPoints[1].y);
        internal.lastPinchDistance = currentDistance;
        updateCameraPosition();
      }
    }

    onReleased: function (touchPoints) {
      if (touchPoints.length === 0) {
        internal.isPanning = false;
        internal.touchCount = 0;
      } else {
        internal.touchCount = touchPoints.length;
        if (touchPoints.length === 1) {
          internal.lastPos = Qt.point(touchPoints[0].x, touchPoints[0].y);
          internal.isPanning = false;
        }
      }
    }

    // Double tap to reset
    onTouchUpdated:
    // Handled by TapHandler below
    {
    }
  }

  // Double tap handler
  TapHandler {
    id: doubleTapHandler
    acceptedButtons: Qt.LeftButton
    gesturePolicy: TapHandler.WithinBounds

    onDoubleTapped: {
      resetView();
    }
  }

  // Mouse wheel zoom (for desktop)
  WheelHandler {
    id: wheelHandler
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

    onWheel: function (event) {
      var zoomDelta = event.angleDelta.y * 0.5;
      root.distance = Math.max(root.minDistance, Math.min(root.maxDistance, root.distance - zoomDelta));
      updateCameraPosition();
    }
  }

  // Helper function
  function calculateDistance(x1, y1, x2, y2) {
    var dx = x2 - x1;
    var dy = y2 - y1;
    return Math.sqrt(dx * dx + dy * dy);
  }
}
