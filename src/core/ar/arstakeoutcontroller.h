#ifndef ARSTAKEOUTCONTROLLER_H
#define ARSTAKEOUTCONTROLLER_H

#include <QObject>
#include <QPointF>
#include <qqmlintegration.h>
#include <qgspoint.h>

class ArStakeoutController : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY( double bearing READ bearing WRITE setBearing NOTIFY bearingChanged )
    Q_PROPERTY( double deviceOrientation READ deviceOrientation WRITE setDeviceOrientation NOTIFY deviceOrientationChanged )
    Q_PROPERTY( double devicePitch READ devicePitch WRITE setDevicePitch NOTIFY devicePitchChanged )
    Q_PROPERTY( double cameraHorizontalFov READ cameraHorizontalFov WRITE setCameraHorizontalFov NOTIFY cameraHorizontalFovChanged )
    Q_PROPERTY( double cameraVerticalFov READ cameraVerticalFov WRITE setCameraVerticalFov NOTIFY cameraVerticalFovChanged )
    Q_PROPERTY( double distance READ distance WRITE setDistance NOTIFY distanceChanged )
    Q_PROPERTY( QPointF markerPosition READ markerPosition NOTIFY markerPositionChanged )
    Q_PROPERTY( bool isOnScreen READ isOnScreen NOTIFY isOnScreenChanged )
    Q_PROPERTY( double relativeBearing READ relativeBearing NOTIFY relativeBearingChanged )
    Q_PROPERTY( double proximityLevel READ proximityLevel NOTIFY proximityLevelChanged )
    Q_PROPERTY( double proximityThreshold READ proximityThreshold WRITE setProximityThreshold NOTIFY proximityThresholdChanged )

  public:
    explicit ArStakeoutController( QObject *parent = nullptr );

    double bearing() const;
    void setBearing( double bearing );

    double deviceOrientation() const;
    void setDeviceOrientation( double orientation );

    double devicePitch() const;
    void setDevicePitch( double pitch );

    double cameraHorizontalFov() const;
    void setCameraHorizontalFov( double fov );

    double cameraVerticalFov() const;
    void setCameraVerticalFov( double fov );

    double distance() const;
    void setDistance( double distance );

    double proximityThreshold() const;
    void setProximityThreshold( double threshold );

    QPointF markerPosition() const;
    bool isOnScreen() const;
    double relativeBearing() const;
    double proximityLevel() const;

  signals:
    void bearingChanged();
    void deviceOrientationChanged();
    void devicePitchChanged();
    void cameraHorizontalFovChanged();
    void cameraVerticalFovChanged();
    void distanceChanged();
    void proximityThresholdChanged();
    void markerPositionChanged();
    void isOnScreenChanged();
    void relativeBearingChanged();
    void proximityLevelChanged();

  private:
    void updateMarkerPosition();

    double mBearing = std::numeric_limits<double>::quiet_NaN();
    double mDeviceOrientation = std::numeric_limits<double>::quiet_NaN();
    double mDevicePitch = 0.0;
    double mCameraHorizontalFov = 60.0;
    double mCameraVerticalFov = 45.0;
    double mDistance = std::numeric_limits<double>::quiet_NaN();
    double mProximityThreshold = 1.0;

    QPointF mMarkerPosition;
    bool mIsOnScreen = false;
    double mRelativeBearing = 0.0;
    double mProximityLevel = 0.0;
};

#endif // ARSTAKEOUTCONTROLLER_H
