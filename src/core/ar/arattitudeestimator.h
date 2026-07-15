/***************************************************************************
  arattitudeestimator.h - ArAttitudeEstimator

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

#ifndef ARATTITUDEESTIMATOR_H
#define ARATTITUDEESTIMATOR_H

#include <QAccelerometer>
#include <QCompass>
#include <QGyroscope>
#include <QObject>
#include <QQuaternion>
#include <QRotationSensor>
#include <QVector3D>

/**
 * Estimates the device attitude as a filtered quaternion rotating device frame
 * vectors into the local east-north-up frame, with north referring to magnetic
 * north. The device frame follows the Qt Sensors convention: x to the right of
 * the screen, y to the top of the screen, z out of the screen.
 *
 * When the platform offers a fused rotation sensor with an absolute z angle
 * (e.g. Android's rotation vector), readings are converted to quaternions and
 * smoothed through spherical interpolation. On platforms without such a
 * backend (e.g. iOS), the attitude is propagated by integrating the gyroscope
 * and slowly corrected towards gravity (accelerometer) and magnetic north
 * (compass), avoiding the jitter of orientations derived directly from
 * magnetometer and accelerometer readings.
 * \ingroup core
 */
class ArAttitudeEstimator : public QObject
{
    Q_OBJECT

  public:
    explicit ArAttitudeEstimator( QObject *parent = nullptr );

    /**
     * Starts or stops the underlying sensors.
     */
    void setActive( bool active );

    /**
     * Returns TRUE when the sensors are active.
     */
    bool active() const { return mActive; }

    /**
     * Returns TRUE when a usable attitude sensor combination is present.
     */
    bool available() const { return mAvailable; }

    /**
     * Returns TRUE once a first attitude has been estimated.
     */
    bool hasAttitude() const { return mHasAttitude; }

    /**
     * Returns the filtered attitude quaternion, rotating device frame vectors
     * into the east-north-up frame.
     */
    QQuaternion attitude() const { return mDisplayAttitude; }

    /**
     * Advances the estimation by \a deltaSeconds. This is the single update
     * path, meant to be called once per rendered frame.
     */
    void advance( double deltaSeconds );

  signals:
    void availableChanged();

  private:
    static QQuaternion quaternionFromRotationReading( double x, double y, double z );
    static double angularDistanceDegrees( const QQuaternion &first, const QQuaternion &second );
    static double azimuthDegrees( const QVector3D &direction );
    static void applyPreferredDataRate( QSensor *sensor );

    void setAvailable( bool available );
    void advanceFromRotationSensor( double deltaSeconds );
    void advanceFromInertialSensors( double deltaSeconds );
    void updateFilteredAcceleration( double deltaSeconds );
    void integrateGyroscope( double deltaSeconds );
    void applyGravityCorrection( double deltaSeconds );
    void correctYawTowardsCompass( double fraction );
    void initializeFromGravityAndCompass();

    bool mActive = false;
    bool mAvailable = false;
    bool mUseRotationSensor = false;
    bool mUseInertialFusion = false;

    QRotationSensor mRotationSensor;
    QGyroscope mGyroscope;
    QAccelerometer mAccelerometer;
    QCompass mCompass;

    bool mHasAttitude = false;
    QQuaternion mAttitude;
    bool mHasDisplayAttitude = false;
    QQuaternion mDisplayAttitude;
    bool mHasFilteredAcceleration = false;
    QVector3D mFilteredAcceleration;
    QQuaternion mPreviousRotationTarget;
    double mFilteredRotationSpeed = 0.0;

    //! Filter cutoff frequency while the device rests, in Hz; lower values smooth more but respond slower
    static constexpr double RestCutoffFrequency = 2.0;
    //! Cutoff frequency gained per degree/second of rotation speed, opening the filter during motion for lag-free tracking
    static constexpr double CutoffSpeedCoefficient = 0.6;
    //! Cutoff frequency of the rotation speed estimate, in Hz
    static constexpr double SpeedEstimateCutoffFrequency = 1.0;
    //! Angular deadband holding the displayed attitude still against sensor noise, in degrees
    static constexpr double AttitudeDeadbandDegrees = 0.1;
    //! Smoothing time constant applied to accelerometer readings, in seconds
    static constexpr double AccelerationSmoothingTimeConstant = 0.3;
    //! Time constant of the tilt correction towards measured gravity, in seconds
    static constexpr double GravityCorrectionTimeConstant = 2.5;
    //! Time constant of the yaw correction towards the compass azimuth, in seconds
    static constexpr double CompassCorrectionTimeConstant = 4.0;
    //! Acceleration magnitudes deviating from standard gravity beyond this value are considered motion and skipped, in m/s²
    static constexpr double AccelerationMagnitudeGate = 1.5;
    static constexpr double StandardGravity = 9.80665;
    //! Vertical component above which the device top axis is considered upright and unusable as a yaw reference
    static constexpr double UprightTopAxisLimit = 0.85;
    //! Largest time step integrated in one advance, protecting against paused frames, in seconds
    static constexpr double MaximumFrameInterval = 0.25;
    static constexpr int PreferredDataRate = 60;
};

#endif // ARATTITUDEESTIMATOR_H
