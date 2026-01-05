/***************************************************************************
  qgsquick3dterrainprovider.h - QgsQuick3DTerrainProvider

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
#ifndef QGSQUICK3DTERRAINPROVIDER_H
#define QGSQUICK3DTERRAINPROVIDER_H

#include <QObject>
#include <QPointer>
#include <QRectF>
#include <QVariantList>

class QgsProject;
class QgsAbstractTerrainProvider;
class QgsRectangle;
class QgsRasterLayer;

/**
 * @brief Provides terrain elevation data from QGIS project to QtQuick3D
 *
 * This class bridges QGIS terrain providers with QtQuick3D terrain rendering.
 * It samples elevation data from DEM layers and provides it to QML.
 */
class QgsQuick3DTerrainProvider : public QObject
{
    Q_OBJECT

    //! The QGIS project to get terrain from
    Q_PROPERTY( QgsProject *project READ project WRITE setProject NOTIFY projectChanged )

    //! Grid resolution (number of samples per axis)
    Q_PROPERTY( int resolution READ resolution WRITE setResolution NOTIFY resolutionChanged )

    //! Vertical exaggeration factor
    Q_PROPERTY( double verticalExaggeration READ verticalExaggeration WRITE setVerticalExaggeration NOTIFY verticalExaggerationChanged )

    //! Whether terrain data is available
    Q_PROPERTY( bool hasTerrainData READ hasTerrainData NOTIFY hasTerrainDataChanged )

    //! Terrain type: "flat", "dem", "mesh"
    Q_PROPERTY( QString terrainType READ terrainType NOTIFY terrainTypeChanged )

    //! Extent of the terrain in map coordinates
    Q_PROPERTY( QRectF extent READ extent WRITE setExtent NOTIFY extentChanged )

    //! Extent of the DEM layer (read-only, in project CRS)
    Q_PROPERTY( QRectF demExtent READ demExtent NOTIFY demExtentChanged )

  public:
    explicit QgsQuick3DTerrainProvider( QObject *parent = nullptr );
    ~QgsQuick3DTerrainProvider() override;

    QgsProject *project() const;
    void setProject( QgsProject *project );

    int resolution() const;
    void setResolution( int resolution );

    double verticalExaggeration() const;
    void setVerticalExaggeration( double exaggeration );

    bool hasTerrainData() const;
    QString terrainType() const;

    QRectF extent() const;
    void setExtent( const QRectF &extent );

    QRectF demExtent() const;

    /**
     * @brief Get elevation at a specific point
     * @param x X coordinate in map CRS
     * @param y Y coordinate in map CRS
     * @return Elevation value, or NaN if no data
     */
    Q_INVOKABLE double heightAt( double x, double y ) const;

    /**
     * @brief Sample terrain heights for a grid
     *
     * Returns a flat array of height values for a grid covering the extent.
     * Array is row-major: [row0col0, row0col1, ..., row1col0, ...]
     *
     * @return List of height values (resolution * resolution)
     */
    Q_INVOKABLE QVariantList sampleHeightGrid() const;

    /**
     * @brief Get terrain statistics
     * @return Map with minHeight, maxHeight, avgHeight
     */
    Q_INVOKABLE QVariantMap terrainStats() const;

    /**
     * @brief Force refresh of terrain data
     */
    Q_INVOKABLE void refresh();

  signals:
    void projectChanged();
    void resolutionChanged();
    void verticalExaggerationChanged();
    void hasTerrainDataChanged();
    void terrainTypeChanged();
    void extentChanged();
    void demExtentChanged();
    void terrainDataReady();

  private:
    void updateTerrainProvider();
    QgsRasterLayer *findLocalDemLayer() const;
    double sampleHeightFromRaster( QgsRasterLayer *layer, double x, double y ) const;

    QgsProject *mProject = nullptr;
    QgsAbstractTerrainProvider *mTerrainProvider = nullptr;
    QPointer<QgsRasterLayer> mFallbackDemLayer;
    QPointer<QgsRasterLayer> mDemLayer; // The actual DEM layer from terrain provider
    int mResolution = 64;
    double mVerticalExaggeration = 1.0;
    QRectF mExtent;
    bool mHasTerrainData = false;
    QString mTerrainType = QStringLiteral( "flat" );
};

#endif // QGSQUICK3DTERRAINPROVIDER_H
