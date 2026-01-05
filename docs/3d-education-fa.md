# آموزش کامل سیستم 3D در QField 🗺️

## فهرست مطالب
1. [مفاهیم پایه گرافیک 3D](#1-مفاهیم-پایه-گرافیک-3d)
2. [QtQuick3D چیست؟](#2-qtquick3d-چیست)
3. [ما در این پروژه چه می‌کنیم؟](#3-ما-در-این-پروژه-چه-می‌کنیم)
4. [معماری کد](#4-معماری-کد)
5. [جزئیات هر کامپوننت](#5-جزئیات-هر-کامپوننت)
6. [چگونه همه چیز کنار هم کار می‌کند](#6-چگونه-همه-چیز-کنار-هم-کار-می‌کند)

---

## 1. مفاهیم پایه گرافیک 3D

### 1.1 فضای سه‌بعدی (3D Space)

تصور کن یک اتاق داری:
- **X**: چپ ↔ راست
- **Y**: پایین ↔ بالا
- **Z**: جلو ↔ عقب

هر نقطه در این فضا با سه عدد مشخص می‌شود: `(x, y, z)`

```
        Y (بالا)
        |
        |
        |_______ X (راست)
       /
      /
     Z (جلو، به سمت بیننده)
```

### 1.2 Mesh (مِش) - شبکه چندضلعی

**Mesh چیست؟**
یک شکل سه‌بعدی از هزاران مثلث کوچک تشکیل شده. مثل یک مجسمه اوریگامی که از کاغذهای مثلثی ساخته شده.

```
     یک مکعب ساده از 12 مثلث تشکیل شده
     (هر وجه = 2 مثلث × 6 وجه = 12 مثلث)

         +-------+
        /|      /|
       / |     / |
      +-------+  |
      |  +----|--+
      | /     | /
      |/      |/
      +-------+
```

**Mesh از چه چیزهایی تشکیل شده؟**

1. **Vertices (رئوس)**: نقاط گوشه‌ای
   ```
   مثال: یک مثلث 3 vertex دارد
   vertex1 = (0, 0, 0)
   vertex2 = (1, 0, 0)
   vertex3 = (0.5, 1, 0)
   ```

2. **Indices (اندیس‌ها)**: کدام رئوس به هم وصل شوند تا مثلث بسازند
   ```
   triangle = [0, 1, 2]  // vertex های 0، 1، 2 یک مثلث می‌سازند
   ```

3. **Normals (نرمال‌ها)**: جهت "رو" هر سطح (برای نورپردازی)
   ```
   اگر یک صفحه افقی داری، نرمالش به بالا اشاره می‌کند: (0, 1, 0)
   ```

4. **UV Coordinates (مختصات بافت)**: کجای تصویر روی هر نقطه بیفتد
   ```
   UV از 0 تا 1 است
   (0,0) = گوشه پایین-چپ تصویر
   (1,1) = گوشه بالا-راست تصویر
   ```

### 1.3 Texture (تکسچر/بافت)

**تکسچر چیست؟**
یک تصویر 2D که روی سطح 3D "کشیده" می‌شود. مثل کاغذ کادو که دور جعبه می‌پیچی.

```
  تصویر 2D (تکسچر)          شکل 3D (Mesh)
  ┌─────────────┐
  │  🌲🌲🌲🌲  │    →→→    روی سطح کشیده می‌شود
  │  🌲🌲🌲🌲  │
  └─────────────┘
```

**انواع تکسچر:**
- **Diffuse/Albedo**: رنگ اصلی سطح
- **Normal Map**: جزئیات برجستگی (بدون افزودن geometry واقعی)
- **Roughness**: چقدر سطح صیقلی یا زبر است

### 1.4 Terrain (زمین/تِرِین)

**Terrain چیست؟**
یک سطح سه‌بعدی که نشان‌دهنده زمین است - با کوه‌ها، دره‌ها، و تپه‌ها.

```
  نمای از بالا (2D)              نمای سه‌بعدی
  ┌─────────────┐
  │ ░░▓▓▓░░░░░ │               ⛰️    ⛰️
  │ ░▓▓▓▓▓░░░░ │     →→→      /  \  /  \
  │ ░░▓▓▓░░░░░ │             /    \/    \
  └─────────────┘            _______________
  (تیره‌تر = بلندتر)
```

### 1.5 DEM (Digital Elevation Model)

**DEM چیست؟**
یک فایل که ارتفاع هر نقطه از زمین را ذخیره کرده. مثل یک تصویر grayscale که:
- **سفیدتر = بلندتر**
- **سیاه‌تر = پایین‌تر**

```
  DEM File (grayscale)
  ┌─────────────┐
  │ ⬜⬜⬛⬛⬛ │  ⬜ = 2000m (کوه)
  │ ⬜⬛⬛⬛⬛ │  ⬛ = 500m (دشت)
  │ ⬛⬛⬛⬛⬛ │
  └─────────────┘
```

### 1.6 Camera (دوربین)

دوربین چشم بیننده است. مشخص می‌کند:
- **Position**: کجا ایستاده‌ای
- **Target/LookAt**: به کجا نگاه می‌کنی
- **Field of View (FOV)**: زاویه دید (مثل لنز واید یا تله)

```
  دوربین با FOV مختلف:

  FOV کم (تله‌فوتو)         FOV زیاد (واید)
       /|                      /|
      / |                    /  |
     /  |                  /    |
    👁️  |                👁️     |
     \  |                  \    |
      \ |                    \  |
       \|                      \|
```

### 1.7 Orbit Camera (دوربین مداری)

یک نوع کنترل دوربین که:
- همیشه به یک نقطه (target) نگاه می‌کند
- دور آن نقطه می‌چرخد (مثل ماه دور زمین)

```
  پارامترها:
  - distance: فاصله از target
  - yaw: چرخش افقی (0° تا 360°)
  - pitch: چرخش عمودی (زاویه از افق)

        * دوربین
         \
          \  distance
           \
            ● target
```

---

## 2. QtQuick3D چیست؟

### 2.1 Qt3D vs QtQuick3D

**توجه مهم:** این دو فریمورک کاملاً متفاوتند!

| ویژگی | Qt3D | QtQuick3D |
|-------|------|-----------|
| معماری | Entity-Component-System (ECS) | QML-based Scene Graph |
| سختی | پیچیده‌تر | ساده‌تر |
| یکپارچگی با QML | ضعیف | عالی |
| مناسب برای | بازی‌های پیچیده | اپ‌های UI-محور |

**ما از QtQuick3D استفاده می‌کنیم** چون QField یک اپ QML-محور است.

### 2.2 کامپوننت‌های اصلی QtQuick3D

```qml
// 1. View3D - پنجره‌ای به دنیای 3D
View3D {
    anchors.fill: parent

    // 2. SceneEnvironment - تنظیمات کلی صحنه
    environment: SceneEnvironment {
        clearColor: "#87CEEB"  // رنگ آسمان
        antialiasingMode: SceneEnvironment.MSAA
    }

    // 3. PerspectiveCamera - دوربین
    PerspectiveCamera {
        id: camera
        position: Qt.vector3d(0, 100, 200)
    }

    // 4. DirectionalLight - نور خورشید
    DirectionalLight {
        eulerRotation: Qt.vector3d(-45, -45, 0)
    }

    // 5. Model - یک شیء 3D
    Model {
        source: "#Cube"  // شکل آماده
        materials: PrincipledMaterial {
            baseColor: "red"
        }
    }
}
```

### 2.3 QQuick3DGeometry - ساخت Mesh سفارشی

وقتی می‌خواهی شکل خودت را بسازی (نه مکعب/کره آماده):

```cpp
class MyGeometry : public QQuick3DGeometry {
    void updateGeometry() {
        // 1. تعریف vertex ها
        QByteArray vertexData;
        // ... پر کردن با موقعیت + نرمال + UV

        // 2. تعریف index ها (کدام vertex ها مثلث بسازند)
        QByteArray indexData;
        // ...

        // 3. ست کردن داده‌ها
        setVertexData(vertexData);
        setIndexData(indexData);

        // 4. تعریف attribute ها
        addAttribute(PositionSemantic, ...);
        addAttribute(NormalSemantic, ...);
        addAttribute(TexCoordSemantic, ...);
    }
};
```

---

## 3. ما در این پروژه چه می‌کنیم؟

### 3.1 هدف کلی

**نمایش نقشه به صورت سه‌بعدی:**
1. خواندن داده ارتفاع (DEM) از پروژه QGIS
2. ساختن یک سطح سه‌بعدی از آن
3. کشیدن تصویر ماهواره‌ای روی آن سطح
4. اجازه چرخش/زوم به کاربر

```
  ورودی‌ها:                          خروجی:

  ┌─────────────┐
  │ DEM File    │                       ⛰️🛰️
  │ (ارتفاع)    │    ──────────►      /      \
  └─────────────┘                    /  نقشه  \
  ┌─────────────┐                   /    3D    \
  │ Satellite   │                  ─────────────
  │ (تصویر)     │
  └─────────────┘
```

### 3.2 مراحل کار

```
┌──────────────────────────────────────────────────────────────┐
│  1. QgsQuick3DTerrainProvider                                │
│     ↓ خواندن DEM از پروژه QGIS                               │
│     ↓ تبدیل سیستم مختصات (CRS)                               │
│     ↓ نمونه‌برداری ارتفاعات در یک grid                        │
├──────────────────────────────────────────────────────────────┤
│  2. QgsQuick3DTerrainGeometry                                │
│     ↓ دریافت آرایه ارتفاعات                                  │
│     ↓ ساخت vertex ها (موقعیت + نرمال + UV)                   │
│     ↓ ساخت index ها (مثلث‌ها)                                │
│     ↓ تولید Mesh سه‌بعدی                                     │
├──────────────────────────────────────────────────────────────┤
│  3. QgsQuick3DMapTextureGenerator                            │
│     ↓ رندر کردن لایه‌های نقشه به تصویر                       │
│     ↓ ذخیره به فایل موقت                                     │
│     ↓ بارگذاری به عنوان Texture                              │
├──────────────────────────────────────────────────────────────┤
│  4. Map3DView.qml                                            │
│     ↓ نمایش Mesh + Texture                                   │
│     ↓ نورپردازی                                              │
│     ↓ کنترل دوربین                                           │
└──────────────────────────────────────────────────────────────┘
```

---

## 4. معماری کد

### 4.1 نمای کلی فایل‌ها

```
src/
├── core/sketquick3d/
│   ├── qgsquick3dterrainprovider.cpp/.h    # خواندن DEM
│   ├── qgsquick3dterraingeometry.cpp/.h    # ساخت Mesh
│   └── qgsquick3dmaptexturegenerator.cpp/.h # ساخت Texture
│
└── qml/3d/
    ├── Map3DView.qml           # صحنه اصلی 3D
    ├── TerrainMesh.qml         # کامپوننت زمین
    └── TouchCameraController.qml # کنترل دوربین
```

### 4.2 جریان داده (Data Flow)

```
┌─────────────────┐
│  QGIS Project   │
│  (پروژه QGIS)   │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────────────────┐
│              QgsQuick3DTerrainProvider              │
│  ┌─────────────────────────────────────────────┐   │
│  │ • خواندن تنظیمات Terrain از پروژه            │   │
│  │ • پیدا کردن لایه DEM                         │   │
│  │ • تبدیل CRS (سیستم مختصات)                   │   │
│  │ • خروجی: آرایه ارتفاعات [h1, h2, h3, ...]   │   │
│  └─────────────────────────────────────────────┘   │
└────────┬────────────────────────────────────────────┘
         │ heights[]
         ▼
┌─────────────────────────────────────────────────────┐
│              QgsQuick3DTerrainGeometry              │
│  ┌─────────────────────────────────────────────┐   │
│  │ • دریافت آرایه ارتفاعات                      │   │
│  │ • ساخت grid از vertex ها                    │   │
│  │ • محاسبه نرمال‌ها برای نورپردازی            │   │
│  │ • ساخت مثلث‌ها (indices)                    │   │
│  │ • خروجی: Mesh آماده رندر                    │   │
│  └─────────────────────────────────────────────┘   │
└────────┬────────────────────────────────────────────┘
         │ Mesh
         ▼
┌─────────────────────────────────────────────────────┐
│                    TerrainMesh.qml                  │
│  ┌─────────────────────────────────────────────┐   │
│  │ Model {                                     │   │
│  │   geometry: QgsQuick3DTerrainGeometry {...} │   │
│  │   materials: PrincipledMaterial {           │   │
│  │     baseColorMap: satelliteTexture          │   │
│  │   }                                         │   │
│  │ }                                           │   │
│  └─────────────────────────────────────────────┘   │
└────────┬────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────┐
│                    Map3DView.qml                    │
│  ┌─────────────────────────────────────────────┐   │
│  │ View3D {                                    │   │
│  │   PerspectiveCamera { ... }                 │   │
│  │   DirectionalLight { ... }                  │   │
│  │   TerrainMesh { ... }                       │   │
│  │ }                                           │   │
│  │ TouchCameraController { ... }               │   │
│  └─────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

---

## 5. جزئیات هر کامپوننت

### 5.1 QgsQuick3DTerrainProvider (C++)

**وظیفه:** خواندن داده ارتفاع از پروژه QGIS

```cpp
// ورودی‌ها (Properties):
property QgsProject* project;     // پروژه QGIS
property int resolution;          // تعداد نقاط (مثلاً 64×64)
property double verticalExaggeration; // اغراق عمودی
property QRectF extent;           // محدوده جغرافیایی

// خروجی‌ها:
bool hasTerrainData;              // آیا DEM داریم؟
QString terrainType;              // نوع terrain (raster, mesh, flat)
QRectF demExtent;                 // محدوده واقعی DEM

// متدها:
QVariantList sampleHeightGrid();  // نمونه‌برداری ارتفاعات
double heightAt(x, y);            // ارتفاع در نقطه خاص
```

**چگونه کار می‌کند:**

```
1. پروژه QGIS باز می‌شود
         ↓
2. از Project → Elevation Properties می‌خواند
         ↓
3. لایه DEM را پیدا می‌کند
         ↓
4. برای هر نقطه در grid:
   - مختصات را به CRS لایه تبدیل می‌کند
   - ارتفاع را از raster می‌خواند
         ↓
5. آرایه ارتفاعات را برمی‌گرداند
```

**مثال خروجی:**
```javascript
// برای یک grid 4×4:
heights = [
  100, 150, 200, 180,    // ردیف 1
  120, 300, 250, 190,    // ردیف 2 (300 = قله کوه)
  110, 200, 180, 170,    // ردیف 3
  105, 130, 140, 160     // ردیف 4
]
```

### 5.2 QgsQuick3DTerrainGeometry (C++)

**وظیفه:** ساختن Mesh سه‌بعدی از آرایه ارتفاعات

```cpp
// ورودی‌ها:
property int resolution;          // تعداد vertex در هر بعد
property float terrainSize;       // اندازه کل terrain
property float heightScale;       // ضریب ارتفاع
property QVariantList heightData; // آرایه ارتفاعات

// متدها:
void generateProceduralTerrain(); // ساخت terrain تستی (سینوسی)
```

**چگونه Mesh ساخته می‌شود:**

```
آرایه ارتفاعات:              Mesh سه‌بعدی:
[100, 150, 200]
[120, 300, 250]      →      یک grid از مثلث‌ها
[110, 200, 180]             با ارتفاعات متفاوت
```

**ساختار هر Vertex:**
```cpp
struct Vertex {
    float x, y, z;      // موقعیت (position)
    float nx, ny, nz;   // نرمال (برای نورپردازی)
    float u, v;         // مختصات texture
};
// مجموعاً: 8 float = 32 bytes
```

**الگوریتم ساخت:**
```cpp
for (row = 0; row < resolution; row++) {
    for (col = 0; col < resolution; col++) {
        // 1. Position
        x = col * cellSize - halfSize;  // از -500 تا +500
        y = heights[row * resolution + col];  // ارتفاع
        z = row * cellSize - halfSize;

        // 2. Normal (از تفاوت ارتفاع همسایه‌ها)
        normal = calculateNormal(row, col);

        // 3. UV (برای texture)
        u = col / (resolution - 1);  // 0 تا 1
        v = row / (resolution - 1);
    }
}
```

**ساخت مثلث‌ها (Indices):**
```
هر سلول grid = 2 مثلث:

  v0 ---- v1          مثلث 1: [v0, v2, v1]
   |    / |           مثلث 2: [v1, v2, v3]
   |   /  |
   |  /   |
   | /    |
  v2 ---- v3
```

### 5.3 QgsQuick3DMapTextureGenerator (C++)

**وظیفه:** رندر کردن لایه‌های نقشه به یک تصویر (texture)

```cpp
// ورودی‌ها:
property QgsProject* project;     // پروژه QGIS
property QRectF extent;           // محدوده
property int textureSize;         // اندازه تصویر (مثلاً 2048)

// خروجی‌ها:
bool ready;                       // آیا texture آماده است؟
QString textureFilePath;          // مسیر فایل تصویر

// سیگنال‌ها:
signal textureReady();            // وقتی رندر تمام شد
signal renderError(QString);      // در صورت خطا
```

**چگونه کار می‌کند:**

```
1. لایه‌های مناسب را پیدا می‌کند:
   - لایه‌های چندبانده (تصویر ماهواره‌ای)
   - لایه‌های WMS (نقشه آنلاین)
   - لایه‌های تک‌بانده را رد می‌کند (معمولاً DEM هستند)
         ↓
2. QgsMapSettings را تنظیم می‌کند:
   - extent: همان محدوده terrain
   - size: 2048×2048 پیکسل
   - CRS: سیستم مختصات پروژه
         ↓
3. با QgsMapRendererSequentialJob رندر می‌کند
         ↓
4. تصویر را به /tmp/qfield_3d_texture_*.png ذخیره می‌کند
         ↓
5. سیگنال textureReady() را emit می‌کند
```

### 5.4 Map3DView.qml

**وظیفه:** صحنه اصلی 3D - همه چیز را کنار هم می‌چیند

```qml
Item {
    // ═══════════════ داده‌ها ═══════════════

    // خواننده DEM
    QgsQuick3DTerrainProvider {
        id: terrainProvider
        project: root.qgisProject
        resolution: 64
    }

    // سازنده texture
    QgsQuick3DMapTextureGenerator {
        id: textureGenerator
        project: root.qgisProject
        extent: root.mapExtent
        textureSize: 2048
    }

    // texture ماهواره‌ای
    Texture {
        id: satelliteTexture
        source: textureGenerator.textureFilePath
    }

    // ═══════════════ صحنه 3D ═══════════════

    View3D {
        // محیط
        environment: SceneEnvironment {
            clearColor: "#87CEEB"  // آسمان آبی
        }

        // دوربین
        PerspectiveCamera {
            id: camera
        }

        // نور خورشید
        DirectionalLight {
            eulerRotation: Qt.vector3d(-45, -45, 0)
        }

        // زمین!
        TerrainMesh {
            id: terrainMesh
            satelliteTexture: satelliteTexture
        }
    }

    // ═══════════════ کنترل‌ها ═══════════════

    TouchCameraController {
        camera: camera
    }
}
```

**جریان اجرا:**
```
1. پروژه QGIS لود می‌شود
         ↓
2. terrainProvider سیگنال terrainDataReady می‌دهد
         ↓
3. loadRealTerrain() صدا زده می‌شود:
   - ارتفاعات را می‌گیرد
   - نرمالایز می‌کند
   - به terrainMesh می‌دهد
         ↓
4. textureGenerator.render() صدا زده می‌شود
         ↓
5. وقتی texture آماده شد، روی terrain نمایش داده می‌شود
```

### 5.5 TerrainMesh.qml

**وظیفه:** نمایش mesh زمین با material مناسب

```qml
Node {
    // ورودی‌ها
    property int resolution: 64
    property real terrainSize: 1000
    property var heightData: []
    property var satelliteTexture: null

    // Texture چمن (وقتی ماهواره‌ای نداریم)
    Texture {
        id: grassTexture
        sourceItem: Canvas {
            // رسم چمن با gradient سبز + noise
        }
    }

    // مدل اصلی
    Model {
        geometry: QgsQuick3DTerrainGeometry {
            resolution: root.resolution
            terrainSize: root.terrainSize
            heightData: root.heightData
        }

        materials: PrincipledMaterial {
            // اگر texture ماهواره‌ای داریم: آن را استفاده کن
            // وگرنه: از چمن استفاده کن
            baseColorMap: satelliteTexture ?? grassTexture
            roughness: 0.9  // سطح زبر (نه براق)
            metalness: 0.0  // فلزی نیست
        }
    }
}
```

### 5.6 TouchCameraController.qml

**وظیفه:** کنترل دوربین با تاچ و ماوس

**سیستم مختصات کروی (Spherical):**
```
دوربین همیشه روی یک کره فرضی است:
- target: مرکز کره (نقطه‌ای که نگاه می‌کنیم)
- distance: شعاع کره
- yaw: زاویه افقی (چرخش دور target)
- pitch: زاویه عمودی (بالا/پایین)

         * camera
          \
           \  distance
            \
      -------●------- target
            /|\
           / | \
          yaw pitch
```

**تبدیل Spherical به Cartesian:**
```javascript
function updateCameraPosition() {
    var elevationRad = pitch * Math.PI / 180;
    var yawRad = yaw * Math.PI / 180;

    var horizontalDist = distance * Math.cos(elevationRad);

    var x = target.x + horizontalDist * Math.sin(yawRad);
    var y = target.y + distance * Math.sin(elevationRad);
    var z = target.z + horizontalDist * Math.cos(yawRad);

    camera.position = Qt.vector3d(x, y, z);
    camera.lookAt(target);
}
```

**کنترل‌ها:**
```
┌────────────────────────────────────────┐
│  1 انگشت: چرخش (Orbit)                │
│     ← → : تغییر yaw                    │
│     ↑ ↓ : تغییر pitch                  │
├────────────────────────────────────────┤
│  2 انگشت: جابجایی + زوم               │
│     کشیدن: Pan (جابجایی target)        │
│     نزدیک/دور: Pinch zoom              │
├────────────────────────────────────────┤
│  دوبار تپ: Reset view                  │
├────────────────────────────────────────┤
│  ماوس:                                 │
│     Drag: چرخش                         │
│     Wheel: زوم                         │
└────────────────────────────────────────┘
```

**Inertia (اینرسی):**
```
وقتی انگشت را برمی‌داری، دوربین یکدفعه نمی‌ایستد.
به آرامی کند می‌شود (مثل چرخ دنده که می‌چرخد).

velocityYaw *= 0.95;  // هر فریم 5% کم می‌شود
velocityPitch *= 0.95;

اگر velocity < 0.05 → توقف کامل
```

---

## 6. چگونه همه چیز کنار هم کار می‌کند

### 6.1 Timeline اجرا

```
┌─────────────────────────────────────────────────────────────┐
│ T=0: کاربر دکمه 3D را می‌زند                                │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ T=1: Map3DView.qml لود می‌شود                               │
│      - View3D ساخته می‌شود                                  │
│      - دوربین در موقعیت پیش‌فرض                             │
│      - terrain خالی (فقط procedural)                        │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ T=2: terrainProvider پروژه را اسکن می‌کند                  │
│      - DEM layer پیدا می‌شود                                │
│      - سیگنال terrainDataReady()                           │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ T=3: loadRealTerrain() اجرا می‌شود                         │
│      - sampleHeightGrid() → آرایه ارتفاعات                 │
│      - نرمالایز کردن (مثلاً 0-600 متر → 0-600 واحد 3D)     │
│      - terrainMesh.heightData = heights                    │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ T=4: QgsQuick3DTerrainGeometry به‌روز می‌شود               │
│      - ساخت vertex ها (64×64 = 4096 نقطه)                  │
│      - ساخت indices (63×63×2 = 7938 مثلث)                  │
│      - Mesh آماده نمایش                                     │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ T=5: textureGenerator.render() شروع می‌شود                 │
│      - لایه‌های satellite/aerial پیدا می‌شوند              │
│      - رندر به تصویر 2048×2048                             │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ T=6: Texture آماده می‌شود                                   │
│      - فایل ذخیره می‌شود                                    │
│      - satelliteTexture.source = فایل                      │
│      - Material به‌روز می‌شود                               │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ T=7+: کاربر با terrain تعامل می‌کند                         │
│      - چرخش، زوم، pan                                       │
│      - دوربین به‌روز می‌شود                                 │
│      - هر فریم رندر می‌شود                                  │
└─────────────────────────────────────────────────────────────┘
```

### 6.2 چرا این معماری؟

**جداسازی concerns:**
```
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  Data Layer     │  │  Geometry Layer │  │  View Layer     │
│  (C++)          │  │  (C++)          │  │  (QML)          │
├─────────────────┤  ├─────────────────┤  ├─────────────────┤
│ TerrainProvider │→ │ TerrainGeometry │→ │ TerrainMesh     │
│ TextureGenerator│  │                 │  │ Map3DView       │
│                 │  │                 │  │ CameraController│
└─────────────────┘  └─────────────────┘  └─────────────────┘

هر لایه فقط یک کار انجام می‌دهد:
- Data: خواندن از QGIS
- Geometry: ساخت Mesh
- View: نمایش و تعامل
```

**چرا C++ برای بعضی‌ها؟**
- **Performance:** پردازش هزاران vertex در JS کند است
- **QGIS Integration:** API های QGIS در C++ هستند
- **Memory:** کنترل دقیق‌تر حافظه

**چرا QML برای بعضی‌ها؟**
- **Declarative:** راحت‌تر برای UI
- **Hot Reload:** تغییرات سریع‌تر اعمال می‌شوند
- **Bindings:** اتصال خودکار property ها

---

## خلاصه

```
┌──────────────────────────────────────────────────────────┐
│                    QField 3D Viewer                      │
├──────────────────────────────────────────────────────────┤
│                                                          │
│   QGIS Project                                           │
│        │                                                 │
│        ▼                                                 │
│   ┌──────────────┐      ┌──────────────┐                │
│   │ Terrain      │      │ Texture      │                │
│   │ Provider     │      │ Generator    │                │
│   └──────┬───────┘      └──────┬───────┘                │
│          │                      │                        │
│          ▼                      ▼                        │
│   ┌──────────────┐      ┌──────────────┐                │
│   │ Terrain      │      │ Satellite    │                │
│   │ Geometry     │      │ Texture      │                │
│   └──────┬───────┘      └──────┬───────┘                │
│          │                      │                        │
│          └──────────┬───────────┘                        │
│                     ▼                                    │
│              ┌──────────────┐                            │
│              │ TerrainMesh  │ ← Material + Geometry      │
│              └──────┬───────┘                            │
│                     ▼                                    │
│              ┌──────────────┐                            │
│              │   View3D     │ ← Camera + Lights          │
│              └──────┬───────┘                            │
│                     ▼                                    │
│              ┌──────────────┐                            │
│              │ TouchCamera  │ ← User Input               │
│              │ Controller   │                            │
│              └──────────────┘                            │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

**تمام!** 🎉

حالا می‌دونی:
1. Mesh چیه و چطور ساخته می‌شه
2. Texture چیه و چطور روی سطح می‌افته
3. Terrain چیه و چطور از DEM می‌سازیمش
4. هر کامپوننت چه کاری انجام می‌ده
5. چطور همه چیز کنار هم کار می‌کنه

سوالی داشتی بپرس! 😊
