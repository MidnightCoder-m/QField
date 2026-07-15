/***************************************************************************
  armarkermodel.cpp - ArMarkerModel

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

#include "armarkermodel.h"
#include "featureutils.h"
#include "positioning.h"

#include <QGuiApplication>
#include <QScreen>
#include <QtMath>
#include <qgsexception.h>
#include <qgsfeatureiterator.h>
#include <qgsfeaturerequest.h>
#include <qgsgeometry.h>
#include <qgslayertree.h>
#include <qgslayertreelayer.h>
#include <qgspoint.h>
#include <qgsproject.h>
#include <qgsvectorlayer.h>
#include <queue>

#include <algorithm>
#include <cmath>

namespace
{
  QString formattedDistance( double distance )
  {
    return QgsDistanceArea::formatDistance( distance, distance >= 1000.0 ? 1 : 0, Qgis::DistanceUnit::Meters );
  }

  double azimuthOfDirection( const QVector3D &direction )
  {
    const double east = direction.x();
    const double north = direction.y();
    if ( std::hypot( east, north ) < 0.05 )
      return std::numeric_limits<double>::quiet_NaN();

    return std::fmod( qRadiansToDegrees( std::atan2( east, north ) ) + 360.0, 360.0 );
  }
} //namespace

ArMarkerModel::ArMarkerModel( QObject *parent )
  : QAbstractListModel( parent )
  , mWgs84( QStringLiteral( "EPSG:4326" ) )
{
  mClock.start();
  connect( &mAttitudeEstimator, &ArAttitudeEstimator::availableChanged, this, &ArMarkerModel::attitudeAvailableChanged );
}

int ArMarkerModel::rowCount( const QModelIndex &parent ) const
{
  return parent.isValid() ? 0 : mMarkers.size();
}

QVariant ArMarkerModel::data( const QModelIndex &index, int role ) const
{
  if ( !index.isValid() || index.row() < 0 || index.row() >= mMarkers.size() )
    return QVariant();

  const Marker &marker = mMarkers.at( index.row() );
  switch ( role )
  {
    case DisplayNameRole:
      return marker.displayName;
    case DistanceRole:
      return marker.distance;
    case DistanceTextRole:
      return marker.distanceText;
    case ScreenPositionRole:
      return marker.screenPosition;
    case WithinViewRole:
      return marker.withinView;
    case FeatureIdRole:
      return marker.featureId;
    case LayerIdRole:
      return marker.layerId;
  }

  return QVariant();
}

QHash<int, QByteArray> ArMarkerModel::roleNames() const
{
  return {
    { DisplayNameRole, "displayName" },
    { DistanceRole, "distanceMeters" },
    { DistanceTextRole, "distanceText" },
    { ScreenPositionRole, "screenPosition" },
    { WithinViewRole, "withinView" },
    { FeatureIdRole, "featureId" },
    { LayerIdRole, "layerId" },
  };
}

void ArMarkerModel::setActive( bool active )
{
  if ( mActive == active )
    return;

  mActive = active;
  mAttitudeEstimator.setActive( active );
  mLastFrameMilliseconds = -1;

  if ( mActive )
  {
    setPositionAvailable( false );
    updateTargetPositionFromSource();
    mFeaturesDirty = true;
  }
  else
  {
    hideAllMarkers();
  }

  emit activeChanged();
}

void ArMarkerModel::setPositioningSource( Positioning *positioningSource )
{
  if ( mPositioningSource == positioningSource )
    return;

  if ( mPositioningSource )
  {
    disconnect( mPositioningSource, &Positioning::positionInformationChanged, this, &ArMarkerModel::updateTargetPositionFromSource );
  }

  mPositioningSource = positioningSource;

  if ( mPositioningSource )
  {
    connect( mPositioningSource, &Positioning::positionInformationChanged, this, &ArMarkerModel::updateTargetPositionFromSource );
  }

  mHasTargetPosition = false;
  setPositionAvailable( false );
  updateTargetPositionFromSource();
  emit positioningSourceChanged();
}

void ArMarkerModel::setProject( QgsProject *project )
{
  if ( mProject == project )
    return;

  if ( mProject )
  {
    disconnect( mProject, nullptr, this, nullptr );
    disconnect( mProject->layerTreeRoot(), nullptr, this, nullptr );
  }

  mProject = project;

  if ( mProject )
  {
    mDistanceArea.setSourceCrs( mWgs84, mProject->transformContext() );
    mDistanceArea.setEllipsoid( QStringLiteral( "WGS84" ) );

    connect( mProject, &QgsProject::transformContextChanged, this, [this] {
      mDistanceArea.setSourceCrs( mWgs84, mProject->transformContext() );
    } );
    connect( mProject, &QgsProject::layersAdded, this, [this] { mFeaturesDirty = true; } );
    connect( mProject, &QgsProject::layersRemoved, this, [this] { mFeaturesDirty = true; } );
    connect( mProject->layerTreeRoot(), &QgsLayerTreeNode::visibilityChanged, this, [this] { mFeaturesDirty = true; } );
  }

  mFeaturesDirty = true;
  emit projectChanged();
}

void ArMarkerModel::setViewportSize( const QSizeF &viewportSize )
{
  if ( mViewportSize == viewportSize )
    return;

  mViewportSize = viewportSize;
  emit viewportSizeChanged();
}

void ArMarkerModel::setHorizontalFieldOfView( double horizontalFieldOfView )
{
  if ( mHorizontalFieldOfView == horizontalFieldOfView )
    return;

  mHorizontalFieldOfView = horizontalFieldOfView;
  emit horizontalFieldOfViewChanged();
}

void ArMarkerModel::setMaximumMarkerCount( int maximumMarkerCount )
{
  if ( mMaximumMarkerCount == maximumMarkerCount )
    return;

  mMaximumMarkerCount = maximumMarkerCount;
  mFeaturesDirty = true;
  emit maximumMarkerCountChanged();
}

void ArMarkerModel::setMaximumMarkerDistance( double maximumMarkerDistance )
{
  if ( mMaximumMarkerDistance == maximumMarkerDistance )
    return;

  mMaximumMarkerDistance = maximumMarkerDistance;
  mFeaturesDirty = true;
  emit maximumMarkerDistanceChanged();
}

void ArMarkerModel::advanceFrame()
{
  if ( !mActive )
    return;

  const qint64 now = mClock.elapsed();
  double deltaSeconds = mLastFrameMilliseconds < 0 ? 1.0 / 60.0 : ( now - mLastFrameMilliseconds ) / 1000.0;
  mLastFrameMilliseconds = now;
  deltaSeconds = std::clamp( deltaSeconds, 0.0, MaximumFrameInterval );

  mAttitudeEstimator.advance( deltaSeconds );
  updateSmoothedPosition( deltaSeconds );
  gatherFeaturesWhenDue( now );
  projectMarkers();

  if ( mLastLabelUpdateMilliseconds < 0 || now - mLastLabelUpdateMilliseconds >= LabelUpdateInterval )
  {
    mLastLabelUpdateMilliseconds = now;
    updateDistanceLabels();
  }

  updateCurrentHeading();
}

void ArMarkerModel::refreshFeatures()
{
  mFeaturesDirty = true;
}

void ArMarkerModel::updateTargetPositionFromSource()
{
  if ( !mPositioningSource )
    return;

  const GnssPositionInformation positionInformation = mPositioningSource->positionInformation();
  if ( !positionInformation.latitudeValid() || !positionInformation.longitudeValid() )
    return;

  mTargetPosition = QgsPointXY( positionInformation.longitude(), positionInformation.latitude() );
  mTargetElevation = positionInformation.elevationValid() ? positionInformation.elevation() : std::numeric_limits<double>::quiet_NaN();
  mHasTargetPosition = true;

  if ( !std::isnan( positionInformation.magneticVariation() ) )
  {
    mMagneticDeclination = positionInformation.magneticVariation();
  }
}

void ArMarkerModel::setPositionAvailable( bool positionAvailable )
{
  if ( mPositionAvailable == positionAvailable )
    return;

  mPositionAvailable = positionAvailable;
  emit positionAvailableChanged();
}

void ArMarkerModel::updateSmoothedPosition( double deltaSeconds )
{
  if ( !mHasTargetPosition )
    return;

  if ( !mPositionAvailable )
  {
    mSmoothedPosition = mTargetPosition;
    mSmoothedElevation = mTargetElevation;
    setPositionAvailable( true );
    mFeaturesDirty = true;
    return;
  }

  // Longitude deltas across the antimeridian cannot be interpolated
  bool snap = std::abs( mTargetPosition.x() - mSmoothedPosition.x() ) > 180.0;
  if ( !snap )
  {
    try
    {
      snap = mDistanceArea.measureLine( mSmoothedPosition, mTargetPosition ) > PositionSnapDistance;
    }
    catch ( const QgsCsException & )
    {
      snap = true;
    }
  }

  if ( snap )
  {
    mSmoothedPosition = mTargetPosition;
    mSmoothedElevation = mTargetElevation;
    return;
  }

  const double interpolationFactor = 1.0 - std::exp( -deltaSeconds / PositionSmoothingTimeConstant );
  mSmoothedPosition.setX( mSmoothedPosition.x() + ( mTargetPosition.x() - mSmoothedPosition.x() ) * interpolationFactor );
  mSmoothedPosition.setY( mSmoothedPosition.y() + ( mTargetPosition.y() - mSmoothedPosition.y() ) * interpolationFactor );

  if ( std::isnan( mTargetElevation ) || std::isnan( mSmoothedElevation ) )
  {
    mSmoothedElevation = mTargetElevation;
  }
  else
  {
    mSmoothedElevation += ( mTargetElevation - mSmoothedElevation ) * interpolationFactor;
  }
}

void ArMarkerModel::gatherFeaturesWhenDue( qint64 elapsedMilliseconds )
{
  if ( !mPositionAvailable || !mProject )
    return;

  if ( !mFeaturesDirty && mHasGatherPosition )
  {
    bool movedFar = false;
    try
    {
      movedFar = mDistanceArea.measureLine( mLastGatherPosition, mSmoothedPosition ) > FeatureRegatherDistance;
    }
    catch ( const QgsCsException & )
    {
      movedFar = true;
    }
    if ( !movedFar )
      return;
  }

  if ( mLastGatherMilliseconds >= 0 && elapsedMilliseconds - mLastGatherMilliseconds < MinimumGatherInterval )
    return;

  mLastGatherMilliseconds = elapsedMilliseconds;
  gatherFeatures();
}

void ArMarkerModel::gatherFeatures()
{
  mFeaturesDirty = false;

  struct Candidate
  {
      QgsVectorLayer *layer = nullptr;
      QgsFeatureId featureId = FID_NULL;
      QgsPointXY position;
      double elevation = std::numeric_limits<double>::quiet_NaN();
      double distance = 0.0;
  };

  const auto nearerThan = []( const Candidate &first, const Candidate &second ) { return first.distance < second.distance; };
  std::priority_queue<Candidate, std::vector<Candidate>, decltype( nearerThan )> nearestCandidates( nearerThan );

  // Search extent in degrees around the device position, wide enough to hold
  // the maximum marker distance
  const double latitudeRadius = mMaximumMarkerDistance / 111320.0;
  const double longitudeRadius = latitudeRadius / std::max( std::cos( qDegreesToRadians( mSmoothedPosition.y() ) ), 0.01 );
  const QgsRectangle searchExtent( mSmoothedPosition.x() - longitudeRadius, mSmoothedPosition.y() - latitudeRadius, mSmoothedPosition.x() + longitudeRadius, mSmoothedPosition.y() + latitudeRadius );

  const QList<QgsLayerTreeLayer *> layerNodes = mProject->layerTreeRoot()->findLayers();
  for ( QgsLayerTreeLayer *layerNode : layerNodes )
  {
    if ( !layerNode->isVisible() )
      continue;

    QgsVectorLayer *layer = qobject_cast<QgsVectorLayer *>( layerNode->layer() );
    if ( !layer || !layer->isValid() || !layer->isSpatial() )
      continue;

    QgsFeatureRequest request;
    request.setDestinationCrs( mWgs84, mProject->transformContext() );
    request.setFilterRect( searchExtent );
    request.setNoAttributes();

    QgsFeatureIterator iterator = layer->getFeatures( request );
    QgsFeature feature;
    while ( iterator.nextFeature( feature ) )
    {
      const QgsGeometry geometry = feature.geometry();
      if ( geometry.isNull() || geometry.isEmpty() )
        continue;

      Candidate candidate;
      candidate.layer = layer;
      candidate.featureId = feature.id();

      if ( geometry.type() == Qgis::GeometryType::Point )
      {
        const QgsPoint vertex = geometry.vertexAt( 0 );
        candidate.position = QgsPointXY( vertex.x(), vertex.y() );
        candidate.elevation = vertex.z();
      }
      else
      {
        // A stable representative point; anchors such as the nearest vertex
        // would swap around while the device moves
        QgsGeometry anchor = geometry.pointOnSurface();
        if ( anchor.isNull() )
          anchor = geometry.centroid();
        if ( anchor.isNull() )
          continue;
        candidate.position = anchor.asPoint();
      }

      try
      {
        candidate.distance = mDistanceArea.measureLine( mSmoothedPosition, candidate.position );
      }
      catch ( const QgsCsException & )
      {
        continue;
      }

      if ( !std::isfinite( candidate.distance ) || candidate.distance > mMaximumMarkerDistance )
        continue;

      nearestCandidates.push( candidate );
      if ( static_cast<int>( nearestCandidates.size() ) > mMaximumMarkerCount )
      {
        nearestCandidates.pop();
      }
    }
  }

  QList<Marker> markers;
  markers.reserve( static_cast<int>( nearestCandidates.size() ) );
  while ( !nearestCandidates.empty() )
  {
    const Candidate candidate = nearestCandidates.top();
    nearestCandidates.pop();

    Marker marker;
    marker.featureId = candidate.featureId;
    marker.layerId = candidate.layer->id();
    marker.positionWgs84 = candidate.position;
    marker.elevation = candidate.elevation;
    marker.distance = candidate.distance;
    marker.distanceText = formattedDistance( candidate.distance );
    marker.displayName = FeatureUtils::displayName( candidate.layer, candidate.layer->getFeature( candidate.featureId ) );

    // The farthest candidate leaves the queue first
    markers.prepend( marker );
  }

  const int previousCount = mMarkers.size();
  beginResetModel();
  mMarkers = markers;
  endResetModel();

  if ( previousCount != mMarkers.size() )
  {
    emit countChanged();
  }

  mLastGatherPosition = mSmoothedPosition;
  mHasGatherPosition = true;
}

void ArMarkerModel::projectMarkers()
{
  if ( mMarkers.isEmpty() )
    return;

  const bool projectionReady = mPositionAvailable && mAttitudeEstimator.hasAttitude() && mViewportSize.width() > 0 && mViewportSize.height() > 0 && mHorizontalFieldOfView > 10.0 && mHorizontalFieldOfView < 170.0;
  if ( !projectionReady )
  {
    hideAllMarkers();
    return;
  }

  // Rotate the magnetic north referenced attitude into the true north frame
  const QQuaternion attitude = QQuaternion::fromAxisAndAngle( 0.0f, 0.0f, 1.0f, static_cast<float>( -mMagneticDeclination ) ) * mAttitudeEstimator.attitude();

  const QScreen *screen = QGuiApplication::primaryScreen();
  const int rotationAngle = screen ? screen->angleBetween( screen->nativeOrientation(), screen->orientation() ) : 0;
  QVector3D deviceRight;
  QVector3D deviceUp;
  screenAxesForRotation( rotationAngle, deviceRight, deviceUp );

  const QVector3D rightWorld = attitude.rotatedVector( deviceRight );
  const QVector3D upWorld = attitude.rotatedVector( deviceUp );
  // The back camera looks along the negative device z axis
  const QVector3D forwardWorld = attitude.rotatedVector( QVector3D( 0.0f, 0.0f, -1.0f ) );

  const double focalLength = ( mViewportSize.width() / 2.0 ) / std::tan( qDegreesToRadians( mHorizontalFieldOfView ) / 2.0 );
  const double centerX = mViewportSize.width() / 2.0;
  const double centerY = mViewportSize.height() / 2.0;

  for ( Marker &marker : mMarkers )
  {
    double azimuthDegrees = 0.0;
    try
    {
      marker.distance = mDistanceArea.measureLine( mSmoothedPosition, marker.positionWgs84 );
      azimuthDegrees = qRadiansToDegrees( mDistanceArea.bearing( mSmoothedPosition, marker.positionWgs84 ) );
    }
    catch ( const QgsCsException & )
    {
      marker.withinView = false;
      continue;
    }

    double elevationAngle = 0.0;
    if ( !std::isnan( mSmoothedElevation ) && !std::isnan( marker.elevation ) && marker.distance > 1.0 )
    {
      elevationAngle = std::atan2( marker.elevation - mSmoothedElevation, marker.distance );
    }

    const double azimuthRadians = qDegreesToRadians( azimuthDegrees );
    const QVector3D direction( static_cast<float>( std::sin( azimuthRadians ) * std::cos( elevationAngle ) ),
                               static_cast<float>( std::cos( azimuthRadians ) * std::cos( elevationAngle ) ),
                               static_cast<float>( std::sin( elevationAngle ) ) );

    const double forwardComponent = QVector3D::dotProduct( direction, forwardWorld );
    if ( forwardComponent < MinimumForwardComponent )
    {
      marker.withinView = false;
      continue;
    }

    const double x = centerX + focalLength * QVector3D::dotProduct( direction, rightWorld ) / forwardComponent;
    const double y = centerY - focalLength * QVector3D::dotProduct( direction, upWorld ) / forwardComponent;
    marker.screenPosition = QPointF( x, y );
    marker.withinView = x >= -OffscreenCullMargin && x <= mViewportSize.width() + OffscreenCullMargin && y >= -OffscreenCullMargin && y <= mViewportSize.height() + OffscreenCullMargin;
  }

  emit dataChanged( index( 0 ), index( mMarkers.size() - 1 ), { DistanceRole, ScreenPositionRole, WithinViewRole } );
}

void ArMarkerModel::updateDistanceLabels()
{
  if ( mMarkers.isEmpty() )
    return;

  bool changed = false;
  for ( Marker &marker : mMarkers )
  {
    const QString distanceText = formattedDistance( marker.distance );
    if ( distanceText != marker.distanceText )
    {
      marker.distanceText = distanceText;
      changed = true;
    }
  }

  if ( changed )
  {
    emit dataChanged( index( 0 ), index( mMarkers.size() - 1 ), { DistanceTextRole } );
  }
}

void ArMarkerModel::updateCurrentHeading()
{
  double heading = std::numeric_limits<double>::quiet_NaN();
  if ( mAttitudeEstimator.hasAttitude() )
  {
    const QQuaternion attitude = QQuaternion::fromAxisAndAngle( 0.0f, 0.0f, 1.0f, static_cast<float>( -mMagneticDeclination ) ) * mAttitudeEstimator.attitude();
    heading = azimuthOfDirection( attitude.rotatedVector( QVector3D( 0.0f, 0.0f, -1.0f ) ) );
    if ( std::isnan( heading ) )
    {
      // Camera pointing at the sky or the ground, fall back to the top axis
      heading = azimuthOfDirection( attitude.rotatedVector( QVector3D( 0.0f, 1.0f, 0.0f ) ) );
    }
  }

  if ( std::isnan( heading ) && std::isnan( mCurrentHeading ) )
    return;

  if ( !std::isnan( heading ) && !std::isnan( mCurrentHeading ) )
  {
    const double delta = std::abs( std::fmod( heading - mCurrentHeading + 540.0, 360.0 ) - 180.0 );
    if ( delta < CurrentHeadingChangeThreshold )
      return;
  }

  mCurrentHeading = heading;
  emit currentHeadingChanged();
}

void ArMarkerModel::hideAllMarkers()
{
  bool changed = false;
  for ( Marker &marker : mMarkers )
  {
    if ( marker.withinView )
    {
      marker.withinView = false;
      changed = true;
    }
  }

  if ( changed )
  {
    emit dataChanged( index( 0 ), index( mMarkers.size() - 1 ), { WithinViewRole } );
  }
}

void ArMarkerModel::screenAxesForRotation( int rotationAngle, QVector3D &deviceRight, QVector3D &deviceUp )
{
  // Sensor axes refer to the device natural orientation while the viewport
  // follows the user interface orientation. The angle between the native and
  // the current screen orientation selects the device axes matching the
  // viewport; should markers pan mirrored in landscape on some platform, the
  // 90 and 270 cases are to be swapped
  switch ( rotationAngle )
  {
    case 90:
      deviceRight = QVector3D( 0.0f, -1.0f, 0.0f );
      deviceUp = QVector3D( 1.0f, 0.0f, 0.0f );
      break;
    case 180:
      deviceRight = QVector3D( -1.0f, 0.0f, 0.0f );
      deviceUp = QVector3D( 0.0f, -1.0f, 0.0f );
      break;
    case 270:
      deviceRight = QVector3D( 0.0f, 1.0f, 0.0f );
      deviceUp = QVector3D( -1.0f, 0.0f, 0.0f );
      break;
    default:
      deviceRight = QVector3D( 1.0f, 0.0f, 0.0f );
      deviceUp = QVector3D( 0.0f, 1.0f, 0.0f );
      break;
  }
}
