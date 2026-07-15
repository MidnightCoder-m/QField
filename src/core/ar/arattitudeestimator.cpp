/***************************************************************************
  arattitudeestimator.cpp - ArAttitudeEstimator

 ---------------------
 begin                : 15.7.2026
 copyright            : (C) 2026 by Mohsen
 email                : mohsen@opengis.ch
 ***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/

#include "arattitudeestimator.h"

#include <QtMath>

#include <algorithm>
#include <cmath>
#include <limits>

ArAttitudeEstimator::ArAttitudeEstimator( QObject *parent )
  : QObject( parent )
{
}

void ArAttitudeEstimator::setActive( bool active )
{
  if ( mActive == active )
    return;

  mActive = active;

  mRotationSensor.stop();
  mGyroscope.stop();
  mAccelerometer.stop();
  mCompass.stop();

  mUseRotationSensor = false;
  mUseInertialFusion = false;
  mHasAttitude = false;
  mHasDisplayAttitude = false;
  mHasFilteredAcceleration = false;
  mFilteredRotationSpeed = 0.0;

  if ( !mActive )
  {
    setAvailable( false );
    return;
  }

  // A fused rotation sensor lacking the z angle (e.g. the generic backend
  // deriving tilt from the accelerometer alone) cannot provide a heading and
  // is not usable for augmented reality
  if ( mRotationSensor.connectToBackend() && mRotationSensor.hasZ() )
  {
    applyPreferredDataRate( &mRotationSensor );
    mUseRotationSensor = mRotationSensor.start();
  }

  if ( !mUseRotationSensor && mGyroscope.connectToBackend() && mAccelerometer.connectToBackend() && mCompass.connectToBackend() )
  {
    applyPreferredDataRate( &mGyroscope );
    applyPreferredDataRate( &mAccelerometer );
    mUseInertialFusion = mGyroscope.start() && mAccelerometer.start() && mCompass.start();
  }

  if ( !mUseRotationSensor && !mUseInertialFusion )
  {
    mRotationSensor.stop();
    mGyroscope.stop();
    mAccelerometer.stop();
    mCompass.stop();
  }

  setAvailable( mUseRotationSensor || mUseInertialFusion );
}

void ArAttitudeEstimator::setAvailable( bool available )
{
  if ( mAvailable == available )
    return;

  mAvailable = available;
  emit availableChanged();
}

void ArAttitudeEstimator::advance( double deltaSeconds )
{
  if ( !mActive || !mAvailable )
    return;

  const double interval = std::clamp( deltaSeconds, 0.0, MaximumFrameInterval );
  if ( mUseRotationSensor )
  {
    advanceFromRotationSensor( interval );
  }
  else
  {
    advanceFromInertialSensors( interval );
  }

  if ( !mHasAttitude )
    return;

  if ( !mHasDisplayAttitude )
  {
    mDisplayAttitude = mAttitude;
    mHasDisplayAttitude = true;
    return;
  }

  // Hold the displayed attitude still within the deadband so markers do not
  // oscillate while the device rests, and follow the estimate directly
  // otherwise; a gradual catch-up here would only add latency on top of the
  // already smoothed estimate
  if ( angularDistanceDegrees( mDisplayAttitude, mAttitude ) < AttitudeDeadbandDegrees )
    return;

  mDisplayAttitude = mAttitude;
}

void ArAttitudeEstimator::advanceFromRotationSensor( double deltaSeconds )
{
  QRotationReading *reading = mRotationSensor.reading();
  if ( !reading )
    return;

  const QQuaternion target = quaternionFromRotationReading( reading->x(), reading->y(), reading->z() );
  if ( !mHasAttitude )
  {
    mAttitude = target;
    mPreviousRotationTarget = target;
    mHasAttitude = true;
    return;
  }

  if ( deltaSeconds <= 0.0 )
    return;

  // Speed-adaptive smoothing: estimate how fast the device rotates and open
  // the filter cutoff accordingly, tracking motion without lag while staying
  // steady at rest
  const double rotationSpeed = angularDistanceDegrees( mPreviousRotationTarget, target ) / deltaSeconds;
  mPreviousRotationTarget = target;
  const double speedInterpolationFactor = 1.0 - std::exp( -2.0 * M_PI * SpeedEstimateCutoffFrequency * deltaSeconds );
  mFilteredRotationSpeed += ( rotationSpeed - mFilteredRotationSpeed ) * speedInterpolationFactor;

  const double cutoffFrequency = RestCutoffFrequency + CutoffSpeedCoefficient * mFilteredRotationSpeed;
  const float interpolationFactor = static_cast<float>( 1.0 - std::exp( -2.0 * M_PI * cutoffFrequency * deltaSeconds ) );
  mAttitude = QQuaternion::slerp( mAttitude, target, interpolationFactor );
}

void ArAttitudeEstimator::advanceFromInertialSensors( double deltaSeconds )
{
  updateFilteredAcceleration( deltaSeconds );

  if ( !mHasAttitude )
  {
    initializeFromGravityAndCompass();
    return;
  }

  integrateGyroscope( deltaSeconds );
  applyGravityCorrection( deltaSeconds );
  correctYawTowardsCompass( 1.0 - std::exp( -deltaSeconds / CompassCorrectionTimeConstant ) );
}

void ArAttitudeEstimator::updateFilteredAcceleration( double deltaSeconds )
{
  QAccelerometerReading *reading = mAccelerometer.reading();
  if ( !reading )
    return;

  const QVector3D acceleration( static_cast<float>( reading->x() ), static_cast<float>( reading->y() ), static_cast<float>( reading->z() ) );
  if ( !mHasFilteredAcceleration )
  {
    mFilteredAcceleration = acceleration;
    mHasFilteredAcceleration = true;
    return;
  }

  const float interpolationFactor = static_cast<float>( 1.0 - std::exp( -deltaSeconds / AccelerationSmoothingTimeConstant ) );
  mFilteredAcceleration += ( acceleration - mFilteredAcceleration ) * interpolationFactor;
}

void ArAttitudeEstimator::integrateGyroscope( double deltaSeconds )
{
  QGyroscopeReading *reading = mGyroscope.reading();
  if ( !reading )
    return;

  // Angular velocities are in degrees per second around the device axes
  const QVector3D angularVelocity( static_cast<float>( reading->x() ), static_cast<float>( reading->y() ), static_cast<float>( reading->z() ) );
  const float angle = angularVelocity.length() * static_cast<float>( deltaSeconds );
  if ( angle <= 0.0f )
    return;

  mAttitude = ( mAttitude * QQuaternion::fromAxisAndAngle( angularVelocity.normalized(), angle ) ).normalized();
}

void ArAttitudeEstimator::applyGravityCorrection( double deltaSeconds )
{
  if ( !mHasFilteredAcceleration )
    return;

  const float magnitude = mFilteredAcceleration.length();
  if ( magnitude <= 0.0f || std::abs( magnitude - StandardGravity ) > AccelerationMagnitudeGate )
    return;

  const QVector3D measuredUpWorld = mAttitude.rotatedVector( mFilteredAcceleration / magnitude );
  const QQuaternion correction = QQuaternion::rotationTo( measuredUpWorld, QVector3D( 0.0f, 0.0f, 1.0f ) );
  const float interpolationFactor = static_cast<float>( 1.0 - std::exp( -deltaSeconds / GravityCorrectionTimeConstant ) );
  mAttitude = ( QQuaternion::slerp( QQuaternion(), correction, interpolationFactor ) * mAttitude ).normalized();
}

void ArAttitudeEstimator::correctYawTowardsCompass( double fraction )
{
  QCompassReading *reading = mCompass.reading();
  if ( !reading )
    return;

  // The compass azimuth refers to the device top axis, degrees clockwise from
  // magnetic north. When the device is held upright that axis points at the
  // sky and platform backends effectively report the projected orientation, so
  // the camera axis is used as the yaw reference instead
  const QVector3D topAxisWorld = mAttitude.rotatedVector( QVector3D( 0.0f, 1.0f, 0.0f ) );
  const QVector3D yawReferenceWorld = std::abs( topAxisWorld.z() ) < UprightTopAxisLimit ? topAxisWorld : mAttitude.rotatedVector( QVector3D( 0.0f, 0.0f, -1.0f ) );
  const double estimatedAzimuth = azimuthDegrees( yawReferenceWorld );
  if ( std::isnan( estimatedAzimuth ) )
    return;

  const double error = std::fmod( reading->azimuth() - estimatedAzimuth + 540.0, 360.0 ) - 180.0;
  mAttitude = ( QQuaternion::fromAxisAndAngle( 0.0f, 0.0f, 1.0f, static_cast<float>( -error * fraction ) ) * mAttitude ).normalized();
}

void ArAttitudeEstimator::initializeFromGravityAndCompass()
{
  if ( !mHasFilteredAcceleration || !mCompass.reading() )
    return;

  const float magnitude = mFilteredAcceleration.length();
  if ( magnitude <= 0.0f )
    return;

  mAttitude = QQuaternion::rotationTo( mFilteredAcceleration / magnitude, QVector3D( 0.0f, 0.0f, 1.0f ) );
  mHasAttitude = true;
  correctYawTowardsCompass( 1.0 );
}

QQuaternion ArAttitudeEstimator::quaternionFromRotationReading( double x, double y, double z )
{
  // Qt Sensors rotation readings apply intrinsic rotations in the order z,
  // then x, then y, with z counter-clockwise from magnetic north
  return QQuaternion::fromAxisAndAngle( 0.0f, 0.0f, 1.0f, static_cast<float>( z ) )
         * QQuaternion::fromAxisAndAngle( 1.0f, 0.0f, 0.0f, static_cast<float>( x ) )
         * QQuaternion::fromAxisAndAngle( 0.0f, 1.0f, 0.0f, static_cast<float>( y ) );
}

double ArAttitudeEstimator::angularDistanceDegrees( const QQuaternion &first, const QQuaternion &second )
{
  const double dotProduct = std::clamp( static_cast<double>( std::abs( QQuaternion::dotProduct( first, second ) ) ), 0.0, 1.0 );
  return qRadiansToDegrees( 2.0 * std::acos( dotProduct ) );
}

double ArAttitudeEstimator::azimuthDegrees( const QVector3D &direction )
{
  const double east = direction.x();
  const double north = direction.y();
  if ( std::hypot( east, north ) < 0.05 )
    return std::numeric_limits<double>::quiet_NaN();

  return std::fmod( qRadiansToDegrees( std::atan2( east, north ) ) + 360.0, 360.0 );
}

void ArAttitudeEstimator::applyPreferredDataRate( QSensor *sensor )
{
  const qrangelist ranges = sensor->availableDataRates();
  if ( ranges.isEmpty() )
  {
    // Backends such as Android report no rates; without an explicit request
    // they fall back to the platform default, a mere 5 Hz on Android. The
    // backend clamps the requested rate to the hardware capabilities
    sensor->setDataRate( PreferredDataRate );
    return;
  }

  int bestRate = 0;
  for ( const qrange &range : ranges )
  {
    if ( PreferredDataRate >= range.first && PreferredDataRate <= range.second )
    {
      bestRate = PreferredDataRate;
      break;
    }
    if ( range.second < PreferredDataRate )
    {
      bestRate = std::max( bestRate, range.second );
    }
    else if ( bestRate == 0 )
    {
      bestRate = range.first;
    }
  }

  if ( bestRate > 0 )
  {
    sensor->setDataRate( bestRate );
  }
}
