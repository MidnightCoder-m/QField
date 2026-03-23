#include "arstakeoutcontroller.h"

#include <QtMath>

ArStakeoutController::ArStakeoutController( QObject *parent )
  : QObject( parent )
{
}

double ArStakeoutController::bearing() const
{
  return mBearing;
}

void ArStakeoutController::setBearing( double bearing )
{
  if ( qFuzzyCompare( mBearing, bearing ) || ( std::isnan( mBearing ) && std::isnan( bearing ) ) )
    return;

  mBearing = bearing;
  emit bearingChanged();
  updateMarkerPosition();
}

double ArStakeoutController::deviceOrientation() const
{
  return mDeviceOrientation;
}

void ArStakeoutController::setDeviceOrientation( double orientation )
{
  if ( qFuzzyCompare( mDeviceOrientation, orientation ) || ( std::isnan( mDeviceOrientation ) && std::isnan( orientation ) ) )
    return;

  mDeviceOrientation = orientation;
  emit deviceOrientationChanged();
  updateMarkerPosition();
}

double ArStakeoutController::devicePitch() const
{
  return mDevicePitch;
}

void ArStakeoutController::setDevicePitch( double pitch )
{
  if ( qFuzzyCompare( mDevicePitch, pitch ) )
    return;

  mDevicePitch = pitch;
  emit devicePitchChanged();
  updateMarkerPosition();
}

double ArStakeoutController::cameraHorizontalFov() const
{
  return mCameraHorizontalFov;
}

void ArStakeoutController::setCameraHorizontalFov( double fov )
{
  if ( qFuzzyCompare( mCameraHorizontalFov, fov ) )
    return;

  mCameraHorizontalFov = fov;
  emit cameraHorizontalFovChanged();
  updateMarkerPosition();
}

double ArStakeoutController::cameraVerticalFov() const
{
  return mCameraVerticalFov;
}

void ArStakeoutController::setCameraVerticalFov( double fov )
{
  if ( qFuzzyCompare( mCameraVerticalFov, fov ) )
    return;

  mCameraVerticalFov = fov;
  emit cameraVerticalFovChanged();
  updateMarkerPosition();
}

double ArStakeoutController::distance() const
{
  return mDistance;
}

void ArStakeoutController::setDistance( double distance )
{
  if ( qFuzzyCompare( mDistance, distance ) || ( std::isnan( mDistance ) && std::isnan( distance ) ) )
    return;

  mDistance = distance;
  emit distanceChanged();
  updateMarkerPosition();
}

double ArStakeoutController::proximityThreshold() const
{
  return mProximityThreshold;
}

void ArStakeoutController::setProximityThreshold( double threshold )
{
  if ( qFuzzyCompare( mProximityThreshold, threshold ) )
    return;

  mProximityThreshold = std::max( 0.1, threshold );
  emit proximityThresholdChanged();
  updateMarkerPosition();
}

QPointF ArStakeoutController::markerPosition() const
{
  return mMarkerPosition;
}

bool ArStakeoutController::isOnScreen() const
{
  return mIsOnScreen;
}

double ArStakeoutController::relativeBearing() const
{
  return mRelativeBearing;
}

double ArStakeoutController::proximityLevel() const
{
  return mProximityLevel;
}

void ArStakeoutController::updateMarkerPosition()
{
  if ( std::isnan( mBearing ) || std::isnan( mDeviceOrientation ) || std::isnan( mDistance ) )
  {
    const bool wasOnScreen = mIsOnScreen;
    mIsOnScreen = false;
    mMarkerPosition = QPointF( 0.5, 0.5 );
    mRelativeBearing = 0.0;
    mProximityLevel = 0.0;

    emit markerPositionChanged();
    emit relativeBearingChanged();
    emit proximityLevelChanged();
    if ( wasOnScreen )
      emit isOnScreenChanged();
    return;
  }

  double delta = mBearing - mDeviceOrientation;
  if ( delta > 180.0 )
    delta -= 360.0;
  else if ( delta < -180.0 )
    delta += 360.0;

  const double oldRelativeBearing = mRelativeBearing;
  mRelativeBearing = delta;

  const double halfHFov = mCameraHorizontalFov / 2.0;
  const double normalizedX = 0.5 + ( delta / ( 2.0 * halfHFov ) );

  const double halfVFov = mCameraVerticalFov / 2.0;
  const double normalizedY = 0.5 + ( mDevicePitch / ( 2.0 * halfVFov ) );

  const QPointF newPosition( qBound( 0.0, normalizedX, 1.0 ), qBound( 0.0, normalizedY, 1.0 ) );
  const bool newOnScreen = ( normalizedX >= 0.0 && normalizedX <= 1.0 && normalizedY >= 0.0 && normalizedY <= 1.0 );

  const double newProximity = qBound( 0.0, 1.0 - ( mDistance / mProximityThreshold ), 1.0 );

  const bool positionChanged = mMarkerPosition != newPosition;
  const bool onScreenChanged = mIsOnScreen != newOnScreen;
  const bool bearingDiffChanged = !qFuzzyCompare( oldRelativeBearing, mRelativeBearing );
  const bool proximityChanged = !qFuzzyCompare( mProximityLevel, newProximity );

  mMarkerPosition = newPosition;
  mIsOnScreen = newOnScreen;
  mProximityLevel = newProximity;

  if ( positionChanged )
    emit markerPositionChanged();
  if ( onScreenChanged )
    emit isOnScreenChanged();
  if ( bearingDiffChanged )
    emit relativeBearingChanged();
  if ( proximityChanged )
    emit proximityLevelChanged();
}
