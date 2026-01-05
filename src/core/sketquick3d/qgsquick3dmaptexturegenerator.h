/***************************************************************************
  qgsquick3dmaptexturegenerator.h - QgsQuick3DMapTextureGenerator

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
#ifndef QGSQUICK3DMAPTEXTUREGENERATOR_H
#define QGSQUICK3DMAPTEXTUREGENERATOR_H

#include <QImage>
#include <QObject>
#include <QPointer>
#include <QQuickImageProvider>
#include <QRectF>
#include <QUrl>

class QgsProject;
class QgsMapSettings;
class QgsMapRendererSequentialJob;

/**
 * @brief Generates map texture for 3D terrain draping
 *
 * This class renders the 2D map layers to a texture that can be
 * draped over the 3D terrain mesh.
 */
class QgsQuick3DMapTextureGenerator : public QObject
{
    Q_OBJECT

    //! The QGIS project to render
    Q_PROPERTY( QgsProject *project READ project WRITE setProject NOTIFY projectChanged )

    //! Extent to render (in project CRS)
    Q_PROPERTY( QRectF extent READ extent WRITE setExtent NOTIFY extentChanged )

    //! Texture resolution (width and height in pixels)
    Q_PROPERTY( int textureSize READ textureSize WRITE setTextureSize NOTIFY textureSizeChanged )

    //! Whether texture is ready
    Q_PROPERTY( bool ready READ ready NOTIFY readyChanged )

    //! URL to use in QML Image source (uses image provider)
    Q_PROPERTY( QString textureSource READ textureSource NOTIFY textureReady )

    //! File path to the rendered texture (for direct file loading)
    Q_PROPERTY( QString textureFilePath READ textureFilePath NOTIFY textureReady )

  public:
    explicit QgsQuick3DMapTextureGenerator( QObject *parent = nullptr );
    ~QgsQuick3DMapTextureGenerator() override;

    QgsProject *project() const;
    void setProject( QgsProject *project );

    QRectF extent() const;
    void setExtent( const QRectF &extent );

    int textureSize() const;
    void setTextureSize( int size );

    bool ready() const;

    QString textureSource() const;
    QString textureFilePath() const;

    /**
     * @brief Render the map to texture
     *
     * This starts an asynchronous render job. When complete,
     * textureReady signal is emitted.
     */
    Q_INVOKABLE void render();

    /**
     * @brief Get the rendered image
     * @return The rendered map image, or null image if not ready
     */
    QImage renderedImage() const;

    /**
     * @brief Generate a unique texture ID for this instance
     */
    QString textureId() const;

  signals:
    void projectChanged();
    void extentChanged();
    void textureSizeChanged();
    void readyChanged();
    void textureReady();
    void renderError( const QString &error );

  private slots:
    void onRenderFinished();

  private:
    QgsProject *mProject = nullptr;
    QRectF mExtent;
    int mTextureSize = 1024;
    bool mReady = false;
    QImage mRenderedImage;
    QString mTextureId;
    QString mTextureFilePath;

    std::unique_ptr<QgsMapRendererSequentialJob> mRenderJob;

    static int sTextureIdCounter;
};

/**
 * @brief Image provider for 3D map textures
 *
 * Provides rendered map textures to QML via image://terrain3d/
 */
class QgsQuick3DMapTextureImageProvider : public QQuickImageProvider
{
  public:
    QgsQuick3DMapTextureImageProvider();

    QImage requestImage( const QString &id, QSize *size, const QSize &requestedSize ) override;

    /**
     * @brief Register a texture generator
     */
    static void registerTexture( const QString &id, QgsQuick3DMapTextureGenerator *generator );

    /**
     * @brief Unregister a texture generator
     */
    static void unregisterTexture( const QString &id );

  private:
    static QHash<QString, QPointer<QgsQuick3DMapTextureGenerator>> sTextureGenerators;
};

#endif // QGSQUICK3DMAPTEXTUREGENERATOR_H
