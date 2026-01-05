/***************************************************************************
  qgsquick3dterraingeometry.cpp - QgsQuick3DTerrainGeometry

 ---------------------
 begin                : 5.1.2026
 copyright            : (C) 2026 by QField Contributors
 email                : info@opengis.ch
 ***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/

#include "qgsquick3dterraingeometry.h"

#include <QDebug>

#include <cmath>

QgsQuick3DTerrainGeometry::QgsQuick3DTerrainGeometry( QQuick3DObject *parent )
  : QQuick3DGeometry( parent )
{
  // Generate default procedural terrain
  generateProceduralTerrain();
}

void QgsQuick3DTerrainGeometry::setResolution( int resolution )
{
  if ( resolution < 2 )
    resolution = 2;
  if ( resolution > 512 )
    resolution = 512;

  if ( mResolution != resolution )
  {
    mResolution = resolution;
    mDirty = true;
    emit resolutionChanged();
    updateGeometry();
  }
}

void QgsQuick3DTerrainGeometry::setTerrainSize( float size )
{
  if ( size <= 0 )
    size = 1.0f;

  if ( !qFuzzyCompare( mTerrainSize, size ) )
  {
    mTerrainSize = size;
    mDirty = true;
    emit terrainSizeChanged();
    updateGeometry();
  }
}

void QgsQuick3DTerrainGeometry::setHeightScale( float scale )
{
  if ( !qFuzzyCompare( mHeightScale, scale ) )
  {
    mHeightScale = scale;
    mDirty = true;
    emit heightScaleChanged();
    updateGeometry();
  }
}

void QgsQuick3DTerrainGeometry::setHeightData( const QVariantList &data )
{
  mHeightData = data;
  mHeights.clear();
  mHeights.reserve( data.size() );

  for ( const QVariant &v : data )
  {
    mHeights.append( v.toFloat() );
  }

  mDirty = true;
  emit heightDataChanged();
  updateGeometry();
}

void QgsQuick3DTerrainGeometry::generateProceduralTerrain()
{
  mHeights.clear();
  mHeights.reserve( mResolution * mResolution );

  for ( int z = 0; z < mResolution; ++z )
  {
    for ( int x = 0; x < mResolution; ++x )
    {
      float fx = static_cast<float>( x ) / mResolution;
      float fz = static_cast<float>( z ) / mResolution;

      // Multiple octaves for more interesting terrain
      float height = 0.0f;

      // Large hills
      height += std::sin( fx * 3.0f * M_PI ) * std::cos( fz * 2.0f * M_PI ) * 0.5f;

      // Medium features
      height += std::sin( fx * 7.0f * M_PI + 1.0f ) * std::cos( fz * 5.0f * M_PI + 2.0f ) * 0.25f;

      // Small details
      height += std::sin( fx * 15.0f * M_PI + 3.0f ) * std::cos( fz * 13.0f * M_PI + 4.0f ) * 0.1f;

      // Normalize to 0-1 range
      height = ( height + 0.85f ) / 1.7f;

      mHeights.append( height );
    }
  }

  mDirty = true;
  updateGeometry();
}

float QgsQuick3DTerrainGeometry::getHeight( int x, int z ) const
{
  if ( mHeights.isEmpty() )
    return 0.0f;

  x = qBound( 0, x, mResolution - 1 );
  z = qBound( 0, z, mResolution - 1 );

  return mHeights[z * mResolution + x];
}

QVector3D QgsQuick3DTerrainGeometry::calculateNormal( int x, int z )
{
  // Sample neighboring heights
  float hL = getHeight( x - 1, z );
  float hR = getHeight( x + 1, z );
  float hD = getHeight( x, z - 1 );
  float hU = getHeight( x, z + 1 );

  // Calculate normal using central differences
  QVector3D normal( hL - hR, 2.0f / mHeightScale, hD - hU );
  return normal.normalized();
}

void QgsQuick3DTerrainGeometry::updateGeometry()
{
  if ( !mDirty )
    return;

  if ( mHeights.size() != mResolution * mResolution )
  {
    qWarning() << "Height data size mismatch. Expected:" << mResolution * mResolution << "Got:" << mHeights.size();
    generateProceduralTerrain();
    return;
  }

  // Calculate sizes
  const int vertexCount = mResolution * mResolution;
  const int triangleCount = ( mResolution - 1 ) * ( mResolution - 1 ) * 2;
  const int indexCount = triangleCount * 3;

  // Vertex stride: position (3 floats) + normal (3 floats) + UV (2 floats) = 8 floats = 32 bytes
  const int stride = 8 * sizeof( float );

  // Allocate buffers
  QByteArray vertexData;
  vertexData.resize( vertexCount * stride );
  float *vptr = reinterpret_cast<float *>( vertexData.data() );

  QByteArray indexData;
  indexData.resize( indexCount * sizeof( quint32 ) );
  quint32 *iptr = reinterpret_cast<quint32 *>( indexData.data() );

  const float cellSize = mTerrainSize / ( mResolution - 1 );
  const float halfSize = mTerrainSize / 2.0f;

  // Generate vertices
  for ( int z = 0; z < mResolution; ++z )
  {
    for ( int x = 0; x < mResolution; ++x )
    {
      const int idx = z * mResolution + x;

      // Position
      float px = x * cellSize - halfSize;
      float py = getHeight( x, z ) * mHeightScale;
      float pz = z * cellSize - halfSize;

      *vptr++ = px;
      *vptr++ = py;
      *vptr++ = pz;

      // Normal
      QVector3D normal = calculateNormal( x, z );
      *vptr++ = normal.x();
      *vptr++ = normal.y();
      *vptr++ = normal.z();

      // UV coordinates
      // U: left to right (west to east) - unchanged
      // V: flip vertically - image Y=0 is north but mesh Z=0 is south
      *vptr++ = static_cast<float>( x ) / ( mResolution - 1 );
      *vptr++ = 1.0f - static_cast<float>( z ) / ( mResolution - 1 );
    }
  }

  // Generate indices (two triangles per cell)
  for ( int z = 0; z < mResolution - 1; ++z )
  {
    for ( int x = 0; x < mResolution - 1; ++x )
    {
      const quint32 topLeft = z * mResolution + x;
      const quint32 topRight = topLeft + 1;
      const quint32 bottomLeft = topLeft + mResolution;
      const quint32 bottomRight = bottomLeft + 1;

      // Triangle 1
      *iptr++ = topLeft;
      *iptr++ = bottomLeft;
      *iptr++ = topRight;

      // Triangle 2
      *iptr++ = topRight;
      *iptr++ = bottomLeft;
      *iptr++ = bottomRight;
    }
  }

  // Set geometry data
  clear();

  setVertexData( vertexData );
  setIndexData( indexData );
  setStride( stride );

  // Define attributes
  addAttribute( QQuick3DGeometry::Attribute::PositionSemantic, 0, QQuick3DGeometry::Attribute::F32Type );
  addAttribute( QQuick3DGeometry::Attribute::NormalSemantic, 3 * sizeof( float ), QQuick3DGeometry::Attribute::F32Type );
  addAttribute( QQuick3DGeometry::Attribute::TexCoordSemantic, 6 * sizeof( float ), QQuick3DGeometry::Attribute::F32Type );
  addAttribute( QQuick3DGeometry::Attribute::IndexSemantic, 0, QQuick3DGeometry::Attribute::U32Type );

  // Set primitive type
  setPrimitiveType( QQuick3DGeometry::PrimitiveType::Triangles );

  // Calculate bounds
  QVector3D minBound( -halfSize, 0, -halfSize );
  QVector3D maxBound( halfSize, mHeightScale, halfSize );
  setBounds( minBound, maxBound );

  mDirty = false;
  update();
}
