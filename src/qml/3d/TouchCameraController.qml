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
 *
 * Features:
 * - Inertia/momentum for smooth feel
 * - Pitch limits to prevent going underground
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
  property real minPitch: 5     // Minimum 5° above horizon (can't go underground!)
  property real maxPitch: 89    // Maximum 89° (almost top-down)

  // Sensitivity
  property real orbitSensitivity: 0.3
  property real panSensitivity: 1.0
  property real zoomSensitivity: 0.005

  // Inertia settings
  property real inertiaDecay: 0.95      // How fast inertia slows down (0.9-0.98), higher = longer
  property real minInertiaVelocity: 0.05 // Stop inertia below this velocity

  // Current camera state (spherical coordinates)
  property real distance: 800
  property real yaw: 0      // horizontal angle (degrees)
  property real pitch: 40   // vertical angle (degrees) - positive = above target

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

    // Inertia velocities
    property real velocityYaw: 0
    property real velocityPitch: 0
    property real velocityZoom: 0
    property bool inertiaActive: false

    // For velocity calculation
    property real lastDx: 0
    property real lastDy: 0
    property real lastTime: 0
  }

  Component.onCompleted: {
    updateCameraPosition();
  }

  // Inertia animation timer
  Timer {
    id: inertiaTimer
    interval: 16  // ~60fps
    repeat: true
    running: internal.inertiaActive

    onTriggered: {
      // Apply inertia velocities
      if (Math.abs(internal.velocityYaw) > root.minInertiaVelocity || Math.abs(internal.velocityPitch) > root.minInertiaVelocity) {
        root.yaw += internal.velocityYaw;
        root.pitch = Math.max(root.minPitch, Math.min(root.maxPitch, root.pitch + internal.velocityPitch));

        // Decay velocities
        internal.velocityYaw *= root.inertiaDecay;
        internal.velocityPitch *= root.inertiaDecay;
        updateCameraPosition();
      } else {
        // Stop inertia when velocity is too low
        internal.inertiaActive = false;
        internal.velocityYaw = 0;
        internal.velocityPitch = 0;
      }
    }
  }

  // Update camera position from spherical coordinates
  // pitch: positive = looking down from above, negative = looking up from below
  function updateCameraPosition() {
    if (!camera) {
      return;
    }
    // pitch of 45 means camera is 45 degrees above horizon looking down
    var elevationRad = pitch * Math.PI / 180;
    var yawRad = yaw * Math.PI / 180;
    var horizontalDist = distance * Math.cos(elevationRad);
    var x = target.x + horizontalDist * Math.sin(yawRad);
    var y = target.y + distance * Math.sin(elevationRad);  // Positive pitch = above target
    var z = target.z + horizontalDist * Math.cos(yawRad);
    camera.position = Qt.vector3d(x, y, z);
    camera.lookAt(target);
  }

  // Reset view to default (with smooth animation)
  function resetView() {
    // Stop inertia
    internal.inertiaActive = false;
    internal.velocityYaw = 0;
    internal.velocityPitch = 0;

    // Animate to default position
    resetAnimation.start();
  }

  // Smooth reset animation
  ParallelAnimation {
    id: resetAnimation

    NumberAnimation {
      target: root
      property: "yaw"
      to: 0
      duration: 300
      easing.type: Easing.OutCubic
    }
    NumberAnimation {
      target: root
      property: "pitch"
      to: 40
      duration: 300
      easing.type: Easing.OutCubic
    }
    NumberAnimation {
      target: root
      property: "distance"
      to: 2200
      duration: 300
      easing.type: Easing.OutCubic
    }

    onFinished: {
      target = Qt.vector3d(0, 100, 0);
      updateCameraPosition();
    }
  }

  // Update camera when animated properties change
  onYawChanged: if (resetAnimation.running)
    updateCameraPosition()
  onPitchChanged: if (resetAnimation.running)
    updateCameraPosition()
  onDistanceChanged: if (resetAnimation.running)
    updateCameraPosition()

  // Zoom to fit
  function zoomToFit(center, radius) {
    target = center;
    distance = radius * 2.5;
    updateCameraPosition();
  }

  // Multi-touch handler (for touch screens only, mouse handled by DragHandler)
  MultiPointTouchArea {
    id: touchArea
    anchors.fill: parent
    minimumTouchPoints: 1
    maximumTouchPoints: 2
    mouseEnabled: false  // Mouse handled by DragHandler for better inertia

    touchPoints: [
      TouchPoint {
        id: touch1
      },
      TouchPoint {
        id: touch2
      }
    ]

    onPressed: function (touchPoints) {
      // Stop any ongoing inertia
      internal.inertiaActive = false;
      internal.velocityYaw = 0;
      internal.velocityPitch = 0;
      internal.touchCount = touchPoints.length;
      if (touchPoints.length >= 1) {
        internal.lastPos = Qt.point(touchPoints[0].x, touchPoints[0].y);
        internal.lastTime = Date.now();
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

        // Calculate time delta for velocity
        var now = Date.now();
        var dt = Math.max(16, now - internal.lastTime);  // Min 16ms to avoid spikes

        // Store velocity for inertia (inverted for natural feel)
        internal.velocityYaw = (-dx * root.orbitSensitivity) * (16 / dt);
        internal.velocityPitch = (dy * root.orbitSensitivity) * (16 / dt);  // Inverted: drag up = look up

        // Apply rotation (inverted for natural drag direction)
        root.yaw -= dx * root.orbitSensitivity;
        root.pitch = Math.max(root.minPitch, Math.min(root.maxPitch, root.pitch + dy * root.orbitSensitivity));
        internal.lastPos = Qt.point(touchPoints[0].x, touchPoints[0].y);
        internal.lastTime = now;
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
        // Start inertia when releasing single finger orbit
        var hasVelocity = Math.abs(internal.velocityYaw) > root.minInertiaVelocity || Math.abs(internal.velocityPitch) > root.minInertiaVelocity;
        if (!internal.isPanning && hasVelocity) {
          internal.inertiaActive = true;
        }
        internal.isPanning = false;
        internal.touchCount = 0;
      } else {
        internal.touchCount = touchPoints.length;
        if (touchPoints.length === 1) {
          internal.lastPos = Qt.point(touchPoints[0].x, touchPoints[0].y);
          internal.lastTime = Date.now();
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

  // Mouse drag handler for desktop (better inertia support)
  DragHandler {
    id: mouseDragHandler
    acceptedButtons: Qt.LeftButton
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

    property point lastPoint: Qt.point(0, 0)
    property real lastTime: 0

    onActiveChanged: {
      if (active) {
        // Drag started
        internal.inertiaActive = false;
        internal.velocityYaw = 0;
        internal.velocityPitch = 0;
        lastPoint = centroid.position;
        lastTime = Date.now();
      } else {
        // Drag ended - start inertia
        var hasVelocity = Math.abs(internal.velocityYaw) > root.minInertiaVelocity || Math.abs(internal.velocityPitch) > root.minInertiaVelocity;
        if (hasVelocity) {
          internal.inertiaActive = true;
        }
      }
    }

    onCentroidChanged: {
      if (!active)
        return;
      var dx = centroid.position.x - lastPoint.x;
      var dy = centroid.position.y - lastPoint.y;
      var now = Date.now();
      var dt = Math.max(16, now - lastTime);

      // Store velocity for inertia (both inverted for natural drag feel)
      internal.velocityYaw = (-dx * root.orbitSensitivity) * (16 / dt);
      internal.velocityPitch = (dy * root.orbitSensitivity) * (16 / dt);  // Inverted: drag up = look up

      // Apply rotation (inverted for natural feel)
      root.yaw -= dx * root.orbitSensitivity;
      root.pitch = Math.max(root.minPitch, Math.min(root.maxPitch, root.pitch + dy * root.orbitSensitivity));
      lastPoint = centroid.position;
      lastTime = now;
      updateCameraPosition();
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
