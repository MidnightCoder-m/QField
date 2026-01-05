# بررسی دقیق کلاس‌های 3D در QField

> این داکیومنت برای بررسی خط به خط کد و درک عمیق عملکرد هر کلاس است.

---

## 1. QgsQuick3DTerrainProvider

### 1.1 هدف کلی

این کلاس **پل ارتباطی** بین QGIS و QtQuick3D است:
- از پروژه QGIS داده ارتفاع (DEM) می‌خواند
- آن را به فرمت قابل استفاده برای QML تبدیل می‌کند

```
┌─────────────────┐         ┌──────────────────────────┐         ┌─────────────┐
│  QGIS Project   │ ──────► │ QgsQuick3DTerrainProvider│ ──────► │    QML      │
│  (DEM Layer)    │         │      (این کلاس)          │         │ (3D View)   │
└─────────────────┘         └──────────────────────────┘         └─────────────┘
```

---

### 1.2 استفاده در QML

```qml
QgsQuick3DTerrainProvider {
    id: terrainProvider
    project: root.qgisProject              // پروژه QGIS
    resolution: 64                          // تعداد نقاط نمونه‌برداری
    verticalExaggeration: root.verticalExaggeration  // اغراق عمودی
    extent: root.mapExtent                  // محدوده جغرافیایی

    onTerrainDataReady: {
        // سیگنال: وقتی داده terrain آماده شد
        // ...
    }
}
```

---

### 1.3 Properties (ویژگی‌ها)

#### 1.3.1 `project` - پروژه QGIS

```cpp
Q_PROPERTY( QgsProject *project READ project WRITE setProject NOTIFY projectChanged )
```

**چیست؟**
- اشاره‌گر به پروژه QGIS که باز شده
- از این پروژه تنظیمات terrain و لایه DEM خوانده می‌شود

**کد:**
```cpp
void QgsQuick3DTerrainProvider::setProject( QgsProject *project )
{
  if ( mProject == project )
    return;                    // اگر همان پروژه قبلی است، کاری نکن

  mProject = project;
  emit projectChanged();       // به QML اطلاع بده که تغییر کرد

  updateTerrainProvider();     // terrain را به‌روزرسانی کن
}
```

**نکته مهم:**
- وقتی پروژه ست می‌شود، خودکار `updateTerrainProvider()` صدا زده می‌شود
- این یعنی فقط با ست کردن project، همه چیز شروع می‌شود

---

#### 1.3.2 `resolution` - رزولوشن/دقت

```cpp
Q_PROPERTY( int resolution READ resolution WRITE setResolution NOTIFY resolutionChanged )
```

**چیست؟**
- تعداد نقاط نمونه‌برداری در هر بُعد
- `resolution = 64` یعنی یک grid با 64×64 = 4096 نقطه

```
resolution = 4:          resolution = 8:
┌─┬─┬─┬─┐               ┌─┬─┬─┬─┬─┬─┬─┬─┐
├─┼─┼─┼─┤               ├─┼─┼─┼─┼─┼─┼─┼─┤
├─┼─┼─┼─┤               ├─┼─┼─┼─┼─┼─┼─┼─┤
├─┼─┼─┼─┤               ├─┼─┼─┼─┼─┼─┼─┼─┤
└─┴─┴─┴─┘               ... (8 ردیف)
16 نقطه                  64 نقطه
```

**کد:**
```cpp
void QgsQuick3DTerrainProvider::setResolution( int resolution )
{
  resolution = qBound( 8, resolution, 256 );  // محدود کن بین 8 تا 256
  if ( mResolution == resolution )
    return;

  mResolution = resolution;
  emit resolutionChanged();
}
```

**چرا محدود شده؟**
- کمتر از 8: خیلی بی‌کیفیت
- بیشتر از 256: خیلی سنگین (256×256 = 65,536 نقطه!)

---

#### 1.3.3 `verticalExaggeration` - اغراق عمودی

```cpp
Q_PROPERTY( double verticalExaggeration READ verticalExaggeration
            WRITE setVerticalExaggeration NOTIFY verticalExaggerationChanged )
```

**چیست؟**
- ضریبی که ارتفاعات را بزرگ‌تر/کوچک‌تر نشان می‌دهد
- `1.0` = واقعی
- `2.0` = کوه‌ها دو برابر بلندتر به نظر می‌رسند
- `0.5` = کوه‌ها نصف ارتفاع واقعی

```
verticalExaggeration = 1.0:     verticalExaggeration = 2.0:
         ⛰️                              ⛰️
        /  \                            /  \
       /    \                          /    \
      /      \                        /      \
     /        \                      /        \
    /__________\                    /          \
                                   /            \
                                  /______________\
```

**کد:**
```cpp
void QgsQuick3DTerrainProvider::setVerticalExaggeration( double exaggeration )
{
  exaggeration = qBound( 0.1, exaggeration, 10.0 );  // 0.1 تا 10 برابر
  if ( qFuzzyCompare( mVerticalExaggeration, exaggeration ) )
    return;

  mVerticalExaggeration = exaggeration;
  emit verticalExaggerationChanged();
}
```

**نکته:** `qFuzzyCompare` برای مقایسه اعداد اعشاری استفاده می‌شود (به خاطر خطای floating point)

---

#### 1.3.4 `extent` - محدوده جغرافیایی

```cpp
Q_PROPERTY( QRectF extent READ extent WRITE setExtent NOTIFY extentChanged )
```

**چیست؟**
- مستطیلی که مشخص می‌کند کدام قسمت از نقشه را می‌خواهیم ببینیم
- در سیستم مختصات پروژه (CRS)

```
extent = QRectF(x, y, width, height)

         ┌─────────────────────┐
         │                     │
         │    این قسمت را      │
    y ───│    نمایش بده        │
         │                     │
         └─────────────────────┘
         x         width
```

**کد:**
```cpp
void QgsQuick3DTerrainProvider::setExtent( const QRectF &extent )
{
  if ( mExtent == extent )
    return;

  mExtent = extent;
  emit extentChanged();
}
```

---

#### 1.3.5 `hasTerrainData` - آیا داده terrain داریم؟

```cpp
Q_PROPERTY( bool hasTerrainData READ hasTerrainData NOTIFY hasTerrainDataChanged )
```

**چیست؟**
- `true` = پروژه دارای لایه DEM است
- `false` = پروژه فقط flat است (بدون ارتفاع)

**چطور تشخیص داده می‌شود؟**
```cpp
// در updateTerrainProvider():
mHasTerrainData = ( mTerrainType != QStringLiteral( "flat" ) );
```

---

#### 1.3.6 `terrainType` - نوع terrain

```cpp
Q_PROPERTY( QString terrainType READ terrainType NOTIFY terrainTypeChanged )
```

**مقادیر ممکن:**
| مقدار | توضیح |
|-------|-------|
| `"flat"` | بدون ارتفاع (زمین صاف) |
| `"raster"` | DEM از یک لایه raster |
| `"mesh"` | مدل 3D مش (کمتر استفاده می‌شود) |

---

#### 1.3.7 `demExtent` - محدوده واقعی DEM

```cpp
Q_PROPERTY( QRectF demExtent READ demExtent NOTIFY demExtentChanged )
```

**چیست؟**
- محدوده واقعی لایه DEM (نه محدوده نقشه)
- این دقیق‌تر است چون ممکن است DEM فقط بخشی از نقشه را پوشش دهد

**کد:**
```cpp
QRectF QgsQuick3DTerrainProvider::demExtent() const
{
  QgsRasterLayer *layer = mDemLayer ? mDemLayer : mFallbackDemLayer;
  if ( !layer )
    return QRectF();

  QgsRectangle layerExtent = layer->extent();

  // تبدیل به CRS پروژه (اگر لازم باشد)
  if ( mProject && layer->crs() != mProject->crs() )
  {
    QgsCoordinateTransform transform( layer->crs(), mProject->crs(),
                                       mProject->transformContext() );
    try {
      layerExtent = transform.transformBoundingBox( layerExtent );
    } catch ( ... ) {
      // خطا در تبدیل، extent اصلی را برگردان
    }
  }

  // مربع کردن extent (terrain mesh مربع است)
  double width = layerExtent.width();
  double height = layerExtent.height();
  if ( width > height ) {
    double diff = ( width - height ) / 2.0;
    layerExtent.setYMinimum( layerExtent.yMinimum() - diff );
    layerExtent.setYMaximum( layerExtent.yMaximum() + diff );
  } else if ( height > width ) {
    double diff = ( height - width ) / 2.0;
    layerExtent.setXMinimum( layerExtent.xMinimum() - diff );
    layerExtent.setXMaximum( layerExtent.xMaximum() + diff );
  }

  return QRectF( layerExtent.xMinimum(), layerExtent.yMinimum(),
                 layerExtent.width(), layerExtent.height() );
}
```

**چرا مربع می‌کنیم؟**
```
اگر DEM مستطیلی باشد:        بعد از مربع کردن:
┌────────────────┐           ┌────────────────┐
│                │           │    افزوده      │
│      DEM       │    →      ├────────────────┤
│                │           │      DEM       │
└────────────────┘           ├────────────────┤
                             │    افزوده      │
                             └────────────────┘

چون terrain mesh ما مربع است، اگر texture مستطیلی باشد کشیده می‌شود!
```

---

### 1.4 Signals (سیگنال‌ها)

```cpp
signals:
    void projectChanged();              // پروژه عوض شد
    void resolutionChanged();           // رزولوشن عوض شد
    void verticalExaggerationChanged(); // اغراق عمودی عوض شد
    void hasTerrainDataChanged();       // وضعیت داشتن terrain عوض شد
    void terrainTypeChanged();          // نوع terrain عوض شد
    void extentChanged();               // محدوده عوض شد
    void demExtentChanged();            // محدوده DEM عوض شد
    void terrainDataReady();            // ⭐ داده terrain آماده است!
```

**مهم‌ترین سیگنال: `terrainDataReady`**

این سیگنال وقتی emit می‌شود که:
1. پروژه ست شده
2. terrain provider پیدا شده
3. همه چیز آماده خواندن است

```qml
// در QML:
onTerrainDataReady: {
    // حالا می‌توانیم داده ارتفاع را بخوانیم
    loadRealTerrain();
}
```

---

### 1.5 Methods (متدها)

#### 1.5.1 `heightAt(x, y)` - ارتفاع در یک نقطه

```cpp
Q_INVOKABLE double heightAt( double x, double y ) const;
```

**چیست؟**
- ارتفاع زمین در مختصات (x, y) را برمی‌گرداند

**کد:**
```cpp
double QgsQuick3DTerrainProvider::heightAt( double x, double y ) const
{
  if ( !mTerrainProvider )
    return 0.0;

  double height = mTerrainProvider->heightAt( x, y );

  if ( std::isnan( height ) )
    return 0.0;

  return height * mVerticalExaggeration;  // اعمال اغراق عمودی
}
```

---

#### 1.5.2 `sampleHeightGrid()` - نمونه‌برداری grid ارتفاعات ⭐

```cpp
Q_INVOKABLE QVariantList sampleHeightGrid() const;
```

**چیست؟**
- مهم‌ترین متد! آرایه‌ای از ارتفاعات برمی‌گرداند
- این آرایه مستقیماً به `QgsQuick3DTerrainGeometry` داده می‌شود

**خروجی:**
```
برای resolution = 4:
[h00, h01, h02, h03,    // ردیف 0
 h10, h11, h12, h13,    // ردیف 1
 h20, h21, h22, h23,    // ردیف 2
 h30, h31, h32, h33]    // ردیف 3

row-major order: ردیف به ردیف
```

**کد (تحلیل مرحله به مرحله):**

```cpp
QVariantList QgsQuick3DTerrainProvider::sampleHeightGrid() const
{
  QVariantList heights;
  heights.reserve( mResolution * mResolution );  // حافظه از قبل رزرو کن

  // اگر extent خالی است، آرایه صفر برگردان
  if ( mExtent.isEmpty() )
  {
    for ( int i = 0; i < mResolution * mResolution; ++i )
      heights.append( 0.0 );
    return heights;
  }

  // انتخاب لایه DEM
  QgsRasterLayer *layerToUse = nullptr;
  if ( mDemLayer && mDemLayer->isValid() )
    layerToUse = mDemLayer;
  else if ( mFallbackDemLayer && mFallbackDemLayer->isValid() )
    layerToUse = mFallbackDemLayer;

  if ( !layerToUse )
  {
    // لایه DEM نداریم، آرایه صفر برگردان
    for ( int i = 0; i < mResolution * mResolution; ++i )
      heights.append( 0.0 );
    return heights;
  }

  // محاسبه step بین نقاط
  const double xStep = mExtent.width() / ( mResolution - 1 );
  const double yStep = mExtent.height() / ( mResolution - 1 );

  // حلقه روی همه نقاط grid
  for ( int row = 0; row < mResolution; ++row )
  {
    const double y = mExtent.top() + row * yStep;

    for ( int col = 0; col < mResolution; ++col )
    {
      const double x = mExtent.left() + col * xStep;

      // خواندن ارتفاع از raster
      double height = sampleHeightFromRaster( layerToUse, x, y );

      if ( std::isnan( height ) )
        height = 0.0;

      // اعمال اغراق عمودی و اضافه کردن به لیست
      heights.append( height * mVerticalExaggeration );
    }
  }

  return heights;
}
```

**نمودار:**
```
extent:
┌─────────────────────────────────────┐
│ (left,top)                          │
│    ●───●───●───●  ← row 0           │
│    │   │   │   │                    │
│    ●───●───●───●  ← row 1           │
│    │   │   │   │     ↑              │
│    ●───●───●───●  ← row 2    yStep  │
│    │   │   │   │     ↓              │
│    ●───●───●───●  ← row 3           │
│    ←─xStep─→                        │
│                     (left+width,    │
│                      top+height)    │
└─────────────────────────────────────┘
```

---

#### 1.5.3 `terrainStats()` - آمار terrain

```cpp
Q_INVOKABLE QVariantMap terrainStats() const;
```

**چیست؟**
- حداقل، حداکثر، و میانگین ارتفاع را برمی‌گرداند

**خروجی:**
```javascript
{
    "minHeight": 450.0,    // کمترین ارتفاع
    "maxHeight": 2100.0,   // بیشترین ارتفاع
    "avgHeight": 980.0     // میانگین ارتفاع
}
```

---

#### 1.5.4 `refresh()` - به‌روزرسانی

```cpp
Q_INVOKABLE void refresh();
```

**کد:**
```cpp
void QgsQuick3DTerrainProvider::refresh()
{
  updateTerrainProvider();
  emit terrainDataReady();
}
```

---

### 1.6 Private Methods (متدهای خصوصی)

#### 1.6.1 `updateTerrainProvider()` - به‌روزرسانی اصلی

**این متد قلب کلاس است!**

```cpp
void QgsQuick3DTerrainProvider::updateTerrainProvider()
{
  // 1. Reset همه چیز
  mTerrainProvider = nullptr;
  mHasTerrainData = false;
  mTerrainType = QStringLiteral( "flat" );

  if ( !mProject )
  {
    emit hasTerrainDataChanged();
    emit terrainTypeChanged();
    return;
  }

  // 2. گرفتن Elevation Properties از پروژه
  QgsProjectElevationProperties *elevProps = mProject->elevationProperties();
  if ( !elevProps )
  {
    emit hasTerrainDataChanged();
    emit terrainTypeChanged();
    return;
  }

  // 3. گرفتن Terrain Provider
  QgsAbstractTerrainProvider *provider = elevProps->terrainProvider();
  if ( !provider )
  {
    emit hasTerrainDataChanged();
    emit terrainTypeChanged();
    return;
  }

  mTerrainProvider = provider;
  mTerrainType = provider->type();  // "flat", "raster", "mesh"
  mHasTerrainData = ( mTerrainType != QStringLiteral( "flat" ) );

  // 4. اگر raster DEM است، لایه را بگیر
  if ( mTerrainType == QStringLiteral( "raster" ) )
  {
    QgsRasterDemTerrainProvider *rasterProvider =
        dynamic_cast<QgsRasterDemTerrainProvider *>( provider );

    if ( rasterProvider )
    {
      QgsRasterLayer *demLayer = rasterProvider->layer();
      if ( demLayer )
      {
        mDemLayer = demLayer;

        // اگر DEM از WMS است، یک DEM محلی پیدا کن
        if ( demLayer->dataProvider() &&
             demLayer->dataProvider()->name() == QStringLiteral( "wms" ) )
        {
          mFallbackDemLayer = findLocalDemLayer();
        }
      }
    }
  }

  // 5. اگر extent ست نشده، از پروژه بگیر
  if ( mExtent.isEmpty() )
  {
    const QgsRectangle fullExtent = mProject->viewSettings()->fullExtent();
    if ( !fullExtent.isEmpty() )
    {
      mExtent = QRectF( fullExtent.xMinimum(), fullExtent.yMinimum(),
                        fullExtent.width(), fullExtent.height() );
      emit extentChanged();
    }
  }

  // 6. اطلاع‌رسانی
  emit hasTerrainDataChanged();
  emit terrainTypeChanged();
  emit terrainDataReady();  // ⭐ مهم! QML منتظر این است
}
```

**نمودار جریان:**
```
setProject() ────────────────────────────────────────────────────►
                              │
                              ▼
                    updateTerrainProvider()
                              │
           ┌──────────────────┼──────────────────┐
           │                  │                  │
           ▼                  ▼                  ▼
      پروژه ندارد      elevProps ندارد    provider ندارد
           │                  │                  │
           └──────────────────┴──────────────────┘
                              │
                              ▼ (خروج زودهنگام)

           ───────────────────┼───────────────────
                              │
                              ▼ (ادامه اگر همه چیز OK)

                    mTerrainProvider = provider
                    mTerrainType = provider->type()
                              │
                              ▼
                 ┌────────────┴────────────┐
                 │  if type == "raster"    │
                 │  لایه DEM را پیدا کن    │
                 └────────────┬────────────┘
                              │
                              ▼
                    emit terrainDataReady() ────► QML
```

---

#### 1.6.2 `findLocalDemLayer()` - پیدا کردن DEM محلی

```cpp
QgsRasterLayer *QgsQuick3DTerrainProvider::findLocalDemLayer() const
```

**چرا لازم است؟**
- گاهی پروژه QGIS از یک DEM آنلاین (WMS) استفاده می‌کند
- WMS برای نمونه‌برداری pixel به pixel مناسب نیست
- این متد یک DEM محلی جایگزین پیدا می‌کند

**الگوریتم:**
```
پاس اول:
  برای هر لایه raster:
    - اگر WMS/WMTS است → رد شو
    - اگر چند بانده است → رد شو
    - اگر نام شامل "dem", "dtm", "srtm", "elevation" است → برگردان

پاس دوم:
  برای هر لایه raster:
    - اگر WMS/WMTS است → رد شو
    - اگر تک بانده است → برگردان (حتی بدون نام خاص)
```

---

#### 1.6.3 `sampleHeightFromRaster()` - خواندن ارتفاع از raster

```cpp
double QgsQuick3DTerrainProvider::sampleHeightFromRaster(
    QgsRasterLayer *layer, double x, double y ) const
```

**چرا این متد جدا است؟**
- باید تبدیل CRS انجام شود
- باید چک شود نقطه داخل extent لایه است

**کد:**
```cpp
double QgsQuick3DTerrainProvider::sampleHeightFromRaster(
    QgsRasterLayer *layer, double x, double y ) const
{
  if ( !layer || !layer->dataProvider() )
    return 0.0;

  QgsRasterDataProvider *provider = layer->dataProvider();
  QgsPointXY point( x, y );

  // تبدیل CRS (اگر لازم باشد)
  if ( mProject && layer->crs() != mProject->crs() )
  {
    QgsCoordinateTransform transform(
        mProject->crs(),      // از: CRS پروژه
        layer->crs(),         // به: CRS لایه
        mProject->transformContext()
    );
    try {
      point = transform.transform( point );
    } catch ( ... ) {
      return 0.0;
    }
  }

  // چک extent
  if ( !layer->extent().contains( point ) )
    return 0.0;

  // خواندن مقدار pixel
  bool ok = false;
  double value = provider->sample( point, 1, &ok );  // band 1

  if ( !ok || std::isnan( value ) )
    return 0.0;

  return value;
}
```

**تبدیل CRS چیست؟**
```
پروژه در EPSG:4326 (lat/lon):
  نقطه: (51.4, 35.7)
              ↓
         CRS Transform
              ↓
لایه DEM در EPSG:32639 (UTM):
  نقطه: (534000, 3952000)
```

---

### 1.7 Member Variables (متغیرهای عضو)

```cpp
private:
    QgsProject *mProject = nullptr;
    // پروژه QGIS

    QgsAbstractTerrainProvider *mTerrainProvider = nullptr;
    // terrain provider از QGIS (برای heightAt)

    QPointer<QgsRasterLayer> mFallbackDemLayer;
    // DEM محلی جایگزین (اگر اصلی WMS باشد)

    QPointer<QgsRasterLayer> mDemLayer;
    // لایه DEM اصلی از terrain provider

    int mResolution = 64;
    // رزولوشن grid

    double mVerticalExaggeration = 1.0;
    // اغراق عمودی

    QRectF mExtent;
    // محدوده نمونه‌برداری

    bool mHasTerrainData = false;
    // آیا DEM داریم؟

    QString mTerrainType = QStringLiteral( "flat" );
    // نوع terrain
```

**چرا `QPointer` برای لایه‌ها؟**
- لایه‌ها ممکن است از پروژه حذف شوند
- `QPointer` به طور خودکار `nullptr` می‌شود اگر object حذف شود
- جلوگیری از crash به خاطر dangling pointer

---

### 1.8 خلاصه جریان کار

```
┌────────────────────────────────────────────────────────────────┐
│                         QML                                    │
├────────────────────────────────────────────────────────────────┤
│  QgsQuick3DTerrainProvider {                                   │
│      project: qgisProject  ──────────────────────┐             │
│  }                                               │             │
└──────────────────────────────────────────────────│─────────────┘
                                                   │
                                                   ▼
┌────────────────────────────────────────────────────────────────┐
│                    setProject()                                │
│                         │                                      │
│                         ▼                                      │
│               updateTerrainProvider()                          │
│                         │                                      │
│         ┌───────────────┼───────────────┐                      │
│         ▼               ▼               ▼                      │
│   elevProps       terrainProvider    demLayer                  │
│         │               │               │                      │
│         └───────────────┴───────────────┘                      │
│                         │                                      │
│                         ▼                                      │
│              emit terrainDataReady()                           │
└────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────────────────────┐
│                         QML                                    │
├────────────────────────────────────────────────────────────────┤
│  onTerrainDataReady: {                                         │
│      var heights = terrainProvider.sampleHeightGrid()          │
│      terrainMesh.heightData = heights                          │
│  }                                                             │
└────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────────────────────┐
│               sampleHeightGrid()                               │
│                         │                                      │
│    ┌────────────────────┼────────────────────┐                 │
│    │ for row = 0..res-1                      │                 │
│    │   for col = 0..res-1                    │                 │
│    │     x = left + col * xStep              │                 │
│    │     y = top + row * yStep               │                 │
│    │     h = sampleHeightFromRaster(x, y)    │                 │
│    │     heights.append(h * exaggeration)    │                 │
│    └─────────────────────────────────────────┘                 │
│                         │                                      │
│                         ▼                                      │
│              return heights[]                                  │
└────────────────────────────────────────────────────────────────┘
```

---

## ادامه دارد...

> در بخش بعدی: `QgsQuick3DTerrainGeometry` - چگونه از آرایه ارتفاعات یک Mesh 3D می‌سازیم

