/***************************************************************************
  qgsquick3dterrainprovider.cpp - QgsQuick3DTerrainProvider

 ---------------------
 begin                : 5.1.2026
 copyright            : (C) 2026 by Mohsen
 email                : mohsen@example.com
 ***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/

#include "qgsquick3dterrainprovider.h"

#include <QDebug>
#include <qgscoordinatetransform.h>
#include <qgsmaplayer.h>
#include <qgsproject.h>
#include <qgsprojectelevationproperties.h>
#include <qgsprojectviewsettings.h>
#include <qgsrasterblock.h>
#include <qgsrasterdataprovider.h>
#include <qgsrasterlayer.h>
#include <qgsrectangle.h>
#include <qgsterrainprovider.h>

#include <cmath>
#include <limits>

QgsQuick3DTerrainProvider::QgsQuick3DTerrainProvider( QObject *parent )
  : QObject( parent )
{
}

QgsQuick3DTerrainProvider::~QgsQuick3DTerrainProvider() = default;

QgsProject *QgsQuick3DTerrainProvider::project() const
{
  return mProject;
}

void QgsQuick3DTerrainProvider::setProject( QgsProject *project )
{
  if ( mProject == project )
    return;

  mProject = project;
  emit projectChanged();

  updateTerrainProvider();
}

int QgsQuick3DTerrainProvider::resolution() const
{
  return mResolution;
}

void QgsQuick3DTerrainProvider::setResolution( int resolution )
{
  resolution = qBound( 8, resolution, 256 );
  if ( mResolution == resolution )
    return;

  mResolution = resolution;
  emit resolutionChanged();
}

double QgsQuick3DTerrainProvider::verticalExaggeration() const
{
  return mVerticalExaggeration;
}

void QgsQuick3DTerrainProvider::setVerticalExaggeration( double exaggeration )
{
  exaggeration = qBound( 0.1, exaggeration, 10.0 );
  if ( qFuzzyCompare( mVerticalExaggeration, exaggeration ) )
    return;

  mVerticalExaggeration = exaggeration;
  emit verticalExaggerationChanged();
}

bool QgsQuick3DTerrainProvider::hasTerrainData() const
{
  return mHasTerrainData;
}

QString QgsQuick3DTerrainProvider::terrainType() const
{
  return mTerrainType;
}

QRectF QgsQuick3DTerrainProvider::extent() const
{
  return mExtent;
}

void QgsQuick3DTerrainProvider::setExtent( const QRectF &extent )
{
  if ( mExtent == extent )
    return;

  mExtent = extent;
  emit extentChanged();
}

QRectF QgsQuick3DTerrainProvider::demExtent() const
{
  // Return DEM layer extent transformed to project CRS
  QgsRasterLayer *layer = mDemLayer ? mDemLayer : mFallbackDemLayer;
  if ( !layer )
    return QRectF();

  QgsRectangle layerExtent = layer->extent();

  // Transform to project CRS if needed
  if ( mProject && layer->crs() != mProject->crs() )
  {
    QgsCoordinateTransform transform( layer->crs(), mProject->crs(), mProject->transformContext() );
    try
    {
      layerExtent = transform.transformBoundingBox( layerExtent );
    }
    catch ( ... )
    {
      // Transform failed, return original
    }
  }

  // Make extent square (terrain mesh is square, texture should match)
  double width = layerExtent.width();
  double height = layerExtent.height();
  if ( width > height )
  {
    double diff = ( width - height ) / 2.0;
    layerExtent.setYMinimum( layerExtent.yMinimum() - diff );
    layerExtent.setYMaximum( layerExtent.yMaximum() + diff );
  }
  else if ( height > width )
  {
    double diff = ( height - width ) / 2.0;
    layerExtent.setXMinimum( layerExtent.xMinimum() - diff );
    layerExtent.setXMaximum( layerExtent.xMaximum() + diff );
  }

  return QRectF( layerExtent.xMinimum(), layerExtent.yMinimum(),
                 layerExtent.width(), layerExtent.height() );
}

double QgsQuick3DTerrainProvider::heightAt( double x, double y ) const
{
  if ( !mTerrainProvider )
    return 0.0;

  double height = mTerrainProvider->heightAt( x, y );

  // Handle NaN
  if ( std::isnan( height ) )
    return 0.0;

  return height * mVerticalExaggeration;
}

QVariantList QgsQuick3DTerrainProvider::sampleHeightGrid() const
{
  QVariantList heights;
  heights.reserve( mResolution * mResolution );

  if ( mExtent.isEmpty() )
  {
    for ( int i = 0; i < mResolution * mResolution; ++i )
    {
      heights.append( 0.0 );
    }
    return heights;
  }

  // Decide which layer to use for heights - prefer direct layer access with CRS transform
  QgsRasterLayer *layerToUse = nullptr;

  if ( mDemLayer && mDemLayer->isValid() )
  {
    layerToUse = mDemLayer;
  }
  else if ( mFallbackDemLayer && mFallbackDemLayer->isValid() )
  {
    layerToUse = mFallbackDemLayer;
  }

  if ( !layerToUse )
  {
    for ( int i = 0; i < mResolution * mResolution; ++i )
    {
      heights.append( 0.0 );
    }
    return heights;
  }

  const double xStep = mExtent.width() / ( mResolution - 1 );
  const double yStep = mExtent.height() / ( mResolution - 1 );

  double minH = std::numeric_limits<double>::max();
  double maxH = std::numeric_limits<double>::lowest();
  int validCount = 0;

  for ( int row = 0; row < mResolution; ++row )
  {
    const double y = mExtent.top() + row * yStep;
    for ( int col = 0; col < mResolution; ++col )
    {
      const double x = mExtent.left() + col * xStep;

      double height = sampleHeightFromRaster( layerToUse, x, y );

      // Handle NaN
      if ( std::isnan( height ) )
      {
        height = 0.0;
      }
      else if ( height != 0.0 )
      {
        validCount++;
        if ( height < minH )
          minH = height;
        if ( height > maxH )
          maxH = height;
      }

      heights.append( height * mVerticalExaggeration );
    }
  }

  // Only log summary once
  if ( validCount > 0 )
  {
    qDebug() << "3D TERRAIN: Sampled" << validCount << "valid heights, range:" << minH << "-" << maxH;
  }

  return heights;
}

QVariantMap QgsQuick3DTerrainProvider::terrainStats() const
{
  QVariantMap stats;

  if ( !mTerrainProvider || mExtent.isEmpty() )
  {
    stats[QStringLiteral( "minHeight" )] = 0.0;
    stats[QStringLiteral( "maxHeight" )] = 0.0;
    stats[QStringLiteral( "avgHeight" )] = 0.0;
    return stats;
  }

  double minH = std::numeric_limits<double>::max();
  double maxH = std::numeric_limits<double>::lowest();
  double sumH = 0.0;
  int count = 0;

  // Sample at lower resolution for stats
  const int sampleRes = qMin( 32, mResolution );
  const double xStep = mExtent.width() / ( sampleRes - 1 );
  const double yStep = mExtent.height() / ( sampleRes - 1 );

  for ( int row = 0; row < sampleRes; ++row )
  {
    const double y = mExtent.top() + row * yStep;
    for ( int col = 0; col < sampleRes; ++col )
    {
      const double x = mExtent.left() + col * xStep;
      double height = mTerrainProvider->heightAt( x, y );

      if ( !std::isnan( height ) )
      {
        height *= mVerticalExaggeration;
        minH = qMin( minH, height );
        maxH = qMax( maxH, height );
        sumH += height;
        count++;
      }
    }
  }

  if ( count > 0 )
  {
    stats[QStringLiteral( "minHeight" )] = minH;
    stats[QStringLiteral( "maxHeight" )] = maxH;
    stats[QStringLiteral( "avgHeight" )] = sumH / count;
  }
  else
  {
    stats[QStringLiteral( "minHeight" )] = 0.0;
    stats[QStringLiteral( "maxHeight" )] = 0.0;
    stats[QStringLiteral( "avgHeight" )] = 0.0;
  }

  return stats;
}

void QgsQuick3DTerrainProvider::refresh()
{
  updateTerrainProvider();
  emit terrainDataReady();
}

void QgsQuick3DTerrainProvider::updateTerrainProvider()
{
  mTerrainProvider = nullptr;
  mHasTerrainData = false;
  mTerrainType = QStringLiteral( "flat" );

  if ( !mProject )
  {
    emit hasTerrainDataChanged();
    emit terrainTypeChanged();
    return;
  }

  QgsProjectElevationProperties *elevProps = mProject->elevationProperties();
  if ( !elevProps )
  {
    emit hasTerrainDataChanged();
    emit terrainTypeChanged();
    return;
  }

  QgsAbstractTerrainProvider *provider = elevProps->terrainProvider();
  if ( !provider )
  {
    emit hasTerrainDataChanged();
    emit terrainTypeChanged();
    return;
  }

  mTerrainProvider = provider;
  mTerrainType = provider->type();

  // Check if we have actual terrain data (not just flat)
  mHasTerrainData = ( mTerrainType != QStringLiteral( "flat" ) );

  // If it's a raster DEM provider, get the layer
  if ( mTerrainType == QStringLiteral( "raster" ) )
  {
    QgsRasterDemTerrainProvider *rasterProvider = dynamic_cast<QgsRasterDemTerrainProvider *>( provider );
    if ( rasterProvider )
    {
      QgsRasterLayer *demLayer = rasterProvider->layer();
      if ( demLayer )
      {
        // Store the DEM layer for direct sampling with CRS transform
        mDemLayer = demLayer;

        qDebug() << "3D TERRAIN: DEM Layer:" << demLayer->name() << "CRS:" << demLayer->crs().authid();

        // Check data provider - if WMS, find a local DEM
        if ( demLayer->dataProvider() && demLayer->dataProvider()->name() == QStringLiteral( "wms" ) )
        {
          mFallbackDemLayer = findLocalDemLayer();
        }
      }
    }
  }

  // If extent not set, use project extent
  if ( mExtent.isEmpty() )
  {
    // Try to get full extent from project
    const QgsRectangle fullExtent = mProject->viewSettings()->fullExtent();
    if ( !fullExtent.isEmpty() )
    {
      mExtent = QRectF( fullExtent.xMinimum(), fullExtent.yMinimum(),
                        fullExtent.width(), fullExtent.height() );
      emit extentChanged();
    }
  }

  emit hasTerrainDataChanged();
  emit terrainTypeChanged();
  emit terrainDataReady();
}

QgsRasterLayer *QgsQuick3DTerrainProvider::findLocalDemLayer() const
{
  if ( !mProject )
    return nullptr;

  const QMap<QString, QgsMapLayer *> layers = mProject->mapLayers();

  // First pass: look for layers with "dem" or "elevation" in name
  for ( auto it = layers.begin(); it != layers.end(); ++it )
  {
    QgsMapLayer *layer = it.value();
    if ( layer->type() != Qgis::LayerType::Raster )
      continue;

    QgsRasterLayer *rasterLayer = qobject_cast<QgsRasterLayer *>( layer );
    if ( !rasterLayer || !rasterLayer->isValid() )
      continue;

    // Skip WMS/online layers
    if ( rasterLayer->dataProvider() && ( rasterLayer->dataProvider()->name() == QStringLiteral( "wms" ) || rasterLayer->dataProvider()->name() == QStringLiteral( "wmts" ) ) )
      continue;

    // Check if it's a single-band raster (typical for DEM)
    if ( rasterLayer->bandCount() != 1 )
      continue;

    QString name = rasterLayer->name().toLower();
    if ( name.contains( QStringLiteral( "dem" ) ) || name.contains( QStringLiteral( "dtm" ) ) || name.contains( QStringLiteral( "srtm" ) ) || name.contains( QStringLiteral( "elevation" ) ) || name.contains( QStringLiteral( "terrain" ) ) || name.contains( QStringLiteral( "height" ) ) )
    {
      return rasterLayer;
    }
  }

  // Second pass: any single-band local raster
  for ( auto it = layers.begin(); it != layers.end(); ++it )
  {
    QgsMapLayer *layer = it.value();
    if ( layer->type() != Qgis::LayerType::Raster )
      continue;

    QgsRasterLayer *rasterLayer = qobject_cast<QgsRasterLayer *>( layer );
    if ( !rasterLayer || !rasterLayer->isValid() )
      continue;

    // Skip WMS/online layers
    if ( rasterLayer->dataProvider() && ( rasterLayer->dataProvider()->name() == QStringLiteral( "wms" ) || rasterLayer->dataProvider()->name() == QStringLiteral( "wmts" ) ) )
      continue;

    if ( rasterLayer->bandCount() == 1 )
    {
      return rasterLayer;
    }
  }

  return nullptr;
}

double QgsQuick3DTerrainProvider::sampleHeightFromRaster( QgsRasterLayer *layer, double x, double y ) const
{
  static bool crsLogged = false;

  if ( !layer || !layer->dataProvider() )
    return 0.0;

  QgsRasterDataProvider *provider = layer->dataProvider();

  // Transform coordinates if needed
  QgsPointXY point( x, y );

  // Check if we need coordinate transformation
  if ( mProject && layer->crs() != mProject->crs() )
  {
    if ( !crsLogged )
    {
      qDebug() << "3D TERRAIN: CRS transform:" << mProject->crs().authid() << "->" << layer->crs().authid();
      crsLogged = true;
    }

    QgsCoordinateTransform transform( mProject->crs(), layer->crs(), mProject->transformContext() );
    try
    {
      point = transform.transform( point );
    }
    catch ( ... )
    {
      return 0.0;
    }
  }

  // Check if point is within layer extent
  if ( !layer->extent().contains( point ) )
  {
    return 0.0;
  }

  // Sample the raster
  bool ok = false;
  double value = provider->sample( point, 1, &ok );

  if ( !ok || std::isnan( value ) )
    return 0.0;

  return value;
}
