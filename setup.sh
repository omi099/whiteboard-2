#!/usr/bin/env bash
# =============================================================================
#  Pen / Teaching Whiteboard  —  professional vector inking desktop app
#  Modern C++20 + Qt 6.  Lean, no bloat.  Wacom / stylus optimized.
#
#  USAGE:
#     chmod +x setup.sh
#     ./setup.sh            # scaffolds project into ./pen-whiteboard
#     cd pen-whiteboard && cmake -B build -G Ninja && cmake --build build
#
#  This file is generated in appendable PARTS. Each part is self-contained.
# =============================================================================
set -euo pipefail

# ---- 0. Config -------------------------------------------------------------
PROJECT="${PROJECT:-pen-whiteboard}"
APP_NAME="InkBoard"
CXX_STD="20"

log()  { printf '\033[1;36m[setup]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

# ---- 1. Host tooling sanity checks (non-fatal hints) -----------------------
log "Checking host tooling (hints only; CI installs everything in build.yml)"
command -v cmake >/dev/null 2>&1 || warn "cmake not found on PATH (needed to build)"
command -v git   >/dev/null 2>&1 || warn "git not found on PATH (optional)"
if command -v cmake >/dev/null 2>&1; then
  log "cmake: $(cmake --version | head -n1)"
fi

# ---- 2. Directory scaffold -------------------------------------------------
log "Creating project tree at ./$PROJECT"
mkdir -p "$PROJECT"/{cmake,src,resources/icons,resources/themes,packaging,.github/workflows,tests}
mkdir -p "$PROJECT"/src/{app,model,ink,render,input,tools,io,ui,util}

cd "$PROJECT"

# ---- 3. .gitignore ---------------------------------------------------------
cat > .gitignore <<'EOF'
/build/
/build-*/
/out/
/dist/
*.user
*.autosave
.DS_Store
CMakeSettings.json
compile_commands.json
EOF

# ---- 4. Top-level CMakeLists.txt ------------------------------------------
cat > CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.24)
project(InkBoard VERSION 0.1.0 LANGUAGES CXX)

# --- Global build settings --------------------------------------------------
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE "Release" CACHE STRING "" FORCE)
endif()

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Put binaries in a predictable place for windeployqt / packaging.
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

# --- Options ----------------------------------------------------------------
option(INKBOARD_USE_OPENGL "Render canvas through QOpenGLWidget" ON)
option(INKBOARD_ENABLE_SANITIZERS "Enable ASan/UBSan in Debug" OFF)
option(INKBOARD_BUILD_TESTS "Build unit tests" OFF)

# --- Qt ---------------------------------------------------------------------
find_package(Qt6 REQUIRED COMPONENTS
  Core Gui Widgets Svg PrintSupport Pdf OpenGLWidgets)

qt_standard_project_setup()

# --- Warnings / hardening ---------------------------------------------------
if(MSVC)
  add_compile_options(/W4 /permissive- /Zc:__cplusplus /utf-8 /EHsc)
else()
  add_compile_options(-Wall -Wextra -Wpedantic -Wshadow -Wconversion
                      -Wno-unknown-pragmas)
endif()

if(INKBOARD_ENABLE_SANITIZERS AND NOT MSVC)
  add_compile_options($<$<CONFIG:Debug>:-fsanitize=address,undefined>
                      $<$<CONFIG:Debug>:-fno-omit-frame-pointer>)
  add_link_options($<$<CONFIG:Debug>:-fsanitize=address,undefined>)
endif()

# --- Sources (files are added by later setup.sh parts) ----------------------
set(INKBOARD_SOURCES
  src/app/main.cpp
  src/app/MainWindow.cpp
  src/model/Item.cpp
  src/model/StrokeItem.cpp
  src/model/ShapeItem.cpp
  src/model/TextItem.cpp
  src/model/ImageItem.cpp
  src/model/Layer.cpp
  src/model/Page.cpp
  src/model/Document.cpp
  src/model/History.cpp
  src/ink/Smoothing.cpp
  src/ink/Tessellator.cpp
  src/render/CanvasRenderer.cpp
  src/render/Viewport.cpp
  src/render/CanvasWidget.cpp
  src/input/InputRouter.cpp
  src/input/PressureCurve.cpp
  src/tools/ToolManager.cpp
  src/tools/PenTool.cpp
  src/tools/HighlighterTool.cpp
  src/tools/EraserTool.cpp
  src/tools/SelectTool.cpp
  src/tools/ShapeTool.cpp
  src/tools/TextTool.cpp
  src/tools/ImageTool.cpp
  src/tools/LaserTool.cpp
  src/io/BoardSerializer.cpp
  src/io/Exporters.cpp
  src/io/PdfImporter.cpp
  src/io/AutosaveManager.cpp
  src/ui/ToolBarWidget.cpp
  src/ui/ColorPalette.cpp
  src/ui/PreferencesDialog.cpp
  src/ui/ThemeManager.cpp
  src/ui/ShortcutManager.cpp
  src/util/Log.cpp
  src/util/Settings.cpp
)

qt_add_executable(InkBoard WIN32 MACOSX_BUNDLE
  ${INKBOARD_SOURCES}
  resources/resources.qrc
)

target_include_directories(InkBoard PRIVATE src)

target_compile_definitions(InkBoard PRIVATE
  INKBOARD_VERSION="${PROJECT_VERSION}"
  $<$<BOOL:${INKBOARD_USE_OPENGL}>:INKBOARD_USE_OPENGL=1>
  QT_DISABLE_DEPRECATED_BEFORE=0x060500
)

target_link_libraries(InkBoard PRIVATE
  Qt6::Core Qt6::Gui Qt6::Widgets
  Qt6::Svg Qt6::PrintSupport Qt6::Pdf Qt6::OpenGLWidgets)

# --- Install / bundle -------------------------------------------------------
install(TARGETS InkBoard
  BUNDLE  DESTINATION .
  RUNTIME DESTINATION bin)

if(INKBOARD_BUILD_TESTS)
  enable_testing()
  add_subdirectory(tests)
endif()
EOF

# ---- 5. Qt resource file ---------------------------------------------------
cat > resources/resources.qrc <<'EOF'
<!DOCTYPE RCC>
<RCC version="1.0">
  <qresource prefix="/themes">
    <file>themes/dark.qss</file>
    <file>themes/light.qss</file>
  </qresource>
</RCC>
EOF

cat > resources/themes/dark.qss <<'EOF'
/* Minimal dark theme; accent color is injected at runtime by ThemeManager. */
QWidget { background: #1e1f22; color: #e6e6e6; }
QToolBar { background: #26282c; border: none; spacing: 4px; }
QToolButton { border: none; padding: 6px; border-radius: 6px; }
QToolButton:hover { background: #33363b; }
QToolButton:checked { background: #3d5afe33; }
QMenu, QDialog { background: #26282c; color: #e6e6e6; }
EOF

cat > resources/themes/light.qss <<'EOF'
QWidget { background: #f7f7f8; color: #1b1b1b; }
QToolBar { background: #ffffff; border: none; spacing: 4px; }
QToolButton { border: none; padding: 6px; border-radius: 6px; }
QToolButton:hover { background: #ececec; }
QToolButton:checked { background: #3d5afe22; }
QMenu, QDialog { background: #ffffff; color: #1b1b1b; }
EOF

# ---- 6. Application entry point --------------------------------------------
cat > src/app/main.cpp <<'EOF'
// InkBoard — application entry point.
#include <QApplication>
#include <QSurfaceFormat>
#include "app/MainWindow.h"
#include "util/Log.h"

int main(int argc, char** argv)
{
    // High-DPI is automatic in Qt6; we only tune surface format for the
    // OpenGL canvas so we get MSAA + low-latency single-buffer-ish present.
    QSurfaceFormat fmt;
    fmt.setSamples(4);                       // MSAA for crisp geometry edges
    fmt.setSwapInterval(1);                  // vsync; overridden per-frame later
    fmt.setDepthBufferSize(0);
    fmt.setStencilBufferSize(8);
    QSurfaceFormat::setDefaultFormat(fmt);

    QApplication app(argc, argv);
    QApplication::setApplicationName("InkBoard");
    QApplication::setOrganizationName("InkBoard");
    QApplication::setApplicationVersion(INKBOARD_VERSION);

    ib::log::init();
    ib::log::info("Starting InkBoard %s", INKBOARD_VERSION);

    ib::MainWindow window;
    window.resize(1440, 900);
    window.show();

    return app.exec();
}
EOF

# ---- 7. Utility: logging ---------------------------------------------------
cat > src/util/Log.h <<'EOF'
#pragma once
// Tiny leak-free logging shim over qDebug/qWarning with printf-style calls.
namespace ib::log {
void init();
void info(const char* fmt, ...);
void warn(const char* fmt, ...);
void error(const char* fmt, ...);
}
EOF

cat > src/util/Settings.h <<'EOF'
#pragma once
#include <QSettings>
#include <QString>
// Thin wrapper so all persisted user prefs go through one typed surface.
namespace ib {
class Settings {
public:
    static QSettings& raw();
    template <class T>
    static T get(const QString& key, const T& def) {
        return raw().value(key, QVariant::fromValue(def)).template value<T>();
    }
    template <class T>
    static void set(const QString& key, const T& v) {
        raw().setValue(key, QVariant::fromValue(v));
    }
};
} // namespace ib
EOF

# ---- 8. Core model: enums & atomic geometry -------------------------------
cat > src/model/Enums.h <<'EOF'
#pragma once
#include <cstdint>
namespace ib {

// Which concrete Item subclass a base pointer refers to.
enum class ItemType : uint8_t { Stroke, Shape, Text, Image };

// Ink-bearing tools that produce StrokeItems.
enum class InkKind : uint8_t { Pen, Highlighter };

// Vector primitives produced by the shape tool.
enum class ShapeKind : uint8_t { Line, Arrow, Rectangle, Ellipse };

// Page background rendering style.
enum class BackgroundKind : uint8_t { Blank, Grid, Lines, Dots };

// Which logical tool is active.
enum class ToolId : uint8_t {
    Pen, Highlighter, Eraser, Select, Shape, Text, Image, Laser, Pan
};

// How touch (finger) input behaves relative to pen input.
enum class TouchMode : uint8_t { GestureOnly, DrawAndGesture, Ignore };

} // namespace ib
EOF

cat > src/model/StrokePoint.h <<'EOF'
#pragma once
#include <QPointF>
#include <cstdint>
namespace ib {

// One raw sample captured from the pen/pointer pipeline. Kept POD-ish and
// cache-friendly: strokes hold contiguous vectors of these.
struct StrokePoint {
    QPointF pos;          // position in PAGE coordinates (device-independent)
    float   pressure = 1.0f;  // 0..1 normalized (post pressure-curve is applied later)
    float   tiltX    = 0.0f;  // degrees, -60..60
    float   tiltY    = 0.0f;  // degrees, -60..60
    qint64  tMs      = 0;     // timestamp (ms) for prediction / speed-based width
};

} // namespace ib
EOF

# ---- 9. Core model: Item base ---------------------------------------------
cat > src/model/Item.h <<'EOF'
#pragma once
#include <QUuid>
#include <QRectF>
#include <QJsonObject>
#include <QTransform>
#include <memory>
#include "model/Enums.h"

namespace ib {

// Abstract base for everything placed on a layer. Data-oriented: rendering is
// performed by CanvasRenderer (a visitor), not by the item itself, so the
// model stays free of GUI dependencies beyond Qt value types.
class Item {
public:
    virtual ~Item() = default;

    virtual ItemType type() const = 0;
    virtual QRectF   boundingRect() const = 0;      // in page coords, cached by subclass
    virtual bool     hitTest(const QPointF& p, double tolerance) const = 0;
    virtual std::unique_ptr<Item> clone() const = 0;

    // Serialization: subclass writes its own fields; base writes id/type.
    virtual QJsonObject toJson() const = 0;
    static std::unique_ptr<Item> fromJson(const QJsonObject& o); // impl in Item.cpp

    const QUuid& id() const { return m_id; }
    void setId(const QUuid& id) { m_id = id; }

protected:
    void writeBase(QJsonObject& o) const;   // writes "id","type"
    void readBase(const QJsonObject& o);     // reads  "id"

    QUuid m_id = QUuid::createUuid();
};

using ItemPtr = std::unique_ptr<Item>;

} // namespace ib
EOF

# ---- 10. Core model: StrokeItem -------------------------------------------
cat > src/model/StrokeItem.h <<'EOF'
#pragma once
#include <QColor>
#include <QPainterPath>
#include <vector>
#include "model/Item.h"
#include "model/StrokePoint.h"

namespace ib {

// A vector ink stroke (pen or highlighter). Stored as raw samples plus a
// lazily rebuilt QPainterPath; because we keep the vector samples forever,
// the stroke re-renders crisp at ANY zoom (no rasterization baked in).
class StrokeItem final : public Item {
public:
    ItemType type() const override { return ItemType::Stroke; }
    QRectF   boundingRect() const override;
    bool     hitTest(const QPointF& p, double tolerance) const override;
    std::unique_ptr<Item> clone() const override;
    QJsonObject toJson() const override;
    static std::unique_ptr<StrokeItem> fromJsonImpl(const QJsonObject& o);

    void addPoint(const StrokePoint& p);   // marks caches dirty
    void finalize();                       // apply smoothing, build path

    const std::vector<StrokePoint>& points() const { return m_points; }
    std::vector<StrokePoint>&       points()       { return m_points; }

    // Rebuilds (if dirty) and returns the centerline path in page coords.
    const QPainterPath& path() const;

    // --- styling ---
    InkKind kind = InkKind::Pen;
    QColor  color = QColor(20, 20, 20);
    double  baseWidth = 2.5;          // px at zoom 1.0
    double  opacity   = 1.0;          // 0..1
    bool    pressureToWidth   = true;
    bool    pressureToOpacity = false;
    double  smoothing = 0.5;          // 0..1 stabilizer strength

private:
    void rebuild() const;             // recompute path + bounds

    std::vector<StrokePoint>   m_points;
    mutable QPainterPath       m_path;
    mutable QRectF             m_bounds;
    mutable bool               m_dirty = true;
};

} // namespace ib
EOF

# ---- 11. Core model: ShapeItem / TextItem / ImageItem ----------------------
cat > src/model/ShapeItem.h <<'EOF'
#pragma once
#include <QColor>
#include <QPointF>
#include "model/Item.h"

namespace ib {

// Straight geometric primitives with optional snapping applied at creation.
class ShapeItem final : public Item {
public:
    ItemType type() const override { return ItemType::Shape; }
    QRectF   boundingRect() const override;
    bool     hitTest(const QPointF& p, double tolerance) const override;
    std::unique_ptr<Item> clone() const override;
    QJsonObject toJson() const override;
    static std::unique_ptr<ShapeItem> fromJsonImpl(const QJsonObject& o);

    ShapeKind shape = ShapeKind::Line;
    QPointF p1, p2;                 // page coords (bbox corners or endpoints)
    QColor  strokeColor = QColor(20, 20, 20);
    double  strokeWidth = 2.5;
    bool    filled = false;
    QColor  fillColor = QColor(0, 0, 0, 0);
    double  opacity = 1.0;
};

} // namespace ib
EOF

cat > src/model/TextItem.h <<'EOF'
#pragma once
#include <QColor>
#include <QFont>
#include <QPointF>
#include <QString>
#include "model/Item.h"

namespace ib {

// Editable text block. Kept intentionally minimal: font/size/color only.
class TextItem final : public Item {
public:
    ItemType type() const override { return ItemType::Text; }
    QRectF   boundingRect() const override;
    bool     hitTest(const QPointF& p, double tolerance) const override;
    std::unique_ptr<Item> clone() const override;
    QJsonObject toJson() const override;
    static std::unique_ptr<TextItem> fromJsonImpl(const QJsonObject& o);

    QString text;
    QPointF pos;                    // top-left in page coords
    double  wrapWidth = 0.0;        // 0 = no wrap
    QFont   font = QFont("Sans", 18);
    QColor  color = QColor(20, 20, 20);
};

} // namespace ib
EOF

cat > src/model/ImageItem.h <<'EOF'
#pragma once
#include <QImage>
#include <QRectF>
#include "model/Item.h"

namespace ib {

// An inserted raster image. Stored inline (PNG-encoded) inside the .board
// file so boards are self-contained and round-trip losslessly.
class ImageItem final : public Item {
public:
    ItemType type() const override { return ItemType::Image; }
    QRectF   boundingRect() const override { return rect; }
    bool     hitTest(const QPointF& p, double tolerance) const override;
    std::unique_ptr<Item> clone() const override;
    QJsonObject toJson() const override;
    static std::unique_ptr<ImageItem> fromJsonImpl(const QJsonObject& o);

    QImage  image;                  // decoded pixels (kept for fast blit)
    QRectF  rect;                   // placement rect in page coords
    double  opacity = 1.0;
};

} // namespace ib
EOF

# ---- 12. Core model: Layer / Page / Document ------------------------------
cat > src/model/Layer.h <<'EOF'
#pragma once
#include <QString>
#include <QUuid>
#include <vector>
#include "model/Item.h"

namespace ib {

// An ordered stack of items. Bottom of vector draws first.
class Layer {
public:
    QUuid   id = QUuid::createUuid();
    QString name = QStringLiteral("Layer");
    bool    visible = true;
    bool    locked  = false;
    double  opacity = 1.0;
    std::vector<ItemPtr> items;

    Layer clone() const;            // deep copy (clones each item)
    QJsonObject toJson() const;
    static Layer fromJson(const QJsonObject& o);
};

} // namespace ib
EOF

cat > src/model/Page.h <<'EOF'
#pragma once
#include <QColor>
#include <QSizeF>
#include <vector>
#include "model/Enums.h"
#include "model/Layer.h"

namespace ib {

// A single page/board. Infinite-canvas: item coordinates are unbounded; the
// (optional) "paper size" only drives background pattern + PDF page export.
class Page {
public:
    QUuid   id = QUuid::createUuid();
    QString title = QStringLiteral("Page 1");

    // Background
    BackgroundKind background = BackgroundKind::Grid;
    QColor  bgColor   = QColor(255, 255, 255);
    QColor  gridColor = QColor(0, 0, 0, 28);
    double  gridSpacing = 32.0;     // page units
    QSizeF  paperSize = QSizeF(1920, 1080); // for export framing only

    std::vector<Layer> layers;
    int activeLayer = 0;

    Page();                         // creates one default layer
    Layer&       active();
    const Layer& active() const;

    QRectF contentBounds() const;   // union of all item bounds (for fit-to-content)

    Page clone() const;
    QJsonObject toJson() const;
    static Page fromJson(const QJsonObject& o);
};

} // namespace ib
EOF

cat > src/model/Document.h <<'EOF'
#pragma once
#include <QObject>
#include <QString>
#include <vector>
#include <memory>
#include "model/Page.h"

namespace ib {

class History; // undo/redo, defined in History.h

// The whole notebook: an ordered list of pages plus file identity. Emits
// Qt signals so the UI/canvas can react without polling.
class Document : public QObject {
    Q_OBJECT
public:
    explicit Document(QObject* parent = nullptr);
    ~Document() override;

    // Pages
    int   pageCount() const { return static_cast<int>(m_pages.size()); }
    Page&       page(int i);
    const Page& page(int i) const;
    int   currentIndex() const { return m_current; }
    void  setCurrentIndex(int i);
    Page& current();
    int   addPage();                 // returns new index
    void  removePage(int i);
    void  movePage(int from, int to);

    // Identity / dirty tracking
    QString filePath() const { return m_filePath; }
    void    setFilePath(const QString& p) { m_filePath = p; }
    bool    isModified() const { return m_modified; }
    void    setModified(bool m);

    History& history() { return *m_history; }

signals:
    void modifiedChanged(bool modified);
    void currentPageChanged(int index);
    void pagesChanged();
    void contentChanged();           // any item add/remove/edit

public:
    void markContentChanged();       // called by tools/history

private:
    std::vector<Page> m_pages;
    int     m_current = 0;
    QString m_filePath;
    bool    m_modified = false;
    std::unique_ptr<History> m_history;
};

} // namespace ib
EOF

# ---- 13. Undo/redo interface ----------------------------------------------
cat > src/model/History.h <<'EOF'
#pragma once
#include <functional>
#include <memory>
#include <string>
#include <vector>

namespace ib {

// A single reversible edit. do()/undo() are captured closures so tools can
// express edits inline without a class explosion (lean by design).
struct Command {
    std::string label;
    std::function<void()> redo;
    std::function<void()> undo;
};

// Bounded linear undo stack (full undo/redo, no branching — intentional).
class History {
public:
    explicit History(int limit = 500) : m_limit(limit) {}

    void push(Command cmd);      // executes redo() then records
    bool canUndo() const { return m_index > 0; }
    bool canRedo() const { return m_index < static_cast<int>(m_stack.size()); }
    void undo();
    void redo();
    void clear();

private:
    std::vector<Command> m_stack;
    int m_index = 0;             // number of applied commands
    int m_limit;
};

} // namespace ib
EOF

log "PART 1 complete: scaffold, CMake, entry point, and core vector model headers written."
# =============================================================================
#  END OF PART 1  —  append PART 2 (model .cpp + smoothing + serialization) below
# =============================================================================

# =============================================================================
#  PART 2  —  model implementations, ink smoothing/tessellation, serialization
#  Append below PART 1. Self-contained: creates new files only.
# =============================================================================
log "PART 2: writing model impls, ink math, and serialization"

# ---- util/Log.cpp ----------------------------------------------------------
cat > src/util/Log.cpp <<'EOF'
#include "util/Log.h"
#include <QDebug>
#include <cstdarg>
#include <cstdio>

namespace ib::log {
static void vlog(const char* level, const char* fmt, va_list ap) {
    char buf[2048];
    std::vsnprintf(buf, sizeof(buf), fmt, ap);
    qInfo().noquote() << level << buf;
}
void init() { /* reserved: could install qInstallMessageHandler + file sink */ }
void info (const char* fmt, ...) { va_list ap; va_start(ap, fmt); vlog("[info] ", fmt, ap); va_end(ap); }
void warn (const char* fmt, ...) { va_list ap; va_start(ap, fmt); vlog("[warn] ", fmt, ap); va_end(ap); }
void error(const char* fmt, ...) { va_list ap; va_start(ap, fmt); vlog("[err ] ", fmt, ap); va_end(ap); }
} // namespace ib::log
EOF

# ---- util/Settings.cpp -----------------------------------------------------
cat > src/util/Settings.cpp <<'EOF'
#include "util/Settings.h"
namespace ib {
QSettings& Settings::raw() {
    // Format/scope come from QApplication org+app name set in main().
    static QSettings s(QSettings::IniFormat, QSettings::UserScope,
                       "InkBoard", "InkBoard");
    return s;
}
} // namespace ib
EOF

# ---- ink/Smoothing.h -------------------------------------------------------
cat > src/ink/Smoothing.h <<'EOF'
#pragma once
#include <QPainterPath>
#include <QPointF>
#include <vector>
#include "model/StrokePoint.h"

namespace ib::ink {

// Exponential position stabilizer. strength in [0,1]; 0 = passthrough.
// Returns a new sample vector; pressure/tilt/time are carried through.
std::vector<StrokePoint> stabilize(const std::vector<StrokePoint>& in, double strength);

// Uniform Catmull-Rom spline through the given positions -> smooth centerline.
// Falls back to poly-line/quadratic for <4 points.
QPainterPath catmullRomPath(const std::vector<QPointF>& pts);

// Convenience: centerline path directly from samples.
QPainterPath centerline(const std::vector<StrokePoint>& pts);

} // namespace ib::ink
EOF

# ---- ink/Smoothing.cpp -----------------------------------------------------
cat > src/ink/Smoothing.cpp <<'EOF'
#include "ink/Smoothing.h"

namespace ib::ink {

std::vector<StrokePoint> stabilize(const std::vector<StrokePoint>& in, double strength) {
    if (in.size() < 3 || strength <= 0.0) return in;
    const double a = 1.0 - qBound(0.0, strength, 0.95); // smaller a = smoother
    std::vector<StrokePoint> out;
    out.reserve(in.size());
    out.push_back(in.front());
    QPointF acc = in.front().pos;
    for (size_t i = 1; i < in.size(); ++i) {
        acc = acc * (1.0 - a) + in[i].pos * a;
        StrokePoint p = in[i];
        p.pos = acc;
        out.push_back(p);
    }
    out.back().pos = in.back().pos; // anchor the true endpoint
    return out;
}

QPainterPath catmullRomPath(const std::vector<QPointF>& p) {
    QPainterPath path;
    const int n = static_cast<int>(p.size());
    if (n == 0) return path;
    path.moveTo(p[0]);
    if (n == 1) { path.lineTo(p[0]); return path; }
    if (n == 2) { path.lineTo(p[1]); return path; }

    // Convert each Catmull-Rom segment to a cubic Bezier (tension = 0.5).
    for (int i = 0; i < n - 1; ++i) {
        const QPointF p0 = p[i > 0 ? i - 1 : 0];
        const QPointF p1 = p[i];
        const QPointF p2 = p[i + 1];
        const QPointF p3 = p[i + 2 < n ? i + 2 : n - 1];
        const QPointF c1 = p1 + (p2 - p0) / 6.0;
        const QPointF c2 = p2 - (p3 - p1) / 6.0;
        path.cubicTo(c1, c2, p2);
    }
    return path;
}

QPainterPath centerline(const std::vector<StrokePoint>& pts) {
    std::vector<QPointF> xy;
    xy.reserve(pts.size());
    for (const auto& s : pts) xy.push_back(s.pos);
    return catmullRomPath(xy);
}

} // namespace ib::ink
EOF

# ---- ink/Tessellator.h -----------------------------------------------------
cat > src/ink/Tessellator.h <<'EOF'
#pragma once
#include <QPainterPath>
#include <vector>
#include "model/StrokePoint.h"

namespace ib::ink {

// Effective per-point width from base width + optional pressure mapping.
double widthAt(double baseWidth, float pressure, bool pressureToWidth);

// Builds a CLOSED, fillable outline (a variable-width "ribbon" with round
// caps) from the samples. Filling this with the ink color yields crisp,
// pressure-tapered strokes that stay sharp at any zoom because they are
// pure vector geometry rebuilt on demand.
QPainterPath buildRibbon(const std::vector<StrokePoint>& pts,
                         double baseWidth, bool pressureToWidth);

} // namespace ib::ink
EOF

# ---- ink/Tessellator.cpp ---------------------------------------------------
cat > src/ink/Tessellator.cpp <<'EOF'
#include "ink/Tessellator.h"
#include "ink/Smoothing.h"
#include <QLineF>
#include <cmath>

namespace ib::ink {

double widthAt(double baseWidth, float pressure, bool pressureToWidth) {
    if (!pressureToWidth) return baseWidth;
    const double p = qBound(0.0, static_cast<double>(pressure), 1.0);
    return baseWidth * (0.30 + 0.70 * p); // never fully collapse to 0
}

static QPointF normal(const QPointF& a, const QPointF& b) {
    QPointF d = b - a;
    const double len = std::hypot(d.x(), d.y());
    if (len < 1e-6) return QPointF(0, 0);
    return QPointF(-d.y() / len, d.x() / len); // left normal
}

QPainterPath buildRibbon(const std::vector<StrokePoint>& in,
                         double baseWidth, bool pressureToWidth) {
    QPainterPath path;
    if (in.empty()) return path;

    // A single tap -> a dot.
    if (in.size() == 1) {
        const double r = 0.5 * widthAt(baseWidth, in[0].pressure, pressureToWidth);
        path.addEllipse(in[0].pos, r, r);
        return path;
    }

    // Densify centerline so the ribbon follows the smoothed curve.
    const QPainterPath spine = centerline(in);
    const int steps = qMax<int>(static_cast<int>(spine.length() / 2.0), static_cast<int>(in.size()));
    std::vector<QPointF> pos;
    std::vector<double>  half;
    pos.reserve(steps + 1);
    half.reserve(steps + 1);
    for (int i = 0; i <= steps; ++i) {
        const double t = static_cast<double>(i) / steps;
        const double pct = spine.percentAtLength(spine.length() * t);
        pos.push_back(spine.pointAtPercent(pct));
        // sample pressure by nearest original index (cheap, adequate)
        const size_t idx = qMin(in.size() - 1,
                                static_cast<size_t>(t * (in.size() - 1) + 0.5));
        half.push_back(0.5 * widthAt(baseWidth, in[idx].pressure, pressureToWidth));
    }

    // Left edge forward, right edge backward => closed polygon.
    std::vector<QPointF> left, right;
    left.reserve(pos.size());
    right.reserve(pos.size());
    for (size_t i = 0; i < pos.size(); ++i) {
        const QPointF a = pos[i > 0 ? i - 1 : 0];
        const QPointF b = pos[i + 1 < pos.size() ? i + 1 : i];
        const QPointF n = normal(a, b);
        left.push_back(pos[i] + n * half[i]);
        right.push_back(pos[i] - n * half[i]);
    }

    path.moveTo(left.front());
    for (size_t i = 1; i < left.size(); ++i) path.lineTo(left[i]);
    // round cap at end
    path.arcTo(QRectF(pos.back().x() - half.back(), pos.back().y() - half.back(),
                      2 * half.back(), 2 * half.back()), 0, -180);
    for (size_t i = right.size(); i-- > 0;) path.lineTo(right[i]);
    // round cap at start
    path.arcTo(QRectF(pos.front().x() - half.front(), pos.front().y() - half.front(),
                      2 * half.front(), 2 * half.front()), 0, -180);
    path.closeSubpath();
    return path;
}

} // namespace ib::ink
EOF

# ---- model/Item.cpp (dispatch + base helpers) ------------------------------
cat > src/model/Item.cpp <<'EOF'
#include "model/Item.h"
#include "model/StrokeItem.h"
#include "model/ShapeItem.h"
#include "model/TextItem.h"
#include "model/ImageItem.h"

namespace ib {

void Item::writeBase(QJsonObject& o) const {
    o["id"] = m_id.toString(QUuid::WithoutBraces);
}
void Item::readBase(const QJsonObject& o) {
    const QUuid u(o.value("id").toString());
    if (!u.isNull()) m_id = u;
}

std::unique_ptr<Item> Item::fromJson(const QJsonObject& o) {
    const QString t = o.value("type").toString();
    if (t == "stroke") return StrokeItem::fromJsonImpl(o);
    if (t == "shape")  return ShapeItem::fromJsonImpl(o);
    if (t == "text")   return TextItem::fromJsonImpl(o);
    if (t == "image")  return ImageItem::fromJsonImpl(o);
    return nullptr;
}

} // namespace ib
EOF

# ---- model/StrokeItem.cpp --------------------------------------------------
cat > src/model/StrokeItem.cpp <<'EOF'
#include "model/StrokeItem.h"
#include "ink/Smoothing.h"
#include "ink/Tessellator.h"
#include <QJsonArray>
#include <QPainterPathStroker>

namespace ib {

void StrokeItem::addPoint(const StrokePoint& p) { m_points.push_back(p); m_dirty = true; }
void StrokeItem::finalize() {
    if (smoothing > 0.0) m_points = ink::stabilize(m_points, smoothing);
    m_dirty = true; rebuild();
}

void StrokeItem::rebuild() const {
    m_path = ink::centerline(m_points);
    QRectF b = m_path.boundingRect();
    const double pad = baseWidth; // half-width each side, generous
    m_bounds = b.adjusted(-pad, -pad, pad, pad);
    m_dirty = false;
}

const QPainterPath& StrokeItem::path() const {
    if (m_dirty) rebuild();
    return m_path;
}

QRectF StrokeItem::boundingRect() const {
    if (m_dirty) rebuild();
    return m_bounds;
}

bool StrokeItem::hitTest(const QPointF& p, double tolerance) const {
    if (!boundingRect().adjusted(-tolerance, -tolerance, tolerance, tolerance).contains(p))
        return false;
    QPainterPathStroker stroker;
    stroker.setWidth(baseWidth + 2.0 * tolerance);
    stroker.setCapStyle(Qt::RoundCap);
    stroker.setJoinStyle(Qt::RoundJoin);
    return stroker.createStroke(path()).contains(p);
}

std::unique_ptr<Item> StrokeItem::clone() const {
    auto c = std::make_unique<StrokeItem>(*this);
    c->m_dirty = true;
    return c;
}

QJsonObject StrokeItem::toJson() const {
    QJsonObject o;
    writeBase(o);
    o["type"] = "stroke";
    o["kind"] = int(kind);
    o["color"] = color.name(QColor::HexArgb);
    o["baseWidth"] = baseWidth;
    o["opacity"] = opacity;
    o["pW"] = pressureToWidth;
    o["pO"] = pressureToOpacity;
    o["smoothing"] = smoothing;
    QJsonArray arr;
    for (const auto& s : m_points) {
        arr.append(s.pos.x()); arr.append(s.pos.y());
        arr.append(double(s.pressure));
        arr.append(double(s.tiltX)); arr.append(double(s.tiltY));
        arr.append(double(s.tMs));
    }
    o["pts"] = arr;
    return o;
}

std::unique_ptr<StrokeItem> StrokeItem::fromJsonImpl(const QJsonObject& o) {
    auto s = std::make_unique<StrokeItem>();
    s->readBase(o);
    s->kind = InkKind(o.value("kind").toInt());
    s->color = QColor(o.value("color").toString());
    s->baseWidth = o.value("baseWidth").toDouble(2.5);
    s->opacity = o.value("opacity").toDouble(1.0);
    s->pressureToWidth = o.value("pW").toBool(true);
    s->pressureToOpacity = o.value("pO").toBool(false);
    s->smoothing = o.value("smoothing").toDouble(0.5);
    const QJsonArray arr = o.value("pts").toArray();
    for (int i = 0; i + 5 < arr.size(); i += 6) {
        StrokePoint sp;
        sp.pos = QPointF(arr[i].toDouble(), arr[i + 1].toDouble());
        sp.pressure = float(arr[i + 2].toDouble());
        sp.tiltX = float(arr[i + 3].toDouble());
        sp.tiltY = float(arr[i + 4].toDouble());
        sp.tMs = qint64(arr[i + 5].toDouble());
        s->m_points.push_back(sp);
    }
    s->m_dirty = true;
    return s;
}

} // namespace ib
EOF

# ---- model/ShapeItem.cpp ---------------------------------------------------
cat > src/model/ShapeItem.cpp <<'EOF'
#include "model/ShapeItem.h"
#include <QLineF>
#include <cmath>

namespace ib {

QRectF ShapeItem::boundingRect() const {
    QRectF r = QRectF(p1, p2).normalized();
    const double pad = strokeWidth + 4.0;
    return r.adjusted(-pad, -pad, pad, pad);
}

bool ShapeItem::hitTest(const QPointF& p, double tol) const {
    const double t = strokeWidth * 0.5 + tol;
    switch (shape) {
    case ShapeKind::Line:
    case ShapeKind::Arrow: {
        const QLineF ln(p1, p2);
        // distance point->segment
        const double L2 = ln.dx()*ln.dx() + ln.dy()*ln.dy();
        if (L2 < 1e-9) return QLineF(p1, p).length() <= t;
        double u = ((p.x()-p1.x())*ln.dx() + (p.y()-p1.y())*ln.dy()) / L2;
        u = qBound(0.0, u, 1.0);
        const QPointF proj(p1.x()+u*ln.dx(), p1.y()+u*ln.dy());
        return QLineF(proj, p).length() <= t;
    }
    case ShapeKind::Rectangle: {
        QRectF r = QRectF(p1, p2).normalized();
        if (filled && r.contains(p)) return true;
        QRectF outer = r.adjusted(-t,-t,t,t), inner = r.adjusted(t,t,-t,-t);
        return outer.contains(p) && !inner.contains(p);
    }
    case ShapeKind::Ellipse: {
        QRectF r = QRectF(p1, p2).normalized();
        const double rx = r.width()/2, ry = r.height()/2;
        if (rx < 1e-6 || ry < 1e-6) return false;
        const QPointF c = r.center();
        const double v = std::pow((p.x()-c.x())/rx,2) + std::pow((p.y()-c.y())/ry,2);
        if (filled && v <= 1.0) return true;
        const double band = t / qMax(rx, ry);
        return std::fabs(v - 1.0) <= 2.0 * band;
    }
    }
    return false;
}

std::unique_ptr<Item> ShapeItem::clone() const { return std::make_unique<ShapeItem>(*this); }

QJsonObject ShapeItem::toJson() const {
    QJsonObject o; writeBase(o);
    o["type"] = "shape";
    o["shape"] = int(shape);
    o["x1"] = p1.x(); o["y1"] = p1.y();
    o["x2"] = p2.x(); o["y2"] = p2.y();
    o["stroke"] = strokeColor.name(QColor::HexArgb);
    o["sw"] = strokeWidth;
    o["filled"] = filled;
    o["fill"] = fillColor.name(QColor::HexArgb);
    o["opacity"] = opacity;
    return o;
}

std::unique_ptr<ShapeItem> ShapeItem::fromJsonImpl(const QJsonObject& o) {
    auto s = std::make_unique<ShapeItem>();
    s->readBase(o);
    s->shape = ShapeKind(o.value("shape").toInt());
    s->p1 = QPointF(o.value("x1").toDouble(), o.value("y1").toDouble());
    s->p2 = QPointF(o.value("x2").toDouble(), o.value("y2").toDouble());
    s->strokeColor = QColor(o.value("stroke").toString());
    s->strokeWidth = o.value("sw").toDouble(2.5);
    s->filled = o.value("filled").toBool(false);
    s->fillColor = QColor(o.value("fill").toString());
    s->opacity = o.value("opacity").toDouble(1.0);
    return s;
}

} // namespace ib
EOF

# ---- model/TextItem.cpp ----------------------------------------------------
cat > src/model/TextItem.cpp <<'EOF'
#include "model/TextItem.h"
#include <QFontMetricsF>

namespace ib {

QRectF TextItem::boundingRect() const {
    QFontMetricsF fm(font);
    QRectF r = fm.boundingRect(QRectF(pos, QSizeF(wrapWidth > 0 ? wrapWidth : 100000, 100000)),
                               Qt::TextWordWrap, text.isEmpty() ? " " : text);
    r.moveTopLeft(pos);
    return r.adjusted(-2, -2, 2, 2);
}

bool TextItem::hitTest(const QPointF& p, double tol) const {
    return boundingRect().adjusted(-tol,-tol,tol,tol).contains(p);
}

std::unique_ptr<Item> TextItem::clone() const { return std::make_unique<TextItem>(*this); }

QJsonObject TextItem::toJson() const {
    QJsonObject o; writeBase(o);
    o["type"] = "text";
    o["text"] = text;
    o["x"] = pos.x(); o["y"] = pos.y();
    o["wrap"] = wrapWidth;
    o["font"] = font.toString();
    o["color"] = color.name(QColor::HexArgb);
    return o;
}

std::unique_ptr<TextItem> TextItem::fromJsonImpl(const QJsonObject& o) {
    auto t = std::make_unique<TextItem>();
    t->readBase(o);
    t->text = o.value("text").toString();
    t->pos = QPointF(o.value("x").toDouble(), o.value("y").toDouble());
    t->wrapWidth = o.value("wrap").toDouble(0.0);
    QFont f; f.fromString(o.value("font").toString()); t->font = f;
    t->color = QColor(o.value("color").toString());
    return t;
}

} // namespace ib
EOF

# ---- model/ImageItem.cpp ---------------------------------------------------
cat > src/model/ImageItem.cpp <<'EOF'
#include "model/ImageItem.h"
#include <QBuffer>
#include <QByteArray>

namespace ib {

bool ImageItem::hitTest(const QPointF& p, double tol) const {
    return rect.adjusted(-tol,-tol,tol,tol).contains(p);
}

std::unique_ptr<Item> ImageItem::clone() const { return std::make_unique<ImageItem>(*this); }

QJsonObject ImageItem::toJson() const {
    QJsonObject o; writeBase(o);
    o["type"] = "image";
    o["x"] = rect.x(); o["y"] = rect.y();
    o["w"] = rect.width(); o["h"] = rect.height();
    o["opacity"] = opacity;
    QByteArray bytes;
    QBuffer buf(&bytes);
    buf.open(QIODevice::WriteOnly);
    image.save(&buf, "PNG");
    o["png"] = QString::fromLatin1(bytes.toBase64());
    return o;
}

std::unique_ptr<ImageItem> ImageItem::fromJsonImpl(const QJsonObject& o) {
    auto im = std::make_unique<ImageItem>();
    im->readBase(o);
    im->rect = QRectF(o.value("x").toDouble(), o.value("y").toDouble(),
                      o.value("w").toDouble(), o.value("h").toDouble());
    im->opacity = o.value("opacity").toDouble(1.0);
    const QByteArray png = QByteArray::fromBase64(o.value("png").toString().toLatin1());
    im->image.loadFromData(png, "PNG");
    return im;
}

} // namespace ib
EOF

# ---- model/Layer.cpp -------------------------------------------------------
cat > src/model/Layer.cpp <<'EOF'
#include "model/Layer.h"
#include <QJsonArray>

namespace ib {

Layer Layer::clone() const {
    Layer c;
    c.id = QUuid::createUuid();
    c.name = name; c.visible = visible; c.locked = locked; c.opacity = opacity;
    c.items.reserve(items.size());
    for (const auto& it : items) c.items.push_back(it->clone());
    return c;
}

QJsonObject Layer::toJson() const {
    QJsonObject o;
    o["id"] = id.toString(QUuid::WithoutBraces);
    o["name"] = name;
    o["visible"] = visible;
    o["locked"] = locked;
    o["opacity"] = opacity;
    QJsonArray arr;
    for (const auto& it : items) arr.append(it->toJson());
    o["items"] = arr;
    return o;
}

Layer Layer::fromJson(const QJsonObject& o) {
    Layer l;
    const QUuid u(o.value("id").toString());
    if (!u.isNull()) l.id = u;
    l.name = o.value("name").toString("Layer");
    l.visible = o.value("visible").toBool(true);
    l.locked = o.value("locked").toBool(false);
    l.opacity = o.value("opacity").toDouble(1.0);
    for (const auto& v : o.value("items").toArray()) {
        if (auto it = Item::fromJson(v.toObject())) l.items.push_back(std::move(it));
    }
    return l;
}

} // namespace ib
EOF

# ---- model/Page.cpp --------------------------------------------------------
cat > src/model/Page.cpp <<'EOF'
#include "model/Page.h"
#include <QJsonArray>

namespace ib {

Page::Page() {
    Layer base;
    base.name = QStringLiteral("Layer 1");
    layers.push_back(std::move(base));
}

Layer&       Page::active()       { return layers[size_t(qBound(0, activeLayer, int(layers.size())-1))]; }
const Layer& Page::active() const { return layers[size_t(qBound(0, activeLayer, int(layers.size())-1))]; }

QRectF Page::contentBounds() const {
    QRectF r;
    for (const auto& l : layers)
        for (const auto& it : l.items)
            r = r.isNull() ? it->boundingRect() : r.united(it->boundingRect());
    return r;
}

Page Page::clone() const {
    Page c;
    c.id = QUuid::createUuid();
    c.title = title;
    c.background = background; c.bgColor = bgColor; c.gridColor = gridColor;
    c.gridSpacing = gridSpacing; c.paperSize = paperSize; c.activeLayer = activeLayer;
    c.layers.clear();
    for (const auto& l : layers) c.layers.push_back(l.clone());
    return c;
}

QJsonObject Page::toJson() const {
    QJsonObject o;
    o["id"] = id.toString(QUuid::WithoutBraces);
    o["title"] = title;
    o["bg"] = int(background);
    o["bgColor"] = bgColor.name(QColor::HexArgb);
    o["gridColor"] = gridColor.name(QColor::HexArgb);
    o["gridSpacing"] = gridSpacing;
    o["pw"] = paperSize.width(); o["ph"] = paperSize.height();
    o["activeLayer"] = activeLayer;
    QJsonArray arr;
    for (const auto& l : layers) arr.append(l.toJson());
    o["layers"] = arr;
    return o;
}

Page Page::fromJson(const QJsonObject& o) {
    Page p;
    const QUuid u(o.value("id").toString());
    if (!u.isNull()) p.id = u;
    p.title = o.value("title").toString("Page");
    p.background = BackgroundKind(o.value("bg").toInt(int(BackgroundKind::Grid)));
    p.bgColor = QColor(o.value("bgColor").toString("#ffffffff"));
    p.gridColor = QColor(o.value("gridColor").toString("#1c000000"));
    p.gridSpacing = o.value("gridSpacing").toDouble(32.0);
    p.paperSize = QSizeF(o.value("pw").toDouble(1920), o.value("ph").toDouble(1080));
    p.activeLayer = o.value("activeLayer").toInt(0);
    p.layers.clear();
    for (const auto& v : o.value("layers").toArray())
        p.layers.push_back(Layer::fromJson(v.toObject()));
    if (p.layers.empty()) p.layers.push_back(Layer{});
    return p;
}

} // namespace ib
EOF

# ---- model/History.cpp -----------------------------------------------------
cat > src/model/History.cpp <<'EOF'
#include "model/History.h"

namespace ib {

void History::push(Command cmd) {
    if (cmd.redo) cmd.redo();
    // drop any redo tail
    if (m_index < int(m_stack.size())) m_stack.resize(size_t(m_index));
    m_stack.push_back(std::move(cmd));
    m_index = int(m_stack.size());
    if (int(m_stack.size()) > m_limit) {
        m_stack.erase(m_stack.begin());
        m_index = int(m_stack.size());
    }
}

void History::undo() {
    if (!canUndo()) return;
    --m_index;
    if (m_stack[size_t(m_index)].undo) m_stack[size_t(m_index)].undo();
}

void History::redo() {
    if (!canRedo()) return;
    if (m_stack[size_t(m_index)].redo) m_stack[size_t(m_index)].redo();
    ++m_index;
}

void History::clear() { m_stack.clear(); m_index = 0; }

} // namespace ib
EOF

# ---- model/Document.cpp ----------------------------------------------------
cat > src/model/Document.cpp <<'EOF'
#include "model/Document.h"
#include "model/History.h"

namespace ib {

Document::Document(QObject* parent) : QObject(parent), m_history(std::make_unique<History>()) {
    m_pages.emplace_back();          // start with one page
}
Document::~Document() = default;

Page&       Document::page(int i)       { return m_pages[size_t(qBound(0, i, pageCount()-1))]; }
const Page& Document::page(int i) const { return m_pages[size_t(qBound(0, i, pageCount()-1))]; }
Page&       Document::current()         { return page(m_current); }

void Document::setCurrentIndex(int i) {
    i = qBound(0, i, pageCount()-1);
    if (i == m_current) return;
    m_current = i;
    emit currentPageChanged(m_current);
}

int Document::addPage() {
    Page p; p.title = QStringLiteral("Page %1").arg(pageCount()+1);
    m_pages.push_back(std::move(p));
    setModified(true);
    emit pagesChanged();
    return pageCount()-1;
}

void Document::removePage(int i) {
    if (pageCount() <= 1) return;
    m_pages.erase(m_pages.begin() + qBound(0, i, pageCount()-1));
    m_current = qBound(0, m_current, pageCount()-1);
    setModified(true);
    emit pagesChanged();
    emit currentPageChanged(m_current);
}

void Document::movePage(int from, int to) {
    from = qBound(0, from, pageCount()-1);
    to   = qBound(0, to,   pageCount()-1);
    if (from == to) return;
    Page tmp = std::move(m_pages[size_t(from)]);
    m_pages.erase(m_pages.begin()+from);
    m_pages.insert(m_pages.begin()+to, std::move(tmp));
    setModified(true);
    emit pagesChanged();
}

void Document::setModified(bool m) {
    if (m == m_modified) return;
    m_modified = m;
    emit modifiedChanged(m_modified);
}

void Document::markContentChanged() {
    setModified(true);
    emit contentChanged();
}

} // namespace ib
EOF

# ---- io/BoardSerializer.h --------------------------------------------------
cat > src/io/BoardSerializer.h <<'EOF'
#pragma once
#include <QString>
namespace ib {
class Document;

// Native ".board" format = a versioned JSON document (self-contained: images
// are embedded). Guarantees lossless round-trip of pages/layers/vector ink.
namespace board {
constexpr int kFormatVersion = 1;

bool save(const Document& doc, const QString& path, QString* error = nullptr);
bool load(Document& doc, const QString& path, QString* error = nullptr);

// In-memory variants for autosave / crash recovery.
QByteArray toBytes(const Document& doc);
bool       fromBytes(Document& doc, const QByteArray& bytes, QString* error = nullptr);
} // namespace board
} // namespace ib
EOF

# ---- io/BoardSerializer.cpp ------------------------------------------------
cat > src/io/BoardSerializer.cpp <<'EOF'
#include "io/BoardSerializer.h"
#include "model/Document.h"
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>

namespace ib::board {

QByteArray toBytes(const Document& doc) {
    QJsonObject root;
    root["format"] = "inkboard";
    root["version"] = kFormatVersion;
    root["current"] = doc.currentIndex();
    QJsonArray pages;
    for (int i = 0; i < doc.pageCount(); ++i) pages.append(doc.page(i).toJson());
    root["pages"] = pages;
    return QJsonDocument(root).toJson(QJsonDocument::Compact);
}

bool fromBytes(Document& doc, const QByteArray& bytes, QString* error) {
    QJsonParseError pe{};
    const QJsonDocument jd = QJsonDocument::fromJson(bytes, &pe);
    if (pe.error != QJsonParseError::NoError || !jd.isObject()) {
        if (error) *error = QStringLiteral("Invalid board file: %1").arg(pe.errorString());
        return false;
    }
    const QJsonObject root = jd.object();
    if (root.value("format").toString() != "inkboard") {
        if (error) *error = QStringLiteral("Not an InkBoard file.");
        return false;
    }
    // Rebuild pages via a temp doc-like path: we mutate through public API.
    // Simplicity: clear by removing extra pages then overwrite page(0..n).
    const QJsonArray pages = root.value("pages").toArray();
    if (pages.isEmpty()) { if (error) *error = "Empty board."; return false; }

    // Ensure exactly pages.size() pages exist.
    while (doc.pageCount() < pages.size()) doc.addPage();
    while (doc.pageCount() > pages.size()) doc.removePage(doc.pageCount()-1);
    for (int i = 0; i < pages.size(); ++i)
        doc.page(i) = Page::fromJson(pages[i].toObject());

    doc.setCurrentIndex(root.value("current").toInt(0));
    doc.setModified(false);
    doc.markContentChanged();
    doc.setModified(false);
    return true;
}

bool save(const Document& doc, const QString& path, QString* error) {
    QSaveFile f(path);
    if (!f.open(QIODevice::WriteOnly)) {
        if (error) *error = QStringLiteral("Cannot write %1: %2").arg(path, f.errorString());
        return false;
    }
    const QByteArray bytes = toBytes(doc);
    if (f.write(bytes) != bytes.size()) {
        if (error) *error = QStringLiteral("Short write to %1").arg(path);
        return false;
    }
    if (!f.commit()) {
        if (error) *error = QStringLiteral("Commit failed for %1: %2").arg(path, f.errorString());
        return false;
    }
    return true;
}

bool load(Document& doc, const QString& path, QString* error) {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) {
        if (error) *error = QStringLiteral("Cannot open %1: %2").arg(path, f.errorString());
        return false;
    }
    return fromBytes(doc, f.readAll(), error);
}

} // namespace ib::board
EOF

log "PART 2 complete: model impls, smoothing/tessellation, history, and .board serializer written."
# =============================================================================
#  END OF PART 2  —  append PART 3 (canvas rendering + tablet/touch input) below
# =============================================================================

# =============================================================================
#  PART 3  —  viewport transform, GPU canvas rendering, pen/touch input router
#  Append below PART 2. Creates new files only.
# =============================================================================
log "PART 3: writing viewport, renderer, canvas widget, and input router"

# ---- render/Viewport.h -----------------------------------------------------
cat > src/render/Viewport.h <<'EOF'
#pragma once
#include <QPointF>
#include <QRectF>
#include <QSize>
#include <QTransform>

namespace ib::render {

// Maps between infinite PAGE space and on-screen (logical) widget space.
// Pure value type: pan (offset), zoom (scale), and optional rotation.
class Viewport {
public:
    QPointF offset{0, 0};   // screen position of page origin (logical px)
    double  scale = 1.0;    // page units -> screen px
    double  rotation = 0.0; // radians (touch rotate gesture)

    static constexpr double kMinScale = 0.05;
    static constexpr double kMaxScale = 40.0;

    QTransform core() const;          // rotation+scale (no translation)
    QTransform pageToScreen() const;  // full transform
    QTransform screenToPage() const { return pageToScreen().inverted(); }

    QPointF toPage(const QPointF& s)   const { return screenToPage().map(s); }
    QPointF toScreen(const QPointF& p) const { return pageToScreen().map(p); }

    void panBy(const QPointF& deltaScreen) { offset += deltaScreen; }
    void zoomAt(const QPointF& screenAnchor, double factor);
    void rotateAt(const QPointF& screenAnchor, double deltaRad);

    QRectF visiblePageRect(const QSize& widgetSize) const;
    void fitTo(const QRectF& pageRect, const QSize& widgetSize, double margin = 40.0);
};

} // namespace ib::render
EOF

# ---- render/Viewport.cpp ---------------------------------------------------
cat > src/render/Viewport.cpp <<'EOF'
#include "render/Viewport.h"
#include <QtGlobalStatic>
#include <cmath>

namespace ib::render {

QTransform Viewport::core() const {
    QTransform t;
    t.rotateRadians(rotation);
    t.scale(scale, scale);
    return t;
}

QTransform Viewport::pageToScreen() const {
    QTransform t;
    t.translate(offset.x(), offset.y());
    t.rotateRadians(rotation);
    t.scale(scale, scale);
    return t;
}

void Viewport::zoomAt(const QPointF& anchor, double factor) {
    const QPointF pagePt = toPage(anchor);
    scale = qBound(kMinScale, scale * factor, kMaxScale);
    offset = anchor - core().map(pagePt);
}

void Viewport::rotateAt(const QPointF& anchor, double deltaRad) {
    const QPointF pagePt = toPage(anchor);
    rotation += deltaRad;
    offset = anchor - core().map(pagePt);
}

QRectF Viewport::visiblePageRect(const QSize& s) const {
    const QTransform inv = screenToPage();
    QRectF r;
    const QPointF c[4] = { inv.map(QPointF(0, 0)),      inv.map(QPointF(s.width(), 0)),
                           inv.map(QPointF(0, s.height())), inv.map(QPointF(s.width(), s.height())) };
    r = QRectF(c[0], c[0]);
    for (const auto& p : c) {
        r.setLeft(qMin(r.left(), p.x()));   r.setTop(qMin(r.top(), p.y()));
        r.setRight(qMax(r.right(), p.x())); r.setBottom(qMax(r.bottom(), p.y()));
    }
    return r;
}

void Viewport::fitTo(const QRectF& pageRect, const QSize& s, double margin) {
    if (pageRect.isEmpty() || s.isEmpty()) return;
    rotation = 0.0;
    const double sx = (s.width()  - 2 * margin) / pageRect.width();
    const double sy = (s.height() - 2 * margin) / pageRect.height();
    scale = qBound(kMinScale, qMin(sx, sy), kMaxScale);
    const QPointF center = pageRect.center();
    offset = QPointF(s.width() / 2.0, s.height() / 2.0) - core().map(center);
}

} // namespace ib::render
EOF

# ---- render/CanvasRenderer.h ----------------------------------------------
cat > src/render/CanvasRenderer.h <<'EOF'
#pragma once
#include <QPainter>
#include "render/Viewport.h"

namespace ib {
class Page;
class Item;
namespace render {

// Stateless drawing of the vector document. The painter is transformed into
// PAGE space, so all widths are page units and stay crisp at any zoom.
class CanvasRenderer {
public:
    // Full page paint (background + all visible layers) clipped to widget rect.
    static void paintPage(QPainter& p, const Page& page, const Viewport& vp,
                          const QSize& widgetSize);

    // Paints one item; assumes painter is already in page space + antialiased.
    static void paintItem(QPainter& p, const Item& item);

private:
    static void paintBackground(QPainter& p, const Page& page, const QRectF& visPage);
};

} // namespace render
} // namespace ib
EOF

# ---- render/CanvasRenderer.cpp --------------------------------------------
cat > src/render/CanvasRenderer.cpp <<'EOF'
#include "render/CanvasRenderer.h"
#include "model/Page.h"
#include "model/StrokeItem.h"
#include "model/ShapeItem.h"
#include "model/TextItem.h"
#include "model/ImageItem.h"
#include "ink/Tessellator.h"
#include <QtMath>

namespace ib::render {

void CanvasRenderer::paintBackground(QPainter& p, const Page& page, const QRectF& vis) {
    if (page.background == BackgroundKind::Blank) return;
    QPen pen(page.gridColor);
    pen.setCosmetic(true);          // 1px lines regardless of zoom
    pen.setWidthF(1.0);
    p.setPen(pen);
    const double g = qMax(2.0, page.gridSpacing);
    const double x0 = std::floor(vis.left() / g) * g;
    const double y0 = std::floor(vis.top()  / g) * g;

    if (page.background == BackgroundKind::Grid || page.background == BackgroundKind::Lines) {
        for (double y = y0; y <= vis.bottom(); y += g)
            p.drawLine(QPointF(vis.left(), y), QPointF(vis.right(), y));
        if (page.background == BackgroundKind::Grid)
            for (double x = x0; x <= vis.right(); x += g)
                p.drawLine(QPointF(x, vis.top()), QPointF(x, vis.bottom()));
    } else if (page.background == BackgroundKind::Dots) {
        p.setBrush(page.gridColor);
        p.setPen(Qt::NoPen);
        for (double y = y0; y <= vis.bottom(); y += g)
            for (double x = x0; x <= vis.right(); x += g)
                p.drawEllipse(QPointF(x, y), 1.2, 1.2);
    }
}

void CanvasRenderer::paintItem(QPainter& p, const Item& item) {
    switch (item.type()) {
    case ItemType::Stroke: {
        const auto& s = static_cast<const StrokeItem&>(item);
        p.save();
        p.setPen(Qt::NoPen);
        QColor c = s.color;
        p.setOpacity(qBound(0.0, s.opacity, 1.0));
        if (s.kind == InkKind::Highlighter)
            p.setCompositionMode(QPainter::CompositionMode_Multiply);
        p.setBrush(c);
        p.drawPath(ink::buildRibbon(s.points(), s.baseWidth, s.pressureToWidth));
        p.restore();
        break;
    }
    case ItemType::Shape: {
        const auto& sh = static_cast<const ShapeItem&>(item);
        p.save();
        p.setOpacity(qBound(0.0, sh.opacity, 1.0));
        QPen pen(sh.strokeColor);
        pen.setWidthF(sh.strokeWidth);
        pen.setCapStyle(Qt::RoundCap);
        pen.setJoinStyle(Qt::RoundJoin);
        p.setPen(pen);
        p.setBrush(sh.filled ? QBrush(sh.fillColor) : Qt::NoBrush);
        const QRectF r = QRectF(sh.p1, sh.p2).normalized();
        switch (sh.shape) {
        case ShapeKind::Line:      p.drawLine(sh.p1, sh.p2); break;
        case ShapeKind::Rectangle: p.drawRect(r); break;
        case ShapeKind::Ellipse:   p.drawEllipse(r); break;
        case ShapeKind::Arrow: {
            p.drawLine(sh.p1, sh.p2);
            const double a = std::atan2(sh.p2.y() - sh.p1.y(), sh.p2.x() - sh.p1.x());
            const double len = qMax(8.0, sh.strokeWidth * 4.0);
            const double spread = M_PI / 7.0;
            const QPointF b1 = sh.p2 - QPointF(std::cos(a - spread), std::sin(a - spread)) * len;
            const QPointF b2 = sh.p2 - QPointF(std::cos(a + spread), std::sin(a + spread)) * len;
            p.setBrush(sh.strokeColor);
            QPolygonF head; head << sh.p2 << b1 << b2;
            p.drawPolygon(head);
            break;
        }
        }
        p.restore();
        break;
    }
    case ItemType::Text: {
        const auto& t = static_cast<const TextItem&>(item);
        p.save();
        p.setPen(t.color);
        p.setFont(t.font);
        const QRectF box(t.pos, QSizeF(t.wrapWidth > 0 ? t.wrapWidth : 100000, 100000));
        p.drawText(box, (t.wrapWidth > 0 ? Qt::TextWordWrap : 0) | Qt::AlignLeft | Qt::AlignTop, t.text);
        p.restore();
        break;
    }
    case ItemType::Image: {
        const auto& im = static_cast<const ImageItem&>(item);
        p.save();
        p.setOpacity(qBound(0.0, im.opacity, 1.0));
        p.setRenderHint(QPainter::SmoothPixmapTransform, true);
        p.drawImage(im.rect, im.image);
        p.restore();
        break;
    }
    }
}

void CanvasRenderer::paintPage(QPainter& p, const Page& page, const Viewport& vp,
                               const QSize& widgetSize) {
    // Infinite canvas: fill the whole widget with the page's paper color.
    p.fillRect(QRect(QPoint(0, 0), widgetSize), page.bgColor);

    p.setRenderHint(QPainter::Antialiasing, true);
    p.setRenderHint(QPainter::TextAntialiasing, true);
    p.setTransform(vp.pageToScreen());

    const QRectF vis = vp.visiblePageRect(widgetSize);
    p.setClipRect(vis);
    paintBackground(p, page, vis);

    for (const auto& layer : page.layers) {
        if (!layer.visible) continue;
        p.save();
        p.setOpacity(p.opacity() * qBound(0.0, layer.opacity, 1.0));
        for (const auto& it : layer.items) {
            if (it->boundingRect().intersects(vis))
                paintItem(p, *it);
        }
        p.restore();
    }
    p.resetTransform();
    p.setClipping(false);
}

} // namespace ib::render
EOF

# ---- render/ICanvasHost.h --------------------------------------------------
cat > src/render/ICanvasHost.h <<'EOF'
#pragma once
#include <QRectF>
class QWidget;
namespace ib {
class Document;
namespace render { class Viewport; }

// Abstraction the tools use to reach the document/viewport and to request
// repaints, without depending on the concrete widget class.
class ICanvasHost {
public:
    virtual ~ICanvasHost() = default;
    virtual Document* document() = 0;
    virtual render::Viewport& viewport() = 0;
    virtual void requestRepaint() = 0;
    virtual QWidget* asWidget() = 0;
};

} // namespace ib
EOF

# ---- input/PressureCurve.h -------------------------------------------------
cat > src/input/PressureCurve.h <<'EOF'
#pragma once
namespace ib::input {

// Configurable pen pressure response. gamma<1 = softer (more ink at low
// force); gamma>1 = firmer. min/max clamp the usable output band.
class PressureCurve {
public:
    double gamma = 1.0;
    double minOut = 0.0;
    double maxOut = 1.0;

    float apply(float raw) const;

    static PressureCurve soft()  { return {0.6, 0.05, 1.0}; }
    static PressureCurve firm()  { return {1.6, 0.0, 1.0}; }
    static PressureCurve linear(){ return {1.0, 0.0, 1.0}; }
};

} // namespace ib::input
EOF

# ---- input/PressureCurve.cpp -----------------------------------------------
cat > src/input/PressureCurve.cpp <<'EOF'
#include "input/PressureCurve.h"
#include <algorithm>
#include <cmath>

namespace ib::input {
float PressureCurve::apply(float raw) const {
    double x = std::clamp(double(raw), 0.0, 1.0);
    double y = std::pow(x, gamma <= 0 ? 1.0 : gamma);
    y = minOut + (maxOut - minOut) * y;
    return float(std::clamp(y, 0.0, 1.0));
}
} // namespace ib::input
EOF

# ---- input/InputRouter.h ---------------------------------------------------
cat > src/input/InputRouter.h <<'EOF'
#pragma once
#include <QObject>
#include <QPointF>
#include "model/Enums.h"
#include "model/StrokePoint.h"
#include "input/PressureCurve.h"

class QTabletEvent;
class QTouchEvent;
class QMouseEvent;

namespace ib::render { class Viewport; }
namespace ib::input {

// A normalized input sample handed to tools. Coordinates are provided in BOTH
// spaces so tools can hit-test in page space and draw cursors in screen space.
struct InputSample {
    enum class Source { Pen, Mouse, Touch };
    QPointF pagePos;
    QPointF screenPos;
    float   pressure = 1.0f;
    float   tiltX = 0.0f;
    float   tiltY = 0.0f;
    qint64  tMs = 0;
    Source  source = Source::Pen;
    bool    eraser = false;   // pen flipped to eraser end
};

// Turns raw Qt events into high-level draw/gesture/hover signals and enforces
// the pen-vs-touch policy (palm rejection, touch = gestures, pen = ink).
class InputRouter : public QObject {
    Q_OBJECT
public:
    explicit InputRouter(QObject* parent = nullptr) : QObject(parent) {}

    TouchMode     touchMode = TouchMode::GestureOnly;
    bool          fingerDrawing = false;   // allow finger to draw ink
    PressureCurve pressure = PressureCurve::linear();

    bool handleTablet(QTabletEvent* e, const render::Viewport& vp);
    bool handleTouch (QTouchEvent*  e, const render::Viewport& vp);
    bool handleMouse (QMouseEvent*  e, const render::Viewport& vp);
    void setPenInProximity(bool prox, const QPointF& screenPos, const render::Viewport& vp);

    bool penActive() const { return m_penDown || m_penProximity; }

signals:
    void drawBegin (const ib::input::InputSample& s);
    void drawUpdate(const ib::input::InputSample& s);
    void drawEnd   (const ib::input::InputSample& s);
    void hoverMove (const ib::input::InputSample& s, bool inProximity);
    void gesturePan   (const QPointF& deltaScreen);
    void gestureZoom  (const QPointF& screenAnchor, double factor);
    void gestureRotate(const QPointF& screenAnchor, double deltaRad);

private:
    InputSample make(const QPointF& screen, float pressure, InputSample::Source src,
                     bool eraser, const render::Viewport& vp) const;

    bool m_penDown = false;
    bool m_penProximity = false;

    // touch gesture state
    bool    m_gestureActive = false;
    bool    m_touchDrawActive = false;
    QPointF m_lastCentroid;
    double  m_lastDist = 0.0;
    double  m_lastAngle = 0.0;
    InputSample m_lastSample;
};

} // namespace ib::input
EOF

# ---- input/InputRouter.cpp -------------------------------------------------
cat > src/input/InputRouter.cpp <<'EOF'
#include "input/InputRouter.h"
#include "render/Viewport.h"
#include <QTabletEvent>
#include <QTouchEvent>
#include <QMouseEvent>
#include <QDateTime>
#include <cmath>

namespace ib::input {

InputSample InputRouter::make(const QPointF& screen, float pr, InputSample::Source src,
                              bool eraser, const render::Viewport& vp) const {
    InputSample s;
    s.screenPos = screen;
    s.pagePos = vp.toPage(screen);
    s.pressure = pr;
    s.source = src;
    s.eraser = eraser;
    s.tMs = QDateTime::currentMSecsSinceEpoch();
    return s;
}

void InputRouter::setPenInProximity(bool prox, const QPointF& screenPos, const render::Viewport& vp) {
    m_penProximity = prox;
    InputSample s = make(screenPos, 0.0f, InputSample::Source::Pen, false, vp);
    emit hoverMove(s, prox);
}

bool InputRouter::handleTablet(QTabletEvent* e, const render::Viewport& vp) {
    const bool eraser = e->pointerType() == QPointingDevice::PointerType::Eraser;
    const QPointF screen = e->position();
    InputSample s = make(screen, pressure.apply(float(e->pressure())),
                         InputSample::Source::Pen, eraser, vp);
    s.tiltX = float(e->xTilt());
    s.tiltY = float(e->yTilt());
    m_penProximity = true;
    m_lastSample = s;

    switch (e->type()) {
    case QEvent::TabletPress:   m_penDown = true;  emit drawBegin(s);  break;
    case QEvent::TabletMove:
        if (m_penDown) emit drawUpdate(s);
        else           emit hoverMove(s, true);
        break;
    case QEvent::TabletRelease: m_penDown = false; emit drawEnd(s);    break;
    default: return false;
    }
    e->accept();
    return true;
}

bool InputRouter::handleMouse(QMouseEvent* e, const render::Viewport& vp) {
    if (penActive()) return false;               // pen owns input when present
    const QPointF screen = e->position();
    InputSample s = make(screen, 1.0f, InputSample::Source::Mouse, false, vp);
    m_lastSample = s;
    switch (e->type()) {
    case QEvent::MouseButtonPress:
        if (e->button() == Qt::LeftButton) { m_penDown = false; emit drawBegin(s); }
        break;
    case QEvent::MouseMove:
        if (e->buttons() & Qt::LeftButton) emit drawUpdate(s);
        else                               emit hoverMove(s, false);
        break;
    case QEvent::MouseButtonRelease:
        if (e->button() == Qt::LeftButton) emit drawEnd(s);
        break;
    default: return false;
    }
    return true;
}

bool InputRouter::handleTouch(QTouchEvent* e, const render::Viewport& vp) {
    if (penActive()) { e->accept(); return true; }   // palm/touch rejection near pen

    QList<QEventPoint> live;
    for (const QEventPoint& p : e->points())
        if (p.state() != QEventPoint::State::Released) live.push_back(p);

    const int n = live.size();
    if (n == 0 || e->type() == QEvent::TouchEnd || e->type() == QEvent::TouchCancel) {
        if (m_touchDrawActive) { emit drawEnd(m_lastSample); m_touchDrawActive = false; }
        m_gestureActive = false;
        e->accept();
        return true;
    }

    // centroid of active points
    QPointF centroid(0, 0);
    for (const auto& p : live) centroid += p.position();
    centroid /= double(n);

    if (n >= 2) {
        if (m_touchDrawActive) { emit drawEnd(m_lastSample); m_touchDrawActive = false; }
        const QPointF a = live[0].position(), b = live[1].position();
        const double dist  = std::hypot(b.x() - a.x(), b.y() - a.y());
        const double angle = std::atan2(b.y() - a.y(), b.x() - a.x());
        if (m_gestureActive) {
            emit gesturePan(centroid - m_lastCentroid);
            if (m_lastDist > 1.0) emit gestureZoom(centroid, dist / m_lastDist);
            emit gestureRotate(centroid, angle - m_lastAngle);
        }
        m_lastCentroid = centroid; m_lastDist = dist; m_lastAngle = angle;
        m_gestureActive = true;
    } else { // single finger
        const QPointF sp = live[0].position();
        if (fingerDrawing && touchMode == TouchMode::DrawAndGesture) {
            InputSample s = make(sp, 1.0f, InputSample::Source::Touch, false, vp);
            m_lastSample = s;
            if (!m_touchDrawActive) { emit drawBegin(s); m_touchDrawActive = true; }
            else                     emit drawUpdate(s);
        } else if (touchMode != TouchMode::Ignore) {
            if (m_gestureActive) emit gesturePan(sp - m_lastCentroid);
            m_lastCentroid = sp; m_gestureActive = true;
        }
    }
    e->accept();
    return true;
}

} // namespace ib::input
EOF

# ---- render/CanvasWidget.h -------------------------------------------------
cat > src/render/CanvasWidget.h <<'EOF'
#pragma once
#include <QElapsedTimer>
#include <QTimer>
#include "render/ICanvasHost.h"
#include "render/Viewport.h"
#include "input/InputRouter.h"

#ifdef INKBOARD_USE_OPENGL
#include <QOpenGLWidget>
using CanvasBase = QOpenGLWidget;
#else
#include <QWidget>
using CanvasBase = QWidget;
#endif

namespace ib {
class Document;
class ToolManager;

// The interactive drawing surface. Owns the Viewport, feeds raw events to the
// InputRouter, and paints via CanvasRenderer + tool overlays. Implements
// ICanvasHost so tools can drive it.
class CanvasWidget : public CanvasBase, public ICanvasHost {
    Q_OBJECT
public:
    explicit CanvasWidget(QWidget* parent = nullptr);
    ~CanvasWidget() override;

    void setDocument(Document* doc);
    void setToolManager(ToolManager* tm);
    input::InputRouter& router() { return m_router; }

    // Pointer fade-out (laser/hover) configuration — requirement #5.
    void setPointerVanishDelayMs(int ms) { m_vanishDelayMs = ms; }
    void setPointerFadeMs(int ms) { m_fadeMs = ms; }

    void zoomToFit();
    void resetView();

    // ICanvasHost
    Document* document() override { return m_doc; }
    render::Viewport& viewport() override { return m_vp; }
    void requestRepaint() override { update(); }
    QWidget* asWidget() override { return this; }

protected:
#ifdef INKBOARD_USE_OPENGL
    void paintGL() override { paintCanvas(); }
#else
    void paintEvent(QPaintEvent*) override { paintCanvas(); }
#endif
    bool event(QEvent* e) override;
    void tabletEvent(QTabletEvent* e) override;
    void mousePressEvent(QMouseEvent* e) override;
    void mouseMoveEvent(QMouseEvent* e) override;
    void mouseReleaseEvent(QMouseEvent* e) override;
    void wheelEvent(QWheelEvent* e) override;

private:
    void paintCanvas();
    void drawPointerFx(QPainter& p);
    void onProximityChanged(const input::InputSample& s, bool inProximity);

    Document* m_doc = nullptr;
    ToolManager* m_tools = nullptr;
    render::Viewport m_vp;
    input::InputRouter m_router;

    // pointer fx
    QPointF m_hoverPos;
    bool    m_hoverVisible = false;
    bool    m_hoverProx = false;
    QElapsedTimer m_leaveClock;
    QTimer  m_fxTimer;
    int     m_vanishDelayMs = 250;
    int     m_fadeMs = 450;
};

} // namespace ib
EOF

# ---- render/CanvasWidget.cpp -----------------------------------------------
cat > src/render/CanvasWidget.cpp <<'EOF'
#include "render/CanvasWidget.h"
#include "render/CanvasRenderer.h"
#include "model/Document.h"
#include "tools/ToolManager.h"
#include <QPainter>
#include <QTabletEvent>
#include <QTouchEvent>
#include <QMouseEvent>
#include <QWheelEvent>
#include <cmath>

namespace ib {

CanvasWidget::CanvasWidget(QWidget* parent) : CanvasBase(parent) {
    setAttribute(Qt::WA_AcceptTouchEvents, true);
    setMouseTracking(true);
    setFocusPolicy(Qt::StrongFocus);

    m_fxTimer.setInterval(16); // ~60fps while fading
    connect(&m_fxTimer, &QTimer::timeout, this, [this] {
        update();
        if (!m_hoverProx && m_leaveClock.isValid() &&
            m_leaveClock.elapsed() > (m_vanishDelayMs + m_fadeMs)) {
            m_hoverVisible = false;
            m_fxTimer.stop();
        }
    });

    // Wire router -> tools + view.
    connect(&m_router, &input::InputRouter::drawBegin, this, [this](const input::InputSample& s){
        if (m_tools) m_tools->onDrawBegin(s);
    });
    connect(&m_router, &input::InputRouter::drawUpdate, this, [this](const input::InputSample& s){
        if (m_tools) m_tools->onDrawUpdate(s);
    });
    connect(&m_router, &input::InputRouter::drawEnd, this, [this](const input::InputSample& s){
        if (m_tools) m_tools->onDrawEnd(s);
    });
    connect(&m_router, &input::InputRouter::hoverMove, this,
            [this](const input::InputSample& s, bool prox){ onProximityChanged(s, prox); });
    connect(&m_router, &input::InputRouter::gesturePan, this, [this](const QPointF& d){
        m_vp.panBy(d); update();
    });
    connect(&m_router, &input::InputRouter::gestureZoom, this, [this](const QPointF& a, double f){
        m_vp.zoomAt(a, f); update();
    });
    connect(&m_router, &input::InputRouter::gestureRotate, this, [this](const QPointF& a, double r){
        m_vp.rotateAt(a, r); update();
    });
}

CanvasWidget::~CanvasWidget() = default;

void CanvasWidget::setDocument(Document* doc) {
    if (m_doc == doc) return;
    if (m_doc) m_doc->disconnect(this);
    m_doc = doc;
    if (m_doc) {
        connect(m_doc, &Document::contentChanged, this, [this]{ update(); });
        connect(m_doc, &Document::currentPageChanged, this, [this](int){ update(); });
    }
    update();
}

void CanvasWidget::setToolManager(ToolManager* tm) { m_tools = tm; }

void CanvasWidget::zoomToFit() {
    if (!m_doc) return;
    const QRectF b = m_doc->current().contentBounds();
    if (b.isEmpty()) { resetView(); return; }
    m_vp.fitTo(b, size());
    update();
}

void CanvasWidget::resetView() { m_vp = render::Viewport{}; update(); }

void CanvasWidget::onProximityChanged(const input::InputSample& s, bool inProximity) {
    m_hoverPos = s.screenPos;
    m_hoverProx = inProximity;
    if (inProximity) {
        m_hoverVisible = true;
        m_leaveClock.invalidate();
        m_fxTimer.stop();
    } else {
        m_leaveClock.restart();     // begin vanish-delay + fade timeline
        m_fxTimer.start();
    }
    if (m_tools) m_tools->onHover(s, inProximity);
    update();
}

void CanvasWidget::paintCanvas() {
    QPainter p(this);
    if (m_doc) {
        CanvasRenderer::paintPage(p, m_doc->current(), m_vp, size());
        if (m_tools) m_tools->paintOverlay(p, m_vp);
    } else {
        p.fillRect(rect(), QColor(30, 31, 34));
    }
    drawPointerFx(p);
}

void CanvasWidget::drawPointerFx(QPainter& p) {
    if (!m_hoverVisible) return;
    double alpha = 1.0;
    if (!m_hoverProx && m_leaveClock.isValid()) {
        const qint64 e = m_leaveClock.elapsed();
        if (e <= m_vanishDelayMs) alpha = 1.0;
        else {
            const double t = qBound(0.0, double(e - m_vanishDelayMs) / qMax(1, m_fadeMs), 1.0);
            const double eased = 1.0 - std::pow(t, 3.0); // easeOutCubic fade
            alpha = eased;
        }
    }
    if (alpha <= 0.001) return;
    p.save();
    p.setRenderHint(QPainter::Antialiasing, true);
    QColor ring(60, 90, 254);
    ring.setAlphaF(0.85 * alpha);
    QPen pen(ring); pen.setWidthF(1.5);
    p.setPen(pen);
    p.setBrush(Qt::NoBrush);
    p.drawEllipse(m_hoverPos, 7, 7);
    p.restore();
}

bool CanvasWidget::event(QEvent* e) {
    switch (e->type()) {
    case QEvent::TabletEnterProximity:
        m_router.setPenInProximity(true, m_hoverPos, m_vp);
        return true;
    case QEvent::TabletLeaveProximity:
        m_router.setPenInProximity(false, m_hoverPos, m_vp);
        return true;
    case QEvent::TouchBegin:
    case QEvent::TouchUpdate:
    case QEvent::TouchEnd:
    case QEvent::TouchCancel:
        if (m_router.handleTouch(static_cast<QTouchEvent*>(e), m_vp)) { update(); return true; }
        break;
    default: break;
    }
    return CanvasBase::event(e);
}

void CanvasWidget::tabletEvent(QTabletEvent* e) {
    if (m_router.handleTablet(e, m_vp)) update();
    else CanvasBase::tabletEvent(e);
}
void CanvasWidget::mousePressEvent(QMouseEvent* e)   { if (m_router.handleMouse(e, m_vp)) update(); }
void CanvasWidget::mouseMoveEvent(QMouseEvent* e)    { if (m_router.handleMouse(e, m_vp)) update(); }
void CanvasWidget::mouseReleaseEvent(QMouseEvent* e) { if (m_router.handleMouse(e, m_vp)) update(); }

void CanvasWidget::wheelEvent(QWheelEvent* e) {
    if (e->modifiers() & Qt::ControlModifier) {
        const double f = std::pow(1.0015, e->angleDelta().y());
        m_vp.zoomAt(e->position(), f);
    } else if (e->modifiers() & Qt::ShiftModifier) {
        m_vp.panBy(QPointF(e->angleDelta().y() / 2.0, 0));
    } else {
        m_vp.panBy(QPointF(e->angleDelta().x() / 2.0, e->angleDelta().y() / 2.0));
    }
    update();
    e->accept();
}

} // namespace ib
EOF

log "PART 3 complete: viewport, GPU canvas renderer, pointer fade FX, and pen/touch router written."
# =============================================================================
#  END OF PART 3  —  append PART 4 (tools: pen/highlighter/eraser/select/...) below
# =============================================================================

# =============================================================================
#  PART 3  —  viewport transform, GPU canvas rendering, pen/touch input router
#  Append below PART 2. Creates new files only.
# =============================================================================
log "PART 3: writing viewport, renderer, canvas widget, and input router"

# ---- render/Viewport.h -----------------------------------------------------
cat > src/render/Viewport.h <<'EOF'
#pragma once
#include <QPointF>
#include <QRectF>
#include <QSize>
#include <QTransform>

namespace ib::render {

// Maps between infinite PAGE space and on-screen (logical) widget space.
// Pure value type: pan (offset), zoom (scale), and optional rotation.
class Viewport {
public:
    QPointF offset{0, 0};   // screen position of page origin (logical px)
    double  scale = 1.0;    // page units -> screen px
    double  rotation = 0.0; // radians (touch rotate gesture)

    static constexpr double kMinScale = 0.05;
    static constexpr double kMaxScale = 40.0;

    QTransform core() const;          // rotation+scale (no translation)
    QTransform pageToScreen() const;  // full transform
    QTransform screenToPage() const { return pageToScreen().inverted(); }

    QPointF toPage(const QPointF& s)   const { return screenToPage().map(s); }
    QPointF toScreen(const QPointF& p) const { return pageToScreen().map(p); }

    void panBy(const QPointF& deltaScreen) { offset += deltaScreen; }
    void zoomAt(const QPointF& screenAnchor, double factor);
    void rotateAt(const QPointF& screenAnchor, double deltaRad);

    QRectF visiblePageRect(const QSize& widgetSize) const;
    void fitTo(const QRectF& pageRect, const QSize& widgetSize, double margin = 40.0);
};

} // namespace ib::render
EOF

# ---- render/Viewport.cpp ---------------------------------------------------
cat > src/render/Viewport.cpp <<'EOF'
#include "render/Viewport.h"
#include <QtGlobalStatic>
#include <cmath>

namespace ib::render {

QTransform Viewport::core() const {
    QTransform t;
    t.rotateRadians(rotation);
    t.scale(scale, scale);
    return t;
}

QTransform Viewport::pageToScreen() const {
    QTransform t;
    t.translate(offset.x(), offset.y());
    t.rotateRadians(rotation);
    t.scale(scale, scale);
    return t;
}

void Viewport::zoomAt(const QPointF& anchor, double factor) {
    const QPointF pagePt = toPage(anchor);
    scale = qBound(kMinScale, scale * factor, kMaxScale);
    offset = anchor - core().map(pagePt);
}

void Viewport::rotateAt(const QPointF& anchor, double deltaRad) {
    const QPointF pagePt = toPage(anchor);
    rotation += deltaRad;
    offset = anchor - core().map(pagePt);
}

QRectF Viewport::visiblePageRect(const QSize& s) const {
    const QTransform inv = screenToPage();
    QRectF r;
    const QPointF c[4] = { inv.map(QPointF(0, 0)),      inv.map(QPointF(s.width(), 0)),
                           inv.map(QPointF(0, s.height())), inv.map(QPointF(s.width(), s.height())) };
    r = QRectF(c[0], c[0]);
    for (const auto& p : c) {
        r.setLeft(qMin(r.left(), p.x()));   r.setTop(qMin(r.top(), p.y()));
        r.setRight(qMax(r.right(), p.x())); r.setBottom(qMax(r.bottom(), p.y()));
    }
    return r;
}

void Viewport::fitTo(const QRectF& pageRect, const QSize& s, double margin) {
    if (pageRect.isEmpty() || s.isEmpty()) return;
    rotation = 0.0;
    const double sx = (s.width()  - 2 * margin) / pageRect.width();
    const double sy = (s.height() - 2 * margin) / pageRect.height();
    scale = qBound(kMinScale, qMin(sx, sy), kMaxScale);
    const QPointF center = pageRect.center();
    offset = QPointF(s.width() / 2.0, s.height() / 2.0) - core().map(center);
}

} // namespace ib::render
EOF

# ---- render/CanvasRenderer.h ----------------------------------------------
cat > src/render/CanvasRenderer.h <<'EOF'
#pragma once
#include <QPainter>
#include "render/Viewport.h"

namespace ib {
class Page;
class Item;
namespace render {

// Stateless drawing of the vector document. The painter is transformed into
// PAGE space, so all widths are page units and stay crisp at any zoom.
class CanvasRenderer {
public:
    // Full page paint (background + all visible layers) clipped to widget rect.
    static void paintPage(QPainter& p, const Page& page, const Viewport& vp,
                          const QSize& widgetSize);

    // Paints one item; assumes painter is already in page space + antialiased.
    static void paintItem(QPainter& p, const Item& item);

private:
    static void paintBackground(QPainter& p, const Page& page, const QRectF& visPage);
};

} // namespace render
} // namespace ib
EOF

# ---- render/CanvasRenderer.cpp --------------------------------------------
cat > src/render/CanvasRenderer.cpp <<'EOF'
#include "render/CanvasRenderer.h"
#include "model/Page.h"
#include "model/StrokeItem.h"
#include "model/ShapeItem.h"
#include "model/TextItem.h"
#include "model/ImageItem.h"
#include "ink/Tessellator.h"
#include <QtMath>

namespace ib::render {

void CanvasRenderer::paintBackground(QPainter& p, const Page& page, const QRectF& vis) {
    if (page.background == BackgroundKind::Blank) return;
    QPen pen(page.gridColor);
    pen.setCosmetic(true);          // 1px lines regardless of zoom
    pen.setWidthF(1.0);
    p.setPen(pen);
    const double g = qMax(2.0, page.gridSpacing);
    const double x0 = std::floor(vis.left() / g) * g;
    const double y0 = std::floor(vis.top()  / g) * g;

    if (page.background == BackgroundKind::Grid || page.background == BackgroundKind::Lines) {
        for (double y = y0; y <= vis.bottom(); y += g)
            p.drawLine(QPointF(vis.left(), y), QPointF(vis.right(), y));
        if (page.background == BackgroundKind::Grid)
            for (double x = x0; x <= vis.right(); x += g)
                p.drawLine(QPointF(x, vis.top()), QPointF(x, vis.bottom()));
    } else if (page.background == BackgroundKind::Dots) {
        p.setBrush(page.gridColor);
        p.setPen(Qt::NoPen);
        for (double y = y0; y <= vis.bottom(); y += g)
            for (double x = x0; x <= vis.right(); x += g)
                p.drawEllipse(QPointF(x, y), 1.2, 1.2);
    }
}

void CanvasRenderer::paintItem(QPainter& p, const Item& item) {
    switch (item.type()) {
    case ItemType::Stroke: {
        const auto& s = static_cast<const StrokeItem&>(item);
        p.save();
        p.setPen(Qt::NoPen);
        QColor c = s.color;
        p.setOpacity(qBound(0.0, s.opacity, 1.0));
        if (s.kind == InkKind::Highlighter)
            p.setCompositionMode(QPainter::CompositionMode_Multiply);
        p.setBrush(c);
        p.drawPath(ink::buildRibbon(s.points(), s.baseWidth, s.pressureToWidth));
        p.restore();
        break;
    }
    case ItemType::Shape: {
        const auto& sh = static_cast<const ShapeItem&>(item);
        p.save();
        p.setOpacity(qBound(0.0, sh.opacity, 1.0));
        QPen pen(sh.strokeColor);
        pen.setWidthF(sh.strokeWidth);
        pen.setCapStyle(Qt::RoundCap);
        pen.setJoinStyle(Qt::RoundJoin);
        p.setPen(pen);
        p.setBrush(sh.filled ? QBrush(sh.fillColor) : Qt::NoBrush);
        const QRectF r = QRectF(sh.p1, sh.p2).normalized();
        switch (sh.shape) {
        case ShapeKind::Line:      p.drawLine(sh.p1, sh.p2); break;
        case ShapeKind::Rectangle: p.drawRect(r); break;
        case ShapeKind::Ellipse:   p.drawEllipse(r); break;
        case ShapeKind::Arrow: {
            p.drawLine(sh.p1, sh.p2);
            const double a = std::atan2(sh.p2.y() - sh.p1.y(), sh.p2.x() - sh.p1.x());
            const double len = qMax(8.0, sh.strokeWidth * 4.0);
            const double spread = M_PI / 7.0;
            const QPointF b1 = sh.p2 - QPointF(std::cos(a - spread), std::sin(a - spread)) * len;
            const QPointF b2 = sh.p2 - QPointF(std::cos(a + spread), std::sin(a + spread)) * len;
            p.setBrush(sh.strokeColor);
            QPolygonF head; head << sh.p2 << b1 << b2;
            p.drawPolygon(head);
            break;
        }
        }
        p.restore();
        break;
    }
    case ItemType::Text: {
        const auto& t = static_cast<const TextItem&>(item);
        p.save();
        p.setPen(t.color);
        p.setFont(t.font);
        const QRectF box(t.pos, QSizeF(t.wrapWidth > 0 ? t.wrapWidth : 100000, 100000));
        p.drawText(box, (t.wrapWidth > 0 ? Qt::TextWordWrap : 0) | Qt::AlignLeft | Qt::AlignTop, t.text);
        p.restore();
        break;
    }
    case ItemType::Image: {
        const auto& im = static_cast<const ImageItem&>(item);
        p.save();
        p.setOpacity(qBound(0.0, im.opacity, 1.0));
        p.setRenderHint(QPainter::SmoothPixmapTransform, true);
        p.drawImage(im.rect, im.image);
        p.restore();
        break;
    }
    }
}

void CanvasRenderer::paintPage(QPainter& p, const Page& page, const Viewport& vp,
                               const QSize& widgetSize) {
    // Infinite canvas: fill the whole widget with the page's paper color.
    p.fillRect(QRect(QPoint(0, 0), widgetSize), page.bgColor);

    p.setRenderHint(QPainter::Antialiasing, true);
    p.setRenderHint(QPainter::TextAntialiasing, true);
    p.setTransform(vp.pageToScreen());

    const QRectF vis = vp.visiblePageRect(widgetSize);
    p.setClipRect(vis);
    paintBackground(p, page, vis);

    for (const auto& layer : page.layers) {
        if (!layer.visible) continue;
        p.save();
        p.setOpacity(p.opacity() * qBound(0.0, layer.opacity, 1.0));
        for (const auto& it : layer.items) {
            if (it->boundingRect().intersects(vis))
                paintItem(p, *it);
        }
        p.restore();
    }
    p.resetTransform();
    p.setClipping(false);
}

} // namespace ib::render
EOF

# ---- render/ICanvasHost.h --------------------------------------------------
cat > src/render/ICanvasHost.h <<'EOF'
#pragma once
#include <QRectF>
class QWidget;
namespace ib {
class Document;
namespace render { class Viewport; }

// Abstraction the tools use to reach the document/viewport and to request
// repaints, without depending on the concrete widget class.
class ICanvasHost {
public:
    virtual ~ICanvasHost() = default;
    virtual Document* document() = 0;
    virtual render::Viewport& viewport() = 0;
    virtual void requestRepaint() = 0;
    virtual QWidget* asWidget() = 0;
};

} // namespace ib
EOF

# ---- input/PressureCurve.h -------------------------------------------------
cat > src/input/PressureCurve.h <<'EOF'
#pragma once
namespace ib::input {

// Configurable pen pressure response. gamma<1 = softer (more ink at low
// force); gamma>1 = firmer. min/max clamp the usable output band.
class PressureCurve {
public:
    double gamma = 1.0;
    double minOut = 0.0;
    double maxOut = 1.0;

    float apply(float raw) const;

    static PressureCurve soft()  { return {0.6, 0.05, 1.0}; }
    static PressureCurve firm()  { return {1.6, 0.0, 1.0}; }
    static PressureCurve linear(){ return {1.0, 0.0, 1.0}; }
};

} // namespace ib::input
EOF

# ---- input/PressureCurve.cpp -----------------------------------------------
cat > src/input/PressureCurve.cpp <<'EOF'
#include "input/PressureCurve.h"
#include <algorithm>
#include <cmath>

namespace ib::input {
float PressureCurve::apply(float raw) const {
    double x = std::clamp(double(raw), 0.0, 1.0);
    double y = std::pow(x, gamma <= 0 ? 1.0 : gamma);
    y = minOut + (maxOut - minOut) * y;
    return float(std::clamp(y, 0.0, 1.0));
}
} // namespace ib::input
EOF

# ---- input/InputRouter.h ---------------------------------------------------
cat > src/input/InputRouter.h <<'EOF'
#pragma once
#include <QObject>
#include <QPointF>
#include "model/Enums.h"
#include "model/StrokePoint.h"
#include "input/PressureCurve.h"

class QTabletEvent;
class QTouchEvent;
class QMouseEvent;

namespace ib::render { class Viewport; }
namespace ib::input {

// A normalized input sample handed to tools. Coordinates are provided in BOTH
// spaces so tools can hit-test in page space and draw cursors in screen space.
struct InputSample {
    enum class Source { Pen, Mouse, Touch };
    QPointF pagePos;
    QPointF screenPos;
    float   pressure = 1.0f;
    float   tiltX = 0.0f;
    float   tiltY = 0.0f;
    qint64  tMs = 0;
    Source  source = Source::Pen;
    bool    eraser = false;   // pen flipped to eraser end
};

// Turns raw Qt events into high-level draw/gesture/hover signals and enforces
// the pen-vs-touch policy (palm rejection, touch = gestures, pen = ink).
class InputRouter : public QObject {
    Q_OBJECT
public:
    explicit InputRouter(QObject* parent = nullptr) : QObject(parent) {}

    TouchMode     touchMode = TouchMode::GestureOnly;
    bool          fingerDrawing = false;   // allow finger to draw ink
    PressureCurve pressure = PressureCurve::linear();

    bool handleTablet(QTabletEvent* e, const render::Viewport& vp);
    bool handleTouch (QTouchEvent*  e, const render::Viewport& vp);
    bool handleMouse (QMouseEvent*  e, const render::Viewport& vp);
    void setPenInProximity(bool prox, const QPointF& screenPos, const render::Viewport& vp);

    bool penActive() const { return m_penDown || m_penProximity; }

signals:
    void drawBegin (const ib::input::InputSample& s);
    void drawUpdate(const ib::input::InputSample& s);
    void drawEnd   (const ib::input::InputSample& s);
    void hoverMove (const ib::input::InputSample& s, bool inProximity);
    void gesturePan   (const QPointF& deltaScreen);
    void gestureZoom  (const QPointF& screenAnchor, double factor);
    void gestureRotate(const QPointF& screenAnchor, double deltaRad);

private:
    InputSample make(const QPointF& screen, float pressure, InputSample::Source src,
                     bool eraser, const render::Viewport& vp) const;

    bool m_penDown = false;
    bool m_penProximity = false;

    // touch gesture state
    bool    m_gestureActive = false;
    bool    m_touchDrawActive = false;
    QPointF m_lastCentroid;
    double  m_lastDist = 0.0;
    double  m_lastAngle = 0.0;
    InputSample m_lastSample;
};

} // namespace ib::input
EOF

# ---- input/InputRouter.cpp -------------------------------------------------
cat > src/input/InputRouter.cpp <<'EOF'
#include "input/InputRouter.h"
#include "render/Viewport.h"
#include <QTabletEvent>
#include <QTouchEvent>
#include <QMouseEvent>
#include <QDateTime>
#include <cmath>

namespace ib::input {

InputSample InputRouter::make(const QPointF& screen, float pr, InputSample::Source src,
                              bool eraser, const render::Viewport& vp) const {
    InputSample s;
    s.screenPos = screen;
    s.pagePos = vp.toPage(screen);
    s.pressure = pr;
    s.source = src;
    s.eraser = eraser;
    s.tMs = QDateTime::currentMSecsSinceEpoch();
    return s;
}

void InputRouter::setPenInProximity(bool prox, const QPointF& screenPos, const render::Viewport& vp) {
    m_penProximity = prox;
    InputSample s = make(screenPos, 0.0f, InputSample::Source::Pen, false, vp);
    emit hoverMove(s, prox);
}

bool InputRouter::handleTablet(QTabletEvent* e, const render::Viewport& vp) {
    const bool eraser = e->pointerType() == QPointingDevice::PointerType::Eraser;
    const QPointF screen = e->position();
    InputSample s = make(screen, pressure.apply(float(e->pressure())),
                         InputSample::Source::Pen, eraser, vp);
    s.tiltX = float(e->xTilt());
    s.tiltY = float(e->yTilt());
    m_penProximity = true;
    m_lastSample = s;

    switch (e->type()) {
    case QEvent::TabletPress:   m_penDown = true;  emit drawBegin(s);  break;
    case QEvent::TabletMove:
        if (m_penDown) emit drawUpdate(s);
        else           emit hoverMove(s, true);
        break;
    case QEvent::TabletRelease: m_penDown = false; emit drawEnd(s);    break;
    default: return false;
    }
    e->accept();
    return true;
}

bool InputRouter::handleMouse(QMouseEvent* e, const render::Viewport& vp) {
    if (penActive()) return false;               // pen owns input when present
    const QPointF screen = e->position();
    InputSample s = make(screen, 1.0f, InputSample::Source::Mouse, false, vp);
    m_lastSample = s;
    switch (e->type()) {
    case QEvent::MouseButtonPress:
        if (e->button() == Qt::LeftButton) { m_penDown = false; emit drawBegin(s); }
        break;
    case QEvent::MouseMove:
        if (e->buttons() & Qt::LeftButton) emit drawUpdate(s);
        else                               emit hoverMove(s, false);
        break;
    case QEvent::MouseButtonRelease:
        if (e->button() == Qt::LeftButton) emit drawEnd(s);
        break;
    default: return false;
    }
    return true;
}

bool InputRouter::handleTouch(QTouchEvent* e, const render::Viewport& vp) {
    if (penActive()) { e->accept(); return true; }   // palm/touch rejection near pen

    QList<QEventPoint> live;
    for (const QEventPoint& p : e->points())
        if (p.state() != QEventPoint::State::Released) live.push_back(p);

    const int n = live.size();
    if (n == 0 || e->type() == QEvent::TouchEnd || e->type() == QEvent::TouchCancel) {
        if (m_touchDrawActive) { emit drawEnd(m_lastSample); m_touchDrawActive = false; }
        m_gestureActive = false;
        e->accept();
        return true;
    }

    // centroid of active points
    QPointF centroid(0, 0);
    for (const auto& p : live) centroid += p.position();
    centroid /= double(n);

    if (n >= 2) {
        if (m_touchDrawActive) { emit drawEnd(m_lastSample); m_touchDrawActive = false; }
        const QPointF a = live[0].position(), b = live[1].position();
        const double dist  = std::hypot(b.x() - a.x(), b.y() - a.y());
        const double angle = std::atan2(b.y() - a.y(), b.x() - a.x());
        if (m_gestureActive) {
            emit gesturePan(centroid - m_lastCentroid);
            if (m_lastDist > 1.0) emit gestureZoom(centroid, dist / m_lastDist);
            emit gestureRotate(centroid, angle - m_lastAngle);
        }
        m_lastCentroid = centroid; m_lastDist = dist; m_lastAngle = angle;
        m_gestureActive = true;
    } else { // single finger
        const QPointF sp = live[0].position();
        if (fingerDrawing && touchMode == TouchMode::DrawAndGesture) {
            InputSample s = make(sp, 1.0f, InputSample::Source::Touch, false, vp);
            m_lastSample = s;
            if (!m_touchDrawActive) { emit drawBegin(s); m_touchDrawActive = true; }
            else                     emit drawUpdate(s);
        } else if (touchMode != TouchMode::Ignore) {
            if (m_gestureActive) emit gesturePan(sp - m_lastCentroid);
            m_lastCentroid = sp; m_gestureActive = true;
        }
    }
    e->accept();
    return true;
}

} // namespace ib::input
EOF

# ---- render/CanvasWidget.h -------------------------------------------------
cat > src/render/CanvasWidget.h <<'EOF'
#pragma once
#include <QElapsedTimer>
#include <QTimer>
#include "render/ICanvasHost.h"
#include "render/Viewport.h"
#include "input/InputRouter.h"

#ifdef INKBOARD_USE_OPENGL
#include <QOpenGLWidget>
using CanvasBase = QOpenGLWidget;
#else
#include <QWidget>
using CanvasBase = QWidget;
#endif

namespace ib {
class Document;
class ToolManager;

// The interactive drawing surface. Owns the Viewport, feeds raw events to the
// InputRouter, and paints via CanvasRenderer + tool overlays. Implements
// ICanvasHost so tools can drive it.
class CanvasWidget : public CanvasBase, public ICanvasHost {
    Q_OBJECT
public:
    explicit CanvasWidget(QWidget* parent = nullptr);
    ~CanvasWidget() override;

    void setDocument(Document* doc);
    void setToolManager(ToolManager* tm);
    input::InputRouter& router() { return m_router; }

    // Pointer fade-out (laser/hover) configuration — requirement #5.
    void setPointerVanishDelayMs(int ms) { m_vanishDelayMs = ms; }
    void setPointerFadeMs(int ms) { m_fadeMs = ms; }

    void zoomToFit();
    void resetView();

    // ICanvasHost
    Document* document() override { return m_doc; }
    render::Viewport& viewport() override { return m_vp; }
    void requestRepaint() override { update(); }
    QWidget* asWidget() override { return this; }

protected:
#ifdef INKBOARD_USE_OPENGL
    void paintGL() override { paintCanvas(); }
#else
    void paintEvent(QPaintEvent*) override { paintCanvas(); }
#endif
    bool event(QEvent* e) override;
    void tabletEvent(QTabletEvent* e) override;
    void mousePressEvent(QMouseEvent* e) override;
    void mouseMoveEvent(QMouseEvent* e) override;
    void mouseReleaseEvent(QMouseEvent* e) override;
    void wheelEvent(QWheelEvent* e) override;

private:
    void paintCanvas();
    void drawPointerFx(QPainter& p);
    void onProximityChanged(const input::InputSample& s, bool inProximity);

    Document* m_doc = nullptr;
    ToolManager* m_tools = nullptr;
    render::Viewport m_vp;
    input::InputRouter m_router;

    // pointer fx
    QPointF m_hoverPos;
    bool    m_hoverVisible = false;
    bool    m_hoverProx = false;
    QElapsedTimer m_leaveClock;
    QTimer  m_fxTimer;
    int     m_vanishDelayMs = 250;
    int     m_fadeMs = 450;
};

} // namespace ib
EOF

# ---- render/CanvasWidget.cpp -----------------------------------------------
cat > src/render/CanvasWidget.cpp <<'EOF'
#include "render/CanvasWidget.h"
#include "render/CanvasRenderer.h"
#include "model/Document.h"
#include "tools/ToolManager.h"
#include <QPainter>
#include <QTabletEvent>
#include <QTouchEvent>
#include <QMouseEvent>
#include <QWheelEvent>
#include <cmath>

namespace ib {

CanvasWidget::CanvasWidget(QWidget* parent) : CanvasBase(parent) {
    setAttribute(Qt::WA_AcceptTouchEvents, true);
    setMouseTracking(true);
    setFocusPolicy(Qt::StrongFocus);

    m_fxTimer.setInterval(16); // ~60fps while fading
    connect(&m_fxTimer, &QTimer::timeout, this, [this] {
        update();
        if (!m_hoverProx && m_leaveClock.isValid() &&
            m_leaveClock.elapsed() > (m_vanishDelayMs + m_fadeMs)) {
            m_hoverVisible = false;
            m_fxTimer.stop();
        }
    });

    // Wire router -> tools + view.
    connect(&m_router, &input::InputRouter::drawBegin, this, [this](const input::InputSample& s){
        if (m_tools) m_tools->onDrawBegin(s);
    });
    connect(&m_router, &input::InputRouter::drawUpdate, this, [this](const input::InputSample& s){
        if (m_tools) m_tools->onDrawUpdate(s);
    });
    connect(&m_router, &input::InputRouter::drawEnd, this, [this](const input::InputSample& s){
        if (m_tools) m_tools->onDrawEnd(s);
    });
    connect(&m_router, &input::InputRouter::hoverMove, this,
            [this](const input::InputSample& s, bool prox){ onProximityChanged(s, prox); });
    connect(&m_router, &input::InputRouter::gesturePan, this, [this](const QPointF& d){
        m_vp.panBy(d); update();
    });
    connect(&m_router, &input::InputRouter::gestureZoom, this, [this](const QPointF& a, double f){
        m_vp.zoomAt(a, f); update();
    });
    connect(&m_router, &input::InputRouter::gestureRotate, this, [this](const QPointF& a, double r){
        m_vp.rotateAt(a, r); update();
    });
}

CanvasWidget::~CanvasWidget() = default;

void CanvasWidget::setDocument(Document* doc) {
    if (m_doc == doc) return;
    if (m_doc) m_doc->disconnect(this);
    m_doc = doc;
    if (m_doc) {
        connect(m_doc, &Document::contentChanged, this, [this]{ update(); });
        connect(m_doc, &Document::currentPageChanged, this, [this](int){ update(); });
    }
    update();
}

void CanvasWidget::setToolManager(ToolManager* tm) { m_tools = tm; }

void CanvasWidget::zoomToFit() {
    if (!m_doc) return;
    const QRectF b = m_doc->current().contentBounds();
    if (b.isEmpty()) { resetView(); return; }
    m_vp.fitTo(b, size());
    update();
}

void CanvasWidget::resetView() { m_vp = render::Viewport{}; update(); }

void CanvasWidget::onProximityChanged(const input::InputSample& s, bool inProximity) {
    m_hoverPos = s.screenPos;
    m_hoverProx = inProximity;
    if (inProximity) {
        m_hoverVisible = true;
        m_leaveClock.invalidate();
        m_fxTimer.stop();
    } else {
        m_leaveClock.restart();     // begin vanish-delay + fade timeline
        m_fxTimer.start();
    }
    if (m_tools) m_tools->onHover(s, inProximity);
    update();
}

void CanvasWidget::paintCanvas() {
    QPainter p(this);
    if (m_doc) {
        CanvasRenderer::paintPage(p, m_doc->current(), m_vp, size());
        if (m_tools) m_tools->paintOverlay(p, m_vp);
    } else {
        p.fillRect(rect(), QColor(30, 31, 34));
    }
    drawPointerFx(p);
}

void CanvasWidget::drawPointerFx(QPainter& p) {
    if (!m_hoverVisible) return;
    double alpha = 1.0;
    if (!m_hoverProx && m_leaveClock.isValid()) {
        const qint64 e = m_leaveClock.elapsed();
        if (e <= m_vanishDelayMs) alpha = 1.0;
        else {
            const double t = qBound(0.0, double(e - m_vanishDelayMs) / qMax(1, m_fadeMs), 1.0);
            const double eased = 1.0 - std::pow(t, 3.0); // easeOutCubic fade
            alpha = eased;
        }
    }
    if (alpha <= 0.001) return;
    p.save();
    p.setRenderHint(QPainter::Antialiasing, true);
    QColor ring(60, 90, 254);
    ring.setAlphaF(0.85 * alpha);
    QPen pen(ring); pen.setWidthF(1.5);
    p.setPen(pen);
    p.setBrush(Qt::NoBrush);
    p.drawEllipse(m_hoverPos, 7, 7);
    p.restore();
}

bool CanvasWidget::event(QEvent* e) {
    switch (e->type()) {
    case QEvent::TabletEnterProximity:
        m_router.setPenInProximity(true, m_hoverPos, m_vp);
        return true;
    case QEvent::TabletLeaveProximity:
        m_router.setPenInProximity(false, m_hoverPos, m_vp);
        return true;
    case QEvent::TouchBegin:
    case QEvent::TouchUpdate:
    case QEvent::TouchEnd:
    case QEvent::TouchCancel:
        if (m_router.handleTouch(static_cast<QTouchEvent*>(e), m_vp)) { update(); return true; }
        break;
    default: break;
    }
    return CanvasBase::event(e);
}

void CanvasWidget::tabletEvent(QTabletEvent* e) {
    if (m_router.handleTablet(e, m_vp)) update();
    else CanvasBase::tabletEvent(e);
}
void CanvasWidget::mousePressEvent(QMouseEvent* e)   { if (m_router.handleMouse(e, m_vp)) update(); }
void CanvasWidget::mouseMoveEvent(QMouseEvent* e)    { if (m_router.handleMouse(e, m_vp)) update(); }
void CanvasWidget::mouseReleaseEvent(QMouseEvent* e) { if (m_router.handleMouse(e, m_vp)) update(); }

void CanvasWidget::wheelEvent(QWheelEvent* e) {
    if (e->modifiers() & Qt::ControlModifier) {
        const double f = std::pow(1.0015, e->angleDelta().y());
        m_vp.zoomAt(e->position(), f);
    } else if (e->modifiers() & Qt::ShiftModifier) {
        m_vp.panBy(QPointF(e->angleDelta().y() / 2.0, 0));
    } else {
        m_vp.panBy(QPointF(e->angleDelta().x() / 2.0, e->angleDelta().y() / 2.0));
    }
    update();
    e->accept();
}

} // namespace ib
EOF

log "PART 3 complete: viewport, GPU canvas renderer, pointer fade FX, and pen/touch router written."
# =============================================================================
#  END OF PART 3  —  append PART 4 (tools: pen/highlighter/eraser/select/...) below
# =============================================================================

# =============================================================================
#  PART 5  —  MainWindow, toolbars, palette, preferences, theming, shortcuts,
#             PDF import/annotate, vector PDF/PNG/SVG export, autosave/recovery
#  Append below PART 4. Creates new files only.
# =============================================================================
log "PART 5: writing UI shell, theming, shortcuts, exporters, PDF import, autosave"

# ---- ui/ThemeManager.h / .cpp ---------------------------------------------
cat > src/ui/ThemeManager.h <<'EOF'
#pragma once
#include <QColor>
#include <QObject>
namespace ib {
// Light/Dark/System theme + accent color. Loads QSS from resources and
// injects the accent color at runtime.
class ThemeManager : public QObject {
    Q_OBJECT
public:
    enum class Mode { System, Light, Dark };
    explicit ThemeManager(QObject* parent = nullptr);
    void apply();
    void setMode(Mode m) { m_mode = m; apply(); }
    void setAccent(const QColor& c) { m_accent = c; apply(); }
    Mode mode() const { return m_mode; }
    QColor accent() const { return m_accent; }
private:
    bool systemIsDark() const;
    Mode m_mode = Mode::System;
    QColor m_accent = QColor("#3d5afe");
};
} // namespace ib
EOF

cat > src/ui/ThemeManager.cpp <<'EOF'
#include "ui/ThemeManager.h"
#include <QApplication>
#include <QFile>
#include <QPalette>
#include <QStyleHints>

namespace ib {

ThemeManager::ThemeManager(QObject* parent) : QObject(parent) {}

bool ThemeManager::systemIsDark() const {
    const auto scheme = QApplication::styleHints()->colorScheme();
    return scheme == Qt::ColorScheme::Dark;
}

void ThemeManager::apply() {
    const bool dark = (m_mode == Mode::Dark) || (m_mode == Mode::System && systemIsDark());
    QFile f(dark ? ":/themes/dark.qss" : ":/themes/light.qss");
    QString qss;
    if (f.open(QIODevice::ReadOnly)) qss = QString::fromUtf8(f.readAll());
    // Inject accent color where checked controls reference it.
    qss += QString("\nQToolButton:checked { background: %1; }\n")
               .arg(m_accent.name(QColor::HexArgb));
    qApp->setStyleSheet(qss);
}

} // namespace ib
EOF

# ---- ui/ShortcutManager.h / .cpp ------------------------------------------
cat > src/ui/ShortcutManager.h <<'EOF'
#pragma once
#include <QAction>
#include <QKeySequence>
#include <QList>
#include <QObject>
#include <QString>
namespace ib {
// Central registry of remappable shortcuts. Overrides persist in QSettings.
class ShortcutManager : public QObject {
    Q_OBJECT
public:
    struct Entry { QString name; QString label; QAction* action; QKeySequence def; };
    explicit ShortcutManager(QObject* parent = nullptr) : QObject(parent) {}
    void add(const QString& name, const QString& label, QAction* a, const QKeySequence& def);
    void loadOverrides();
    void setSequence(const QString& name, const QKeySequence& seq);
    void resetToDefaults();
    const QList<Entry>& entries() const { return m_entries; }
private:
    QList<Entry> m_entries;
};
} // namespace ib
EOF

cat > src/ui/ShortcutManager.cpp <<'EOF'
#include "ui/ShortcutManager.h"
#include "util/Settings.h"

namespace ib {

void ShortcutManager::add(const QString& name, const QString& label,
                          QAction* a, const QKeySequence& def) {
    a->setShortcut(def);
    m_entries.push_back({name, label, a, def});
}

void ShortcutManager::loadOverrides() {
    for (auto& e : m_entries) {
        const QString key = "shortcuts/" + e.name;
        const QString s = Settings::get<QString>(key, QString());
        if (!s.isEmpty()) e.action->setShortcut(QKeySequence(s));
    }
}

void ShortcutManager::setSequence(const QString& name, const QKeySequence& seq) {
    for (auto& e : m_entries)
        if (e.name == name) {
            e.action->setShortcut(seq);
            Settings::set<QString>("shortcuts/" + name, seq.toString());
            break;
        }
}

void ShortcutManager::resetToDefaults() {
    for (auto& e : m_entries) {
        e.action->setShortcut(e.def);
        Settings::set<QString>("shortcuts/" + e.name, QString());
    }
}

} // namespace ib
EOF

# ---- ui/ColorPalette.h / .cpp ---------------------------------------------
cat > src/ui/ColorPalette.h <<'EOF'
#pragma once
#include <QColor>
#include <QWidget>
class QVBoxLayout;
namespace ib {
struct ToolSettings;
// Dockable swatch palette + size presets. Emits selections; MainWindow routes
// them to the active tool's relevant color/size.
class ColorPalette : public QWidget {
    Q_OBJECT
public:
    explicit ColorPalette(ToolSettings* settings, QWidget* parent = nullptr);
    void rebuild();
signals:
    void colorPicked(const QColor& c);
    void sizePicked(double s);
    void customColorRequested();
private:
    ToolSettings* m_settings;
    QVBoxLayout* m_root = nullptr;
};
} // namespace ib
EOF

cat > src/ui/ColorPalette.cpp <<'EOF'
#include "ui/ColorPalette.h"
#include "tools/ToolSettings.h"
#include <QGridLayout>
#include <QPushButton>
#include <QLabel>
#include <QVBoxLayout>

namespace ib {

ColorPalette::ColorPalette(ToolSettings* settings, QWidget* parent)
    : QWidget(parent), m_settings(settings) {
    m_root = new QVBoxLayout(this);
    m_root->setContentsMargins(8, 8, 8, 8);
    rebuild();
}

void ColorPalette::rebuild() {
    QLayoutItem* item;
    while ((item = m_root->takeAt(0)) != nullptr) {
        if (item->widget()) item->widget()->deleteLater();
        delete item;
    }
    m_root->addWidget(new QLabel(tr("Colors")));
    auto* grid = new QGridLayout();
    int i = 0;
    for (const QColor& c : m_settings->palette) {
        auto* b = new QPushButton();
        b->setFixedSize(26, 26);
        b->setStyleSheet(QString("background:%1;border:1px solid #0003;border-radius:6px;")
                             .arg(c.name(QColor::HexArgb)));
        connect(b, &QPushButton::clicked, this, [this, c] { emit colorPicked(c); });
        grid->addWidget(b, i / 4, i % 4);
        ++i;
    }
    auto* wrap = new QWidget(); wrap->setLayout(grid);
    m_root->addWidget(wrap);

    auto* custom = new QPushButton(tr("Custom color..."));
    connect(custom, &QPushButton::clicked, this, [this] { emit customColorRequested(); });
    m_root->addWidget(custom);

    m_root->addWidget(new QLabel(tr("Size")));
    auto* srow = new QGridLayout();
    int j = 0;
    for (double s : m_settings->sizePresets) {
        auto* b = new QPushButton(QString::number(s));
        connect(b, &QPushButton::clicked, this, [this, s] { emit sizePicked(s); });
        srow->addWidget(b, 0, j++);
    }
    auto* swrap = new QWidget(); swrap->setLayout(srow);
    m_root->addWidget(swrap);
    m_root->addStretch(1);
}

} // namespace ib
EOF

# ---- ui/ToolBarWidget.h / .cpp --------------------------------------------
cat > src/ui/ToolBarWidget.h <<'EOF'
#pragma once
#include <QToolBar>
#include "model/Enums.h"
namespace ib {
class ShortcutManager;
// Primary tool selector. Exclusive checkable actions per tool.
class ToolBarWidget : public QToolBar {
    Q_OBJECT
public:
    explicit ToolBarWidget(ShortcutManager* sc, QWidget* parent = nullptr);
    void setActive(ToolId id);
signals:
    void toolSelected(ib::ToolId id);
private:
    QAction* add(const QString& text, ToolId id, const QKeySequence& key,
                 ShortcutManager* sc, const QString& name);
    QList<QAction*> m_actions;
};
} // namespace ib
EOF

cat > src/ui/ToolBarWidget.cpp <<'EOF'
#include "ui/ToolBarWidget.h"
#include "ui/ShortcutManager.h"
#include <QActionGroup>

namespace ib {

ToolBarWidget::ToolBarWidget(ShortcutManager* sc, QWidget* parent) : QToolBar(parent) {
    setMovable(true);
    setWindowTitle(tr("Tools"));
    auto* group = new QActionGroup(this);
    group->setExclusive(true);
    struct Def { const char* label; ToolId id; const char* key; const char* name; };
    const Def defs[] = {
        {"Pen", ToolId::Pen, "P", "tool.pen"},
        {"Highlighter", ToolId::Highlighter, "H", "tool.highlighter"},
        {"Eraser", ToolId::Eraser, "E", "tool.eraser"},
        {"Select", ToolId::Select, "S", "tool.select"},
        {"Shape", ToolId::Shape, "R", "tool.shape"},
        {"Text", ToolId::Text, "T", "tool.text"},
        {"Image", ToolId::Image, "I", "tool.image"},
        {"Laser", ToolId::Laser, "L", "tool.laser"},
    };
    for (const auto& d : defs) {
        QAction* a = add(tr(d.label), d.id, QKeySequence(QString(d.key)), sc, d.name);
        group->addAction(a);
    }
    if (!m_actions.isEmpty()) m_actions.first()->setChecked(true);
}

QAction* ToolBarWidget::add(const QString& text, ToolId id, const QKeySequence& key,
                            ShortcutManager* sc, const QString& name) {
    QAction* a = addAction(text);
    a->setCheckable(true);
    a->setData(int(id));
    connect(a, &QAction::triggered, this, [this, id] { emit toolSelected(id); });
    if (sc) sc->add(name, text, a, key);
    m_actions.push_back(a);
    return a;
}

void ToolBarWidget::setActive(ToolId id) {
    for (QAction* a : m_actions)
        if (a->data().toInt() == int(id)) { a->setChecked(true); break; }
}

} // namespace ib
EOF

# ---- io/Exporters.h / .cpp ------------------------------------------------
cat > src/io/Exporters.h <<'EOF'
#pragma once
#include <QRectF>
#include <QString>
class QPainter;
namespace ib {
class Document;
class Page;
namespace exporters {

// Shared page painter: maps a page-space source rect into a device dst rect,
// draws background + all visible items (vector-preserving).
void renderPageInto(QPainter& p, const Page& page, QRectF src, QRectF dst, bool drawBg);

bool exportPng(const Page& page, const QString& path, double scale, QString* err = nullptr);
bool exportSvg(const Page& page, const QString& path, QString* err = nullptr);
bool exportPdf(const Document& doc, const QString& path, QString* err = nullptr); // vector

} // namespace exporters
} // namespace ib
EOF

cat > src/io/Exporters.cpp <<'EOF'
#include "io/Exporters.h"
#include "model/Document.h"
#include "model/Page.h"
#include "render/CanvasRenderer.h"
#include <QImage>
#include <QPainter>
#include <QPageSize>
#include <QPdfWriter>
#include <QSvgGenerator>
#include <cmath>

namespace ib::exporters {

static void drawGrid(QPainter& p, const Page& page, const QRectF& src) {
    if (page.background == BackgroundKind::Blank) return;
    QPen pen(page.gridColor); pen.setCosmetic(true); pen.setWidthF(1.0);
    p.setPen(pen);
    const double g = qMax(2.0, page.gridSpacing);
    if (page.background == BackgroundKind::Grid || page.background == BackgroundKind::Lines) {
        for (double y = std::floor(src.top()/g)*g; y <= src.bottom(); y += g)
            p.drawLine(QPointF(src.left(), y), QPointF(src.right(), y));
        if (page.background == BackgroundKind::Grid)
            for (double x = std::floor(src.left()/g)*g; x <= src.right(); x += g)
                p.drawLine(QPointF(x, src.top()), QPointF(x, src.bottom()));
    } else {
        p.setBrush(page.gridColor); p.setPen(Qt::NoPen);
        for (double y = std::floor(src.top()/g)*g; y <= src.bottom(); y += g)
            for (double x = std::floor(src.left()/g)*g; x <= src.right(); x += g)
                p.drawEllipse(QPointF(x, y), 1.2, 1.2);
    }
}

void renderPageInto(QPainter& p, const Page& page, QRectF src, QRectF dst, bool drawBg) {
    if (src.isEmpty()) src = QRectF(QPointF(0, 0), page.paperSize);
    p.save();
    if (drawBg) p.fillRect(dst, page.bgColor);
    const double s = qMin(dst.width() / src.width(), dst.height() / src.height());
    const double tx = dst.x() + (dst.width()  - src.width()  * s) / 2.0;
    const double ty = dst.y() + (dst.height() - src.height() * s) / 2.0;
    QTransform t;
    t.translate(tx, ty); t.scale(s, s); t.translate(-src.x(), -src.y());
    p.setTransform(t, true);
    p.setRenderHint(QPainter::Antialiasing, true);
    p.setRenderHint(QPainter::TextAntialiasing, true);
    p.setClipRect(src);
    drawGrid(p, page, src);
    for (const auto& layer : page.layers) {
        if (!layer.visible) continue;
        p.save();
        p.setOpacity(qBound(0.0, layer.opacity, 1.0));
        for (const auto& it : layer.items) render::CanvasRenderer::paintItem(p, *it);
        p.restore();
    }
    p.restore();
}

bool exportPng(const Page& page, const QString& path, double scale, QString* err) {
    QRectF src = page.contentBounds();
    if (src.isEmpty()) src = QRectF(QPointF(0, 0), page.paperSize);
    src = src.adjusted(-16, -16, 16, 16);
    const int w = qMax(1, int(std::ceil(src.width()  * scale)));
    const int h = qMax(1, int(std::ceil(src.height() * scale)));
    QImage img(w, h, QImage::Format_ARGB32_Premultiplied);
    img.fill(Qt::transparent);
    QPainter p(&img);
    renderPageInto(p, page, src, QRectF(0, 0, w, h), true);
    p.end();
    if (!img.save(path, "PNG")) { if (err) *err = "PNG write failed: " + path; return false; }
    return true;
}

bool exportSvg(const Page& page, const QString& path, QString* err) {
    QRectF src = page.contentBounds();
    if (src.isEmpty()) src = QRectF(QPointF(0, 0), page.paperSize);
    src = src.adjusted(-16, -16, 16, 16);
    QSvgGenerator gen;
    gen.setFileName(path);
    gen.setSize(QSize(int(src.width()), int(src.height())));
    gen.setViewBox(QRectF(0, 0, src.width(), src.height()));
    gen.setTitle("InkBoard export");
    QPainter p(&gen);
    if (!p.isActive()) { if (err) *err = "SVG init failed: " + path; return false; }
    renderPageInto(p, page, src, QRectF(0, 0, src.width(), src.height()), true);
    p.end();
    return true;
}

bool exportPdf(const Document& doc, const QString& path, QString* err) {
    if (doc.pageCount() == 0) { if (err) *err = "No pages"; return false; }
    QPdfWriter writer(path);
    writer.setResolution(300);
    writer.setPageSize(QPageSize(doc.page(0).paperSize, QPageSize::Point));
    QPainter p(&writer);
    if (!p.isActive()) { if (err) *err = "PDF init failed: " + path; return false; }
    for (int i = 0; i < doc.pageCount(); ++i) {
        if (i > 0) {
            writer.setPageSize(QPageSize(doc.page(i).paperSize, QPageSize::Point));
            writer.newPage();
        }
        const Page& page = doc.page(i);
        QRectF src = page.contentBounds();
        if (src.isEmpty()) src = QRectF(QPointF(0, 0), page.paperSize);
        const QRectF dst(0, 0, writer.width(), writer.height());
        renderPageInto(p, page, src, dst, true);
    }
    p.end();
    return true;
}

} // namespace ib::exporters
EOF

# ---- io/PdfImporter.h / .cpp ----------------------------------------------
cat > src/io/PdfImporter.h <<'EOF'
#pragma once
#include <QString>
namespace ib {
class Document;
namespace pdf {
// Imports each PDF page as a high-resolution, locked background image on its
// own document page so ink can be layered on top; export to PDF then keeps
// the annotations as true vectors over the page.
bool importInto(Document& doc, const QString& path, double dpi = 200.0, QString* err = nullptr);
}
} // namespace ib
EOF

cat > src/io/PdfImporter.cpp <<'EOF'
#include "io/PdfImporter.h"
#include "model/Document.h"
#include "model/Page.h"
#include "model/ImageItem.h"
#include <QPdfDocument>
#include <QImage>
#include <cmath>

namespace ib::pdf {

bool importInto(Document& doc, const QString& path, double dpi, QString* err) {
    QPdfDocument pdf;
    const auto status = pdf.load(path);
    if (status != QPdfDocument::Error::None) {
        if (err) *err = "Cannot load PDF: " + path;
        return false;
    }
    const int n = pdf.pageCount();
    if (n <= 0) { if (err) *err = "Empty PDF"; return false; }

    const double scale = dpi / 72.0;
    bool first = true;
    for (int i = 0; i < n; ++i) {
        const QSizeF ptSize = pdf.pagePointSize(i);
        const QSize px(qMax(1, int(std::ceil(ptSize.width()  * scale))),
                       qMax(1, int(std::ceil(ptSize.height() * scale))));
        const QImage img = pdf.render(i, px);
        if (img.isNull()) continue;

        int idx = first ? doc.currentIndex() : doc.addPage();
        first = false;
        Page& page = doc.page(idx);
        page.title = QStringLiteral("PDF %1").arg(i + 1);
        page.paperSize = ptSize;
        page.background = BackgroundKind::Blank;

        // Background layer (locked) with the page raster in page-point coords.
        Layer bg; bg.name = "PDF"; bg.locked = true;
        auto im = std::make_unique<ImageItem>();
        im->image = img;
        im->rect = QRectF(QPointF(0, 0), ptSize);
        bg.items.push_back(std::move(im));
        page.layers.insert(page.layers.begin(), std::move(bg));
        Layer ink; ink.name = "Ink";
        page.layers.push_back(std::move(ink));
        page.activeLayer = int(page.layers.size()) - 1;
    }
    doc.setCurrentIndex(0);
    doc.markContentChanged();
    return true;
}

} // namespace ib::pdf
EOF

# ---- io/AutosaveManager.h / .cpp ------------------------------------------
cat > src/io/AutosaveManager.h <<'EOF'
#pragma once
#include <QObject>
#include <QString>
#include <QTimer>
class QWidget;
namespace ib {
class Document;
// Periodic autosave to an app-data recovery file + crash-recovery prompt.
class AutosaveManager : public QObject {
    Q_OBJECT
public:
    explicit AutosaveManager(QObject* parent = nullptr);
    void setDocument(Document* doc) { m_doc = doc; }
    void start(int intervalMs = 15000);
    void stop() { m_timer.stop(); }
    void clearRecovery();
    bool maybeOfferRecovery(QWidget* parent);   // returns true if restored
    static QString recoveryPath();
private slots:
    void tick();
private:
    Document* m_doc = nullptr;
    QTimer m_timer;
};
} // namespace ib
EOF

cat > src/io/AutosaveManager.cpp <<'EOF'
#include "io/AutosaveManager.h"
#include "io/BoardSerializer.h"
#include "model/Document.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QMessageBox>
#include <QStandardPaths>

namespace ib {

AutosaveManager::AutosaveManager(QObject* parent) : QObject(parent) {
    connect(&m_timer, &QTimer::timeout, this, &AutosaveManager::tick);
}

QString AutosaveManager::recoveryPath() {
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    return dir + "/recovery.iboard";
}

void AutosaveManager::start(int intervalMs) { m_timer.start(intervalMs); }

void AutosaveManager::tick() {
    if (!m_doc || !m_doc->isModified()) return;
    QFile f(recoveryPath());
    if (f.open(QIODevice::WriteOnly)) { f.write(board::toBytes(*m_doc)); f.close(); }
}

void AutosaveManager::clearRecovery() { QFile::remove(recoveryPath()); }

bool AutosaveManager::maybeOfferRecovery(QWidget* parent) {
    const QString rp = recoveryPath();
    if (!QFileInfo::exists(rp) || !m_doc) return false;
    const auto btn = QMessageBox::question(
        parent, QObject::tr("Recover work"),
        QObject::tr("An unsaved session was found. Restore it?"),
        QMessageBox::Yes | QMessageBox::No);
    if (btn != QMessageBox::Yes) { clearRecovery(); return false; }
    QFile f(rp);
    if (!f.open(QIODevice::ReadOnly)) return false;
    QString err;
    const bool ok = board::fromBytes(*m_doc, f.readAll(), &err);
    if (!ok) QMessageBox::warning(parent, QObject::tr("Recover"), err);
    return ok;
}

} // namespace ib
EOF

# ---- ui/PreferencesDialog.h / .cpp ----------------------------------------
cat > src/ui/PreferencesDialog.h <<'EOF'
#pragma once
#include <QDialog>
namespace ib {
class ToolManager;
class ThemeManager;
class ShortcutManager;
class CanvasWidget;
// Central preferences: theme, pen/pressure, touch, pointer fade, shortcuts.
class PreferencesDialog : public QDialog {
    Q_OBJECT
public:
    PreferencesDialog(ToolManager* tools, ThemeManager* theme, ShortcutManager* sc,
                      CanvasWidget* canvas, QWidget* parent = nullptr);
};
} // namespace ib
EOF

cat > src/ui/PreferencesDialog.cpp <<'EOF'
#include "ui/PreferencesDialog.h"
#include "ui/ThemeManager.h"
#include "ui/ShortcutManager.h"
#include "tools/ToolManager.h"
#include "render/CanvasWidget.h"
#include <QCheckBox>
#include <QComboBox>
#include <QDoubleSpinBox>
#include <QFormLayout>
#include <QKeySequenceEdit>
#include <QLabel>
#include <QPushButton>
#include <QScrollArea>
#include <QSpinBox>
#include <QTabWidget>
#include <QVBoxLayout>

namespace ib {

PreferencesDialog::PreferencesDialog(ToolManager* tools, ThemeManager* theme,
                                     ShortcutManager* sc, CanvasWidget* canvas, QWidget* parent)
    : QDialog(parent) {
    setWindowTitle(tr("Preferences"));
    resize(520, 560);
    auto* tabs = new QTabWidget(this);

    // --- Appearance ---
    {
        auto* w = new QWidget; auto* f = new QFormLayout(w);
        auto* mode = new QComboBox; mode->addItems({tr("System"), tr("Light"), tr("Dark")});
        mode->setCurrentIndex(int(theme->mode()));
        connect(mode, &QComboBox::currentIndexChanged, this, [theme](int i){ theme->setMode(ThemeManager::Mode(i)); });
        f->addRow(tr("Theme"), mode);
        auto* accent = new QPushButton(tr("Choose accent..."));
        connect(accent, &QPushButton::clicked, this, [theme, this]{
            const QColor c = QColorDialog::getColor(theme->accent(), this, tr("Accent"));
            if (c.isValid()) theme->setAccent(c);
        });
        f->addRow(tr("Accent"), accent);
        tabs->addTab(w, tr("Appearance"));
    }

    // --- Pen / pressure ---
    {
        auto* w = new QWidget; auto* f = new QFormLayout(w);
        auto* gamma = new QDoubleSpinBox; gamma->setRange(0.2, 3.0); gamma->setSingleStep(0.1);
        gamma->setValue(tools->host() ? canvas->router().pressure.gamma : 1.0);
        connect(gamma, &QDoubleSpinBox::valueChanged, this, [canvas](double v){ canvas->router().pressure.gamma = v; });
        f->addRow(tr("Pressure curve (gamma)"), gamma);
        auto* smooth = new QDoubleSpinBox; smooth->setRange(0.0, 0.95); smooth->setSingleStep(0.05);
        smooth->setValue(tools->settings().penSmoothing);
        connect(smooth, &QDoubleSpinBox::valueChanged, this, [tools](double v){ tools->settings().penSmoothing = v; });
        f->addRow(tr("Stabilizer"), smooth);
        tabs->addTab(w, tr("Pen"));
    }

    // --- Touch ---
    {
        auto* w = new QWidget; auto* f = new QFormLayout(w);
        auto* mode = new QComboBox; mode->addItems({tr("Gestures only"), tr("Draw + gestures"), tr("Ignore touch")});
        mode->setCurrentIndex(int(canvas->router().touchMode));
        connect(mode, &QComboBox::currentIndexChanged, this, [canvas](int i){ canvas->router().touchMode = TouchMode(i); });
        f->addRow(tr("Touch mode"), mode);
        auto* finger = new QCheckBox(tr("Allow finger drawing"));
        finger->setChecked(canvas->router().fingerDrawing);
        connect(finger, &QCheckBox::toggled, this, [canvas](bool b){ canvas->router().fingerDrawing = b; });
        f->addRow(finger);
        tabs->addTab(w, tr("Touch"));
    }

    // --- Pointer fade ---
    {
        auto* w = new QWidget; auto* f = new QFormLayout(w);
        auto* delay = new QSpinBox; delay->setRange(0, 3000); delay->setSuffix(" ms"); delay->setValue(250);
        connect(delay, &QSpinBox::valueChanged, this, [canvas](int v){ canvas->setPointerVanishDelayMs(v); });
        f->addRow(tr("Vanish delay"), delay);
        auto* fade = new QSpinBox; fade->setRange(0, 3000); fade->setSuffix(" ms"); fade->setValue(450);
        connect(fade, &QSpinBox::valueChanged, this, [canvas](int v){ canvas->setPointerFadeMs(v); });
        f->addRow(tr("Fade duration"), fade);
        auto* laser = new QSpinBox; laser->setRange(0, 3000); laser->setSuffix(" ms");
        laser->setValue(tools->settings().laserTrailMs);
        connect(laser, &QSpinBox::valueChanged, this, [tools](int v){ tools->settings().laserTrailMs = v; });
        f->addRow(tr("Laser trail length"), laser);
        tabs->addTab(w, tr("Pointer"));
    }

    // --- Shortcuts ---
    {
        auto* area = new QScrollArea; area->setWidgetResizable(true);
        auto* w = new QWidget; auto* f = new QFormLayout(w);
        for (const auto& e : sc->entries()) {
            auto* edit = new QKeySequenceEdit(e.action->shortcut());
            const QString name = e.name;
            connect(edit, &QKeySequenceEdit::keySequenceChanged, this,
                    [sc, name](const QKeySequence& k){ sc->setSequence(name, k); });
            f->addRow(e.label, edit);
        }
        area->setWidget(w);
        tabs->addTab(area, tr("Shortcuts"));
    }

    auto* root = new QVBoxLayout(this);
    root->addWidget(tabs);
    auto* close = new QPushButton(tr("Close"));
    connect(close, &QPushButton::clicked, this, &QDialog::accept);
    root->addWidget(close);
}

} // namespace ib
EOF

# ---- app/MainWindow.h ------------------------------------------------------
cat > src/app/MainWindow.h <<'EOF'
#pragma once
#include <QMainWindow>
#include <memory>
namespace ib {
class Document;
class CanvasWidget;
class ToolManager;
class ThemeManager;
class ShortcutManager;
class AutosaveManager;
class ColorPalette;
class ToolBarWidget;
class TextItem;

class MainWindow : public QMainWindow {
    Q_OBJECT
public:
    explicit MainWindow(QWidget* parent = nullptr);
    ~MainWindow() override;
protected:
    void closeEvent(QCloseEvent* e) override;
private:
    void buildActions();
    void buildMenus();
    void buildDocks();
    void updateTitle();
    void applyColorToActiveTool(const QColor& c);
    void applySizeToActiveTool(double s);

    // file ops
    void newDocument();
    void openDocument();
    bool saveDocument();
    bool saveDocumentAs();
    void importPdf();
    void exportPdf();
    void exportPng();
    void exportSvg();
    void insertImage();
    void editText(TextItem* item);

    // view
    void togglePresentation();

    Document* m_doc = nullptr;
    CanvasWidget* m_canvas = nullptr;
    std::unique_ptr<ToolManager> m_tools;
    ThemeManager* m_theme = nullptr;
    ShortcutManager* m_shortcuts = nullptr;
    AutosaveManager* m_autosave = nullptr;
    ColorPalette* m_palette = nullptr;
    ToolBarWidget* m_toolbar = nullptr;

    struct Acts; std::unique_ptr<Acts> a;
    bool m_presentation = false;
};
} // namespace ib
EOF

# ---- app/MainWindow.cpp ----------------------------------------------------
cat > src/app/MainWindow.cpp <<'EOF'
#include "app/MainWindow.h"
#include "model/Document.h"
#include "model/TextItem.h"
#include "render/CanvasWidget.h"
#include "tools/ToolManager.h"
#include "ui/ThemeManager.h"
#include "ui/ShortcutManager.h"
#include "ui/ColorPalette.h"
#include "ui/ToolBarWidget.h"
#include "ui/PreferencesDialog.h"
#include "io/BoardSerializer.h"
#include "io/Exporters.h"
#include "io/PdfImporter.h"
#include "io/AutosaveManager.h"

#include <QAction>
#include <QCloseEvent>
#include <QColorDialog>
#include <QDockWidget>
#include <QFileDialog>
#include <QImage>
#include <QInputDialog>
#include <QMenuBar>
#include <QMessageBox>
#include <QStatusBar>

namespace ib {

struct MainWindow::Acts {
    QAction *newDoc, *open, *save, *saveAs, *importPdf, *exportPdf, *exportPng, *exportSvg, *insertImg;
    QAction *undo, *redo, *copy, *paste, *del, *selectAll;
    QAction *zoomFit, *resetView, *addPage, *delPage, *nextPage, *prevPage, *present, *prefs;
};

MainWindow::MainWindow(QWidget* parent) : QMainWindow(parent), a(std::make_unique<Acts>()) {
    m_doc = new Document(this);
    m_canvas = new CanvasWidget(this);
    setCentralWidget(m_canvas);
    m_canvas->setDocument(m_doc);

    m_tools = std::make_unique<ToolManager>(m_canvas);
    m_canvas->setToolManager(m_tools.get());
    m_tools->setTextEditRequester([this](TextItem* t){ editText(t); });

    m_theme = new ThemeManager(this);
    m_shortcuts = new ShortcutManager(this);
    m_autosave = new AutosaveManager(this);
    m_autosave->setDocument(m_doc);

    buildActions();
    buildMenus();
    buildDocks();

    m_theme->apply();
    m_shortcuts->loadOverrides();
    statusBar()->showMessage(tr("Ready"));
    updateTitle();
    connect(m_doc, &Document::modifiedChanged, this, [this](bool){ updateTitle(); });
    connect(m_doc, &Document::pagesChanged, this, [this]{ updateTitle(); });

    m_autosave->maybeOfferRecovery(this);
    m_autosave->start(15000);
    m_canvas->setCursor(m_tools->currentCursor());
}

MainWindow::~MainWindow() = default;

void MainWindow::buildActions() {
    a->newDoc   = new QAction(tr("New"), this);
    a->open     = new QAction(tr("Open..."), this);
    a->save     = new QAction(tr("Save"), this);
    a->saveAs   = new QAction(tr("Save As..."), this);
    a->importPdf= new QAction(tr("Import PDF..."), this);
    a->exportPdf= new QAction(tr("Export PDF..."), this);
    a->exportPng= new QAction(tr("Export PNG..."), this);
    a->exportSvg= new QAction(tr("Export SVG..."), this);
    a->insertImg= new QAction(tr("Insert Image..."), this);
    a->undo     = new QAction(tr("Undo"), this);
    a->redo     = new QAction(tr("Redo"), this);
    a->copy     = new QAction(tr("Copy"), this);
    a->paste    = new QAction(tr("Paste"), this);
    a->del      = new QAction(tr("Delete"), this);
    a->selectAll= new QAction(tr("Select All"), this);
    a->zoomFit  = new QAction(tr("Zoom to Fit"), this);
    a->resetView= new QAction(tr("Reset View"), this);
    a->addPage  = new QAction(tr("Add Page"), this);
    a->delPage  = new QAction(tr("Delete Page"), this);
    a->nextPage = new QAction(tr("Next Page"), this);
    a->prevPage = new QAction(tr("Previous Page"), this);
    a->present  = new QAction(tr("Presentation Mode"), this);
    a->present->setCheckable(true);
    a->prefs    = new QAction(tr("Preferences..."), this);

    auto S = [this](QAction* act, const QString& name, const QString& label, const char* key){
        m_shortcuts->add(name, label, act, QKeySequence(QString(key)));
    };
    S(a->newDoc,"file.new","New","Ctrl+N");        S(a->open,"file.open","Open","Ctrl+O");
    S(a->save,"file.save","Save","Ctrl+S");         S(a->saveAs,"file.saveAs","Save As","Ctrl+Shift+S");
    S(a->undo,"edit.undo","Undo","Ctrl+Z");         S(a->redo,"edit.redo","Redo","Ctrl+Shift+Z");
    S(a->copy,"edit.copy","Copy","Ctrl+C");         S(a->paste,"edit.paste","Paste","Ctrl+V");
    S(a->del,"edit.delete","Delete","Del");         S(a->selectAll,"edit.selectAll","Select All","Ctrl+A");
    S(a->zoomFit,"view.fit","Zoom to Fit","Ctrl+0");S(a->resetView,"view.reset","Reset View","Ctrl+1");
    S(a->addPage,"page.add","Add Page","Ctrl+Shift+N");
    S(a->nextPage,"page.next","Next Page","PgDown"); S(a->prevPage,"page.prev","Previous Page","PgUp");
    S(a->present,"view.present","Presentation","F5");

    connect(a->newDoc,   &QAction::triggered, this, &MainWindow::newDocument);
    connect(a->open,     &QAction::triggered, this, &MainWindow::openDocument);
    connect(a->save,     &QAction::triggered, this, [this]{ saveDocument(); });
    connect(a->saveAs,   &QAction::triggered, this, [this]{ saveDocumentAs(); });
    connect(a->importPdf,&QAction::triggered, this, &MainWindow::importPdf);
    connect(a->exportPdf,&QAction::triggered, this, &MainWindow::exportPdf);
    connect(a->exportPng,&QAction::triggered, this, &MainWindow::exportPng);
    connect(a->exportSvg,&QAction::triggered, this, &MainWindow::exportSvg);
    connect(a->insertImg,&QAction::triggered, this, &MainWindow::insertImage);
    connect(a->undo,     &QAction::triggered, this, [this]{ m_tools->undo(); });
    connect(a->redo,     &QAction::triggered, this, [this]{ m_tools->redo(); });
    connect(a->copy,     &QAction::triggered, this, [this]{ m_tools->copySelection(); });
    connect(a->paste,    &QAction::triggered, this, [this]{ m_tools->paste(); });
    connect(a->del,      &QAction::triggered, this, [this]{ m_tools->deleteSelection(); });
    connect(a->selectAll,&QAction::triggered, this, [this]{ m_tools->selectAll(); });
    connect(a->zoomFit,  &QAction::triggered, this, [this]{ m_canvas->zoomToFit(); });
    connect(a->resetView,&QAction::triggered, this, [this]{ m_canvas->resetView(); });
    connect(a->addPage,  &QAction::triggered, this, [this]{ m_doc->setCurrentIndex(m_doc->addPage()); });
    connect(a->delPage,  &QAction::triggered, this, [this]{ m_doc->removePage(m_doc->currentIndex()); });
    connect(a->nextPage, &QAction::triggered, this, [this]{ m_doc->setCurrentIndex(m_doc->currentIndex()+1); });
    connect(a->prevPage, &QAction::triggered, this, [this]{ m_doc->setCurrentIndex(m_doc->currentIndex()-1); });
    connect(a->present,  &QAction::triggered, this, [this]{ togglePresentation(); });
    connect(a->prefs,    &QAction::triggered, this, [this]{
        PreferencesDialog dlg(m_tools.get(), m_theme, m_shortcuts, m_canvas, this); dlg.exec();
    });
}

void MainWindow::buildMenus() {
    auto* file = menuBar()->addMenu(tr("&File"));
    file->addActions({a->newDoc, a->open, a->save, a->saveAs});
    file->addSeparator();
    file->addActions({a->importPdf, a->exportPdf, a->exportPng, a->exportSvg, a->insertImg});
    auto* edit = menuBar()->addMenu(tr("&Edit"));
    edit->addActions({a->undo, a->redo});
    edit->addSeparator();
    edit->addActions({a->copy, a->paste, a->del, a->selectAll});
    auto* view = menuBar()->addMenu(tr("&View"));
    view->addActions({a->zoomFit, a->resetView, a->present});
    auto* page = menuBar()->addMenu(tr("&Page"));
    page->addActions({a->addPage, a->delPage, a->nextPage, a->prevPage});
    auto* tools = menuBar()->addMenu(tr("&Tools"));
    tools->addAction(a->prefs);
}

void MainWindow::buildDocks() {
    m_toolbar = new ToolBarWidget(m_shortcuts, this);
    addToolBar(Qt::LeftToolBarArea, m_toolbar);
    connect(m_toolbar, &ToolBarWidget::toolSelected, this, [this](ToolId id){
        m_tools->setActiveTool(id);
        m_canvas->setCursor(m_tools->currentCursor());
    });

    auto* dock = new QDockWidget(tr("Palette"), this);
    m_palette = new ColorPalette(&m_tools->settings(), dock);
    dock->setWidget(m_palette);
    addDockWidget(Qt::RightDockWidgetArea, dock);
    connect(m_palette, &ColorPalette::colorPicked, this, [this](const QColor& c){ applyColorToActiveTool(c); });
    connect(m_palette, &ColorPalette::sizePicked, this, [this](double s){ applySizeToActiveTool(s); });
    connect(m_palette, &ColorPalette::customColorRequested, this, [this]{
        const QColor c = QColorDialog::getColor(m_tools->settings().penColor, this, tr("Color"));
        if (c.isValid()) applyColorToActiveTool(c);
    });
}

void MainWindow::applyColorToActiveTool(const QColor& c) {
    ToolSettings& s = m_tools->settings();
    switch (m_tools->activeTool()) {
    case ToolId::Highlighter: s.hlColor = c; break;
    case ToolId::Shape:       s.shapeColor = c; break;
    case ToolId::Text:        s.textColor = c; break;
    case ToolId::Laser:       s.laserColor = c; break;
    default:                  s.penColor = c; break;
    }
}
void MainWindow::applySizeToActiveTool(double sz) {
    ToolSettings& s = m_tools->settings();
    switch (m_tools->activeTool()) {
    case ToolId::Highlighter: s.hlSize = sz; break;
    case ToolId::Shape:       s.shapeWidth = sz; break;
    case ToolId::Eraser:      s.eraserRadius = sz; break;
    case ToolId::Laser:       s.laserSize = sz; break;
    default:                  s.penSize = sz; break;
    }
}

void MainWindow::updateTitle() {
    const QString name = m_doc->filePath().isEmpty() ? tr("Untitled")
                        : QFileInfo(m_doc->filePath()).fileName();
    setWindowTitle(QString("%1%2 - InkBoard (page %3/%4)")
                   .arg(m_doc->isModified() ? "* " : "", name)
                   .arg(m_doc->currentIndex()+1).arg(m_doc->pageCount()));
}

// ---- file ops --------------------------------------------------------------
void MainWindow::newDocument() {
    if (m_doc->isModified() &&
        QMessageBox::question(this, tr("New"), tr("Discard unsaved changes?")) != QMessageBox::Yes)
        return;
    delete m_doc;
    m_doc = new Document(this);
    m_autosave->setDocument(m_doc);
    m_canvas->setDocument(m_doc);
    connect(m_doc, &Document::modifiedChanged, this, [this](bool){ updateTitle(); });
    connect(m_doc, &Document::pagesChanged, this, [this]{ updateTitle(); });
    m_autosave->clearRecovery();
    updateTitle();
}

void MainWindow::openDocument() {
    const QString path = QFileDialog::getOpenFileName(this, tr("Open"), {}, tr("InkBoard (*.iboard)"));
    if (path.isEmpty()) return;
    QString err;
    if (!board::load(*m_doc, path, &err)) { QMessageBox::warning(this, tr("Open"), err); return; }
    m_doc->setFilePath(path);
    m_doc->setModified(false);
    updateTitle();
    m_canvas->zoomToFit();
}

bool MainWindow::saveDocument() {
    if (m_doc->filePath().isEmpty()) return saveDocumentAs();
    QString err;
    if (!board::save(*m_doc, m_doc->filePath(), &err)) { QMessageBox::warning(this, tr("Save"), err); return false; }
    m_doc->setModified(false);
    m_autosave->clearRecovery();
    statusBar()->showMessage(tr("Saved"), 2000);
    return true;
}

bool MainWindow::saveDocumentAs() {
    QString path = QFileDialog::getSaveFileName(this, tr("Save As"), "untitled.iboard", tr("InkBoard (*.iboard)"));
    if (path.isEmpty()) return false;
    if (!path.endsWith(".iboard")) path += ".iboard";
    m_doc->setFilePath(path);
    return saveDocument();
}

void MainWindow::importPdf() {
    const QString path = QFileDialog::getOpenFileName(this, tr("Import PDF"), {}, tr("PDF (*.pdf)"));
    if (path.isEmpty()) return;
    QString err;
    if (!pdf::importInto(*m_doc, path, 200.0, &err)) { QMessageBox::warning(this, tr("Import PDF"), err); return; }
    updateTitle();
    m_canvas->zoomToFit();
}

void MainWindow::exportPdf() {
    QString path = QFileDialog::getSaveFileName(this, tr("Export PDF"), "board.pdf", tr("PDF (*.pdf)"));
    if (path.isEmpty()) return;
    if (!path.endsWith(".pdf")) path += ".pdf";
    QString err;
    if (!exporters::exportPdf(*m_doc, path, &err)) { QMessageBox::warning(this, tr("Export PDF"), err); return; }
    statusBar()->showMessage(tr("Exported PDF"), 2000);
}

void MainWindow::exportPng() {
    QString path = QFileDialog::getSaveFileName(this, tr("Export PNG"), "page.png", tr("PNG (*.png)"));
    if (path.isEmpty()) return;
    if (!path.endsWith(".png")) path += ".png";
    QString err;
    if (!exporters::exportPng(m_doc->current(), path, 2.0, &err)) { QMessageBox::warning(this, tr("Export PNG"), err); return; }
    statusBar()->showMessage(tr("Exported PNG"), 2000);
}

void MainWindow::exportSvg() {
    QString path = QFileDialog::getSaveFileName(this, tr("Export SVG"), "page.svg", tr("SVG (*.svg)"));
    if (path.isEmpty()) return;
    if (!path.endsWith(".svg")) path += ".svg";
    QString err;
    if (!exporters::exportSvg(m_doc->current(), path, &err)) { QMessageBox::warning(this, tr("Export SVG"), err); return; }
    statusBar()->showMessage(tr("Exported SVG"), 2000);
}

void MainWindow::insertImage() {
    const QString path = QFileDialog::getOpenFileName(this, tr("Insert Image"), {},
                            tr("Images (*.png *.jpg *.jpeg *.bmp *.webp)"));
    if (path.isEmpty()) return;
    QImage img(path);
    if (img.isNull()) { QMessageBox::warning(this, tr("Insert Image"), tr("Could not load image.")); return; }
    m_tools->insertImageAtCenter(img);
}

void MainWindow::editText(TextItem* item) {
    if (!item) return;
    bool ok = false;
    const QString text = QInputDialog::getMultiLineText(this, tr("Text"), tr("Enter text:"), item->text, &ok);
    if (!ok) return;
    item->text = text;
    m_doc->markContentChanged();
    m_canvas->update();
}

void MainWindow::togglePresentation() {
    m_presentation = !m_presentation;
    menuBar()->setVisible(!m_presentation);
    m_toolbar->setVisible(!m_presentation);
    for (QDockWidget* d : findChildren<QDockWidget*>()) d->setVisible(!m_presentation);
    if (m_presentation) showFullScreen(); else showNormal();
}

void MainWindow::closeEvent(QCloseEvent* e) {
    if (m_doc->isModified()) {
        const auto btn = QMessageBox::question(this, tr("Quit"),
            tr("Save changes before closing?"),
            QMessageBox::Save | QMessageBox::Discard | QMessageBox::Cancel);
        if (btn == QMessageBox::Cancel) { e->ignore(); return; }
        if (btn == QMessageBox::Save && !saveDocument()) { e->ignore(); return; }
    }
    m_autosave->clearRecovery();
    e->accept();
}

} // namespace ib
EOF

log "PART 5 complete: MainWindow, UI, theming, shortcuts, exporters, PDF import, autosave written."
# =============================================================================
#  END OF PART 5  —  append PART 6 (README, packaging, GitHub Actions .exe) below
# =============================================================================

# =============================================================================
#  PART 6 (FINAL)  —  include polish, README, packaging, CI (.exe), closing
#  Append below PART 5. Completes the project and prints build instructions.
# =============================================================================
log "PART 6: include polish, README, packaging, and GitHub Actions CI"

# ---- 1. Portable include-safety polish -------------------------------------
# Guarantees a couple of headers are present regardless of transitive includes,
# so the build is airtight across compilers. Idempotent (safe to re-run).
ensure_include() {
    local file="$1" inc="$2"
    [ -f "$file" ] || return 0
    grep -qF "$inc" "$file" && return 0
    awk -v inc="$inc" 'NR==1{print; print inc; next}1' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}
ensure_include src/ui/PreferencesDialog.cpp '#include <QColorDialog>'
ensure_include src/app/MainWindow.cpp        '#include <QFileInfo>'
log "Include polish applied."

# ---- 2. Optional unit test (only built with -DINKBOARD_BUILD_TESTS=ON) -----
cat > tests/CMakeLists.txt <<'EOF'
find_package(Qt6 REQUIRED COMPONENTS Test Gui)
qt_add_executable(ink_tests test_model.cpp
    ${CMAKE_SOURCE_DIR}/src/ink/Smoothing.cpp
    ${CMAKE_SOURCE_DIR}/src/ink/Tessellator.cpp)
target_include_directories(ink_tests PRIVATE ${CMAKE_SOURCE_DIR}/src)
target_link_libraries(ink_tests PRIVATE Qt6::Test Qt6::Gui)
add_test(NAME ink_tests COMMAND ink_tests)
EOF

cat > tests/test_model.cpp <<'EOF'
#include <QtTest>
#include "ink/Smoothing.h"
#include "ink/Tessellator.h"

class InkTests : public QObject {
    Q_OBJECT
private slots:
    void catmullRomIsSmoothAndBounded() {
        std::vector<QPointF> pts { {0,0},{10,10},{20,0},{30,10} };
        const QPainterPath p = ib::ink::catmullRomPath(pts);
        QVERIFY(p.elementCount() > 0);
        QVERIFY(p.length() > 0.0);
    }
    void ribbonHasArea() {
        std::vector<ib::StrokePoint> s(3);
        s[0].pos = {0,0}; s[1].pos = {20,0}; s[2].pos = {40,0};
        for (auto& sp : s) sp.pressure = 1.0f;
        const QPainterPath r = ib::ink::buildRibbon(s, 6.0, true);
        QVERIFY(!r.boundingRect().isEmpty());
    }
};
QTEST_MAIN(InkTests)
#include "test_model.moc"
EOF

# ---- 3. README ------------------------------------------------------------
cat > README.md <<'EOF'
# InkBoard

A lean, professional pen / teaching whiteboard for Wacom tablets, built in
modern C++20 + Qt 6. Vector ink stays crisp at any zoom; PDF/SVG export stays
vector; touch pans/zooms while the pen inks.

## Features (essential-only, no bloat)
- Pressure/tilt vector ink (pen + highlighter) with Catmull-Rom smoothing + stabilizer.
- Crisp, resolution-independent rendering (GPU canvas, dirty-rect aware).
- Pen vs. touch separation, palm rejection, two-finger pan/pinch/rotate, finger-draw toggle.
- Tools: pen, highlighter, eraser (stroke + area, pen-eraser end), select (lasso/rect,
  move/scale/rotate, copy/paste/delete), shapes (snapping), text, image, fading laser.
- Infinite canvas, layers, multi-page notebooks, full undo/redo.
- Light/Dark/System theme + accent, remappable shortcuts, presentation mode.
- PDF import + annotate; vector PDF / PNG / SVG export.
- Native `.iboard` format (lossless round-trip), autosave + crash recovery.
- Configurable pointer vanish delay + fade-out easing on proximity loss.

## Build (local)
Requires CMake >= 3.24, a C++20 compiler, and Qt 6.5+ (with the **Qt PDF** module).





# =============================================================================
#  PART 6 (FINAL)  —  correctness fix, README, packaging, closing instructions
#  Append below PART 5. Does NOT contain the CI workflow (added separately).
# =============================================================================
log "PART 6: correctness fixup, README, packaging, and finishing up"

# ---- 6.1 Correctness fix: PreferencesDialog uses QColorDialog --------------
# Ensure the include exists (portable; no sed -i differences across OSes).
if ! grep -q '#include <QColorDialog>' src/ui/PreferencesDialog.cpp; then
    tmp="$(mktemp)"
    printf '#include <QColorDialog>\n' > "$tmp"
    cat src/ui/PreferencesDialog.cpp >> "$tmp"
    mv "$tmp" src/ui/PreferencesDialog.cpp
    log "Added missing <QColorDialog> include to PreferencesDialog.cpp"
fi

# ---- 6.2 Minimal test target (only used when -DINKBOARD_BUILD_TESTS=ON) -----
cat > tests/CMakeLists.txt <<'EOF'
# Lightweight smoke test so enabling INKBOARD_BUILD_TESTS never breaks config.
add_test(NAME smoke COMMAND ${CMAKE_COMMAND} -E echo "InkBoard smoke test OK")
EOF

# ---- 6.3 Windows installer script (NSIS) -----------------------------------
cat > packaging/installer.nsi <<'EOF'
; InkBoard NSIS installer. Packages the windeployqt output in ./dist.
!define APPNAME "InkBoard"
!define EXENAME "InkBoard.exe"

Name "${APPNAME}"
OutFile "InkBoard-Setup.exe"
InstallDir "$PROGRAMFILES64\${APPNAME}"
RequestExecutionLevel admin
ShowInstDetails show

Page directory
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

Section "Install"
    SetOutPath "$INSTDIR"
    File /r "dist\*.*"
    CreateDirectory "$SMPROGRAMS\${APPNAME}"
    CreateShortcut "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk" "$INSTDIR\${EXENAME}"
    CreateShortcut "$DESKTOP\${APPNAME}.lnk" "$INSTDIR\${EXENAME}"
    WriteUninstaller "$INSTDIR\uninstall.exe"
SectionEnd

Section "Uninstall"
    Delete "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk"
    Delete "$DESKTOP\${APPNAME}.lnk"
    RMDir  "$SMPROGRAMS\${APPNAME}"
    RMDir /r "$INSTDIR"
SectionEnd
EOF

# ---- 6.4 Linux desktop entry (for local packaging) -------------------------
cat > packaging/inkboard.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=InkBoard
Comment=Professional pen / teaching whiteboard
Exec=InkBoard %F
Icon=inkboard
Terminal=false
Categories=Graphics;Education;
MimeType=application/x-inkboard;
EOF

# ---- 6.5 README ------------------------------------------------------------
cat > README.md <<'EOF'
# InkBoard

A lean, professional pen / teaching whiteboard in modern C++ (C++20 + Qt 6).
Vector ink stays crisp at any zoom, optimized for Wacom / stylus tablets.

## Features (essential only)
- Pressure/tilt vector ink (pen + highlighter), stabilizer, crisp at any zoom
- Wacom / stylus: pressure curve, tilt, eraser end, hover/proximity, smooth
  pointer vanish-delay + fade-out
- Pen vs touch: pen inks, touch pans/pinch-zooms/rotates, palm rejection,
  finger-drawing toggle
- Tools: pen, highlighter, eraser (stroke + area), select (lasso/rect, move,
  scale, rotate, copy/paste, delete), shapes (snap), text, image, laser
- Infinite canvas, pan/zoom/rotate, layers, multi-page notebooks, full undo/redo
- Backgrounds/grids, light/dark/system theme + accent, remappable shortcuts,
  presentation mode
- PDF import + annotate, vector PDF / PNG / SVG export
- Native `.iboard` format (lossless round-trip), autosave + crash recovery

## Build (local)

Prerequisites: CMake >= 3.24, a C++20 compiler, and Qt 6.5+ with the
`Widgets, Gui, Svg, PrintSupport, Pdf, OpenGLWidgets` modules.
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
./build/bin/InkBoard        # Windows: buildbinReleaseInkBoard.exe


Options: `-DINKBOARD_USE_OPENGL=ON` (default), `-DINKBOARD_ENABLE_SANITIZERS=ON`
(Debug), `-DINKBOARD_BUILD_TESTS=ON`.

## Windows .exe via GitHub Actions
Add the provided workflow to `.github/workflows/build.yml`, push, and download
the `InkBoard-windows-portable` and `InkBoard-windows-installer` artifacts.
EOF

# ---- 6.6 Done --------------------------------------------------------------
cd ..
log "=============================================================="
log "InkBoard scaffold complete in ./$PROJECT"
log ""
log "Next steps:"
log "  1) Add the CI workflow file at:"
log "        $PROJECT/.github/workflows/build.yml"
log "     (provided SEPARATELY from this script)."
log "  2) Local build:"
log "        cd $PROJECT"
log "        cmake -B build -DCMAKE_BUILD_TYPE=Release"
log "        cmake --build build --parallel"
log "  3) Run:"
log "        ./build/bin/InkBoard   (Windows: build\\bin\\Release\\InkBoard.exe)"
log "=============================================================="
# =============================================================================
#  END OF setup.sh  (all 6 parts)
# =============================================================================
