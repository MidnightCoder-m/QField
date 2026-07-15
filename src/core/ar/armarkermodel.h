/***************************************************************************
  armarkermodel.h - ArMarkerModel

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

#ifndef ARMARKERMODEL_H
#define ARMARKERMODEL_H

#include "arattitudeestimator.h"
#include "positioning.h"

#include <QAbstractListModel>
#include <QElapsedTimer>
#include <QPointF>
#include <QSizeF>
#include <qgscoordinatereferencesystem.h>
#include <qgsdistancearea.h>
#include <qgsfeatureid.h>
#include <qgspointxy.h>
#include <qgsproject.h>

#include <limits>

/**
 * Provides markers for the features nearest to the device position, projected
 * onto the camera viewport for augmented reality rendering.
 *
 * The model gathers candidate features from the project's visible vector
 * layers, transforms them to WGS84 and measures azimuth and distance on the
 * ellipsoid. Screen positions are computed from the filtered device attitude
 * and a smoothed device position in a single per-frame update path driven by
 * advanceFrame().
 * \ingroup core
 */
class ArMarkerModel : public QAbstractListModel
{
    Q_OBJECT

    Q_PROPERTY( bool active READ active WRITE setActive NOTIFY activeChanged )
    Q_PROPERTY( Positioning *positioningSource READ positioningSource WRITE setPositioningSource NOTIFY positioningSourceChanged )
    Q_PROPERTY( QgsProject *project READ project WRITE setProject NOTIFY projectChanged )
    Q_PROPERTY( QSizeF viewportSize READ viewportSize WRITE setViewportSize NOTIFY viewportSizeChanged )
    Q_PROPERTY( double horizontalFieldOfView READ horizontalFieldOfView WRITE setHorizontalFieldOfView NOTIFY horizontalFieldOfViewChanged )
    Q_PROPERTY( int maximumMarkerCount READ maximumMarkerCount WRITE setMaximumMarkerCount NOTIFY maximumMarkerCountChanged )
    Q_PROPERTY( double maximumMarkerDistance READ maximumMarkerDistance WRITE setMaximumMarkerDistance NOTIFY maximumMarkerDistanceChanged )
    Q_PROPERTY( bool attitudeAvailable READ attitudeAvailable NOTIFY attitudeAvailableChanged )
    Q_PROPERTY( bool positionAvailable READ positionAvailable NOTIFY positionAvailableChanged )
    Q_PROPERTY( double currentHeading READ currentHeading NOTIFY currentHeadingChanged )
    Q_PROPERTY( int count READ count NOTIFY countChanged )

  public:
    enum Role
    {
      DisplayNameRole = Qt::UserRole + 1,
      DistanceRole,
      DistanceTextRole,
      ScreenPositionRole,
      WithinViewRole,
      FeatureIdRole,
      LayerIdRole,
    };

    explicit ArMarkerModel( QObject *parent = nullptr );

    int rowCount( const QModelIndex &parent = QModelIndex() ) const override;
    QVariant data( const QModelIndex &index, int role = Qt::DisplayRole ) const override;
    QHash<int, QByteArray> roleNames() const override;

    /**
     * Returns TRUE when the model is actively tracking sensors and features.
     */
    bool active() const { return mActive; }

    /**
     * Sets whether the model actively tracks sensors and features.
     */
    void setActive( bool active );

    /**
     * Returns the positioning source used to obtain the device position.
     */
    Positioning *positioningSource() const { return mPositioningSource; }

    /**
     * Sets the positioning source used to obtain the device position.
     */
    void setPositioningSource( Positioning *positioningSource );

    /**
     * Returns the project from which visible vector layer features are gathered.
     */
    QgsProject *project() const { return mProject; }

    /**
     * Sets the project from which visible vector layer features are gathered.
     */
    void setProject( QgsProject *project );

    /**
     * Returns the size of the viewport markers are projected onto, in pixels.
     */
    QSizeF viewportSize() const { return mViewportSize; }

    /**
     * Sets the size of the viewport markers are projected onto, in pixels.
     */
    void setViewportSize( const QSizeF &viewportSize );

    /**
     * Returns the camera field of view across the viewport width, in degrees.
     */
    double horizontalFieldOfView() const { return mHorizontalFieldOfView; }

    /**
     * Sets the camera field of view across the viewport width, in degrees.
     */
    void setHorizontalFieldOfView( double horizontalFieldOfView );

    /**
     * Returns the maximum number of nearest features shown as markers.
     */
    int maximumMarkerCount() const { return mMaximumMarkerCount; }

    /**
     * Sets the maximum number of nearest features shown as markers.
     */
    void setMaximumMarkerCount( int maximumMarkerCount );

    /**
     * Returns the radius within which features are gathered, in meters.
     */
    double maximumMarkerDistance() const { return mMaximumMarkerDistance; }

    /**
     * Sets the radius within which features are gathered, in meters.
     */
    void setMaximumMarkerDistance( double maximumMarkerDistance );

    /**
     * Returns TRUE when a usable attitude sensor combination is present.
     */
    bool attitudeAvailable() const { return mAttitudeEstimator.available(); }

    /**
     * Returns TRUE once a valid device position has been received.
     */
    bool positionAvailable() const { return mPositionAvailable; }

    /**
     * Returns the filtered heading of the camera view in degrees from north,
     * or NaN while unknown.
     */
    double currentHeading() const { return mCurrentHeading; }

    /**
     * Returns the number of markers.
     */
    int count() const { return mMarkers.size(); }

    /**
     * Advances sensors filtering, position smoothing and marker projection.
     * This is the single update path, meant to be called once per rendered
     * frame while the model is active.
     */
    Q_INVOKABLE void advanceFrame();

    /**
     * Requests a fresh gathering of nearby features on the next frame.
     */
    Q_INVOKABLE void refreshFeatures();

  signals:
    void activeChanged();
    void positioningSourceChanged();
    void projectChanged();
    void viewportSizeChanged();
    void horizontalFieldOfViewChanged();
    void maximumMarkerCountChanged();
    void maximumMarkerDistanceChanged();
    void attitudeAvailableChanged();
    void positionAvailableChanged();
    void currentHeadingChanged();
    void countChanged();

  private slots:
    void updateTargetPositionFromSource();

  private:
    struct Marker
    {
        QgsFeatureId featureId = FID_NULL;
        QString layerId;
        QString displayName;
        QgsPointXY positionWgs84;
        double elevation = std::numeric_limits<double>::quiet_NaN();
        double distance = 0.0;
        QString distanceText;
        QPointF screenPosition;
        bool withinView = false;
    };

    void setPositionAvailable( bool positionAvailable );
    void updateSmoothedPosition( double deltaSeconds );
    void gatherFeaturesWhenDue( qint64 elapsedMilliseconds );
    void gatherFeatures();
    void projectMarkers();
    void updateDistanceLabels();
    void updateCurrentHeading();
    void hideAllMarkers();
    static void screenAxesForRotation( int rotationAngle, QVector3D &deviceRight, QVector3D &deviceUp );

    bool mActive = false;
    Positioning *mPositioningSource = nullptr;
    QgsProject *mProject = nullptr;
    QSizeF mViewportSize;
    double mHorizontalFieldOfView = 60.0;
    int mMaximumMarkerCount = 10;
    double mMaximumMarkerDistance = 1000.0;

    ArAttitudeEstimator mAttitudeEstimator;
    QgsCoordinateReferenceSystem mWgs84;
    QgsDistanceArea mDistanceArea;

    QList<Marker> mMarkers;

    bool mHasTargetPosition = false;
    QgsPointXY mTargetPosition;
    double mTargetElevation = std::numeric_limits<double>::quiet_NaN();
    bool mPositionAvailable = false;
    QgsPointXY mSmoothedPosition;
    double mSmoothedElevation = std::numeric_limits<double>::quiet_NaN();
    double mMagneticDeclination = 0.0;
    double mCurrentHeading = std::numeric_limits<double>::quiet_NaN();

    bool mFeaturesDirty = false;
    bool mHasGatherPosition = false;
    QgsPointXY mLastGatherPosition;
    qint64 mLastGatherMilliseconds = -1;
    qint64 mLastFrameMilliseconds = -1;
    qint64 mLastLabelUpdateMilliseconds = -1;
    QElapsedTimer mClock;

    //! Smoothing time constant applied to device position updates, in seconds
    static constexpr double PositionSmoothingTimeConstant = 1.25;
    //! Position jumps larger than this value snap instead of glide, in meters
    static constexpr double PositionSnapDistance = 25.0;
    //! Movement after which nearby features are gathered again, in meters
    static constexpr double FeatureRegatherDistance = 20.0;
    //! Shortest interval between two feature gatherings, in milliseconds
    static constexpr qint64 MinimumGatherInterval = 3000;
    //! Interval between distance label updates, keeping labels calm, in milliseconds
    static constexpr qint64 LabelUpdateInterval = 500;
    //! Forward component under which a marker counts as behind the camera, cos(85°)
    static constexpr double MinimumForwardComponent = 0.087;
    //! Margin around the viewport within which markers are still laid out, in pixels
    static constexpr double OffscreenCullMargin = 100.0;
    //! Heading changes below this value do not notify, in degrees
    static constexpr double CurrentHeadingChangeThreshold = 1.0;
    //! Largest time step processed in one frame, protecting against paused frames, in seconds
    static constexpr double MaximumFrameInterval = 0.25;
};

#endif // ARMARKERMODEL_H
