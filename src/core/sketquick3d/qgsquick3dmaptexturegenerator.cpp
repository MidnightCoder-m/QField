/***************************************************************************
  qgsquick3dmaptexturegenerator.cpp - QgsQuick3DMapTextureGenerator

 ---------------------
 begin                : 6.1.2026
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

#include "qgsquick3dmaptexturegenerator.h"

#include <QDebug>
#include <qgsmaplayer.h>
#include <qgsmaprenderersequentialjob.h>
#include <qgsmapsettings.h>
#include <qgsproject.h>
#include <qgsrasterlayer.h>
#include <qgsrectangle.h>

int QgsQuick3DMapTextureGenerator::sTextureIdCounter = 0;
QHash<QString, QPointer<QgsQuick3DMapTextureGenerator>> QgsQuick3DMapTextureImageProvider::sTextureGenerators;

QgsQuick3DMapTextureGenerator::QgsQuick3DMapTextureGenerator( QObject *parent )
  : QObject( parent )
{
  mTextureId = QStringLiteral( "terrain3d_%1" ).arg( ++sTextureIdCounter );
  QgsQuick3DMapTextureImageProvider::registerTexture( mTextureId, this );
}

QgsQuick3DMapTextureGenerator::~QgsQuick3DMapTextureGenerator()
{
  QgsQuick3DMapTextureImageProvider::unregisterTexture( mTextureId );
}

QgsProject *QgsQuick3DMapTextureGenerator::project() const
{
  return mProject;
}

void QgsQuick3DMapTextureGenerator::setProject( QgsProject *project )
{
  if ( mProject == project )
    return;

  mProject = project;
  mReady = false;
  emit projectChanged();
  emit readyChanged();
}

QRectF QgsQuick3DMapTextureGenerator::extent() const
{
  return mExtent;
}

void QgsQuick3DMapTextureGenerator::setExtent( const QRectF &extent )
{
  if ( mExtent == extent )
    return;

  mExtent = extent;
  mReady = false;
  emit extentChanged();
  emit readyChanged();
}

int QgsQuick3DMapTextureGenerator::textureSize() const
{
  return mTextureSize;
}

void QgsQuick3DMapTextureGenerator::setTextureSize( int size )
{
  size = qBound( 256, size, 4096 );
  if ( mTextureSize == size )
    return;

  mTextureSize = size;
  mReady = false;
  emit textureSizeChanged();
  emit readyChanged();
}

bool QgsQuick3DMapTextureGenerator::ready() const
{
  return mReady;
}

QString QgsQuick3DMapTextureGenerator::textureSource() const
{
  return QStringLiteral( "image://sketquick3d/%1" ).arg( mTextureId );
}

QString QgsQuick3DMapTextureGenerator::textureFilePath() const
{
  return mTextureFilePath;
}

QString QgsQuick3DMapTextureGenerator::textureId() const
{
  return mTextureId;
}

void QgsQuick3DMapTextureGenerator::render()
{
  if ( !mProject )
  {
    emit renderError( QStringLiteral( "No project set" ) );
    return;
  }

  if ( mExtent.isEmpty() )
  {
    emit renderError( QStringLiteral( "Empty extent" ) );
    return;
  }

  // Cancel any existing job
  if ( mRenderJob )
  {
    mRenderJob->cancel();
    mRenderJob.reset();
  }

  // Use the map extent for rendering (same extent as terrain geometry)
  QgsRectangle renderExtent( mExtent.left(), mExtent.top(),
                             mExtent.left() + mExtent.width(),
                             mExtent.top() + mExtent.height() );

  // Make the extent square (terrain mesh is square, so texture should match)
  // Expand the smaller dimension to match the larger one
  double width = renderExtent.width();
  double height = renderExtent.height();
  if ( width > height )
  {
    // Expand height
    double diff = ( width - height ) / 2.0;
    renderExtent.setYMinimum( renderExtent.yMinimum() - diff );
    renderExtent.setYMaximum( renderExtent.yMaximum() + diff );
  }
  else if ( height > width )
  {
    // Expand width
    double diff = ( height - width ) / 2.0;
    renderExtent.setXMinimum( renderExtent.xMinimum() - diff );
    renderExtent.setXMaximum( renderExtent.xMaximum() + diff );
  }

  // Set up map settings with square output
  QgsMapSettings mapSettings;
  mapSettings.setOutputSize( QSize( mTextureSize, mTextureSize ) );
  mapSettings.setExtent( renderExtent );
  mapSettings.setDestinationCrs( mProject->crs() );
  mapSettings.setTransformContext( mProject->transformContext() );
  mapSettings.setBackgroundColor( QColor( 80, 80, 80 ) );

  // Collect layers to render (raster layers only for now, excluding DEM)
  QList<QgsMapLayer *> layersToRender;
  const QMap<QString, QgsMapLayer *> projectLayers = mProject->mapLayers();
  for ( auto it = projectLayers.begin(); it != projectLayers.end(); ++it )
  {
    QgsMapLayer *layer = it.value();
    if ( !layer || !layer->isValid() )
      continue;

    // Include raster layers (aerial/satellite imagery)
    if ( layer->type() == Qgis::LayerType::Raster )
    {
      QgsRasterLayer *rasterLayer = qobject_cast<QgsRasterLayer *>( layer );
      if ( rasterLayer )
      {
        // Skip single-band DEMs (likely elevation data)
        // Include multi-band rasters (likely imagery)
        if ( rasterLayer->bandCount() > 1 )
        {
          layersToRender.append( layer );
        }
        else
        {
          // Check if it's a WMS layer (likely imagery)
          if ( rasterLayer->dataProvider() && ( rasterLayer->dataProvider()->name() == QStringLiteral( "wms" ) || rasterLayer->dataProvider()->name() == QStringLiteral( "wmts" ) ) )
          {
            layersToRender.append( layer );
          }
        }
      }
    }
  }

  if ( layersToRender.isEmpty() )
  {
    // Create a simple colored texture instead
    mRenderedImage = QImage( mTextureSize, mTextureSize, QImage::Format_RGB32 );
    mRenderedImage.fill( QColor( 100, 140, 100 ) );
    mReady = true;
    emit readyChanged();
    emit textureReady();
    return;
  }

  mapSettings.setLayers( layersToRender );

  // Create render job
  mRenderJob = std::make_unique<QgsMapRendererSequentialJob>( mapSettings );
  connect( mRenderJob.get(), &QgsMapRendererSequentialJob::finished, this, &QgsQuick3DMapTextureGenerator::onRenderFinished );

  mRenderJob->start();
}

void QgsQuick3DMapTextureGenerator::onRenderFinished()
{
  if ( !mRenderJob )
    return;

  mRenderedImage = mRenderJob->renderedImage();
  mRenderJob.reset();

  if ( mRenderedImage.isNull() )
  {
    mRenderedImage = QImage( mTextureSize, mTextureSize, QImage::Format_RGB32 );
    mRenderedImage.fill( QColor( 100, 140, 100 ) );
  }

  // Save texture to a temp file for QtQuick3D to load directly
  mTextureFilePath = QStringLiteral( "/tmp/qfield_3d_texture_%1.png" ).arg( mTextureId );
  mRenderedImage.save( mTextureFilePath );

  mReady = true;
  emit readyChanged();
  emit textureReady();
}

QImage QgsQuick3DMapTextureGenerator::renderedImage() const
{
  return mRenderedImage;
}

// Image Provider implementation

QgsQuick3DMapTextureImageProvider::QgsQuick3DMapTextureImageProvider()
  : QQuickImageProvider( QQuickImageProvider::Image )
{
}

QImage QgsQuick3DMapTextureImageProvider::requestImage( const QString &id, QSize *size, const QSize &requestedSize )
{
  Q_UNUSED( requestedSize )

  QgsQuick3DMapTextureGenerator *generator = sTextureGenerators.value( id );
  if ( generator )
  {
    QImage image = generator->renderedImage();
    if ( size )
      *size = image.size();
    return image;
  }

  // Return a default gray image if generator not found
  QImage fallback( 256, 256, QImage::Format_RGB32 );
  fallback.fill( QColor( 128, 128, 128 ) );
  if ( size )
    *size = fallback.size();
  return fallback;
}

void QgsQuick3DMapTextureImageProvider::registerTexture( const QString &id, QgsQuick3DMapTextureGenerator *generator )
{
  sTextureGenerators.insert( id, generator );
}

void QgsQuick3DMapTextureImageProvider::unregisterTexture( const QString &id )
{
  sTextureGenerators.remove( id );
}
