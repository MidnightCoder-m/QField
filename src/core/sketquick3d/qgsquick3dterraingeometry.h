/***************************************************************************
  qgsquick3dterraingeometry.h - QgsQuick3DTerrainGeometry

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

#ifndef QGSQUICK3DTERRAINGEOMETRY_H
#define QGSQUICK3DTERRAINGEOMETRY_H

#include <QQuick3DGeometry>
#include <QVector3D>
#include <QVector>

/**
 * @brief Custom terrain geometry for QtQuick3D
 *
 * Generates a terrain mesh from elevation data (height array).
 * Can be used with DEM data or procedural generation.
 */
class QgsQuick3DTerrainGeometry : public QQuick3DGeometry
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY( int resolution READ resolution WRITE setResolution NOTIFY resolutionChanged )
    Q_PROPERTY( float terrainSize READ terrainSize WRITE setTerrainSize NOTIFY terrainSizeChanged )
    Q_PROPERTY( float heightScale READ heightScale WRITE setHeightScale NOTIFY heightScaleChanged )
    Q_PROPERTY( QVariantList heightData READ heightData WRITE setHeightData NOTIFY heightDataChanged )

  public:
    explicit QgsQuick3DTerrainGeometry( QQuick3DObject *parent = nullptr );

    int resolution() const { return mResolution; }
    void setResolution( int resolution );

    float terrainSize() const { return mTerrainSize; }
    void setTerrainSize( float size );

    float heightScale() const { return mHeightScale; }
    void setHeightScale( float scale );

    QVariantList heightData() const { return mHeightData; }
    void setHeightData( const QVariantList &data );

    /**
     * Generate procedural terrain (for testing)
     * Creates sine-wave hills
     */
    Q_INVOKABLE void generateProceduralTerrain();

    /**
     * Generate flat terrain at specified height
     */
    Q_INVOKABLE void generateFlatTerrain( float height = 0.0f );

  signals:
    void resolutionChanged();
    void terrainSizeChanged();
    void heightScaleChanged();
    void heightDataChanged();

  private:
    void updateGeometry();
    QVector3D calculateNormal( int x, int z );
    float getHeight( int x, int z ) const;

    int mResolution = 64;         // Grid resolution (vertices per side)
    float mTerrainSize = 1000.0f; // Total terrain size in world units
    float mHeightScale = 100.0f;  // Height multiplier
    QVariantList mHeightData;     // Height values (resolution * resolution)
    QVector<float> mHeights;      // Parsed height data
    bool mDirty = true;
};

#endif // QGSQUICK3DTERRAINGEOMETRY_H
