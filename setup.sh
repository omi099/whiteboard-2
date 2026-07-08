#!/usr/bin/env bash
# =============================================================================
#  InkBoard — pen / teaching whiteboard (Qt6)          setup.sh  (REVAMP)
#  PART 1 of 6 : fresh scaffold, CMake, entry point, core data-model headers
#
#  Usage:   bash setup.sh          # generates ./pen-whiteboard
#  Then configure/build with CMake + Qt6 (see the build.yml delivered in Part 6)
# =============================================================================
set -euo pipefail

PROJECT="pen-whiteboard"
log() { printf '\033[1;36m[setup]\033[0m %s\n' "$*"; }

log "PART 1: fresh scaffold + CMake + core model headers"

# Start from a clean slate so no stale files from earlier attempts survive.
rm -rf "$PROJECT"
mkdir -p "$PROJECT"/src/model
mkdir -p "$PROJECT"/src/core
mkdir -p "$PROJECT"/src/canvas
mkdir -p "$PROJECT"/src/ui
mkdir -p "$PROJECT"/packaging
cd "$PROJECT"

# ---------------------------------------------------------------------------
#  CMakeLists.txt
# ---------------------------------------------------------------------------
cat > CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.21)
project(InkBoard VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Put the executable in a predictable place (multi-config -> bin/<Config>/).
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets Svg PrintSupport)

qt_standard_project_setup()

set(INKBOARD_SOURCES
    src/main.cpp
    src/model/Item.cpp
    src/model/StrokeItem.cpp
    src/model/ShapeItem.cpp
    src/model/TextItem.cpp
    src/model/ImageItem.cpp
    src/model/Document.cpp
    src/core/Serializer.cpp
    src/core/Commands.cpp
    src/core/Exporter.cpp
    src/canvas/Canvas.cpp
    src/ui/MainWindow.cpp
    src/ui/PreferencesDialog.cpp
)

set(INKBOARD_HEADERS
    src/model/Types.h
    src/model/Item.h
    src/model/StrokeItem.h
    src/model/ShapeItem.h
    src/model/TextItem.h
    src/model/ImageItem.h
    src/model/Layer.h
    src/model/Page.h
    src/model/Document.h
    src/core/Serializer.h
    src/core/Commands.h
    src/core/Exporter.h
    src/core/Settings.h
    src/canvas/Tools.h
    src/canvas/Canvas.h
    src/ui/MainWindow.h
    src/ui/PreferencesDialog.h
)

qt_add_executable(InkBoard WIN32 MACOSX_BUNDLE
    ${INKBOARD_SOURCES}
    ${INKBOARD_HEADERS}
)

target_include_directories(InkBoard PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)

target_compile_definitions(InkBoard PRIVATE
    INKBOARD_VERSION="${PROJECT_VERSION}"
)

target_link_libraries(InkBoard PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    Qt6::Svg
    Qt6::PrintSupport
)

if(MSVC)
    target_compile_options(InkBoard PRIVATE /W4 /permissive-)
else()
    target_compile_options(InkBoard PRIVATE -Wall -Wextra)
endif()

install(TARGETS InkBoard RUNTIME DESTINATION bin BUNDLE DESTINATION .)
EOF

# ---------------------------------------------------------------------------
#  src/main.cpp
# ---------------------------------------------------------------------------
cat > src/main.cpp <<'EOF'
#include <QApplication>
#include "ui/MainWindow.h"

int main(int argc, char **argv)
{
    QApplication app(argc, argv);
    QCoreApplication::setOrganizationName("InkBoard");
    QCoreApplication::setApplicationName("InkBoard");
#ifdef INKBOARD_VERSION
    QCoreApplication::setApplicationVersion(INKBOARD_VERSION);
#endif
    QApplication::setAttribute(Qt::AA_UseHighDpiPixmaps, true);

    ib::MainWindow window;
    window.show();
    return app.exec();
}
EOF

# ---------------------------------------------------------------------------
#  src/model/Types.h  — shared enums and the fundamental stroke sample
# ---------------------------------------------------------------------------
cat > src/model/Types.h <<'EOF'
#pragma once

#include <QColor>
#include <QPointF>

namespace ib {

// Active editing tool.
enum class ToolId {
    Pen,
    Highlighter,
    Eraser,
    Select,
    Line,
    Rectangle,
    Ellipse,
    Text
};

// Concrete item kinds stored on a layer.
enum class ItemType {
    Stroke,
    Shape,
    Text,
    Image
};

// Vector shape variants.
enum class ShapeKind {
    Line,
    Rectangle,
    Ellipse
};

// Page background style.
enum class BackgroundKind {
    Blank,
    Grid,
    Lines,
    Dots
};

// A single sample along an ink stroke, with normalized pressure (0..1).
struct StrokePoint {
    double x = 0.0;
    double y = 0.0;
    double pressure = 1.0;

    StrokePoint() = default;
    StrokePoint(double px, double py, double pr = 1.0) : x(px), y(py), pressure(pr) {}

    QPointF pos() const { return QPointF(x, y); }
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/model/Item.h  — abstract base for everything drawn on a layer
# ---------------------------------------------------------------------------
cat > src/model/Item.h <<'EOF'
#pragma once

#include <QRectF>
#include <QJsonObject>
#include <memory>

#include "model/Types.h"

class QPainter;

namespace ib {

// Abstract drawable. Concrete items: StrokeItem, ShapeItem, TextItem, ImageItem.
class Item {
public:
    virtual ~Item() = default;

    virtual ItemType type() const = 0;
    virtual QRectF boundingRect() const = 0;
    virtual void paint(QPainter &p) const = 0;
    virtual std::unique_ptr<Item> clone() const = 0;
    virtual void translate(const QPointF &delta) = 0;

    // Native (.iboard) JSON serialization.
    virtual void write(QJsonObject &obj) const = 0;
    virtual void read(const QJsonObject &obj) = 0;

    bool selected = false;
};

using ItemPtr = std::unique_ptr<Item>;

// Construct an empty item of the requested type (used by the serializer).
ItemPtr makeItem(ItemType type);

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/model/StrokeItem.h  — freehand ink (pen / highlighter)
# ---------------------------------------------------------------------------
cat > src/model/StrokeItem.h <<'EOF'
#pragma once

#include <QColor>
#include <QVector>

#include "model/Item.h"

namespace ib {

class StrokeItem : public Item {
public:
    QVector<StrokePoint> points;
    QColor  color        = QColor(24, 24, 24);
    double  baseWidth    = 3.0;
    double  opacity      = 1.0;
    bool    highlighter  = false;
    bool    pressureWidth = true;

    ItemType type() const override { return ItemType::Stroke; }
    QRectF boundingRect() const override;
    void paint(QPainter &p) const override;
    std::unique_ptr<Item> clone() const override;
    void translate(const QPointF &delta) override;
    void write(QJsonObject &obj) const override;
    void read(const QJsonObject &obj) override;

    void addPoint(const StrokePoint &pt) { points.push_back(pt); }
    bool isEmpty() const { return points.isEmpty(); }
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/model/ShapeItem.h  — line / rectangle / ellipse
# ---------------------------------------------------------------------------
cat > src/model/ShapeItem.h <<'EOF'
#pragma once

#include <QColor>
#include <QPointF>

#include "model/Item.h"

namespace ib {

class ShapeItem : public Item {
public:
    ShapeKind kind   = ShapeKind::Rectangle;
    QPointF   p1;
    QPointF   p2;
    QColor    color  = QColor(24, 24, 24);
    double    width  = 3.0;
    bool      filled = false;
    QColor    fill   = QColor(0, 0, 0, 0);

    ItemType type() const override { return ItemType::Shape; }
    QRectF boundingRect() const override;
    void paint(QPainter &p) const override;
    std::unique_ptr<Item> clone() const override;
    void translate(const QPointF &delta) override;
    void write(QJsonObject &obj) const override;
    void read(const QJsonObject &obj) override;
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/model/TextItem.h  — a positioned text label
# ---------------------------------------------------------------------------
cat > src/model/TextItem.h <<'EOF'
#pragma once

#include <QColor>
#include <QFont>
#include <QPointF>
#include <QString>

#include "model/Item.h"

namespace ib {

class TextItem : public Item {
public:
    QPointF pos;
    QString text;
    QColor  color = QColor(24, 24, 24);
    QFont   font  = QFont(QStringLiteral("Sans Serif"), 18);

    ItemType type() const override { return ItemType::Text; }
    QRectF boundingRect() const override;
    void paint(QPainter &p) const override;
    std::unique_ptr<Item> clone() const override;
    void translate(const QPointF &delta) override;
    void write(QJsonObject &obj) const override;
    void read(const QJsonObject &obj) override;
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/model/ImageItem.h  — an embedded raster image
# ---------------------------------------------------------------------------
cat > src/model/ImageItem.h <<'EOF'
#pragma once

#include <QImage>
#include <QRectF>

#include "model/Item.h"

namespace ib {

class ImageItem : public Item {
public:
    QImage image;
    QRectF rect;

    ItemType type() const override { return ItemType::Image; }
    QRectF boundingRect() const override;
    void paint(QPainter &p) const override;
    std::unique_ptr<Item> clone() const override;
    void translate(const QPointF &delta) override;
    void write(QJsonObject &obj) const override;
    void read(const QJsonObject &obj) override;
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/model/Layer.h  — an ordered, copyable stack of items
# ---------------------------------------------------------------------------
cat > src/model/Layer.h <<'EOF'
#pragma once

#include <QString>
#include <vector>

#include "model/Item.h"

namespace ib {

// A layer owns its items. It is deep-copyable so pages/documents can be cloned.
struct Layer {
    QString name    = QStringLiteral("Layer 1");
    bool    visible = true;
    bool    locked  = false;
    double  opacity = 1.0;
    std::vector<ItemPtr> items;

    Layer() = default;
    Layer(Layer &&) noexcept = default;
    Layer &operator=(Layer &&) noexcept = default;

    Layer(const Layer &other) { copyFrom(other); }
    Layer &operator=(const Layer &other) {
        if (this != &other) copyFrom(other);
        return *this;
    }

    void copyFrom(const Layer &other) {
        name    = other.name;
        visible = other.visible;
        locked  = other.locked;
        opacity = other.opacity;
        items.clear();
        items.reserve(other.items.size());
        for (const auto &it : other.items)
            items.push_back(it->clone());
    }
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/model/Page.h  — background settings + layers
# ---------------------------------------------------------------------------
cat > src/model/Page.h <<'EOF'
#pragma once

#include <QColor>
#include <QRectF>
#include <vector>

#include "model/Layer.h"
#include "model/Types.h"

namespace ib {

struct Page {
    BackgroundKind background   = BackgroundKind::Grid;
    QColor         bgColor      = QColor(255, 255, 255);
    QColor         gridColor    = QColor(223, 223, 223);
    double         gridSpacing  = 40.0;
    std::vector<Layer> layers;
    int            activeLayer  = 0;

    Page() { layers.emplace_back(); }

    Layer &active() {
        if (layers.empty()) layers.emplace_back();
        if (activeLayer < 0 || activeLayer >= static_cast<int>(layers.size()))
            activeLayer = 0;
        return layers[static_cast<std::size_t>(activeLayer)];
    }

    // Union of every visible item's bounding rect (empty if the page is blank).
    QRectF contentBounds() const {
        QRectF r;
        for (const auto &layer : layers) {
            if (!layer.visible) continue;
            for (const auto &it : layer.items)
                r = r.isNull() ? it->boundingRect() : r.united(it->boundingRect());
        }
        return r;
    }
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/model/Document.h  — the full multi-page document (owns the undo stack)
# ---------------------------------------------------------------------------
cat > src/model/Document.h <<'EOF'
#pragma once

#include <QObject>
#include <QString>
#include <vector>

#include "model/Page.h"

class QUndoStack;

namespace ib {

class Document : public QObject {
    Q_OBJECT
public:
    explicit Document(QObject *parent = nullptr);
    ~Document() override;

    int  pageCount() const { return static_cast<int>(m_pages.size()); }
    Page &page(int i)             { return m_pages[static_cast<std::size_t>(i)]; }
    const Page &page(int i) const { return m_pages[static_cast<std::size_t>(i)]; }
    Page &current()               { return m_pages[static_cast<std::size_t>(m_current)]; }

    int  currentIndex() const { return m_current; }
    void setCurrentIndex(int i);

    void addPage();
    void removePage(int i);

    // Replace all pages (used when loading a file). Takes ownership by move.
    void setPages(std::vector<Page> &&pages);

    QUndoStack *undoStack() const { return m_undo; }

    QString filePath() const { return m_filePath; }
    void setFilePath(const QString &p) { m_filePath = p; }

    bool modified() const { return m_modified; }
    void setModified(bool m);
    void markChanged() { setModified(true); emit contentChanged(); }

signals:
    void currentPageChanged(int index);
    void pagesChanged();
    void modifiedChanged(bool modified);
    void contentChanged();

private:
    std::vector<Page> m_pages;
    int         m_current = 0;
    QUndoStack *m_undo    = nullptr;
    QString     m_filePath;
    bool        m_modified = false;
};

} // namespace ib
EOF

log "PART 1 complete: scaffold, CMake, entry point, and core model headers written."
# ---------------------------------------------------------------------------
#  END OF PART 1  —  append PART 2 (model .cpp implementations) below
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
#  PART 2 of 6 : model .cpp implementations
#  Append below PART 1. Creates the source files declared by the Part 1 headers.
# ---------------------------------------------------------------------------
log "PART 2: writing model implementations (items + document)"

# ---------------------------------------------------------------------------
#  src/model/Item.cpp  — factory used by the serializer
# ---------------------------------------------------------------------------
cat > src/model/Item.cpp <<'EOF'
#include "model/Item.h"

#include "model/StrokeItem.h"
#include "model/ShapeItem.h"
#include "model/TextItem.h"
#include "model/ImageItem.h"

namespace ib {

ItemPtr makeItem(ItemType type)
{
    switch (type) {
    case ItemType::Stroke: return std::make_unique<StrokeItem>();
    case ItemType::Shape:  return std::make_unique<ShapeItem>();
    case ItemType::Text:   return std::make_unique<TextItem>();
    case ItemType::Image:  return std::make_unique<ImageItem>();
    }
    return nullptr;
}

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/model/StrokeItem.cpp
# ---------------------------------------------------------------------------
cat > src/model/StrokeItem.cpp <<'EOF'
#include "model/StrokeItem.h"

#include <QPainter>
#include <QPainterPath>
#include <QJsonArray>
#include <algorithm>

namespace ib {

static QJsonArray colorToJson(const QColor &c)
{
    QJsonArray a;
    a.append(c.red());
    a.append(c.green());
    a.append(c.blue());
    a.append(c.alpha());
    return a;
}

static QColor colorFromJson(const QJsonValue &v, const QColor &def)
{
    const QJsonArray a = v.toArray();
    if (a.size() < 3)
        return def;
    const int alpha = a.size() >= 4 ? a.at(3).toInt(255) : 255;
    return QColor(a.at(0).toInt(), a.at(1).toInt(), a.at(2).toInt(), alpha);
}

QRectF StrokeItem::boundingRect() const
{
    if (points.isEmpty())
        return QRectF();

    double minX = points.first().x, maxX = minX;
    double minY = points.first().y, maxY = minY;
    for (const auto &pt : points) {
        minX = std::min(minX, pt.x);
        maxX = std::max(maxX, pt.x);
        minY = std::min(minY, pt.y);
        maxY = std::max(maxY, pt.y);
    }
    const double m = baseWidth * 0.5 + 1.0;
    return QRectF(QPointF(minX, minY), QPointF(maxX, maxY)).adjusted(-m, -m, m, m);
}

void StrokeItem::paint(QPainter &p) const
{
    if (points.isEmpty())
        return;

    p.save();

    QColor c = color;
    c.setAlphaF(c.alphaF() * qBound(0.0, opacity, 1.0));

    if (points.size() == 1) {
        const double pr = pressureWidth ? qMax(0.15, points.first().pressure) : 1.0;
        const double w  = qMax(0.3, baseWidth * pr);
        p.setPen(Qt::NoPen);
        p.setBrush(c);
        p.drawEllipse(points.first().pos(), w * 0.5, w * 0.5);
        p.restore();
        return;
    }

    QPen pen(c);
    pen.setCapStyle(Qt::RoundCap);
    pen.setJoinStyle(Qt::RoundJoin);

    if (pressureWidth) {
        for (int i = 1; i < points.size(); ++i) {
            const double pr = 0.5 * (points[i - 1].pressure + points[i].pressure);
            pen.setWidthF(qMax(0.3, baseWidth * pr));
            p.setPen(pen);
            p.drawLine(points[i - 1].pos(), points[i].pos());
        }
    } else {
        pen.setWidthF(baseWidth);
        p.setPen(pen);
        QPainterPath path(points.first().pos());
        for (int i = 1; i < points.size(); ++i)
            path.lineTo(points[i].pos());
        p.drawPath(path);
    }

    p.restore();
}

std::unique_ptr<Item> StrokeItem::clone() const
{
    return std::make_unique<StrokeItem>(*this);
}

void StrokeItem::translate(const QPointF &delta)
{
    for (auto &pt : points) {
        pt.x += delta.x();
        pt.y += delta.y();
    }
}

void StrokeItem::write(QJsonObject &obj) const
{
    obj["type"]          = "stroke";
    obj["color"]         = colorToJson(color);
    obj["baseWidth"]     = baseWidth;
    obj["opacity"]       = opacity;
    obj["highlighter"]   = highlighter;
    obj["pressureWidth"] = pressureWidth;

    QJsonArray pts;
    for (const auto &pt : points) {
        QJsonArray a;
        a.append(pt.x);
        a.append(pt.y);
        a.append(pt.pressure);
        pts.append(a);
    }
    obj["points"] = pts;
}

void StrokeItem::read(const QJsonObject &obj)
{
    color         = colorFromJson(obj.value("color"), QColor(24, 24, 24));
    baseWidth     = obj.value("baseWidth").toDouble(3.0);
    opacity       = obj.value("opacity").toDouble(1.0);
    highlighter   = obj.value("highlighter").toBool(false);
    pressureWidth = obj.value("pressureWidth").toBool(true);

    points.clear();
    const QJsonArray pts = obj.value("points").toArray();
    for (const auto &v : pts) {
        const QJsonArray a = v.toArray();
        if (a.size() >= 2) {
            const double pr = a.size() >= 3 ? a.at(2).toDouble(1.0) : 1.0;
            points.push_back(StrokePoint(a.at(0).toDouble(), a.at(1).toDouble(), pr));
        }
    }
}

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/model/ShapeItem.cpp
# ---------------------------------------------------------------------------
cat > src/model/ShapeItem.cpp <<'EOF'
#include "model/ShapeItem.h"

#include <QPainter>
#include <QJsonArray>

namespace ib {

static QJsonArray colorToJson(const QColor &c)
{
    QJsonArray a;
    a.append(c.red());
    a.append(c.green());
    a.append(c.blue());
    a.append(c.alpha());
    return a;
}

static QColor colorFromJson(const QJsonValue &v, const QColor &def)
{
    const QJsonArray a = v.toArray();
    if (a.size() < 3)
        return def;
    const int alpha = a.size() >= 4 ? a.at(3).toInt(255) : 255;
    return QColor(a.at(0).toInt(), a.at(1).toInt(), a.at(2).toInt(), alpha);
}

QRectF ShapeItem::boundingRect() const
{
    QRectF r = QRectF(p1, p2).normalized();
    const double m = width * 0.5 + 1.0;
    return r.adjusted(-m, -m, m, m);
}

void ShapeItem::paint(QPainter &p) const
{
    p.save();

    QPen pen(color);
    pen.setWidthF(width);
    pen.setCapStyle(Qt::RoundCap);
    pen.setJoinStyle(Qt::RoundJoin);
    p.setPen(pen);

    if (filled && kind != ShapeKind::Line)
        p.setBrush(fill);
    else
        p.setBrush(Qt::NoBrush);

    const QRectF r = QRectF(p1, p2).normalized();
    switch (kind) {
    case ShapeKind::Line:      p.drawLine(p1, p2); break;
    case ShapeKind::Rectangle: p.drawRect(r);      break;
    case ShapeKind::Ellipse:   p.drawEllipse(r);   break;
    }

    p.restore();
}

std::unique_ptr<Item> ShapeItem::clone() const
{
    return std::make_unique<ShapeItem>(*this);
}

void ShapeItem::translate(const QPointF &delta)
{
    p1 += delta;
    p2 += delta;
}

void ShapeItem::write(QJsonObject &obj) const
{
    obj["type"]   = "shape";
    obj["kind"]   = static_cast<int>(kind);
    obj["x1"]     = p1.x();
    obj["y1"]     = p1.y();
    obj["x2"]     = p2.x();
    obj["y2"]     = p2.y();
    obj["color"]  = colorToJson(color);
    obj["width"]  = width;
    obj["filled"] = filled;
    obj["fill"]   = colorToJson(fill);
}

void ShapeItem::read(const QJsonObject &obj)
{
    kind   = static_cast<ShapeKind>(obj.value("kind").toInt(static_cast<int>(ShapeKind::Rectangle)));
    p1     = QPointF(obj.value("x1").toDouble(), obj.value("y1").toDouble());
    p2     = QPointF(obj.value("x2").toDouble(), obj.value("y2").toDouble());
    color  = colorFromJson(obj.value("color"), QColor(24, 24, 24));
    width  = obj.value("width").toDouble(3.0);
    filled = obj.value("filled").toBool(false);
    fill   = colorFromJson(obj.value("fill"), QColor(0, 0, 0, 0));
}

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/model/TextItem.cpp
# ---------------------------------------------------------------------------
cat > src/model/TextItem.cpp <<'EOF'
#include "model/TextItem.h"

#include <QPainter>
#include <QFontMetricsF>
#include <QJsonArray>
#include <QSizeF>

namespace ib {

static QJsonArray colorToJson(const QColor &c)
{
    QJsonArray a;
    a.append(c.red());
    a.append(c.green());
    a.append(c.blue());
    a.append(c.alpha());
    return a;
}

static QColor colorFromJson(const QJsonValue &v, const QColor &def)
{
    const QJsonArray a = v.toArray();
    if (a.size() < 3)
        return def;
    const int alpha = a.size() >= 4 ? a.at(3).toInt(255) : 255;
    return QColor(a.at(0).toInt(), a.at(1).toInt(), a.at(2).toInt(), alpha);
}

QRectF TextItem::boundingRect() const
{
    QFontMetricsF fm(font);
    QRectF r = fm.boundingRect(QRectF(0, 0, 100000, 100000),
                               Qt::AlignLeft | Qt::AlignTop | Qt::TextWordWrap,
                               text.isEmpty() ? QStringLiteral(" ") : text);
    r.moveTopLeft(pos);
    return r.adjusted(-2, -2, 2, 2);
}

void TextItem::paint(QPainter &p) const
{
    p.save();
    p.setPen(color);
    p.setFont(font);
    p.drawText(QRectF(pos, QSizeF(100000, 100000)),
               Qt::AlignLeft | Qt::AlignTop | Qt::TextWordWrap | Qt::TextDontClip,
               text);
    p.restore();
}

std::unique_ptr<Item> TextItem::clone() const
{
    return std::make_unique<TextItem>(*this);
}

void TextItem::translate(const QPointF &delta)
{
    pos += delta;
}

void TextItem::write(QJsonObject &obj) const
{
    obj["type"]  = "text";
    obj["x"]     = pos.x();
    obj["y"]     = pos.y();
    obj["text"]  = text;
    obj["color"] = colorToJson(color);
    obj["font"]  = font.toString();
}

void TextItem::read(const QJsonObject &obj)
{
    pos   = QPointF(obj.value("x").toDouble(), obj.value("y").toDouble());
    text  = obj.value("text").toString();
    color = colorFromJson(obj.value("color"), QColor(24, 24, 24));
    QFont f;
    if (f.fromString(obj.value("font").toString()))
        font = f;
}

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/model/ImageItem.cpp
# ---------------------------------------------------------------------------
cat > src/model/ImageItem.cpp <<'EOF'
#include "model/ImageItem.h"

#include <QPainter>
#include <QBuffer>
#include <QByteArray>

namespace ib {

QRectF ImageItem::boundingRect() const
{
    return rect.normalized();
}

void ImageItem::paint(QPainter &p) const
{
    if (!image.isNull())
        p.drawImage(rect, image);
}

std::unique_ptr<Item> ImageItem::clone() const
{
    return std::make_unique<ImageItem>(*this);
}

void ImageItem::translate(const QPointF &delta)
{
    rect.translate(delta);
}

void ImageItem::write(QJsonObject &obj) const
{
    obj["type"] = "image";
    obj["x"]    = rect.x();
    obj["y"]    = rect.y();
    obj["w"]    = rect.width();
    obj["h"]    = rect.height();

    QByteArray bytes;
    QBuffer buffer(&bytes);
    buffer.open(QIODevice::WriteOnly);
    if (!image.isNull())
        image.save(&buffer, "PNG");
    buffer.close();
    obj["data"] = QString::fromLatin1(bytes.toBase64());
}

void ImageItem::read(const QJsonObject &obj)
{
    rect = QRectF(obj.value("x").toDouble(),
                  obj.value("y").toDouble(),
                  obj.value("w").toDouble(),
                  obj.value("h").toDouble());
    const QByteArray bytes = QByteArray::fromBase64(obj.value("data").toString().toLatin1());
    image = QImage();
    if (!bytes.isEmpty())
        image.loadFromData(bytes, "PNG");
}

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/model/Document.cpp
# ---------------------------------------------------------------------------
cat > src/model/Document.cpp <<'EOF'
#include "model/Document.h"

#include <QUndoStack>

namespace ib {

Document::Document(QObject *parent)
    : QObject(parent)
{
    m_undo = new QUndoStack(this);
    m_pages.emplace_back();

    connect(m_undo, &QUndoStack::cleanChanged, this, [this](bool clean) {
        setModified(!clean);
    });
}

Document::~Document() = default;

void Document::setCurrentIndex(int i)
{
    if (i < 0 || i >= pageCount() || i == m_current)
        return;
    m_current = i;
    emit currentPageChanged(m_current);
}

void Document::addPage()
{
    m_pages.emplace_back();
    m_current = pageCount() - 1;
    markChanged();
    emit pagesChanged();
    emit currentPageChanged(m_current);
}

void Document::removePage(int i)
{
    if (pageCount() <= 1 || i < 0 || i >= pageCount())
        return;
    m_pages.erase(m_pages.begin() + i);
    if (m_current >= pageCount())
        m_current = pageCount() - 1;
    markChanged();
    emit pagesChanged();
    emit currentPageChanged(m_current);
}

void Document::setPages(std::vector<Page> &&pages)
{
    m_pages = std::move(pages);
    if (m_pages.empty())
        m_pages.emplace_back();
    m_current = 0;
    emit pagesChanged();
    emit currentPageChanged(m_current);
}

void Document::setModified(bool m)
{
    if (m_modified == m)
        return;
    m_modified = m;
    emit modifiedChanged(m_modified);
}

} // namespace ib
EOF

log "PART 2 complete: item implementations and document model written."
# ---------------------------------------------------------------------------
#  END OF PART 2  —  append PART 3 (serializer, undo commands, exporter, settings) below
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
#  PART 3 of 6 : .iboard serializer, QUndoCommand classes, exporter, settings
#  Append below PART 2. Creates new files only.
# ---------------------------------------------------------------------------
log "PART 3: writing serializer, undo commands, exporter, and settings"

# ---------------------------------------------------------------------------
#  src/core/Settings.h  — thin typed wrapper over QSettings
# ---------------------------------------------------------------------------
cat > src/core/Settings.h <<'EOF'
#pragma once

#include <QSettings>
#include <QVariant>
#include <QString>

namespace ib {

// Convenience typed access to persistent app settings (org/app set in main()).
class Settings {
public:
    template <typename T>
    static T get(const QString &key, const T &def)
    {
        QSettings s;
        return s.value(key, QVariant::fromValue(def)).template value<T>();
    }

    template <typename T>
    static void set(const QString &key, const T &value)
    {
        QSettings s;
        s.setValue(key, QVariant::fromValue(value));
    }
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/core/Serializer.h
# ---------------------------------------------------------------------------
cat > src/core/Serializer.h <<'EOF'
#pragma once

#include <QByteArray>
#include <QString>
#include <vector>

#include "model/Page.h"

namespace ib {

class Document;

namespace io {

// Native ".iboard" format (JSON). Returns false and sets *error on failure.
QByteArray toBytes(const Document &doc);
bool fromBytes(std::vector<Page> &pagesOut, const QByteArray &bytes, QString *error = nullptr);

bool saveToFile(const Document &doc, const QString &path, QString *error = nullptr);
bool loadFromFile(Document &doc, const QString &path, QString *error = nullptr);

} // namespace io
} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/core/Serializer.cpp
# ---------------------------------------------------------------------------
cat > src/core/Serializer.cpp <<'EOF'
#include "core/Serializer.h"

#include "model/Document.h"
#include "model/Item.h"

#include <QFile>
#include <QSaveFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonParseError>
#include <QColor>

namespace ib {
namespace io {

static QJsonArray colorToJson(const QColor &c)
{
    QJsonArray a;
    a.append(c.red());
    a.append(c.green());
    a.append(c.blue());
    a.append(c.alpha());
    return a;
}

static QColor colorFromJson(const QJsonValue &v, const QColor &def)
{
    const QJsonArray a = v.toArray();
    if (a.size() < 3)
        return def;
    const int alpha = a.size() >= 4 ? a.at(3).toInt(255) : 255;
    return QColor(a.at(0).toInt(), a.at(1).toInt(), a.at(2).toInt(), alpha);
}

static ItemType typeFromString(const QString &s)
{
    if (s == QLatin1String("stroke")) return ItemType::Stroke;
    if (s == QLatin1String("shape"))  return ItemType::Shape;
    if (s == QLatin1String("text"))   return ItemType::Text;
    return ItemType::Image;
}

static QJsonObject pageToJson(const Page &pg)
{
    QJsonObject o;
    o["background"]  = static_cast<int>(pg.background);
    o["bgColor"]     = colorToJson(pg.bgColor);
    o["gridColor"]   = colorToJson(pg.gridColor);
    o["gridSpacing"] = pg.gridSpacing;
    o["activeLayer"] = pg.activeLayer;

    QJsonArray layers;
    for (const auto &ly : pg.layers) {
        QJsonObject lo;
        lo["name"]    = ly.name;
        lo["visible"] = ly.visible;
        lo["locked"]  = ly.locked;
        lo["opacity"] = ly.opacity;

        QJsonArray items;
        for (const auto &it : ly.items) {
            QJsonObject io;
            it->write(io);
            items.append(io);
        }
        lo["items"] = items;
        layers.append(lo);
    }
    o["layers"] = layers;
    return o;
}

static Page pageFromJson(const QJsonObject &o)
{
    Page pg;
    pg.background   = static_cast<BackgroundKind>(
        o.value("background").toInt(static_cast<int>(BackgroundKind::Grid)));
    pg.bgColor      = colorFromJson(o.value("bgColor"), QColor(255, 255, 255));
    pg.gridColor    = colorFromJson(o.value("gridColor"), QColor(223, 223, 223));
    pg.gridSpacing  = o.value("gridSpacing").toDouble(40.0);

    pg.layers.clear();
    const QJsonArray layers = o.value("layers").toArray();
    for (const auto &lv : layers) {
        const QJsonObject lo = lv.toObject();
        Layer ly;
        ly.name    = lo.value("name").toString(QStringLiteral("Layer"));
        ly.visible = lo.value("visible").toBool(true);
        ly.locked  = lo.value("locked").toBool(false);
        ly.opacity = lo.value("opacity").toDouble(1.0);

        const QJsonArray items = lo.value("items").toArray();
        for (const auto &iv : items) {
            const QJsonObject io = iv.toObject();
            ItemPtr item = makeItem(typeFromString(io.value("type").toString()));
            if (item) {
                item->read(io);
                ly.items.push_back(std::move(item));
            }
        }
        pg.layers.push_back(std::move(ly));
    }
    if (pg.layers.empty())
        pg.layers.emplace_back();

    pg.activeLayer = o.value("activeLayer").toInt(0);
    return pg;
}

QByteArray toBytes(const Document &doc)
{
    QJsonObject root;
    root["format"]  = "inkboard";
    root["version"] = 1;

    QJsonArray pages;
    for (int i = 0; i < doc.pageCount(); ++i)
        pages.append(pageToJson(doc.page(i)));
    root["pages"] = pages;

    return QJsonDocument(root).toJson(QJsonDocument::Indented);
}

bool fromBytes(std::vector<Page> &pagesOut, const QByteArray &bytes, QString *error)
{
    QJsonParseError pe;
    const QJsonDocument doc = QJsonDocument::fromJson(bytes, &pe);
    if (pe.error != QJsonParseError::NoError) {
        if (error) *error = pe.errorString();
        return false;
    }
    const QJsonObject root = doc.object();
    if (root.value("format").toString() != QLatin1String("inkboard")) {
        if (error) *error = QStringLiteral("Not an InkBoard (.iboard) file.");
        return false;
    }

    pagesOut.clear();
    const QJsonArray pages = root.value("pages").toArray();
    for (const auto &pv : pages)
        pagesOut.push_back(pageFromJson(pv.toObject()));
    if (pagesOut.empty())
        pagesOut.emplace_back();
    return true;
}

bool saveToFile(const Document &doc, const QString &path, QString *error)
{
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly)) {
        if (error) *error = file.errorString();
        return false;
    }
    const QByteArray bytes = toBytes(doc);
    if (file.write(bytes) != bytes.size()) {
        if (error) *error = file.errorString();
        return false;
    }
    if (!file.commit()) {
        if (error) *error = file.errorString();
        return false;
    }
    return true;
}

bool loadFromFile(Document &doc, const QString &path, QString *error)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        if (error) *error = file.errorString();
        return false;
    }
    const QByteArray bytes = file.readAll();
    std::vector<Page> pages;
    if (!fromBytes(pages, bytes, error))
        return false;

    doc.setPages(std::move(pages));
    doc.setFilePath(path);
    return true;
}

} // namespace io
} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/core/Commands.h  — undoable operations (add / remove / translate)
# ---------------------------------------------------------------------------
cat > src/core/Commands.h <<'EOF'
#pragma once

#include <QUndoCommand>
#include <QPointF>
#include <QString>
#include <vector>

#include "model/Item.h"

namespace ib {

class Document;
struct Layer;

// Add a single item to a layer.
class AddItemCommand : public QUndoCommand {
public:
    AddItemCommand(Document *doc, int page, int layer, ItemPtr item,
                   const QString &text = QString());
    void undo() override;
    void redo() override;

private:
    Layer &layerRef();
    Document *m_doc;
    int       m_page;
    int       m_layer;
    ItemPtr   m_item;
    Item     *m_raw = nullptr;
};

// Remove a set of items (identified by raw pointer) from a layer.
class RemoveItemsCommand : public QUndoCommand {
public:
    RemoveItemsCommand(Document *doc, int page, int layer,
                       std::vector<Item *> targets, const QString &text = QString());
    void undo() override;
    void redo() override;

private:
    Layer &layerRef();
    struct Removed {
        std::size_t index;
        ItemPtr     item;
    };
    Document           *m_doc;
    int                 m_page;
    int                 m_layer;
    std::vector<Item *> m_targets;
    std::vector<Removed> m_removed;
};

// Translate a set of items by a fixed delta.
class TranslateItemsCommand : public QUndoCommand {
public:
    TranslateItemsCommand(Document *doc, int page, int layer,
                          std::vector<Item *> targets, QPointF delta,
                          const QString &text = QString());
    void undo() override;
    void redo() override;

private:
    Document           *m_doc;
    int                 m_page;
    int                 m_layer;
    std::vector<Item *> m_targets;
    QPointF             m_delta;
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/core/Commands.cpp
# ---------------------------------------------------------------------------
cat > src/core/Commands.cpp <<'EOF'
#include "core/Commands.h"

#include "model/Document.h"

#include <algorithm>

namespace ib {

// ---- AddItemCommand -------------------------------------------------------
AddItemCommand::AddItemCommand(Document *doc, int page, int layer, ItemPtr item,
                               const QString &text)
    : m_doc(doc), m_page(page), m_layer(layer), m_item(std::move(item))
{
    setText(text.isEmpty() ? QStringLiteral("Add") : text);
}

Layer &AddItemCommand::layerRef()
{
    Page &pg = m_doc->page(m_page);
    if (m_layer < 0 || m_layer >= static_cast<int>(pg.layers.size()))
        m_layer = 0;
    return pg.layers[static_cast<std::size_t>(m_layer)];
}

void AddItemCommand::redo()
{
    Layer &ly = layerRef();
    if (m_item) {
        m_raw = m_item.get();
        ly.items.push_back(std::move(m_item));
    }
    m_doc->markChanged();
}

void AddItemCommand::undo()
{
    Layer &ly = layerRef();
    for (auto it = ly.items.begin(); it != ly.items.end(); ++it) {
        if (it->get() == m_raw) {
            m_item = std::move(*it);
            ly.items.erase(it);
            break;
        }
    }
    m_doc->markChanged();
}

// ---- RemoveItemsCommand ---------------------------------------------------
RemoveItemsCommand::RemoveItemsCommand(Document *doc, int page, int layer,
                                       std::vector<Item *> targets, const QString &text)
    : m_doc(doc), m_page(page), m_layer(layer), m_targets(std::move(targets))
{
    setText(text.isEmpty() ? QStringLiteral("Delete") : text);
}

Layer &RemoveItemsCommand::layerRef()
{
    Page &pg = m_doc->page(m_page);
    if (m_layer < 0 || m_layer >= static_cast<int>(pg.layers.size()))
        m_layer = 0;
    return pg.layers[static_cast<std::size_t>(m_layer)];
}

void RemoveItemsCommand::redo()
{
    Layer &ly = layerRef();
    m_removed.clear();
    for (std::size_t i = 0; i < ly.items.size();) {
        Item *raw = ly.items[i].get();
        if (std::find(m_targets.begin(), m_targets.end(), raw) != m_targets.end()) {
            m_removed.push_back({i, std::move(ly.items[i])});
            ly.items.erase(ly.items.begin() + static_cast<std::ptrdiff_t>(i));
        } else {
            ++i;
        }
    }
    m_doc->markChanged();
}

void RemoveItemsCommand::undo()
{
    Layer &ly = layerRef();
    std::sort(m_removed.begin(), m_removed.end(),
              [](const Removed &a, const Removed &b) { return a.index < b.index; });
    for (auto &r : m_removed) {
        std::size_t idx = std::min(r.index, ly.items.size());
        ly.items.insert(ly.items.begin() + static_cast<std::ptrdiff_t>(idx),
                        std::move(r.item));
    }
    m_removed.clear();
    m_doc->markChanged();
}

// ---- TranslateItemsCommand ------------------------------------------------
TranslateItemsCommand::TranslateItemsCommand(Document *doc, int page, int layer,
                                             std::vector<Item *> targets, QPointF delta,
                                             const QString &text)
    : m_doc(doc), m_page(page), m_layer(layer),
      m_targets(std::move(targets)), m_delta(delta)
{
    setText(text.isEmpty() ? QStringLiteral("Move") : text);
}

void TranslateItemsCommand::redo()
{
    for (Item *it : m_targets)
        if (it) it->translate(m_delta);
    m_doc->markChanged();
}

void TranslateItemsCommand::undo()
{
    for (Item *it : m_targets)
        if (it) it->translate(-m_delta);
    m_doc->markChanged();
}

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/core/Exporter.h
# ---------------------------------------------------------------------------
cat > src/core/Exporter.h <<'EOF'
#pragma once

#include <QRectF>
#include <QString>

class QPainter;

namespace ib {

class Document;
struct Page;

namespace io {

// Render one page's content (mapping logical rect src -> device rect dst).
void renderPage(QPainter &p, const Page &page, const QRectF &src,
                const QRectF &dst, bool drawBackground);

bool exportPng(const Page &page, const QString &path, double scale,
               QString *error = nullptr);
bool exportSvg(const Page &page, const QString &path, QString *error = nullptr);
bool exportPdf(const Document &doc, const QString &path, QString *error = nullptr);

} // namespace io
} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/core/Exporter.cpp
# ---------------------------------------------------------------------------
cat > src/core/Exporter.cpp <<'EOF'
#include "core/Exporter.h"

#include "model/Document.h"
#include "model/Page.h"

#include <QPainter>
#include <QImage>
#include <QSize>
#include <QPen>
#include <QSvgGenerator>
#include <QPdfWriter>
#include <QPageSize>
#include <cmath>

namespace ib {
namespace io {

static void drawBackgroundPattern(QPainter &p, const Page &pg, const QRectF &area)
{
    if (pg.background == BackgroundKind::Blank)
        return;

    const double s = qMax(4.0, pg.gridSpacing);
    QPen pen(pg.gridColor);
    pen.setWidthF(0.0); // cosmetic: always 1px on device
    p.setPen(pen);

    const double startX = std::floor(area.left() / s) * s;
    const double startY = std::floor(area.top() / s) * s;

    if (pg.background == BackgroundKind::Grid) {
        for (double x = startX; x <= area.right(); x += s)
            p.drawLine(QPointF(x, area.top()), QPointF(x, area.bottom()));
        for (double y = startY; y <= area.bottom(); y += s)
            p.drawLine(QPointF(area.left(), y), QPointF(area.right(), y));
    } else if (pg.background == BackgroundKind::Lines) {
        for (double y = startY; y <= area.bottom(); y += s)
            p.drawLine(QPointF(area.left(), y), QPointF(area.right(), y));
    } else if (pg.background == BackgroundKind::Dots) {
        p.setPen(Qt::NoPen);
        p.setBrush(pg.gridColor);
        for (double x = startX; x <= area.right(); x += s)
            for (double y = startY; y <= area.bottom(); y += s)
                p.drawEllipse(QPointF(x, y), 1.3, 1.3);
    }
}

void renderPage(QPainter &p, const Page &pg, const QRectF &src,
                const QRectF &dst, bool drawBackground)
{
    p.save();
    p.setRenderHint(QPainter::Antialiasing, true);
    p.setRenderHint(QPainter::TextAntialiasing, true);
    p.setRenderHint(QPainter::SmoothPixmapTransform, true);

    p.setClipRect(dst);
    p.translate(dst.topLeft());
    const double sx = dst.width()  / (src.width()  <= 0 ? 1.0 : src.width());
    const double sy = dst.height() / (src.height() <= 0 ? 1.0 : src.height());
    p.scale(sx, sy);
    p.translate(-src.topLeft());

    if (drawBackground) {
        p.fillRect(src, pg.bgColor);
        drawBackgroundPattern(p, pg, src);
    }

    for (const auto &ly : pg.layers) {
        if (!ly.visible)
            continue;
        p.save();
        if (ly.opacity < 1.0)
            p.setOpacity(ly.opacity);
        for (const auto &it : ly.items)
            it->paint(p);
        p.restore();
    }

    p.restore();
}

bool exportPng(const Page &pg, const QString &path, double scale, QString *error)
{
    QRectF b = pg.contentBounds();
    if (b.isNull())
        b = QRectF(0, 0, 1280, 720);
    const double margin = 40.0;
    b.adjust(-margin, -margin, margin, margin);

    scale = qBound(0.1, scale, 8.0);
    const QSize sz(qMax(1, static_cast<int>(b.width() * scale)),
                   qMax(1, static_cast<int>(b.height() * scale)));

    QImage img(sz, QImage::Format_ARGB32_Premultiplied);
    img.fill(Qt::transparent);
    {
        QPainter p(&img);
        renderPage(p, pg, b, QRectF(0, 0, sz.width(), sz.height()), true);
    }
    if (!img.save(path, "PNG")) {
        if (error) *error = QStringLiteral("Failed to write PNG file.");
        return false;
    }
    return true;
}

bool exportSvg(const Page &pg, const QString &path, QString *error)
{
    QRectF b = pg.contentBounds();
    if (b.isNull())
        b = QRectF(0, 0, 1280, 720);
    const double margin = 40.0;
    b.adjust(-margin, -margin, margin, margin);

    QSvgGenerator gen;
    gen.setFileName(path);
    gen.setSize(QSize(static_cast<int>(b.width()), static_cast<int>(b.height())));
    gen.setViewBox(QRectF(0, 0, b.width(), b.height()));
    gen.setTitle(QStringLiteral("InkBoard Page"));
    gen.setDescription(QStringLiteral("Exported by InkBoard"));

    {
        QPainter p(&gen);
        if (!p.isActive()) {
            if (error) *error = QStringLiteral("Failed to create SVG file.");
            return false;
        }
        renderPage(p, pg, b, QRectF(0, 0, b.width(), b.height()), true);
    }
    return true;
}

bool exportPdf(const Document &doc, const QString &path, QString *error)
{
    QPdfWriter writer(path);
    writer.setResolution(150);
    writer.setPageSize(QPageSize(QPageSize::A4));

    QPainter p(&writer);
    if (!p.isActive()) {
        if (error) *error = QStringLiteral("Failed to create PDF file.");
        return false;
    }

    bool first = true;
    for (int i = 0; i < doc.pageCount(); ++i) {
        if (!first)
            writer.newPage();
        first = false;

        const Page &pg = doc.page(i);
        QRectF b = pg.contentBounds();
        if (b.isNull())
            b = QRectF(0, 0, 1280, 720);
        const double margin = 40.0;
        b.adjust(-margin, -margin, margin, margin);

        const QRectF dst(0, 0, writer.width(), writer.height());
        const double s = qMin(dst.width() / b.width(), dst.height() / b.height());
        QRectF fitted(0, 0, b.width() * s, b.height() * s);
        fitted.moveCenter(dst.center());

        renderPage(p, pg, b, fitted, true);
    }
    return true;
}

} // namespace io
} // namespace ib
EOF

log "PART 3 complete: serializer, undo commands, exporter, and settings written."
# ---------------------------------------------------------------------------
#  END OF PART 3  —  append PART 4 (canvas widget + tool settings) below
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
#  PART 4 of 6 : tool settings + the interactive pressure-aware Canvas widget
#  Append below PART 3. Creates new files only.
# ---------------------------------------------------------------------------
log "PART 4: writing tool settings and the interactive canvas widget"

# ---------------------------------------------------------------------------
#  src/canvas/Tools.h  — per-tool settings shared with the UI
# ---------------------------------------------------------------------------
cat > src/canvas/Tools.h <<'EOF'
#pragma once

#include <QColor>
#include <QFont>
#include <QList>

#include "model/Types.h"

namespace ib {

enum class EraserMode { Stroke, Area };

struct ToolSettings {
    ToolId tool = ToolId::Pen;

    // Pen
    QColor penColor    = QColor(24, 24, 24);
    double penWidth    = 3.0;
    bool   penPressure = true;

    // Highlighter
    QColor hlColor   = QColor(255, 214, 10);
    double hlWidth   = 18.0;
    double hlOpacity = 0.40;

    // Eraser
    EraserMode eraserMode   = EraserMode::Stroke;
    double     eraserRadius = 12.0;

    // Shape
    ShapeKind shapeKind   = ShapeKind::Rectangle;
    QColor    shapeColor  = QColor(24, 24, 24);
    double    shapeWidth  = 3.0;
    bool      shapeFilled = false;
    QColor    shapeFill   = QColor(120, 170, 255, 90);

    // Text
    QColor textColor = QColor(24, 24, 24);
    QFont  textFont  = QFont(QStringLiteral("Sans Serif"), 18);

    QList<QColor> palette;

    ToolSettings()
    {
        palette = {
            QColor(24, 24, 24),  QColor(230, 30, 30),  QColor(30, 110, 230),
            QColor(30, 160, 60), QColor(245, 170, 20), QColor(150, 40, 200),
            QColor(255, 255, 255)
        };
    }
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/canvas/Canvas.h
# ---------------------------------------------------------------------------
cat > src/canvas/Canvas.h <<'EOF'
#pragma once

#include <QWidget>
#include <QPointF>
#include <memory>
#include <vector>

#include "model/Document.h"
#include "model/StrokeItem.h"
#include "model/ShapeItem.h"
#include "canvas/Tools.h"

class QPaintEvent;
class QMouseEvent;
class QTabletEvent;
class QWheelEvent;
class QKeyEvent;

namespace ib {

class Canvas : public QWidget {
    Q_OBJECT
public:
    explicit Canvas(QWidget *parent = nullptr);

    void setDocument(Document *doc);
    Document *document() const { return m_doc; }

    ToolSettings &settings() { return m_settings; }
    const ToolSettings &settings() const { return m_settings; }

    void setTool(ToolId t);
    ToolId tool() const { return m_settings.tool; }

    bool hasSelection() const { return !m_selection.empty(); }
    double zoomPercent() const { return m_scale * 100.0; }

public slots:
    void zoomIn();
    void zoomOut();
    void resetView();
    void zoomToFit();
    void deleteSelection();
    void selectAll();
    void clearSelection();
    void refresh() { update(); }

signals:
    void viewChanged();
    void toolChanged(ib::ToolId tool);
    void cursorMoved(QPointF scenePos);

protected:
    void paintEvent(QPaintEvent *) override;
    void mousePressEvent(QMouseEvent *e) override;
    void mouseMoveEvent(QMouseEvent *e) override;
    void mouseReleaseEvent(QMouseEvent *e) override;
    void tabletEvent(QTabletEvent *e) override;
    void wheelEvent(QWheelEvent *e) override;
    void keyPressEvent(QKeyEvent *e) override;
    void keyReleaseEvent(QKeyEvent *e) override;

private:
    enum class Action { Press, Move, Release };

    struct EraseStash {
        std::size_t index;
        ItemPtr     item;
    };

    // Coordinate transforms.
    QPointF widgetToScene(const QPointF &p) const { return (p - m_translate) / m_scale; }
    QPointF sceneToWidget(const QPointF &s) const { return s * m_scale + m_translate; }

    void handlePointer(Action a, const QPointF &widgetPos, double pressure,
                       Qt::KeyboardModifiers mods, bool eraserTip);
    void handleSelect(Action a, const QPointF &sp, Qt::KeyboardModifiers mods);

    void commitAdd(ItemPtr item, const QString &text);
    void eraseAt(const QPointF &sp);
    void finishErase();
    void addTextAt(const QPointF &sp);
    void cancelActive();
    void zoomAround(const QPointF &widgetPos, double factor);
    void updateCursor();

    void drawBackground(QPainter &p, const Page &pg, const QRectF &area);
    void drawSelection(QPainter &p);

    bool hitTest(Item *it, const QPointF &sp, double radius) const;
    Item *topItemAt(const QPointF &sp);
    void selectInRect(const QRectF &r, bool add);
    void setSelectionSingle(Item *it);
    void addToSelection(Item *it);
    void removeFromSelection(Item *it);

    Document    *m_doc = nullptr;
    ToolSettings m_settings;

    double  m_scale = 1.0;
    QPointF m_translate;

    // panning
    bool   m_panning = false;
    bool   m_spaceDown = false;
    QPoint m_lastPanPos;

    // active building
    std::unique_ptr<StrokeItem> m_activeStroke;
    std::unique_ptr<ShapeItem>  m_activeShape;
    bool m_drawing = false;

    // eraser
    bool m_erasing = false;
    std::vector<EraseStash> m_eraseStash;

    // selection / move / rubber-band
    std::vector<Item *> m_selection;
    bool    m_movingSelection = false;
    QPointF m_moveStartScene;
    QPointF m_moveAccum;
    bool    m_rubber = false;
    QPointF m_rubberStartScene;
    QRectF  m_rubberRect;

    QPointF m_cursorWidget;
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/canvas/Canvas.cpp
# ---------------------------------------------------------------------------
cat > src/canvas/Canvas.cpp <<'EOF'
#include "canvas/Canvas.h"

#include "core/Commands.h"

#include <QPainter>
#include <QPen>
#include <QMouseEvent>
#include <QTabletEvent>
#include <QWheelEvent>
#include <QKeyEvent>
#include <QPointingDevice>
#include <QInputDialog>
#include <QUndoStack>
#include <QLineF>
#include <algorithm>
#include <cmath>

namespace ib {

static const double kPi = 3.14159265358979323846;

static double distToSegment(const QPointF &p, const QPointF &a, const QPointF &b)
{
    const QPointF ab = b - a;
    const double len2 = ab.x() * ab.x() + ab.y() * ab.y();
    if (len2 <= 1e-9)
        return std::hypot(p.x() - a.x(), p.y() - a.y());
    double t = ((p.x() - a.x()) * ab.x() + (p.y() - a.y()) * ab.y()) / len2;
    t = std::max(0.0, std::min(1.0, t));
    const QPointF proj(a.x() + t * ab.x(), a.y() + t * ab.y());
    return std::hypot(p.x() - proj.x(), p.y() - proj.y());
}

static QPointF constrainShape(const QPointF &a, const QPointF &b, ShapeKind kind)
{
    const QPointF d = b - a;
    if (kind == ShapeKind::Line) {
        double ang = std::atan2(d.y(), d.x());
        const double step = kPi / 4.0;
        ang = std::round(ang / step) * step;
        const double len = std::hypot(d.x(), d.y());
        return a + QPointF(std::cos(ang) * len, std::sin(ang) * len);
    }
    const double s = std::max(std::abs(d.x()), std::abs(d.y()));
    return a + QPointF(d.x() < 0 ? -s : s, d.y() < 0 ? -s : s);
}

Canvas::Canvas(QWidget *parent)
    : QWidget(parent)
{
    setFocusPolicy(Qt::StrongFocus);
    setMouseTracking(true);
    setAttribute(Qt::WA_TabletTracking, true);
    setAutoFillBackground(false);
    m_translate = QPointF(40, 40);
    updateCursor();
}

void Canvas::setDocument(Document *doc)
{
    if (m_doc == doc)
        return;
    if (m_doc) {
        m_doc->disconnect(this);
        if (m_doc->undoStack())
            m_doc->undoStack()->disconnect(this);
    }
    m_doc = doc;
    cancelActive();
    m_selection.clear();

    if (m_doc) {
        connect(m_doc, &Document::currentPageChanged, this, [this](int) {
            cancelActive(); m_selection.clear(); update();
        });
        connect(m_doc, &Document::pagesChanged, this, [this]() {
            cancelActive(); m_selection.clear(); update();
        });
        connect(m_doc, &Document::contentChanged, this, [this]() { update(); });
        if (m_doc->undoStack()) {
            connect(m_doc->undoStack(), &QUndoStack::indexChanged, this, [this](int) {
                m_selection.clear(); cancelActive(); update();
            });
        }
    }
    update();
}

void Canvas::setTool(ToolId t)
{
    cancelActive();
    m_settings.tool = t;
    updateCursor();
    emit toolChanged(t);
    update();
}

// ---- view ------------------------------------------------------------------
void Canvas::zoomAround(const QPointF &widgetPos, double factor)
{
    const QPointF before = widgetToScene(widgetPos);
    m_scale = qBound(0.05, m_scale * factor, 40.0);
    m_translate = widgetPos - before * m_scale;
    update();
    emit viewChanged();
}

void Canvas::zoomIn()  { zoomAround(QPointF(width() / 2.0, height() / 2.0), 1.2); }
void Canvas::zoomOut() { zoomAround(QPointF(width() / 2.0, height() / 2.0), 1.0 / 1.2); }

void Canvas::resetView()
{
    m_scale = 1.0;
    m_translate = QPointF(40, 40);
    update();
    emit viewChanged();
}

void Canvas::zoomToFit()
{
    if (!m_doc) { update(); return; }
    QRectF b = m_doc->current().contentBounds();
    if (b.isNull()) { resetView(); return; }
    b.adjust(-40, -40, 40, 40);
    const double sx = width()  / b.width();
    const double sy = height() / b.height();
    m_scale = qBound(0.05, qMin(sx, sy), 40.0);
    m_translate = QPointF(width() / 2.0, height() / 2.0) - b.center() * m_scale;
    update();
    emit viewChanged();
}

// ---- painting --------------------------------------------------------------
void Canvas::drawBackground(QPainter &p, const Page &pg, const QRectF &area)
{
    if (pg.background == BackgroundKind::Blank)
        return;
    const double s = qMax(4.0, pg.gridSpacing);
    QPen pen(pg.gridColor);
    pen.setCosmetic(true);
    pen.setWidth(1);
    p.setPen(pen);

    const double startX = std::floor(area.left() / s) * s;
    const double startY = std::floor(area.top() / s) * s;

    if (pg.background == BackgroundKind::Grid) {
        for (double x = startX; x <= area.right(); x += s)
            p.drawLine(QPointF(x, area.top()), QPointF(x, area.bottom()));
        for (double y = startY; y <= area.bottom(); y += s)
            p.drawLine(QPointF(area.left(), y), QPointF(area.right(), y));
    } else if (pg.background == BackgroundKind::Lines) {
        for (double y = startY; y <= area.bottom(); y += s)
            p.drawLine(QPointF(area.left(), y), QPointF(area.right(), y));
    } else {
        p.setPen(Qt::NoPen);
        p.setBrush(pg.gridColor);
        for (double x = startX; x <= area.right(); x += s)
            for (double y = startY; y <= area.bottom(); y += s)
                p.drawEllipse(QPointF(x, y), 1.3, 1.3);
    }
}

void Canvas::drawSelection(QPainter &p)
{
    if (m_selection.empty())
        return;
    QPen pen(QColor(60, 120, 220));
    pen.setCosmetic(true);
    pen.setStyle(Qt::DashLine);
    pen.setWidth(1);
    p.setPen(pen);
    p.setBrush(Qt::NoBrush);
    for (Item *it : m_selection)
        p.drawRect(it->boundingRect());
}

void Canvas::paintEvent(QPaintEvent *)
{
    QPainter p(this);
    p.fillRect(rect(), QColor(90, 93, 99));
    if (!m_doc)
        return;

    p.save();
    p.translate(m_translate);
    p.scale(m_scale, m_scale);

    const QRectF sceneRect =
        QRectF(widgetToScene(QPointF(0, 0)),
               widgetToScene(QPointF(width(), height()))).normalized();

    Page &pg = m_doc->current();
    p.fillRect(sceneRect, pg.bgColor);
    drawBackground(p, pg, sceneRect);

    p.setRenderHint(QPainter::Antialiasing, true);
    p.setRenderHint(QPainter::TextAntialiasing, true);

    for (const auto &ly : pg.layers) {
        if (!ly.visible)
            continue;
        p.save();
        if (ly.opacity < 1.0)
            p.setOpacity(ly.opacity);
        for (const auto &it : ly.items)
            it->paint(p);
        p.restore();
    }

    if (m_activeStroke) m_activeStroke->paint(p);
    if (m_activeShape)  m_activeShape->paint(p);

    drawSelection(p);

    if (m_rubber) {
        QPen pen(QColor(60, 120, 220));
        pen.setCosmetic(true);
        pen.setStyle(Qt::DashLine);
        p.setPen(pen);
        p.setBrush(QColor(60, 120, 220, 40));
        p.drawRect(m_rubberRect);
    }

    p.restore();

    if (m_settings.tool == ToolId::Eraser && underMouse()) {
        const double r = m_settings.eraserRadius * m_scale;
        QPen pen(QColor(70, 70, 70));
        pen.setStyle(Qt::DashLine);
        p.setPen(pen);
        p.setBrush(Qt::NoBrush);
        p.drawEllipse(m_cursorWidget, r, r);
    }
}

// ---- input -----------------------------------------------------------------
void Canvas::mousePressEvent(QMouseEvent *e)
{
    m_cursorWidget = e->position();
    if (e->button() == Qt::MiddleButton ||
        (m_spaceDown && e->button() == Qt::LeftButton)) {
        m_panning = true;
        m_lastPanPos = e->position().toPoint();
        setCursor(Qt::ClosedHandCursor);
        return;
    }
    if (e->button() == Qt::LeftButton)
        handlePointer(Action::Press, e->position(), 1.0, e->modifiers(), false);
}

void Canvas::mouseMoveEvent(QMouseEvent *e)
{
    m_cursorWidget = e->position();
    if (m_panning) {
        const QPoint d = e->position().toPoint() - m_lastPanPos;
        m_lastPanPos = e->position().toPoint();
        m_translate += QPointF(d);
        update();
        emit viewChanged();
        return;
    }
    handlePointer(Action::Move, e->position(), 1.0, e->modifiers(), false);
    if (m_settings.tool == ToolId::Eraser)
        update();
    emit cursorMoved(widgetToScene(e->position()));
}

void Canvas::mouseReleaseEvent(QMouseEvent *e)
{
    m_cursorWidget = e->position();
    if (m_panning &&
        (e->button() == Qt::MiddleButton || e->button() == Qt::LeftButton)) {
        m_panning = false;
        updateCursor();
        return;
    }
    if (e->button() == Qt::LeftButton)
        handlePointer(Action::Release, e->position(), 1.0, e->modifiers(), false);
}

void Canvas::tabletEvent(QTabletEvent *e)
{
    const bool eraserTip =
        e->pointerType() == QPointingDevice::PointerType::Eraser;
    double pr = e->pressure();
    if (pr <= 0.0)
        pr = 1.0;
    m_cursorWidget = e->position();

    switch (e->type()) {
    case QEvent::TabletPress:
        handlePointer(Action::Press, e->position(), pr, e->modifiers(), eraserTip);
        break;
    case QEvent::TabletMove:
        handlePointer(Action::Move, e->position(), pr, e->modifiers(), eraserTip);
        emit cursorMoved(widgetToScene(e->position()));
        if (m_settings.tool == ToolId::Eraser)
            update();
        break;
    case QEvent::TabletRelease:
        handlePointer(Action::Release, e->position(), pr, e->modifiers(), eraserTip);
        break;
    default:
        break;
    }
    e->accept();
}

void Canvas::wheelEvent(QWheelEvent *e)
{
    const double factor = std::pow(1.0015, e->angleDelta().y());
    zoomAround(e->position(), factor);
    e->accept();
}

void Canvas::keyPressEvent(QKeyEvent *e)
{
    if (e->key() == Qt::Key_Space) {
        m_spaceDown = true;
        setCursor(Qt::OpenHandCursor);
        e->accept();
        return;
    }
    if (e->key() == Qt::Key_Delete || e->key() == Qt::Key_Backspace) {
        deleteSelection();
        e->accept();
        return;
    }
    if (e->key() == Qt::Key_Escape) {
        cancelActive();
        clearSelection();
        update();
        e->accept();
        return;
    }
    QWidget::keyPressEvent(e);
}

void Canvas::keyReleaseEvent(QKeyEvent *e)
{
    if (e->key() == Qt::Key_Space) {
        m_spaceDown = false;
        updateCursor();
        e->accept();
        return;
    }
    QWidget::keyReleaseEvent(e);
}

// ---- pointer dispatch ------------------------------------------------------
void Canvas::handlePointer(Action a, const QPointF &widgetPos, double pressure,
                           Qt::KeyboardModifiers mods, bool eraserTip)
{
    if (!m_doc)
        return;
    const QPointF sp = widgetToScene(widgetPos);
    m_cursorWidget = widgetPos;

    const ToolId t = eraserTip ? ToolId::Eraser : m_settings.tool;
    Layer &ly = m_doc->current().active();
    if (ly.locked)
        return;

    switch (t) {
    case ToolId::Pen:
    case ToolId::Highlighter: {
        const bool hl = (t == ToolId::Highlighter);
        if (a == Action::Press) {
            m_drawing = true;
            m_activeStroke = std::make_unique<StrokeItem>();
            m_activeStroke->highlighter   = hl;
            m_activeStroke->color         = hl ? m_settings.hlColor : m_settings.penColor;
            m_activeStroke->baseWidth     = hl ? m_settings.hlWidth : m_settings.penWidth;
            m_activeStroke->opacity       = hl ? m_settings.hlOpacity : 1.0;
            m_activeStroke->pressureWidth = hl ? false : m_settings.penPressure;
            m_activeStroke->addPoint(StrokePoint(sp.x(), sp.y(), pressure));
            update();
        } else if (a == Action::Move && m_drawing && m_activeStroke) {
            m_activeStroke->addPoint(StrokePoint(sp.x(), sp.y(), pressure));
            update();
        } else if (a == Action::Release && m_drawing) {
            if (m_activeStroke && !m_activeStroke->isEmpty())
                commitAdd(std::move(m_activeStroke),
                          hl ? QStringLiteral("Highlight") : QStringLiteral("Draw"));
            m_activeStroke.reset();
            m_drawing = false;
            update();
        }
        break;
    }
    case ToolId::Eraser: {
        if (a == Action::Press) { m_erasing = true; m_eraseStash.clear(); eraseAt(sp); update(); }
        else if (a == Action::Move && m_erasing) { eraseAt(sp); update(); }
        else if (a == Action::Release && m_erasing) { finishErase(); m_erasing = false; update(); }
        break;
    }
    case ToolId::Line:
    case ToolId::Rectangle:
    case ToolId::Ellipse: {
        if (a == Action::Press) {
            m_activeShape = std::make_unique<ShapeItem>();
            m_activeShape->kind = (t == ToolId::Line) ? ShapeKind::Line
                                : (t == ToolId::Rectangle) ? ShapeKind::Rectangle
                                : ShapeKind::Ellipse;
            m_activeShape->color  = m_settings.shapeColor;
            m_activeShape->width  = m_settings.shapeWidth;
            m_activeShape->filled = m_settings.shapeFilled;
            m_activeShape->fill   = m_settings.shapeFill;
            m_activeShape->p1 = sp;
            m_activeShape->p2 = sp;
            m_drawing = true;
            update();
        } else if (a == Action::Move && m_drawing && m_activeShape) {
            m_activeShape->p2 = (mods & Qt::ShiftModifier)
                ? constrainShape(m_activeShape->p1, sp, m_activeShape->kind)
                : sp;
            update();
        } else if (a == Action::Release && m_drawing) {
            if (m_activeShape) {
                const QLineF diag(m_activeShape->p1, m_activeShape->p2);
                if (diag.length() >= 2.0)
                    commitAdd(std::move(m_activeShape), QStringLiteral("Shape"));
            }
            m_activeShape.reset();
            m_drawing = false;
            update();
        }
        break;
    }
    case ToolId::Text: {
        if (a == Action::Press)
            addTextAt(sp);
        break;
    }
    case ToolId::Select: {
        handleSelect(a, sp, mods);
        break;
    }
    }
}

// ---- selection -------------------------------------------------------------
void Canvas::handleSelect(Action a, const QPointF &sp, Qt::KeyboardModifiers mods)
{
    if (a == Action::Press) {
        Item *hit = topItemAt(sp);
        if (hit) {
            const bool already =
                std::find(m_selection.begin(), m_selection.end(), hit) != m_selection.end();
            if (mods & Qt::ShiftModifier) {
                if (already) removeFromSelection(hit);
                else addToSelection(hit);
            } else if (!already) {
                setSelectionSingle(hit);
            }
            m_movingSelection = true;
            m_moveStartScene = sp;
            m_moveAccum = QPointF(0, 0);
        } else {
            if (!(mods & Qt::ShiftModifier))
                clearSelection();
            m_rubber = true;
            m_rubberStartScene = sp;
            m_rubberRect = QRectF(sp, sp);
        }
        update();
    } else if (a == Action::Move) {
        if (m_movingSelection && !m_selection.empty()) {
            const QPointF d = sp - m_moveStartScene;
            const QPointF step = d - m_moveAccum;
            for (Item *it : m_selection)
                it->translate(step);
            m_moveAccum = d;
            update();
        } else if (m_rubber) {
            m_rubberRect = QRectF(m_rubberStartScene, sp).normalized();
            update();
        }
    } else { // Release
        if (m_movingSelection) {
            m_movingSelection = false;
            if (!m_selection.empty() &&
                (qAbs(m_moveAccum.x()) > 0.01 || qAbs(m_moveAccum.y()) > 0.01)) {
                for (Item *it : m_selection)
                    it->translate(-m_moveAccum);
                std::vector<Item *> targets(m_selection.begin(), m_selection.end());
                m_doc->undoStack()->push(new TranslateItemsCommand(
                    m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
                    targets, m_moveAccum, QStringLiteral("Move")));
            }
            m_moveAccum = QPointF(0, 0);
        } else if (m_rubber) {
            m_rubber = false;
            selectInRect(m_rubberRect, (mods & Qt::ShiftModifier));
        }
        update();
    }
}

void Canvas::setSelectionSingle(Item *it)
{
    m_selection.clear();
    if (it) m_selection.push_back(it);
}

void Canvas::addToSelection(Item *it)
{
    if (it && std::find(m_selection.begin(), m_selection.end(), it) == m_selection.end())
        m_selection.push_back(it);
}

void Canvas::removeFromSelection(Item *it)
{
    m_selection.erase(std::remove(m_selection.begin(), m_selection.end(), it),
                      m_selection.end());
}

void Canvas::clearSelection()
{
    if (m_selection.empty())
        return;
    m_selection.clear();
    update();
}

void Canvas::selectAll()
{
    if (!m_doc)
        return;
    m_selection.clear();
    for (auto &it : m_doc->current().active().items)
        m_selection.push_back(it.get());
    update();
}

void Canvas::selectInRect(const QRectF &r, bool add)
{
    if (!m_doc)
        return;
    if (!add)
        m_selection.clear();
    for (auto &it : m_doc->current().active().items) {
        if (r.intersects(it->boundingRect()) &&
            std::find(m_selection.begin(), m_selection.end(), it.get()) == m_selection.end())
            m_selection.push_back(it.get());
    }
}

Item *Canvas::topItemAt(const QPointF &sp)
{
    if (!m_doc)
        return nullptr;
    Layer &ly = m_doc->current().active();
    const double r = 6.0 / qMax(0.0001, m_scale);
    for (int i = static_cast<int>(ly.items.size()) - 1; i >= 0; --i) {
        Item *it = ly.items[static_cast<std::size_t>(i)].get();
        if (hitTest(it, sp, r))
            return it;
    }
    return nullptr;
}

bool Canvas::hitTest(Item *it, const QPointF &sp, double radius) const
{
    const QRectF bb = it->boundingRect().adjusted(-radius, -radius, radius, radius);
    if (!bb.contains(sp))
        return false;

    if (it->type() == ItemType::Stroke) {
        const StrokeItem *s = static_cast<const StrokeItem *>(it);
        const double tol = radius + s->baseWidth * 0.5;
        if (s->points.size() == 1)
            return QLineF(sp, s->points.first().pos()).length() <= tol;
        for (int i = 1; i < s->points.size(); ++i)
            if (distToSegment(sp, s->points[i - 1].pos(), s->points[i].pos()) <= tol)
                return true;
        return false;
    }
    return true;
}

// ---- helpers ---------------------------------------------------------------
void Canvas::commitAdd(ItemPtr item, const QString &text)
{
    if (!m_doc || !item)
        return;
    m_doc->undoStack()->push(new AddItemCommand(
        m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
        std::move(item), text));
}

void Canvas::eraseAt(const QPointF &sp)
{
    if (!m_doc)
        return;
    Layer &ly = m_doc->current().active();
    const double r = m_settings.eraserRadius;
    for (std::size_t i = 0; i < ly.items.size();) {
        if (hitTest(ly.items[i].get(), sp, r)) {
            m_eraseStash.push_back({i, std::move(ly.items[i])});
            ly.items.erase(ly.items.begin() + static_cast<std::ptrdiff_t>(i));
        } else {
            ++i;
        }
    }
}

void Canvas::finishErase()
{
    if (!m_doc || m_eraseStash.empty())
        return;
    Layer &ly = m_doc->current().active();
    std::sort(m_eraseStash.begin(), m_eraseStash.end(),
              [](const EraseStash &a, const EraseStash &b) { return a.index < b.index; });

    std::vector<Item *> targets;
    for (auto &s : m_eraseStash) {
        Item *raw = s.item.get();
        targets.push_back(raw);
        const std::size_t idx = std::min(s.index, ly.items.size());
        ly.items.insert(ly.items.begin() + static_cast<std::ptrdiff_t>(idx),
                        std::move(s.item));
    }
    m_eraseStash.clear();

    m_doc->undoStack()->push(new RemoveItemsCommand(
        m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
        std::move(targets), QStringLiteral("Erase")));
}

void Canvas::addTextAt(const QPointF &sp)
{
    bool ok = false;
    const QString text = QInputDialog::getMultiLineText(
        this, tr("Add Text"), tr("Text:"), QString(), &ok);
    if (!ok || text.trimmed().isEmpty())
        return;
    auto t = std::make_unique<TextItem>();
    t->pos   = sp;
    t->text  = text;
    t->color = m_settings.textColor;
    t->font  = m_settings.textFont;
    commitAdd(std::move(t), QStringLiteral("Text"));
}

void Canvas::deleteSelection()
{
    if (!m_doc || m_selection.empty())
        return;
    std::vector<Item *> targets(m_selection.begin(), m_selection.end());
    m_selection.clear();
    m_doc->undoStack()->push(new RemoveItemsCommand(
        m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
        std::move(targets), QStringLiteral("Delete")));
    update();
}

void Canvas::cancelActive()
{
    m_activeStroke.reset();
    m_activeShape.reset();
    m_drawing = false;
    if (m_erasing && m_doc) {
        Layer &ly = m_doc->current().active();
        for (auto &s : m_eraseStash)
            ly.items.push_back(std::move(s.item));
    }
    m_eraseStash.clear();
    m_erasing = false;
    m_movingSelection = false;
    m_rubber = false;
}

void Canvas::updateCursor()
{
    switch (m_settings.tool) {
    case ToolId::Pen:
    case ToolId::Highlighter:
    case ToolId::Line:
    case ToolId::Rectangle:
    case ToolId::Ellipse:
        setCursor(Qt::CrossCursor);
        break;
    case ToolId::Eraser:
        setCursor(Qt::BlankCursor);
        break;
    case ToolId::Text:
        setCursor(Qt::IBeamCursor);
        break;
    case ToolId::Select:
        setCursor(Qt::ArrowCursor);
        break;
    }
}

} // namespace ib
EOF

log "PART 4 complete: tool settings and the interactive canvas widget written."
# ---------------------------------------------------------------------------
#  END OF PART 4  —  append PART 5 (MainWindow, toolbars, preferences) below
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
#  PART 5 of 6 : application shell — MainWindow + PreferencesDialog
#  Append below PART 4. Creates new files only.
# ---------------------------------------------------------------------------
log "PART 5: writing MainWindow and PreferencesDialog"

# ---------------------------------------------------------------------------
#  src/ui/PreferencesDialog.h
# ---------------------------------------------------------------------------
cat > src/ui/PreferencesDialog.h <<'EOF'
#pragma once

#include <QDialog>
#include <QColor>

#include "canvas/Tools.h"

class QSpinBox;
class QDoubleSpinBox;
class QPushButton;

namespace ib {

class PreferencesDialog : public QDialog {
    Q_OBJECT
public:
    PreferencesDialog(const ToolSettings &s, int autosaveSeconds,
                      QWidget *parent = nullptr);

    ToolSettings toolSettings() const { return m_settings; }
    int autosaveSeconds() const;

private slots:
    void pickPenColor();
    void applyAndAccept();

private:
    void refreshColorButton();

    ToolSettings m_settings;
    QColor       m_penColor;

    QSpinBox       *m_penWidth      = nullptr;
    QPushButton    *m_penColorBtn   = nullptr;
    QDoubleSpinBox *m_hlWidth       = nullptr;
    QDoubleSpinBox *m_hlOpacity     = nullptr;
    QDoubleSpinBox *m_eraserRadius  = nullptr;
    QSpinBox       *m_textSize      = nullptr;
    QSpinBox       *m_autosave      = nullptr;
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/ui/PreferencesDialog.cpp
# ---------------------------------------------------------------------------
cat > src/ui/PreferencesDialog.cpp <<'EOF'
#include "ui/PreferencesDialog.h"

#include <QFormLayout>
#include <QVBoxLayout>
#include <QDialogButtonBox>
#include <QSpinBox>
#include <QDoubleSpinBox>
#include <QPushButton>
#include <QColorDialog>
#include <QLabel>

namespace ib {

PreferencesDialog::PreferencesDialog(const ToolSettings &s, int autosaveSeconds,
                                     QWidget *parent)
    : QDialog(parent)
    , m_settings(s)
    , m_penColor(s.penColor)
{
    setWindowTitle(tr("Preferences"));
    setModal(true);

    auto *form = new QFormLayout;

    m_penWidth = new QSpinBox(this);
    m_penWidth->setRange(1, 64);
    m_penWidth->setValue(qRound(m_settings.penWidth));
    m_penWidth->setSuffix(tr(" px"));
    form->addRow(tr("Pen width:"), m_penWidth);

    m_penColorBtn = new QPushButton(this);
    connect(m_penColorBtn, &QPushButton::clicked, this, &PreferencesDialog::pickPenColor);
    refreshColorButton();
    form->addRow(tr("Pen color:"), m_penColorBtn);

    m_hlWidth = new QDoubleSpinBox(this);
    m_hlWidth->setRange(1.0, 120.0);
    m_hlWidth->setValue(m_settings.hlWidth);
    m_hlWidth->setSuffix(tr(" px"));
    form->addRow(tr("Highlighter width:"), m_hlWidth);

    m_hlOpacity = new QDoubleSpinBox(this);
    m_hlOpacity->setRange(0.05, 1.0);
    m_hlOpacity->setSingleStep(0.05);
    m_hlOpacity->setValue(m_settings.hlOpacity);
    form->addRow(tr("Highlighter opacity:"), m_hlOpacity);

    m_eraserRadius = new QDoubleSpinBox(this);
    m_eraserRadius->setRange(2.0, 200.0);
    m_eraserRadius->setValue(m_settings.eraserRadius);
    m_eraserRadius->setSuffix(tr(" px"));
    form->addRow(tr("Eraser radius:"), m_eraserRadius);

    m_textSize = new QSpinBox(this);
    m_textSize->setRange(6, 200);
    m_textSize->setValue(m_settings.textFont.pointSize() > 0
                             ? m_settings.textFont.pointSize() : 18);
    m_textSize->setSuffix(tr(" pt"));
    form->addRow(tr("Text size:"), m_textSize);

    m_autosave = new QSpinBox(this);
    m_autosave->setRange(0, 3600);
    m_autosave->setValue(autosaveSeconds);
    m_autosave->setSuffix(tr(" s (0 = off)"));
    form->addRow(tr("Autosave interval:"), m_autosave);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel,
                                         this);
    connect(buttons, &QDialogButtonBox::accepted, this, &PreferencesDialog::applyAndAccept);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);

    auto *root = new QVBoxLayout(this);
    root->addLayout(form);
    root->addWidget(buttons);
}

void PreferencesDialog::refreshColorButton()
{
    m_penColorBtn->setText(m_penColor.name(QColor::HexRgb));
    m_penColorBtn->setStyleSheet(
        QString("background-color:%1; color:%2; padding:4px;")
            .arg(m_penColor.name(),
                 m_penColor.lightness() > 128 ? "#000000" : "#ffffff"));
}

void PreferencesDialog::pickPenColor()
{
    const QColor c = QColorDialog::getColor(m_penColor, this, tr("Pen Color"));
    if (c.isValid()) {
        m_penColor = c;
        refreshColorButton();
    }
}

int PreferencesDialog::autosaveSeconds() const
{
    return m_autosave->value();
}

void PreferencesDialog::applyAndAccept()
{
    m_settings.penWidth     = m_penWidth->value();
    m_settings.penColor     = m_penColor;
    m_settings.hlWidth      = m_hlWidth->value();
    m_settings.hlOpacity    = m_hlOpacity->value();
    m_settings.eraserRadius = m_eraserRadius->value();

    QFont f = m_settings.textFont;
    f.setPointSize(m_textSize->value());
    m_settings.textFont = f;

    accept();
}

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/ui/MainWindow.h
# ---------------------------------------------------------------------------
cat > src/ui/MainWindow.h <<'EOF'
#pragma once

#include <QMainWindow>
#include <map>

#include "model/Document.h"

class QLabel;
class QSpinBox;
class QAction;
class QActionGroup;
class QTimer;
class QToolBar;
class QCloseEvent;

namespace ib {

class Canvas;

class MainWindow : public QMainWindow {
    Q_OBJECT
public:
    explicit MainWindow(QWidget *parent = nullptr);

protected:
    void closeEvent(QCloseEvent *e) override;

private slots:
    void newDocument();
    void openDocument();
    bool saveDocument();
    bool saveDocumentAs();
    void exportPng();
    void exportSvg();
    void exportPdf();
    void addPage();
    void deletePage();
    void nextPage();
    void prevPage();
    void showPreferences();
    void about();
    void updateTitle();
    void updateZoomLabel();
    void updatePageLabel();

private:
    void buildActions();
    void buildMenus();
    void buildToolbars();
    void buildStatusBar();
    void addColorSwatches(QToolBar *tb);

    void loadSettings();
    void saveSettingsToStore();
    void applyAutosave();

    void setActiveColor(const QColor &c);
    void setActiveWidth(double w);
    void setBackgroundKind(BackgroundKind k);
    void syncWidthSpin();
    double currentToolWidth() const;

    bool maybeSave();
    bool saveTo(const QString &path);

    Document *m_doc    = nullptr;
    Canvas   *m_canvas = nullptr;

    QLabel   *m_zoomLabel = nullptr;
    QLabel   *m_posLabel  = nullptr;
    QLabel   *m_pageLabel = nullptr;
    QSpinBox *m_widthSpin = nullptr;

    QActionGroup *m_toolGroup = nullptr;
    QTimer       *m_autosaveTimer = nullptr;
    int           m_autosaveSeconds = 60;

    std::map<ToolId, QAction *> m_toolActions;
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/ui/MainWindow.cpp
# ---------------------------------------------------------------------------
cat > src/ui/MainWindow.cpp <<'EOF'
#include "ui/MainWindow.h"

#include "canvas/Canvas.h"
#include "core/Serializer.h"
#include "core/Exporter.h"
#include "core/Settings.h"
#include "ui/PreferencesDialog.h"

#include <QMenuBar>
#include <QMenu>
#include <QToolBar>
#include <QToolButton>
#include <QAction>
#include <QActionGroup>
#include <QStatusBar>
#include <QLabel>
#include <QSpinBox>
#include <QFileDialog>
#include <QMessageBox>
#include <QColorDialog>
#include <QTimer>
#include <QCloseEvent>
#include <QSignalBlocker>
#include <QKeySequence>
#include <QFileInfo>
#include <QPixmap>
#include <QIcon>
#include <vector>

namespace ib {

static Page makeBlankPage()
{
    Page pg;
    Layer ly;
    ly.name = QStringLiteral("Layer 1");
    pg.layers.clear();
    pg.layers.push_back(std::move(ly));
    pg.activeLayer = 0;
    return pg;
}

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
{
    m_doc = new Document(this);

    m_canvas = new Canvas(this);
    m_canvas->setDocument(m_doc);
    setCentralWidget(m_canvas);

    buildActions();
    buildMenus();
    buildToolbars();
    buildStatusBar();
    loadSettings();

    connect(m_doc, &Document::modifiedChanged, this, &MainWindow::updateTitle);
    connect(m_doc, &Document::pagesChanged, this, &MainWindow::updatePageLabel);
    connect(m_doc, &Document::currentPageChanged, this, [this](int) {
        updatePageLabel();
        m_canvas->update();
    });

    connect(m_canvas, &Canvas::viewChanged, this, &MainWindow::updateZoomLabel);
    connect(m_canvas, &Canvas::cursorMoved, this, [this](QPointF p) {
        m_posLabel->setText(QString("%1, %2")
                                .arg(p.x(), 0, 'f', 0)
                                .arg(p.y(), 0, 'f', 0));
    });
    connect(m_canvas, &Canvas::toolChanged, this, [this](ToolId t) {
        auto it = m_toolActions.find(t);
        if (it != m_toolActions.end())
            it->second->setChecked(true);
        syncWidthSpin();
    });

    m_autosaveTimer = new QTimer(this);
    connect(m_autosaveTimer, &QTimer::timeout, this, [this]() {
        if (m_doc->modified() && !m_doc->filePath().isEmpty())
            saveTo(m_doc->filePath());
    });

    newDocument();
    applyAutosave();
    syncWidthSpin();

    resize(1280, 860);
    updateTitle();
    updateZoomLabel();
    updatePageLabel();
}

// ---- construction helpers --------------------------------------------------
void MainWindow::buildActions()
{
    struct ToolDef { ToolId id; const char *name; const char *shortcut; };
    static const ToolDef defs[] = {
        { ToolId::Pen,         "Pen",         "P" },
        { ToolId::Highlighter, "Highlighter", "H" },
        { ToolId::Eraser,      "Eraser",      "E" },
        { ToolId::Select,      "Select",      "V" },
        { ToolId::Line,        "Line",        "L" },
        { ToolId::Rectangle,   "Rectangle",   "R" },
        { ToolId::Ellipse,     "Ellipse",     "O" },
        { ToolId::Text,        "Text",        "T" },
    };

    m_toolGroup = new QActionGroup(this);
    m_toolGroup->setExclusive(true);

    for (const auto &d : defs) {
        auto *a = new QAction(tr(d.name), this);
        a->setCheckable(true);
        a->setShortcut(QKeySequence(QString::fromLatin1(d.shortcut)));
        const ToolId id = d.id;
        connect(a, &QAction::triggered, this, [this, id]() { m_canvas->setTool(id); });
        m_toolGroup->addAction(a);
        m_toolActions[id] = a;
    }
    m_toolActions[ToolId::Pen]->setChecked(true);
}

void MainWindow::buildMenus()
{
    auto add = [&](QMenu *m, const QString &text, const QKeySequence &sc,
                   auto slot) -> QAction * {
        auto *a = new QAction(text, this);
        if (!sc.isEmpty())
            a->setShortcut(sc);
        connect(a, &QAction::triggered, this, slot);
        m->addAction(a);
        return a;
    };

    // File
    QMenu *file = menuBar()->addMenu(tr("&File"));
    add(file, tr("&New"),  QKeySequence::New,  &MainWindow::newDocument);
    add(file, tr("&Open…"), QKeySequence::Open, &MainWindow::openDocument);
    file->addSeparator();
    add(file, tr("&Save"),    QKeySequence::Save,      &MainWindow::saveDocument);
    add(file, tr("Save &As…"), QKeySequence::SaveAs,   &MainWindow::saveDocumentAs);
    file->addSeparator();
    QMenu *exp = file->addMenu(tr("&Export"));
    add(exp, tr("PNG…"), QKeySequence(), &MainWindow::exportPng);
    add(exp, tr("SVG…"), QKeySequence(), &MainWindow::exportSvg);
    add(exp, tr("PDF…"), QKeySequence(), &MainWindow::exportPdf);
    file->addSeparator();
    add(file, tr("&Quit"), QKeySequence::Quit, [this]() { close(); });

    // Edit
    QMenu *edit = menuBar()->addMenu(tr("&Edit"));
    QAction *undo = m_doc->undoStack()->createUndoAction(this, tr("&Undo"));
    undo->setShortcut(QKeySequence::Undo);
    QAction *redo = m_doc->undoStack()->createRedoAction(this, tr("&Redo"));
    redo->setShortcut(QKeySequence::Redo);
    edit->addAction(undo);
    edit->addAction(redo);
    edit->addSeparator();
    add(edit, tr("&Delete Selection"), QKeySequence::Delete,
        [this]() { m_canvas->deleteSelection(); });
    add(edit, tr("Select &All"), QKeySequence::SelectAll,
        [this]() { m_canvas->selectAll(); });
    add(edit, tr("&Clear Selection"), QKeySequence(),
        [this]() { m_canvas->clearSelection(); });

    // View
    QMenu *view = menuBar()->addMenu(tr("&View"));
    add(view, tr("Zoom &In"),  QKeySequence::ZoomIn,  [this]() { m_canvas->zoomIn(); });
    add(view, tr("Zoom &Out"), QKeySequence::ZoomOut, [this]() { m_canvas->zoomOut(); });
    add(view, tr("&Reset Zoom"), QKeySequence(Qt::CTRL | Qt::Key_0),
        [this]() { m_canvas->resetView(); });
    add(view, tr("Zoom to &Fit"), QKeySequence(Qt::CTRL | Qt::SHIFT | Qt::Key_F),
        [this]() { m_canvas->zoomToFit(); });

    // Tools
    QMenu *tools = menuBar()->addMenu(tr("&Tools"));
    for (const auto &pair : m_toolActions)
        tools->addAction(pair.second);

    // Page
    QMenu *page = menuBar()->addMenu(tr("&Page"));
    add(page, tr("&Add Page"), QKeySequence(Qt::CTRL | Qt::Key_Return),
        &MainWindow::addPage);
    add(page, tr("&Delete Page"), QKeySequence(),  &MainWindow::deletePage);
    add(page, tr("&Next Page"),   QKeySequence(Qt::Key_PageDown), &MainWindow::nextPage);
    add(page, tr("&Previous Page"), QKeySequence(Qt::Key_PageUp), &MainWindow::prevPage);
    page->addSeparator();
    QMenu *bg = page->addMenu(tr("&Background"));
    add(bg, tr("Blank"), QKeySequence(), [this]() { setBackgroundKind(BackgroundKind::Blank); });
    add(bg, tr("Grid"),  QKeySequence(), [this]() { setBackgroundKind(BackgroundKind::Grid); });
    add(bg, tr("Lines"), QKeySequence(), [this]() { setBackgroundKind(BackgroundKind::Lines); });
    add(bg, tr("Dots"),  QKeySequence(), [this]() { setBackgroundKind(BackgroundKind::Dots); });

    // Settings + Help
    QMenu *settings = menuBar()->addMenu(tr("&Settings"));
    add(settings, tr("&Preferences…"), QKeySequence(Qt::CTRL | Qt::Key_Comma),
        &MainWindow::showPreferences);

    QMenu *help = menuBar()->addMenu(tr("&Help"));
    add(help, tr("&About InkBoard"), QKeySequence(), &MainWindow::about);
}

void MainWindow::buildToolbars()
{
    auto *toolBar = addToolBar(tr("Tools"));
    toolBar->setToolButtonStyle(Qt::ToolButtonTextOnly);
    toolBar->setMovable(false);
    for (const auto &pair : m_toolActions)
        toolBar->addAction(pair.second);

    addToolBarBreak();

    auto *props = addToolBar(tr("Properties"));
    props->setMovable(false);
    addColorSwatches(props);
    props->addSeparator();

    props->addWidget(new QLabel(tr(" Size ")));
    m_widthSpin = new QSpinBox(props);
    m_widthSpin->setRange(1, 200);
    m_widthSpin->setValue(3);
    m_widthSpin->setSuffix(tr(" px"));
    connect(m_widthSpin, QOverload<int>::of(&QSpinBox::valueChanged), this,
            [this](int v) { setActiveWidth(static_cast<double>(v)); });
    props->addWidget(m_widthSpin);

    props->addSeparator();
    auto *addPageBtn = new QToolButton(props);
    addPageBtn->setText(tr("+ Page"));
    connect(addPageBtn, &QToolButton::clicked, this, &MainWindow::addPage);
    props->addWidget(addPageBtn);

    auto *prevBtn = new QToolButton(props);
    prevBtn->setText(tr("◀"));
    connect(prevBtn, &QToolButton::clicked, this, &MainWindow::prevPage);
    props->addWidget(prevBtn);

    auto *nextBtn = new QToolButton(props);
    nextBtn->setText(tr("▶"));
    connect(nextBtn, &QToolButton::clicked, this, &MainWindow::nextPage);
    props->addWidget(nextBtn);
}

void MainWindow::addColorSwatches(QToolBar *tb)
{
    for (const QColor &c : m_canvas->settings().palette) {
        QPixmap pm(18, 18);
        pm.fill(c);
        auto *b = new QToolButton(tb);
        b->setIcon(QIcon(pm));
        b->setToolTip(c.name());
        connect(b, &QToolButton::clicked, this, [this, c]() { setActiveColor(c); });
        tb->addWidget(b);
    }
    auto *more = new QToolButton(tb);
    more->setText(QStringLiteral("…"));
    more->setToolTip(tr("Custom color"));
    connect(more, &QToolButton::clicked, this, [this]() {
        const QColor c = QColorDialog::getColor(Qt::black, this, tr("Select Color"));
        if (c.isValid())
            setActiveColor(c);
    });
    tb->addWidget(more);
}

void MainWindow::buildStatusBar()
{
    m_pageLabel = new QLabel(this);
    m_zoomLabel = new QLabel(this);
    m_posLabel  = new QLabel(this);
    statusBar()->addWidget(m_pageLabel);
    statusBar()->addPermanentWidget(m_posLabel);
    statusBar()->addPermanentWidget(m_zoomLabel);
}

// ---- settings persistence --------------------------------------------------
void MainWindow::loadSettings()
{
    auto &s = m_canvas->settings();
    s.penWidth  = Settings::get<double>(QStringLiteral("pen/width"), s.penWidth);
    const QString pc =
        Settings::get<QString>(QStringLiteral("pen/color"),
                               s.penColor.name(QColor::HexArgb));
    if (QColor(pc).isValid())
        s.penColor = QColor(pc);
    s.hlWidth      = Settings::get<double>(QStringLiteral("hl/width"), s.hlWidth);
    s.hlOpacity    = Settings::get<double>(QStringLiteral("hl/opacity"), s.hlOpacity);
    s.eraserRadius = Settings::get<double>(QStringLiteral("eraser/radius"), s.eraserRadius);

    const int ts = Settings::get<int>(QStringLiteral("text/size"),
                                      s.textFont.pointSize() > 0 ? s.textFont.pointSize() : 18);
    QFont f = s.textFont;
    f.setPointSize(ts);
    s.textFont = f;

    m_autosaveSeconds =
        Settings::get<int>(QStringLiteral("app/autosaveSeconds"), m_autosaveSeconds);
}

void MainWindow::saveSettingsToStore()
{
    const auto &s = m_canvas->settings();
    Settings::set<double>(QStringLiteral("pen/width"), s.penWidth);
    Settings::set<QString>(QStringLiteral("pen/color"), s.penColor.name(QColor::HexArgb));
    Settings::set<double>(QStringLiteral("hl/width"), s.hlWidth);
    Settings::set<double>(QStringLiteral("hl/opacity"), s.hlOpacity);
    Settings::set<double>(QStringLiteral("eraser/radius"), s.eraserRadius);
    Settings::set<int>(QStringLiteral("text/size"), s.textFont.pointSize());
    Settings::set<int>(QStringLiteral("app/autosaveSeconds"), m_autosaveSeconds);
}

void MainWindow::applyAutosave()
{
    if (m_autosaveSeconds > 0)
        m_autosaveTimer->start(m_autosaveSeconds * 1000);
    else
        m_autosaveTimer->stop();
}

// ---- tool property helpers -------------------------------------------------
void MainWindow::setActiveColor(const QColor &c)
{
    auto &s = m_canvas->settings();
    switch (s.tool) {
    case ToolId::Highlighter: s.hlColor = c; break;
    case ToolId::Line:
    case ToolId::Rectangle:
    case ToolId::Ellipse:     s.shapeColor = c; break;
    case ToolId::Text:        s.textColor = c; break;
    default:                  s.penColor = c; break;
    }
    m_canvas->refresh();
}

void MainWindow::setActiveWidth(double w)
{
    auto &s = m_canvas->settings();
    switch (s.tool) {
    case ToolId::Highlighter: s.hlWidth = w; break;
    case ToolId::Line:
    case ToolId::Rectangle:
    case ToolId::Ellipse:     s.shapeWidth = w; break;
    case ToolId::Eraser:      s.eraserRadius = w; break;
    default:                  s.penWidth = w; break;
    }
    m_canvas->refresh();
}

double MainWindow::currentToolWidth() const
{
    const auto &s = m_canvas->settings();
    switch (s.tool) {
    case ToolId::Highlighter: return s.hlWidth;
    case ToolId::Line:
    case ToolId::Rectangle:
    case ToolId::Ellipse:     return s.shapeWidth;
    case ToolId::Eraser:      return s.eraserRadius;
    default:                  return s.penWidth;
    }
}

void MainWindow::syncWidthSpin()
{
    if (!m_widthSpin)
        return;
    const QSignalBlocker blocker(m_widthSpin);
    m_widthSpin->setValue(qRound(currentToolWidth()));
}

void MainWindow::setBackgroundKind(BackgroundKind k)
{
    if (!m_doc)
        return;
    m_doc->current().background = k;
    m_doc->markChanged();
    m_canvas->update();
}

// ---- file operations -------------------------------------------------------
bool MainWindow::maybeSave()
{
    if (!m_doc->modified())
        return true;
    const auto r = QMessageBox::warning(
        this, tr("InkBoard"),
        tr("The document has unsaved changes.\nDo you want to save them?"),
        QMessageBox::Save | QMessageBox::Discard | QMessageBox::Cancel);
    if (r == QMessageBox::Save)
        return saveDocument();
    if (r == QMessageBox::Cancel)
        return false;
    return true;
}

void MainWindow::newDocument()
{
    if (!maybeSave())
        return;
    std::vector<Page> pages;
    pages.push_back(makeBlankPage());
    m_doc->setPages(std::move(pages));
    m_doc->setCurrentIndex(0);
    m_doc->setFilePath(QString());
    m_doc->undoStack()->clear();
    m_doc->setModified(false);
    m_canvas->clearSelection();
    m_canvas->resetView();
    updateTitle();
    updatePageLabel();
    m_canvas->update();
}

void MainWindow::openDocument()
{
    if (!maybeSave())
        return;
    const QString path = QFileDialog::getOpenFileName(
        this, tr("Open"), QString(),
        tr("InkBoard files (*.iboard);;All files (*)"));
    if (path.isEmpty())
        return;

    QString err;
    if (!io::Serializer::loadFromFile(*m_doc, path, &err)) {
        QMessageBox::warning(this, tr("Open failed"),
                             tr("Could not open the file:\n%1").arg(err));
        return;
    }
    m_doc->setFilePath(path);
    m_doc->setCurrentIndex(0);
    m_doc->undoStack()->clear();
    m_doc->setModified(false);
    m_canvas->clearSelection();
    m_canvas->zoomToFit();
    updateTitle();
    updatePageLabel();
    m_canvas->update();
}

bool MainWindow::saveTo(const QString &path)
{
    QString err;
    if (!io::Serializer::saveToFile(*m_doc, path, &err)) {
        QMessageBox::warning(this, tr("Save failed"),
                             tr("Could not save the file:\n%1").arg(err));
        return false;
    }
    m_doc->setFilePath(path);
    m_doc->undoStack()->setClean();
    m_doc->setModified(false);
    updateTitle();
    statusBar()->showMessage(tr("Saved %1").arg(QFileInfo(path).fileName()), 3000);
    return true;
}

bool MainWindow::saveDocument()
{
    if (m_doc->filePath().isEmpty())
        return saveDocumentAs();
    return saveTo(m_doc->filePath());
}

bool MainWindow::saveDocumentAs()
{
    QString path = QFileDialog::getSaveFileName(
        this, tr("Save As"), QStringLiteral("Untitled.iboard"),
        tr("InkBoard files (*.iboard)"));
    if (path.isEmpty())
        return false;
    if (!path.endsWith(QStringLiteral(".iboard"), Qt::CaseInsensitive))
        path += QStringLiteral(".iboard");
    return saveTo(path);
}

void MainWindow::exportPng()
{
    const QString path = QFileDialog::getSaveFileName(
        this, tr("Export PNG"), QStringLiteral("page.png"), tr("PNG image (*.png)"));
    if (path.isEmpty())
        return;
    QString err;
    if (!io::Exporter::exportPng(m_doc->current(), path, 2.0, &err))
        QMessageBox::warning(this, tr("Export failed"), err);
}

void MainWindow::exportSvg()
{
    const QString path = QFileDialog::getSaveFileName(
        this, tr("Export SVG"), QStringLiteral("page.svg"), tr("SVG image (*.svg)"));
    if (path.isEmpty())
        return;
    QString err;
    if (!io::Exporter::exportSvg(m_doc->current(), path, &err))
        QMessageBox::warning(this, tr("Export failed"), err);
}

void MainWindow::exportPdf()
{
    const QString path = QFileDialog::getSaveFileName(
        this, tr("Export PDF"), QStringLiteral("document.pdf"), tr("PDF document (*.pdf)"));
    if (path.isEmpty())
        return;
    QString err;
    if (!io::Exporter::exportPdf(*m_doc, path, &err))
        QMessageBox::warning(this, tr("Export failed"), err);
}

// ---- page navigation -------------------------------------------------------
void MainWindow::addPage()
{
    m_doc->addPage();
    m_doc->setCurrentIndex(m_doc->pageCount() - 1);
    updatePageLabel();
    m_canvas->update();
}

void MainWindow::deletePage()
{
    if (m_doc->pageCount() <= 1) {
        QMessageBox::information(this, tr("InkBoard"),
                                tr("Cannot delete the only page."));
        return;
    }
    m_doc->removePage(m_doc->currentIndex());
    updatePageLabel();
    m_canvas->update();
}

void MainWindow::nextPage()
{
    if (m_doc->currentIndex() + 1 < m_doc->pageCount())
        m_doc->setCurrentIndex(m_doc->currentIndex() + 1);
}

void MainWindow::prevPage()
{
    if (m_doc->currentIndex() > 0)
        m_doc->setCurrentIndex(m_doc->currentIndex() - 1);
}

// ---- misc ------------------------------------------------------------------
void MainWindow::showPreferences()
{
    PreferencesDialog dlg(m_canvas->settings(), m_autosaveSeconds, this);
    if (dlg.exec() != QDialog::Accepted)
        return;

    ToolSettings ns = dlg.toolSettings();
    ns.tool    = m_canvas->settings().tool;    // preserve active tool
    ns.palette = m_canvas->settings().palette; // preserve palette
    m_canvas->settings() = ns;

    m_autosaveSeconds = dlg.autosaveSeconds();
    saveSettingsToStore();
    applyAutosave();
    syncWidthSpin();
    m_canvas->refresh();
}

void MainWindow::about()
{
    QMessageBox::about(
        this, tr("About InkBoard"),
        tr("<b>InkBoard %1</b><br>"
           "A pressure-aware teaching whiteboard for pen displays.<br><br>"
           "Built with Qt 6.")
            .arg(QStringLiteral(INKBOARD_VERSION)));
}

void MainWindow::updateTitle()
{
    const QString name = m_doc->filePath().isEmpty()
                             ? tr("Untitled")
                             : QFileInfo(m_doc->filePath()).fileName();
    setWindowTitle(QString("%1[*] — InkBoard").arg(name));
    setWindowModified(m_doc->modified());
}

void MainWindow::updateZoomLabel()
{
    if (m_zoomLabel)
        m_zoomLabel->setText(QString("%1%").arg(qRound(m_canvas->zoomPercent())));
}

void MainWindow::updatePageLabel()
{
    if (m_pageLabel)
        m_pageLabel->setText(tr("Page %1 / %2")
                                 .arg(m_doc->currentIndex() + 1)
                                 .arg(m_doc->pageCount()));
}

void MainWindow::closeEvent(QCloseEvent *e)
{
    if (maybeSave())
        e->accept();
    else
        e->ignore();
}

} // namespace ib
EOF

log "PART 5 complete: MainWindow and PreferencesDialog written."
# ---------------------------------------------------------------------------
#  END OF PART 5  —  append PART 6 (NSIS packaging + README + closing) below
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
#  PART 6 of 6 : Windows installer script, README, and closing banner
#  Append below PART 5. This finishes setup.sh.
# ---------------------------------------------------------------------------
log "PART 6: writing packaging installer and README"

# ---------------------------------------------------------------------------
#  packaging/installer.nsi  — NSIS (MUI2) installer for the deployed dist/
# ---------------------------------------------------------------------------
cat > packaging/installer.nsi <<'NSIS_EOF'
; InkBoard Windows installer
; Compiled by build.yml with:  makensis.exe packaging/installer.nsi
; (invoked from the pen-whiteboard/ directory, so relative paths resolve there)

!include "MUI2.nsh"

Name "InkBoard"
OutFile "InkBoard-Setup.exe"
Unicode true
InstallDir "$PROGRAMFILES64\InkBoard"
InstallDirRegKey HKLM "Software\InkBoard" "InstallDir"
RequestExecutionLevel admin

!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\InkBoard.exe"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

Section "InkBoard (required)" SecMain
  SectionIn RO
  SetOutPath "$INSTDIR"

  ; Deploy everything windeployqt placed in dist/ (exe + Qt runtime + plugins)
  File /r "dist\*.*"

  WriteRegStr HKLM "Software\InkBoard" "InstallDir" "$INSTDIR"
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  CreateDirectory "$SMPROGRAMS\InkBoard"
  CreateShortcut "$SMPROGRAMS\InkBoard\InkBoard.lnk" "$INSTDIR\InkBoard.exe"
  CreateShortcut "$SMPROGRAMS\InkBoard\Uninstall InkBoard.lnk" "$INSTDIR\Uninstall.exe"
  CreateShortcut "$DESKTOP\InkBoard.lnk" "$INSTDIR\InkBoard.exe"

  WriteRegStr   HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\InkBoard" "DisplayName"     "InkBoard"
  WriteRegStr   HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\InkBoard" "UninstallString" "$\"$INSTDIR\Uninstall.exe$\""
  WriteRegStr   HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\InkBoard" "DisplayIcon"     "$\"$INSTDIR\InkBoard.exe$\""
  WriteRegStr   HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\InkBoard" "Publisher"       "InkBoard"
  WriteRegStr   HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\InkBoard" "DisplayVersion"  "1.0.0"
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\InkBoard" "NoModify" 1
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\InkBoard" "NoRepair" 1
SectionEnd

Section "Uninstall"
  Delete "$SMPROGRAMS\InkBoard\InkBoard.lnk"
  Delete "$SMPROGRAMS\InkBoard\Uninstall InkBoard.lnk"
  RMDir  "$SMPROGRAMS\InkBoard"
  Delete "$DESKTOP\InkBoard.lnk"

  RMDir /r "$INSTDIR"

  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\InkBoard"
  DeleteRegKey HKLM "Software\InkBoard"
SectionEnd
NSIS_EOF

# ---------------------------------------------------------------------------
#  README.md
# ---------------------------------------------------------------------------
cat > README.md <<'EOF'
# InkBoard

A pressure-aware teaching whiteboard for pen displays (optimized for Wacom-style
tablets), built with Qt 6 Widgets.

## Features

- Pressure-sensitive **pen** and **highlighter** (via `QTabletEvent`)
- **Eraser** (stylus eraser tip auto-switches), **shapes** (line / rectangle /
  ellipse), **text**, and a **selection** tool with move + rubber-band
- Full **undo / redo** through `QUndoStack`
- Multi-page documents with **grid / lines / dots / blank** backgrounds
- **Layers** per page
- Infinite pan (space-drag or middle mouse) and cursor-anchored zoom (wheel)
- Native `.iboard` JSON format, plus **PNG / SVG / PDF** export
- **Autosave**, persistent preferences

## Building locally

Requirements: Qt 6.5+ (Core, Gui, Widgets, Svg, PrintSupport), CMake 3.21+, a
C++17 compiler.
bash setup.sh              # generates the pen-whiteboard/ project
cd pen-whiteboard
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release

The executable is written to `build/bin/` (or `build/bin/Release/` with
multi-config generators such as Visual Studio).

## Windows CI build

Pushing to `main` runs `.github/workflows/build.yml`, which regenerates the
project from `setup.sh`, compiles it with MSVC + Qt, runs `windeployqt`, builds
an NSIS installer, and uploads the portable build, the installer, and the build
log as artifacts.

## Keyboard shortcuts

| Key | Action |
| --- | --- |
| P / H / E / V | Pen / Highlighter / Eraser / Select |
| L / R / O / T | Line / Rectangle / Ellipse / Text |
| Ctrl+Z / Ctrl+Y | Undo / Redo |
| Ctrl+N / O / S | New / Open / Save |
| Ctrl++ / Ctrl+- / Ctrl+0 | Zoom in / out / reset |
| Ctrl+Shift+F | Zoom to fit |
| PgUp / PgDn | Previous / next page |
| Del | Delete selection |
| Space + drag | Pan |
EOF

log "PART 6 complete: installer and README written."

echo ""
echo "=================================================================="
echo "  InkBoard scaffold complete."
echo "  Project generated in: $(pwd)"
echo "  Next:"
echo "    cmake -B build -DCMAKE_BUILD_TYPE=Release"
echo "    cmake --build build --config Release"
echo "=================================================================="

# ---------------------------------------------------------------------------
#  PART 7 : post-generation source patches (compile-fix pass)
#  Appended after PART 6. Runs from inside pen-whiteboard/ (cwd unchanged).
#  Fixes:
#   1) Canvas.cpp  : add TextItem/ImageItem includes (make_unique<TextItem>)
#   2) MainWindow  : include <QUndoStack> (Document.h only forward-declares it)
#   3) MainWindow  : ib::io Serializer/Exporter are free functions, not classes
#   4) main.cpp    : drop deprecated AA_UseHighDpiPixmaps (C4996)
# ---------------------------------------------------------------------------
log "PART 7: applying compile-fix patches"

# 1) Canvas.cpp needs the concrete TextItem type for make_unique<TextItem>().
sed -i 's|#include "core/Commands.h"|#include "core/Commands.h"\n#include "model/TextItem.h"\n#include "model/ImageItem.h"|' src/canvas/Canvas.cpp

# 2) MainWindow.cpp must see the full QUndoStack definition.
sed -i 's|#include <QMenuBar>|#include <QUndoStack>\n#include <QMenuBar>|' src/ui/MainWindow.cpp

# 3) ib::io serializer/exporter entry points are free functions in namespace io.
sed -i 's|io::Serializer::|io::|g' src/ui/MainWindow.cpp
sed -i 's|io::Exporter::|io::|g' src/ui/MainWindow.cpp

# 4) Remove the deprecated high-DPI attribute (no effect in Qt 6, emits C4996).
sed -i '/AA_UseHighDpiPixmaps/d' src/main.cpp

log "PART 7 complete: compile-fix patches applied"
# ---------------------------------------------------------------------------
#  END OF PART 7  —  setup.sh is complete.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
#  PART 8 : Apple-style Laser Pointer tool (hot core + glow + fade)
#  Appended after PART 7. Overwrites specific files with laser-enabled
#  versions and adds a header-only trail engine. No serialization changes.
# ---------------------------------------------------------------------------
log "PART 8: adding the laser pointer tool"

# ---------------------------------------------------------------------------
#  src/model/Types.h  (overwrite: adds ToolId::Laser)
# ---------------------------------------------------------------------------
cat > src/model/Types.h <<'EOF'
#pragma once

#include <QPointF>

namespace ib {

enum class ToolId {
    Pen,
    Highlighter,
    Eraser,
    Select,
    Line,
    Rectangle,
    Ellipse,
    Text,
    Laser
};

enum class ItemType { Stroke, Shape, Text, Image };
enum class ShapeKind { Line, Rectangle, Ellipse };
enum class BackgroundKind { Blank, Grid, Lines, Dots };

struct StrokePoint {
    double x = 0.0;
    double y = 0.0;
    double pressure = 1.0;

    StrokePoint() = default;
    StrokePoint(double px, double py, double pr = 1.0)
        : x(px), y(py), pressure(pr) {}

    QPointF pos() const { return QPointF(x, y); }
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/canvas/Laser.h  (new: settings + fading trail renderer, header-only)
# ---------------------------------------------------------------------------
cat > src/canvas/Laser.h <<'EOF'
#pragma once

#include <QColor>
#include <QPointF>
#include <QVector>
#include <QPainter>
#include <QRadialGradient>

namespace ib {

// All timing values are in milliseconds; sizes are in screen pixels.
struct LaserSettings {
    QColor coreColor    = QColor(255, 255, 255); // hot white core
    QColor glowColor    = QColor(255, 45, 40);   // warm outer glow (Apple-like)
    double width        = 7.0;    // core diameter
    double glowRadius   = 26.0;   // glow radius around the core
    double intensity    = 1.0;    // overall opacity multiplier (0..1)
    int    vanishDelayMs  = 200;  // time a sample stays fully bright
    int    fadeDurationMs = 700;  // time to fade from full to gone
    bool   glowEnabled  = true;
};

struct LaserPoint {
    QPointF pos;      // widget/device coordinates
    qint64  bornMs = 0;
};

class LaserTrail {
public:
    void setSettings(const LaserSettings &s) { m_s = s; }
    const LaserSettings &settings() const { return m_s; }

    void add(const QPointF &widgetPos, qint64 nowMs)
    {
        m_points.push_back({ widgetPos, nowMs });
        if (m_points.size() > 4096)
            m_points.remove(0, m_points.size() - 4096);
    }

    void clear() { m_points.clear(); }
    bool isEmpty() const { return m_points.isEmpty(); }

    // Drop fully-faded samples. Returns true if anything remains.
    bool prune(qint64 nowMs)
    {
        const qint64 life =
            static_cast<qint64>(m_s.vanishDelayMs) + static_cast<qint64>(m_s.fadeDurationMs);
        int i = 0;
        while (i < m_points.size() && (nowMs - m_points[i].bornMs) > life)
            ++i;
        if (i > 0)
            m_points.remove(0, i);
        return !m_points.isEmpty();
    }

    double alphaFor(qint64 ageMs) const
    {
        if (ageMs <= m_s.vanishDelayMs)
            return 1.0;
        if (m_s.fadeDurationMs <= 0)
            return 0.0;
        const double f =
            1.0 - static_cast<double>(ageMs - m_s.vanishDelayMs) /
                      static_cast<double>(m_s.fadeDurationMs);
        return f < 0.0 ? 0.0 : (f > 1.0 ? 1.0 : f);
    }

    // Painted in DEVICE (widget) coordinates.
    void paint(QPainter &p, qint64 nowMs) const
    {
        if (m_points.isEmpty())
            return;

        p.save();
        p.setRenderHint(QPainter::Antialiasing, true);
        p.setPen(Qt::NoPen);

        const double coreR = qMax(0.5, m_s.width * 0.5);
        const double glowR = qMax(coreR, m_s.glowRadius);

        if (m_s.glowEnabled) {
            for (const auto &lp : m_points) {
                const double a = alphaFor(nowMs - lp.bornMs) * m_s.intensity;
                if (a <= 0.01)
                    continue;
                QRadialGradient g(lp.pos, glowR);
                QColor c0 = m_s.glowColor; c0.setAlphaF(0.55 * a);
                QColor c1 = m_s.glowColor; c1.setAlphaF(0.0);
                g.setColorAt(0.0, c0);
                g.setColorAt(1.0, c1);
                p.setBrush(g);
                p.drawEllipse(lp.pos, glowR, glowR);
            }
        }

        for (const auto &lp : m_points) {
            const double a = alphaFor(nowMs - lp.bornMs) * m_s.intensity;
            if (a <= 0.01)
                continue;
            const double r = coreR * 1.6;
            QRadialGradient g(lp.pos, r);
            QColor cc = m_s.coreColor; cc.setAlphaF(a);
            QColor edge = m_s.glowColor; edge.setAlphaF(0.0);
            g.setColorAt(0.0, cc);
            g.setColorAt(0.6, cc);
            g.setColorAt(1.0, edge);
            p.setBrush(g);
            p.drawEllipse(lp.pos, r, r);
        }

        p.restore();
    }

private:
    LaserSettings       m_s;
    QVector<LaserPoint> m_points;
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/canvas/Tools.h  (overwrite: adds LaserSettings to ToolSettings)
# ---------------------------------------------------------------------------
cat > src/canvas/Tools.h <<'EOF'
#pragma once

#include <QColor>
#include <QFont>
#include <QList>

#include "model/Types.h"
#include "canvas/Laser.h"

namespace ib {

enum class EraserMode { Stroke, Area };

struct ToolSettings {
    ToolId tool = ToolId::Pen;

    // Pen
    QColor penColor    = QColor(24, 24, 24);
    double penWidth    = 3.0;
    bool   penPressure = true;

    // Highlighter
    QColor hlColor   = QColor(255, 214, 10);
    double hlWidth   = 18.0;
    double hlOpacity = 0.40;

    // Eraser
    EraserMode eraserMode   = EraserMode::Stroke;
    double     eraserRadius = 12.0;

    // Shape
    ShapeKind shapeKind   = ShapeKind::Rectangle;
    QColor    shapeColor  = QColor(24, 24, 24);
    double    shapeWidth  = 3.0;
    bool      shapeFilled = false;
    QColor    shapeFill   = QColor(120, 170, 255, 90);

    // Text
    QColor textColor = QColor(24, 24, 24);
    QFont  textFont  = QFont(QStringLiteral("Sans Serif"), 18);

    // Laser pointer
    LaserSettings laser;

    QList<QColor> palette;

    ToolSettings()
    {
        palette = {
            QColor(24, 24, 24),  QColor(230, 30, 30),  QColor(30, 110, 230),
            QColor(30, 160, 60), QColor(245, 170, 20), QColor(150, 40, 200),
            QColor(255, 255, 255)
        };
    }
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/canvas/Canvas.h  (overwrite: adds laser trail + fade timer)
# ---------------------------------------------------------------------------
cat > src/canvas/Canvas.h <<'EOF'
#pragma once

#include <QWidget>
#include <QPointF>
#include <QElapsedTimer>
#include <memory>
#include <vector>

#include "model/Document.h"
#include "model/StrokeItem.h"
#include "model/ShapeItem.h"
#include "canvas/Tools.h"

class QPaintEvent;
class QMouseEvent;
class QTabletEvent;
class QWheelEvent;
class QKeyEvent;
class QTimer;

namespace ib {

class Canvas : public QWidget {
    Q_OBJECT
public:
    explicit Canvas(QWidget *parent = nullptr);

    void setDocument(Document *doc);
    Document *document() const { return m_doc; }

    ToolSettings &settings() { return m_settings; }
    const ToolSettings &settings() const { return m_settings; }

    void setTool(ToolId t);
    ToolId tool() const { return m_settings.tool; }

    bool hasSelection() const { return !m_selection.empty(); }
    double zoomPercent() const { return m_scale * 100.0; }

public slots:
    void zoomIn();
    void zoomOut();
    void resetView();
    void zoomToFit();
    void deleteSelection();
    void selectAll();
    void clearSelection();
    void refresh() { update(); }

signals:
    void viewChanged();
    void toolChanged(ib::ToolId tool);
    void cursorMoved(QPointF scenePos);

protected:
    void paintEvent(QPaintEvent *) override;
    void mousePressEvent(QMouseEvent *e) override;
    void mouseMoveEvent(QMouseEvent *e) override;
    void mouseReleaseEvent(QMouseEvent *e) override;
    void tabletEvent(QTabletEvent *e) override;
    void wheelEvent(QWheelEvent *e) override;
    void keyPressEvent(QKeyEvent *e) override;
    void keyReleaseEvent(QKeyEvent *e) override;

private:
    enum class Action { Press, Move, Release };

    struct EraseStash {
        std::size_t index;
        ItemPtr     item;
    };

    QPointF widgetToScene(const QPointF &p) const { return (p - m_translate) / m_scale; }
    QPointF sceneToWidget(const QPointF &s) const { return s * m_scale + m_translate; }

    void handlePointer(Action a, const QPointF &widgetPos, double pressure,
                       Qt::KeyboardModifiers mods, bool eraserTip);
    void handleSelect(Action a, const QPointF &sp, Qt::KeyboardModifiers mods);

    void commitAdd(ItemPtr item, const QString &text);
    void eraseAt(const QPointF &sp);
    void finishErase();
    void addTextAt(const QPointF &sp);
    void cancelActive();
    void zoomAround(const QPointF &widgetPos, double factor);
    void updateCursor();

    void drawBackground(QPainter &p, const Page &pg, const QRectF &area);
    void drawSelection(QPainter &p);

    bool hitTest(Item *it, const QPointF &sp, double radius) const;
    Item *topItemAt(const QPointF &sp);
    void selectInRect(const QRectF &r, bool add);
    void setSelectionSingle(Item *it);
    void addToSelection(Item *it);
    void removeFromSelection(Item *it);

    Document    *m_doc = nullptr;
    ToolSettings m_settings;

    double  m_scale = 1.0;
    QPointF m_translate;

    bool   m_panning = false;
    bool   m_spaceDown = false;
    QPoint m_lastPanPos;

    std::unique_ptr<StrokeItem> m_activeStroke;
    std::unique_ptr<ShapeItem>  m_activeShape;
    bool m_drawing = false;

    bool m_erasing = false;
    std::vector<EraseStash> m_eraseStash;

    std::vector<Item *> m_selection;
    bool    m_movingSelection = false;
    QPointF m_moveStartScene;
    QPointF m_moveAccum;
    bool    m_rubber = false;
    QPointF m_rubberStartScene;
    QRectF  m_rubberRect;

    QPointF m_cursorWidget;

    // Laser pointer
    LaserTrail    m_laser;
    QTimer       *m_laserTimer = nullptr;
    QElapsedTimer m_clock;
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/canvas/Canvas.cpp  (overwrite: laser handling + overlay rendering)
# ---------------------------------------------------------------------------
cat > src/canvas/Canvas.cpp <<'EOF'
#include "canvas/Canvas.h"

#include "core/Commands.h"
#include "model/TextItem.h"
#include "model/ImageItem.h"

#include <QPainter>
#include <QPen>
#include <QMouseEvent>
#include <QTabletEvent>
#include <QWheelEvent>
#include <QKeyEvent>
#include <QPointingDevice>
#include <QInputDialog>
#include <QUndoStack>
#include <QTimer>
#include <QLineF>
#include <algorithm>
#include <cmath>

namespace ib {

static const double kPi = 3.14159265358979323846;

static double distToSegment(const QPointF &p, const QPointF &a, const QPointF &b)
{
    const QPointF ab = b - a;
    const double len2 = ab.x() * ab.x() + ab.y() * ab.y();
    if (len2 <= 1e-9)
        return std::hypot(p.x() - a.x(), p.y() - a.y());
    double t = ((p.x() - a.x()) * ab.x() + (p.y() - a.y()) * ab.y()) / len2;
    t = std::max(0.0, std::min(1.0, t));
    const QPointF proj(a.x() + t * ab.x(), a.y() + t * ab.y());
    return std::hypot(p.x() - proj.x(), p.y() - proj.y());
}

static QPointF constrainShape(const QPointF &a, const QPointF &b, ShapeKind kind)
{
    const QPointF d = b - a;
    if (kind == ShapeKind::Line) {
        double ang = std::atan2(d.y(), d.x());
        const double step = kPi / 4.0;
        ang = std::round(ang / step) * step;
        const double len = std::hypot(d.x(), d.y());
        return a + QPointF(std::cos(ang) * len, std::sin(ang) * len);
    }
    const double s = std::max(std::abs(d.x()), std::abs(d.y()));
    return a + QPointF(d.x() < 0 ? -s : s, d.y() < 0 ? -s : s);
}

Canvas::Canvas(QWidget *parent)
    : QWidget(parent)
{
    setFocusPolicy(Qt::StrongFocus);
    setMouseTracking(true);
    setAttribute(Qt::WA_TabletTracking, true);
    setAutoFillBackground(false);
    m_translate = QPointF(40, 40);

    m_clock.start();
    m_laserTimer = new QTimer(this);
    connect(m_laserTimer, &QTimer::timeout, this, [this]() {
        if (m_laser.prune(m_clock.elapsed())) {
            update();
        } else {
            m_laserTimer->stop();
            update();
        }
    });

    updateCursor();
}

void Canvas::setDocument(Document *doc)
{
    if (m_doc == doc)
        return;
    if (m_doc) {
        m_doc->disconnect(this);
        if (m_doc->undoStack())
            m_doc->undoStack()->disconnect(this);
    }
    m_doc = doc;
    cancelActive();
    m_selection.clear();

    if (m_doc) {
        connect(m_doc, &Document::currentPageChanged, this, [this](int) {
            cancelActive(); m_selection.clear(); update();
        });
        connect(m_doc, &Document::pagesChanged, this, [this]() {
            cancelActive(); m_selection.clear(); update();
        });
        connect(m_doc, &Document::contentChanged, this, [this]() { update(); });
        if (m_doc->undoStack()) {
            connect(m_doc->undoStack(), &QUndoStack::indexChanged, this, [this](int) {
                m_selection.clear(); cancelActive(); update();
            });
        }
    }
    update();
}

void Canvas::setTool(ToolId t)
{
    cancelActive();
    m_settings.tool = t;
    updateCursor();
    emit toolChanged(t);
    update();
}

// ---- view ------------------------------------------------------------------
void Canvas::zoomAround(const QPointF &widgetPos, double factor)
{
    const QPointF before = widgetToScene(widgetPos);
    m_scale = qBound(0.05, m_scale * factor, 40.0);
    m_translate = widgetPos - before * m_scale;
    update();
    emit viewChanged();
}

void Canvas::zoomIn()  { zoomAround(QPointF(width() / 2.0, height() / 2.0), 1.2); }
void Canvas::zoomOut() { zoomAround(QPointF(width() / 2.0, height() / 2.0), 1.0 / 1.2); }

void Canvas::resetView()
{
    m_scale = 1.0;
    m_translate = QPointF(40, 40);
    update();
    emit viewChanged();
}

void Canvas::zoomToFit()
{
    if (!m_doc) { update(); return; }
    QRectF b = m_doc->current().contentBounds();
    if (b.isNull()) { resetView(); return; }
    b.adjust(-40, -40, 40, 40);
    const double sx = width()  / b.width();
    const double sy = height() / b.height();
    m_scale = qBound(0.05, qMin(sx, sy), 40.0);
    m_translate = QPointF(width() / 2.0, height() / 2.0) - b.center() * m_scale;
    update();
    emit viewChanged();
}

// ---- painting --------------------------------------------------------------
void Canvas::drawBackground(QPainter &p, const Page &pg, const QRectF &area)
{
    if (pg.background == BackgroundKind::Blank)
        return;
    const double s = qMax(4.0, pg.gridSpacing);
    QPen pen(pg.gridColor);
    pen.setCosmetic(true);
    pen.setWidth(1);
    p.setPen(pen);

    const double startX = std::floor(area.left() / s) * s;
    const double startY = std::floor(area.top() / s) * s;

    if (pg.background == BackgroundKind::Grid) {
        for (double x = startX; x <= area.right(); x += s)
            p.drawLine(QPointF(x, area.top()), QPointF(x, area.bottom()));
        for (double y = startY; y <= area.bottom(); y += s)
            p.drawLine(QPointF(area.left(), y), QPointF(area.right(), y));
    } else if (pg.background == BackgroundKind::Lines) {
        for (double y = startY; y <= area.bottom(); y += s)
            p.drawLine(QPointF(area.left(), y), QPointF(area.right(), y));
    } else {
        p.setPen(Qt::NoPen);
        p.setBrush(pg.gridColor);
        for (double x = startX; x <= area.right(); x += s)
            for (double y = startY; y <= area.bottom(); y += s)
                p.drawEllipse(QPointF(x, y), 1.3, 1.3);
    }
}

void Canvas::drawSelection(QPainter &p)
{
    if (m_selection.empty())
        return;
    QPen pen(QColor(60, 120, 220));
    pen.setCosmetic(true);
    pen.setStyle(Qt::DashLine);
    pen.setWidth(1);
    p.setPen(pen);
    p.setBrush(Qt::NoBrush);
    for (Item *it : m_selection)
        p.drawRect(it->boundingRect());
}

void Canvas::paintEvent(QPaintEvent *)
{
    QPainter p(this);
    p.fillRect(rect(), QColor(90, 93, 99));
    if (!m_doc)
        return;

    p.save();
    p.translate(m_translate);
    p.scale(m_scale, m_scale);

    const QRectF sceneRect =
        QRectF(widgetToScene(QPointF(0, 0)),
               widgetToScene(QPointF(width(), height()))).normalized();

    Page &pg = m_doc->current();
    p.fillRect(sceneRect, pg.bgColor);
    drawBackground(p, pg, sceneRect);

    p.setRenderHint(QPainter::Antialiasing, true);
    p.setRenderHint(QPainter::TextAntialiasing, true);

    for (const auto &ly : pg.layers) {
        if (!ly.visible)
            continue;
        p.save();
        if (ly.opacity < 1.0)
            p.setOpacity(ly.opacity);
        for (const auto &it : ly.items)
            it->paint(p);
        p.restore();
    }

    if (m_activeStroke) m_activeStroke->paint(p);
    if (m_activeShape)  m_activeShape->paint(p);

    drawSelection(p);

    if (m_rubber) {
        QPen pen(QColor(60, 120, 220));
        pen.setCosmetic(true);
        pen.setStyle(Qt::DashLine);
        p.setPen(pen);
        p.setBrush(QColor(60, 120, 220, 40));
        p.drawRect(m_rubberRect);
    }

    p.restore();

    if (m_settings.tool == ToolId::Eraser && underMouse()) {
        const double r = m_settings.eraserRadius * m_scale;
        QPen pen(QColor(70, 70, 70));
        pen.setStyle(Qt::DashLine);
        p.setPen(pen);
        p.setBrush(Qt::NoBrush);
        p.drawEllipse(m_cursorWidget, r, r);
    }

    // Laser overlay (device coordinates, drawn on top of everything).
    if (!m_laser.isEmpty())
        m_laser.paint(p, m_clock.elapsed());
}

// ---- input -----------------------------------------------------------------
void Canvas::mousePressEvent(QMouseEvent *e)
{
    m_cursorWidget = e->position();
    if (e->button() == Qt::MiddleButton ||
        (m_spaceDown && e->button() == Qt::LeftButton)) {
        m_panning = true;
        m_lastPanPos = e->position().toPoint();
        setCursor(Qt::ClosedHandCursor);
        return;
    }
    if (e->button() == Qt::LeftButton)
        handlePointer(Action::Press, e->position(), 1.0, e->modifiers(), false);
}

void Canvas::mouseMoveEvent(QMouseEvent *e)
{
    m_cursorWidget = e->position();
    if (m_panning) {
        const QPoint d = e->position().toPoint() - m_lastPanPos;
        m_lastPanPos = e->position().toPoint();
        m_translate += QPointF(d);
        update();
        emit viewChanged();
        return;
    }
    handlePointer(Action::Move, e->position(), 1.0, e->modifiers(), false);
    if (m_settings.tool == ToolId::Eraser)
        update();
    emit cursorMoved(widgetToScene(e->position()));
}

void Canvas::mouseReleaseEvent(QMouseEvent *e)
{
    m_cursorWidget = e->position();
    if (m_panning &&
        (e->button() == Qt::MiddleButton || e->button() == Qt::LeftButton)) {
        m_panning = false;
        updateCursor();
        return;
    }
    if (e->button() == Qt::LeftButton)
        handlePointer(Action::Release, e->position(), 1.0, e->modifiers(), false);
}

void Canvas::tabletEvent(QTabletEvent *e)
{
    const bool eraserTip =
        e->pointerType() == QPointingDevice::PointerType::Eraser;
    double pr = e->pressure();
    if (pr <= 0.0)
        pr = 1.0;
    m_cursorWidget = e->position();

    switch (e->type()) {
    case QEvent::TabletPress:
        handlePointer(Action::Press, e->position(), pr, e->modifiers(), eraserTip);
        break;
    case QEvent::TabletMove:
        handlePointer(Action::Move, e->position(), pr, e->modifiers(), eraserTip);
        emit cursorMoved(widgetToScene(e->position()));
        if (m_settings.tool == ToolId::Eraser)
            update();
        break;
    case QEvent::TabletRelease:
        handlePointer(Action::Release, e->position(), pr, e->modifiers(), eraserTip);
        break;
    default:
        break;
    }
    e->accept();
}

void Canvas::wheelEvent(QWheelEvent *e)
{
    const double factor = std::pow(1.0015, e->angleDelta().y());
    zoomAround(e->position(), factor);
    e->accept();
}

void Canvas::keyPressEvent(QKeyEvent *e)
{
    if (e->key() == Qt::Key_Space) {
        m_spaceDown = true;
        setCursor(Qt::OpenHandCursor);
        e->accept();
        return;
    }
    if (e->key() == Qt::Key_Delete || e->key() == Qt::Key_Backspace) {
        deleteSelection();
        e->accept();
        return;
    }
    if (e->key() == Qt::Key_Escape) {
        cancelActive();
        clearSelection();
        update();
        e->accept();
        return;
    }
    QWidget::keyPressEvent(e);
}

void Canvas::keyReleaseEvent(QKeyEvent *e)
{
    if (e->key() == Qt::Key_Space) {
        m_spaceDown = false;
        updateCursor();
        e->accept();
        return;
    }
    QWidget::keyReleaseEvent(e);
}

// ---- pointer dispatch ------------------------------------------------------
void Canvas::handlePointer(Action a, const QPointF &widgetPos, double pressure,
                           Qt::KeyboardModifiers mods, bool eraserTip)
{
    if (!m_doc)
        return;
    const QPointF sp = widgetToScene(widgetPos);
    m_cursorWidget = widgetPos;

    const ToolId t = eraserTip ? ToolId::Eraser : m_settings.tool;

    // Laser is an ephemeral overlay: it ignores layer locks and never edits the model.
    if (t == ToolId::Laser) {
        m_laser.setSettings(m_settings.laser);
        if (a == Action::Press) {
            m_drawing = true;
            m_laser.add(widgetPos, m_clock.elapsed());
            if (!m_laserTimer->isActive())
                m_laserTimer->start(16);
            update();
        } else if (a == Action::Move && m_drawing) {
            m_laser.add(widgetPos, m_clock.elapsed());
            update();
        } else if (a == Action::Release) {
            m_drawing = false;
        }
        return;
    }

    Layer &ly = m_doc->current().active();
    if (ly.locked)
        return;

    switch (t) {
    case ToolId::Pen:
    case ToolId::Highlighter: {
        const bool hl = (t == ToolId::Highlighter);
        if (a == Action::Press) {
            m_drawing = true;
            m_activeStroke = std::make_unique<StrokeItem>();
            m_activeStroke->highlighter   = hl;
            m_activeStroke->color         = hl ? m_settings.hlColor : m_settings.penColor;
            m_activeStroke->baseWidth     = hl ? m_settings.hlWidth : m_settings.penWidth;
            m_activeStroke->opacity       = hl ? m_settings.hlOpacity : 1.0;
            m_activeStroke->pressureWidth = hl ? false : m_settings.penPressure;
            m_activeStroke->addPoint(StrokePoint(sp.x(), sp.y(), pressure));
            update();
        } else if (a == Action::Move && m_drawing && m_activeStroke) {
            m_activeStroke->addPoint(StrokePoint(sp.x(), sp.y(), pressure));
            update();
        } else if (a == Action::Release && m_drawing) {
            if (m_activeStroke && !m_activeStroke->isEmpty())
                commitAdd(std::move(m_activeStroke),
                          hl ? QStringLiteral("Highlight") : QStringLiteral("Draw"));
            m_activeStroke.reset();
            m_drawing = false;
            update();
        }
        break;
    }
    case ToolId::Eraser: {
        if (a == Action::Press) { m_erasing = true; m_eraseStash.clear(); eraseAt(sp); update(); }
        else if (a == Action::Move && m_erasing) { eraseAt(sp); update(); }
        else if (a == Action::Release && m_erasing) { finishErase(); m_erasing = false; update(); }
        break;
    }
    case ToolId::Line:
    case ToolId::Rectangle:
    case ToolId::Ellipse: {
        if (a == Action::Press) {
            m_activeShape = std::make_unique<ShapeItem>();
            m_activeShape->kind = (t == ToolId::Line) ? ShapeKind::Line
                                : (t == ToolId::Rectangle) ? ShapeKind::Rectangle
                                : ShapeKind::Ellipse;
            m_activeShape->color  = m_settings.shapeColor;
            m_activeShape->width  = m_settings.shapeWidth;
            m_activeShape->filled = m_settings.shapeFilled;
            m_activeShape->fill   = m_settings.shapeFill;
            m_activeShape->p1 = sp;
            m_activeShape->p2 = sp;
            m_drawing = true;
            update();
        } else if (a == Action::Move && m_drawing && m_activeShape) {
            m_activeShape->p2 = (mods & Qt::ShiftModifier)
                ? constrainShape(m_activeShape->p1, sp, m_activeShape->kind)
                : sp;
            update();
        } else if (a == Action::Release && m_drawing) {
            if (m_activeShape) {
                const QLineF diag(m_activeShape->p1, m_activeShape->p2);
                if (diag.length() >= 2.0)
                    commitAdd(std::move(m_activeShape), QStringLiteral("Shape"));
            }
            m_activeShape.reset();
            m_drawing = false;
            update();
        }
        break;
    }
    case ToolId::Text: {
        if (a == Action::Press)
            addTextAt(sp);
        break;
    }
    case ToolId::Select: {
        handleSelect(a, sp, mods);
        break;
    }
    case ToolId::Laser:
        break; // handled above
    }
}

// ---- selection -------------------------------------------------------------
void Canvas::handleSelect(Action a, const QPointF &sp, Qt::KeyboardModifiers mods)
{
    if (a == Action::Press) {
        Item *hit = topItemAt(sp);
        if (hit) {
            const bool already =
                std::find(m_selection.begin(), m_selection.end(), hit) != m_selection.end();
            if (mods & Qt::ShiftModifier) {
                if (already) removeFromSelection(hit);
                else addToSelection(hit);
            } else if (!already) {
                setSelectionSingle(hit);
            }
            m_movingSelection = true;
            m_moveStartScene = sp;
            m_moveAccum = QPointF(0, 0);
        } else {
            if (!(mods & Qt::ShiftModifier))
                clearSelection();
            m_rubber = true;
            m_rubberStartScene = sp;
            m_rubberRect = QRectF(sp, sp);
        }
        update();
    } else if (a == Action::Move) {
        if (m_movingSelection && !m_selection.empty()) {
            const QPointF d = sp - m_moveStartScene;
            const QPointF step = d - m_moveAccum;
            for (Item *it : m_selection)
                it->translate(step);
            m_moveAccum = d;
            update();
        } else if (m_rubber) {
            m_rubberRect = QRectF(m_rubberStartScene, sp).normalized();
            update();
        }
    } else {
        if (m_movingSelection) {
            m_movingSelection = false;
            if (!m_selection.empty() &&
                (qAbs(m_moveAccum.x()) > 0.01 || qAbs(m_moveAccum.y()) > 0.01)) {
                for (Item *it : m_selection)
                    it->translate(-m_moveAccum);
                std::vector<Item *> targets(m_selection.begin(), m_selection.end());
                m_doc->undoStack()->push(new TranslateItemsCommand(
                    m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
                    targets, m_moveAccum, QStringLiteral("Move")));
            }
            m_moveAccum = QPointF(0, 0);
        } else if (m_rubber) {
            m_rubber = false;
            selectInRect(m_rubberRect, (mods & Qt::ShiftModifier));
        }
        update();
    }
}

void Canvas::setSelectionSingle(Item *it)
{
    m_selection.clear();
    if (it) m_selection.push_back(it);
}

void Canvas::addToSelection(Item *it)
{
    if (it && std::find(m_selection.begin(), m_selection.end(), it) == m_selection.end())
        m_selection.push_back(it);
}

void Canvas::removeFromSelection(Item *it)
{
    m_selection.erase(std::remove(m_selection.begin(), m_selection.end(), it),
                      m_selection.end());
}

void Canvas::clearSelection()
{
    if (m_selection.empty())
        return;
    m_selection.clear();
    update();
}

void Canvas::selectAll()
{
    if (!m_doc)
        return;
    m_selection.clear();
    for (auto &it : m_doc->current().active().items)
        m_selection.push_back(it.get());
    update();
}

void Canvas::selectInRect(const QRectF &r, bool add)
{
    if (!m_doc)
        return;
    if (!add)
        m_selection.clear();
    for (auto &it : m_doc->current().active().items) {
        if (r.intersects(it->boundingRect()) &&
            std::find(m_selection.begin(), m_selection.end(), it.get()) == m_selection.end())
            m_selection.push_back(it.get());
    }
}

Item *Canvas::topItemAt(const QPointF &sp)
{
    if (!m_doc)
        return nullptr;
    Layer &ly = m_doc->current().active();
    const double r = 6.0 / qMax(0.0001, m_scale);
    for (int i = static_cast<int>(ly.items.size()) - 1; i >= 0; --i) {
        Item *it = ly.items[static_cast<std::size_t>(i)].get();
        if (hitTest(it, sp, r))
            return it;
    }
    return nullptr;
}

bool Canvas::hitTest(Item *it, const QPointF &sp, double radius) const
{
    const QRectF bb = it->boundingRect().adjusted(-radius, -radius, radius, radius);
    if (!bb.contains(sp))
        return false;

    if (it->type() == ItemType::Stroke) {
        const StrokeItem *s = static_cast<const StrokeItem *>(it);
        const double tol = radius + s->baseWidth * 0.5;
        if (s->points.size() == 1)
            return QLineF(sp, s->points.first().pos()).length() <= tol;
        for (int i = 1; i < s->points.size(); ++i)
            if (distToSegment(sp, s->points[i - 1].pos(), s->points[i].pos()) <= tol)
                return true;
        return false;
    }
    return true;
}

// ---- helpers ---------------------------------------------------------------
void Canvas::commitAdd(ItemPtr item, const QString &text)
{
    if (!m_doc || !item)
        return;
    m_doc->undoStack()->push(new AddItemCommand(
        m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
        std::move(item), text));
}

void Canvas::eraseAt(const QPointF &sp)
{
    if (!m_doc)
        return;
    Layer &ly = m_doc->current().active();
    const double r = m_settings.eraserRadius;
    for (std::size_t i = 0; i < ly.items.size();) {
        if (hitTest(ly.items[i].get(), sp, r)) {
            m_eraseStash.push_back({i, std::move(ly.items[i])});
            ly.items.erase(ly.items.begin() + static_cast<std::ptrdiff_t>(i));
        } else {
            ++i;
        }
    }
}

void Canvas::finishErase()
{
    if (!m_doc || m_eraseStash.empty())
        return;
    Layer &ly = m_doc->current().active();
    std::sort(m_eraseStash.begin(), m_eraseStash.end(),
              [](const EraseStash &a, const EraseStash &b) { return a.index < b.index; });

    std::vector<Item *> targets;
    for (auto &s : m_eraseStash) {
        Item *raw = s.item.get();
        targets.push_back(raw);
        const std::size_t idx = std::min(s.index, ly.items.size());
        ly.items.insert(ly.items.begin() + static_cast<std::ptrdiff_t>(idx),
                        std::move(s.item));
    }
    m_eraseStash.clear();

    m_doc->undoStack()->push(new RemoveItemsCommand(
        m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
        std::move(targets), QStringLiteral("Erase")));
}

void Canvas::addTextAt(const QPointF &sp)
{
    bool ok = false;
    const QString text = QInputDialog::getMultiLineText(
        this, tr("Add Text"), tr("Text:"), QString(), &ok);
    if (!ok || text.trimmed().isEmpty())
        return;
    auto t = std::make_unique<TextItem>();
    t->pos   = sp;
    t->text  = text;
    t->color = m_settings.textColor;
    t->font  = m_settings.textFont;
    commitAdd(std::move(t), QStringLiteral("Text"));
}

void Canvas::deleteSelection()
{
    if (!m_doc || m_selection.empty())
        return;
    std::vector<Item *> targets(m_selection.begin(), m_selection.end());
    m_selection.clear();
    m_doc->undoStack()->push(new RemoveItemsCommand(
        m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
        std::move(targets), QStringLiteral("Delete")));
    update();
}

void Canvas::cancelActive()
{
    m_activeStroke.reset();
    m_activeShape.reset();
    m_drawing = false;
    if (m_erasing && m_doc) {
        Layer &ly = m_doc->current().active();
        for (auto &s : m_eraseStash)
            ly.items.push_back(std::move(s.item));
    }
    m_eraseStash.clear();
    m_erasing = false;
    m_movingSelection = false;
    m_rubber = false;
}

void Canvas::updateCursor()
{
    switch (m_settings.tool) {
    case ToolId::Pen:
    case ToolId::Highlighter:
    case ToolId::Line:
    case ToolId::Rectangle:
    case ToolId::Ellipse:
    case ToolId::Laser:
        setCursor(Qt::CrossCursor);
        break;
    case ToolId::Eraser:
        setCursor(Qt::BlankCursor);
        break;
    case ToolId::Text:
        setCursor(Qt::IBeamCursor);
        break;
    case ToolId::Select:
        setCursor(Qt::ArrowCursor);
        break;
    }
}

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/ui/PreferencesDialog.h  (overwrite: adds laser controls)
# ---------------------------------------------------------------------------
cat > src/ui/PreferencesDialog.h <<'EOF'
#pragma once

#include <QDialog>
#include <QColor>

#include "canvas/Tools.h"

class QSpinBox;
class QDoubleSpinBox;
class QPushButton;
class QCheckBox;

namespace ib {

class PreferencesDialog : public QDialog {
    Q_OBJECT
public:
    PreferencesDialog(const ToolSettings &s, int autosaveSeconds,
                      QWidget *parent = nullptr);

    ToolSettings toolSettings() const { return m_settings; }
    int autosaveSeconds() const;

private slots:
    void pickPenColor();
    void pickLaserCore();
    void pickLaserGlow();
    void applyAndAccept();

private:
    ToolSettings m_settings;

    QColor m_penColor;
    QColor m_laserCore;
    QColor m_laserGlow;

    QSpinBox       *m_penWidth      = nullptr;
    QPushButton    *m_penColorBtn   = nullptr;
    QDoubleSpinBox *m_hlWidth       = nullptr;
    QDoubleSpinBox *m_hlOpacity     = nullptr;
    QDoubleSpinBox *m_eraserRadius  = nullptr;
    QSpinBox       *m_textSize      = nullptr;
    QSpinBox       *m_autosave      = nullptr;

    QPushButton    *m_laserCoreBtn  = nullptr;
    QPushButton    *m_laserGlowBtn  = nullptr;
    QDoubleSpinBox *m_laserWidth    = nullptr;
    QDoubleSpinBox *m_laserGlowRad  = nullptr;
    QDoubleSpinBox *m_laserInten    = nullptr;
    QSpinBox       *m_laserVanish   = nullptr;
    QSpinBox       *m_laserFade     = nullptr;
    QCheckBox      *m_laserGlowOn   = nullptr;
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/ui/PreferencesDialog.cpp  (overwrite: adds laser section)
# ---------------------------------------------------------------------------
cat > src/ui/PreferencesDialog.cpp <<'EOF'
#include "ui/PreferencesDialog.h"

#include <QFormLayout>
#include <QVBoxLayout>
#include <QGroupBox>
#include <QDialogButtonBox>
#include <QSpinBox>
#include <QDoubleSpinBox>
#include <QPushButton>
#include <QCheckBox>
#include <QColorDialog>

namespace ib {

static void styleColorButton(QPushButton *b, const QColor &c)
{
    b->setText(c.name(QColor::HexRgb));
    b->setStyleSheet(QString("background-color:%1; color:%2; padding:4px;")
                         .arg(c.name(),
                              c.lightness() > 128 ? "#000000" : "#ffffff"));
}

PreferencesDialog::PreferencesDialog(const ToolSettings &s, int autosaveSeconds,
                                     QWidget *parent)
    : QDialog(parent)
    , m_settings(s)
    , m_penColor(s.penColor)
    , m_laserCore(s.laser.coreColor)
    , m_laserGlow(s.laser.glowColor)
{
    setWindowTitle(tr("Preferences"));
    setModal(true);

    // ---- Tools group -------------------------------------------------------
    auto *toolsBox = new QGroupBox(tr("Tools"), this);
    auto *form = new QFormLayout(toolsBox);

    m_penWidth = new QSpinBox(this);
    m_penWidth->setRange(1, 64);
    m_penWidth->setValue(qRound(m_settings.penWidth));
    m_penWidth->setSuffix(tr(" px"));
    form->addRow(tr("Pen width:"), m_penWidth);

    m_penColorBtn = new QPushButton(this);
    connect(m_penColorBtn, &QPushButton::clicked, this, &PreferencesDialog::pickPenColor);
    styleColorButton(m_penColorBtn, m_penColor);
    form->addRow(tr("Pen color:"), m_penColorBtn);

    m_hlWidth = new QDoubleSpinBox(this);
    m_hlWidth->setRange(1.0, 120.0);
    m_hlWidth->setValue(m_settings.hlWidth);
    m_hlWidth->setSuffix(tr(" px"));
    form->addRow(tr("Highlighter width:"), m_hlWidth);

    m_hlOpacity = new QDoubleSpinBox(this);
    m_hlOpacity->setRange(0.05, 1.0);
    m_hlOpacity->setSingleStep(0.05);
    m_hlOpacity->setValue(m_settings.hlOpacity);
    form->addRow(tr("Highlighter opacity:"), m_hlOpacity);

    m_eraserRadius = new QDoubleSpinBox(this);
    m_eraserRadius->setRange(2.0, 200.0);
    m_eraserRadius->setValue(m_settings.eraserRadius);
    m_eraserRadius->setSuffix(tr(" px"));
    form->addRow(tr("Eraser radius:"), m_eraserRadius);

    m_textSize = new QSpinBox(this);
    m_textSize->setRange(6, 200);
    m_textSize->setValue(m_settings.textFont.pointSize() > 0
                             ? m_settings.textFont.pointSize() : 18);
    m_textSize->setSuffix(tr(" pt"));
    form->addRow(tr("Text size:"), m_textSize);

    // ---- Laser group -------------------------------------------------------
    auto *laserBox = new QGroupBox(tr("Laser pointer"), this);
    auto *lf = new QFormLayout(laserBox);

    m_laserCoreBtn = new QPushButton(this);
    connect(m_laserCoreBtn, &QPushButton::clicked, this, &PreferencesDialog::pickLaserCore);
    styleColorButton(m_laserCoreBtn, m_laserCore);
    lf->addRow(tr("Core color:"), m_laserCoreBtn);

    m_laserGlowBtn = new QPushButton(this);
    connect(m_laserGlowBtn, &QPushButton::clicked, this, &PreferencesDialog::pickLaserGlow);
    styleColorButton(m_laserGlowBtn, m_laserGlow);
    lf->addRow(tr("Glow color:"), m_laserGlowBtn);

    m_laserWidth = new QDoubleSpinBox(this);
    m_laserWidth->setRange(1.0, 60.0);
    m_laserWidth->setValue(m_settings.laser.width);
    m_laserWidth->setSuffix(tr(" px"));
    lf->addRow(tr("Core width:"), m_laserWidth);

    m_laserGlowRad = new QDoubleSpinBox(this);
    m_laserGlowRad->setRange(2.0, 200.0);
    m_laserGlowRad->setValue(m_settings.laser.glowRadius);
    m_laserGlowRad->setSuffix(tr(" px"));
    lf->addRow(tr("Glow radius:"), m_laserGlowRad);

    m_laserInten = new QDoubleSpinBox(this);
    m_laserInten->setRange(0.1, 1.0);
    m_laserInten->setSingleStep(0.05);
    m_laserInten->setValue(m_settings.laser.intensity);
    lf->addRow(tr("Intensity:"), m_laserInten);

    m_laserVanish = new QSpinBox(this);
    m_laserVanish->setRange(0, 5000);
    m_laserVanish->setValue(m_settings.laser.vanishDelayMs);
    m_laserVanish->setSuffix(tr(" ms"));
    lf->addRow(tr("Vanish delay:"), m_laserVanish);

    m_laserFade = new QSpinBox(this);
    m_laserFade->setRange(0, 5000);
    m_laserFade->setValue(m_settings.laser.fadeDurationMs);
    m_laserFade->setSuffix(tr(" ms"));
    lf->addRow(tr("Fade-out duration:"), m_laserFade);

    m_laserGlowOn = new QCheckBox(tr("Enable glow"), this);
    m_laserGlowOn->setChecked(m_settings.laser.glowEnabled);
    lf->addRow(QString(), m_laserGlowOn);

    // ---- App group ---------------------------------------------------------
    auto *appBox = new QGroupBox(tr("Application"), this);
    auto *af = new QFormLayout(appBox);
    m_autosave = new QSpinBox(this);
    m_autosave->setRange(0, 3600);
    m_autosave->setValue(autosaveSeconds);
    m_autosave->setSuffix(tr(" s (0 = off)"));
    af->addRow(tr("Autosave interval:"), m_autosave);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel,
                                         this);
    connect(buttons, &QDialogButtonBox::accepted, this, &PreferencesDialog::applyAndAccept);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);

    auto *root = new QVBoxLayout(this);
    root->addWidget(toolsBox);
    root->addWidget(laserBox);
    root->addWidget(appBox);
    root->addWidget(buttons);
}

void PreferencesDialog::pickPenColor()
{
    const QColor c = QColorDialog::getColor(m_penColor, this, tr("Pen Color"));
    if (c.isValid()) { m_penColor = c; styleColorButton(m_penColorBtn, c); }
}

void PreferencesDialog::pickLaserCore()
{
    const QColor c = QColorDialog::getColor(m_laserCore, this, tr("Laser Core Color"));
    if (c.isValid()) { m_laserCore = c; styleColorButton(m_laserCoreBtn, c); }
}

void PreferencesDialog::pickLaserGlow()
{
    const QColor c = QColorDialog::getColor(m_laserGlow, this, tr("Laser Glow Color"));
    if (c.isValid()) { m_laserGlow = c; styleColorButton(m_laserGlowBtn, c); }
}

int PreferencesDialog::autosaveSeconds() const
{
    return m_autosave->value();
}

void PreferencesDialog::applyAndAccept()
{
    m_settings.penWidth     = m_penWidth->value();
    m_settings.penColor     = m_penColor;
    m_settings.hlWidth      = m_hlWidth->value();
    m_settings.hlOpacity    = m_hlOpacity->value();
    m_settings.eraserRadius = m_eraserRadius->value();

    QFont f = m_settings.textFont;
    f.setPointSize(m_textSize->value());
    m_settings.textFont = f;

    m_settings.laser.coreColor     = m_laserCore;
    m_settings.laser.glowColor     = m_laserGlow;
    m_settings.laser.width         = m_laserWidth->value();
    m_settings.laser.glowRadius    = m_laserGlowRad->value();
    m_settings.laser.intensity     = m_laserInten->value();
    m_settings.laser.vanishDelayMs = m_laserVanish->value();
    m_settings.laser.fadeDurationMs = m_laserFade->value();
    m_settings.laser.glowEnabled   = m_laserGlowOn->isChecked();

    accept();
}

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  Wire the Laser tool into MainWindow (targeted, anchored edits).
# ---------------------------------------------------------------------------
# 1) Add the Laser tool button + shortcut (K) to the tool table.
sed -i 's|        { ToolId::Text,        "Text",        "T" },|        { ToolId::Text,        "Text",        "T" },\n        { ToolId::Laser,       "Laser",       "K" },|' src/ui/MainWindow.cpp

# 2) Route the toolbar color swatches to the laser core color when active.
sed -i 's|    default:                  s.penColor = c; break;|    case ToolId::Laser:       s.laser.coreColor = c; break;\n    default:                  s.penColor = c; break;|' src/ui/MainWindow.cpp

# 3) Route the toolbar width spinbox to the laser core width when active.
sed -i 's|    default:                  s.penWidth = w; break;|    case ToolId::Laser:       s.laser.width = w; break;\n    default:                  s.penWidth = w; break;|' src/ui/MainWindow.cpp

# 4) Report the laser width back to the toolbar spinbox when the tool is picked.
sed -i 's|    default:                  return s.penWidth;|    case ToolId::Laser:       return s.laser.width;\n    default:                  return s.penWidth;|' src/ui/MainWindow.cpp

log "PART 8 complete: laser pointer tool added (core + glow + fade, fully customizable)"


# ---------------------------------------------------------------------------
#  PART 9 : Laser upgrades — live hover pointer + persistent (no-vanish) mode
#  Overwrites Laser.h, Canvas.h, Canvas.cpp, PreferencesDialog.{h,cpp}.
#  No model / serialization / MainWindow changes.
# ---------------------------------------------------------------------------
log "PART 9: laser hover pointer + persistent mode"

# ---------------------------------------------------------------------------
#  src/canvas/Laser.h  (overwrite: adds live hover dot + persist option)
# ---------------------------------------------------------------------------
cat > src/canvas/Laser.h <<'EOF'
#pragma once

#include <QColor>
#include <QPointF>
#include <QVector>
#include <QPainter>
#include <QRadialGradient>

namespace ib {

// Timing in milliseconds; sizes in screen pixels.
struct LaserSettings {
    QColor coreColor    = QColor(255, 255, 255); // hot white core
    QColor glowColor    = QColor(255, 45, 40);   // warm outer glow (Apple-like)
    double width        = 7.0;    // core diameter
    double glowRadius   = 26.0;   // glow radius around the core
    double intensity    = 1.0;    // overall opacity multiplier (0..1)
    int    vanishDelayMs  = 200;  // time a sample stays fully bright
    int    fadeDurationMs = 700;  // time to fade from full to gone
    bool   glowEnabled  = true;
    bool   persist      = false;  // when true, the trail never vanishes
};

struct LaserPoint {
    QPointF pos;      // widget/device coordinates
    qint64  bornMs = 0;
};

class LaserTrail {
public:
    void setSettings(const LaserSettings &s) { m_s = s; }
    const LaserSettings &settings() const { return m_s; }

    // The live pointer dot that follows the pen (even while only hovering).
    void setLive(bool on, const QPointF &pos) { m_liveOn = on; m_livePos = pos; }
    bool liveOn() const { return m_liveOn; }

    void add(const QPointF &widgetPos, qint64 nowMs)
    {
        m_points.push_back({ widgetPos, nowMs });
        if (m_points.size() > 8192)
            m_points.remove(0, m_points.size() - 8192);
    }

    void clear() { m_points.clear(); }
    bool hasTrail() const { return !m_points.isEmpty(); }
    bool isEmpty() const { return m_points.isEmpty() && !m_liveOn; }

    // Drop faded samples. In persist mode nothing ages out.
    bool prune(qint64 nowMs)
    {
        if (m_s.persist)
            return !m_points.isEmpty();
        const qint64 life =
            static_cast<qint64>(m_s.vanishDelayMs) + static_cast<qint64>(m_s.fadeDurationMs);
        int i = 0;
        while (i < m_points.size() && (nowMs - m_points[i].bornMs) > life)
            ++i;
        if (i > 0)
            m_points.remove(0, i);
        return !m_points.isEmpty();
    }

    double alphaFor(qint64 ageMs) const
    {
        if (m_s.persist)
            return 1.0;
        if (ageMs <= m_s.vanishDelayMs)
            return 1.0;
        if (m_s.fadeDurationMs <= 0)
            return 0.0;
        const double f =
            1.0 - static_cast<double>(ageMs - m_s.vanishDelayMs) /
                      static_cast<double>(m_s.fadeDurationMs);
        return f < 0.0 ? 0.0 : (f > 1.0 ? 1.0 : f);
    }

    // Painted in DEVICE (widget) coordinates.
    void paint(QPainter &p, qint64 nowMs) const
    {
        if (m_points.isEmpty() && !m_liveOn)
            return;

        p.save();
        p.setRenderHint(QPainter::Antialiasing, true);
        p.setPen(Qt::NoPen);

        for (const auto &lp : m_points)
            drawDot(p, lp.pos, alphaFor(nowMs - lp.bornMs) * m_s.intensity);

        if (m_liveOn)
            drawDot(p, m_livePos, m_s.intensity);

        p.restore();
    }

private:
    void drawDot(QPainter &p, const QPointF &pos, double a) const
    {
        if (a <= 0.01)
            return;

        const double coreR = qMax(0.5, m_s.width * 0.5);
        const double glowR = qMax(coreR, m_s.glowRadius);

        if (m_s.glowEnabled) {
            QRadialGradient g(pos, glowR);
            QColor c0 = m_s.glowColor; c0.setAlphaF(0.55 * a);
            QColor c1 = m_s.glowColor; c1.setAlphaF(0.0);
            g.setColorAt(0.0, c0);
            g.setColorAt(1.0, c1);
            p.setBrush(g);
            p.drawEllipse(pos, glowR, glowR);
        }

        const double r = coreR * 1.6;
        QRadialGradient g(pos, r);
        QColor cc = m_s.coreColor; cc.setAlphaF(a);
        QColor edge = m_s.glowColor; edge.setAlphaF(0.0);
        g.setColorAt(0.0, cc);
        g.setColorAt(0.6, cc);
        g.setColorAt(1.0, edge);
        p.setBrush(g);
        p.drawEllipse(pos, r, r);
    }

    LaserSettings       m_s;
    QVector<LaserPoint> m_points;
    bool                m_liveOn = false;
    QPointF             m_livePos;
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/canvas/Canvas.h  (overwrite: adds leaveEvent + eventFilter for hover)
# ---------------------------------------------------------------------------
cat > src/canvas/Canvas.h <<'EOF'
#pragma once

#include <QWidget>
#include <QPointF>
#include <QElapsedTimer>
#include <memory>
#include <vector>

#include "model/Document.h"
#include "model/StrokeItem.h"
#include "model/ShapeItem.h"
#include "canvas/Tools.h"

class QPaintEvent;
class QMouseEvent;
class QTabletEvent;
class QWheelEvent;
class QKeyEvent;
class QTimer;

namespace ib {

class Canvas : public QWidget {
    Q_OBJECT
public:
    explicit Canvas(QWidget *parent = nullptr);

    void setDocument(Document *doc);
    Document *document() const { return m_doc; }

    ToolSettings &settings() { return m_settings; }
    const ToolSettings &settings() const { return m_settings; }

    void setTool(ToolId t);
    ToolId tool() const { return m_settings.tool; }

    bool hasSelection() const { return !m_selection.empty(); }
    double zoomPercent() const { return m_scale * 100.0; }

public slots:
    void zoomIn();
    void zoomOut();
    void resetView();
    void zoomToFit();
    void deleteSelection();
    void selectAll();
    void clearSelection();
    void clearLaser();
    void refresh() { update(); }

signals:
    void viewChanged();
    void toolChanged(ib::ToolId tool);
    void cursorMoved(QPointF scenePos);

protected:
    void paintEvent(QPaintEvent *) override;
    void mousePressEvent(QMouseEvent *e) override;
    void mouseMoveEvent(QMouseEvent *e) override;
    void mouseReleaseEvent(QMouseEvent *e) override;
    void tabletEvent(QTabletEvent *e) override;
    void wheelEvent(QWheelEvent *e) override;
    void keyPressEvent(QKeyEvent *e) override;
    void keyReleaseEvent(QKeyEvent *e) override;
    void leaveEvent(QEvent *e) override;
    bool eventFilter(QObject *obj, QEvent *ev) override;

private:
    enum class Action { Press, Move, Release };

    struct EraseStash {
        std::size_t index;
        ItemPtr     item;
    };

    QPointF widgetToScene(const QPointF &p) const { return (p - m_translate) / m_scale; }
    QPointF sceneToWidget(const QPointF &s) const { return s * m_scale + m_translate; }

    void handlePointer(Action a, const QPointF &widgetPos, double pressure,
                       Qt::KeyboardModifiers mods, bool eraserTip);
    void handleSelect(Action a, const QPointF &sp, Qt::KeyboardModifiers mods);

    void commitAdd(ItemPtr item, const QString &text);
    void eraseAt(const QPointF &sp);
    void finishErase();
    void addTextAt(const QPointF &sp);
    void cancelActive();
    void zoomAround(const QPointF &widgetPos, double factor);
    void updateCursor();

    void drawBackground(QPainter &p, const Page &pg, const QRectF &area);
    void drawSelection(QPainter &p);

    bool hitTest(Item *it, const QPointF &sp, double radius) const;
    Item *topItemAt(const QPointF &sp);
    void selectInRect(const QRectF &r, bool add);
    void setSelectionSingle(Item *it);
    void addToSelection(Item *it);
    void removeFromSelection(Item *it);

    Document    *m_doc = nullptr;
    ToolSettings m_settings;

    double  m_scale = 1.0;
    QPointF m_translate;

    bool   m_panning = false;
    bool   m_spaceDown = false;
    QPoint m_lastPanPos;

    std::unique_ptr<StrokeItem> m_activeStroke;
    std::unique_ptr<ShapeItem>  m_activeShape;
    bool m_drawing = false;

    bool m_erasing = false;
    std::vector<EraseStash> m_eraseStash;

    std::vector<Item *> m_selection;
    bool    m_movingSelection = false;
    QPointF m_moveStartScene;
    QPointF m_moveAccum;
    bool    m_rubber = false;
    QPointF m_rubberStartScene;
    QRectF  m_rubberRect;

    QPointF m_cursorWidget;

    // Laser pointer
    LaserTrail    m_laser;
    QTimer       *m_laserTimer = nullptr;
    QElapsedTimer m_clock;
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/canvas/Canvas.cpp  (overwrite: hover live dot + persistent trail)
# ---------------------------------------------------------------------------
cat > src/canvas/Canvas.cpp <<'EOF'
#include "canvas/Canvas.h"

#include "core/Commands.h"
#include "model/TextItem.h"
#include "model/ImageItem.h"

#include <QApplication>
#include <QPainter>
#include <QPen>
#include <QMouseEvent>
#include <QTabletEvent>
#include <QWheelEvent>
#include <QKeyEvent>
#include <QPointingDevice>
#include <QInputDialog>
#include <QUndoStack>
#include <QTimer>
#include <QLineF>
#include <algorithm>
#include <cmath>

namespace ib {

static const double kPi = 3.14159265358979323846;

static double distToSegment(const QPointF &p, const QPointF &a, const QPointF &b)
{
    const QPointF ab = b - a;
    const double len2 = ab.x() * ab.x() + ab.y() * ab.y();
    if (len2 <= 1e-9)
        return std::hypot(p.x() - a.x(), p.y() - a.y());
    double t = ((p.x() - a.x()) * ab.x() + (p.y() - a.y()) * ab.y()) / len2;
    t = std::max(0.0, std::min(1.0, t));
    const QPointF proj(a.x() + t * ab.x(), a.y() + t * ab.y());
    return std::hypot(p.x() - proj.x(), p.y() - proj.y());
}

static QPointF constrainShape(const QPointF &a, const QPointF &b, ShapeKind kind)
{
    const QPointF d = b - a;
    if (kind == ShapeKind::Line) {
        double ang = std::atan2(d.y(), d.x());
        const double step = kPi / 4.0;
        ang = std::round(ang / step) * step;
        const double len = std::hypot(d.x(), d.y());
        return a + QPointF(std::cos(ang) * len, std::sin(ang) * len);
    }
    const double s = std::max(std::abs(d.x()), std::abs(d.y()));
    return a + QPointF(d.x() < 0 ? -s : s, d.y() < 0 ? -s : s);
}

Canvas::Canvas(QWidget *parent)
    : QWidget(parent)
{
    setFocusPolicy(Qt::StrongFocus);
    setMouseTracking(true);
    setAttribute(Qt::WA_TabletTracking, true);
    setAutoFillBackground(false);
    m_translate = QPointF(40, 40);

    m_clock.start();
    m_laserTimer = new QTimer(this);
    connect(m_laserTimer, &QTimer::timeout, this, [this]() {
        if (m_laser.prune(m_clock.elapsed())) {
            update();
        } else {
            m_laserTimer->stop();
            update();
        }
    });

    // Proximity leave events are delivered to the application object, not the
    // widget, so watch them via an application-wide event filter.
    if (qApp)
        qApp->installEventFilter(this);

    updateCursor();
}

void Canvas::setDocument(Document *doc)
{
    if (m_doc == doc)
        return;
    if (m_doc) {
        m_doc->disconnect(this);
        if (m_doc->undoStack())
            m_doc->undoStack()->disconnect(this);
    }
    m_doc = doc;
    cancelActive();
    m_selection.clear();

    if (m_doc) {
        connect(m_doc, &Document::currentPageChanged, this, [this](int) {
            cancelActive(); m_selection.clear(); update();
        });
        connect(m_doc, &Document::pagesChanged, this, [this]() {
            cancelActive(); m_selection.clear(); update();
        });
        connect(m_doc, &Document::contentChanged, this, [this]() { update(); });
        if (m_doc->undoStack()) {
            connect(m_doc->undoStack(), &QUndoStack::indexChanged, this, [this](int) {
                m_selection.clear(); cancelActive(); update();
            });
        }
    }
    update();
}

void Canvas::setTool(ToolId t)
{
    cancelActive();
    if (t != ToolId::Laser)
        m_laser.setLive(false, QPointF());
    m_settings.tool = t;
    updateCursor();
    emit toolChanged(t);
    update();
}

void Canvas::clearLaser()
{
    m_laser.clear();
    update();
}

// ---- view ------------------------------------------------------------------
void Canvas::zoomAround(const QPointF &widgetPos, double factor)
{
    const QPointF before = widgetToScene(widgetPos);
    m_scale = qBound(0.05, m_scale * factor, 40.0);
    m_translate = widgetPos - before * m_scale;
    update();
    emit viewChanged();
}

void Canvas::zoomIn()  { zoomAround(QPointF(width() / 2.0, height() / 2.0), 1.2); }
void Canvas::zoomOut() { zoomAround(QPointF(width() / 2.0, height() / 2.0), 1.0 / 1.2); }

void Canvas::resetView()
{
    m_scale = 1.0;
    m_translate = QPointF(40, 40);
    update();
    emit viewChanged();
}

void Canvas::zoomToFit()
{
    if (!m_doc) { update(); return; }
    QRectF b = m_doc->current().contentBounds();
    if (b.isNull()) { resetView(); return; }
    b.adjust(-40, -40, 40, 40);
    const double sx = width()  / b.width();
    const double sy = height() / b.height();
    m_scale = qBound(0.05, qMin(sx, sy), 40.0);
    m_translate = QPointF(width() / 2.0, height() / 2.0) - b.center() * m_scale;
    update();
    emit viewChanged();
}

// ---- painting --------------------------------------------------------------
void Canvas::drawBackground(QPainter &p, const Page &pg, const QRectF &area)
{
    if (pg.background == BackgroundKind::Blank)
        return;
    const double s = qMax(4.0, pg.gridSpacing);
    QPen pen(pg.gridColor);
    pen.setCosmetic(true);
    pen.setWidth(1);
    p.setPen(pen);

    const double startX = std::floor(area.left() / s) * s;
    const double startY = std::floor(area.top() / s) * s;

    if (pg.background == BackgroundKind::Grid) {
        for (double x = startX; x <= area.right(); x += s)
            p.drawLine(QPointF(x, area.top()), QPointF(x, area.bottom()));
        for (double y = startY; y <= area.bottom(); y += s)
            p.drawLine(QPointF(area.left(), y), QPointF(area.right(), y));
    } else if (pg.background == BackgroundKind::Lines) {
        for (double y = startY; y <= area.bottom(); y += s)
            p.drawLine(QPointF(area.left(), y), QPointF(area.right(), y));
    } else {
        p.setPen(Qt::NoPen);
        p.setBrush(pg.gridColor);
        for (double x = startX; x <= area.right(); x += s)
            for (double y = startY; y <= area.bottom(); y += s)
                p.drawEllipse(QPointF(x, y), 1.3, 1.3);
    }
}

void Canvas::drawSelection(QPainter &p)
{
    if (m_selection.empty())
        return;
    QPen pen(QColor(60, 120, 220));
    pen.setCosmetic(true);
    pen.setStyle(Qt::DashLine);
    pen.setWidth(1);
    p.setPen(pen);
    p.setBrush(Qt::NoBrush);
    for (Item *it : m_selection)
        p.drawRect(it->boundingRect());
}

void Canvas::paintEvent(QPaintEvent *)
{
    QPainter p(this);
    p.fillRect(rect(), QColor(90, 93, 99));
    if (!m_doc) {
        if (!m_laser.isEmpty())
            m_laser.paint(p, m_clock.elapsed());
        return;
    }

    p.save();
    p.translate(m_translate);
    p.scale(m_scale, m_scale);

    const QRectF sceneRect =
        QRectF(widgetToScene(QPointF(0, 0)),
               widgetToScene(QPointF(width(), height()))).normalized();

    Page &pg = m_doc->current();
    p.fillRect(sceneRect, pg.bgColor);
    drawBackground(p, pg, sceneRect);

    p.setRenderHint(QPainter::Antialiasing, true);
    p.setRenderHint(QPainter::TextAntialiasing, true);

    for (const auto &ly : pg.layers) {
        if (!ly.visible)
            continue;
        p.save();
        if (ly.opacity < 1.0)
            p.setOpacity(ly.opacity);
        for (const auto &it : ly.items)
            it->paint(p);
        p.restore();
    }

    if (m_activeStroke) m_activeStroke->paint(p);
    if (m_activeShape)  m_activeShape->paint(p);

    drawSelection(p);

    if (m_rubber) {
        QPen pen(QColor(60, 120, 220));
        pen.setCosmetic(true);
        pen.setStyle(Qt::DashLine);
        p.setPen(pen);
        p.setBrush(QColor(60, 120, 220, 40));
        p.drawRect(m_rubberRect);
    }

    p.restore();

    if (m_settings.tool == ToolId::Eraser && underMouse()) {
        const double r = m_settings.eraserRadius * m_scale;
        QPen pen(QColor(70, 70, 70));
        pen.setStyle(Qt::DashLine);
        p.setPen(pen);
        p.setBrush(Qt::NoBrush);
        p.drawEllipse(m_cursorWidget, r, r);
    }

    // Laser overlay (device coordinates, on top of everything).
    if (!m_laser.isEmpty())
        m_laser.paint(p, m_clock.elapsed());
}

// ---- input -----------------------------------------------------------------
void Canvas::mousePressEvent(QMouseEvent *e)
{
    m_cursorWidget = e->position();
    if (e->button() == Qt::MiddleButton ||
        (m_spaceDown && e->button() == Qt::LeftButton)) {
        m_panning = true;
        m_lastPanPos = e->position().toPoint();
        setCursor(Qt::ClosedHandCursor);
        return;
    }
    if (e->button() == Qt::LeftButton)
        handlePointer(Action::Press, e->position(), 1.0, e->modifiers(), false);
}

void Canvas::mouseMoveEvent(QMouseEvent *e)
{
    m_cursorWidget = e->position();
    if (m_panning) {
        const QPoint d = e->position().toPoint() - m_lastPanPos;
        m_lastPanPos = e->position().toPoint();
        m_translate += QPointF(d);
        update();
        emit viewChanged();
        return;
    }
    handlePointer(Action::Move, e->position(), 1.0, e->modifiers(), false);
    if (m_settings.tool == ToolId::Eraser)
        update();
    emit cursorMoved(widgetToScene(e->position()));
}

void Canvas::mouseReleaseEvent(QMouseEvent *e)
{
    m_cursorWidget = e->position();
    if (m_panning &&
        (e->button() == Qt::MiddleButton || e->button() == Qt::LeftButton)) {
        m_panning = false;
        updateCursor();
        return;
    }
    if (e->button() == Qt::LeftButton)
        handlePointer(Action::Release, e->position(), 1.0, e->modifiers(), false);
}

void Canvas::tabletEvent(QTabletEvent *e)
{
    const bool eraserTip =
        e->pointerType() == QPointingDevice::PointerType::Eraser;
    double pr = e->pressure();
    if (pr <= 0.0)
        pr = 1.0;
    m_cursorWidget = e->position();

    switch (e->type()) {
    case QEvent::TabletPress:
        handlePointer(Action::Press, e->position(), pr, e->modifiers(), eraserTip);
        break;
    case QEvent::TabletMove:
        // Fires during hover (in proximity) as well as while pressed.
        handlePointer(Action::Move, e->position(), pr, e->modifiers(), eraserTip);
        emit cursorMoved(widgetToScene(e->position()));
        if (m_settings.tool == ToolId::Eraser)
            update();
        break;
    case QEvent::TabletRelease:
        handlePointer(Action::Release, e->position(), pr, e->modifiers(), eraserTip);
        break;
    default:
        break;
    }
    e->accept();
}

void Canvas::wheelEvent(QWheelEvent *e)
{
    const double factor = std::pow(1.0015, e->angleDelta().y());
    zoomAround(e->position(), factor);
    e->accept();
}

void Canvas::keyPressEvent(QKeyEvent *e)
{
    if (e->key() == Qt::Key_Space) {
        m_spaceDown = true;
        setCursor(Qt::OpenHandCursor);
        e->accept();
        return;
    }
    if (e->key() == Qt::Key_Delete || e->key() == Qt::Key_Backspace) {
        deleteSelection();
        e->accept();
        return;
    }
    if (e->key() == Qt::Key_Escape) {
        cancelActive();
        clearSelection();
        m_laser.clear();          // clear a persistent laser trail
        update();
        e->accept();
        return;
    }
    QWidget::keyPressEvent(e);
}

void Canvas::keyReleaseEvent(QKeyEvent *e)
{
    if (e->key() == Qt::Key_Space) {
        m_spaceDown = false;
        updateCursor();
        e->accept();
        return;
    }
    QWidget::keyReleaseEvent(e);
}

void Canvas::leaveEvent(QEvent *e)
{
    if (m_laser.liveOn()) {
        m_laser.setLive(false, QPointF());
        update();
    }
    QWidget::leaveEvent(e);
}

bool Canvas::eventFilter(QObject *obj, QEvent *ev)
{
    if (ev->type() == QEvent::TabletLeaveProximity && m_laser.liveOn()) {
        m_laser.setLive(false, QPointF());
        update();
    }
    return QWidget::eventFilter(obj, ev);
}

// ---- pointer dispatch ------------------------------------------------------
void Canvas::handlePointer(Action a, const QPointF &widgetPos, double pressure,
                           Qt::KeyboardModifiers mods, bool eraserTip)
{
    if (!m_doc)
        return;
    const QPointF sp = widgetToScene(widgetPos);
    m_cursorWidget = widgetPos;

    const ToolId t = eraserTip ? ToolId::Eraser : m_settings.tool;

    // Laser: an ephemeral overlay. The dot follows the pen even while hovering
    // (not touching); pressing draws a trail. Never edits the model or locks.
    if (t == ToolId::Laser) {
        m_laser.setSettings(m_settings.laser);
        m_laser.setLive(true, widgetPos);
        if (a == Action::Press) {
            m_drawing = true;
            m_laser.add(widgetPos, m_clock.elapsed());
            if (!m_settings.laser.persist && !m_laserTimer->isActive())
                m_laserTimer->start(16);
        } else if (a == Action::Move && m_drawing) {
            m_laser.add(widgetPos, m_clock.elapsed());
            if (!m_settings.laser.persist && !m_laserTimer->isActive())
                m_laserTimer->start(16);
        } else if (a == Action::Release) {
            m_drawing = false;
        }
        update();
        return;
    }

    Layer &ly = m_doc->current().active();
    if (ly.locked)
        return;

    switch (t) {
    case ToolId::Pen:
    case ToolId::Highlighter: {
        const bool hl = (t == ToolId::Highlighter);
        if (a == Action::Press) {
            m_drawing = true;
            m_activeStroke = std::make_unique<StrokeItem>();
            m_activeStroke->highlighter   = hl;
            m_activeStroke->color         = hl ? m_settings.hlColor : m_settings.penColor;
            m_activeStroke->baseWidth     = hl ? m_settings.hlWidth : m_settings.penWidth;
            m_activeStroke->opacity       = hl ? m_settings.hlOpacity : 1.0;
            m_activeStroke->pressureWidth = hl ? false : m_settings.penPressure;
            m_activeStroke->addPoint(StrokePoint(sp.x(), sp.y(), pressure));
            update();
        } else if (a == Action::Move && m_drawing && m_activeStroke) {
            m_activeStroke->addPoint(StrokePoint(sp.x(), sp.y(), pressure));
            update();
        } else if (a == Action::Release && m_drawing) {
            if (m_activeStroke && !m_activeStroke->isEmpty())
                commitAdd(std::move(m_activeStroke),
                          hl ? QStringLiteral("Highlight") : QStringLiteral("Draw"));
            m_activeStroke.reset();
            m_drawing = false;
            update();
        }
        break;
    }
    case ToolId::Eraser: {
        if (a == Action::Press) { m_erasing = true; m_eraseStash.clear(); eraseAt(sp); update(); }
        else if (a == Action::Move && m_erasing) { eraseAt(sp); update(); }
        else if (a == Action::Release && m_erasing) { finishErase(); m_erasing = false; update(); }
        break;
    }
    case ToolId::Line:
    case ToolId::Rectangle:
    case ToolId::Ellipse: {
        if (a == Action::Press) {
            m_activeShape = std::make_unique<ShapeItem>();
            m_activeShape->kind = (t == ToolId::Line) ? ShapeKind::Line
                                : (t == ToolId::Rectangle) ? ShapeKind::Rectangle
                                : ShapeKind::Ellipse;
            m_activeShape->color  = m_settings.shapeColor;
            m_activeShape->width  = m_settings.shapeWidth;
            m_activeShape->filled = m_settings.shapeFilled;
            m_activeShape->fill   = m_settings.shapeFill;
            m_activeShape->p1 = sp;
            m_activeShape->p2 = sp;
            m_drawing = true;
            update();
        } else if (a == Action::Move && m_drawing && m_activeShape) {
            m_activeShape->p2 = (mods & Qt::ShiftModifier)
                ? constrainShape(m_activeShape->p1, sp, m_activeShape->kind)
                : sp;
            update();
        } else if (a == Action::Release && m_drawing) {
            if (m_activeShape) {
                const QLineF diag(m_activeShape->p1, m_activeShape->p2);
                if (diag.length() >= 2.0)
                    commitAdd(std::move(m_activeShape), QStringLiteral("Shape"));
            }
            m_activeShape.reset();
            m_drawing = false;
            update();
        }
        break;
    }
    case ToolId::Text: {
        if (a == Action::Press)
            addTextAt(sp);
        break;
    }
    case ToolId::Select: {
        handleSelect(a, sp, mods);
        break;
    }
    case ToolId::Laser:
        break; // handled above
    }
}

// ---- selection -------------------------------------------------------------
void Canvas::handleSelect(Action a, const QPointF &sp, Qt::KeyboardModifiers mods)
{
    if (a == Action::Press) {
        Item *hit = topItemAt(sp);
        if (hit) {
            const bool already =
                std::find(m_selection.begin(), m_selection.end(), hit) != m_selection.end();
            if (mods & Qt::ShiftModifier) {
                if (already) removeFromSelection(hit);
                else addToSelection(hit);
            } else if (!already) {
                setSelectionSingle(hit);
            }
            m_movingSelection = true;
            m_moveStartScene = sp;
            m_moveAccum = QPointF(0, 0);
        } else {
            if (!(mods & Qt::ShiftModifier))
                clearSelection();
            m_rubber = true;
            m_rubberStartScene = sp;
            m_rubberRect = QRectF(sp, sp);
        }
        update();
    } else if (a == Action::Move) {
        if (m_movingSelection && !m_selection.empty()) {
            const QPointF d = sp - m_moveStartScene;
            const QPointF step = d - m_moveAccum;
            for (Item *it : m_selection)
                it->translate(step);
            m_moveAccum = d;
            update();
        } else if (m_rubber) {
            m_rubberRect = QRectF(m_rubberStartScene, sp).normalized();
            update();
        }
    } else {
        if (m_movingSelection) {
            m_movingSelection = false;
            if (!m_selection.empty() &&
                (qAbs(m_moveAccum.x()) > 0.01 || qAbs(m_moveAccum.y()) > 0.01)) {
                for (Item *it : m_selection)
                    it->translate(-m_moveAccum);
                std::vector<Item *> targets(m_selection.begin(), m_selection.end());
                m_doc->undoStack()->push(new TranslateItemsCommand(
                    m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
                    targets, m_moveAccum, QStringLiteral("Move")));
            }
            m_moveAccum = QPointF(0, 0);
        } else if (m_rubber) {
            m_rubber = false;
            selectInRect(m_rubberRect, (mods & Qt::ShiftModifier));
        }
        update();
    }
}

void Canvas::setSelectionSingle(Item *it)
{
    m_selection.clear();
    if (it) m_selection.push_back(it);
}

void Canvas::addToSelection(Item *it)
{
    if (it && std::find(m_selection.begin(), m_selection.end(), it) == m_selection.end())
        m_selection.push_back(it);
}

void Canvas::removeFromSelection(Item *it)
{
    m_selection.erase(std::remove(m_selection.begin(), m_selection.end(), it),
                      m_selection.end());
}

void Canvas::clearSelection()
{
    if (m_selection.empty())
        return;
    m_selection.clear();
    update();
}

void Canvas::selectAll()
{
    if (!m_doc)
        return;
    m_selection.clear();
    for (auto &it : m_doc->current().active().items)
        m_selection.push_back(it.get());
    update();
}

void Canvas::selectInRect(const QRectF &r, bool add)
{
    if (!m_doc)
        return;
    if (!add)
        m_selection.clear();
    for (auto &it : m_doc->current().active().items) {
        if (r.intersects(it->boundingRect()) &&
            std::find(m_selection.begin(), m_selection.end(), it.get()) == m_selection.end())
            m_selection.push_back(it.get());
    }
}

Item *Canvas::topItemAt(const QPointF &sp)
{
    if (!m_doc)
        return nullptr;
    Layer &ly = m_doc->current().active();
    const double r = 6.0 / qMax(0.0001, m_scale);
    for (int i = static_cast<int>(ly.items.size()) - 1; i >= 0; --i) {
        Item *it = ly.items[static_cast<std::size_t>(i)].get();
        if (hitTest(it, sp, r))
            return it;
    }
    return nullptr;
}

bool Canvas::hitTest(Item *it, const QPointF &sp, double radius) const
{
    const QRectF bb = it->boundingRect().adjusted(-radius, -radius, radius, radius);
    if (!bb.contains(sp))
        return false;

    if (it->type() == ItemType::Stroke) {
        const StrokeItem *s = static_cast<const StrokeItem *>(it);
        const double tol = radius + s->baseWidth * 0.5;
        if (s->points.size() == 1)
            return QLineF(sp, s->points.first().pos()).length() <= tol;
        for (int i = 1; i < s->points.size(); ++i)
            if (distToSegment(sp, s->points[i - 1].pos(), s->points[i].pos()) <= tol)
                return true;
        return false;
    }
    return true;
}

// ---- helpers ---------------------------------------------------------------
void Canvas::commitAdd(ItemPtr item, const QString &text)
{
    if (!m_doc || !item)
        return;
    m_doc->undoStack()->push(new AddItemCommand(
        m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
        std::move(item), text));
}

void Canvas::eraseAt(const QPointF &sp)
{
    if (!m_doc)
        return;
    Layer &ly = m_doc->current().active();
    const double r = m_settings.eraserRadius;
    for (std::size_t i = 0; i < ly.items.size();) {
        if (hitTest(ly.items[i].get(), sp, r)) {
            m_eraseStash.push_back({i, std::move(ly.items[i])});
            ly.items.erase(ly.items.begin() + static_cast<std::ptrdiff_t>(i));
        } else {
            ++i;
        }
    }
}

void Canvas::finishErase()
{
    if (!m_doc || m_eraseStash.empty())
        return;
    Layer &ly = m_doc->current().active();
    std::sort(m_eraseStash.begin(), m_eraseStash.end(),
              [](const EraseStash &a, const EraseStash &b) { return a.index < b.index; });

    std::vector<Item *> targets;
    for (auto &s : m_eraseStash) {
        Item *raw = s.item.get();
        targets.push_back(raw);
        const std::size_t idx = std::min(s.index, ly.items.size());
        ly.items.insert(ly.items.begin() + static_cast<std::ptrdiff_t>(idx),
                        std::move(s.item));
    }
    m_eraseStash.clear();

    m_doc->undoStack()->push(new RemoveItemsCommand(
        m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
        std::move(targets), QStringLiteral("Erase")));
}

void Canvas::addTextAt(const QPointF &sp)
{
    bool ok = false;
    const QString text = QInputDialog::getMultiLineText(
        this, tr("Add Text"), tr("Text:"), QString(), &ok);
    if (!ok || text.trimmed().isEmpty())
        return;
    auto t = std::make_unique<TextItem>();
    t->pos   = sp;
    t->text  = text;
    t->color = m_settings.textColor;
    t->font  = m_settings.textFont;
    commitAdd(std::move(t), QStringLiteral("Text"));
}

void Canvas::deleteSelection()
{
    if (!m_doc || m_selection.empty())
        return;
    std::vector<Item *> targets(m_selection.begin(), m_selection.end());
    m_selection.clear();
    m_doc->undoStack()->push(new RemoveItemsCommand(
        m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
        std::move(targets), QStringLiteral("Delete")));
    update();
}

void Canvas::cancelActive()
{
    m_activeStroke.reset();
    m_activeShape.reset();
    m_drawing = false;
    if (m_erasing && m_doc) {
        Layer &ly = m_doc->current().active();
        for (auto &s : m_eraseStash)
            ly.items.push_back(std::move(s.item));
    }
    m_eraseStash.clear();
    m_erasing = false;
    m_movingSelection = false;
    m_rubber = false;
}

void Canvas::updateCursor()
{
    switch (m_settings.tool) {
    case ToolId::Pen:
    case ToolId::Highlighter:
    case ToolId::Line:
    case ToolId::Rectangle:
    case ToolId::Ellipse:
        setCursor(Qt::CrossCursor);
        break;
    case ToolId::Eraser:
    case ToolId::Laser:
        setCursor(Qt::BlankCursor);
        break;
    case ToolId::Text:
        setCursor(Qt::IBeamCursor);
        break;
    case ToolId::Select:
        setCursor(Qt::ArrowCursor);
        break;
    }
}

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/ui/PreferencesDialog.h  (overwrite: adds "stay permanently" checkbox)
# ---------------------------------------------------------------------------
cat > src/ui/PreferencesDialog.h <<'EOF'
#pragma once

#include <QDialog>
#include <QColor>

#include "canvas/Tools.h"

class QSpinBox;
class QDoubleSpinBox;
class QPushButton;
class QCheckBox;

namespace ib {

class PreferencesDialog : public QDialog {
    Q_OBJECT
public:
    PreferencesDialog(const ToolSettings &s, int autosaveSeconds,
                      QWidget *parent = nullptr);

    ToolSettings toolSettings() const { return m_settings; }
    int autosaveSeconds() const;

private slots:
    void pickPenColor();
    void pickLaserCore();
    void pickLaserGlow();
    void applyAndAccept();

private:
    ToolSettings m_settings;

    QColor m_penColor;
    QColor m_laserCore;
    QColor m_laserGlow;

    QSpinBox       *m_penWidth      = nullptr;
    QPushButton    *m_penColorBtn   = nullptr;
    QDoubleSpinBox *m_hlWidth       = nullptr;
    QDoubleSpinBox *m_hlOpacity     = nullptr;
    QDoubleSpinBox *m_eraserRadius  = nullptr;
    QSpinBox       *m_textSize      = nullptr;
    QSpinBox       *m_autosave      = nullptr;

    QPushButton    *m_laserCoreBtn  = nullptr;
    QPushButton    *m_laserGlowBtn  = nullptr;
    QDoubleSpinBox *m_laserWidth    = nullptr;
    QDoubleSpinBox *m_laserGlowRad  = nullptr;
    QDoubleSpinBox *m_laserInten    = nullptr;
    QSpinBox       *m_laserVanish   = nullptr;
    QSpinBox       *m_laserFade     = nullptr;
    QCheckBox      *m_laserGlowOn   = nullptr;
    QCheckBox      *m_laserPersist  = nullptr;
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/ui/PreferencesDialog.cpp  (overwrite: adds persist row + logic)
# ---------------------------------------------------------------------------
cat > src/ui/PreferencesDialog.cpp <<'EOF'
#include "ui/PreferencesDialog.h"

#include <QFormLayout>
#include <QVBoxLayout>
#include <QGroupBox>
#include <QDialogButtonBox>
#include <QSpinBox>
#include <QDoubleSpinBox>
#include <QPushButton>
#include <QCheckBox>
#include <QColorDialog>

namespace ib {

static void styleColorButton(QPushButton *b, const QColor &c)
{
    b->setText(c.name(QColor::HexRgb));
    b->setStyleSheet(QString("background-color:%1; color:%2; padding:4px;")
                         .arg(c.name(),
                              c.lightness() > 128 ? "#000000" : "#ffffff"));
}

PreferencesDialog::PreferencesDialog(const ToolSettings &s, int autosaveSeconds,
                                     QWidget *parent)
    : QDialog(parent)
    , m_settings(s)
    , m_penColor(s.penColor)
    , m_laserCore(s.laser.coreColor)
    , m_laserGlow(s.laser.glowColor)
{
    setWindowTitle(tr("Preferences"));
    setModal(true);

    // ---- Tools group -------------------------------------------------------
    auto *toolsBox = new QGroupBox(tr("Tools"), this);
    auto *form = new QFormLayout(toolsBox);

    m_penWidth = new QSpinBox(this);
    m_penWidth->setRange(1, 64);
    m_penWidth->setValue(qRound(m_settings.penWidth));
    m_penWidth->setSuffix(tr(" px"));
    form->addRow(tr("Pen width:"), m_penWidth);

    m_penColorBtn = new QPushButton(this);
    connect(m_penColorBtn, &QPushButton::clicked, this, &PreferencesDialog::pickPenColor);
    styleColorButton(m_penColorBtn, m_penColor);
    form->addRow(tr("Pen color:"), m_penColorBtn);

    m_hlWidth = new QDoubleSpinBox(this);
    m_hlWidth->setRange(1.0, 120.0);
    m_hlWidth->setValue(m_settings.hlWidth);
    m_hlWidth->setSuffix(tr(" px"));
    form->addRow(tr("Highlighter width:"), m_hlWidth);

    m_hlOpacity = new QDoubleSpinBox(this);
    m_hlOpacity->setRange(0.05, 1.0);
    m_hlOpacity->setSingleStep(0.05);
    m_hlOpacity->setValue(m_settings.hlOpacity);
    form->addRow(tr("Highlighter opacity:"), m_hlOpacity);

    m_eraserRadius = new QDoubleSpinBox(this);
    m_eraserRadius->setRange(2.0, 200.0);
    m_eraserRadius->setValue(m_settings.eraserRadius);
    m_eraserRadius->setSuffix(tr(" px"));
    form->addRow(tr("Eraser radius:"), m_eraserRadius);

    m_textSize = new QSpinBox(this);
    m_textSize->setRange(6, 200);
    m_textSize->setValue(m_settings.textFont.pointSize() > 0
                             ? m_settings.textFont.pointSize() : 18);
    m_textSize->setSuffix(tr(" pt"));
    form->addRow(tr("Text size:"), m_textSize);

    // ---- Laser group -------------------------------------------------------
    auto *laserBox = new QGroupBox(tr("Laser pointer"), this);
    auto *lf = new QFormLayout(laserBox);

    m_laserCoreBtn = new QPushButton(this);
    connect(m_laserCoreBtn, &QPushButton::clicked, this, &PreferencesDialog::pickLaserCore);
    styleColorButton(m_laserCoreBtn, m_laserCore);
    lf->addRow(tr("Core color:"), m_laserCoreBtn);

    m_laserGlowBtn = new QPushButton(this);
    connect(m_laserGlowBtn, &QPushButton::clicked, this, &PreferencesDialog::pickLaserGlow);
    styleColorButton(m_laserGlowBtn, m_laserGlow);
    lf->addRow(tr("Glow color:"), m_laserGlowBtn);

    m_laserWidth = new QDoubleSpinBox(this);
    m_laserWidth->setRange(1.0, 60.0);
    m_laserWidth->setValue(m_settings.laser.width);
    m_laserWidth->setSuffix(tr(" px"));
    lf->addRow(tr("Core width:"), m_laserWidth);

    m_laserGlowRad = new QDoubleSpinBox(this);
    m_laserGlowRad->setRange(2.0, 200.0);
    m_laserGlowRad->setValue(m_settings.laser.glowRadius);
    m_laserGlowRad->setSuffix(tr(" px"));
    lf->addRow(tr("Glow radius:"), m_laserGlowRad);

    m_laserInten = new QDoubleSpinBox(this);
    m_laserInten->setRange(0.1, 1.0);
    m_laserInten->setSingleStep(0.05);
    m_laserInten->setValue(m_settings.laser.intensity);
    lf->addRow(tr("Intensity:"), m_laserInten);

    m_laserVanish = new QSpinBox(this);
    m_laserVanish->setRange(0, 5000);
    m_laserVanish->setValue(m_settings.laser.vanishDelayMs);
    m_laserVanish->setSuffix(tr(" ms"));
    lf->addRow(tr("Vanish delay:"), m_laserVanish);

    m_laserFade = new QSpinBox(this);
    m_laserFade->setRange(0, 5000);
    m_laserFade->setValue(m_settings.laser.fadeDurationMs);
    m_laserFade->setSuffix(tr(" ms"));
    lf->addRow(tr("Fade-out duration:"), m_laserFade);

    m_laserGlowOn = new QCheckBox(tr("Enable glow"), this);
    m_laserGlowOn->setChecked(m_settings.laser.glowEnabled);
    lf->addRow(QString(), m_laserGlowOn);

    m_laserPersist = new QCheckBox(tr("Stay permanently (no vanishing)"), this);
    m_laserPersist->setChecked(m_settings.laser.persist);
    lf->addRow(QString(), m_laserPersist);

    // ---- App group ---------------------------------------------------------
    auto *appBox = new QGroupBox(tr("Application"), this);
    auto *af = new QFormLayout(appBox);
    m_autosave = new QSpinBox(this);
    m_autosave->setRange(0, 3600);
    m_autosave->setValue(autosaveSeconds);
    m_autosave->setSuffix(tr(" s (0 = off)"));
    af->addRow(tr("Autosave interval:"), m_autosave);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel,
                                         this);
    connect(buttons, &QDialogButtonBox::accepted, this, &PreferencesDialog::applyAndAccept);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);

    auto *root = new QVBoxLayout(this);
    root->addWidget(toolsBox);
    root->addWidget(laserBox);
    root->addWidget(appBox);
    root->addWidget(buttons);
}

void PreferencesDialog::pickPenColor()
{
    const QColor c = QColorDialog::getColor(m_penColor, this, tr("Pen Color"));
    if (c.isValid()) { m_penColor = c; styleColorButton(m_penColorBtn, c); }
}

void PreferencesDialog::pickLaserCore()
{
    const QColor c = QColorDialog::getColor(m_laserCore, this, tr("Laser Core Color"));
    if (c.isValid()) { m_laserCore = c; styleColorButton(m_laserCoreBtn, c); }
}

void PreferencesDialog::pickLaserGlow()
{
    const QColor c = QColorDialog::getColor(m_laserGlow, this, tr("Laser Glow Color"));
    if (c.isValid()) { m_laserGlow = c; styleColorButton(m_laserGlowBtn, c); }
}

int PreferencesDialog::autosaveSeconds() const
{
    return m_autosave->value();
}

void PreferencesDialog::applyAndAccept()
{
    m_settings.penWidth     = m_penWidth->value();
    m_settings.penColor     = m_penColor;
    m_settings.hlWidth      = m_hlWidth->value();
    m_settings.hlOpacity    = m_hlOpacity->value();
    m_settings.eraserRadius = m_eraserRadius->value();

    QFont f = m_settings.textFont;
    f.setPointSize(m_textSize->value());
    m_settings.textFont = f;

    m_settings.laser.coreColor      = m_laserCore;
    m_settings.laser.glowColor      = m_laserGlow;
    m_settings.laser.width          = m_laserWidth->value();
    m_settings.laser.glowRadius     = m_laserGlowRad->value();
    m_settings.laser.intensity      = m_laserInten->value();
    m_settings.laser.vanishDelayMs  = m_laserVanish->value();
    m_settings.laser.fadeDurationMs = m_laserFade->value();
    m_settings.laser.glowEnabled    = m_laserGlowOn->isChecked();
    m_settings.laser.persist        = m_laserPersist->isChecked();

    accept();
}

} // namespace ib
EOF

log "PART 9 complete: laser now hovers like a pen + optional permanent (no-vanish) mode"


# ---------------------------------------------------------------------------
#  PART 10 : Laser becomes a true vector "laser pen" (permanent, unpixelated)
#            + OS-cursor nib-dot brush preview for drawing tools.
#  Overwrites Laser.h, Canvas.h, Canvas.cpp, PreferencesDialog.{h,cpp}.
#  Removes the fade timer / proximity filter / elapsed clock (de-bloat).
# ---------------------------------------------------------------------------
log "PART 10: vector laser pen + nib-dot cursor"

# ---------------------------------------------------------------------------
#  src/canvas/Laser.h  (overwrite: permanent vector glow ink in scene space)
# ---------------------------------------------------------------------------
cat > src/canvas/Laser.h <<'EOF'
#pragma once

#include <QColor>
#include <QPointF>
#include <QPolygonF>
#include <QVector>
#include <QPen>
#include <QPainter>

namespace ib {

// Sizes are in SCENE units (so the ink scales with zoom like real ink).
struct LaserSettings {
    QColor coreColor  = QColor(255, 255, 255); // hot core
    QColor glowColor  = QColor(255, 45, 40);   // warm glow (Apple-like)
    double width      = 6.0;    // core stroke width
    double glowRadius = 10.0;   // extra glow width added around the core
    double intensity  = 1.0;    // overall opacity (0..1)
    bool   glowEnabled = true;
};

// Permanent, vector, scene-space laser ink. Painted while the canvas painter
// is already translated+scaled, so everything stays crisp at any zoom.
class LaserInk {
public:
    void setSettings(const LaserSettings &s) { m_s = s; }
    const LaserSettings &settings() const { return m_s; }

    void begin(const QPointF &scenePt)
    {
        m_active.clear();
        m_active << scenePt;
        m_activeOn = true;
    }
    void extend(const QPointF &scenePt)
    {
        if (m_activeOn)
            m_active << scenePt;
    }
    void end()
    {
        if (m_activeOn && !m_active.isEmpty())
            m_strokes.push_back({ m_active, m_s });
        m_active.clear();
        m_activeOn = false;
    }

    void clear()
    {
        m_strokes.clear();
        m_active.clear();
        m_activeOn = false;
    }

    bool isEmpty() const { return m_strokes.isEmpty() && !m_activeOn; }

    void paint(QPainter &p) const
    {
        for (const auto &st : m_strokes)
            drawStroke(p, st.pts, st.s);
        if (m_activeOn && !m_active.isEmpty())
            drawStroke(p, m_active, m_s);
    }

private:
    struct Stroke {
        QPolygonF     pts;
        LaserSettings s;
    };

    static void strokePass(QPainter &p, const QPolygonF &pts,
                           const QColor &col, double w)
    {
        QPen pen(col);
        pen.setWidthF(qMax(0.1, w));
        pen.setCapStyle(Qt::RoundCap);
        pen.setJoinStyle(Qt::RoundJoin);
        p.setPen(pen);
        p.setBrush(Qt::NoBrush);
        if (pts.size() == 1)
            p.drawPoint(pts.first());
        else
            p.drawPolyline(pts);
    }

    static void drawStroke(QPainter &p, const QPolygonF &pts, const LaserSettings &s)
    {
        if (pts.isEmpty())
            return;
        p.save();
        p.setRenderHint(QPainter::Antialiasing, true);

        if (s.glowEnabled && s.glowRadius > 0.0) {
            QColor g1 = s.glowColor; g1.setAlphaF(0.30 * s.intensity);
            strokePass(p, pts, g1, s.width + 2.0 * s.glowRadius);
            QColor g2 = s.glowColor; g2.setAlphaF(0.50 * s.intensity);
            strokePass(p, pts, g2, s.width + s.glowRadius);
        }

        QColor c = s.coreColor;
        c.setAlphaF(s.intensity);
        strokePass(p, pts, c, s.width);

        p.restore();
    }

    LaserSettings   m_s;
    QVector<Stroke> m_strokes;
    QPolygonF       m_active;
    bool            m_activeOn = false;
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/canvas/Canvas.h  (overwrite: LaserInk + hover flag, no timer/clock)
# ---------------------------------------------------------------------------
cat > src/canvas/Canvas.h <<'EOF'
#pragma once

#include <QWidget>
#include <QPointF>
#include <memory>
#include <vector>

#include "model/Document.h"
#include "model/StrokeItem.h"
#include "model/ShapeItem.h"
#include "canvas/Tools.h"

class QPaintEvent;
class QMouseEvent;
class QTabletEvent;
class QWheelEvent;
class QKeyEvent;

namespace ib {

class Canvas : public QWidget {
    Q_OBJECT
public:
    explicit Canvas(QWidget *parent = nullptr);

    void setDocument(Document *doc);
    Document *document() const { return m_doc; }

    ToolSettings &settings() { return m_settings; }
    const ToolSettings &settings() const { return m_settings; }

    void setTool(ToolId t);
    ToolId tool() const { return m_settings.tool; }

    bool hasSelection() const { return !m_selection.empty(); }
    double zoomPercent() const { return m_scale * 100.0; }

public slots:
    void zoomIn();
    void zoomOut();
    void resetView();
    void zoomToFit();
    void deleteSelection();
    void selectAll();
    void clearSelection();
    void clearLaser();
    void refresh() { update(); }

signals:
    void viewChanged();
    void toolChanged(ib::ToolId tool);
    void cursorMoved(QPointF scenePos);

protected:
    void paintEvent(QPaintEvent *) override;
    void mousePressEvent(QMouseEvent *e) override;
    void mouseMoveEvent(QMouseEvent *e) override;
    void mouseReleaseEvent(QMouseEvent *e) override;
    void tabletEvent(QTabletEvent *e) override;
    void wheelEvent(QWheelEvent *e) override;
    void keyPressEvent(QKeyEvent *e) override;
    void keyReleaseEvent(QKeyEvent *e) override;
    void leaveEvent(QEvent *e) override;

private:
    enum class Action { Press, Move, Release };

    struct EraseStash {
        std::size_t index;
        ItemPtr     item;
    };

    QPointF widgetToScene(const QPointF &p) const { return (p - m_translate) / m_scale; }
    QPointF sceneToWidget(const QPointF &s) const { return s * m_scale + m_translate; }

    void handlePointer(Action a, const QPointF &widgetPos, double pressure,
                       Qt::KeyboardModifiers mods, bool eraserTip);
    void handleSelect(Action a, const QPointF &sp, Qt::KeyboardModifiers mods);

    void commitAdd(ItemPtr item, const QString &text);
    void eraseAt(const QPointF &sp);
    void finishErase();
    void addTextAt(const QPointF &sp);
    void cancelActive();
    void zoomAround(const QPointF &widgetPos, double factor);
    void updateCursor();

    void drawBackground(QPainter &p, const Page &pg, const QRectF &area);
    void drawSelection(QPainter &p);
    void drawBrushPreview(QPainter &p);

    bool hitTest(Item *it, const QPointF &sp, double radius) const;
    Item *topItemAt(const QPointF &sp);
    void selectInRect(const QRectF &r, bool add);
    void setSelectionSingle(Item *it);
    void addToSelection(Item *it);
    void removeFromSelection(Item *it);

    Document    *m_doc = nullptr;
    ToolSettings m_settings;

    double  m_scale = 1.0;
    QPointF m_translate;

    bool   m_panning = false;
    bool   m_spaceDown = false;
    QPoint m_lastPanPos;

    std::unique_ptr<StrokeItem> m_activeStroke;
    std::unique_ptr<ShapeItem>  m_activeShape;
    bool m_drawing = false;

    bool m_erasing = false;
    std::vector<EraseStash> m_eraseStash;

    std::vector<Item *> m_selection;
    bool    m_movingSelection = false;
    QPointF m_moveStartScene;
    QPointF m_moveAccum;
    bool    m_rubber = false;
    QPointF m_rubberStartScene;
    QRectF  m_rubberRect;

    QPointF m_cursorWidget;
    bool    m_hoverValid = false;

    LaserInk m_laser;
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/canvas/Canvas.cpp  (overwrite)
# ---------------------------------------------------------------------------
cat > src/canvas/Canvas.cpp <<'EOF'
#include "canvas/Canvas.h"

#include "core/Commands.h"
#include "model/TextItem.h"
#include "model/ImageItem.h"

#include <QPainter>
#include <QPen>
#include <QRadialGradient>
#include <QMouseEvent>
#include <QTabletEvent>
#include <QWheelEvent>
#include <QKeyEvent>
#include <QPointingDevice>
#include <QInputDialog>
#include <QUndoStack>
#include <QLineF>
#include <algorithm>
#include <cmath>

namespace ib {

static const double kPi = 3.14159265358979323846;

static double distToSegment(const QPointF &p, const QPointF &a, const QPointF &b)
{
    const QPointF ab = b - a;
    const double len2 = ab.x() * ab.x() + ab.y() * ab.y();
    if (len2 <= 1e-9)
        return std::hypot(p.x() - a.x(), p.y() - a.y());
    double t = ((p.x() - a.x()) * ab.x() + (p.y() - a.y()) * ab.y()) / len2;
    t = std::max(0.0, std::min(1.0, t));
    const QPointF proj(a.x() + t * ab.x(), a.y() + t * ab.y());
    return std::hypot(p.x() - proj.x(), p.y() - proj.y());
}

static QPointF constrainShape(const QPointF &a, const QPointF &b, ShapeKind kind)
{
    const QPointF d = b - a;
    if (kind == ShapeKind::Line) {
        double ang = std::atan2(d.y(), d.x());
        const double step = kPi / 4.0;
        ang = std::round(ang / step) * step;
        const double len = std::hypot(d.x(), d.y());
        return a + QPointF(std::cos(ang) * len, std::sin(ang) * len);
    }
    const double s = std::max(std::abs(d.x()), std::abs(d.y()));
    return a + QPointF(d.x() < 0 ? -s : s, d.y() < 0 ? -s : s);
}

Canvas::Canvas(QWidget *parent)
    : QWidget(parent)
{
    setFocusPolicy(Qt::StrongFocus);
    setMouseTracking(true);
    setAttribute(Qt::WA_TabletTracking, true);
    setAutoFillBackground(false);
    m_translate = QPointF(40, 40);
    updateCursor();
}

void Canvas::setDocument(Document *doc)
{
    if (m_doc == doc)
        return;
    if (m_doc) {
        m_doc->disconnect(this);
        if (m_doc->undoStack())
            m_doc->undoStack()->disconnect(this);
    }
    m_doc = doc;
    cancelActive();
    m_selection.clear();

    if (m_doc) {
        connect(m_doc, &Document::currentPageChanged, this, [this](int) {
            cancelActive(); m_selection.clear(); update();
        });
        connect(m_doc, &Document::pagesChanged, this, [this]() {
            cancelActive(); m_selection.clear(); update();
        });
        connect(m_doc, &Document::contentChanged, this, [this]() { update(); });
        if (m_doc->undoStack()) {
            connect(m_doc->undoStack(), &QUndoStack::indexChanged, this, [this](int) {
                m_selection.clear(); cancelActive(); update();
            });
        }
    }
    update();
}

void Canvas::setTool(ToolId t)
{
    cancelActive();
    m_settings.tool = t;
    updateCursor();
    emit toolChanged(t);
    update();
}

void Canvas::clearLaser()
{
    m_laser.clear();
    update();
}

// ---- view ------------------------------------------------------------------
void Canvas::zoomAround(const QPointF &widgetPos, double factor)
{
    const QPointF before = widgetToScene(widgetPos);
    m_scale = qBound(0.05, m_scale * factor, 40.0);
    m_translate = widgetPos - before * m_scale;
    update();
    emit viewChanged();
}

void Canvas::zoomIn()  { zoomAround(QPointF(width() / 2.0, height() / 2.0), 1.2); }
void Canvas::zoomOut() { zoomAround(QPointF(width() / 2.0, height() / 2.0), 1.0 / 1.2); }

void Canvas::resetView()
{
    m_scale = 1.0;
    m_translate = QPointF(40, 40);
    update();
    emit viewChanged();
}

void Canvas::zoomToFit()
{
    if (!m_doc) { update(); return; }
    QRectF b = m_doc->current().contentBounds();
    if (b.isNull()) { resetView(); return; }
    b.adjust(-40, -40, 40, 40);
    const double sx = width()  / b.width();
    const double sy = height() / b.height();
    m_scale = qBound(0.05, qMin(sx, sy), 40.0);
    m_translate = QPointF(width() / 2.0, height() / 2.0) - b.center() * m_scale;
    update();
    emit viewChanged();
}

// ---- painting --------------------------------------------------------------
void Canvas::drawBackground(QPainter &p, const Page &pg, const QRectF &area)
{
    if (pg.background == BackgroundKind::Blank)
        return;
    const double s = qMax(4.0, pg.gridSpacing);
    QPen pen(pg.gridColor);
    pen.setCosmetic(true);
    pen.setWidth(1);
    p.setPen(pen);

    const double startX = std::floor(area.left() / s) * s;
    const double startY = std::floor(area.top() / s) * s;

    if (pg.background == BackgroundKind::Grid) {
        for (double x = startX; x <= area.right(); x += s)
            p.drawLine(QPointF(x, area.top()), QPointF(x, area.bottom()));
        for (double y = startY; y <= area.bottom(); y += s)
            p.drawLine(QPointF(area.left(), y), QPointF(area.right(), y));
    } else if (pg.background == BackgroundKind::Lines) {
        for (double y = startY; y <= area.bottom(); y += s)
            p.drawLine(QPointF(area.left(), y), QPointF(area.right(), y));
    } else {
        p.setPen(Qt::NoPen);
        p.setBrush(pg.gridColor);
        for (double x = startX; x <= area.right(); x += s)
            for (double y = startY; y <= area.bottom(); y += s)
                p.drawEllipse(QPointF(x, y), 1.3, 1.3);
    }
}

void Canvas::drawSelection(QPainter &p)
{
    if (m_selection.empty())
        return;
    QPen pen(QColor(60, 120, 220));
    pen.setCosmetic(true);
    pen.setStyle(Qt::DashLine);
    pen.setWidth(1);
    p.setPen(pen);
    p.setBrush(Qt::NoBrush);
    for (Item *it : m_selection)
        p.drawRect(it->boundingRect());
}

void Canvas::drawBrushPreview(QPainter &p)
{
    if (!m_hoverValid || m_panning)
        return;

    // Eraser keeps its own radius ring.
    if (m_settings.tool == ToolId::Eraser) {
        const double r = m_settings.eraserRadius * m_scale;
        QPen pen(QColor(70, 70, 70));
        pen.setStyle(Qt::DashLine);
        p.setPen(pen);
        p.setBrush(Qt::NoBrush);
        p.drawEllipse(m_cursorWidget, r, r);
        return;
    }

    QColor col;
    double w = 0.0;
    bool laser = false;
    switch (m_settings.tool) {
    case ToolId::Pen:         col = m_settings.penColor;   w = m_settings.penWidth;   break;
    case ToolId::Highlighter: col = m_settings.hlColor;    w = m_settings.hlWidth;    break;
    case ToolId::Line:
    case ToolId::Rectangle:
    case ToolId::Ellipse:     col = m_settings.shapeColor; w = m_settings.shapeWidth; break;
    case ToolId::Laser:       col = m_settings.laser.coreColor; w = m_settings.laser.width; laser = true; break;
    default: return; // Select / Text: no nib dot
    }

    const double r = qMax(1.5, w * 0.5 * m_scale);

    p.save();
    p.setRenderHint(QPainter::Antialiasing, true);

    if (laser && m_settings.laser.glowEnabled) {
        const double gr = r + m_settings.laser.glowRadius * m_scale;
        QRadialGradient g(m_cursorWidget, gr);
        QColor g0 = m_settings.laser.glowColor; g0.setAlphaF(0.55 * m_settings.laser.intensity);
        QColor g1 = m_settings.laser.glowColor; g1.setAlphaF(0.0);
        g.setColorAt(0.0, g0);
        g.setColorAt(1.0, g1);
        p.setPen(Qt::NoPen);
        p.setBrush(g);
        p.drawEllipse(m_cursorWidget, gr, gr);
    }

    QColor fill = col;
    fill.setAlphaF(laser ? m_settings.laser.intensity : 0.9);
    const QColor outline = (col.lightness() > 128) ? QColor(0, 0, 0, 170)
                                                   : QColor(255, 255, 255, 190);
    QPen pen(outline);
    pen.setWidthF(1.0);
    p.setPen(pen);
    p.setBrush(fill);
    p.drawEllipse(m_cursorWidget, r, r);
    p.restore();
}

void Canvas::paintEvent(QPaintEvent *)
{
    QPainter p(this);
    p.fillRect(rect(), QColor(90, 93, 99));
    if (!m_doc)
        return;

    p.save();
    p.translate(m_translate);
    p.scale(m_scale, m_scale);

    const QRectF sceneRect =
        QRectF(widgetToScene(QPointF(0, 0)),
               widgetToScene(QPointF(width(), height()))).normalized();

    Page &pg = m_doc->current();
    p.fillRect(sceneRect, pg.bgColor);
    drawBackground(p, pg, sceneRect);

    p.setRenderHint(QPainter::Antialiasing, true);
    p.setRenderHint(QPainter::TextAntialiasing, true);

    for (const auto &ly : pg.layers) {
        if (!ly.visible)
            continue;
        p.save();
        if (ly.opacity < 1.0)
            p.setOpacity(ly.opacity);
        for (const auto &it : ly.items)
            it->paint(p);
        p.restore();
    }

    if (m_activeStroke) m_activeStroke->paint(p);
    if (m_activeShape)  m_activeShape->paint(p);

    // Laser pen ink (permanent, vector, scene-space) sits above the artwork.
    if (!m_laser.isEmpty())
        m_laser.paint(p);

    drawSelection(p);

    if (m_rubber) {
        QPen pen(QColor(60, 120, 220));
        pen.setCosmetic(true);
        pen.setStyle(Qt::DashLine);
        p.setPen(pen);
        p.setBrush(QColor(60, 120, 220, 40));
        p.drawRect(m_rubberRect);
    }

    p.restore();

    drawBrushPreview(p);
}

// ---- input -----------------------------------------------------------------
void Canvas::mousePressEvent(QMouseEvent *e)
{
    m_cursorWidget = e->position();
    m_hoverValid = true;
    if (e->button() == Qt::MiddleButton ||
        (m_spaceDown && e->button() == Qt::LeftButton)) {
        m_panning = true;
        m_lastPanPos = e->position().toPoint();
        setCursor(Qt::ClosedHandCursor);
        return;
    }
    if (e->button() == Qt::LeftButton)
        handlePointer(Action::Press, e->position(), 1.0, e->modifiers(), false);
}

void Canvas::mouseMoveEvent(QMouseEvent *e)
{
    m_cursorWidget = e->position();
    m_hoverValid = true;
    if (m_panning) {
        const QPoint d = e->position().toPoint() - m_lastPanPos;
        m_lastPanPos = e->position().toPoint();
        m_translate += QPointF(d);
        update();
        emit viewChanged();
        return;
    }
    handlePointer(Action::Move, e->position(), 1.0, e->modifiers(), false);
    update();
    emit cursorMoved(widgetToScene(e->position()));
}

void Canvas::mouseReleaseEvent(QMouseEvent *e)
{
    m_cursorWidget = e->position();
    if (m_panning &&
        (e->button() == Qt::MiddleButton || e->button() == Qt::LeftButton)) {
        m_panning = false;
        updateCursor();
        return;
    }
    if (e->button() == Qt::LeftButton)
        handlePointer(Action::Release, e->position(), 1.0, e->modifiers(), false);
}

void Canvas::tabletEvent(QTabletEvent *e)
{
    const bool eraserTip =
        e->pointerType() == QPointingDevice::PointerType::Eraser;
    double pr = e->pressure();
    if (pr <= 0.0)
        pr = 1.0;
    m_cursorWidget = e->position();
    m_hoverValid = true;

    switch (e->type()) {
    case QEvent::TabletPress:
        handlePointer(Action::Press, e->position(), pr, e->modifiers(), eraserTip);
        break;
    case QEvent::TabletMove:
        handlePointer(Action::Move, e->position(), pr, e->modifiers(), eraserTip);
        emit cursorMoved(widgetToScene(e->position()));
        update();
        break;
    case QEvent::TabletRelease:
        handlePointer(Action::Release, e->position(), pr, e->modifiers(), eraserTip);
        break;
    default:
        break;
    }
    e->accept();
}

void Canvas::wheelEvent(QWheelEvent *e)
{
    const double factor = std::pow(1.0015, e->angleDelta().y());
    zoomAround(e->position(), factor);
    e->accept();
}

void Canvas::keyPressEvent(QKeyEvent *e)
{
    if (e->key() == Qt::Key_Space) {
        m_spaceDown = true;
        setCursor(Qt::OpenHandCursor);
        e->accept();
        return;
    }
    if (e->key() == Qt::Key_Delete || e->key() == Qt::Key_Backspace) {
        deleteSelection();
        e->accept();
        return;
    }
    if (e->key() == Qt::Key_Escape) {
        cancelActive();
        clearSelection();
        m_laser.clear();          // Esc clears the laser ink
        update();
        e->accept();
        return;
    }
    QWidget::keyPressEvent(e);
}

void Canvas::keyReleaseEvent(QKeyEvent *e)
{
    if (e->key() == Qt::Key_Space) {
        m_spaceDown = false;
        updateCursor();
        e->accept();
        return;
    }
    QWidget::keyReleaseEvent(e);
}

void Canvas::leaveEvent(QEvent *e)
{
    m_hoverValid = false;
    update();
    QWidget::leaveEvent(e);
}

// ---- pointer dispatch ------------------------------------------------------
void Canvas::handlePointer(Action a, const QPointF &widgetPos, double pressure,
                           Qt::KeyboardModifiers mods, bool eraserTip)
{
    if (!m_doc)
        return;
    const QPointF sp = widgetToScene(widgetPos);
    m_cursorWidget = widgetPos;

    const ToolId t = eraserTip ? ToolId::Eraser : m_settings.tool;

    // Laser pen: permanent vector ink; ignores layer locks; never edits model.
    if (t == ToolId::Laser) {
        m_laser.setSettings(m_settings.laser);
        if (a == Action::Press) {
            m_drawing = true;
            m_laser.begin(sp);
        } else if (a == Action::Move && m_drawing) {
            m_laser.extend(sp);
        } else if (a == Action::Release) {
            m_laser.end();
            m_drawing = false;
        }
        update();
        return;
    }

    Layer &ly = m_doc->current().active();
    if (ly.locked)
        return;

    switch (t) {
    case ToolId::Pen:
    case ToolId::Highlighter: {
        const bool hl = (t == ToolId::Highlighter);
        if (a == Action::Press) {
            m_drawing = true;
            m_activeStroke = std::make_unique<StrokeItem>();
            m_activeStroke->highlighter   = hl;
            m_activeStroke->color         = hl ? m_settings.hlColor : m_settings.penColor;
            m_activeStroke->baseWidth     = hl ? m_settings.hlWidth : m_settings.penWidth;
            m_activeStroke->opacity       = hl ? m_settings.hlOpacity : 1.0;
            m_activeStroke->pressureWidth = hl ? false : m_settings.penPressure;
            m_activeStroke->addPoint(StrokePoint(sp.x(), sp.y(), pressure));
            update();
        } else if (a == Action::Move && m_drawing && m_activeStroke) {
            m_activeStroke->addPoint(StrokePoint(sp.x(), sp.y(), pressure));
            update();
        } else if (a == Action::Release && m_drawing) {
            if (m_activeStroke && !m_activeStroke->isEmpty())
                commitAdd(std::move(m_activeStroke),
                          hl ? QStringLiteral("Highlight") : QStringLiteral("Draw"));
            m_activeStroke.reset();
            m_drawing = false;
            update();
        }
        break;
    }
    case ToolId::Eraser: {
        if (a == Action::Press) { m_erasing = true; m_eraseStash.clear(); eraseAt(sp); update(); }
        else if (a == Action::Move && m_erasing) { eraseAt(sp); update(); }
        else if (a == Action::Release && m_erasing) { finishErase(); m_erasing = false; update(); }
        break;
    }
    case ToolId::Line:
    case ToolId::Rectangle:
    case ToolId::Ellipse: {
        if (a == Action::Press) {
            m_activeShape = std::make_unique<ShapeItem>();
            m_activeShape->kind = (t == ToolId::Line) ? ShapeKind::Line
                                : (t == ToolId::Rectangle) ? ShapeKind::Rectangle
                                : ShapeKind::Ellipse;
            m_activeShape->color  = m_settings.shapeColor;
            m_activeShape->width  = m_settings.shapeWidth;
            m_activeShape->filled = m_settings.shapeFilled;
            m_activeShape->fill   = m_settings.shapeFill;
            m_activeShape->p1 = sp;
            m_activeShape->p2 = sp;
            m_drawing = true;
            update();
        } else if (a == Action::Move && m_drawing && m_activeShape) {
            m_activeShape->p2 = (mods & Qt::ShiftModifier)
                ? constrainShape(m_activeShape->p1, sp, m_activeShape->kind)
                : sp;
            update();
        } else if (a == Action::Release && m_drawing) {
            if (m_activeShape) {
                const QLineF diag(m_activeShape->p1, m_activeShape->p2);
                if (diag.length() >= 2.0)
                    commitAdd(std::move(m_activeShape), QStringLiteral("Shape"));
            }
            m_activeShape.reset();
            m_drawing = false;
            update();
        }
        break;
    }
    case ToolId::Text: {
        if (a == Action::Press)
            addTextAt(sp);
        break;
    }
    case ToolId::Select: {
        handleSelect(a, sp, mods);
        break;
    }
    case ToolId::Laser:
        break; // handled above
    }
}

// ---- selection -------------------------------------------------------------
void Canvas::handleSelect(Action a, const QPointF &sp, Qt::KeyboardModifiers mods)
{
    if (a == Action::Press) {
        Item *hit = topItemAt(sp);
        if (hit) {
            const bool already =
                std::find(m_selection.begin(), m_selection.end(), hit) != m_selection.end();
            if (mods & Qt::ShiftModifier) {
                if (already) removeFromSelection(hit);
                else addToSelection(hit);
            } else if (!already) {
                setSelectionSingle(hit);
            }
            m_movingSelection = true;
            m_moveStartScene = sp;
            m_moveAccum = QPointF(0, 0);
        } else {
            if (!(mods & Qt::ShiftModifier))
                clearSelection();
            m_rubber = true;
            m_rubberStartScene = sp;
            m_rubberRect = QRectF(sp, sp);
        }
        update();
    } else if (a == Action::Move) {
        if (m_movingSelection && !m_selection.empty()) {
            const QPointF d = sp - m_moveStartScene;
            const QPointF step = d - m_moveAccum;
            for (Item *it : m_selection)
                it->translate(step);
            m_moveAccum = d;
            update();
        } else if (m_rubber) {
            m_rubberRect = QRectF(m_rubberStartScene, sp).normalized();
            update();
        }
    } else {
        if (m_movingSelection) {
            m_movingSelection = false;
            if (!m_selection.empty() &&
                (qAbs(m_moveAccum.x()) > 0.01 || qAbs(m_moveAccum.y()) > 0.01)) {
                for (Item *it : m_selection)
                    it->translate(-m_moveAccum);
                std::vector<Item *> targets(m_selection.begin(), m_selection.end());
                m_doc->undoStack()->push(new TranslateItemsCommand(
                    m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
                    targets, m_moveAccum, QStringLiteral("Move")));
            }
            m_moveAccum = QPointF(0, 0);
        } else if (m_rubber) {
            m_rubber = false;
            selectInRect(m_rubberRect, (mods & Qt::ShiftModifier));
        }
        update();
    }
}

void Canvas::setSelectionSingle(Item *it)
{
    m_selection.clear();
    if (it) m_selection.push_back(it);
}

void Canvas::addToSelection(Item *it)
{
    if (it && std::find(m_selection.begin(), m_selection.end(), it) == m_selection.end())
        m_selection.push_back(it);
}

void Canvas::removeFromSelection(Item *it)
{
    m_selection.erase(std::remove(m_selection.begin(), m_selection.end(), it),
                      m_selection.end());
}

void Canvas::clearSelection()
{
    if (m_selection.empty())
        return;
    m_selection.clear();
    update();
}

void Canvas::selectAll()
{
    if (!m_doc)
        return;
    m_selection.clear();
    for (auto &it : m_doc->current().active().items)
        m_selection.push_back(it.get());
    update();
}

void Canvas::selectInRect(const QRectF &r, bool add)
{
    if (!m_doc)
        return;
    if (!add)
        m_selection.clear();
    for (auto &it : m_doc->current().active().items) {
        if (r.intersects(it->boundingRect()) &&
            std::find(m_selection.begin(), m_selection.end(), it.get()) == m_selection.end())
            m_selection.push_back(it.get());
    }
}

Item *Canvas::topItemAt(const QPointF &sp)
{
    if (!m_doc)
        return nullptr;
    Layer &ly = m_doc->current().active();
    const double r = 6.0 / qMax(0.0001, m_scale);
    for (int i = static_cast<int>(ly.items.size()) - 1; i >= 0; --i) {
        Item *it = ly.items[static_cast<std::size_t>(i)].get();
        if (hitTest(it, sp, r))
            return it;
    }
    return nullptr;
}

bool Canvas::hitTest(Item *it, const QPointF &sp, double radius) const
{
    const QRectF bb = it->boundingRect().adjusted(-radius, -radius, radius, radius);
    if (!bb.contains(sp))
        return false;

    if (it->type() == ItemType::Stroke) {
        const StrokeItem *s = static_cast<const StrokeItem *>(it);
        const double tol = radius + s->baseWidth * 0.5;
        if (s->points.size() == 1)
            return QLineF(sp, s->points.first().pos()).length() <= tol;
        for (int i = 1; i < s->points.size(); ++i)
            if (distToSegment(sp, s->points[i - 1].pos(), s->points[i].pos()) <= tol)
                return true;
        return false;
    }
    return true;
}

// ---- helpers ---------------------------------------------------------------
void Canvas::commitAdd(ItemPtr item, const QString &text)
{
    if (!m_doc || !item)
        return;
    m_doc->undoStack()->push(new AddItemCommand(
        m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
        std::move(item), text));
}

void Canvas::eraseAt(const QPointF &sp)
{
    if (!m_doc)
        return;
    Layer &ly = m_doc->current().active();
    const double r = m_settings.eraserRadius;
    for (std::size_t i = 0; i < ly.items.size();) {
        if (hitTest(ly.items[i].get(), sp, r)) {
            m_eraseStash.push_back({i, std::move(ly.items[i])});
            ly.items.erase(ly.items.begin() + static_cast<std::ptrdiff_t>(i));
        } else {
            ++i;
        }
    }
}

void Canvas::finishErase()
{
    if (!m_doc || m_eraseStash.empty())
        return;
    Layer &ly = m_doc->current().active();
    std::sort(m_eraseStash.begin(), m_eraseStash.end(),
              [](const EraseStash &a, const EraseStash &b) { return a.index < b.index; });

    std::vector<Item *> targets;
    for (auto &s : m_eraseStash) {
        Item *raw = s.item.get();
        targets.push_back(raw);
        const std::size_t idx = std::min(s.index, ly.items.size());
        ly.items.insert(ly.items.begin() + static_cast<std::ptrdiff_t>(idx),
                        std::move(s.item));
    }
    m_eraseStash.clear();

    m_doc->undoStack()->push(new RemoveItemsCommand(
        m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
        std::move(targets), QStringLiteral("Erase")));
}

void Canvas::addTextAt(const QPointF &sp)
{
    bool ok = false;
    const QString text = QInputDialog::getMultiLineText(
        this, tr("Add Text"), tr("Text:"), QString(), &ok);
    if (!ok || text.trimmed().isEmpty())
        return;
    auto t = std::make_unique<TextItem>();
    t->pos   = sp;
    t->text  = text;
    t->color = m_settings.textColor;
    t->font  = m_settings.textFont;
    commitAdd(std::move(t), QStringLiteral("Text"));
}

void Canvas::deleteSelection()
{
    if (!m_doc || m_selection.empty())
        return;
    std::vector<Item *> targets(m_selection.begin(), m_selection.end());
    m_selection.clear();
    m_doc->undoStack()->push(new RemoveItemsCommand(
        m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
        std::move(targets), QStringLiteral("Delete")));
    update();
}

void Canvas::cancelActive()
{
    m_activeStroke.reset();
    m_activeShape.reset();
    m_drawing = false;
    if (m_erasing && m_doc) {
        Layer &ly = m_doc->current().active();
        for (auto &s : m_eraseStash)
            ly.items.push_back(std::move(s.item));
    }
    m_eraseStash.clear();
    m_erasing = false;
    m_movingSelection = false;
    m_rubber = false;
}

void Canvas::updateCursor()
{
    switch (m_settings.tool) {
    case ToolId::Pen:
    case ToolId::Highlighter:
    case ToolId::Line:
    case ToolId::Rectangle:
    case ToolId::Ellipse:
    case ToolId::Laser:
    case ToolId::Select:
        setCursor(Qt::ArrowCursor);   // OS cursor; nib dot painted on top
        break;
    case ToolId::Eraser:
        setCursor(Qt::BlankCursor);
        break;
    case ToolId::Text:
        setCursor(Qt::IBeamCursor);
        break;
    }
}

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/ui/PreferencesDialog.h  (overwrite: laser now glow-only, no fade)
# ---------------------------------------------------------------------------
cat > src/ui/PreferencesDialog.h <<'EOF'
#pragma once

#include <QDialog>
#include <QColor>

#include "canvas/Tools.h"

class QSpinBox;
class QDoubleSpinBox;
class QPushButton;
class QCheckBox;

namespace ib {

class PreferencesDialog : public QDialog {
    Q_OBJECT
public:
    PreferencesDialog(const ToolSettings &s, int autosaveSeconds,
                      QWidget *parent = nullptr);

    ToolSettings toolSettings() const { return m_settings; }
    int autosaveSeconds() const;

private slots:
    void pickPenColor();
    void pickLaserCore();
    void pickLaserGlow();
    void applyAndAccept();

private:
    ToolSettings m_settings;

    QColor m_penColor;
    QColor m_laserCore;
    QColor m_laserGlow;

    QSpinBox       *m_penWidth      = nullptr;
    QPushButton    *m_penColorBtn   = nullptr;
    QDoubleSpinBox *m_hlWidth       = nullptr;
    QDoubleSpinBox *m_hlOpacity     = nullptr;
    QDoubleSpinBox *m_eraserRadius  = nullptr;
    QSpinBox       *m_textSize      = nullptr;
    QSpinBox       *m_autosave      = nullptr;

    QPushButton    *m_laserCoreBtn  = nullptr;
    QPushButton    *m_laserGlowBtn  = nullptr;
    QDoubleSpinBox *m_laserWidth    = nullptr;
    QDoubleSpinBox *m_laserGlowRad  = nullptr;
    QDoubleSpinBox *m_laserInten    = nullptr;
    QCheckBox      *m_laserGlowOn   = nullptr;
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/ui/PreferencesDialog.cpp  (overwrite)
# ---------------------------------------------------------------------------
cat > src/ui/PreferencesDialog.cpp <<'EOF'
#include "ui/PreferencesDialog.h"

#include <QFormLayout>
#include <QVBoxLayout>
#include <QGroupBox>
#include <QDialogButtonBox>
#include <QSpinBox>
#include <QDoubleSpinBox>
#include <QPushButton>
#include <QCheckBox>
#include <QColorDialog>

namespace ib {

static void styleColorButton(QPushButton *b, const QColor &c)
{
    b->setText(c.name(QColor::HexRgb));
    b->setStyleSheet(QString("background-color:%1; color:%2; padding:4px;")
                         .arg(c.name(),
                              c.lightness() > 128 ? "#000000" : "#ffffff"));
}

PreferencesDialog::PreferencesDialog(const ToolSettings &s, int autosaveSeconds,
                                     QWidget *parent)
    : QDialog(parent)
    , m_settings(s)
    , m_penColor(s.penColor)
    , m_laserCore(s.laser.coreColor)
    , m_laserGlow(s.laser.glowColor)
{
    setWindowTitle(tr("Preferences"));
    setModal(true);

    auto *toolsBox = new QGroupBox(tr("Tools"), this);
    auto *form = new QFormLayout(toolsBox);

    m_penWidth = new QSpinBox(this);
    m_penWidth->setRange(1, 64);
    m_penWidth->setValue(qRound(m_settings.penWidth));
    m_penWidth->setSuffix(tr(" px"));
    form->addRow(tr("Pen width:"), m_penWidth);

    m_penColorBtn = new QPushButton(this);
    connect(m_penColorBtn, &QPushButton::clicked, this, &PreferencesDialog::pickPenColor);
    styleColorButton(m_penColorBtn, m_penColor);
    form->addRow(tr("Pen color:"), m_penColorBtn);

    m_hlWidth = new QDoubleSpinBox(this);
    m_hlWidth->setRange(1.0, 120.0);
    m_hlWidth->setValue(m_settings.hlWidth);
    m_hlWidth->setSuffix(tr(" px"));
    form->addRow(tr("Highlighter width:"), m_hlWidth);

    m_hlOpacity = new QDoubleSpinBox(this);
    m_hlOpacity->setRange(0.05, 1.0);
    m_hlOpacity->setSingleStep(0.05);
    m_hlOpacity->setValue(m_settings.hlOpacity);
    form->addRow(tr("Highlighter opacity:"), m_hlOpacity);

    m_eraserRadius = new QDoubleSpinBox(this);
    m_eraserRadius->setRange(2.0, 200.0);
    m_eraserRadius->setValue(m_settings.eraserRadius);
    m_eraserRadius->setSuffix(tr(" px"));
    form->addRow(tr("Eraser radius:"), m_eraserRadius);

    m_textSize = new QSpinBox(this);
    m_textSize->setRange(6, 200);
    m_textSize->setValue(m_settings.textFont.pointSize() > 0
                             ? m_settings.textFont.pointSize() : 18);
    m_textSize->setSuffix(tr(" pt"));
    form->addRow(tr("Text size:"), m_textSize);

    auto *laserBox = new QGroupBox(tr("Laser pen"), this);
    auto *lf = new QFormLayout(laserBox);

    m_laserCoreBtn = new QPushButton(this);
    connect(m_laserCoreBtn, &QPushButton::clicked, this, &PreferencesDialog::pickLaserCore);
    styleColorButton(m_laserCoreBtn, m_laserCore);
    lf->addRow(tr("Core color:"), m_laserCoreBtn);

    m_laserGlowBtn = new QPushButton(this);
    connect(m_laserGlowBtn, &QPushButton::clicked, this, &PreferencesDialog::pickLaserGlow);
    styleColorButton(m_laserGlowBtn, m_laserGlow);
    lf->addRow(tr("Glow color:"), m_laserGlowBtn);

    m_laserWidth = new QDoubleSpinBox(this);
    m_laserWidth->setRange(1.0, 60.0);
    m_laserWidth->setValue(m_settings.laser.width);
    m_laserWidth->setSuffix(tr(" px"));
    lf->addRow(tr("Core width:"), m_laserWidth);

    m_laserGlowRad = new QDoubleSpinBox(this);
    m_laserGlowRad->setRange(0.0, 200.0);
    m_laserGlowRad->setValue(m_settings.laser.glowRadius);
    m_laserGlowRad->setSuffix(tr(" px"));
    lf->addRow(tr("Glow radius:"), m_laserGlowRad);

    m_laserInten = new QDoubleSpinBox(this);
    m_laserInten->setRange(0.1, 1.0);
    m_laserInten->setSingleStep(0.05);
    m_laserInten->setValue(m_settings.laser.intensity);
    lf->addRow(tr("Intensity:"), m_laserInten);

    m_laserGlowOn = new QCheckBox(tr("Enable glow"), this);
    m_laserGlowOn->setChecked(m_settings.laser.glowEnabled);
    lf->addRow(QString(), m_laserGlowOn);

    auto *appBox = new QGroupBox(tr("Application"), this);
    auto *af = new QFormLayout(appBox);
    m_autosave = new QSpinBox(this);
    m_autosave->setRange(0, 3600);
    m_autosave->setValue(autosaveSeconds);
    m_autosave->setSuffix(tr(" s (0 = off)"));
    af->addRow(tr("Autosave interval:"), m_autosave);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel,
                                         this);
    connect(buttons, &QDialogButtonBox::accepted, this, &PreferencesDialog::applyAndAccept);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);

    auto *root = new QVBoxLayout(this);
    root->addWidget(toolsBox);
    root->addWidget(laserBox);
    root->addWidget(appBox);
    root->addWidget(buttons);
}

void PreferencesDialog::pickPenColor()
{
    const QColor c = QColorDialog::getColor(m_penColor, this, tr("Pen Color"));
    if (c.isValid()) { m_penColor = c; styleColorButton(m_penColorBtn, c); }
}

void PreferencesDialog::pickLaserCore()
{
    const QColor c = QColorDialog::getColor(m_laserCore, this, tr("Laser Core Color"));
    if (c.isValid()) { m_laserCore = c; styleColorButton(m_laserCoreBtn, c); }
}

void PreferencesDialog::pickLaserGlow()
{
    const QColor c = QColorDialog::getColor(m_laserGlow, this, tr("Laser Glow Color"));
    if (c.isValid()) { m_laserGlow = c; styleColorButton(m_laserGlowBtn, c); }
}

int PreferencesDialog::autosaveSeconds() const
{
    return m_autosave->value();
}

void PreferencesDialog::applyAndAccept()
{
    m_settings.penWidth     = m_penWidth->value();
    m_settings.penColor     = m_penColor;
    m_settings.hlWidth      = m_hlWidth->value();
    m_settings.hlOpacity    = m_hlOpacity->value();
    m_settings.eraserRadius = m_eraserRadius->value();

    QFont f = m_settings.textFont;
    f.setPointSize(m_textSize->value());
    m_settings.textFont = f;

    m_settings.laser.coreColor   = m_laserCore;
    m_settings.laser.glowColor   = m_laserGlow;
    m_settings.laser.width       = m_laserWidth->value();
    m_settings.laser.glowRadius  = m_laserGlowRad->value();
    m_settings.laser.intensity   = m_laserInten->value();
    m_settings.laser.glowEnabled = m_laserGlowOn->isChecked();

    accept();
}

} // namespace ib
EOF

log "PART 10 complete: vector laser pen (permanent, crisp at any zoom) + nib-dot cursor"


# ---------------------------------------------------------------------------
#  PART 11 : Laser "vanishing mode" — fade + clear when the pen leaves the
#            tablet's range (proximity-out). Re-entering range cancels the fade.
#            Vanishing OFF = permanent ink (unchanged). Overwrites Laser.h,
#            Canvas.{h,cpp}, PreferencesDialog.{h,cpp}. No model/MainWindow edits.
# ---------------------------------------------------------------------------
log "PART 11: laser vanishing mode (proximity-out fade)"

# ---------------------------------------------------------------------------
#  src/canvas/Laser.h  (overwrite: add vanish settings + fade alpha)
# ---------------------------------------------------------------------------
cat > src/canvas/Laser.h <<'EOF'
#pragma once

#include <QColor>
#include <QPointF>
#include <QPolygonF>
#include <QVector>
#include <QPen>
#include <QPainter>

namespace ib {

// Sizes are in SCENE units (so the ink scales with zoom like real ink).
struct LaserSettings {
    QColor coreColor  = QColor(255, 255, 255); // hot core
    QColor glowColor  = QColor(255, 45, 40);   // warm glow (Apple-like)
    double width      = 6.0;    // core stroke width
    double glowRadius = 10.0;   // extra glow width around the core
    double intensity  = 1.0;    // overall opacity (0..1)
    bool   glowEnabled = true;

    // Vanishing mode: when the pen leaves the tablet's range, wait
    // vanishDelayMs then fade the ink out over fadeDurationMs and clear it.
    bool   vanishMode     = false;
    int    vanishDelayMs  = 250;
    int    fadeDurationMs = 600;
};

// Permanent, vector, scene-space laser ink. Painted while the canvas painter
// is already translated+scaled, so everything stays crisp at any zoom.
class LaserInk {
public:
    void setSettings(const LaserSettings &s) { m_s = s; }
    const LaserSettings &settings() const { return m_s; }

    void begin(const QPointF &scenePt)
    {
        m_active.clear();
        m_active << scenePt;
        m_activeOn = true;
    }
    void extend(const QPointF &scenePt)
    {
        if (m_activeOn)
            m_active << scenePt;
    }
    void end()
    {
        if (m_activeOn && !m_active.isEmpty())
            m_strokes.push_back({ m_active, m_s });
        m_active.clear();
        m_activeOn = false;
    }

    void clear()
    {
        m_strokes.clear();
        m_active.clear();
        m_activeOn = false;
    }

    bool isEmpty() const { return m_strokes.isEmpty() && !m_activeOn; }

    // Global fade multiplier used by vanishing mode (1 = fully visible).
    void   setFadeAlpha(double a) { m_fadeAlpha = qBound(0.0, a, 1.0); }
    double fadeAlpha() const { return m_fadeAlpha; }
    void   resetFade() { m_fadeAlpha = 1.0; }

    void paint(QPainter &p) const
    {
        for (const auto &st : m_strokes)
            drawStroke(p, st.pts, st.s, m_fadeAlpha);
        if (m_activeOn && !m_active.isEmpty())
            drawStroke(p, m_active, m_s, m_fadeAlpha);
    }

private:
    struct Stroke {
        QPolygonF     pts;
        LaserSettings s;
    };

    static void strokePass(QPainter &p, const QPolygonF &pts,
                           const QColor &col, double w)
    {
        QPen pen(col);
        pen.setWidthF(qMax(0.1, w));
        pen.setCapStyle(Qt::RoundCap);
        pen.setJoinStyle(Qt::RoundJoin);
        p.setPen(pen);
        p.setBrush(Qt::NoBrush);
        if (pts.size() == 1)
            p.drawPoint(pts.first());
        else
            p.drawPolyline(pts);
    }

    static void drawStroke(QPainter &p, const QPolygonF &pts,
                           const LaserSettings &s, double fade)
    {
        if (pts.isEmpty() || fade <= 0.0)
            return;
        p.save();
        p.setRenderHint(QPainter::Antialiasing, true);

        if (s.glowEnabled && s.glowRadius > 0.0) {
            QColor g1 = s.glowColor; g1.setAlphaF(0.30 * s.intensity * fade);
            strokePass(p, pts, g1, s.width + 2.0 * s.glowRadius);
            QColor g2 = s.glowColor; g2.setAlphaF(0.50 * s.intensity * fade);
            strokePass(p, pts, g2, s.width + s.glowRadius);
        }

        QColor c = s.coreColor;
        c.setAlphaF(s.intensity * fade);
        strokePass(p, pts, c, s.width);

        p.restore();
    }

    LaserSettings   m_s;
    QVector<Stroke> m_strokes;
    QPolygonF       m_active;
    bool            m_activeOn = false;
    double          m_fadeAlpha = 1.0;
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/canvas/Canvas.h  (overwrite: add proximity event filter + fade timer)
# ---------------------------------------------------------------------------
cat > src/canvas/Canvas.h <<'EOF'
#pragma once

#include <QWidget>
#include <QPointF>
#include <QElapsedTimer>
#include <memory>
#include <vector>

#include "model/Document.h"
#include "model/StrokeItem.h"
#include "model/ShapeItem.h"
#include "canvas/Tools.h"

class QPaintEvent;
class QMouseEvent;
class QTabletEvent;
class QWheelEvent;
class QKeyEvent;
class QTimer;

namespace ib {

class Canvas : public QWidget {
    Q_OBJECT
public:
    explicit Canvas(QWidget *parent = nullptr);

    void setDocument(Document *doc);
    Document *document() const { return m_doc; }

    ToolSettings &settings() { return m_settings; }
    const ToolSettings &settings() const { return m_settings; }

    void setTool(ToolId t);
    ToolId tool() const { return m_settings.tool; }

    bool hasSelection() const { return !m_selection.empty(); }
    double zoomPercent() const { return m_scale * 100.0; }

public slots:
    void zoomIn();
    void zoomOut();
    void resetView();
    void zoomToFit();
    void deleteSelection();
    void selectAll();
    void clearSelection();
    void clearLaser();
    void refresh() { update(); }

signals:
    void viewChanged();
    void toolChanged(ib::ToolId tool);
    void cursorMoved(QPointF scenePos);

protected:
    void paintEvent(QPaintEvent *) override;
    void mousePressEvent(QMouseEvent *e) override;
    void mouseMoveEvent(QMouseEvent *e) override;
    void mouseReleaseEvent(QMouseEvent *e) override;
    void tabletEvent(QTabletEvent *e) override;
    void wheelEvent(QWheelEvent *e) override;
    void keyPressEvent(QKeyEvent *e) override;
    void keyReleaseEvent(QKeyEvent *e) override;
    void leaveEvent(QEvent *e) override;
    bool eventFilter(QObject *obj, QEvent *ev) override;

private:
    enum class Action { Press, Move, Release };

    struct EraseStash {
        std::size_t index;
        ItemPtr     item;
    };

    QPointF widgetToScene(const QPointF &p) const { return (p - m_translate) / m_scale; }
    QPointF sceneToWidget(const QPointF &s) const { return s * m_scale + m_translate; }

    void handlePointer(Action a, const QPointF &widgetPos, double pressure,
                       Qt::KeyboardModifiers mods, bool eraserTip);
    void handleSelect(Action a, const QPointF &sp, Qt::KeyboardModifiers mods);

    void commitAdd(ItemPtr item, const QString &text);
    void eraseAt(const QPointF &sp);
    void finishErase();
    void addTextAt(const QPointF &sp);
    void cancelActive();
    void zoomAround(const QPointF &widgetPos, double factor);
    void updateCursor();

    void startVanish();
    void stopVanish();
    void onFadeTick();

    void drawBackground(QPainter &p, const Page &pg, const QRectF &area);
    void drawSelection(QPainter &p);
    void drawBrushPreview(QPainter &p);

    bool hitTest(Item *it, const QPointF &sp, double radius) const;
    Item *topItemAt(const QPointF &sp);
    void selectInRect(const QRectF &r, bool add);
    void setSelectionSingle(Item *it);
    void addToSelection(Item *it);
    void removeFromSelection(Item *it);

    Document    *m_doc = nullptr;
    ToolSettings m_settings;

    double  m_scale = 1.0;
    QPointF m_translate;

    bool   m_panning = false;
    bool   m_spaceDown = false;
    QPoint m_lastPanPos;

    std::unique_ptr<StrokeItem> m_activeStroke;
    std::unique_ptr<ShapeItem>  m_activeShape;
    bool m_drawing = false;

    bool m_erasing = false;
    std::vector<EraseStash> m_eraseStash;

    std::vector<Item *> m_selection;
    bool    m_movingSelection = false;
    QPointF m_moveStartScene;
    QPointF m_moveAccum;
    bool    m_rubber = false;
    QPointF m_rubberStartScene;
    QRectF  m_rubberRect;

    QPointF m_cursorWidget;
    bool    m_hoverValid = false;

    LaserInk       m_laser;
    QTimer        *m_fadeTimer = nullptr;
    QElapsedTimer  m_fadeClock;
    bool           m_fading = false;
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/canvas/Canvas.cpp  (overwrite)
# ---------------------------------------------------------------------------
cat > src/canvas/Canvas.cpp <<'EOF'
#include "canvas/Canvas.h"

#include "core/Commands.h"
#include "model/TextItem.h"
#include "model/ImageItem.h"

#include <QApplication>
#include <QTimer>
#include <QPainter>
#include <QPen>
#include <QRadialGradient>
#include <QMouseEvent>
#include <QTabletEvent>
#include <QWheelEvent>
#include <QKeyEvent>
#include <QPointingDevice>
#include <QInputDialog>
#include <QUndoStack>
#include <QLineF>
#include <algorithm>
#include <cmath>

namespace ib {

static const double kPi = 3.14159265358979323846;

static double distToSegment(const QPointF &p, const QPointF &a, const QPointF &b)
{
    const QPointF ab = b - a;
    const double len2 = ab.x() * ab.x() + ab.y() * ab.y();
    if (len2 <= 1e-9)
        return std::hypot(p.x() - a.x(), p.y() - a.y());
    double t = ((p.x() - a.x()) * ab.x() + (p.y() - a.y()) * ab.y()) / len2;
    t = std::max(0.0, std::min(1.0, t));
    const QPointF proj(a.x() + t * ab.x(), a.y() + t * ab.y());
    return std::hypot(p.x() - proj.x(), p.y() - proj.y());
}

static QPointF constrainShape(const QPointF &a, const QPointF &b, ShapeKind kind)
{
    const QPointF d = b - a;
    if (kind == ShapeKind::Line) {
        double ang = std::atan2(d.y(), d.x());
        const double step = kPi / 4.0;
        ang = std::round(ang / step) * step;
        const double len = std::hypot(d.x(), d.y());
        return a + QPointF(std::cos(ang) * len, std::sin(ang) * len);
    }
    const double s = std::max(std::abs(d.x()), std::abs(d.y()));
    return a + QPointF(d.x() < 0 ? -s : s, d.y() < 0 ? -s : s);
}

Canvas::Canvas(QWidget *parent)
    : QWidget(parent)
{
    setFocusPolicy(Qt::StrongFocus);
    setMouseTracking(true);
    setAttribute(Qt::WA_TabletTracking, true);
    setAutoFillBackground(false);
    m_translate = QPointF(40, 40);

    // Tablet proximity events are delivered to the application object, so we
    // watch them via an app-level filter to drive laser vanishing mode.
    qApp->installEventFilter(this);

    m_fadeTimer = new QTimer(this);
    m_fadeTimer->setInterval(16);
    connect(m_fadeTimer, &QTimer::timeout, this, &Canvas::onFadeTick);

    updateCursor();
}

void Canvas::setDocument(Document *doc)
{
    if (m_doc == doc)
        return;
    if (m_doc) {
        m_doc->disconnect(this);
        if (m_doc->undoStack())
            m_doc->undoStack()->disconnect(this);
    }
    m_doc = doc;
    cancelActive();
    m_selection.clear();

    if (m_doc) {
        connect(m_doc, &Document::currentPageChanged, this, [this](int) {
            cancelActive(); m_selection.clear(); update();
        });
        connect(m_doc, &Document::pagesChanged, this, [this]() {
            cancelActive(); m_selection.clear(); update();
        });
        connect(m_doc, &Document::contentChanged, this, [this]() { update(); });
        if (m_doc->undoStack()) {
            connect(m_doc->undoStack(), &QUndoStack::indexChanged, this, [this](int) {
                m_selection.clear(); cancelActive(); update();
            });
        }
    }
    update();
}

void Canvas::setTool(ToolId t)
{
    cancelActive();
    m_settings.tool = t;
    updateCursor();
    emit toolChanged(t);
    update();
}

void Canvas::clearLaser()
{
    stopVanish();
    m_laser.clear();
    update();
}

// ---- laser vanishing -------------------------------------------------------
void Canvas::startVanish()
{
    if (m_laser.isEmpty())
        return;
    m_fading = true;
    m_laser.resetFade();
    m_fadeClock.restart();
    if (!m_fadeTimer->isActive())
        m_fadeTimer->start();
    update();
}

void Canvas::stopVanish()
{
    m_fading = false;
    if (m_fadeTimer->isActive())
        m_fadeTimer->stop();
    m_laser.resetFade();
    update();
}

void Canvas::onFadeTick()
{
    if (!m_fading) {
        m_fadeTimer->stop();
        return;
    }
    const qint64 el = m_fadeClock.elapsed();
    const int delay = qMax(0, m_settings.laser.vanishDelayMs);
    const int dur   = qMax(1, m_settings.laser.fadeDurationMs);

    if (el <= delay) {
        m_laser.setFadeAlpha(1.0);
        update();
        return;
    }
    const double t = static_cast<double>(el - delay) / static_cast<double>(dur);
    if (t >= 1.0) {
        m_laser.clear();
        m_laser.resetFade();
        m_fading = false;
        m_fadeTimer->stop();
        update();
        return;
    }
    m_laser.setFadeAlpha(1.0 - t);
    update();
}

bool Canvas::eventFilter(QObject *obj, QEvent *ev)
{
    if (ev->type() == QEvent::TabletLeaveProximity) {
        if (m_settings.tool == ToolId::Laser && m_settings.laser.vanishMode &&
            !m_drawing && !m_laser.isEmpty())
            startVanish();
    } else if (ev->type() == QEvent::TabletEnterProximity) {
        // Pen back in range: cancel the fade and restore the ink.
        if (m_fading)
            stopVanish();
    }
    return QWidget::eventFilter(obj, ev);
}

// ---- view ------------------------------------------------------------------
void Canvas::zoomAround(const QPointF &widgetPos, double factor)
{
    const QPointF before = widgetToScene(widgetPos);
    m_scale = qBound(0.05, m_scale * factor, 40.0);
    m_translate = widgetPos - before * m_scale;
    update();
    emit viewChanged();
}

void Canvas::zoomIn()  { zoomAround(QPointF(width() / 2.0, height() / 2.0), 1.2); }
void Canvas::zoomOut() { zoomAround(QPointF(width() / 2.0, height() / 2.0), 1.0 / 1.2); }

void Canvas::resetView()
{
    m_scale = 1.0;
    m_translate = QPointF(40, 40);
    update();
    emit viewChanged();
}

void Canvas::zoomToFit()
{
    if (!m_doc) { update(); return; }
    QRectF b = m_doc->current().contentBounds();
    if (b.isNull()) { resetView(); return; }
    b.adjust(-40, -40, 40, 40);
    const double sx = width()  / b.width();
    const double sy = height() / b.height();
    m_scale = qBound(0.05, qMin(sx, sy), 40.0);
    m_translate = QPointF(width() / 2.0, height() / 2.0) - b.center() * m_scale;
    update();
    emit viewChanged();
}

// ---- painting --------------------------------------------------------------
void Canvas::drawBackground(QPainter &p, const Page &pg, const QRectF &area)
{
    if (pg.background == BackgroundKind::Blank)
        return;
    const double s = qMax(4.0, pg.gridSpacing);
    QPen pen(pg.gridColor);
    pen.setCosmetic(true);
    pen.setWidth(1);
    p.setPen(pen);

    const double startX = std::floor(area.left() / s) * s;
    const double startY = std::floor(area.top() / s) * s;

    if (pg.background == BackgroundKind::Grid) {
        for (double x = startX; x <= area.right(); x += s)
            p.drawLine(QPointF(x, area.top()), QPointF(x, area.bottom()));
        for (double y = startY; y <= area.bottom(); y += s)
            p.drawLine(QPointF(area.left(), y), QPointF(area.right(), y));
    } else if (pg.background == BackgroundKind::Lines) {
        for (double y = startY; y <= area.bottom(); y += s)
            p.drawLine(QPointF(area.left(), y), QPointF(area.right(), y));
    } else {
        p.setPen(Qt::NoPen);
        p.setBrush(pg.gridColor);
        for (double x = startX; x <= area.right(); x += s)
            for (double y = startY; y <= area.bottom(); y += s)
                p.drawEllipse(QPointF(x, y), 1.3, 1.3);
    }
}

void Canvas::drawSelection(QPainter &p)
{
    if (m_selection.empty())
        return;
    QPen pen(QColor(60, 120, 220));
    pen.setCosmetic(true);
    pen.setStyle(Qt::DashLine);
    pen.setWidth(1);
    p.setPen(pen);
    p.setBrush(Qt::NoBrush);
    for (Item *it : m_selection)
        p.drawRect(it->boundingRect());
}

void Canvas::drawBrushPreview(QPainter &p)
{
    if (!m_hoverValid || m_panning)
        return;

    if (m_settings.tool == ToolId::Eraser) {
        const double r = m_settings.eraserRadius * m_scale;
        QPen pen(QColor(70, 70, 70));
        pen.setStyle(Qt::DashLine);
        p.setPen(pen);
        p.setBrush(Qt::NoBrush);
        p.drawEllipse(m_cursorWidget, r, r);
        return;
    }

    QColor col;
    double w = 0.0;
    bool laser = false;
    switch (m_settings.tool) {
    case ToolId::Pen:         col = m_settings.penColor;   w = m_settings.penWidth;   break;
    case ToolId::Highlighter: col = m_settings.hlColor;    w = m_settings.hlWidth;    break;
    case ToolId::Line:
    case ToolId::Rectangle:
    case ToolId::Ellipse:     col = m_settings.shapeColor; w = m_settings.shapeWidth; break;
    case ToolId::Laser:       col = m_settings.laser.coreColor; w = m_settings.laser.width; laser = true; break;
    default: return;
    }

    const double r = qMax(1.5, w * 0.5 * m_scale);

    p.save();
    p.setRenderHint(QPainter::Antialiasing, true);

    if (laser && m_settings.laser.glowEnabled) {
        const double gr = r + m_settings.laser.glowRadius * m_scale;
        QRadialGradient g(m_cursorWidget, gr);
        QColor g0 = m_settings.laser.glowColor; g0.setAlphaF(0.55 * m_settings.laser.intensity);
        QColor g1 = m_settings.laser.glowColor; g1.setAlphaF(0.0);
        g.setColorAt(0.0, g0);
        g.setColorAt(1.0, g1);
        p.setPen(Qt::NoPen);
        p.setBrush(g);
        p.drawEllipse(m_cursorWidget, gr, gr);
    }

    QColor fill = col;
    fill.setAlphaF(laser ? m_settings.laser.intensity : 0.9);
    const QColor outline = (col.lightness() > 128) ? QColor(0, 0, 0, 170)
                                                   : QColor(255, 255, 255, 190);
    QPen pen(outline);
    pen.setWidthF(1.0);
    p.setPen(pen);
    p.setBrush(fill);
    p.drawEllipse(m_cursorWidget, r, r);
    p.restore();
}

void Canvas::paintEvent(QPaintEvent *)
{
    QPainter p(this);
    p.fillRect(rect(), QColor(90, 93, 99));
    if (!m_doc)
        return;

    p.save();
    p.translate(m_translate);
    p.scale(m_scale, m_scale);

    const QRectF sceneRect =
        QRectF(widgetToScene(QPointF(0, 0)),
               widgetToScene(QPointF(width(), height()))).normalized();

    Page &pg = m_doc->current();
    p.fillRect(sceneRect, pg.bgColor);
    drawBackground(p, pg, sceneRect);

    p.setRenderHint(QPainter::Antialiasing, true);
    p.setRenderHint(QPainter::TextAntialiasing, true);

    for (const auto &ly : pg.layers) {
        if (!ly.visible)
            continue;
        p.save();
        if (ly.opacity < 1.0)
            p.setOpacity(ly.opacity);
        for (const auto &it : ly.items)
            it->paint(p);
        p.restore();
    }

    if (m_activeStroke) m_activeStroke->paint(p);
    if (m_activeShape)  m_activeShape->paint(p);

    if (!m_laser.isEmpty())
        m_laser.paint(p);

    drawSelection(p);

    if (m_rubber) {
        QPen pen(QColor(60, 120, 220));
        pen.setCosmetic(true);
        pen.setStyle(Qt::DashLine);
        p.setPen(pen);
        p.setBrush(QColor(60, 120, 220, 40));
        p.drawRect(m_rubberRect);
    }

    p.restore();

    drawBrushPreview(p);
}

// ---- input -----------------------------------------------------------------
void Canvas::mousePressEvent(QMouseEvent *e)
{
    m_cursorWidget = e->position();
    m_hoverValid = true;
    if (e->button() == Qt::MiddleButton ||
        (m_spaceDown && e->button() == Qt::LeftButton)) {
        m_panning = true;
        m_lastPanPos = e->position().toPoint();
        setCursor(Qt::ClosedHandCursor);
        return;
    }
    if (e->button() == Qt::LeftButton)
        handlePointer(Action::Press, e->position(), 1.0, e->modifiers(), false);
}

void Canvas::mouseMoveEvent(QMouseEvent *e)
{
    m_cursorWidget = e->position();
    m_hoverValid = true;
    if (m_panning) {
        const QPoint d = e->position().toPoint() - m_lastPanPos;
        m_lastPanPos = e->position().toPoint();
        m_translate += QPointF(d);
        update();
        emit viewChanged();
        return;
    }
    handlePointer(Action::Move, e->position(), 1.0, e->modifiers(), false);
    update();
    emit cursorMoved(widgetToScene(e->position()));
}

void Canvas::mouseReleaseEvent(QMouseEvent *e)
{
    m_cursorWidget = e->position();
    if (m_panning &&
        (e->button() == Qt::MiddleButton || e->button() == Qt::LeftButton)) {
        m_panning = false;
        updateCursor();
        return;
    }
    if (e->button() == Qt::LeftButton)
        handlePointer(Action::Release, e->position(), 1.0, e->modifiers(), false);
}

void Canvas::tabletEvent(QTabletEvent *e)
{
    const bool eraserTip =
        e->pointerType() == QPointingDevice::PointerType::Eraser;
    double pr = e->pressure();
    if (pr <= 0.0)
        pr = 1.0;
    m_cursorWidget = e->position();
    m_hoverValid = true;

    switch (e->type()) {
    case QEvent::TabletPress:
        handlePointer(Action::Press, e->position(), pr, e->modifiers(), eraserTip);
        break;
    case QEvent::TabletMove:
        handlePointer(Action::Move, e->position(), pr, e->modifiers(), eraserTip);
        emit cursorMoved(widgetToScene(e->position()));
        update();
        break;
    case QEvent::TabletRelease:
        handlePointer(Action::Release, e->position(), pr, e->modifiers(), eraserTip);
        break;
    default:
        break;
    }
    e->accept();
}

void Canvas::wheelEvent(QWheelEvent *e)
{
    const double factor = std::pow(1.0015, e->angleDelta().y());
    zoomAround(e->position(), factor);
    e->accept();
}

void Canvas::keyPressEvent(QKeyEvent *e)
{
    if (e->key() == Qt::Key_Space) {
        m_spaceDown = true;
        setCursor(Qt::OpenHandCursor);
        e->accept();
        return;
    }
    if (e->key() == Qt::Key_Delete || e->key() == Qt::Key_Backspace) {
        deleteSelection();
        e->accept();
        return;
    }
    if (e->key() == Qt::Key_Escape) {
        cancelActive();
        clearSelection();
        clearLaser();
        e->accept();
        return;
    }
    QWidget::keyPressEvent(e);
}

void Canvas::keyReleaseEvent(QKeyEvent *e)
{
    if (e->key() == Qt::Key_Space) {
        m_spaceDown = false;
        updateCursor();
        e->accept();
        return;
    }
    QWidget::keyReleaseEvent(e);
}

void Canvas::leaveEvent(QEvent *e)
{
    m_hoverValid = false;
    update();
    QWidget::leaveEvent(e);
}

// ---- pointer dispatch ------------------------------------------------------
void Canvas::handlePointer(Action a, const QPointF &widgetPos, double pressure,
                           Qt::KeyboardModifiers mods, bool eraserTip)
{
    if (!m_doc)
        return;
    const QPointF sp = widgetToScene(widgetPos);
    m_cursorWidget = widgetPos;

    const ToolId t = eraserTip ? ToolId::Eraser : m_settings.tool;

    if (t == ToolId::Laser) {
        m_laser.setSettings(m_settings.laser);
        if (a == Action::Press) {
            stopVanish();              // a new stroke cancels any pending fade
            m_drawing = true;
            m_laser.begin(sp);
        } else if (a == Action::Move && m_drawing) {
            m_laser.extend(sp);
        } else if (a == Action::Release) {
            m_laser.end();
            m_drawing = false;
        }
        update();
        return;
    }

    Layer &ly = m_doc->current().active();
    if (ly.locked)
        return;

    switch (t) {
    case ToolId::Pen:
    case ToolId::Highlighter: {
        const bool hl = (t == ToolId::Highlighter);
        if (a == Action::Press) {
            m_drawing = true;
            m_activeStroke = std::make_unique<StrokeItem>();
            m_activeStroke->highlighter   = hl;
            m_activeStroke->color         = hl ? m_settings.hlColor : m_settings.penColor;
            m_activeStroke->baseWidth     = hl ? m_settings.hlWidth : m_settings.penWidth;
            m_activeStroke->opacity       = hl ? m_settings.hlOpacity : 1.0;
            m_activeStroke->pressureWidth = hl ? false : m_settings.penPressure;
            m_activeStroke->addPoint(StrokePoint(sp.x(), sp.y(), pressure));
            update();
        } else if (a == Action::Move && m_drawing && m_activeStroke) {
            m_activeStroke->addPoint(StrokePoint(sp.x(), sp.y(), pressure));
            update();
        } else if (a == Action::Release && m_drawing) {
            if (m_activeStroke && !m_activeStroke->isEmpty())
                commitAdd(std::move(m_activeStroke),
                          hl ? QStringLiteral("Highlight") : QStringLiteral("Draw"));
            m_activeStroke.reset();
            m_drawing = false;
            update();
        }
        break;
    }
    case ToolId::Eraser: {
        if (a == Action::Press) { m_erasing = true; m_eraseStash.clear(); eraseAt(sp); update(); }
        else if (a == Action::Move && m_erasing) { eraseAt(sp); update(); }
        else if (a == Action::Release && m_erasing) { finishErase(); m_erasing = false; update(); }
        break;
    }
    case ToolId::Line:
    case ToolId::Rectangle:
    case ToolId::Ellipse: {
        if (a == Action::Press) {
            m_activeShape = std::make_unique<ShapeItem>();
            m_activeShape->kind = (t == ToolId::Line) ? ShapeKind::Line
                                : (t == ToolId::Rectangle) ? ShapeKind::Rectangle
                                : ShapeKind::Ellipse;
            m_activeShape->color  = m_settings.shapeColor;
            m_activeShape->width  = m_settings.shapeWidth;
            m_activeShape->filled = m_settings.shapeFilled;
            m_activeShape->fill   = m_settings.shapeFill;
            m_activeShape->p1 = sp;
            m_activeShape->p2 = sp;
            m_drawing = true;
            update();
        } else if (a == Action::Move && m_drawing && m_activeShape) {
            m_activeShape->p2 = (mods & Qt::ShiftModifier)
                ? constrainShape(m_activeShape->p1, sp, m_activeShape->kind)
                : sp;
            update();
        } else if (a == Action::Release && m_drawing) {
            if (m_activeShape) {
                const QLineF diag(m_activeShape->p1, m_activeShape->p2);
                if (diag.length() >= 2.0)
                    commitAdd(std::move(m_activeShape), QStringLiteral("Shape"));
            }
            m_activeShape.reset();
            m_drawing = false;
            update();
        }
        break;
    }
    case ToolId::Text: {
        if (a == Action::Press)
            addTextAt(sp);
        break;
    }
    case ToolId::Select: {
        handleSelect(a, sp, mods);
        break;
    }
    case ToolId::Laser:
        break;
    }
}

// ---- selection -------------------------------------------------------------
void Canvas::handleSelect(Action a, const QPointF &sp, Qt::KeyboardModifiers mods)
{
    if (a == Action::Press) {
        Item *hit = topItemAt(sp);
        if (hit) {
            const bool already =
                std::find(m_selection.begin(), m_selection.end(), hit) != m_selection.end();
            if (mods & Qt::ShiftModifier) {
                if (already) removeFromSelection(hit);
                else addToSelection(hit);
            } else if (!already) {
                setSelectionSingle(hit);
            }
            m_movingSelection = true;
            m_moveStartScene = sp;
            m_moveAccum = QPointF(0, 0);
        } else {
            if (!(mods & Qt::ShiftModifier))
                clearSelection();
            m_rubber = true;
            m_rubberStartScene = sp;
            m_rubberRect = QRectF(sp, sp);
        }
        update();
    } else if (a == Action::Move) {
        if (m_movingSelection && !m_selection.empty()) {
            const QPointF d = sp - m_moveStartScene;
            const QPointF step = d - m_moveAccum;
            for (Item *it : m_selection)
                it->translate(step);
            m_moveAccum = d;
            update();
        } else if (m_rubber) {
            m_rubberRect = QRectF(m_rubberStartScene, sp).normalized();
            update();
        }
    } else {
        if (m_movingSelection) {
            m_movingSelection = false;
            if (!m_selection.empty() &&
                (qAbs(m_moveAccum.x()) > 0.01 || qAbs(m_moveAccum.y()) > 0.01)) {
                for (Item *it : m_selection)
                    it->translate(-m_moveAccum);
                std::vector<Item *> targets(m_selection.begin(), m_selection.end());
                m_doc->undoStack()->push(new TranslateItemsCommand(
                    m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
                    targets, m_moveAccum, QStringLiteral("Move")));
            }
            m_moveAccum = QPointF(0, 0);
        } else if (m_rubber) {
            m_rubber = false;
            selectInRect(m_rubberRect, (mods & Qt::ShiftModifier));
        }
        update();
    }
}

void Canvas::setSelectionSingle(Item *it)
{
    m_selection.clear();
    if (it) m_selection.push_back(it);
}

void Canvas::addToSelection(Item *it)
{
    if (it && std::find(m_selection.begin(), m_selection.end(), it) == m_selection.end())
        m_selection.push_back(it);
}

void Canvas::removeFromSelection(Item *it)
{
    m_selection.erase(std::remove(m_selection.begin(), m_selection.end(), it),
                      m_selection.end());
}

void Canvas::clearSelection()
{
    if (m_selection.empty())
        return;
    m_selection.clear();
    update();
}

void Canvas::selectAll()
{
    if (!m_doc)
        return;
    m_selection.clear();
    for (auto &it : m_doc->current().active().items)
        m_selection.push_back(it.get());
    update();
}

void Canvas::selectInRect(const QRectF &r, bool add)
{
    if (!m_doc)
        return;
    if (!add)
        m_selection.clear();
    for (auto &it : m_doc->current().active().items) {
        if (r.intersects(it->boundingRect()) &&
            std::find(m_selection.begin(), m_selection.end(), it.get()) == m_selection.end())
            m_selection.push_back(it.get());
    }
}

Item *Canvas::topItemAt(const QPointF &sp)
{
    if (!m_doc)
        return nullptr;
    Layer &ly = m_doc->current().active();
    const double r = 6.0 / qMax(0.0001, m_scale);
    for (int i = static_cast<int>(ly.items.size()) - 1; i >= 0; --i) {
        Item *it = ly.items[static_cast<std::size_t>(i)].get();
        if (hitTest(it, sp, r))
            return it;
    }
    return nullptr;
}

bool Canvas::hitTest(Item *it, const QPointF &sp, double radius) const
{
    const QRectF bb = it->boundingRect().adjusted(-radius, -radius, radius, radius);
    if (!bb.contains(sp))
        return false;

    if (it->type() == ItemType::Stroke) {
        const StrokeItem *s = static_cast<const StrokeItem *>(it);
        const double tol = radius + s->baseWidth * 0.5;
        if (s->points.size() == 1)
            return QLineF(sp, s->points.first().pos()).length() <= tol;
        for (int i = 1; i < s->points.size(); ++i)
            if (distToSegment(sp, s->points[i - 1].pos(), s->points[i].pos()) <= tol)
                return true;
        return false;
    }
    return true;
}

// ---- helpers ---------------------------------------------------------------
void Canvas::commitAdd(ItemPtr item, const QString &text)
{
    if (!m_doc || !item)
        return;
    m_doc->undoStack()->push(new AddItemCommand(
        m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
        std::move(item), text));
}

void Canvas::eraseAt(const QPointF &sp)
{
    if (!m_doc)
        return;
    Layer &ly = m_doc->current().active();
    const double r = m_settings.eraserRadius;
    for (std::size_t i = 0; i < ly.items.size();) {
        if (hitTest(ly.items[i].get(), sp, r)) {
            m_eraseStash.push_back({i, std::move(ly.items[i])});
            ly.items.erase(ly.items.begin() + static_cast<std::ptrdiff_t>(i));
        } else {
            ++i;
        }
    }
}

void Canvas::finishErase()
{
    if (!m_doc || m_eraseStash.empty())
        return;
    Layer &ly = m_doc->current().active();
    std::sort(m_eraseStash.begin(), m_eraseStash.end(),
              [](const EraseStash &a, const EraseStash &b) { return a.index < b.index; });

    std::vector<Item *> targets;
    for (auto &s : m_eraseStash) {
        Item *raw = s.item.get();
        targets.push_back(raw);
        const std::size_t idx = std::min(s.index, ly.items.size());
        ly.items.insert(ly.items.begin() + static_cast<std::ptrdiff_t>(idx),
                        std::move(s.item));
    }
    m_eraseStash.clear();

    m_doc->undoStack()->push(new RemoveItemsCommand(
        m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
        std::move(targets), QStringLiteral("Erase")));
}

void Canvas::addTextAt(const QPointF &sp)
{
    bool ok = false;
    const QString text = QInputDialog::getMultiLineText(
        this, tr("Add Text"), tr("Text:"), QString(), &ok);
    if (!ok || text.trimmed().isEmpty())
        return;
    auto t = std::make_unique<TextItem>();
    t->pos   = sp;
    t->text  = text;
    t->color = m_settings.textColor;
    t->font  = m_settings.textFont;
    commitAdd(std::move(t), QStringLiteral("Text"));
}

void Canvas::deleteSelection()
{
    if (!m_doc || m_selection.empty())
        return;
    std::vector<Item *> targets(m_selection.begin(), m_selection.end());
    m_selection.clear();
    m_doc->undoStack()->push(new RemoveItemsCommand(
        m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
        std::move(targets), QStringLiteral("Delete")));
    update();
}

void Canvas::cancelActive()
{
    m_activeStroke.reset();
    m_activeShape.reset();
    m_drawing = false;
    if (m_erasing && m_doc) {
        Layer &ly = m_doc->current().active();
        for (auto &s : m_eraseStash)
            ly.items.push_back(std::move(s.item));
    }
    m_eraseStash.clear();
    m_erasing = false;
    m_movingSelection = false;
    m_rubber = false;
}

void Canvas::updateCursor()
{
    switch (m_settings.tool) {
    case ToolId::Pen:
    case ToolId::Highlighter:
    case ToolId::Line:
    case ToolId::Rectangle:
    case ToolId::Ellipse:
    case ToolId::Laser:
    case ToolId::Select:
        setCursor(Qt::ArrowCursor);
        break;
    case ToolId::Eraser:
        setCursor(Qt::BlankCursor);
        break;
    case ToolId::Text:
        setCursor(Qt::IBeamCursor);
        break;
    }
}

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/ui/PreferencesDialog.h  (overwrite: add vanish controls)
# ---------------------------------------------------------------------------
cat > src/ui/PreferencesDialog.h <<'EOF'
#pragma once

#include <QDialog>
#include <QColor>

#include "canvas/Tools.h"

class QSpinBox;
class QDoubleSpinBox;
class QPushButton;
class QCheckBox;

namespace ib {

class PreferencesDialog : public QDialog {
    Q_OBJECT
public:
    PreferencesDialog(const ToolSettings &s, int autosaveSeconds,
                      QWidget *parent = nullptr);

    ToolSettings toolSettings() const { return m_settings; }
    int autosaveSeconds() const;

private slots:
    void pickPenColor();
    void pickLaserCore();
    void pickLaserGlow();
    void applyAndAccept();

private:
    ToolSettings m_settings;

    QColor m_penColor;
    QColor m_laserCore;
    QColor m_laserGlow;

    QSpinBox       *m_penWidth      = nullptr;
    QPushButton    *m_penColorBtn   = nullptr;
    QDoubleSpinBox *m_hlWidth       = nullptr;
    QDoubleSpinBox *m_hlOpacity     = nullptr;
    QDoubleSpinBox *m_eraserRadius  = nullptr;
    QSpinBox       *m_textSize      = nullptr;
    QSpinBox       *m_autosave      = nullptr;

    QPushButton    *m_laserCoreBtn  = nullptr;
    QPushButton    *m_laserGlowBtn  = nullptr;
    QDoubleSpinBox *m_laserWidth    = nullptr;
    QDoubleSpinBox *m_laserGlowRad  = nullptr;
    QDoubleSpinBox *m_laserInten    = nullptr;
    QCheckBox      *m_laserGlowOn   = nullptr;
    QCheckBox      *m_laserVanish   = nullptr;
    QSpinBox       *m_laserDelay    = nullptr;
    QSpinBox       *m_laserFade     = nullptr;
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/ui/PreferencesDialog.cpp  (overwrite)
# ---------------------------------------------------------------------------
cat > src/ui/PreferencesDialog.cpp <<'EOF'
#include "ui/PreferencesDialog.h"

#include <QFormLayout>
#include <QVBoxLayout>
#include <QGroupBox>
#include <QDialogButtonBox>
#include <QSpinBox>
#include <QDoubleSpinBox>
#include <QPushButton>
#include <QCheckBox>
#include <QColorDialog>

namespace ib {

static void styleColorButton(QPushButton *b, const QColor &c)
{
    b->setText(c.name(QColor::HexRgb));
    b->setStyleSheet(QString("background-color:%1; color:%2; padding:4px;")
                         .arg(c.name(),
                              c.lightness() > 128 ? "#000000" : "#ffffff"));
}

PreferencesDialog::PreferencesDialog(const ToolSettings &s, int autosaveSeconds,
                                     QWidget *parent)
    : QDialog(parent)
    , m_settings(s)
    , m_penColor(s.penColor)
    , m_laserCore(s.laser.coreColor)
    , m_laserGlow(s.laser.glowColor)
{
    setWindowTitle(tr("Preferences"));
    setModal(true);

    auto *toolsBox = new QGroupBox(tr("Tools"), this);
    auto *form = new QFormLayout(toolsBox);

    m_penWidth = new QSpinBox(this);
    m_penWidth->setRange(1, 64);
    m_penWidth->setValue(qRound(m_settings.penWidth));
    m_penWidth->setSuffix(tr(" px"));
    form->addRow(tr("Pen width:"), m_penWidth);

    m_penColorBtn = new QPushButton(this);
    connect(m_penColorBtn, &QPushButton::clicked, this, &PreferencesDialog::pickPenColor);
    styleColorButton(m_penColorBtn, m_penColor);
    form->addRow(tr("Pen color:"), m_penColorBtn);

    m_hlWidth = new QDoubleSpinBox(this);
    m_hlWidth->setRange(1.0, 120.0);
    m_hlWidth->setValue(m_settings.hlWidth);
    m_hlWidth->setSuffix(tr(" px"));
    form->addRow(tr("Highlighter width:"), m_hlWidth);

    m_hlOpacity = new QDoubleSpinBox(this);
    m_hlOpacity->setRange(0.05, 1.0);
    m_hlOpacity->setSingleStep(0.05);
    m_hlOpacity->setValue(m_settings.hlOpacity);
    form->addRow(tr("Highlighter opacity:"), m_hlOpacity);

    m_eraserRadius = new QDoubleSpinBox(this);
    m_eraserRadius->setRange(2.0, 200.0);
    m_eraserRadius->setValue(m_settings.eraserRadius);
    m_eraserRadius->setSuffix(tr(" px"));
    form->addRow(tr("Eraser radius:"), m_eraserRadius);

    m_textSize = new QSpinBox(this);
    m_textSize->setRange(6, 200);
    m_textSize->setValue(m_settings.textFont.pointSize() > 0
                             ? m_settings.textFont.pointSize() : 18);
    m_textSize->setSuffix(tr(" pt"));
    form->addRow(tr("Text size:"), m_textSize);

    auto *laserBox = new QGroupBox(tr("Laser pen"), this);
    auto *lf = new QFormLayout(laserBox);

    m_laserCoreBtn = new QPushButton(this);
    connect(m_laserCoreBtn, &QPushButton::clicked, this, &PreferencesDialog::pickLaserCore);
    styleColorButton(m_laserCoreBtn, m_laserCore);
    lf->addRow(tr("Core color:"), m_laserCoreBtn);

    m_laserGlowBtn = new QPushButton(this);
    connect(m_laserGlowBtn, &QPushButton::clicked, this, &PreferencesDialog::pickLaserGlow);
    styleColorButton(m_laserGlowBtn, m_laserGlow);
    lf->addRow(tr("Glow color:"), m_laserGlowBtn);

    m_laserWidth = new QDoubleSpinBox(this);
    m_laserWidth->setRange(1.0, 60.0);
    m_laserWidth->setValue(m_settings.laser.width);
    m_laserWidth->setSuffix(tr(" px"));
    lf->addRow(tr("Core width:"), m_laserWidth);

    m_laserGlowRad = new QDoubleSpinBox(this);
    m_laserGlowRad->setRange(0.0, 200.0);
    m_laserGlowRad->setValue(m_settings.laser.glowRadius);
    m_laserGlowRad->setSuffix(tr(" px"));
    lf->addRow(tr("Glow radius:"), m_laserGlowRad);

    m_laserInten = new QDoubleSpinBox(this);
    m_laserInten->setRange(0.1, 1.0);
    m_laserInten->setSingleStep(0.05);
    m_laserInten->setValue(m_settings.laser.intensity);
    lf->addRow(tr("Intensity:"), m_laserInten);

    m_laserGlowOn = new QCheckBox(tr("Enable glow"), this);
    m_laserGlowOn->setChecked(m_settings.laser.glowEnabled);
    lf->addRow(QString(), m_laserGlowOn);

    m_laserVanish = new QCheckBox(tr("Vanishing mode (fade after pen leaves range)"), this);
    m_laserVanish->setChecked(m_settings.laser.vanishMode);
    lf->addRow(QString(), m_laserVanish);

    m_laserDelay = new QSpinBox(this);
    m_laserDelay->setRange(0, 5000);
    m_laserDelay->setSingleStep(50);
    m_laserDelay->setValue(m_settings.laser.vanishDelayMs);
    m_laserDelay->setSuffix(tr(" ms"));
    lf->addRow(tr("Vanish delay:"), m_laserDelay);

    m_laserFade = new QSpinBox(this);
    m_laserFade->setRange(50, 10000);
    m_laserFade->setSingleStep(50);
    m_laserFade->setValue(m_settings.laser.fadeDurationMs);
    m_laserFade->setSuffix(tr(" ms"));
    lf->addRow(tr("Fade duration:"), m_laserFade);

    auto *appBox = new QGroupBox(tr("Application"), this);
    auto *af = new QFormLayout(appBox);
    m_autosave = new QSpinBox(this);
    m_autosave->setRange(0, 3600);
    m_autosave->setValue(autosaveSeconds);
    m_autosave->setSuffix(tr(" s (0 = off)"));
    af->addRow(tr("Autosave interval:"), m_autosave);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel,
                                         this);
    connect(buttons, &QDialogButtonBox::accepted, this, &PreferencesDialog::applyAndAccept);
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);

    auto *root = new QVBoxLayout(this);
    root->addWidget(toolsBox);
    root->addWidget(laserBox);
    root->addWidget(appBox);
    root->addWidget(buttons);
}

void PreferencesDialog::pickPenColor()
{
    const QColor c = QColorDialog::getColor(m_penColor, this, tr("Pen Color"));
    if (c.isValid()) { m_penColor = c; styleColorButton(m_penColorBtn, c); }
}

void PreferencesDialog::pickLaserCore()
{
    const QColor c = QColorDialog::getColor(m_laserCore, this, tr("Laser Core Color"));
    if (c.isValid()) { m_laserCore = c; styleColorButton(m_laserCoreBtn, c); }
}

void PreferencesDialog::pickLaserGlow()
{
    const QColor c = QColorDialog::getColor(m_laserGlow, this, tr("Laser Glow Color"));
    if (c.isValid()) { m_laserGlow = c; styleColorButton(m_laserGlowBtn, c); }
}

int PreferencesDialog::autosaveSeconds() const
{
    return m_autosave->value();
}

void PreferencesDialog::applyAndAccept()
{
    m_settings.penWidth     = m_penWidth->value();
    m_settings.penColor     = m_penColor;
    m_settings.hlWidth      = m_hlWidth->value();
    m_settings.hlOpacity    = m_hlOpacity->value();
    m_settings.eraserRadius = m_eraserRadius->value();

    QFont f = m_settings.textFont;
    f.setPointSize(m_textSize->value());
    m_settings.textFont = f;

    m_settings.laser.coreColor     = m_laserCore;
    m_settings.laser.glowColor     = m_laserGlow;
    m_settings.laser.width         = m_laserWidth->value();
    m_settings.laser.glowRadius    = m_laserGlowRad->value();
    m_settings.laser.intensity     = m_laserInten->value();
    m_settings.laser.glowEnabled   = m_laserGlowOn->isChecked();
    m_settings.laser.vanishMode    = m_laserVanish->isChecked();
    m_settings.laser.vanishDelayMs = m_laserDelay->value();
    m_settings.laser.fadeDurationMs= m_laserFade->value();

    accept();
}

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  PART 12 : Permanent laser = a real glow StrokeItem (erasable / undoable /
#            saveable / selectable, exactly like the pen). Vanishing mode
#            stays the transient overlay from Part 11.
#            Overwrites StrokeItem.{h,cpp} and Canvas.cpp only.
# ---------------------------------------------------------------------------
log "PART 12: erasable/undoable/saveable glow-stroke laser"

# ---------------------------------------------------------------------------
#  src/model/StrokeItem.h  (overwrite: add glow style fields)
# ---------------------------------------------------------------------------
cat > src/model/StrokeItem.h <<'EOF'
#pragma once

#include <QColor>
#include <QVector>

#include "model/Item.h"

namespace ib {

class StrokeItem : public Item {
public:
    QVector<StrokePoint> points;
    QColor  color         = QColor(24, 24, 24);
    double  baseWidth     = 3.0;
    double  opacity       = 1.0;
    bool    highlighter   = false;
    bool    pressureWidth = true;

    // Laser glow style (used by the Laser tool in permanent mode). When glow
    // is true, a translucent glowColor underlay is drawn beneath the core.
    bool    glow          = false;
    QColor  glowColor     = QColor(255, 45, 40);
    double  glowRadius    = 10.0;

    ItemType type() const override { return ItemType::Stroke; }
    QRectF boundingRect() const override;
    void paint(QPainter &p) const override;
    std::unique_ptr<Item> clone() const override;
    void translate(const QPointF &delta) override;
    void write(QJsonObject &obj) const override;
    void read(const QJsonObject &obj) override;

    void addPoint(const StrokePoint &pt) { points.push_back(pt); }
    bool isEmpty() const { return points.isEmpty(); }
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/model/StrokeItem.cpp  (overwrite: glow rendering + serialization)
# ---------------------------------------------------------------------------
cat > src/model/StrokeItem.cpp <<'EOF'
#include "model/StrokeItem.h"

#include <QPainter>
#include <QPainterPath>
#include <QJsonArray>
#include <algorithm>

namespace ib {

static QJsonArray colorToJson(const QColor &c)
{
    QJsonArray a;
    a.append(c.red());
    a.append(c.green());
    a.append(c.blue());
    a.append(c.alpha());
    return a;
}

static QColor colorFromJson(const QJsonValue &v, const QColor &def)
{
    const QJsonArray a = v.toArray();
    if (a.size() < 3)
        return def;
    const int alpha = a.size() >= 4 ? a.at(3).toInt(255) : 255;
    return QColor(a.at(0).toInt(), a.at(1).toInt(), a.at(2).toInt(), alpha);
}

QRectF StrokeItem::boundingRect() const
{
    if (points.isEmpty())
        return QRectF();

    double minX = points.first().x, maxX = minX;
    double minY = points.first().y, maxY = minY;
    for (const auto &pt : points) {
        minX = std::min(minX, pt.x);
        maxX = std::max(maxX, pt.x);
        minY = std::min(minY, pt.y);
        maxY = std::max(maxY, pt.y);
    }
    const double m = baseWidth * 0.5 + (glow ? glowRadius : 0.0) + 1.0;
    return QRectF(QPointF(minX, minY), QPointF(maxX, maxY)).adjusted(-m, -m, m, m);
}

void StrokeItem::paint(QPainter &p) const
{
    if (points.isEmpty())
        return;

    p.save();

    QColor c = color;
    c.setAlphaF(c.alphaF() * qBound(0.0, opacity, 1.0));

    // Glow underlay (laser pen), drawn beneath the core stroke.
    if (glow && glowRadius > 0.0) {
        p.setRenderHint(QPainter::Antialiasing, true);
        const double baseAlpha = qBound(0.0, opacity, 1.0);
        const auto glowPass = [&](double extra, double a) {
            QColor gc = glowColor;
            gc.setAlphaF(a * baseAlpha);
            QPen gp(gc);
            gp.setWidthF(qMax(0.3, baseWidth + extra));
            gp.setCapStyle(Qt::RoundCap);
            gp.setJoinStyle(Qt::RoundJoin);
            p.setPen(gp);
            p.setBrush(Qt::NoBrush);
            if (points.size() == 1) {
                p.drawPoint(points.first().pos());
            } else {
                QPainterPath path(points.first().pos());
                for (int i = 1; i < points.size(); ++i)
                    path.lineTo(points[i].pos());
                p.drawPath(path);
            }
        };
        glowPass(2.0 * glowRadius, 0.30);
        glowPass(glowRadius, 0.50);
    }

    if (points.size() == 1) {
        const double pr = pressureWidth ? qMax(0.15, points.first().pressure) : 1.0;
        const double w  = qMax(0.3, baseWidth * pr);
        p.setPen(Qt::NoPen);
        p.setBrush(c);
        p.drawEllipse(points.first().pos(), w * 0.5, w * 0.5);
        p.restore();
        return;
    }

    QPen pen(c);
    pen.setCapStyle(Qt::RoundCap);
    pen.setJoinStyle(Qt::RoundJoin);

    if (pressureWidth) {
        for (int i = 1; i < points.size(); ++i) {
            const double pr = 0.5 * (points[i - 1].pressure + points[i].pressure);
            pen.setWidthF(qMax(0.3, baseWidth * pr));
            p.setPen(pen);
            p.drawLine(points[i - 1].pos(), points[i].pos());
        }
    } else {
        pen.setWidthF(baseWidth);
        p.setPen(pen);
        QPainterPath path(points.first().pos());
        for (int i = 1; i < points.size(); ++i)
            path.lineTo(points[i].pos());
        p.drawPath(path);
    }

    p.restore();
}

std::unique_ptr<Item> StrokeItem::clone() const
{
    return std::make_unique<StrokeItem>(*this);
}

void StrokeItem::translate(const QPointF &delta)
{
    for (auto &pt : points) {
        pt.x += delta.x();
        pt.y += delta.y();
    }
}

void StrokeItem::write(QJsonObject &obj) const
{
    obj["type"]          = "stroke";
    obj["color"]         = colorToJson(color);
    obj["baseWidth"]     = baseWidth;
    obj["opacity"]       = opacity;
    obj["highlighter"]   = highlighter;
    obj["pressureWidth"] = pressureWidth;

    if (glow) {
        obj["glow"]       = true;
        obj["glowColor"]  = colorToJson(glowColor);
        obj["glowRadius"] = glowRadius;
    }

    QJsonArray pts;
    for (const auto &pt : points) {
        QJsonArray a;
        a.append(pt.x);
        a.append(pt.y);
        a.append(pt.pressure);
        pts.append(a);
    }
    obj["points"] = pts;
}

void StrokeItem::read(const QJsonObject &obj)
{
    color         = colorFromJson(obj.value("color"), QColor(24, 24, 24));
    baseWidth     = obj.value("baseWidth").toDouble(3.0);
    opacity       = obj.value("opacity").toDouble(1.0);
    highlighter   = obj.value("highlighter").toBool(false);
    pressureWidth = obj.value("pressureWidth").toBool(true);

    glow          = obj.value("glow").toBool(false);
    glowColor     = colorFromJson(obj.value("glowColor"), QColor(255, 45, 40));
    glowRadius    = obj.value("glowRadius").toDouble(10.0);

    points.clear();
    const QJsonArray pts = obj.value("points").toArray();
    for (const auto &v : pts) {
        const QJsonArray a = v.toArray();
        if (a.size() >= 2) {
            const double pr = a.size() >= 3 ? a.at(2).toDouble(1.0) : 1.0;
            points.push_back(StrokePoint(a.at(0).toDouble(), a.at(1).toDouble(), pr));
        }
    }
}

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/canvas/Canvas.cpp  (overwrite: permanent laser draws a real glow stroke)
# ---------------------------------------------------------------------------
cat > src/canvas/Canvas.cpp <<'EOF'
#include "canvas/Canvas.h"

#include "core/Commands.h"
#include "model/TextItem.h"
#include "model/ImageItem.h"

#include <QApplication>
#include <QTimer>
#include <QPainter>
#include <QPen>
#include <QRadialGradient>
#include <QMouseEvent>
#include <QTabletEvent>
#include <QWheelEvent>
#include <QKeyEvent>
#include <QPointingDevice>
#include <QInputDialog>
#include <QUndoStack>
#include <QLineF>
#include <algorithm>
#include <cmath>

namespace ib {

static const double kPi = 3.14159265358979323846;

static double distToSegment(const QPointF &p, const QPointF &a, const QPointF &b)
{
    const QPointF ab = b - a;
    const double len2 = ab.x() * ab.x() + ab.y() * ab.y();
    if (len2 <= 1e-9)
        return std::hypot(p.x() - a.x(), p.y() - a.y());
    double t = ((p.x() - a.x()) * ab.x() + (p.y() - a.y()) * ab.y()) / len2;
    t = std::max(0.0, std::min(1.0, t));
    const QPointF proj(a.x() + t * ab.x(), a.y() + t * ab.y());
    return std::hypot(p.x() - proj.x(), p.y() - proj.y());
}

static QPointF constrainShape(const QPointF &a, const QPointF &b, ShapeKind kind)
{
    const QPointF d = b - a;
    if (kind == ShapeKind::Line) {
        double ang = std::atan2(d.y(), d.x());
        const double step = kPi / 4.0;
        ang = std::round(ang / step) * step;
        const double len = std::hypot(d.x(), d.y());
        return a + QPointF(std::cos(ang) * len, std::sin(ang) * len);
    }
    const double s = std::max(std::abs(d.x()), std::abs(d.y()));
    return a + QPointF(d.x() < 0 ? -s : s, d.y() < 0 ? -s : s);
}

Canvas::Canvas(QWidget *parent)
    : QWidget(parent)
{
    setFocusPolicy(Qt::StrongFocus);
    setMouseTracking(true);
    setAttribute(Qt::WA_TabletTracking, true);
    setAutoFillBackground(false);
    m_translate = QPointF(40, 40);

    // Tablet proximity events are delivered to the application object, so we
    // watch them via an app-level filter to drive laser vanishing mode.
    qApp->installEventFilter(this);

    m_fadeTimer = new QTimer(this);
    m_fadeTimer->setInterval(16);
    connect(m_fadeTimer, &QTimer::timeout, this, &Canvas::onFadeTick);

    updateCursor();
}

void Canvas::setDocument(Document *doc)
{
    if (m_doc == doc)
        return;
    if (m_doc) {
        m_doc->disconnect(this);
        if (m_doc->undoStack())
            m_doc->undoStack()->disconnect(this);
    }
    m_doc = doc;
    cancelActive();
    m_selection.clear();

    if (m_doc) {
        connect(m_doc, &Document::currentPageChanged, this, [this](int) {
            cancelActive(); m_selection.clear(); update();
        });
        connect(m_doc, &Document::pagesChanged, this, [this]() {
            cancelActive(); m_selection.clear(); update();
        });
        connect(m_doc, &Document::contentChanged, this, [this]() { update(); });
        if (m_doc->undoStack()) {
            connect(m_doc->undoStack(), &QUndoStack::indexChanged, this, [this](int) {
                m_selection.clear(); cancelActive(); update();
            });
        }
    }
    update();
}

void Canvas::setTool(ToolId t)
{
    cancelActive();
    m_settings.tool = t;
    updateCursor();
    emit toolChanged(t);
    update();
}

void Canvas::clearLaser()
{
    stopVanish();
    m_laser.clear();
    update();
}

// ---- laser vanishing -------------------------------------------------------
void Canvas::startVanish()
{
    if (m_laser.isEmpty())
        return;
    m_fading = true;
    m_laser.resetFade();
    m_fadeClock.restart();
    if (!m_fadeTimer->isActive())
        m_fadeTimer->start();
    update();
}

void Canvas::stopVanish()
{
    m_fading = false;
    if (m_fadeTimer->isActive())
        m_fadeTimer->stop();
    m_laser.resetFade();
    update();
}

void Canvas::onFadeTick()
{
    if (!m_fading) {
        m_fadeTimer->stop();
        return;
    }
    const qint64 el = m_fadeClock.elapsed();
    const int delay = qMax(0, m_settings.laser.vanishDelayMs);
    const int dur   = qMax(1, m_settings.laser.fadeDurationMs);

    if (el <= delay) {
        m_laser.setFadeAlpha(1.0);
        update();
        return;
    }
    const double t = static_cast<double>(el - delay) / static_cast<double>(dur);
    if (t >= 1.0) {
        m_laser.clear();
        m_laser.resetFade();
        m_fading = false;
        m_fadeTimer->stop();
        update();
        return;
    }
    m_laser.setFadeAlpha(1.0 - t);
    update();
}

bool Canvas::eventFilter(QObject *obj, QEvent *ev)
{
    if (ev->type() == QEvent::TabletLeaveProximity) {
        if (m_settings.tool == ToolId::Laser && m_settings.laser.vanishMode &&
            !m_drawing && !m_laser.isEmpty())
            startVanish();
    } else if (ev->type() == QEvent::TabletEnterProximity) {
        if (m_fading)
            stopVanish();
    }
    return QWidget::eventFilter(obj, ev);
}

// ---- view ------------------------------------------------------------------
void Canvas::zoomAround(const QPointF &widgetPos, double factor)
{
    const QPointF before = widgetToScene(widgetPos);
    m_scale = qBound(0.05, m_scale * factor, 40.0);
    m_translate = widgetPos - before * m_scale;
    update();
    emit viewChanged();
}

void Canvas::zoomIn()  { zoomAround(QPointF(width() / 2.0, height() / 2.0), 1.2); }
void Canvas::zoomOut() { zoomAround(QPointF(width() / 2.0, height() / 2.0), 1.0 / 1.2); }

void Canvas::resetView()
{
    m_scale = 1.0;
    m_translate = QPointF(40, 40);
    update();
    emit viewChanged();
}

void Canvas::zoomToFit()
{
    if (!m_doc) { update(); return; }
    QRectF b = m_doc->current().contentBounds();
    if (b.isNull()) { resetView(); return; }
    b.adjust(-40, -40, 40, 40);
    const double sx = width()  / b.width();
    const double sy = height() / b.height();
    m_scale = qBound(0.05, qMin(sx, sy), 40.0);
    m_translate = QPointF(width() / 2.0, height() / 2.0) - b.center() * m_scale;
    update();
    emit viewChanged();
}

// ---- painting --------------------------------------------------------------
void Canvas::drawBackground(QPainter &p, const Page &pg, const QRectF &area)
{
    if (pg.background == BackgroundKind::Blank)
        return;
    const double s = qMax(4.0, pg.gridSpacing);
    QPen pen(pg.gridColor);
    pen.setCosmetic(true);
    pen.setWidth(1);
    p.setPen(pen);

    const double startX = std::floor(area.left() / s) * s;
    const double startY = std::floor(area.top() / s) * s;

    if (pg.background == BackgroundKind::Grid) {
        for (double x = startX; x <= area.right(); x += s)
            p.drawLine(QPointF(x, area.top()), QPointF(x, area.bottom()));
        for (double y = startY; y <= area.bottom(); y += s)
            p.drawLine(QPointF(area.left(), y), QPointF(area.right(), y));
    } else if (pg.background == BackgroundKind::Lines) {
        for (double y = startY; y <= area.bottom(); y += s)
            p.drawLine(QPointF(area.left(), y), QPointF(area.right(), y));
    } else {
        p.setPen(Qt::NoPen);
        p.setBrush(pg.gridColor);
        for (double x = startX; x <= area.right(); x += s)
            for (double y = startY; y <= area.bottom(); y += s)
                p.drawEllipse(QPointF(x, y), 1.3, 1.3);
    }
}

void Canvas::drawSelection(QPainter &p)
{
    if (m_selection.empty())
        return;
    QPen pen(QColor(60, 120, 220));
    pen.setCosmetic(true);
    pen.setStyle(Qt::DashLine);
    pen.setWidth(1);
    p.setPen(pen);
    p.setBrush(Qt::NoBrush);
    for (Item *it : m_selection)
        p.drawRect(it->boundingRect());
}

void Canvas::drawBrushPreview(QPainter &p)
{
    if (!m_hoverValid || m_panning)
        return;

    if (m_settings.tool == ToolId::Eraser) {
        const double r = m_settings.eraserRadius * m_scale;
        QPen pen(QColor(70, 70, 70));
        pen.setStyle(Qt::DashLine);
        p.setPen(pen);
        p.setBrush(Qt::NoBrush);
        p.drawEllipse(m_cursorWidget, r, r);
        return;
    }

    QColor col;
    double w = 0.0;
    bool laser = false;
    switch (m_settings.tool) {
    case ToolId::Pen:         col = m_settings.penColor;   w = m_settings.penWidth;   break;
    case ToolId::Highlighter: col = m_settings.hlColor;    w = m_settings.hlWidth;    break;
    case ToolId::Line:
    case ToolId::Rectangle:
    case ToolId::Ellipse:     col = m_settings.shapeColor; w = m_settings.shapeWidth; break;
    case ToolId::Laser:       col = m_settings.laser.coreColor; w = m_settings.laser.width; laser = true; break;
    default: return;
    }

    const double r = qMax(1.5, w * 0.5 * m_scale);

    p.save();
    p.setRenderHint(QPainter::Antialiasing, true);

    if (laser && m_settings.laser.glowEnabled) {
        const double gr = r + m_settings.laser.glowRadius * m_scale;
        QRadialGradient g(m_cursorWidget, gr);
        QColor g0 = m_settings.laser.glowColor; g0.setAlphaF(0.55 * m_settings.laser.intensity);
        QColor g1 = m_settings.laser.glowColor; g1.setAlphaF(0.0);
        g.setColorAt(0.0, g0);
        g.setColorAt(1.0, g1);
        p.setPen(Qt::NoPen);
        p.setBrush(g);
        p.drawEllipse(m_cursorWidget, gr, gr);
    }

    QColor fill = col;
    fill.setAlphaF(laser ? m_settings.laser.intensity : 0.9);
    const QColor outline = (col.lightness() > 128) ? QColor(0, 0, 0, 170)
                                                   : QColor(255, 255, 255, 190);
    QPen pen(outline);
    pen.setWidthF(1.0);
    p.setPen(pen);
    p.setBrush(fill);
    p.drawEllipse(m_cursorWidget, r, r);
    p.restore();
}

void Canvas::paintEvent(QPaintEvent *)
{
    QPainter p(this);
    p.fillRect(rect(), QColor(90, 93, 99));
    if (!m_doc)
        return;

    p.save();
    p.translate(m_translate);
    p.scale(m_scale, m_scale);

    const QRectF sceneRect =
        QRectF(widgetToScene(QPointF(0, 0)),
               widgetToScene(QPointF(width(), height()))).normalized();

    Page &pg = m_doc->current();
    p.fillRect(sceneRect, pg.bgColor);
    drawBackground(p, pg, sceneRect);

    p.setRenderHint(QPainter::Antialiasing, true);
    p.setRenderHint(QPainter::TextAntialiasing, true);

    for (const auto &ly : pg.layers) {
        if (!ly.visible)
            continue;
        p.save();
        if (ly.opacity < 1.0)
            p.setOpacity(ly.opacity);
        for (const auto &it : ly.items)
            it->paint(p);
        p.restore();
    }

    if (m_activeStroke) m_activeStroke->paint(p);
    if (m_activeShape)  m_activeShape->paint(p);

    if (!m_laser.isEmpty())
        m_laser.paint(p);

    drawSelection(p);

    if (m_rubber) {
        QPen pen(QColor(60, 120, 220));
        pen.setCosmetic(true);
        pen.setStyle(Qt::DashLine);
        p.setPen(pen);
        p.setBrush(QColor(60, 120, 220, 40));
        p.drawRect(m_rubberRect);
    }

    p.restore();

    drawBrushPreview(p);
}

// ---- input -----------------------------------------------------------------
void Canvas::mousePressEvent(QMouseEvent *e)
{
    m_cursorWidget = e->position();
    m_hoverValid = true;
    if (e->button() == Qt::MiddleButton ||
        (m_spaceDown && e->button() == Qt::LeftButton)) {
        m_panning = true;
        m_lastPanPos = e->position().toPoint();
        setCursor(Qt::ClosedHandCursor);
        return;
    }
    if (e->button() == Qt::LeftButton)
        handlePointer(Action::Press, e->position(), 1.0, e->modifiers(), false);
}

void Canvas::mouseMoveEvent(QMouseEvent *e)
{
    m_cursorWidget = e->position();
    m_hoverValid = true;
    if (m_panning) {
        const QPoint d = e->position().toPoint() - m_lastPanPos;
        m_lastPanPos = e->position().toPoint();
        m_translate += QPointF(d);
        update();
        emit viewChanged();
        return;
    }
    handlePointer(Action::Move, e->position(), 1.0, e->modifiers(), false);
    update();
    emit cursorMoved(widgetToScene(e->position()));
}

void Canvas::mouseReleaseEvent(QMouseEvent *e)
{
    m_cursorWidget = e->position();
    if (m_panning &&
        (e->button() == Qt::MiddleButton || e->button() == Qt::LeftButton)) {
        m_panning = false;
        updateCursor();
        return;
    }
    if (e->button() == Qt::LeftButton)
        handlePointer(Action::Release, e->position(), 1.0, e->modifiers(), false);
}

void Canvas::tabletEvent(QTabletEvent *e)
{
    const bool eraserTip =
        e->pointerType() == QPointingDevice::PointerType::Eraser;
    double pr = e->pressure();
    if (pr <= 0.0)
        pr = 1.0;
    m_cursorWidget = e->position();
    m_hoverValid = true;

    switch (e->type()) {
    case QEvent::TabletPress:
        handlePointer(Action::Press, e->position(), pr, e->modifiers(), eraserTip);
        break;
    case QEvent::TabletMove:
        handlePointer(Action::Move, e->position(), pr, e->modifiers(), eraserTip);
        emit cursorMoved(widgetToScene(e->position()));
        update();
        break;
    case QEvent::TabletRelease:
        handlePointer(Action::Release, e->position(), pr, e->modifiers(), eraserTip);
        break;
    default:
        break;
    }
    e->accept();
}

void Canvas::wheelEvent(QWheelEvent *e)
{
    const double factor = std::pow(1.0015, e->angleDelta().y());
    zoomAround(e->position(), factor);
    e->accept();
}

void Canvas::keyPressEvent(QKeyEvent *e)
{
    if (e->key() == Qt::Key_Space) {
        m_spaceDown = true;
        setCursor(Qt::OpenHandCursor);
        e->accept();
        return;
    }
    if (e->key() == Qt::Key_Delete || e->key() == Qt::Key_Backspace) {
        deleteSelection();
        e->accept();
        return;
    }
    if (e->key() == Qt::Key_Escape) {
        cancelActive();
        clearSelection();
        clearLaser();
        e->accept();
        return;
    }
    QWidget::keyPressEvent(e);
}

void Canvas::keyReleaseEvent(QKeyEvent *e)
{
    if (e->key() == Qt::Key_Space) {
        m_spaceDown = false;
        updateCursor();
        e->accept();
        return;
    }
    QWidget::keyReleaseEvent(e);
}

void Canvas::leaveEvent(QEvent *e)
{
    m_hoverValid = false;
    update();
    QWidget::leaveEvent(e);
}

// ---- pointer dispatch ------------------------------------------------------
void Canvas::handlePointer(Action a, const QPointF &widgetPos, double pressure,
                           Qt::KeyboardModifiers mods, bool eraserTip)
{
    if (!m_doc)
        return;
    const QPointF sp = widgetToScene(widgetPos);
    m_cursorWidget = widgetPos;

    const ToolId t = eraserTip ? ToolId::Eraser : m_settings.tool;

    if (t == ToolId::Laser) {
        // Vanishing mode: transient overlay that fades when the pen leaves range.
        if (m_settings.laser.vanishMode) {
            m_laser.setSettings(m_settings.laser);
            if (a == Action::Press) {
                stopVanish();
                m_drawing = true;
                m_laser.begin(sp);
            } else if (a == Action::Move && m_drawing) {
                m_laser.extend(sp);
            } else if (a == Action::Release) {
                m_laser.end();
                m_drawing = false;
            }
            update();
            return;
        }

        // Permanent mode: a real glow stroke on the active layer — fully
        // erasable, undoable, saveable and selectable, exactly like the pen.
        Layer &lly = m_doc->current().active();
        if (lly.locked)
            return;
        if (a == Action::Press) {
            m_drawing = true;
            m_activeStroke = std::make_unique<StrokeItem>();
            m_activeStroke->highlighter   = false;
            m_activeStroke->pressureWidth = false;
            m_activeStroke->color         = m_settings.laser.coreColor;
            m_activeStroke->baseWidth     = m_settings.laser.width;
            m_activeStroke->opacity       = qBound(0.0, m_settings.laser.intensity, 1.0);
            m_activeStroke->glow          = m_settings.laser.glowEnabled;
            m_activeStroke->glowColor     = m_settings.laser.glowColor;
            m_activeStroke->glowRadius    = m_settings.laser.glowRadius;
            m_activeStroke->addPoint(StrokePoint(sp.x(), sp.y(), pressure));
            update();
        } else if (a == Action::Move && m_drawing && m_activeStroke) {
            m_activeStroke->addPoint(StrokePoint(sp.x(), sp.y(), pressure));
            update();
        } else if (a == Action::Release && m_drawing) {
            if (m_activeStroke && !m_activeStroke->isEmpty())
                commitAdd(std::move(m_activeStroke), QStringLiteral("Laser"));
            m_activeStroke.reset();
            m_drawing = false;
            update();
        }
        return;
    }

    Layer &ly = m_doc->current().active();
    if (ly.locked)
        return;

    switch (t) {
    case ToolId::Pen:
    case ToolId::Highlighter: {
        const bool hl = (t == ToolId::Highlighter);
        if (a == Action::Press) {
            m_drawing = true;
            m_activeStroke = std::make_unique<StrokeItem>();
            m_activeStroke->highlighter   = hl;
            m_activeStroke->color         = hl ? m_settings.hlColor : m_settings.penColor;
            m_activeStroke->baseWidth     = hl ? m_settings.hlWidth : m_settings.penWidth;
            m_activeStroke->opacity       = hl ? m_settings.hlOpacity : 1.0;
            m_activeStroke->pressureWidth = hl ? false : m_settings.penPressure;
            m_activeStroke->addPoint(StrokePoint(sp.x(), sp.y(), pressure));
            update();
        } else if (a == Action::Move && m_drawing && m_activeStroke) {
            m_activeStroke->addPoint(StrokePoint(sp.x(), sp.y(), pressure));
            update();
        } else if (a == Action::Release && m_drawing) {
            if (m_activeStroke && !m_activeStroke->isEmpty())
                commitAdd(std::move(m_activeStroke),
                          hl ? QStringLiteral("Highlight") : QStringLiteral("Draw"));
            m_activeStroke.reset();
            m_drawing = false;
            update();
        }
        break;
    }
    case ToolId::Eraser: {
        if (a == Action::Press) { m_erasing = true; m_eraseStash.clear(); eraseAt(sp); update(); }
        else if (a == Action::Move && m_erasing) { eraseAt(sp); update(); }
        else if (a == Action::Release && m_erasing) { finishErase(); m_erasing = false; update(); }
        break;
    }
    case ToolId::Line:
    case ToolId::Rectangle:
    case ToolId::Ellipse: {
        if (a == Action::Press) {
            m_activeShape = std::make_unique<ShapeItem>();
            m_activeShape->kind = (t == ToolId::Line) ? ShapeKind::Line
                                : (t == ToolId::Rectangle) ? ShapeKind::Rectangle
                                : ShapeKind::Ellipse;
            m_activeShape->color  = m_settings.shapeColor;
            m_activeShape->width  = m_settings.shapeWidth;
            m_activeShape->filled = m_settings.shapeFilled;
            m_activeShape->fill   = m_settings.shapeFill;
            m_activeShape->p1 = sp;
            m_activeShape->p2 = sp;
            m_drawing = true;
            update();
        } else if (a == Action::Move && m_drawing && m_activeShape) {
            m_activeShape->p2 = (mods & Qt::ShiftModifier)
                ? constrainShape(m_activeShape->p1, sp, m_activeShape->kind)
                : sp;
            update();
        } else if (a == Action::Release && m_drawing) {
            if (m_activeShape) {
                const QLineF diag(m_activeShape->p1, m_activeShape->p2);
                if (diag.length() >= 2.0)
                    commitAdd(std::move(m_activeShape), QStringLiteral("Shape"));
            }
            m_activeShape.reset();
            m_drawing = false;
            update();
        }
        break;
    }
    case ToolId::Text: {
        if (a == Action::Press)
            addTextAt(sp);
        break;
    }
    case ToolId::Select: {
        handleSelect(a, sp, mods);
        break;
    }
    case ToolId::Laser:
        break;
    }
}

// ---- selection -------------------------------------------------------------
void Canvas::handleSelect(Action a, const QPointF &sp, Qt::KeyboardModifiers mods)
{
    if (a == Action::Press) {
        Item *hit = topItemAt(sp);
        if (hit) {
            const bool already =
                std::find(m_selection.begin(), m_selection.end(), hit) != m_selection.end();
            if (mods & Qt::ShiftModifier) {
                if (already) removeFromSelection(hit);
                else addToSelection(hit);
            } else if (!already) {
                setSelectionSingle(hit);
            }
            m_movingSelection = true;
            m_moveStartScene = sp;
            m_moveAccum = QPointF(0, 0);
        } else {
            if (!(mods & Qt::ShiftModifier))
                clearSelection();
            m_rubber = true;
            m_rubberStartScene = sp;
            m_rubberRect = QRectF(sp, sp);
        }
        update();
    } else if (a == Action::Move) {
        if (m_movingSelection && !m_selection.empty()) {
            const QPointF d = sp - m_moveStartScene;
            const QPointF step = d - m_moveAccum;
            for (Item *it : m_selection)
                it->translate(step);
            m_moveAccum = d;
            update();
        } else if (m_rubber) {
            m_rubberRect = QRectF(m_rubberStartScene, sp).normalized();
            update();
        }
    } else {
        if (m_movingSelection) {
            m_movingSelection = false;
            if (!m_selection.empty() &&
                (qAbs(m_moveAccum.x()) > 0.01 || qAbs(m_moveAccum.y()) > 0.01)) {
                for (Item *it : m_selection)
                    it->translate(-m_moveAccum);
                std::vector<Item *> targets(m_selection.begin(), m_selection.end());
                m_doc->undoStack()->push(new TranslateItemsCommand(
                    m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
                    targets, m_moveAccum, QStringLiteral("Move")));
            }
            m_moveAccum = QPointF(0, 0);
        } else if (m_rubber) {
            m_rubber = false;
            selectInRect(m_rubberRect, (mods & Qt::ShiftModifier));
        }
        update();
    }
}

void Canvas::setSelectionSingle(Item *it)
{
    m_selection.clear();
    if (it) m_selection.push_back(it);
}

void Canvas::addToSelection(Item *it)
{
    if (it && std::find(m_selection.begin(), m_selection.end(), it) == m_selection.end())
        m_selection.push_back(it);
}

void Canvas::removeFromSelection(Item *it)
{
    m_selection.erase(std::remove(m_selection.begin(), m_selection.end(), it),
                      m_selection.end());
}

void Canvas::clearSelection()
{
    if (m_selection.empty())
        return;
    m_selection.clear();
    update();
}

void Canvas::selectAll()
{
    if (!m_doc)
        return;
    m_selection.clear();
    for (auto &it : m_doc->current().active().items)
        m_selection.push_back(it.get());
    update();
}

void Canvas::selectInRect(const QRectF &r, bool add)
{
    if (!m_doc)
        return;
    if (!add)
        m_selection.clear();
    for (auto &it : m_doc->current().active().items) {
        if (r.intersects(it->boundingRect()) &&
            std::find(m_selection.begin(), m_selection.end(), it.get()) == m_selection.end())
            m_selection.push_back(it.get());
    }
}

Item *Canvas::topItemAt(const QPointF &sp)
{
    if (!m_doc)
        return nullptr;
    Layer &ly = m_doc->current().active();
    const double r = 6.0 / qMax(0.0001, m_scale);
    for (int i = static_cast<int>(ly.items.size()) - 1; i >= 0; --i) {
        Item *it = ly.items[static_cast<std::size_t>(i)].get();
        if (hitTest(it, sp, r))
            return it;
    }
    return nullptr;
}

bool Canvas::hitTest(Item *it, const QPointF &sp, double radius) const
{
    const QRectF bb = it->boundingRect().adjusted(-radius, -radius, radius, radius);
    if (!bb.contains(sp))
        return false;

    if (it->type() == ItemType::Stroke) {
        const StrokeItem *s = static_cast<const StrokeItem *>(it);
        const double tol = radius + s->baseWidth * 0.5;
        if (s->points.size() == 1)
            return QLineF(sp, s->points.first().pos()).length() <= tol;
        for (int i = 1; i < s->points.size(); ++i)
            if (distToSegment(sp, s->points[i - 1].pos(), s->points[i].pos()) <= tol)
                return true;
        return false;
    }
    return true;
}

// ---- helpers ---------------------------------------------------------------
void Canvas::commitAdd(ItemPtr item, const QString &text)
{
    if (!m_doc || !item)
        return;
    m_doc->undoStack()->push(new AddItemCommand(
        m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
        std::move(item), text));
}

void Canvas::eraseAt(const QPointF &sp)
{
    if (!m_doc)
        return;
    Layer &ly = m_doc->current().active();
    const double r = m_settings.eraserRadius;
    for (std::size_t i = 0; i < ly.items.size();) {
        if (hitTest(ly.items[i].get(), sp, r)) {
            m_eraseStash.push_back({i, std::move(ly.items[i])});
            ly.items.erase(ly.items.begin() + static_cast<std::ptrdiff_t>(i));
        } else {
            ++i;
        }
    }
}

void Canvas::finishErase()
{
    if (!m_doc || m_eraseStash.empty())
        return;
    Layer &ly = m_doc->current().active();
    std::sort(m_eraseStash.begin(), m_eraseStash.end(),
              [](const EraseStash &a, const EraseStash &b) { return a.index < b.index; });

    std::vector<Item *> targets;
    for (auto &s : m_eraseStash) {
        Item *raw = s.item.get();
        targets.push_back(raw);
        const std::size_t idx = std::min(s.index, ly.items.size());
        ly.items.insert(ly.items.begin() + static_cast<std::ptrdiff_t>(idx),
                        std::move(s.item));
    }
    m_eraseStash.clear();

    m_doc->undoStack()->push(new RemoveItemsCommand(
        m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
        std::move(targets), QStringLiteral("Erase")));
}

void Canvas::addTextAt(const QPointF &sp)
{
    bool ok = false;
    const QString text = QInputDialog::getMultiLineText(
        this, tr("Add Text"), tr("Text:"), QString(), &ok);
    if (!ok || text.trimmed().isEmpty())
        return;
    auto t = std::make_unique<TextItem>();
    t->pos   = sp;
    t->text  = text;
    t->color = m_settings.textColor;
    t->font  = m_settings.textFont;
    commitAdd(std::move(t), QStringLiteral("Text"));
}

void Canvas::deleteSelection()
{
    if (!m_doc || m_selection.empty())
        return;
    std::vector<Item *> targets(m_selection.begin(), m_selection.end());
    m_selection.clear();
    m_doc->undoStack()->push(new RemoveItemsCommand(
        m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
        std::move(targets), QStringLiteral("Delete")));
    update();
}

void Canvas::cancelActive()
{
    m_activeStroke.reset();
    m_activeShape.reset();
    m_drawing = false;
    if (m_erasing && m_doc) {
        Layer &ly = m_doc->current().active();
        for (auto &s : m_eraseStash)
            ly.items.push_back(std::move(s.item));
    }
    m_eraseStash.clear();
    m_erasing = false;
    m_movingSelection = false;
    m_rubber = false;
}

void Canvas::updateCursor()
{
    switch (m_settings.tool) {
    case ToolId::Pen:
    case ToolId::Highlighter:
    case ToolId::Line:
    case ToolId::Rectangle:
    case ToolId::Ellipse:
    case ToolId::Laser:
    case ToolId::Select:
        setCursor(Qt::ArrowCursor);
        break;
    case ToolId::Eraser:
        setCursor(Qt::BlankCursor);
        break;
    case ToolId::Text:
        setCursor(Qt::IBeamCursor);
        break;
    }
}

} // namespace ib
EOF

log "PART 12 complete: permanent laser is now a real erasable/undoable/saveable glow stroke"

# ---------------------------------------------------------------------------
#  PART 13 : Vanishing-mode laser now behaves EXACTLY like the pen — it is a
#            real glow StrokeItem (erasable, undoable, selectable, saveable).
#            "Vanishing" just fades that real stroke out and removes it when
#            the pen leaves the tablet's range. Overwrites StrokeItem.h and
#            Canvas.cpp only (Canvas.h untouched).
# ---------------------------------------------------------------------------
log "PART 13: vanishing laser is a real erasable pen-like glow stroke"

# ---------------------------------------------------------------------------
#  src/model/StrokeItem.h  (overwrite: add runtime-only 'ephemeral' flag)
# ---------------------------------------------------------------------------
cat > src/model/StrokeItem.h <<'EOF'
#pragma once

#include <QColor>
#include <QVector>

#include "model/Item.h"

namespace ib {

class StrokeItem : public Item {
public:
    QVector<StrokePoint> points;
    QColor  color         = QColor(24, 24, 24);
    double  baseWidth     = 3.0;
    double  opacity       = 1.0;
    bool    highlighter   = false;
    bool    pressureWidth = true;

    // Laser glow style (used by the Laser tool). When glow is true a
    // translucent glowColor underlay is drawn beneath the core stroke.
    bool    glow          = false;
    QColor  glowColor     = QColor(255, 45, 40);
    double  glowRadius    = 10.0;

    // Runtime-only marker: vanishing-mode laser ink. NOT serialized (write/read
    // ignore it), so loaded strokes are always permanent. Copied by clone().
    bool    ephemeral     = false;

    ItemType type() const override { return ItemType::Stroke; }
    QRectF boundingRect() const override;
    void paint(QPainter &p) const override;
    std::unique_ptr<Item> clone() const override;
    void translate(const QPointF &delta) override;
    void write(QJsonObject &obj) const override;
    void read(const QJsonObject &obj) override;

    void addPoint(const StrokePoint &pt) { points.push_back(pt); }
    bool isEmpty() const { return points.isEmpty(); }
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/canvas/Canvas.cpp  (overwrite: unify laser onto real strokes; vanish =
#                          fade + RemoveItemsCommand on the ephemeral strokes)
# ---------------------------------------------------------------------------
cat > src/canvas/Canvas.cpp <<'EOF'
#include "canvas/Canvas.h"

#include "core/Commands.h"
#include "model/TextItem.h"
#include "model/ImageItem.h"

#include <QApplication>
#include <QTimer>
#include <QPainter>
#include <QPen>
#include <QRadialGradient>
#include <QMouseEvent>
#include <QTabletEvent>
#include <QWheelEvent>
#include <QKeyEvent>
#include <QPointingDevice>
#include <QInputDialog>
#include <QUndoStack>
#include <QLineF>
#include <algorithm>
#include <cmath>

namespace ib {

static const double kPi = 3.14159265358979323846;

static double distToSegment(const QPointF &p, const QPointF &a, const QPointF &b)
{
    const QPointF ab = b - a;
    const double len2 = ab.x() * ab.x() + ab.y() * ab.y();
    if (len2 <= 1e-9)
        return std::hypot(p.x() - a.x(), p.y() - a.y());
    double t = ((p.x() - a.x()) * ab.x() + (p.y() - a.y()) * ab.y()) / len2;
    t = std::max(0.0, std::min(1.0, t));
    const QPointF proj(a.x() + t * ab.x(), a.y() + t * ab.y());
    return std::hypot(p.x() - proj.x(), p.y() - proj.y());
}

static QPointF constrainShape(const QPointF &a, const QPointF &b, ShapeKind kind)
{
    const QPointF d = b - a;
    if (kind == ShapeKind::Line) {
        double ang = std::atan2(d.y(), d.x());
        const double step = kPi / 4.0;
        ang = std::round(ang / step) * step;
        const double len = std::hypot(d.x(), d.y());
        return a + QPointF(std::cos(ang) * len, std::sin(ang) * len);
    }
    const double s = std::max(std::abs(d.x()), std::abs(d.y()));
    return a + QPointF(d.x() < 0 ? -s : s, d.y() < 0 ? -s : s);
}

// Vanish fade curve: full until 'delay', then linear to 0 over 'dur'.
static double fadeAlphaFor(qint64 elapsedMs, int delayMs, int durMs)
{
    if (elapsedMs <= delayMs)
        return 1.0;
    const double t = static_cast<double>(elapsedMs - delayMs) /
                     static_cast<double>(qMax(1, durMs));
    if (t >= 1.0)
        return 0.0;
    return 1.0 - t;
}

static bool layerHasEphemeral(const Layer &ly)
{
    for (const auto &it : ly.items)
        if (it->type() == ItemType::Stroke &&
            static_cast<const StrokeItem *>(it.get())->ephemeral)
            return true;
    return false;
}

Canvas::Canvas(QWidget *parent)
    : QWidget(parent)
{
    setFocusPolicy(Qt::StrongFocus);
    setMouseTracking(true);
    setAttribute(Qt::WA_TabletTracking, true);
    setAutoFillBackground(false);
    m_translate = QPointF(40, 40);

    // Tablet proximity events are delivered to the application object, so we
    // watch them via an app-level filter to drive laser vanishing mode.
    qApp->installEventFilter(this);

    m_fadeTimer = new QTimer(this);
    m_fadeTimer->setInterval(16);
    connect(m_fadeTimer, &QTimer::timeout, this, &Canvas::onFadeTick);

    updateCursor();
}

void Canvas::setDocument(Document *doc)
{
    if (m_doc == doc)
        return;
    if (m_doc) {
        m_doc->disconnect(this);
        if (m_doc->undoStack())
            m_doc->undoStack()->disconnect(this);
    }
    m_doc = doc;
    stopVanish();
    cancelActive();
    m_selection.clear();

    if (m_doc) {
        connect(m_doc, &Document::currentPageChanged, this, [this](int) {
            stopVanish(); cancelActive(); m_selection.clear(); update();
        });
        connect(m_doc, &Document::pagesChanged, this, [this]() {
            stopVanish(); cancelActive(); m_selection.clear(); update();
        });
        connect(m_doc, &Document::contentChanged, this, [this]() { update(); });
        if (m_doc->undoStack()) {
            connect(m_doc->undoStack(), &QUndoStack::indexChanged, this, [this](int) {
                m_selection.clear(); cancelActive(); update();
            });
        }
    }
    update();
}

void Canvas::setTool(ToolId t)
{
    cancelActive();
    m_settings.tool = t;
    updateCursor();
    emit toolChanged(t);
    update();
}

void Canvas::clearLaser()
{
    // Laser ink is now real strokes; Esc only cancels a pending vanish fade.
    stopVanish();
    update();
}

// ---- laser vanishing -------------------------------------------------------
void Canvas::startVanish()
{
    if (!m_doc || !layerHasEphemeral(m_doc->current().active()))
        return;
    m_fading = true;
    m_fadeClock.restart();
    if (!m_fadeTimer->isActive())
        m_fadeTimer->start();
    update();
}

void Canvas::stopVanish()
{
    if (!m_fading)
        return;
    m_fading = false;
    if (m_fadeTimer->isActive())
        m_fadeTimer->stop();
    update();
}

void Canvas::onFadeTick()
{
    if (!m_fading || !m_doc) {
        m_fading = false;
        m_fadeTimer->stop();
        return;
    }
    const qint64 el = m_fadeClock.elapsed();
    const int delay = qMax(0, m_settings.laser.vanishDelayMs);
    const int dur   = qMax(1, m_settings.laser.fadeDurationMs);

    if (el < static_cast<qint64>(delay) + dur) {
        update();               // still fading; paintEvent computes the alpha
        return;
    }

    // Fade complete: remove the ephemeral (vanishing) strokes for real, through
    // the undo system so nothing dangles and it stays consistent with the pen.
    m_fading = false;
    m_fadeTimer->stop();

    Layer &ly = m_doc->current().active();
    std::vector<Item *> targets;
    for (auto &it : ly.items)
        if (it->type() == ItemType::Stroke &&
            static_cast<StrokeItem *>(it.get())->ephemeral)
            targets.push_back(it.get());

    if (!targets.empty())
        m_doc->undoStack()->push(new RemoveItemsCommand(
            m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
            std::move(targets), QStringLiteral("Laser vanish")));
    update();
}

bool Canvas::eventFilter(QObject *obj, QEvent *ev)
{
    if (ev->type() == QEvent::TabletLeaveProximity) {
        if (m_settings.tool == ToolId::Laser && m_settings.laser.vanishMode && !m_drawing)
            startVanish();                 // no-op if there is no ephemeral ink
    } else if (ev->type() == QEvent::TabletEnterProximity) {
        stopVanish();                      // no-op if not currently fading
    }
    return QWidget::eventFilter(obj, ev);
}

// ---- view ------------------------------------------------------------------
void Canvas::zoomAround(const QPointF &widgetPos, double factor)
{
    const QPointF before = widgetToScene(widgetPos);
    m_scale = qBound(0.05, m_scale * factor, 40.0);
    m_translate = widgetPos - before * m_scale;
    update();
    emit viewChanged();
}

void Canvas::zoomIn()  { zoomAround(QPointF(width() / 2.0, height() / 2.0), 1.2); }
void Canvas::zoomOut() { zoomAround(QPointF(width() / 2.0, height() / 2.0), 1.0 / 1.2); }

void Canvas::resetView()
{
    m_scale = 1.0;
    m_translate = QPointF(40, 40);
    update();
    emit viewChanged();
}

void Canvas::zoomToFit()
{
    if (!m_doc) { update(); return; }
    QRectF b = m_doc->current().contentBounds();
    if (b.isNull()) { resetView(); return; }
    b.adjust(-40, -40, 40, 40);
    const double sx = width()  / b.width();
    const double sy = height() / b.height();
    m_scale = qBound(0.05, qMin(sx, sy), 40.0);
    m_translate = QPointF(width() / 2.0, height() / 2.0) - b.center() * m_scale;
    update();
    emit viewChanged();
}

// ---- painting --------------------------------------------------------------
void Canvas::drawBackground(QPainter &p, const Page &pg, const QRectF &area)
{
    if (pg.background == BackgroundKind::Blank)
        return;
    const double s = qMax(4.0, pg.gridSpacing);
    QPen pen(pg.gridColor);
    pen.setCosmetic(true);
    pen.setWidth(1);
    p.setPen(pen);

    const double startX = std::floor(area.left() / s) * s;
    const double startY = std::floor(area.top() / s) * s;

    if (pg.background == BackgroundKind::Grid) {
        for (double x = startX; x <= area.right(); x += s)
            p.drawLine(QPointF(x, area.top()), QPointF(x, area.bottom()));
        for (double y = startY; y <= area.bottom(); y += s)
            p.drawLine(QPointF(area.left(), y), QPointF(area.right(), y));
    } else if (pg.background == BackgroundKind::Lines) {
        for (double y = startY; y <= area.bottom(); y += s)
            p.drawLine(QPointF(area.left(), y), QPointF(area.right(), y));
    } else {
        p.setPen(Qt::NoPen);
        p.setBrush(pg.gridColor);
        for (double x = startX; x <= area.right(); x += s)
            for (double y = startY; y <= area.bottom(); y += s)
                p.drawEllipse(QPointF(x, y), 1.3, 1.3);
    }
}

void Canvas::drawSelection(QPainter &p)
{
    if (m_selection.empty())
        return;
    QPen pen(QColor(60, 120, 220));
    pen.setCosmetic(true);
    pen.setStyle(Qt::DashLine);
    pen.setWidth(1);
    p.setPen(pen);
    p.setBrush(Qt::NoBrush);
    for (Item *it : m_selection)
        p.drawRect(it->boundingRect());
}

void Canvas::drawBrushPreview(QPainter &p)
{
    if (!m_hoverValid || m_panning)
        return;

    if (m_settings.tool == ToolId::Eraser) {
        const double r = m_settings.eraserRadius * m_scale;
        QPen pen(QColor(70, 70, 70));
        pen.setStyle(Qt::DashLine);
        p.setPen(pen);
        p.setBrush(Qt::NoBrush);
        p.drawEllipse(m_cursorWidget, r, r);
        return;
    }

    QColor col;
    double w = 0.0;
    bool laser = false;
    switch (m_settings.tool) {
    case ToolId::Pen:         col = m_settings.penColor;   w = m_settings.penWidth;   break;
    case ToolId::Highlighter: col = m_settings.hlColor;    w = m_settings.hlWidth;    break;
    case ToolId::Line:
    case ToolId::Rectangle:
    case ToolId::Ellipse:     col = m_settings.shapeColor; w = m_settings.shapeWidth; break;
    case ToolId::Laser:       col = m_settings.laser.coreColor; w = m_settings.laser.width; laser = true; break;
    default: return;
    }

    const double r = qMax(1.5, w * 0.5 * m_scale);

    p.save();
    p.setRenderHint(QPainter::Antialiasing, true);

    if (laser && m_settings.laser.glowEnabled) {
        const double gr = r + m_settings.laser.glowRadius * m_scale;
        QRadialGradient g(m_cursorWidget, gr);
        QColor g0 = m_settings.laser.glowColor; g0.setAlphaF(0.55 * m_settings.laser.intensity);
        QColor g1 = m_settings.laser.glowColor; g1.setAlphaF(0.0);
        g.setColorAt(0.0, g0);
        g.setColorAt(1.0, g1);
        p.setPen(Qt::NoPen);
        p.setBrush(g);
        p.drawEllipse(m_cursorWidget, gr, gr);
    }

    QColor fill = col;
    fill.setAlphaF(laser ? m_settings.laser.intensity : 0.9);
    const QColor outline = (col.lightness() > 128) ? QColor(0, 0, 0, 170)
                                                   : QColor(255, 255, 255, 190);
    QPen pen(outline);
    pen.setWidthF(1.0);
    p.setPen(pen);
    p.setBrush(fill);
    p.drawEllipse(m_cursorWidget, r, r);
    p.restore();
}

void Canvas::paintEvent(QPaintEvent *)
{
    QPainter p(this);
    p.fillRect(rect(), QColor(90, 93, 99));
    if (!m_doc)
        return;

    p.save();
    p.translate(m_translate);
    p.scale(m_scale, m_scale);

    const QRectF sceneRect =
        QRectF(widgetToScene(QPointF(0, 0)),
               widgetToScene(QPointF(width(), height()))).normalized();

    Page &pg = m_doc->current();
    p.fillRect(sceneRect, pg.bgColor);
    drawBackground(p, pg, sceneRect);

    p.setRenderHint(QPainter::Antialiasing, true);
    p.setRenderHint(QPainter::TextAntialiasing, true);

    // Vanish fade multiplier, applied only to ephemeral (vanishing) laser ink.
    const double vanishFade = m_fading
        ? fadeAlphaFor(m_fadeClock.elapsed(),
                       qMax(0, m_settings.laser.vanishDelayMs),
                       qMax(1, m_settings.laser.fadeDurationMs))
        : 1.0;

    for (const auto &ly : pg.layers) {
        if (!ly.visible)
            continue;
        const double layerOpacity = ly.opacity < 1.0 ? ly.opacity : 1.0;
        for (const auto &it : ly.items) {
            double o = layerOpacity;
            if (vanishFade < 1.0 && it->type() == ItemType::Stroke &&
                static_cast<const StrokeItem *>(it.get())->ephemeral)
                o *= vanishFade;
            p.save();
            p.setOpacity(o);
            it->paint(p);
            p.restore();
        }
    }

    if (m_activeStroke) m_activeStroke->paint(p);
    if (m_activeShape)  m_activeShape->paint(p);

    drawSelection(p);

    if (m_rubber) {
        QPen pen(QColor(60, 120, 220));
        pen.setCosmetic(true);
        pen.setStyle(Qt::DashLine);
        p.setPen(pen);
        p.setBrush(QColor(60, 120, 220, 40));
        p.drawRect(m_rubberRect);
    }

    p.restore();

    drawBrushPreview(p);
}

// ---- input -----------------------------------------------------------------
void Canvas::mousePressEvent(QMouseEvent *e)
{
    m_cursorWidget = e->position();
    m_hoverValid = true;
    if (e->button() == Qt::MiddleButton ||
        (m_spaceDown && e->button() == Qt::LeftButton)) {
        m_panning = true;
        m_lastPanPos = e->position().toPoint();
        setCursor(Qt::ClosedHandCursor);
        return;
    }
    if (e->button() == Qt::LeftButton)
        handlePointer(Action::Press, e->position(), 1.0, e->modifiers(), false);
}

void Canvas::mouseMoveEvent(QMouseEvent *e)
{
    m_cursorWidget = e->position();
    m_hoverValid = true;
    if (m_panning) {
        const QPoint d = e->position().toPoint() - m_lastPanPos;
        m_lastPanPos = e->position().toPoint();
        m_translate += QPointF(d);
        update();
        emit viewChanged();
        return;
    }
    handlePointer(Action::Move, e->position(), 1.0, e->modifiers(), false);
    update();
    emit cursorMoved(widgetToScene(e->position()));
}

void Canvas::mouseReleaseEvent(QMouseEvent *e)
{
    m_cursorWidget = e->position();
    if (m_panning &&
        (e->button() == Qt::MiddleButton || e->button() == Qt::LeftButton)) {
        m_panning = false;
        updateCursor();
        return;
    }
    if (e->button() == Qt::LeftButton)
        handlePointer(Action::Release, e->position(), 1.0, e->modifiers(), false);
}

void Canvas::tabletEvent(QTabletEvent *e)
{
    const bool eraserTip =
        e->pointerType() == QPointingDevice::PointerType::Eraser;
    double pr = e->pressure();
    if (pr <= 0.0)
        pr = 1.0;
    m_cursorWidget = e->position();
    m_hoverValid = true;

    switch (e->type()) {
    case QEvent::TabletPress:
        handlePointer(Action::Press, e->position(), pr, e->modifiers(), eraserTip);
        break;
    case QEvent::TabletMove:
        handlePointer(Action::Move, e->position(), pr, e->modifiers(), eraserTip);
        emit cursorMoved(widgetToScene(e->position()));
        update();
        break;
    case QEvent::TabletRelease:
        handlePointer(Action::Release, e->position(), pr, e->modifiers(), eraserTip);
        break;
    default:
        break;
    }
    e->accept();
}

void Canvas::wheelEvent(QWheelEvent *e)
{
    const double factor = std::pow(1.0015, e->angleDelta().y());
    zoomAround(e->position(), factor);
    e->accept();
}

void Canvas::keyPressEvent(QKeyEvent *e)
{
    if (e->key() == Qt::Key_Space) {
        m_spaceDown = true;
        setCursor(Qt::OpenHandCursor);
        e->accept();
        return;
    }
    if (e->key() == Qt::Key_Delete || e->key() == Qt::Key_Backspace) {
        deleteSelection();
        e->accept();
        return;
    }
    if (e->key() == Qt::Key_Escape) {
        cancelActive();
        clearSelection();
        clearLaser();
        e->accept();
        return;
    }
    QWidget::keyPressEvent(e);
}

void Canvas::keyReleaseEvent(QKeyEvent *e)
{
    if (e->key() == Qt::Key_Space) {
        m_spaceDown = false;
        updateCursor();
        e->accept();
        return;
    }
    QWidget::keyReleaseEvent(e);
}

void Canvas::leaveEvent(QEvent *e)
{
    m_hoverValid = false;
    update();
    QWidget::leaveEvent(e);
}

// ---- pointer dispatch ------------------------------------------------------
void Canvas::handlePointer(Action a, const QPointF &widgetPos, double pressure,
                           Qt::KeyboardModifiers mods, bool eraserTip)
{
    if (!m_doc)
        return;
    const QPointF sp = widgetToScene(widgetPos);
    m_cursorWidget = widgetPos;

    const ToolId t = eraserTip ? ToolId::Eraser : m_settings.tool;

    if (t == ToolId::Laser) {
        // In BOTH modes the laser is a real glow stroke on the active layer, so
        // it can be erased, undone, selected and saved exactly like the pen.
        // Vanishing mode only tags it 'ephemeral' so it fades + removes itself
        // when the pen later leaves the tablet's range.
        Layer &lly = m_doc->current().active();
        if (lly.locked)
            return;
        if (a == Action::Press) {
            stopVanish();                 // a new stroke cancels any pending fade
            m_drawing = true;
            m_activeStroke = std::make_unique<StrokeItem>();
            m_activeStroke->highlighter   = false;
            m_activeStroke->pressureWidth = false;
            m_activeStroke->color         = m_settings.laser.coreColor;
            m_activeStroke->baseWidth     = m_settings.laser.width;
            m_activeStroke->opacity       = qBound(0.0, m_settings.laser.intensity, 1.0);
            m_activeStroke->glow          = m_settings.laser.glowEnabled;
            m_activeStroke->glowColor     = m_settings.laser.glowColor;
            m_activeStroke->glowRadius    = m_settings.laser.glowRadius;
            m_activeStroke->ephemeral     = m_settings.laser.vanishMode;
            m_activeStroke->addPoint(StrokePoint(sp.x(), sp.y(), pressure));
            update();
        } else if (a == Action::Move && m_drawing && m_activeStroke) {
            m_activeStroke->addPoint(StrokePoint(sp.x(), sp.y(), pressure));
            update();
        } else if (a == Action::Release && m_drawing) {
            if (m_activeStroke && !m_activeStroke->isEmpty())
                commitAdd(std::move(m_activeStroke), QStringLiteral("Laser"));
            m_activeStroke.reset();
            m_drawing = false;
            update();
        }
        return;
    }

    Layer &ly = m_doc->current().active();
    if (ly.locked)
        return;

    switch (t) {
    case ToolId::Pen:
    case ToolId::Highlighter: {
        const bool hl = (t == ToolId::Highlighter);
        if (a == Action::Press) {
            m_drawing = true;
            m_activeStroke = std::make_unique<StrokeItem>();
            m_activeStroke->highlighter   = hl;
            m_activeStroke->color         = hl ? m_settings.hlColor : m_settings.penColor;
            m_activeStroke->baseWidth     = hl ? m_settings.hlWidth : m_settings.penWidth;
            m_activeStroke->opacity       = hl ? m_settings.hlOpacity : 1.0;
            m_activeStroke->pressureWidth = hl ? false : m_settings.penPressure;
            m_activeStroke->addPoint(StrokePoint(sp.x(), sp.y(), pressure));
            update();
        } else if (a == Action::Move && m_drawing && m_activeStroke) {
            m_activeStroke->addPoint(StrokePoint(sp.x(), sp.y(), pressure));
            update();
        } else if (a == Action::Release && m_drawing) {
            if (m_activeStroke && !m_activeStroke->isEmpty())
                commitAdd(std::move(m_activeStroke),
                          hl ? QStringLiteral("Highlight") : QStringLiteral("Draw"));
            m_activeStroke.reset();
            m_drawing = false;
            update();
        }
        break;
    }
    case ToolId::Eraser: {
        if (a == Action::Press) { m_erasing = true; m_eraseStash.clear(); eraseAt(sp); update(); }
        else if (a == Action::Move && m_erasing) { eraseAt(sp); update(); }
        else if (a == Action::Release && m_erasing) { finishErase(); m_erasing = false; update(); }
        break;
    }
    case ToolId::Line:
    case ToolId::Rectangle:
    case ToolId::Ellipse: {
        if (a == Action::Press) {
            m_activeShape = std::make_unique<ShapeItem>();
            m_activeShape->kind = (t == ToolId::Line) ? ShapeKind::Line
                                : (t == ToolId::Rectangle) ? ShapeKind::Rectangle
                                : ShapeKind::Ellipse;
            m_activeShape->color  = m_settings.shapeColor;
            m_activeShape->width  = m_settings.shapeWidth;
            m_activeShape->filled = m_settings.shapeFilled;
            m_activeShape->fill   = m_settings.shapeFill;
            m_activeShape->p1 = sp;
            m_activeShape->p2 = sp;
            m_drawing = true;
            update();
        } else if (a == Action::Move && m_drawing && m_activeShape) {
            m_activeShape->p2 = (mods & Qt::ShiftModifier)
                ? constrainShape(m_activeShape->p1, sp, m_activeShape->kind)
                : sp;
            update();
        } else if (a == Action::Release && m_drawing) {
            if (m_activeShape) {
                const QLineF diag(m_activeShape->p1, m_activeShape->p2);
                if (diag.length() >= 2.0)
                    commitAdd(std::move(m_activeShape), QStringLiteral("Shape"));
            }
            m_activeShape.reset();
            m_drawing = false;
            update();
        }
        break;
    }
    case ToolId::Text: {
        if (a == Action::Press)
            addTextAt(sp);
        break;
    }
    case ToolId::Select: {
        handleSelect(a, sp, mods);
        break;
    }
    case ToolId::Laser:
        break;
    }
}

// ---- selection -------------------------------------------------------------
void Canvas::handleSelect(Action a, const QPointF &sp, Qt::KeyboardModifiers mods)
{
    if (a == Action::Press) {
        Item *hit = topItemAt(sp);
        if (hit) {
            const bool already =
                std::find(m_selection.begin(), m_selection.end(), hit) != m_selection.end();
            if (mods & Qt::ShiftModifier) {
                if (already) removeFromSelection(hit);
                else addToSelection(hit);
            } else if (!already) {
                setSelectionSingle(hit);
            }
            m_movingSelection = true;
            m_moveStartScene = sp;
            m_moveAccum = QPointF(0, 0);
        } else {
            if (!(mods & Qt::ShiftModifier))
                clearSelection();
            m_rubber = true;
            m_rubberStartScene = sp;
            m_rubberRect = QRectF(sp, sp);
        }
        update();
    } else if (a == Action::Move) {
        if (m_movingSelection && !m_selection.empty()) {
            const QPointF d = sp - m_moveStartScene;
            const QPointF step = d - m_moveAccum;
            for (Item *it : m_selection)
                it->translate(step);
            m_moveAccum = d;
            update();
        } else if (m_rubber) {
            m_rubberRect = QRectF(m_rubberStartScene, sp).normalized();
            update();
        }
    } else {
        if (m_movingSelection) {
            m_movingSelection = false;
            if (!m_selection.empty() &&
                (qAbs(m_moveAccum.x()) > 0.01 || qAbs(m_moveAccum.y()) > 0.01)) {
                for (Item *it : m_selection)
                    it->translate(-m_moveAccum);
                std::vector<Item *> targets(m_selection.begin(), m_selection.end());
                m_doc->undoStack()->push(new TranslateItemsCommand(
                    m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
                    targets, m_moveAccum, QStringLiteral("Move")));
            }
            m_moveAccum = QPointF(0, 0);
        } else if (m_rubber) {
            m_rubber = false;
            selectInRect(m_rubberRect, (mods & Qt::ShiftModifier));
        }
        update();
    }
}

void Canvas::setSelectionSingle(Item *it)
{
    m_selection.clear();
    if (it) m_selection.push_back(it);
}

void Canvas::addToSelection(Item *it)
{
    if (it && std::find(m_selection.begin(), m_selection.end(), it) == m_selection.end())
        m_selection.push_back(it);
}

void Canvas::removeFromSelection(Item *it)
{
    m_selection.erase(std::remove(m_selection.begin(), m_selection.end(), it),
                      m_selection.end());
}

void Canvas::clearSelection()
{
    if (m_selection.empty())
        return;
    m_selection.clear();
    update();
}

void Canvas::selectAll()
{
    if (!m_doc)
        return;
    m_selection.clear();
    for (auto &it : m_doc->current().active().items)
        m_selection.push_back(it.get());
    update();
}

void Canvas::selectInRect(const QRectF &r, bool add)
{
    if (!m_doc)
        return;
    if (!add)
        m_selection.clear();
    for (auto &it : m_doc->current().active().items) {
        if (r.intersects(it->boundingRect()) &&
            std::find(m_selection.begin(), m_selection.end(), it.get()) == m_selection.end())
            m_selection.push_back(it.get());
    }
}

Item *Canvas::topItemAt(const QPointF &sp)
{
    if (!m_doc)
        return nullptr;
    Layer &ly = m_doc->current().active();
    const double r = 6.0 / qMax(0.0001, m_scale);
    for (int i = static_cast<int>(ly.items.size()) - 1; i >= 0; --i) {
        Item *it = ly.items[static_cast<std::size_t>(i)].get();
        if (hitTest(it, sp, r))
            return it;
    }
    return nullptr;
}

bool Canvas::hitTest(Item *it, const QPointF &sp, double radius) const
{
    const QRectF bb = it->boundingRect().adjusted(-radius, -radius, radius, radius);
    if (!bb.contains(sp))
        return false;

    if (it->type() == ItemType::Stroke) {
        const StrokeItem *s = static_cast<const StrokeItem *>(it);
        const double tol = radius + s->baseWidth * 0.5;
        if (s->points.size() == 1)
            return QLineF(sp, s->points.first().pos()).length() <= tol;
        for (int i = 1; i < s->points.size(); ++i)
            if (distToSegment(sp, s->points[i - 1].pos(), s->points[i].pos()) <= tol)
                return true;
        return false;
    }
    return true;
}

// ---- helpers ---------------------------------------------------------------
void Canvas::commitAdd(ItemPtr item, const QString &text)
{
    if (!m_doc || !item)
        return;
    m_doc->undoStack()->push(new AddItemCommand(
        m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
        std::move(item), text));
}

void Canvas::eraseAt(const QPointF &sp)
{
    if (!m_doc)
        return;
    Layer &ly = m_doc->current().active();
    const double r = m_settings.eraserRadius;
    for (std::size_t i = 0; i < ly.items.size();) {
        if (hitTest(ly.items[i].get(), sp, r)) {
            m_eraseStash.push_back({i, std::move(ly.items[i])});
            ly.items.erase(ly.items.begin() + static_cast<std::ptrdiff_t>(i));
        } else {
            ++i;
        }
    }
}

void Canvas::finishErase()
{
    if (!m_doc || m_eraseStash.empty())
        return;
    Layer &ly = m_doc->current().active();
    std::sort(m_eraseStash.begin(), m_eraseStash.end(),
              [](const EraseStash &a, const EraseStash &b) { return a.index < b.index; });

    std::vector<Item *> targets;
    for (auto &s : m_eraseStash) {
        Item *raw = s.item.get();
        targets.push_back(raw);
        const std::size_t idx = std::min(s.index, ly.items.size());
        ly.items.insert(ly.items.begin() + static_cast<std::ptrdiff_t>(idx),
                        std::move(s.item));
    }
    m_eraseStash.clear();

    m_doc->undoStack()->push(new RemoveItemsCommand(
        m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
        std::move(targets), QStringLiteral("Erase")));
}

void Canvas::addTextAt(const QPointF &sp)
{
    bool ok = false;
    const QString text = QInputDialog::getMultiLineText(
        this, tr("Add Text"), tr("Text:"), QString(), &ok);
    if (!ok || text.trimmed().isEmpty())
        return;
    auto t = std::make_unique<TextItem>();
    t->pos   = sp;
    t->text  = text;
    t->color = m_settings.textColor;
    t->font  = m_settings.textFont;
    commitAdd(std::move(t), QStringLiteral("Text"));
}

void Canvas::deleteSelection()
{
    if (!m_doc || m_selection.empty())
        return;
    std::vector<Item *> targets(m_selection.begin(), m_selection.end());
    m_selection.clear();
    m_doc->undoStack()->push(new RemoveItemsCommand(
        m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
        std::move(targets), QStringLiteral("Delete")));
    update();
}

void Canvas::cancelActive()
{
    m_activeStroke.reset();
    m_activeShape.reset();
    m_drawing = false;
    if (m_erasing && m_doc) {
        Layer &ly = m_doc->current().active();
        for (auto &s : m_eraseStash)
            ly.items.push_back(std::move(s.item));
    }
    m_eraseStash.clear();
    m_erasing = false;
    m_movingSelection = false;
    m_rubber = false;
}

void Canvas::updateCursor()
{
    switch (m_settings.tool) {
    case ToolId::Pen:
    case ToolId::Highlighter:
    case ToolId::Line:
    case ToolId::Rectangle:
    case ToolId::Ellipse:
    case ToolId::Laser:
    case ToolId::Select:
        setCursor(Qt::ArrowCursor);
        break;
    case ToolId::Eraser:
        setCursor(Qt::BlankCursor);
        break;
    case ToolId::Text:
        setCursor(Qt::IBeamCursor);
        break;
    }
}

} // namespace ib
EOF

log "PART 13 complete: vanishing laser is a real pen-like stroke (erasable/undoable) that fades away when the pen leaves range"

# ---------------------------------------------------------------------------
#  PART 14 : Canvas presets & page sizing (Infinite / A4 / A5 / Letter /
#            Legal / Custom, portrait+landscape). Adds page geometry to the
#            model, persists it, renders a real paper sheet, and exposes the
#            presets via a right-click "Page Size" menu on the canvas.
#            Overwrites Page.h, Serializer.cpp and Canvas.cpp only.
# ---------------------------------------------------------------------------
log "PART 14: page sizing presets (infinite / A4 / A5 / Letter / Legal / custom)"

# ---------------------------------------------------------------------------
#  src/model/Page.h  (overwrite: add infinite / pageWidth / pageHeight)
# ---------------------------------------------------------------------------
cat > src/model/Page.h <<'EOF'
#pragma once

#include <QColor>
#include <QRectF>
#include <vector>

#include "model/Layer.h"
#include "model/Types.h"

namespace ib {

struct Page {
    BackgroundKind background   = BackgroundKind::Grid;
    QColor         bgColor      = QColor(255, 255, 255);
    QColor         gridColor    = QColor(223, 223, 223);
    double         gridSpacing  = 40.0;

    // Page geometry. infinite == true (default) is the boundless whiteboard.
    // When false, the page is a fixed sheet of pageWidth x pageHeight (scene
    // units, ~96 DPI pixels). Defaults describe A4 portrait.
    bool           infinite     = true;
    double         pageWidth    = 794.0;
    double         pageHeight   = 1123.0;

    std::vector<Layer> layers;
    int            activeLayer  = 0;

    Page() { layers.emplace_back(); }

    Layer &active() {
        if (layers.empty()) layers.emplace_back();
        if (activeLayer < 0 || activeLayer >= static_cast<int>(layers.size()))
            activeLayer = 0;
        return layers[static_cast<std::size_t>(activeLayer)];
    }

    // Union of every visible item's bounding rect (empty if the page is blank).
    QRectF contentBounds() const {
        QRectF r;
        for (const auto &layer : layers) {
            if (!layer.visible) continue;
            for (const auto &it : layer.items)
                r = r.isNull() ? it->boundingRect() : r.united(it->boundingRect());
        }
        return r;
    }
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/core/Serializer.cpp  (overwrite: persist page geometry, back-compatible)
# ---------------------------------------------------------------------------
cat > src/core/Serializer.cpp <<'EOF'
#include "core/Serializer.h"

#include "model/Document.h"
#include "model/Item.h"

#include <QFile>
#include <QSaveFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonParseError>
#include <QColor>

namespace ib {
namespace io {

static QJsonArray colorToJson(const QColor &c)
{
    QJsonArray a;
    a.append(c.red());
    a.append(c.green());
    a.append(c.blue());
    a.append(c.alpha());
    return a;
}

static QColor colorFromJson(const QJsonValue &v, const QColor &def)
{
    const QJsonArray a = v.toArray();
    if (a.size() < 3)
        return def;
    const int alpha = a.size() >= 4 ? a.at(3).toInt(255) : 255;
    return QColor(a.at(0).toInt(), a.at(1).toInt(), a.at(2).toInt(), alpha);
}

static ItemType typeFromString(const QString &s)
{
    if (s == QLatin1String("stroke")) return ItemType::Stroke;
    if (s == QLatin1String("shape"))  return ItemType::Shape;
    if (s == QLatin1String("text"))   return ItemType::Text;
    return ItemType::Image;
}

static QJsonObject pageToJson(const Page &pg)
{
    QJsonObject o;
    o["background"]  = static_cast<int>(pg.background);
    o["bgColor"]     = colorToJson(pg.bgColor);
    o["gridColor"]   = colorToJson(pg.gridColor);
    o["gridSpacing"] = pg.gridSpacing;
    o["infinite"]    = pg.infinite;
    o["pageWidth"]   = pg.pageWidth;
    o["pageHeight"]  = pg.pageHeight;
    o["activeLayer"] = pg.activeLayer;

    QJsonArray layers;
    for (const auto &ly : pg.layers) {
        QJsonObject lo;
        lo["name"]    = ly.name;
        lo["visible"] = ly.visible;
        lo["locked"]  = ly.locked;
        lo["opacity"] = ly.opacity;

        QJsonArray items;
        for (const auto &it : ly.items) {
            QJsonObject io;
            it->write(io);
            items.append(io);
        }
        lo["items"] = items;
        layers.append(lo);
    }
    o["layers"] = layers;
    return o;
}

static Page pageFromJson(const QJsonObject &o)
{
    Page pg;
    pg.background   = static_cast<BackgroundKind>(
        o.value("background").toInt(static_cast<int>(BackgroundKind::Grid)));
    pg.bgColor      = colorFromJson(o.value("bgColor"), QColor(255, 255, 255));
    pg.gridColor    = colorFromJson(o.value("gridColor"), QColor(223, 223, 223));
    pg.gridSpacing  = o.value("gridSpacing").toDouble(40.0);
    pg.infinite     = o.value("infinite").toBool(true);
    pg.pageWidth    = o.value("pageWidth").toDouble(794.0);
    pg.pageHeight   = o.value("pageHeight").toDouble(1123.0);

    pg.layers.clear();
    const QJsonArray layers = o.value("layers").toArray();
    for (const auto &lv : layers) {
        const QJsonObject lo = lv.toObject();
        Layer ly;
        ly.name    = lo.value("name").toString(QStringLiteral("Layer"));
        ly.visible = lo.value("visible").toBool(true);
        ly.locked  = lo.value("locked").toBool(false);
        ly.opacity = lo.value("opacity").toDouble(1.0);

        const QJsonArray items = lo.value("items").toArray();
        for (const auto &iv : items) {
            const QJsonObject io = iv.toObject();
            ItemPtr item = makeItem(typeFromString(io.value("type").toString()));
            if (item) {
                item->read(io);
                ly.items.push_back(std::move(item));
            }
        }
        pg.layers.push_back(std::move(ly));
    }
    if (pg.layers.empty())
        pg.layers.emplace_back();

    pg.activeLayer = o.value("activeLayer").toInt(0);
    return pg;
}

QByteArray toBytes(const Document &doc)
{
    QJsonObject root;
    root["format"]  = "inkboard";
    root["version"] = 1;

    QJsonArray pages;
    for (int i = 0; i < doc.pageCount(); ++i)
        pages.append(pageToJson(doc.page(i)));
    root["pages"] = pages;

    return QJsonDocument(root).toJson(QJsonDocument::Indented);
}

bool fromBytes(std::vector<Page> &pagesOut, const QByteArray &bytes, QString *error)
{
    QJsonParseError pe;
    const QJsonDocument doc = QJsonDocument::fromJson(bytes, &pe);
    if (pe.error != QJsonParseError::NoError) {
        if (error) *error = pe.errorString();
        return false;
    }
    const QJsonObject root = doc.object();
    if (root.value("format").toString() != QLatin1String("inkboard")) {
        if (error) *error = QStringLiteral("Not an InkBoard (.iboard) file.");
        return false;
    }

    pagesOut.clear();
    const QJsonArray pages = root.value("pages").toArray();
    for (const auto &pv : pages)
        pagesOut.push_back(pageFromJson(pv.toObject()));
    if (pagesOut.empty())
        pagesOut.emplace_back();
    return true;
}

bool saveToFile(const Document &doc, const QString &path, QString *error)
{
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly)) {
        if (error) *error = file.errorString();
        return false;
    }
    const QByteArray bytes = toBytes(doc);
    if (file.write(bytes) != bytes.size()) {
        if (error) *error = file.errorString();
        return false;
    }
    if (!file.commit()) {
        if (error) *error = file.errorString();
        return false;
    }
    return true;
}

bool loadFromFile(Document &doc, const QString &path, QString *error)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        if (error) *error = file.errorString();
        return false;
    }
    const QByteArray bytes = file.readAll();
    std::vector<Page> pages;
    if (!fromBytes(pages, bytes, error))
        return false;

    doc.setPages(std::move(pages));
    doc.setFilePath(path);
    return true;
}

} // namespace io
} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/canvas/Canvas.cpp  (overwrite: paper-sheet rendering + right-click
#                          "Page Size" menu + fit-to-sheet zoom)
# ---------------------------------------------------------------------------
cat > src/canvas/Canvas.cpp <<'EOF'
#include "canvas/Canvas.h"

#include "core/Commands.h"
#include "model/TextItem.h"
#include "model/ImageItem.h"

#include <QApplication>
#include <QTimer>
#include <QPainter>
#include <QPen>
#include <QRadialGradient>
#include <QMouseEvent>
#include <QTabletEvent>
#include <QWheelEvent>
#include <QKeyEvent>
#include <QPointingDevice>
#include <QInputDialog>
#include <QMenu>
#include <QAction>
#include <QVector>
#include <QUndoStack>
#include <QLineF>
#include <algorithm>
#include <cmath>

namespace ib {

static const double kPi = 3.14159265358979323846;

static double distToSegment(const QPointF &p, const QPointF &a, const QPointF &b)
{
    const QPointF ab = b - a;
    const double len2 = ab.x() * ab.x() + ab.y() * ab.y();
    if (len2 <= 1e-9)
        return std::hypot(p.x() - a.x(), p.y() - a.y());
    double t = ((p.x() - a.x()) * ab.x() + (p.y() - a.y()) * ab.y()) / len2;
    t = std::max(0.0, std::min(1.0, t));
    const QPointF proj(a.x() + t * ab.x(), a.y() + t * ab.y());
    return std::hypot(p.x() - proj.x(), p.y() - proj.y());
}

static QPointF constrainShape(const QPointF &a, const QPointF &b, ShapeKind kind)
{
    const QPointF d = b - a;
    if (kind == ShapeKind::Line) {
        double ang = std::atan2(d.y(), d.x());
        const double step = kPi / 4.0;
        ang = std::round(ang / step) * step;
        const double len = std::hypot(d.x(), d.y());
        return a + QPointF(std::cos(ang) * len, std::sin(ang) * len);
    }
    const double s = std::max(std::abs(d.x()), std::abs(d.y()));
    return a + QPointF(d.x() < 0 ? -s : s, d.y() < 0 ? -s : s);
}

// Vanish fade curve: full until 'delay', then linear to 0 over 'dur'.
static double fadeAlphaFor(qint64 elapsedMs, int delayMs, int durMs)
{
    if (elapsedMs <= delayMs)
        return 1.0;
    const double t = static_cast<double>(elapsedMs - delayMs) /
                     static_cast<double>(qMax(1, durMs));
    if (t >= 1.0)
        return 0.0;
    return 1.0 - t;
}

static bool layerHasEphemeral(const Layer &ly)
{
    for (const auto &it : ly.items)
        if (it->type() == ItemType::Stroke &&
            static_cast<const StrokeItem *>(it.get())->ephemeral)
            return true;
    return false;
}

Canvas::Canvas(QWidget *parent)
    : QWidget(parent)
{
    setFocusPolicy(Qt::StrongFocus);
    setMouseTracking(true);
    setAttribute(Qt::WA_TabletTracking, true);
    setAutoFillBackground(false);
    m_translate = QPointF(40, 40);

    // Tablet proximity events are delivered to the application object, so we
    // watch them via an app-level filter to drive laser vanishing mode.
    qApp->installEventFilter(this);

    m_fadeTimer = new QTimer(this);
    m_fadeTimer->setInterval(16);
    connect(m_fadeTimer, &QTimer::timeout, this, &Canvas::onFadeTick);

    updateCursor();
}

void Canvas::setDocument(Document *doc)
{
    if (m_doc == doc)
        return;
    if (m_doc) {
        m_doc->disconnect(this);
        if (m_doc->undoStack())
            m_doc->undoStack()->disconnect(this);
    }
    m_doc = doc;
    stopVanish();
    cancelActive();
    m_selection.clear();

    if (m_doc) {
        connect(m_doc, &Document::currentPageChanged, this, [this](int) {
            stopVanish(); cancelActive(); m_selection.clear(); update();
        });
        connect(m_doc, &Document::pagesChanged, this, [this]() {
            stopVanish(); cancelActive(); m_selection.clear(); update();
        });
        connect(m_doc, &Document::contentChanged, this, [this]() { update(); });
        if (m_doc->undoStack()) {
            connect(m_doc->undoStack(), &QUndoStack::indexChanged, this, [this](int) {
                m_selection.clear(); cancelActive(); update();
            });
        }
    }
    update();
}

void Canvas::setTool(ToolId t)
{
    cancelActive();
    m_settings.tool = t;
    updateCursor();
    emit toolChanged(t);
    update();
}

void Canvas::clearLaser()
{
    // Laser ink is now real strokes; Esc only cancels a pending vanish fade.
    stopVanish();
    update();
}

// ---- laser vanishing -------------------------------------------------------
void Canvas::startVanish()
{
    if (!m_doc || !layerHasEphemeral(m_doc->current().active()))
        return;
    m_fading = true;
    m_fadeClock.restart();
    if (!m_fadeTimer->isActive())
        m_fadeTimer->start();
    update();
}

void Canvas::stopVanish()
{
    if (!m_fading)
        return;
    m_fading = false;
    if (m_fadeTimer->isActive())
        m_fadeTimer->stop();
    update();
}

void Canvas::onFadeTick()
{
    if (!m_fading || !m_doc) {
        m_fading = false;
        m_fadeTimer->stop();
        return;
    }
    const qint64 el = m_fadeClock.elapsed();
    const int delay = qMax(0, m_settings.laser.vanishDelayMs);
    const int dur   = qMax(1, m_settings.laser.fadeDurationMs);

    if (el < static_cast<qint64>(delay) + dur) {
        update();               // still fading; paintEvent computes the alpha
        return;
    }

    // Fade complete: remove the ephemeral (vanishing) strokes for real, through
    // the undo system so nothing dangles and it stays consistent with the pen.
    m_fading = false;
    m_fadeTimer->stop();

    Layer &ly = m_doc->current().active();
    std::vector<Item *> targets;
    for (auto &it : ly.items)
        if (it->type() == ItemType::Stroke &&
            static_cast<StrokeItem *>(it.get())->ephemeral)
            targets.push_back(it.get());

    if (!targets.empty())
        m_doc->undoStack()->push(new RemoveItemsCommand(
            m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
            std::move(targets), QStringLiteral("Laser vanish")));
    update();
}

bool Canvas::eventFilter(QObject *obj, QEvent *ev)
{
    if (ev->type() == QEvent::TabletLeaveProximity) {
        if (m_settings.tool == ToolId::Laser && m_settings.laser.vanishMode && !m_drawing)
            startVanish();                 // no-op if there is no ephemeral ink
    } else if (ev->type() == QEvent::TabletEnterProximity) {
        stopVanish();                      // no-op if not currently fading
    }
    return QWidget::eventFilter(obj, ev);
}

// ---- view ------------------------------------------------------------------
void Canvas::zoomAround(const QPointF &widgetPos, double factor)
{
    const QPointF before = widgetToScene(widgetPos);
    m_scale = qBound(0.05, m_scale * factor, 40.0);
    m_translate = widgetPos - before * m_scale;
    update();
    emit viewChanged();
}

void Canvas::zoomIn()  { zoomAround(QPointF(width() / 2.0, height() / 2.0), 1.2); }
void Canvas::zoomOut() { zoomAround(QPointF(width() / 2.0, height() / 2.0), 1.0 / 1.2); }

void Canvas::resetView()
{
    m_scale = 1.0;
    m_translate = QPointF(40, 40);
    update();
    emit viewChanged();
}

void Canvas::zoomToFit()
{
    if (!m_doc) { update(); return; }
    Page &pg = m_doc->current();
    QRectF b;
    if (!pg.infinite)
        b = QRectF(0.0, 0.0, qMax(1.0, pg.pageWidth), qMax(1.0, pg.pageHeight));
    else
        b = pg.contentBounds();
    if (b.isNull()) { resetView(); return; }
    b.adjust(-40, -40, 40, 40);
    const double sx = width()  / b.width();
    const double sy = height() / b.height();
    m_scale = qBound(0.05, qMin(sx, sy), 40.0);
    m_translate = QPointF(width() / 2.0, height() / 2.0) - b.center() * m_scale;
    update();
    emit viewChanged();
}

// ---- painting --------------------------------------------------------------
void Canvas::drawBackground(QPainter &p, const Page &pg, const QRectF &area)
{
    if (pg.background == BackgroundKind::Blank)
        return;
    const double s = qMax(4.0, pg.gridSpacing);
    QPen pen(pg.gridColor);
    pen.setCosmetic(true);
    pen.setWidth(1);
    p.setPen(pen);

    const double startX = std::floor(area.left() / s) * s;
    const double startY = std::floor(area.top() / s) * s;

    if (pg.background == BackgroundKind::Grid) {
        for (double x = startX; x <= area.right(); x += s)
            p.drawLine(QPointF(x, area.top()), QPointF(x, area.bottom()));
        for (double y = startY; y <= area.bottom(); y += s)
            p.drawLine(QPointF(area.left(), y), QPointF(area.right(), y));
    } else if (pg.background == BackgroundKind::Lines) {
        for (double y = startY; y <= area.bottom(); y += s)
            p.drawLine(QPointF(area.left(), y), QPointF(area.right(), y));
    } else {
        p.setPen(Qt::NoPen);
        p.setBrush(pg.gridColor);
        for (double x = startX; x <= area.right(); x += s)
            for (double y = startY; y <= area.bottom(); y += s)
                p.drawEllipse(QPointF(x, y), 1.3, 1.3);
    }
}

void Canvas::drawSelection(QPainter &p)
{
    if (m_selection.empty())
        return;
    QPen pen(QColor(60, 120, 220));
    pen.setCosmetic(true);
    pen.setStyle(Qt::DashLine);
    pen.setWidth(1);
    p.setPen(pen);
    p.setBrush(Qt::NoBrush);
    for (Item *it : m_selection)
        p.drawRect(it->boundingRect());
}

void Canvas::drawBrushPreview(QPainter &p)
{
    if (!m_hoverValid || m_panning)
        return;

    if (m_settings.tool == ToolId::Eraser) {
        const double r = m_settings.eraserRadius * m_scale;
        QPen pen(QColor(70, 70, 70));
        pen.setStyle(Qt::DashLine);
        p.setPen(pen);
        p.setBrush(Qt::NoBrush);
        p.drawEllipse(m_cursorWidget, r, r);
        return;
    }

    QColor col;
    double w = 0.0;
    bool laser = false;
    switch (m_settings.tool) {
    case ToolId::Pen:         col = m_settings.penColor;   w = m_settings.penWidth;   break;
    case ToolId::Highlighter: col = m_settings.hlColor;    w = m_settings.hlWidth;    break;
    case ToolId::Line:
    case ToolId::Rectangle:
    case ToolId::Ellipse:     col = m_settings.shapeColor; w = m_settings.shapeWidth; break;
    case ToolId::Laser:       col = m_settings.laser.coreColor; w = m_settings.laser.width; laser = true; break;
    default: return;
    }

    const double r = qMax(1.5, w * 0.5 * m_scale);

    p.save();
    p.setRenderHint(QPainter::Antialiasing, true);

    if (laser && m_settings.laser.glowEnabled) {
        const double gr = r + m_settings.laser.glowRadius * m_scale;
        QRadialGradient g(m_cursorWidget, gr);
        QColor g0 = m_settings.laser.glowColor; g0.setAlphaF(0.55 * m_settings.laser.intensity);
        QColor g1 = m_settings.laser.glowColor; g1.setAlphaF(0.0);
        g.setColorAt(0.0, g0);
        g.setColorAt(1.0, g1);
        p.setPen(Qt::NoPen);
        p.setBrush(g);
        p.drawEllipse(m_cursorWidget, gr, gr);
    }

    QColor fill = col;
    fill.setAlphaF(laser ? m_settings.laser.intensity : 0.9);
    const QColor outline = (col.lightness() > 128) ? QColor(0, 0, 0, 170)
                                                   : QColor(255, 255, 255, 190);
    QPen pen(outline);
    pen.setWidthF(1.0);
    p.setPen(pen);
    p.setBrush(fill);
    p.drawEllipse(m_cursorWidget, r, r);
    p.restore();
}

void Canvas::paintEvent(QPaintEvent *)
{
    QPainter p(this);
    p.fillRect(rect(), QColor(90, 93, 99));
    if (!m_doc)
        return;

    p.save();
    p.translate(m_translate);
    p.scale(m_scale, m_scale);

    Page &pg = m_doc->current();

    if (pg.infinite) {
        const QRectF sceneRect =
            QRectF(widgetToScene(QPointF(0, 0)),
                   widgetToScene(QPointF(width(), height()))).normalized();
        p.fillRect(sceneRect, pg.bgColor);
        drawBackground(p, pg, sceneRect);
    } else {
        const QRectF sheet(0.0, 0.0,
                           qMax(1.0, pg.pageWidth), qMax(1.0, pg.pageHeight));
        // Soft drop shadow behind the sheet.
        p.save();
        p.setRenderHint(QPainter::Antialiasing, true);
        p.setPen(Qt::NoPen);
        p.setBrush(QColor(0, 0, 0, 55));
        p.drawRoundedRect(sheet.translated(6.0, 7.0), 2.0, 2.0);
        p.restore();
        // Paper.
        p.fillRect(sheet, pg.bgColor);
        // Background pattern, clipped to the sheet.
        p.save();
        p.setClipRect(sheet);
        drawBackground(p, pg, sheet);
        p.restore();
        // Crisp 1px border.
        p.save();
        QPen border(QColor(0, 0, 0, 45));
        border.setCosmetic(true);
        border.setWidth(1);
        p.setPen(border);
        p.setBrush(Qt::NoBrush);
        p.drawRect(sheet);
        p.restore();
    }

    p.setRenderHint(QPainter::Antialiasing, true);
    p.setRenderHint(QPainter::TextAntialiasing, true);

    // Vanish fade multiplier, applied only to ephemeral (vanishing) laser ink.
    const double vanishFade = m_fading
        ? fadeAlphaFor(m_fadeClock.elapsed(),
                       qMax(0, m_settings.laser.vanishDelayMs),
                       qMax(1, m_settings.laser.fadeDurationMs))
        : 1.0;

    for (const auto &ly : pg.layers) {
        if (!ly.visible)
            continue;
        const double layerOpacity = ly.opacity < 1.0 ? ly.opacity : 1.0;
        for (const auto &it : ly.items) {
            double o = layerOpacity;
            if (vanishFade < 1.0 && it->type() == ItemType::Stroke &&
                static_cast<const StrokeItem *>(it.get())->ephemeral)
                o *= vanishFade;
            p.save();
            p.setOpacity(o);
            it->paint(p);
            p.restore();
        }
    }

    if (m_activeStroke) m_activeStroke->paint(p);
    if (m_activeShape)  m_activeShape->paint(p);

    drawSelection(p);

    if (m_rubber) {
        QPen pen(QColor(60, 120, 220));
        pen.setCosmetic(true);
        pen.setStyle(Qt::DashLine);
        p.setPen(pen);
        p.setBrush(QColor(60, 120, 220, 40));
        p.drawRect(m_rubberRect);
    }

    p.restore();

    drawBrushPreview(p);
}

// ---- input -----------------------------------------------------------------
void Canvas::mousePressEvent(QMouseEvent *e)
{
    m_cursorWidget = e->position();
    m_hoverValid = true;

    // Right-click: canvas page-size presets (infinite / A4 / A5 / Letter /
    // Legal / custom). Modal, so the page reference stays valid during exec.
    if (e->button() == Qt::RightButton && m_doc) {
        Page &pg = m_doc->current();
        QMenu menu(this);
        QMenu *sizeMenu = menu.addMenu(tr("Page Size"));

        struct Preset { QString label; bool inf; double w; double h; };
        const QVector<Preset> presets = {
            { tr("Infinite Canvas"),    true,  0.0,    0.0    },
            { tr("A4 — Portrait"),      false, 794.0,  1123.0 },
            { tr("A4 — Landscape"),     false, 1123.0, 794.0  },
            { tr("A5 — Portrait"),      false, 559.0,  794.0  },
            { tr("A5 — Landscape"),     false, 794.0,  559.0  },
            { tr("Letter — Portrait"),  false, 816.0,  1056.0 },
            { tr("Letter — Landscape"), false, 1056.0, 816.0  },
            { tr("Legal — Portrait"),   false, 816.0,  1344.0 },
            { tr("Legal — Landscape"),  false, 1344.0, 816.0  },
        };
        for (int i = 0; i < presets.size(); ++i) {
            const Preset &pr = presets[i];
            QAction *a = sizeMenu->addAction(pr.label);
            a->setCheckable(true);
            a->setChecked(pr.inf
                ? pg.infinite
                : (!pg.infinite && qAbs(pg.pageWidth - pr.w) < 0.5 &&
                   qAbs(pg.pageHeight - pr.h) < 0.5));
            a->setData(i);
            if (i == 0)
                sizeMenu->addSeparator();
        }
        sizeMenu->addSeparator();
        QAction *customAct = sizeMenu->addAction(tr("Custom…"));

        QAction *chosen = menu.exec(e->globalPosition().toPoint());
        if (!chosen)
            return;

        if (chosen == customAct) {
            bool ok1 = false, ok2 = false;
            const int w = QInputDialog::getInt(
                this, tr("Custom Page Size"), tr("Width (px):"),
                qRound(pg.infinite ? 794.0 : pg.pageWidth), 50, 20000, 10, &ok1);
            if (!ok1)
                return;
            const int h = QInputDialog::getInt(
                this, tr("Custom Page Size"), tr("Height (px):"),
                qRound(pg.infinite ? 1123.0 : pg.pageHeight), 50, 20000, 10, &ok2);
            if (!ok2)
                return;
            pg.infinite   = false;
            pg.pageWidth  = static_cast<double>(w);
            pg.pageHeight = static_cast<double>(h);
            m_doc->markChanged();
            zoomToFit();
            update();
            return;
        }

        const int idx = chosen->data().toInt();
        if (idx >= 0 && idx < presets.size()) {
            const Preset &pr = presets[idx];
            pg.infinite = pr.inf;
            if (!pr.inf) {
                pg.pageWidth  = pr.w;
                pg.pageHeight = pr.h;
            }
            m_doc->markChanged();
            zoomToFit();
            update();
        }
        return;
    }

    if (e->button() == Qt::MiddleButton ||
        (m_spaceDown && e->button() == Qt::LeftButton)) {
        m_panning = true;
        m_lastPanPos = e->position().toPoint();
        setCursor(Qt::ClosedHandCursor);
        return;
    }
    if (e->button() == Qt::LeftButton)
        handlePointer(Action::Press, e->position(), 1.0, e->modifiers(), false);
}

void Canvas::mouseMoveEvent(QMouseEvent *e)
{
    m_cursorWidget = e->position();
    m_hoverValid = true;
    if (m_panning) {
        const QPoint d = e->position().toPoint() - m_lastPanPos;
        m_lastPanPos = e->position().toPoint();
        m_translate += QPointF(d);
        update();
        emit viewChanged();
        return;
    }
    handlePointer(Action::Move, e->position(), 1.0, e->modifiers(), false);
    update();
    emit cursorMoved(widgetToScene(e->position()));
}

void Canvas::mouseReleaseEvent(QMouseEvent *e)
{
    m_cursorWidget = e->position();
    if (m_panning &&
        (e->button() == Qt::MiddleButton || e->button() == Qt::LeftButton)) {
        m_panning = false;
        updateCursor();
        return;
    }
    if (e->button() == Qt::LeftButton)
        handlePointer(Action::Release, e->position(), 1.0, e->modifiers(), false);
}

void Canvas::tabletEvent(QTabletEvent *e)
{
    const bool eraserTip =
        e->pointerType() == QPointingDevice::PointerType::Eraser;
    double pr = e->pressure();
    if (pr <= 0.0)
        pr = 1.0;
    m_cursorWidget = e->position();
    m_hoverValid = true;

    switch (e->type()) {
    case QEvent::TabletPress:
        handlePointer(Action::Press, e->position(), pr, e->modifiers(), eraserTip);
        break;
    case QEvent::TabletMove:
        handlePointer(Action::Move, e->position(), pr, e->modifiers(), eraserTip);
        emit cursorMoved(widgetToScene(e->position()));
        update();
        break;
    case QEvent::TabletRelease:
        handlePointer(Action::Release, e->position(), pr, e->modifiers(), eraserTip);
        break;
    default:
        break;
    }
    e->accept();
}

void Canvas::wheelEvent(QWheelEvent *e)
{
    const double factor = std::pow(1.0015, e->angleDelta().y());
    zoomAround(e->position(), factor);
    e->accept();
}

void Canvas::keyPressEvent(QKeyEvent *e)
{
    if (e->key() == Qt::Key_Space) {
        m_spaceDown = true;
        setCursor(Qt::OpenHandCursor);
        e->accept();
        return;
    }
    if (e->key() == Qt::Key_Delete || e->key() == Qt::Key_Backspace) {
        deleteSelection();
        e->accept();
        return;
    }
    if (e->key() == Qt::Key_Escape) {
        cancelActive();
        clearSelection();
        clearLaser();
        e->accept();
        return;
    }
    QWidget::keyPressEvent(e);
}

void Canvas::keyReleaseEvent(QKeyEvent *e)
{
    if (e->key() == Qt::Key_Space) {
        m_spaceDown = false;
        updateCursor();
        e->accept();
        return;
    }
    QWidget::keyReleaseEvent(e);
}

void Canvas::leaveEvent(QEvent *e)
{
    m_hoverValid = false;
    update();
    QWidget::leaveEvent(e);
}

// ---- pointer dispatch ------------------------------------------------------
void Canvas::handlePointer(Action a, const QPointF &widgetPos, double pressure,
                           Qt::KeyboardModifiers mods, bool eraserTip)
{
    if (!m_doc)
        return;
    const QPointF sp = widgetToScene(widgetPos);
    m_cursorWidget = widgetPos;

    const ToolId t = eraserTip ? ToolId::Eraser : m_settings.tool;

    if (t == ToolId::Laser) {
        // In BOTH modes the laser is a real glow stroke on the active layer, so
        // it can be erased, undone, selected and saved exactly like the pen.
        // Vanishing mode only tags it 'ephemeral' so it fades + removes itself
        // when the pen later leaves the tablet's range.
        Layer &lly = m_doc->current().active();
        if (lly.locked)
            return;
        if (a == Action::Press) {
            stopVanish();                 // a new stroke cancels any pending fade
            m_drawing = true;
            m_activeStroke = std::make_unique<StrokeItem>();
            m_activeStroke->highlighter   = false;
            m_activeStroke->pressureWidth = false;
            m_activeStroke->color         = m_settings.laser.coreColor;
            m_activeStroke->baseWidth     = m_settings.laser.width;
            m_activeStroke->opacity       = qBound(0.0, m_settings.laser.intensity, 1.0);
            m_activeStroke->glow          = m_settings.laser.glowEnabled;
            m_activeStroke->glowColor     = m_settings.laser.glowColor;
            m_activeStroke->glowRadius    = m_settings.laser.glowRadius;
            m_activeStroke->ephemeral     = m_settings.laser.vanishMode;
            m_activeStroke->addPoint(StrokePoint(sp.x(), sp.y(), pressure));
            update();
        } else if (a == Action::Move && m_drawing && m_activeStroke) {
            m_activeStroke->addPoint(StrokePoint(sp.x(), sp.y(), pressure));
            update();
        } else if (a == Action::Release && m_drawing) {
            if (m_activeStroke && !m_activeStroke->isEmpty())
                commitAdd(std::move(m_activeStroke), QStringLiteral("Laser"));
            m_activeStroke.reset();
            m_drawing = false;
            update();
        }
        return;
    }

    Layer &ly = m_doc->current().active();
    if (ly.locked)
        return;

    switch (t) {
    case ToolId::Pen:
    case ToolId::Highlighter: {
        const bool hl = (t == ToolId::Highlighter);
        if (a == Action::Press) {
            m_drawing = true;
            m_activeStroke = std::make_unique<StrokeItem>();
            m_activeStroke->highlighter   = hl;
            m_activeStroke->color         = hl ? m_settings.hlColor : m_settings.penColor;
            m_activeStroke->baseWidth     = hl ? m_settings.hlWidth : m_settings.penWidth;
            m_activeStroke->opacity       = hl ? m_settings.hlOpacity : 1.0;
            m_activeStroke->pressureWidth = hl ? false : m_settings.penPressure;
            m_activeStroke->addPoint(StrokePoint(sp.x(), sp.y(), pressure));
            update();
        } else if (a == Action::Move && m_drawing && m_activeStroke) {
            m_activeStroke->addPoint(StrokePoint(sp.x(), sp.y(), pressure));
            update();
        } else if (a == Action::Release && m_drawing) {
            if (m_activeStroke && !m_activeStroke->isEmpty())
                commitAdd(std::move(m_activeStroke),
                          hl ? QStringLiteral("Highlight") : QStringLiteral("Draw"));
            m_activeStroke.reset();
            m_drawing = false;
            update();
        }
        break;
    }
    case ToolId::Eraser: {
        if (a == Action::Press) { m_erasing = true; m_eraseStash.clear(); eraseAt(sp); update(); }
        else if (a == Action::Move && m_erasing) { eraseAt(sp); update(); }
        else if (a == Action::Release && m_erasing) { finishErase(); m_erasing = false; update(); }
        break;
    }
    case ToolId::Line:
    case ToolId::Rectangle:
    case ToolId::Ellipse: {
        if (a == Action::Press) {
            m_activeShape = std::make_unique<ShapeItem>();
            m_activeShape->kind = (t == ToolId::Line) ? ShapeKind::Line
                                : (t == ToolId::Rectangle) ? ShapeKind::Rectangle
                                : ShapeKind::Ellipse;
            m_activeShape->color  = m_settings.shapeColor;
            m_activeShape->width  = m_settings.shapeWidth;
            m_activeShape->filled = m_settings.shapeFilled;
            m_activeShape->fill   = m_settings.shapeFill;
            m_activeShape->p1 = sp;
            m_activeShape->p2 = sp;
            m_drawing = true;
            update();
        } else if (a == Action::Move && m_drawing && m_activeShape) {
            m_activeShape->p2 = (mods & Qt::ShiftModifier)
                ? constrainShape(m_activeShape->p1, sp, m_activeShape->kind)
                : sp;
            update();
        } else if (a == Action::Release && m_drawing) {
            if (m_activeShape) {
                const QLineF diag(m_activeShape->p1, m_activeShape->p2);
                if (diag.length() >= 2.0)
                    commitAdd(std::move(m_activeShape), QStringLiteral("Shape"));
            }
            m_activeShape.reset();
            m_drawing = false;
            update();
        }
        break;
    }
    case ToolId::Text: {
        if (a == Action::Press)
            addTextAt(sp);
        break;
    }
    case ToolId::Select: {
        handleSelect(a, sp, mods);
        break;
    }
    case ToolId::Laser:
        break;
    }
}

// ---- selection -------------------------------------------------------------
void Canvas::handleSelect(Action a, const QPointF &sp, Qt::KeyboardModifiers mods)
{
    if (a == Action::Press) {
        Item *hit = topItemAt(sp);
        if (hit) {
            const bool already =
                std::find(m_selection.begin(), m_selection.end(), hit) != m_selection.end();
            if (mods & Qt::ShiftModifier) {
                if (already) removeFromSelection(hit);
                else addToSelection(hit);
            } else if (!already) {
                setSelectionSingle(hit);
            }
            m_movingSelection = true;
            m_moveStartScene = sp;
            m_moveAccum = QPointF(0, 0);
        } else {
            if (!(mods & Qt::ShiftModifier))
                clearSelection();
            m_rubber = true;
            m_rubberStartScene = sp;
            m_rubberRect = QRectF(sp, sp);
        }
        update();
    } else if (a == Action::Move) {
        if (m_movingSelection && !m_selection.empty()) {
            const QPointF d = sp - m_moveStartScene;
            const QPointF step = d - m_moveAccum;
            for (Item *it : m_selection)
                it->translate(step);
            m_moveAccum = d;
            update();
        } else if (m_rubber) {
            m_rubberRect = QRectF(m_rubberStartScene, sp).normalized();
            update();
        }
    } else if (a == Action::Release) {
        if (m_movingSelection) {
            m_movingSelection = false;
            if (!m_selection.empty() &&
                (std::abs(m_moveAccum.x()) > 0.01 || std::abs(m_moveAccum.y()) > 0.01)) {
                // Roll back the live translation, then re-apply it as one undoable command.
                for (Item *it : m_selection)
                    it->translate(-m_moveAccum);
                m_doc->undoStack()->push(new TranslateItemsCommand(
                    m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
                    m_selection, m_moveAccum, QStringLiteral("Move")));
            }
            m_moveAccum = QPointF(0, 0);
        } else if (m_rubber) {
            selectInRect(m_rubberRect, (QApplication::keyboardModifiers() & Qt::ShiftModifier));
            m_rubber = false;
            update();
        }
    }
}
void Canvas::selectInRect(const QRectF &r, bool add)
{
    if (!m_doc)
        return;
    if (!add)
        m_selection.clear();
    Layer &ly = m_doc->current().active();
    for (auto &it : ly.items) {
        if (r.contains(it->boundingRect()) || r.intersects(it->boundingRect())) {
            it->selected = true;
            if (std::find(m_selection.begin(), m_selection.end(), it.get()) == m_selection.end())
                m_selection.push_back(it.get());
        }
    }
    update();
}

void Canvas::setSelectionSingle(Item *it)
{
    clearSelection();
    if (it) {
        it->selected = true;
        m_selection.push_back(it);
    }
}

void Canvas::addToSelection(Item *it)
{
    if (!it)
        return;
    if (std::find(m_selection.begin(), m_selection.end(), it) == m_selection.end()) {
        it->selected = true;
        m_selection.push_back(it);
    }
}

void Canvas::removeFromSelection(Item *it)
{
    auto pos = std::find(m_selection.begin(), m_selection.end(), it);
    if (pos != m_selection.end()) {
        (*pos)->selected = false;
        m_selection.erase(pos);
    }
}

bool Canvas::hitTest(Item *it, const QPointF &sp, double radius) const
{
    if (!it)
        return false;
    const QRectF bb = it->boundingRect().adjusted(-radius, -radius, radius, radius);
    if (!bb.contains(sp))
        return false;

    if (it->type() == ItemType::Stroke) {
        const auto *s = static_cast<const StrokeItem *>(it);
        if (s->points.size() == 1)
            return std::hypot(sp.x() - s->points.first().x,
                              sp.y() - s->points.first().y) <= radius + s->baseWidth;
        for (int i = 1; i < s->points.size(); ++i) {
            if (distToSegment(sp, s->points[i - 1].pos(), s->points[i].pos())
                    <= radius + s->baseWidth * 0.5)
                return true;
        }
        return false;
    }
    return true;
}

Item *Canvas::topItemAt(const QPointF &sp)
{
    if (!m_doc)
        return nullptr;
    Layer &ly = m_doc->current().active();
    const double radius = 6.0 / m_scale;
    for (auto it = ly.items.rbegin(); it != ly.items.rend(); ++it) {
        if (hitTest(it->get(), sp, radius))
            return it->get();
    }
    return nullptr;
}

// ---- mutations -------------------------------------------------------------
void Canvas::commitAdd(ItemPtr item, const QString &text)
{
    if (!m_doc || !item)
        return;
    m_doc->undoStack()->push(new AddItemCommand(
        m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
        std::move(item), text));
}

void Canvas::eraseAt(const QPointF &sp)
{
    if (!m_doc)
        return;
    Layer &ly = m_doc->current().active();
    const double radius = m_settings.eraserRadius;
    for (std::size_t i = 0; i < ly.items.size();) {
        if (hitTest(ly.items[i].get(), sp, radius)) {
            m_eraseStash.push_back({ i, std::move(ly.items[i]) });
            ly.items.erase(ly.items.begin() + static_cast<long>(i));
        } else {
            ++i;
        }
    }
}

void Canvas::finishErase()
{
    if (!m_doc || m_eraseStash.empty()) {
        m_eraseStash.clear();
        return;
    }
    // Reinsert the removed items, then remove them again through the undo stack
    // so the whole erase gesture is a single undoable action.
    Layer &ly = m_doc->current().active();
    std::sort(m_eraseStash.begin(), m_eraseStash.end(),
              [](const EraseStash &a, const EraseStash &b) { return a.index < b.index; });
    std::vector<Item *> targets;
    for (auto &st : m_eraseStash) {
        const std::size_t idx = std::min(st.index, ly.items.size());
        Item *raw = st.item.get();
        ly.items.insert(ly.items.begin() + static_cast<long>(idx), std::move(st.item));
        targets.push_back(raw);
    }
    m_eraseStash.clear();
    if (!targets.empty())
        m_doc->undoStack()->push(new RemoveItemsCommand(
            m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
            std::move(targets), QStringLiteral("Erase")));
}

void Canvas::addTextAt(const QPointF &sp)
{
    if (!m_doc)
        return;
    bool ok = false;
    const QString text = QInputDialog::getText(
        this, tr("Add Text"), tr("Text:"), QLineEdit::Normal, QString(), &ok);
    if (!ok || text.isEmpty())
        return;
    auto item = std::make_unique<TextItem>();
    item->pos   = sp;
    item->text  = text;
    item->color = m_settings.textColor;
    item->font  = m_settings.textFont;
    commitAdd(std::move(item), QStringLiteral("Text"));
}

void Canvas::cancelActive()
{
    m_activeStroke.reset();
    m_activeShape.reset();
    m_drawing = false;
    m_erasing = false;
    m_movingSelection = false;
    m_rubber = false;
    if (!m_eraseStash.empty() && m_doc) {
        // Restore anything stashed by an interrupted erase gesture.
        Layer &ly = m_doc->current().active();
        std::sort(m_eraseStash.begin(), m_eraseStash.end(),
                  [](const EraseStash &a, const EraseStash &b) { return a.index < b.index; });
        for (auto &st : m_eraseStash) {
            const std::size_t idx = std::min(st.index, ly.items.size());
            ly.items.insert(ly.items.begin() + static_cast<long>(idx), std::move(st.item));
        }
    }
    m_eraseStash.clear();
}

void Canvas::deleteSelection()
{
    if (!m_doc || m_selection.empty())
        return;
    std::vector<Item *> targets = m_selection;
    m_doc->undoStack()->push(new RemoveItemsCommand(
        m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
        std::move(targets), QStringLiteral("Delete")));
    m_selection.clear();
    update();
}

void Canvas::selectAll()
{
    if (!m_doc)
        return;
    clearSelection();
    Layer &ly = m_doc->current().active();
    for (auto &it : ly.items) {
        it->selected = true;
        m_selection.push_back(it.get());
    }
    update();
}

void Canvas::clearSelection()
{
    for (Item *it : m_selection)
        it->selected = false;
    m_selection.clear();
    update();
}

void Canvas::updateCursor()
{
    switch (m_settings.tool) {
    case ToolId::Eraser:
        setCursor(Qt::BlankCursor);
        break;
    case ToolId::Text:
        setCursor(Qt::IBeamCursor);
        break;
    default:
        setCursor(Qt::ArrowCursor);
        break;
    }
}

} // namespace ib
EOF

log "PART 14 complete: page-size presets (infinite / A4 / A5 / Letter / Legal / custom) with paper-sheet rendering, persistence, and a right-click Page Size menu"


# ---------------------------------------------------------------------------
#  PART 15 : Granular background engine + advanced graph.
#            - BackgroundKind gains Graph (major+minor "graph-in-graph"),
#              Isometric, Music, Log presets.
#            - Per-page minor color, minor divisions, axes toggle, axis color.
#            - drawBackground renders every preset with a screen-space density
#              guard; axes overlay on top.
#            - Right-click canvas menu exposes background preset, axes,
#              spacing, minor divisions, and all four per-page colors.
#            Overwrites Types.h, Page.h, Serializer.cpp, Canvas.cpp only.
# ---------------------------------------------------------------------------
log "PART 15: granular background engine + advanced graph presets"

# ---------------------------------------------------------------------------
#  src/model/Types.h  (overwrite: extend BackgroundKind, append-only)
# ---------------------------------------------------------------------------
cat > src/model/Types.h <<'EOF'
#pragma once

#include <QPointF>

namespace ib {

enum class ToolId {
    Pen,
    Highlighter,
    Eraser,
    Select,
    Line,
    Rectangle,
    Ellipse,
    Text,
    Laser
};

enum class ItemType { Stroke, Shape, Text, Image };
enum class ShapeKind { Line, Rectangle, Ellipse };

// NOTE: values are append-only so existing .iboard files keep loading
// correctly (Blank=0, Grid=1, Lines=2, Dots=3, ...).
enum class BackgroundKind { Blank, Grid, Lines, Dots, Graph, Isometric, Music, Log };

struct StrokePoint {
    double x = 0.0;
    double y = 0.0;
    double pressure = 1.0;

    StrokePoint() = default;
    StrokePoint(double px, double py, double pr = 1.0)
        : x(px), y(py), pressure(pr) {}

    QPointF pos() const { return QPointF(x, y); }
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/model/Page.h  (overwrite: add granular background fields)
# ---------------------------------------------------------------------------
cat > src/model/Page.h <<'EOF'
#pragma once

#include <QColor>
#include <QRectF>
#include <vector>

#include "model/Layer.h"
#include "model/Types.h"

namespace ib {

struct Page {
    BackgroundKind background   = BackgroundKind::Grid;
    QColor         bgColor      = QColor(255, 255, 255);
    QColor         gridColor    = QColor(223, 223, 223);   // major / primary grid
    double         gridSpacing  = 40.0;                     // major spacing (px)

    // Granular background engine.
    QColor         minorColor     = QColor(233, 236, 239);  // minor grid (graph/log)
    int            minorDivisions = 5;                       // minor cells per major cell
    bool           showAxes       = false;                   // draw x=0 / y=0 axes
    QColor         axisColor      = QColor(120, 120, 120);

    // Page geometry (Part 14).
    bool           infinite     = true;
    double         pageWidth    = 794.0;
    double         pageHeight   = 1123.0;

    std::vector<Layer> layers;
    int            activeLayer  = 0;

    Page() { layers.emplace_back(); }

    Layer &active() {
        if (layers.empty()) layers.emplace_back();
        if (activeLayer < 0 || activeLayer >= static_cast<int>(layers.size()))
            activeLayer = 0;
        return layers[static_cast<std::size_t>(activeLayer)];
    }

    // Union of every visible item's bounding rect (empty if the page is blank).
    QRectF contentBounds() const {
        QRectF r;
        for (const auto &layer : layers) {
            if (!layer.visible) continue;
            for (const auto &it : layer.items)
                r = r.isNull() ? it->boundingRect() : r.united(it->boundingRect());
        }
        return r;
    }
};

} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/core/Serializer.cpp  (overwrite: persist granular background fields)
# ---------------------------------------------------------------------------
cat > src/core/Serializer.cpp <<'EOF'
#include "core/Serializer.h"

#include "model/Document.h"
#include "model/Item.h"

#include <QFile>
#include <QSaveFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonParseError>
#include <QColor>

namespace ib {
namespace io {

static QJsonArray colorToJson(const QColor &c)
{
    QJsonArray a;
    a.append(c.red());
    a.append(c.green());
    a.append(c.blue());
    a.append(c.alpha());
    return a;
}

static QColor colorFromJson(const QJsonValue &v, const QColor &def)
{
    const QJsonArray a = v.toArray();
    if (a.size() < 3)
        return def;
    const int alpha = a.size() >= 4 ? a.at(3).toInt(255) : 255;
    return QColor(a.at(0).toInt(), a.at(1).toInt(), a.at(2).toInt(), alpha);
}

static ItemType typeFromString(const QString &s)
{
    if (s == QLatin1String("stroke")) return ItemType::Stroke;
    if (s == QLatin1String("shape"))  return ItemType::Shape;
    if (s == QLatin1String("text"))   return ItemType::Text;
    return ItemType::Image;
}

static QJsonObject pageToJson(const Page &pg)
{
    QJsonObject o;
    o["background"]     = static_cast<int>(pg.background);
    o["bgColor"]        = colorToJson(pg.bgColor);
    o["gridColor"]      = colorToJson(pg.gridColor);
    o["gridSpacing"]    = pg.gridSpacing;
    o["minorColor"]     = colorToJson(pg.minorColor);
    o["minorDivisions"] = pg.minorDivisions;
    o["showAxes"]       = pg.showAxes;
    o["axisColor"]      = colorToJson(pg.axisColor);
    o["infinite"]       = pg.infinite;
    o["pageWidth"]      = pg.pageWidth;
    o["pageHeight"]     = pg.pageHeight;
    o["activeLayer"]    = pg.activeLayer;

    QJsonArray layers;
    for (const auto &ly : pg.layers) {
        QJsonObject lo;
        lo["name"]    = ly.name;
        lo["visible"] = ly.visible;
        lo["locked"]  = ly.locked;
        lo["opacity"] = ly.opacity;

        QJsonArray items;
        for (const auto &it : ly.items) {
            QJsonObject io;
            it->write(io);
            items.append(io);
        }
        lo["items"] = items;
        layers.append(lo);
    }
    o["layers"] = layers;
    return o;
}

static Page pageFromJson(const QJsonObject &o)
{
    Page pg;
    pg.background   = static_cast<BackgroundKind>(
        o.value("background").toInt(static_cast<int>(BackgroundKind::Grid)));
    pg.bgColor      = colorFromJson(o.value("bgColor"), QColor(255, 255, 255));
    pg.gridColor    = colorFromJson(o.value("gridColor"), QColor(223, 223, 223));
    pg.gridSpacing  = o.value("gridSpacing").toDouble(40.0);

    pg.minorColor     = colorFromJson(o.value("minorColor"), QColor(233, 236, 239));
    pg.minorDivisions = o.value("minorDivisions").toInt(5);
    pg.showAxes       = o.value("showAxes").toBool(false);
    pg.axisColor      = colorFromJson(o.value("axisColor"), QColor(120, 120, 120));

    pg.infinite     = o.value("infinite").toBool(true);
    pg.pageWidth    = o.value("pageWidth").toDouble(794.0);
    pg.pageHeight   = o.value("pageHeight").toDouble(1123.0);

    pg.layers.clear();
    const QJsonArray layers = o.value("layers").toArray();
    for (const auto &lv : layers) {
        const QJsonObject lo = lv.toObject();
        Layer ly;
        ly.name    = lo.value("name").toString(QStringLiteral("Layer"));
        ly.visible = lo.value("visible").toBool(true);
        ly.locked  = lo.value("locked").toBool(false);
        ly.opacity = lo.value("opacity").toDouble(1.0);

        const QJsonArray items = lo.value("items").toArray();
        for (const auto &iv : items) {
            const QJsonObject io = iv.toObject();
            ItemPtr item = makeItem(typeFromString(io.value("type").toString()));
            if (item) {
                item->read(io);
                ly.items.push_back(std::move(item));
            }
        }
        pg.layers.push_back(std::move(ly));
    }
    if (pg.layers.empty())
        pg.layers.emplace_back();

    pg.activeLayer = o.value("activeLayer").toInt(0);
    return pg;
}

QByteArray toBytes(const Document &doc)
{
    QJsonObject root;
    root["format"]  = "inkboard";
    root["version"] = 1;

    QJsonArray pages;
    for (int i = 0; i < doc.pageCount(); ++i)
        pages.append(pageToJson(doc.page(i)));
    root["pages"] = pages;

    return QJsonDocument(root).toJson(QJsonDocument::Indented);
}

bool fromBytes(std::vector<Page> &pagesOut, const QByteArray &bytes, QString *error)
{
    QJsonParseError pe;
    const QJsonDocument doc = QJsonDocument::fromJson(bytes, &pe);
    if (pe.error != QJsonParseError::NoError) {
        if (error) *error = pe.errorString();
        return false;
    }
    const QJsonObject root = doc.object();
    if (root.value("format").toString() != QLatin1String("inkboard")) {
        if (error) *error = QStringLiteral("Not an InkBoard (.iboard) file.");
        return false;
    }

    pagesOut.clear();
    const QJsonArray pages = root.value("pages").toArray();
    for (const auto &pv : pages)
        pagesOut.push_back(pageFromJson(pv.toObject()));
    if (pagesOut.empty())
        pagesOut.emplace_back();
    return true;
}

bool saveToFile(const Document &doc, const QString &path, QString *error)
{
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly)) {
        if (error) *error = file.errorString();
        return false;
    }
    const QByteArray bytes = toBytes(doc);
    if (file.write(bytes) != bytes.size()) {
        if (error) *error = file.errorString();
        return false;
    }
    if (!file.commit()) {
        if (error) *error = file.errorString();
        return false;
    }
    return true;
}

bool loadFromFile(Document &doc, const QString &path, QString *error)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        if (error) *error = file.errorString();
        return false;
    }
    const QByteArray bytes = file.readAll();
    std::vector<Page> pages;
    if (!fromBytes(pages, bytes, error))
        return false;

    doc.setPages(std::move(pages));
    doc.setFilePath(path);
    return true;
}

} // namespace io
} // namespace ib
EOF

# ---------------------------------------------------------------------------
#  src/canvas/Canvas.cpp  (overwrite: multi-preset drawBackground + extended
#                          right-click menu; all Part 13/14 behavior retained)
# ---------------------------------------------------------------------------
cat > src/canvas/Canvas.cpp <<'EOF'
#include "canvas/Canvas.h"

#include "core/Commands.h"
#include "model/TextItem.h"
#include "model/ImageItem.h"

#include <QApplication>
#include <QTimer>
#include <QPainter>
#include <QPen>
#include <QRadialGradient>
#include <QMouseEvent>
#include <QTabletEvent>
#include <QWheelEvent>
#include <QKeyEvent>
#include <QPointingDevice>
#include <QInputDialog>
#include <QLineEdit>
#include <QMenu>
#include <QAction>
#include <QColorDialog>
#include <QVector>
#include <QUndoStack>
#include <QLineF>
#include <algorithm>
#include <cmath>

namespace ib {

static const double kPi = 3.14159265358979323846;

static double distToSegment(const QPointF &p, const QPointF &a, const QPointF &b)
{
    const QPointF ab = b - a;
    const double len2 = ab.x() * ab.x() + ab.y() * ab.y();
    if (len2 <= 1e-9)
        return std::hypot(p.x() - a.x(), p.y() - a.y());
    double t = ((p.x() - a.x()) * ab.x() + (p.y() - a.y()) * ab.y()) / len2;
    t = std::max(0.0, std::min(1.0, t));
    const QPointF proj(a.x() + t * ab.x(), a.y() + t * ab.y());
    return std::hypot(p.x() - proj.x(), p.y() - proj.y());
}

static QPointF constrainShape(const QPointF &a, const QPointF &b, ShapeKind kind)
{
    const QPointF d = b - a;
    if (kind == ShapeKind::Line) {
        double ang = std::atan2(d.y(), d.x());
        const double step = kPi / 4.0;
        ang = std::round(ang / step) * step;
        const double len = std::hypot(d.x(), d.y());
        return a + QPointF(std::cos(ang) * len, std::sin(ang) * len);
    }
    const double s = std::max(std::abs(d.x()), std::abs(d.y()));
    return a + QPointF(d.x() < 0 ? -s : s, d.y() < 0 ? -s : s);
}

// Vanish fade curve: full until 'delay', then linear to 0 over 'dur'.
static double fadeAlphaFor(qint64 elapsedMs, int delayMs, int durMs)
{
    if (elapsedMs <= delayMs)
        return 1.0;
    const double t = static_cast<double>(elapsedMs - delayMs) /
                     static_cast<double>(qMax(1, durMs));
    if (t >= 1.0)
        return 0.0;
    return 1.0 - t;
}

static bool layerHasEphemeral(const Layer &ly)
{
    for (const auto &it : ly.items)
        if (it->type() == ItemType::Stroke &&
            static_cast<const StrokeItem *>(it.get())->ephemeral)
            return true;
    return false;
}

Canvas::Canvas(QWidget *parent)
    : QWidget(parent)
{
    setFocusPolicy(Qt::StrongFocus);
    setMouseTracking(true);
    setAttribute(Qt::WA_TabletTracking, true);
    setAutoFillBackground(false);
    m_translate = QPointF(40, 40);

    qApp->installEventFilter(this);

    m_fadeTimer = new QTimer(this);
    m_fadeTimer->setInterval(16);
    connect(m_fadeTimer, &QTimer::timeout, this, &Canvas::onFadeTick);

    updateCursor();
}

void Canvas::setDocument(Document *doc)
{
    if (m_doc == doc)
        return;
    if (m_doc) {
        m_doc->disconnect(this);
        if (m_doc->undoStack())
            m_doc->undoStack()->disconnect(this);
    }
    m_doc = doc;
    stopVanish();
    cancelActive();
    m_selection.clear();

    if (m_doc) {
        connect(m_doc, &Document::currentPageChanged, this, [this](int) {
            stopVanish(); cancelActive(); m_selection.clear(); update();
        });
        connect(m_doc, &Document::pagesChanged, this, [this]() {
            stopVanish(); cancelActive(); m_selection.clear(); update();
        });
        connect(m_doc, &Document::contentChanged, this, [this]() { update(); });
        if (m_doc->undoStack()) {
            connect(m_doc->undoStack(), &QUndoStack::indexChanged, this, [this](int) {
                m_selection.clear(); cancelActive(); update();
            });
        }
    }
    update();
}

void Canvas::setTool(ToolId t)
{
    cancelActive();
    m_settings.tool = t;
    updateCursor();
    emit toolChanged(t);
    update();
}

void Canvas::clearLaser()
{
    stopVanish();
    update();
}

// ---- laser vanishing -------------------------------------------------------
void Canvas::startVanish()
{
    if (!m_doc || !layerHasEphemeral(m_doc->current().active()))
        return;
    m_fading = true;
    m_fadeClock.restart();
    if (!m_fadeTimer->isActive())
        m_fadeTimer->start();
    update();
}

void Canvas::stopVanish()
{
    if (!m_fading)
        return;
    m_fading = false;
    if (m_fadeTimer->isActive())
        m_fadeTimer->stop();
    update();
}

void Canvas::onFadeTick()
{
    if (!m_fading || !m_doc) {
        m_fading = false;
        m_fadeTimer->stop();
        return;
    }
    const qint64 el = m_fadeClock.elapsed();
    const int delay = qMax(0, m_settings.laser.vanishDelayMs);
    const int dur   = qMax(1, m_settings.laser.fadeDurationMs);

    if (el < static_cast<qint64>(delay) + dur) {
        update();
        return;
    }

    m_fading = false;
    m_fadeTimer->stop();

    Layer &ly = m_doc->current().active();
    std::vector<Item *> targets;
    for (auto &it : ly.items)
        if (it->type() == ItemType::Stroke &&
            static_cast<StrokeItem *>(it.get())->ephemeral)
            targets.push_back(it.get());

    if (!targets.empty())
        m_doc->undoStack()->push(new RemoveItemsCommand(
            m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
            std::move(targets), QStringLiteral("Laser vanish")));
    update();
}

bool Canvas::eventFilter(QObject *obj, QEvent *ev)
{
    if (ev->type() == QEvent::TabletLeaveProximity) {
        if (m_settings.tool == ToolId::Laser && m_settings.laser.vanishMode && !m_drawing)
            startVanish();
    } else if (ev->type() == QEvent::TabletEnterProximity) {
        stopVanish();
    }
    return QWidget::eventFilter(obj, ev);
}

// ---- view ------------------------------------------------------------------
void Canvas::zoomAround(const QPointF &widgetPos, double factor)
{
    const QPointF before = widgetToScene(widgetPos);
    m_scale = qBound(0.05, m_scale * factor, 40.0);
    m_translate = widgetPos - before * m_scale;
    update();
    emit viewChanged();
}

void Canvas::zoomIn()  { zoomAround(QPointF(width() / 2.0, height() / 2.0), 1.2); }
void Canvas::zoomOut() { zoomAround(QPointF(width() / 2.0, height() / 2.0), 1.0 / 1.2); }

void Canvas::resetView()
{
    m_scale = 1.0;
    m_translate = QPointF(40, 40);
    update();
    emit viewChanged();
}

void Canvas::zoomToFit()
{
    if (!m_doc) { update(); return; }
    Page &pg = m_doc->current();
    QRectF b;
    if (!pg.infinite)
        b = QRectF(0.0, 0.0, qMax(1.0, pg.pageWidth), qMax(1.0, pg.pageHeight));
    else
        b = pg.contentBounds();
    if (b.isNull()) { resetView(); return; }
    b.adjust(-40, -40, 40, 40);
    const double sx = width()  / b.width();
    const double sy = height() / b.height();
    m_scale = qBound(0.05, qMin(sx, sy), 40.0);
    m_translate = QPointF(width() / 2.0, height() / 2.0) - b.center() * m_scale;
    update();
    emit viewChanged();
}

// ---- background rendering --------------------------------------------------
void Canvas::drawBackground(QPainter &p, const Page &pg, const QRectF &area)
{
    if (pg.background == BackgroundKind::Blank && !pg.showAxes)
        return;

    const double major = qMax(4.0, pg.gridSpacing);
    const int divisions = qBound(1, pg.minorDivisions, 40);
    const double minor = major / divisions;

    // Skip a line set when its on-screen spacing would be too dense to read.
    const auto visible = [this](double spacingScene) {
        return spacingScene * m_scale >= 3.5;
    };

    const auto lineSet = [&](double spacing, const QColor &color, double penW,
                             bool vertical, bool horizontal) {
        if (!visible(spacing))
            return;
        QPen pen(color);
        pen.setCosmetic(true);
        pen.setWidthF(penW);
        p.setPen(pen);
        if (vertical) {
            const double sx = std::floor(area.left() / spacing) * spacing;
            for (double x = sx; x <= area.right(); x += spacing)
                p.drawLine(QPointF(x, area.top()), QPointF(x, area.bottom()));
        }
        if (horizontal) {
            const double sy = std::floor(area.top() / spacing) * spacing;
            for (double y = sy; y <= area.bottom(); y += spacing)
                p.drawLine(QPointF(area.left(), y), QPointF(area.right(), y));
        }
    };

    switch (pg.background) {
    case BackgroundKind::Blank:
        break;
    case BackgroundKind::Grid:
        lineSet(major, pg.gridColor, 1.0, true, true);
        break;
    case BackgroundKind::Lines:
        lineSet(major, pg.gridColor, 1.0, false, true);
        break;
    case BackgroundKind::Dots: {
        if (visible(major)) {
            p.setPen(Qt::NoPen);
            p.setBrush(pg.gridColor);
            const double sx = std::floor(area.left() / major) * major;
            const double sy = std::floor(area.top() / major) * major;
            for (double x = sx; x <= area.right(); x += major)
                for (double y = sy; y <= area.bottom(); y += major)
                    p.drawEllipse(QPointF(x, y), 1.3, 1.3);
        }
        break;
    }
    case BackgroundKind::Graph:
        // "Graph-in-graph": fine minor grid overlaid with a heavier major grid.
        lineSet(minor, pg.minorColor, 1.0, true, true);
        lineSet(major, pg.gridColor,  1.4, true, true);
        break;
    case BackgroundKind::Log: {
        // Semi-log: uniform vertical majors; horizontal lines at log10 stops,
        // one decade per major cell.
        lineSet(major, pg.gridColor, 1.2, true, false);
        if (visible(major)) {
            QPen minorPen(pg.minorColor);
            minorPen.setCosmetic(true);
            minorPen.setWidthF(1.0);
            QPen majorPen(pg.gridColor);
            majorPen.setCosmetic(true);
            majorPen.setWidthF(1.2);
            const double startDecade = std::floor(area.top() / major) * major;
            for (double base = startDecade; base <= area.bottom() + major; base += major) {
                for (int k = 1; k <= 10; ++k) {
                    const double y = base + major * std::log10(static_cast<double>(k));
                    if (y < area.top() || y > area.bottom())
                        continue;
                    p.setPen((k == 1 || k == 10) ? majorPen : minorPen);
                    p.drawLine(QPointF(area.left(), y), QPointF(area.right(), y));
                }
            }
        }
        break;
    }
    case BackgroundKind::Isometric: {
        if (visible(major)) {
            QPen pen(pg.gridColor);
            pen.setCosmetic(true);
            pen.setWidthF(1.0);
            p.setPen(pen);
            // Vertical rulers.
            const double sx = std::floor(area.left() / major) * major;
            for (double x = sx; x <= area.right(); x += major)
                p.drawLine(QPointF(x, area.top()), QPointF(x, area.bottom()));
            // +/-30 degree diagonals.
            const double slope = std::tan(30.0 * kPi / 180.0);
            const double dy = major;
            const double span = std::abs(slope) *
                    (std::abs(area.left()) + std::abs(area.right())) + area.height();
            const double cLo = std::floor((area.top() - span) / dy) * dy;
            const double cHi = area.bottom() + span;
            for (double c = cLo; c <= cHi; c += dy) {
                p.drawLine(QPointF(area.left(),  slope * area.left()  + c),
                           QPointF(area.right(), slope * area.right() + c));
                p.drawLine(QPointF(area.left(), -slope * area.left()  + c),
                           QPointF(area.right(),-slope * area.right() + c));
            }
        }
        break;
    }
    case BackgroundKind::Music: {
        // Repeating staves of 5 lines with a gap of 3 line-spaces between staves.
        const double lineGap = major / 4.0;                 // 4 gaps -> 5 lines
        if (visible(lineGap)) {
            QPen pen(pg.gridColor);
            pen.setCosmetic(true);
            pen.setWidthF(1.0);
            p.setPen(pen);
            const double staffHeight = lineGap * 4.0;
            const double staffPeriod = staffHeight + lineGap * 3.0;
            const double firstStaff = std::floor(area.top() / staffPeriod) * staffPeriod;
            for (double top = firstStaff; top <= area.bottom(); top += staffPeriod) {
                for (int i = 0; i < 5; ++i) {
                    const double y = top + i * lineGap;
                    if (y >= area.top() && y <= area.bottom())
                        p.drawLine(QPointF(area.left(), y), QPointF(area.right(), y));
                }
            }
        }
        break;
    }
    }

    // Axes overlay (scene x = 0 and y = 0), drawn on top of the pattern.
    if (pg.showAxes) {
        QPen axisPen(pg.axisColor);
        axisPen.setCosmetic(true);
        axisPen.setWidthF(1.8);
        p.setPen(axisPen);
        if (0.0 >= area.top() && 0.0 <= area.bottom())
            p.drawLine(QPointF(area.left(), 0.0), QPointF(area.right(), 0.0));
        if (0.0 >= area.left() && 0.0 <= area.right())
            p.drawLine(QPointF(0.0, area.top()), QPointF(0.0, area.bottom()));
    }
}

void Canvas::drawSelection(QPainter &p)
{
    if (m_selection.empty())
        return;
    QPen pen(QColor(60, 120, 220));
    pen.setCosmetic(true);
    pen.setStyle(Qt::DashLine);
    pen.setWidth(1);
    p.setPen(pen);
    p.setBrush(Qt::NoBrush);
    for (Item *it : m_selection)
        p.drawRect(it->boundingRect());
}

void Canvas::drawBrushPreview(QPainter &p)
{
    if (!m_hoverValid || m_panning)
        return;

    if (m_settings.tool == ToolId::Eraser) {
        const double r = m_settings.eraserRadius * m_scale;
        QPen pen(QColor(70, 70, 70));
        pen.setStyle(Qt::DashLine);
        p.setPen(pen);
        p.setBrush(Qt::NoBrush);
        p.drawEllipse(m_cursorWidget, r, r);
        return;
    }

    QColor col;
    double w = 0.0;
    bool laser = false;
    switch (m_settings.tool) {
    case ToolId::Pen:         col = m_settings.penColor;   w = m_settings.penWidth;   break;
    case ToolId::Highlighter: col = m_settings.hlColor;    w = m_settings.hlWidth;    break;
    case ToolId::Line:
    case ToolId::Rectangle:
    case ToolId::Ellipse:     col = m_settings.shapeColor; w = m_settings.shapeWidth; break;
    case ToolId::Laser:       col = m_settings.laser.coreColor; w = m_settings.laser.width; laser = true; break;
    default: return;
    }

    const double r = qMax(1.5, w * 0.5 * m_scale);

    p.save();
    p.setRenderHint(QPainter::Antialiasing, true);

    if (laser && m_settings.laser.glowEnabled) {
        const double gr = r + m_settings.laser.glowRadius * m_scale;
        QRadialGradient g(m_cursorWidget, gr);
        QColor g0 = m_settings.laser.glowColor; g0.setAlphaF(0.55 * m_settings.laser.intensity);
        QColor g1 = m_settings.laser.glowColor; g1.setAlphaF(0.0);
        g.setColorAt(0.0, g0);
        g.setColorAt(1.0, g1);
        p.setPen(Qt::NoPen);
        p.setBrush(g);
        p.drawEllipse(m_cursorWidget, gr, gr);
    }

    QColor fill = col;
    fill.setAlphaF(laser ? m_settings.laser.intensity : 0.9);
    const QColor outline = (col.lightness() > 128) ? QColor(0, 0, 0, 170)
                                                   : QColor(255, 255, 255, 190);
    QPen pen(outline);
    pen.setWidthF(1.0);
    p.setPen(pen);
    p.setBrush(fill);
    p.drawEllipse(m_cursorWidget, r, r);
    p.restore();
}

void Canvas::paintEvent(QPaintEvent *)
{
    QPainter p(this);
    p.fillRect(rect(), QColor(90, 93, 99));
    if (!m_doc)
        return;

    p.save();
    p.translate(m_translate);
    p.scale(m_scale, m_scale);

    Page &pg = m_doc->current();

    if (pg.infinite) {
        const QRectF sceneRect =
            QRectF(widgetToScene(QPointF(0, 0)),
                   widgetToScene(QPointF(width(), height()))).normalized();
        p.fillRect(sceneRect, pg.bgColor);
        drawBackground(p, pg, sceneRect);
    } else {
        const QRectF sheet(0.0, 0.0,
                           qMax(1.0, pg.pageWidth), qMax(1.0, pg.pageHeight));
        p.save();
        p.setRenderHint(QPainter::Antialiasing, true);
        p.setPen(Qt::NoPen);
        p.setBrush(QColor(0, 0, 0, 55));
        p.drawRoundedRect(sheet.translated(6.0, 7.0), 2.0, 2.0);
        p.restore();
        p.fillRect(sheet, pg.bgColor);
        p.save();
        p.setClipRect(sheet);
        drawBackground(p, pg, sheet);
        p.restore();
        p.save();
        QPen border(QColor(0, 0, 0, 45));
        border.setCosmetic(true);
        border.setWidth(1);
        p.setPen(border);
        p.setBrush(Qt::NoBrush);
        p.drawRect(sheet);
        p.restore();
    }

    p.setRenderHint(QPainter::Antialiasing, true);
    p.setRenderHint(QPainter::TextAntialiasing, true);

    const double vanishFade = m_fading
        ? fadeAlphaFor(m_fadeClock.elapsed(),
                       qMax(0, m_settings.laser.vanishDelayMs),
                       qMax(1, m_settings.laser.fadeDurationMs))
        : 1.0;

    for (const auto &ly : pg.layers) {
        if (!ly.visible)
            continue;
        const double layerOpacity = ly.opacity < 1.0 ? ly.opacity : 1.0;
        for (const auto &it : ly.items) {
            double o = layerOpacity;
            if (vanishFade < 1.0 && it->type() == ItemType::Stroke &&
                static_cast<const StrokeItem *>(it.get())->ephemeral)
                o *= vanishFade;
            p.save();
            p.setOpacity(o);
            it->paint(p);
            p.restore();
        }
    }

    if (m_activeStroke) m_activeStroke->paint(p);
    if (m_activeShape)  m_activeShape->paint(p);

    drawSelection(p);

    if (m_rubber) {
        QPen pen(QColor(60, 120, 220));
        pen.setCosmetic(true);
        pen.setStyle(Qt::DashLine);
        p.setPen(pen);
        p.setBrush(QColor(60, 120, 220, 40));
        p.drawRect(m_rubberRect);
    }

    p.restore();

    drawBrushPreview(p);
}

// ---- input -----------------------------------------------------------------
void Canvas::mousePressEvent(QMouseEvent *e)
{
    m_cursorWidget = e->position();
    m_hoverValid = true;

    // Right-click: per-page canvas presets (size + background engine).
    if (e->button() == Qt::RightButton && m_doc) {
        QMenu menu(this);

        // ---- Page size ----
        QMenu *sizeMenu = menu.addMenu(tr("Page Size"));
        auto addSize = [&](const QString &label, bool inf, double w, double h) {
            QAction *a = sizeMenu->addAction(label);
            a->setCheckable(true);
            Page &pg = m_doc->current();
            a->setChecked(inf
                ? pg.infinite
                : (!pg.infinite && qAbs(pg.pageWidth - w) < 0.5 &&
                   qAbs(pg.pageHeight - h) < 0.5));
            connect(a, &QAction::triggered, this, [this, inf, w, h]() {
                Page &p = m_doc->current();
                p.infinite = inf;
                if (!inf) { p.pageWidth = w; p.pageHeight = h; }
                m_doc->markChanged();
                zoomToFit();
                update();
            });
        };
        addSize(tr("Infinite Canvas"), true, 0.0, 0.0);
        sizeMenu->addSeparator();
        addSize(tr("A4 — Portrait"),      false, 794.0,  1123.0);
        addSize(tr("A4 — Landscape"),     false, 1123.0, 794.0);
        addSize(tr("A5 — Portrait"),      false, 559.0,  794.0);
        addSize(tr("A5 — Landscape"),     false, 794.0,  559.0);
        addSize(tr("Letter — Portrait"),  false, 816.0,  1056.0);
        addSize(tr("Letter — Landscape"), false, 1056.0, 816.0);
        addSize(tr("Legal — Portrait"),   false, 816.0,  1344.0);
        addSize(tr("Legal — Landscape"),  false, 1344.0, 816.0);
        sizeMenu->addSeparator();
        {
            QAction *custom = sizeMenu->addAction(tr("Custom…"));
            connect(custom, &QAction::triggered, this, [this]() {
                Page &pg = m_doc->current();
                bool ok1 = false, ok2 = false;
                const int w = QInputDialog::getInt(
                    this, tr("Custom Page Size"), tr("Width (px):"),
                    qRound(pg.infinite ? 794.0 : pg.pageWidth), 50, 20000, 10, &ok1);
                if (!ok1) return;
                const int h = QInputDialog::getInt(
                    this, tr("Custom Page Size"), tr("Height (px):"),
                    qRound(pg.infinite ? 1123.0 : pg.pageHeight), 50, 20000, 10, &ok2);
                if (!ok2) return;
                pg.infinite   = false;
                pg.pageWidth  = static_cast<double>(w);
                pg.pageHeight = static_cast<double>(h);
                m_doc->markChanged();
                zoomToFit();
                update();
            });
        }

        // ---- Background preset ----
        QMenu *bgMenu = menu.addMenu(tr("Background"));
        auto addBg = [&](const QString &label, BackgroundKind k) {
            QAction *a = bgMenu->addAction(label);
            a->setCheckable(true);
            a->setChecked(m_doc->current().background == k);
            connect(a, &QAction::triggered, this, [this, k]() {
                m_doc->current().background = k;
                m_doc->markChanged();
                update();
            });
        };
        addBg(tr("Blank"),               BackgroundKind::Blank);
        addBg(tr("Grid"),                BackgroundKind::Grid);
        addBg(tr("Graph (major + minor)"), BackgroundKind::Graph);
        addBg(tr("Lines"),               BackgroundKind::Lines);
        addBg(tr("Dots"),                BackgroundKind::Dots);
        addBg(tr("Isometric"),           BackgroundKind::Isometric);
        addBg(tr("Music staves"),        BackgroundKind::Music);
        addBg(tr("Logarithmic"),         BackgroundKind::Log);

        {
            QAction *axes = menu.addAction(tr("Show Axes"));
            axes->setCheckable(true);
            axes->setChecked(m_doc->current().showAxes);
            connect(axes, &QAction::triggered, this, [this](bool on) {
                m_doc->current().showAxes = on;
                m_doc->markChanged();
                update();
            });
        }

        menu.addSeparator();

        // ---- Spacing & divisions ----
        {
            QAction *a = menu.addAction(tr("Grid Spacing…"));
            connect(a, &QAction::triggered, this, [this]() {
                Page &pg = m_doc->current();
                bool ok = false;
                const int s = QInputDialog::getInt(
                    this, tr("Grid Spacing"), tr("Major spacing (px):"),
                    qRound(pg.gridSpacing), 4, 400, 1, &ok);
                if (ok) { pg.gridSpacing = static_cast<double>(s); m_doc->markChanged(); update(); }
            });
        }
        {
            QAction *a = menu.addAction(tr("Minor Divisions…"));
            connect(a, &QAction::triggered, this, [this]() {
                Page &pg = m_doc->current();
                bool ok = false;
                const int n = QInputDialog::getInt(
                    this, tr("Minor Divisions"), tr("Minor cells per major cell:"),
                    qMax(1, pg.minorDivisions), 1, 20, 1, &ok);
                if (ok) { pg.minorDivisions = n; m_doc->markChanged(); update(); }
            });
        }

        menu.addSeparator();

        // ---- Per-page colors ----
        {
            QAction *a = menu.addAction(tr("Paper Color…"));
            connect(a, &QAction::triggered, this, [this]() {
                Page &pg = m_doc->current();
                const QColor c = QColorDialog::getColor(pg.bgColor, this, tr("Paper Color"));
                if (c.isValid()) { pg.bgColor = c; m_doc->markChanged(); update(); }
            });
        }
        {
            QAction *a = menu.addAction(tr("Major Grid Color…"));
            connect(a, &QAction::triggered, this, [this]() {
                Page &pg = m_doc->current();
                const QColor c = QColorDialog::getColor(pg.gridColor, this, tr("Major Grid Color"));
                if (c.isValid()) { pg.gridColor = c; m_doc->markChanged(); update(); }
            });
        }
        {
            QAction *a = menu.addAction(tr("Minor Grid Color…"));
            connect(a, &QAction::triggered, this, [this]() {
                Page &pg = m_doc->current();
                const QColor c = QColorDialog::getColor(pg.minorColor, this, tr("Minor Grid Color"));
                if (c.isValid()) { pg.minorColor = c; m_doc->markChanged(); update(); }
            });
        }
        {
            QAction *a = menu.addAction(tr("Axis Color…"));
            connect(a, &QAction::triggered, this, [this]() {
                Page &pg = m_doc->current();
                const QColor c = QColorDialog::getColor(pg.axisColor, this, tr("Axis Color"));
                if (c.isValid()) { pg.axisColor = c; m_doc->markChanged(); update(); }
            });
        }

        menu.exec(e->globalPosition().toPoint());
        return;
    }

    if (e->button() == Qt::MiddleButton ||
        (m_spaceDown && e->button() == Qt::LeftButton)) {
        m_panning = true;
        m_lastPanPos = e->position().toPoint();
        setCursor(Qt::ClosedHandCursor);
        return;
    }
    if (e->button() == Qt::LeftButton)
        handlePointer(Action::Press, e->position(), 1.0, e->modifiers(), false);
}

void Canvas::mouseMoveEvent(QMouseEvent *e)
{
    m_cursorWidget = e->position();
    m_hoverValid = true;
    if (m_panning) {
        const QPoint d = e->position().toPoint() - m_lastPanPos;
        m_lastPanPos = e->position().toPoint();
        m_translate += QPointF(d);
        update();
        emit viewChanged();
        return;
    }
    handlePointer(Action::Move, e->position(), 1.0, e->modifiers(), false);
    update();
    emit cursorMoved(widgetToScene(e->position()));
}

void Canvas::mouseReleaseEvent(QMouseEvent *e)
{
    m_cursorWidget = e->position();
    if (m_panning &&
        (e->button() == Qt::MiddleButton || e->button() == Qt::LeftButton)) {
        m_panning = false;
        updateCursor();
        return;
    }
    if (e->button() == Qt::LeftButton)
        handlePointer(Action::Release, e->position(), 1.0, e->modifiers(), false);
}

void Canvas::tabletEvent(QTabletEvent *e)
{
    const bool eraserTip =
        e->pointerType() == QPointingDevice::PointerType::Eraser;
    double pr = e->pressure();
    if (pr <= 0.0)
        pr = 1.0;
    m_cursorWidget = e->position();
    m_hoverValid = true;

    switch (e->type()) {
    case QEvent::TabletPress:
        handlePointer(Action::Press, e->position(), pr, e->modifiers(), eraserTip);
        break;
    case QEvent::TabletMove:
        handlePointer(Action::Move, e->position(), pr, e->modifiers(), eraserTip);
        emit cursorMoved(widgetToScene(e->position()));
        update();
        break;
    case QEvent::TabletRelease:
        handlePointer(Action::Release, e->position(), pr, e->modifiers(), eraserTip);
        break;
    default:
        break;
    }
    e->accept();
}

void Canvas::wheelEvent(QWheelEvent *e)
{
    const double factor = std::pow(1.0015, e->angleDelta().y());
    zoomAround(e->position(), factor);
    e->accept();
}

void Canvas::keyPressEvent(QKeyEvent *e)
{
    if (e->key() == Qt::Key_Space) {
        m_spaceDown = true;
        setCursor(Qt::OpenHandCursor);
        e->accept();
        return;
    }
    if (e->key() == Qt::Key_Delete || e->key() == Qt::Key_Backspace) {
        deleteSelection();
        e->accept();
        return;
    }
    if (e->key() == Qt::Key_Escape) {
        cancelActive();
        clearSelection();
        clearLaser();
        e->accept();
        return;
    }
    QWidget::keyPressEvent(e);
}

void Canvas::keyReleaseEvent(QKeyEvent *e)
{
    if (e->key() == Qt::Key_Space) {
        m_spaceDown = false;
        updateCursor();
        e->accept();
        return;
    }
    QWidget::keyReleaseEvent(e);
}

void Canvas::leaveEvent(QEvent *e)
{
    m_hoverValid = false;
    update();
    QWidget::leaveEvent(e);
}

// ---- pointer dispatch ------------------------------------------------------
void Canvas::handlePointer(Action a, const QPointF &widgetPos, double pressure,
                           Qt::KeyboardModifiers mods, bool eraserTip)
{
    if (!m_doc)
        return;
    const QPointF sp = widgetToScene(widgetPos);
    m_cursorWidget = widgetPos;

    const ToolId t = eraserTip ? ToolId::Eraser : m_settings.tool;

    if (t == ToolId::Laser) {
        Layer &lly = m_doc->current().active();
        if (lly.locked)
            return;
        if (a == Action::Press) {
            stopVanish();
            m_drawing = true;
            m_activeStroke = std::make_unique<StrokeItem>();
            m_activeStroke->highlighter   = false;
            m_activeStroke->pressureWidth = false;
            m_activeStroke->color         = m_settings.laser.coreColor;
            m_activeStroke->baseWidth     = m_settings.laser.width;
            m_activeStroke->opacity       = qBound(0.0, m_settings.laser.intensity, 1.0);
            m_activeStroke->glow          = m_settings.laser.glowEnabled;
            m_activeStroke->glowColor     = m_settings.laser.glowColor;
            m_activeStroke->glowRadius    = m_settings.laser.glowRadius;
            m_activeStroke->ephemeral     = m_settings.laser.vanishMode;
            m_activeStroke->addPoint(StrokePoint(sp.x(), sp.y(), pressure));
            update();
        } else if (a == Action::Move && m_drawing && m_activeStroke) {
            m_activeStroke->addPoint(StrokePoint(sp.x(), sp.y(), pressure));
            update();
        } else if (a == Action::Release && m_drawing) {
            if (m_activeStroke && !m_activeStroke->isEmpty())
                commitAdd(std::move(m_activeStroke), QStringLiteral("Laser"));
            m_activeStroke.reset();
            m_drawing = false;
            update();
        }
        return;
    }

    Layer &ly = m_doc->current().active();
    if (ly.locked)
        return;

    switch (t) {
    case ToolId::Pen:
    case ToolId::Highlighter: {
        const bool hl = (t == ToolId::Highlighter);
        if (a == Action::Press) {
            m_drawing = true;
            m_activeStroke = std::make_unique<StrokeItem>();
            m_activeStroke->highlighter   = hl;
            m_activeStroke->color         = hl ? m_settings.hlColor : m_settings.penColor;
            m_activeStroke->baseWidth     = hl ? m_settings.hlWidth : m_settings.penWidth;
            m_activeStroke->opacity       = hl ? m_settings.hlOpacity : 1.0;
            m_activeStroke->pressureWidth = hl ? false : m_settings.penPressure;
            m_activeStroke->addPoint(StrokePoint(sp.x(), sp.y(), pressure));
            update();
        } else if (a == Action::Move && m_drawing && m_activeStroke) {
            m_activeStroke->addPoint(StrokePoint(sp.x(), sp.y(), pressure));
            update();
        } else if (a == Action::Release && m_drawing) {
            if (m_activeStroke && !m_activeStroke->isEmpty())
                commitAdd(std::move(m_activeStroke),
                          hl ? QStringLiteral("Highlight") : QStringLiteral("Draw"));
            m_activeStroke.reset();
            m_drawing = false;
            update();
        }
        break;
    }
    case ToolId::Eraser: {
        if (a == Action::Press) { m_erasing = true; m_eraseStash.clear(); eraseAt(sp); update(); }
        else if (a == Action::Move && m_erasing) { eraseAt(sp); update(); }
        else if (a == Action::Release && m_erasing) { finishErase(); m_erasing = false; update(); }
        break;
    }
    case ToolId::Line:
    case ToolId::Rectangle:
    case ToolId::Ellipse: {
        if (a == Action::Press) {
            m_activeShape = std::make_unique<ShapeItem>();
            m_activeShape->kind = (t == ToolId::Line) ? ShapeKind::Line
                                : (t == ToolId::Rectangle) ? ShapeKind::Rectangle
                                : ShapeKind::Ellipse;
            m_activeShape->color  = m_settings.shapeColor;
            m_activeShape->width  = m_settings.shapeWidth;
            m_activeShape->filled = m_settings.shapeFilled;
            m_activeShape->fill   = m_settings.shapeFill;
            m_activeShape->p1 = sp;
            m_activeShape->p2 = sp;
            m_drawing = true;
            update();
        } else if (a == Action::Move && m_drawing && m_activeShape) {
            m_activeShape->p2 = (mods & Qt::ShiftModifier)
                ? constrainShape(m_activeShape->p1, sp, m_activeShape->kind)
                : sp;
            update();
        } else if (a == Action::Release && m_drawing) {
            if (m_activeShape) {
                const QLineF diag(m_activeShape->p1, m_activeShape->p2);
                if (diag.length() >= 2.0)
                    commitAdd(std::move(m_activeShape), QStringLiteral("Shape"));
            }
            m_activeShape.reset();
            m_drawing = false;
            update();
        }
        break;
    }
    case ToolId::Text: {
        if (a == Action::Press)
            addTextAt(sp);
        break;
    }
    case ToolId::Select: {
        handleSelect(a, sp, mods);
        break;
    }
    case ToolId::Laser:
        break;
    }
}

// ---- selection -------------------------------------------------------------
void Canvas::handleSelect(Action a, const QPointF &sp, Qt::KeyboardModifiers mods)
{
    if (a == Action::Press) {
        Item *hit = topItemAt(sp);
        if (hit) {
            const bool already =
                std::find(m_selection.begin(), m_selection.end(), hit) != m_selection.end();
            if (mods & Qt::ShiftModifier) {
                if (already) removeFromSelection(hit);
                else addToSelection(hit);
            } else if (!already) {
                setSelectionSingle(hit);
            }
            m_movingSelection = true;
            m_moveStartScene = sp;
            m_moveAccum = QPointF(0, 0);
        } else {
            if (!(mods & Qt::ShiftModifier))
                clearSelection();
            m_rubber = true;
            m_rubberStartScene = sp;
            m_rubberRect = QRectF(sp, sp);
        }
        update();
    } else if (a == Action::Move) {
        if (m_movingSelection && !m_selection.empty()) {
            const QPointF d = sp - m_moveStartScene;
            const QPointF step = d - m_moveAccum;
            for (Item *it : m_selection)
                it->translate(step);
            m_moveAccum = d;
            update();
        } else if (m_rubber) {
            m_rubberRect = QRectF(m_rubberStartScene, sp).normalized();
            update();
        }
    } else if (a == Action::Release) {
        if (m_movingSelection) {
            m_movingSelection = false;
            if (!m_selection.empty() &&
                (std::abs(m_moveAccum.x()) > 0.01 || std::abs(m_moveAccum.y()) > 0.01)) {
                for (Item *it : m_selection)
                    it->translate(-m_moveAccum);
                m_doc->undoStack()->push(new TranslateItemsCommand(
                    m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
                    m_selection, m_moveAccum, QStringLiteral("Move")));
            }
            m_moveAccum = QPointF(0, 0);
        } else if (m_rubber) {
            selectInRect(m_rubberRect, (QApplication::keyboardModifiers() & Qt::ShiftModifier));
            m_rubber = false;
            update();
        }
    }
}

void Canvas::selectInRect(const QRectF &r, bool add)
{
    if (!m_doc)
        return;
    if (!add)
        m_selection.clear();
    Layer &ly = m_doc->current().active();
    for (auto &it : ly.items) {
        if (r.contains(it->boundingRect()) || r.intersects(it->boundingRect())) {
            it->selected = true;
            if (std::find(m_selection.begin(), m_selection.end(), it.get()) == m_selection.end())
                m_selection.push_back(it.get());
        }
    }
    update();
}

void Canvas::setSelectionSingle(Item *it)
{
    clearSelection();
    if (it) {
        it->selected = true;
        m_selection.push_back(it);
    }
}

void Canvas::addToSelection(Item *it)
{
    if (!it)
        return;
    if (std::find(m_selection.begin(), m_selection.end(), it) == m_selection.end()) {
        it->selected = true;
        m_selection.push_back(it);
    }
}

void Canvas::removeFromSelection(Item *it)
{
    auto pos = std::find(m_selection.begin(), m_selection.end(), it);
    if (pos != m_selection.end()) {
        (*pos)->selected = false;
        m_selection.erase(pos);
    }
}

bool Canvas::hitTest(Item *it, const QPointF &sp, double radius) const
{
    if (!it)
        return false;
    const QRectF bb = it->boundingRect().adjusted(-radius, -radius, radius, radius);
    if (!bb.contains(sp))
        return false;

    if (it->type() == ItemType::Stroke) {
        const auto *s = static_cast<const StrokeItem *>(it);
        if (s->points.size() == 1)
            return std::hypot(sp.x() - s->points.first().x,
                              sp.y() - s->points.first().y) <= radius + s->baseWidth;
        for (int i = 1; i < s->points.size(); ++i) {
            if (distToSegment(sp, s->points[i - 1].pos(), s->points[i].pos())
                    <= radius + s->baseWidth * 0.5)
                return true;
        }
        return false;
    }
    return true;
}

Item *Canvas::topItemAt(const QPointF &sp)
{
    if (!m_doc)
        return nullptr;
    Layer &ly = m_doc->current().active();
    const double radius = 6.0 / m_scale;
    for (auto it = ly.items.rbegin(); it != ly.items.rend(); ++it) {
        if (hitTest(it->get(), sp, radius))
            return it->get();
    }
    return nullptr;
}

// ---- mutations -------------------------------------------------------------
void Canvas::commitAdd(ItemPtr item, const QString &text)
{
    if (!m_doc || !item)
        return;
    m_doc->undoStack()->push(new AddItemCommand(
        m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
        std::move(item), text));
}

void Canvas::eraseAt(const QPointF &sp)
{
    if (!m_doc)
        return;
    Layer &ly = m_doc->current().active();
    const double radius = m_settings.eraserRadius;
    for (std::size_t i = 0; i < ly.items.size();) {
        if (hitTest(ly.items[i].get(), sp, radius)) {
            m_eraseStash.push_back({ i, std::move(ly.items[i]) });
            ly.items.erase(ly.items.begin() + static_cast<long>(i));
        } else {
            ++i;
        }
    }
}

void Canvas::finishErase()
{
    if (!m_doc || m_eraseStash.empty()) {
        m_eraseStash.clear();
        return;
    }
    Layer &ly = m_doc->current().active();
    std::sort(m_eraseStash.begin(), m_eraseStash.end(),
              [](const EraseStash &a, const EraseStash &b) { return a.index < b.index; });
    std::vector<Item *> targets;
    for (auto &st : m_eraseStash) {
        const std::size_t idx = std::min(st.index, ly.items.size());
        Item *raw = st.item.get();
        ly.items.insert(ly.items.begin() + static_cast<long>(idx), std::move(st.item));
        targets.push_back(raw);
    }
    m_eraseStash.clear();
    if (!targets.empty())
        m_doc->undoStack()->push(new RemoveItemsCommand(
            m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
            std::move(targets), QStringLiteral("Erase")));
}

void Canvas::addTextAt(const QPointF &sp)
{
    if (!m_doc)
        return;
    bool ok = false;
    const QString text = QInputDialog::getText(
        this, tr("Add Text"), tr("Text:"), QLineEdit::Normal, QString(), &ok);
    if (!ok || text.isEmpty())
        return;
    auto item = std::make_unique<TextItem>();
    item->pos   = sp;
    item->text  = text;
    item->color = m_settings.textColor;
    item->font  = m_settings.textFont;
    commitAdd(std::move(item), QStringLiteral("Text"));
}

void Canvas::cancelActive()
{
    m_activeStroke.reset();
    m_activeShape.reset();
    m_drawing = false;
    m_erasing = false;
    m_movingSelection = false;
    m_rubber = false;
    if (!m_eraseStash.empty() && m_doc) {
        Layer &ly = m_doc->current().active();
        std::sort(m_eraseStash.begin(), m_eraseStash.end(),
                  [](const EraseStash &a, const EraseStash &b) { return a.index < b.index; });
        for (auto &st : m_eraseStash) {
            const std::size_t idx = std::min(st.index, ly.items.size());
            ly.items.insert(ly.items.begin() + static_cast<long>(idx), std::move(st.item));
        }
    }
    m_eraseStash.clear();
}

void Canvas::deleteSelection()
{
    if (!m_doc || m_selection.empty())
        return;
    std::vector<Item *> targets = m_selection;
    m_doc->undoStack()->push(new RemoveItemsCommand(
        m_doc, m_doc->currentIndex(), m_doc->current().activeLayer,
        std::move(targets), QStringLiteral("Delete")));
    m_selection.clear();
    update();
}

void Canvas::selectAll()
{
    if (!m_doc)
        return;
    clearSelection();
    Layer &ly = m_doc->current().active();
    for (auto &it : ly.items) {
        it->selected = true;
        m_selection.push_back(it.get());
    }
    update();
}

void Canvas::clearSelection()
{
    for (Item *it : m_selection)
        it->selected = false;
    m_selection.clear();
    update();
}

void Canvas::updateCursor()
{
    switch (m_settings.tool) {
    case ToolId::Eraser:
        setCursor(Qt::BlankCursor);
        break;
    case ToolId::Text:
        setCursor(Qt::IBeamCursor);
        break;
    default:
        setCursor(Qt::ArrowCursor);
        break;
    }
}

} // namespace ib
EOF

log "PART 15 complete: granular background engine (graph/isometric/music/log presets, major+minor grid, per-page colors/spacing, axes) with right-click canvas controls"


# ---------------------------------------------------------------------------
#  PART 16 : High-fidelity export.
#            - Exporter background renderer now matches the full Part-15
#              engine (Graph/Isometric/Music/Log + minor grid + axes +
#              per-page colors), all vector & cosmetic-pen crisp.
#            - PDF is page-size aware: each page's PDF sheet takes that page's
#              own dimensions + orientation; finite pages render their exact
#              sheet, infinite pages fit content onto A4. Backgrounds included.
#            - PNG/SVG honor finite page sheets too.
#            Overwrites src/core/Exporter.cpp only (Exporter.h unchanged).
# ---------------------------------------------------------------------------
log "PART 16: page-size-aware, background-included vector export (PDF/PNG/SVG)"

cat > src/core/Exporter.cpp <<'EOF'
#include "core/Exporter.h"

#include "model/Document.h"
#include "model/Page.h"

#include <QPainter>
#include <QImage>
#include <QSize>
#include <QSizeF>
#include <QPen>
#include <QTransform>
#include <QSvgGenerator>
#include <QPdfWriter>
#include <QPageSize>
#include <cmath>

namespace ib {
namespace io {

static const double kPiExp = 3.14159265358979323846;

// Full background engine, mirroring Canvas' Part-15 renderer but keyed off the
// painter's device scale (there is no interactive zoom during export).
static void drawBackgroundPattern(QPainter &p, const Page &pg, const QRectF &area)
{
    if (pg.background == BackgroundKind::Blank && !pg.showAxes)
        return;

    const double devScale = std::sqrt(std::abs(p.worldTransform().determinant()));
    const auto visible = [devScale](double spacingScene) {
        return spacingScene * devScale >= 2.0;
    };

    const double major = qMax(4.0, pg.gridSpacing);
    const int divisions = qBound(1, pg.minorDivisions, 40);
    const double minor = major / divisions;

    const auto lineSet = [&](double spacing, const QColor &color, double penW,
                             bool vertical, bool horizontal) {
        if (!visible(spacing))
            return;
        QPen pen(color);
        pen.setCosmetic(true);
        pen.setWidthF(penW);
        p.setPen(pen);
        p.setBrush(Qt::NoBrush);
        if (vertical) {
            const double sx = std::floor(area.left() / spacing) * spacing;
            for (double x = sx; x <= area.right(); x += spacing)
                p.drawLine(QPointF(x, area.top()), QPointF(x, area.bottom()));
        }
        if (horizontal) {
            const double sy = std::floor(area.top() / spacing) * spacing;
            for (double y = sy; y <= area.bottom(); y += spacing)
                p.drawLine(QPointF(area.left(), y), QPointF(area.right(), y));
        }
    };

    switch (pg.background) {
    case BackgroundKind::Blank:
        break;
    case BackgroundKind::Grid:
        lineSet(major, pg.gridColor, 1.0, true, true);
        break;
    case BackgroundKind::Lines:
        lineSet(major, pg.gridColor, 1.0, false, true);
        break;
    case BackgroundKind::Dots: {
        if (visible(major)) {
            p.setPen(Qt::NoPen);
            p.setBrush(pg.gridColor);
            const double sx = std::floor(area.left() / major) * major;
            const double sy = std::floor(area.top() / major) * major;
            for (double x = sx; x <= area.right(); x += major)
                for (double y = sy; y <= area.bottom(); y += major)
                    p.drawEllipse(QPointF(x, y), 1.3, 1.3);
        }
        break;
    }
    case BackgroundKind::Graph:
        lineSet(minor, pg.minorColor, 1.0, true, true);
        lineSet(major, pg.gridColor,  1.4, true, true);
        break;
    case BackgroundKind::Log: {
        lineSet(major, pg.gridColor, 1.2, true, false);
        if (visible(major)) {
            QPen minorPen(pg.minorColor); minorPen.setCosmetic(true); minorPen.setWidthF(1.0);
            QPen majorPen(pg.gridColor);  majorPen.setCosmetic(true); majorPen.setWidthF(1.2);
            const double startDecade = std::floor(area.top() / major) * major;
            for (double base = startDecade; base <= area.bottom() + major; base += major) {
                for (int k = 1; k <= 10; ++k) {
                    const double y = base + major * std::log10(static_cast<double>(k));
                    if (y < area.top() || y > area.bottom())
                        continue;
                    p.setPen((k == 1 || k == 10) ? majorPen : minorPen);
                    p.drawLine(QPointF(area.left(), y), QPointF(area.right(), y));
                }
            }
        }
        break;
    }
    case BackgroundKind::Isometric: {
        if (visible(major)) {
            QPen pen(pg.gridColor); pen.setCosmetic(true); pen.setWidthF(1.0);
            p.setPen(pen);
            const double sx = std::floor(area.left() / major) * major;
            for (double x = sx; x <= area.right(); x += major)
                p.drawLine(QPointF(x, area.top()), QPointF(x, area.bottom()));
            const double slope = std::tan(30.0 * kPiExp / 180.0);
            const double dy = major;
            const double span = std::abs(slope) *
                    (std::abs(area.left()) + std::abs(area.right())) + area.height();
            const double cLo = std::floor((area.top() - span) / dy) * dy;
            const double cHi = area.bottom() + span;
            for (double c = cLo; c <= cHi; c += dy) {
                p.drawLine(QPointF(area.left(),  slope * area.left()  + c),
                           QPointF(area.right(), slope * area.right() + c));
                p.drawLine(QPointF(area.left(), -slope * area.left()  + c),
                           QPointF(area.right(),-slope * area.right() + c));
            }
        }
        break;
    }
    case BackgroundKind::Music: {
        const double lineGap = major / 4.0;
        if (visible(lineGap)) {
            QPen pen(pg.gridColor); pen.setCosmetic(true); pen.setWidthF(1.0);
            p.setPen(pen);
            const double staffHeight = lineGap * 4.0;
            const double staffPeriod = staffHeight + lineGap * 3.0;
            const double firstStaff = std::floor(area.top() / staffPeriod) * staffPeriod;
            for (double top = firstStaff; top <= area.bottom(); top += staffPeriod) {
                for (int i = 0; i < 5; ++i) {
                    const double y = top + i * lineGap;
                    if (y >= area.top() && y <= area.bottom())
                        p.drawLine(QPointF(area.left(), y), QPointF(area.right(), y));
                }
            }
        }
        break;
    }
    }

    if (pg.showAxes) {
        QPen axisPen(pg.axisColor); axisPen.setCosmetic(true); axisPen.setWidthF(1.8);
        p.setPen(axisPen);
        if (0.0 >= area.top() && 0.0 <= area.bottom())
            p.drawLine(QPointF(area.left(), 0.0), QPointF(area.right(), 0.0));
        if (0.0 >= area.left() && 0.0 <= area.right())
            p.drawLine(QPointF(0.0, area.top()), QPointF(0.0, area.bottom()));
    }
}

// Logical bounds to export for a page: the exact sheet when finite, otherwise
// the content bounds plus a margin.
static QRectF exportBounds(const Page &pg)
{
    if (!pg.infinite)
        return QRectF(0.0, 0.0, qMax(1.0, pg.pageWidth), qMax(1.0, pg.pageHeight));
    QRectF b = pg.contentBounds();
    if (b.isNull())
        b = QRectF(0, 0, 1280, 720);
    const double margin = 40.0;
    b.adjust(-margin, -margin, margin, margin);
    return b;
}

void renderPage(QPainter &p, const Page &pg, const QRectF &src,
                const QRectF &dst, bool drawBackground)
{
    p.save();
    p.setRenderHint(QPainter::Antialiasing, true);
    p.setRenderHint(QPainter::TextAntialiasing, true);
    p.setRenderHint(QPainter::SmoothPixmapTransform, true);

    p.setClipRect(dst);
    p.translate(dst.topLeft());
    const double sx = dst.width()  / (src.width()  <= 0 ? 1.0 : src.width());
    const double sy = dst.height() / (src.height() <= 0 ? 1.0 : src.height());
    p.scale(sx, sy);
    p.translate(-src.topLeft());

    if (drawBackground) {
        p.fillRect(src, pg.bgColor);
        drawBackgroundPattern(p, pg, src);
    }

    for (const auto &ly : pg.layers) {
        if (!ly.visible)
            continue;
        p.save();
        if (ly.opacity < 1.0)
            p.setOpacity(ly.opacity);
        for (const auto &it : ly.items)
            it->paint(p);
        p.restore();
    }

    p.restore();
}

bool exportPng(const Page &pg, const QString &path, double scale, QString *error)
{
    QRectF b = exportBounds(pg);

    scale = qBound(0.1, scale, 8.0);
    const QSize sz(qMax(1, static_cast<int>(b.width() * scale)),
                   qMax(1, static_cast<int>(b.height() * scale)));

    QImage img(sz, QImage::Format_ARGB32_Premultiplied);
    img.fill(Qt::transparent);
    {
        QPainter p(&img);
        renderPage(p, pg, b, QRectF(0, 0, sz.width(), sz.height()), true);
    }
    if (!img.save(path, "PNG")) {
        if (error) *error = QStringLiteral("Failed to write PNG file.");
        return false;
    }
    return true;
}

bool exportSvg(const Page &pg, const QString &path, QString *error)
{
    QRectF b = exportBounds(pg);

    QSvgGenerator gen;
    gen.setFileName(path);
    gen.setSize(QSize(static_cast<int>(b.width()), static_cast<int>(b.height())));
    gen.setViewBox(QRectF(0, 0, b.width(), b.height()));
    gen.setTitle(QStringLiteral("InkBoard Page"));
    gen.setDescription(QStringLiteral("Exported by InkBoard"));

    {
        QPainter p(&gen);
        if (!p.isActive()) {
            if (error) *error = QStringLiteral("Failed to create SVG file.");
            return false;
        }
        renderPage(p, pg, b, QRectF(0, 0, b.width(), b.height()), true);
    }
    return true;
}

bool exportPdf(const Document &doc, const QString &path, QString *error)
{
    if (doc.pageCount() <= 0) {
        if (error) *error = QStringLiteral("Nothing to export.");
        return false;
    }

    QPdfWriter writer(path);
    writer.setResolution(150);

    // Per-page PDF sheet size + logical source rect.
    const auto layoutFor = [](const Page &pg, QPageSize &size, QRectF &src) {
        if (!pg.infinite) {
            const double wpt = qMax(1.0, pg.pageWidth)  * 0.75; // 96 DPI px -> points
            const double hpt = qMax(1.0, pg.pageHeight) * 0.75;
            size = QPageSize(QSizeF(wpt, hpt), QPageSize::Point,
                             QStringLiteral("InkBoardPage"), QPageSize::ExactMatch);
            src  = QRectF(0.0, 0.0, qMax(1.0, pg.pageWidth), qMax(1.0, pg.pageHeight));
        } else {
            QRectF b = pg.contentBounds();
            if (b.isNull())
                b = QRectF(0, 0, 1280, 720);
            b.adjust(-40, -40, 40, 40);
            size = QPageSize(QPageSize::A4);
            src  = b;
        }
    };

    QPageSize firstSize;
    QRectF firstSrc;
    layoutFor(doc.page(0), firstSize, firstSrc);
    writer.setPageSize(firstSize);

    QPainter p(&writer);
    if (!p.isActive()) {
        if (error) *error = QStringLiteral("Failed to create PDF file.");
        return false;
    }

    for (int i = 0; i < doc.pageCount(); ++i) {
        QPageSize size;
        QRectF src;
        layoutFor(doc.page(i), size, src);
        if (i > 0) {
            writer.setPageSize(size);
            writer.newPage();
        }
        const QRectF dst(0, 0, writer.width(), writer.height());
        const double s = qMin(dst.width()  / (src.width()  <= 0 ? 1.0 : src.width()),
                              dst.height() / (src.height() <= 0 ? 1.0 : src.height()));
        QRectF fitted(0, 0, src.width() * s, src.height() * s);
        fitted.moveCenter(dst.center());
        renderPage(p, doc.page(i), src, fitted, true);
    }
    return true;
}

} // namespace io
} // namespace ib
EOF

log "PART 16 complete: vector export is now page-size aware with full backgrounds (PDF per-page sheet size/orientation, PNG/SVG honor finite sheets)"

# ---------------------------------------------------------------------------
#  PART 17 : Notebook -> Sections -> Pages (OneNote-style).
#            - Page gains a "section" label (persisted, backward compatible).
#            - New docked sidebar: sections list + pages list, with
#              add / rename / delete for sections, new-page / delete for pages,
#              live two-way sync with the current page, and per-page
#              orientation hints.
#            - Uses ONLY Document's existing API (addPage/removePage/
#              setCurrentIndex/page/current), so the undo stack, Canvas and
#              Commands are completely unchanged (pointer-stable, undo-safe).
#            - MainWindow + CMakeLists patched via anchored sed (no rewrite).
# ---------------------------------------------------------------------------
log "PART 17: notebook sections + pages sidebar (OneNote-style navigation & storage)"

# 1) Page gains a section label ------------------------------------------------
cat > src/model/Page.h <<'EOF'
#pragma once

#include <QColor>
#include <QRectF>
#include <QString>
#include <vector>

#include "model/Layer.h"
#include "model/Types.h"

namespace ib {

struct Page {
    BackgroundKind background   = BackgroundKind::Grid;
    QColor         bgColor      = QColor(255, 255, 255);
    QColor         gridColor    = QColor(223, 223, 223);   // major / primary grid
    double         gridSpacing  = 40.0;                     // major spacing (px)

    // Granular background engine.
    QColor         minorColor     = QColor(233, 236, 239);  // minor grid (graph/log)
    int            minorDivisions = 5;                       // minor cells per major cell
    bool           showAxes       = false;                   // draw x=0 / y=0 axes
    QColor         axisColor      = QColor(120, 120, 120);

    // Page geometry (Part 14).
    bool           infinite     = true;
    double         pageWidth    = 794.0;
    double         pageHeight   = 1123.0;

    // Notebook organization (Part 17): the section this page belongs to.
    QString        section      = QStringLiteral("Section 1");

    std::vector<Layer> layers;
    int            activeLayer  = 0;

    Page() { layers.emplace_back(); }

    Layer &active() {
        if (layers.empty()) layers.emplace_back();
        if (activeLayer < 0 || activeLayer >= static_cast<int>(layers.size()))
            activeLayer = 0;
        return layers[static_cast<std::size_t>(activeLayer)];
    }

    // Union of every visible item's bounding rect (empty if the page is blank).
    QRectF contentBounds() const {
        QRectF r;
        for (const auto &layer : layers) {
            if (!layer.visible) continue;
            for (const auto &it : layer.items)
                r = r.isNull() ? it->boundingRect() : r.united(it->boundingRect());
        }
        return r;
    }
};

} // namespace ib
EOF

# 2) Serializer persists the section label (additive, backward compatible) -----
cat > src/core/Serializer.cpp <<'EOF'
#include "core/Serializer.h"

#include "model/Document.h"
#include "model/Item.h"

#include <QFile>
#include <QSaveFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonParseError>
#include <QColor>

namespace ib {
namespace io {

static QJsonArray colorToJson(const QColor &c)
{
    QJsonArray a;
    a.append(c.red());
    a.append(c.green());
    a.append(c.blue());
    a.append(c.alpha());
    return a;
}

static QColor colorFromJson(const QJsonValue &v, const QColor &def)
{
    const QJsonArray a = v.toArray();
    if (a.size() < 3)
        return def;
    const int alpha = a.size() >= 4 ? a.at(3).toInt(255) : 255;
    return QColor(a.at(0).toInt(), a.at(1).toInt(), a.at(2).toInt(), alpha);
}

static ItemType typeFromString(const QString &s)
{
    if (s == QLatin1String("stroke")) return ItemType::Stroke;
    if (s == QLatin1String("shape"))  return ItemType::Shape;
    if (s == QLatin1String("text"))   return ItemType::Text;
    return ItemType::Image;
}

static QJsonObject pageToJson(const Page &pg)
{
    QJsonObject o;
    o["background"]     = static_cast<int>(pg.background);
    o["bgColor"]        = colorToJson(pg.bgColor);
    o["gridColor"]      = colorToJson(pg.gridColor);
    o["gridSpacing"]    = pg.gridSpacing;
    o["minorColor"]     = colorToJson(pg.minorColor);
    o["minorDivisions"] = pg.minorDivisions;
    o["showAxes"]       = pg.showAxes;
    o["axisColor"]      = colorToJson(pg.axisColor);
    o["infinite"]       = pg.infinite;
    o["pageWidth"]      = pg.pageWidth;
    o["pageHeight"]     = pg.pageHeight;
    o["section"]        = pg.section;
    o["activeLayer"]    = pg.activeLayer;

    QJsonArray layers;
    for (const auto &ly : pg.layers) {
        QJsonObject lo;
        lo["name"]    = ly.name;
        lo["visible"] = ly.visible;
        lo["locked"]  = ly.locked;
        lo["opacity"] = ly.opacity;

        QJsonArray items;
        for (const auto &it : ly.items) {
            QJsonObject io;
            it->write(io);
            items.append(io);
        }
        lo["items"] = items;
        layers.append(lo);
    }
    o["layers"] = layers;
    return o;
}

static Page pageFromJson(const QJsonObject &o)
{
    Page pg;
    pg.background   = static_cast<BackgroundKind>(
        o.value("background").toInt(static_cast<int>(BackgroundKind::Grid)));
    pg.bgColor      = colorFromJson(o.value("bgColor"), QColor(255, 255, 255));
    pg.gridColor    = colorFromJson(o.value("gridColor"), QColor(223, 223, 223));
    pg.gridSpacing  = o.value("gridSpacing").toDouble(40.0);

    pg.minorColor     = colorFromJson(o.value("minorColor"), QColor(233, 236, 239));
    pg.minorDivisions = o.value("minorDivisions").toInt(5);
    pg.showAxes       = o.value("showAxes").toBool(false);
    pg.axisColor      = colorFromJson(o.value("axisColor"), QColor(120, 120, 120));

    pg.infinite     = o.value("infinite").toBool(true);
    pg.pageWidth    = o.value("pageWidth").toDouble(794.0);
    pg.pageHeight   = o.value("pageHeight").toDouble(1123.0);
    pg.section      = o.value("section").toString(QStringLiteral("Section 1"));

    pg.layers.clear();
    const QJsonArray layers = o.value("layers").toArray();
    for (const auto &lv : layers) {
        const QJsonObject lo = lv.toObject();
        Layer ly;
        ly.name    = lo.value("name").toString(QStringLiteral("Layer"));
        ly.visible = lo.value("visible").toBool(true);
        ly.locked  = lo.value("locked").toBool(false);
        ly.opacity = lo.value("opacity").toDouble(1.0);

        const QJsonArray items = lo.value("items").toArray();
        for (const auto &iv : items) {
            const QJsonObject io = iv.toObject();
            ItemPtr item = makeItem(typeFromString(io.value("type").toString()));
            if (item) {
                item->read(io);
                ly.items.push_back(std::move(item));
            }
        }
        pg.layers.push_back(std::move(ly));
    }
    if (pg.layers.empty())
        pg.layers.emplace_back();

    pg.activeLayer = o.value("activeLayer").toInt(0);
    return pg;
}

QByteArray toBytes(const Document &doc)
{
    QJsonObject root;
    root["format"]  = "inkboard";
    root["version"] = 1;

    QJsonArray pages;
    for (int i = 0; i < doc.pageCount(); ++i)
        pages.append(pageToJson(doc.page(i)));
    root["pages"] = pages;

    return QJsonDocument(root).toJson(QJsonDocument::Indented);
}

bool fromBytes(std::vector<Page> &pagesOut, const QByteArray &bytes, QString *error)
{
    QJsonParseError pe;
    const QJsonDocument doc = QJsonDocument::fromJson(bytes, &pe);
    if (pe.error != QJsonParseError::NoError) {
        if (error) *error = pe.errorString();
        return false;
    }
    const QJsonObject root = doc.object();
    if (root.value("format").toString() != QLatin1String("inkboard")) {
        if (error) *error = QStringLiteral("Not an InkBoard (.iboard) file.");
        return false;
    }

    pagesOut.clear();
    const QJsonArray pages = root.value("pages").toArray();
    for (const auto &pv : pages)
        pagesOut.push_back(pageFromJson(pv.toObject()));
    if (pagesOut.empty())
        pagesOut.emplace_back();
    return true;
}

bool saveToFile(const Document &doc, const QString &path, QString *error)
{
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly)) {
        if (error) *error = file.errorString();
        return false;
    }
    const QByteArray bytes = toBytes(doc);
    if (file.write(bytes) != bytes.size()) {
        if (error) *error = file.errorString();
        return false;
    }
    if (!file.commit()) {
        if (error) *error = file.errorString();
        return false;
    }
    return true;
}

bool loadFromFile(Document &doc, const QString &path, QString *error)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        if (error) *error = file.errorString();
        return false;
    }
    const QByteArray bytes = file.readAll();
    std::vector<Page> pages;
    if (!fromBytes(pages, bytes, error))
        return false;

    doc.setPages(std::move(pages));
    doc.setFilePath(path);
    return true;
}

} // namespace io
} // namespace ib
EOF

# 3) New OneNote-style sidebar widget -----------------------------------------
cat > src/ui/NotebookPanel.h <<'EOF'
#pragma once

#include <QWidget>
#include <QString>
#include <QStringList>
#include <QList>

class QListWidget;

namespace ib {

class Document;

// OneNote-style navigation: a list of Sections (each grouping pages that share
// a "section" label) above a list of the selected section's Pages. Drives the
// document purely through its existing public API, so it never disturbs the
// undo stack or the canvas.
class NotebookPanel : public QWidget {
    Q_OBJECT
public:
    explicit NotebookPanel(Document *doc, QWidget *parent = nullptr);

private slots:
    void rebuild();
    void syncSelection();
    void onSectionRowChanged();
    void onPageRowChanged();
    void addSection();
    void renameSection();
    void deleteSection();
    void addPage();
    void deletePage();

private:
    QStringList sectionOrder() const;
    QList<int>  pagesInSection(const QString &name) const;
    QString     selectedSectionName() const;
    int         selectedPageIndex() const;
    void        refreshPageList();
    QString     uniqueSectionName(const QString &desired, const QString &except) const;
    void        selectSectionRow(const QString &name);

    Document    *m_doc = nullptr;
    QListWidget *m_sectionList = nullptr;
    QListWidget *m_pageList = nullptr;
    bool         m_updating = false;
};

} // namespace ib
EOF

cat > src/ui/NotebookPanel.cpp <<'EOF'
#include "ui/NotebookPanel.h"

#include "model/Document.h"
#include "model/Page.h"

#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QListWidget>
#include <QListWidgetItem>
#include <QPushButton>
#include <QLabel>
#include <QFont>
#include <QAbstractItemView>
#include <QInputDialog>
#include <QLineEdit>
#include <QMessageBox>

namespace ib {

NotebookPanel::NotebookPanel(Document *doc, QWidget *parent)
    : QWidget(parent), m_doc(doc)
{
    setMinimumWidth(200);

    auto *root = new QVBoxLayout(this);
    root->setContentsMargins(6, 6, 6, 6);
    root->setSpacing(6);

    auto *secHeader = new QLabel(tr("Sections"), this);
    { QFont f = secHeader->font(); f.setBold(true); secHeader->setFont(f); }
    root->addWidget(secHeader);

    m_sectionList = new QListWidget(this);
    m_sectionList->setSelectionMode(QAbstractItemView::SingleSelection);
    root->addWidget(m_sectionList, 1);

    auto *secBtns = new QHBoxLayout();
    auto *secAdd = new QPushButton(tr("Add"), this);
    auto *secRen = new QPushButton(tr("Rename"), this);
    auto *secDel = new QPushButton(tr("Delete"), this);
    secBtns->addWidget(secAdd);
    secBtns->addWidget(secRen);
    secBtns->addWidget(secDel);
    root->addLayout(secBtns);

    auto *pageHeader = new QLabel(tr("Pages"), this);
    { QFont f = pageHeader->font(); f.setBold(true); pageHeader->setFont(f); }
    root->addWidget(pageHeader);

    m_pageList = new QListWidget(this);
    m_pageList->setSelectionMode(QAbstractItemView::SingleSelection);
    root->addWidget(m_pageList, 2);

    auto *pageBtns = new QHBoxLayout();
    auto *pageAdd = new QPushButton(tr("New Page"), this);
    auto *pageDel = new QPushButton(tr("Delete"), this);
    pageBtns->addWidget(pageAdd);
    pageBtns->addWidget(pageDel);
    root->addLayout(pageBtns);

    connect(secAdd,  &QPushButton::clicked, this, &NotebookPanel::addSection);
    connect(secRen,  &QPushButton::clicked, this, &NotebookPanel::renameSection);
    connect(secDel,  &QPushButton::clicked, this, &NotebookPanel::deleteSection);
    connect(pageAdd, &QPushButton::clicked, this, &NotebookPanel::addPage);
    connect(pageDel, &QPushButton::clicked, this, &NotebookPanel::deletePage);

    connect(m_sectionList, &QListWidget::currentRowChanged,
            this, &NotebookPanel::onSectionRowChanged);
    connect(m_pageList, &QListWidget::currentRowChanged,
            this, &NotebookPanel::onPageRowChanged);

    if (m_doc) {
        connect(m_doc, &Document::pagesChanged, this, &NotebookPanel::rebuild);
        connect(m_doc, &Document::currentPageChanged, this, &NotebookPanel::syncSelection);
    }

    rebuild();
}

QStringList NotebookPanel::sectionOrder() const
{
    QStringList out;
    if (!m_doc) return out;
    for (int i = 0; i < m_doc->pageCount(); ++i) {
        const QString s = m_doc->page(i).section;
        if (!out.contains(s))
            out.append(s);
    }
    if (out.isEmpty())
        out.append(QStringLiteral("Section 1"));
    return out;
}

QList<int> NotebookPanel::pagesInSection(const QString &name) const
{
    QList<int> out;
    if (!m_doc) return out;
    for (int i = 0; i < m_doc->pageCount(); ++i)
        if (m_doc->page(i).section == name)
            out.append(i);
    return out;
}

QString NotebookPanel::selectedSectionName() const
{
    QListWidgetItem *it = m_sectionList->currentItem();
    return it ? it->text() : QString();
}

int NotebookPanel::selectedPageIndex() const
{
    QListWidgetItem *it = m_pageList->currentItem();
    return it ? it->data(Qt::UserRole).toInt() : -1;
}

void NotebookPanel::rebuild()
{
    if (!m_doc) return;
    m_updating = true;

    QString keepSection;
    const int cur = m_doc->currentIndex();
    if (cur >= 0 && cur < m_doc->pageCount())
        keepSection = m_doc->page(cur).section;

    m_sectionList->clear();
    const QStringList secs = sectionOrder();
    for (const QString &s : secs)
        m_sectionList->addItem(s);

    int selRow = 0;
    if (!keepSection.isEmpty()) {
        const int found = secs.indexOf(keepSection);
        if (found >= 0) selRow = found;
    }
    if (m_sectionList->count() > 0)
        m_sectionList->setCurrentRow(selRow);

    m_updating = false;
    refreshPageList();
}

void NotebookPanel::refreshPageList()
{
    if (!m_doc) return;
    m_updating = true;
    m_pageList->clear();

    const QString sec = selectedSectionName();
    const QList<int> idxs = pagesInSection(sec);
    const int cur = m_doc->currentIndex();

    int rowToSelect = -1;
    for (int n = 0; n < idxs.size(); ++n) {
        const int gi = idxs[n];
        const Page &pg = m_doc->page(gi);
        QString hint;
        if (pg.infinite)
            hint = tr("Infinite");
        else
            hint = (pg.pageWidth <= pg.pageHeight) ? tr("Portrait") : tr("Landscape");
        auto *item = new QListWidgetItem(tr("Page %1  -  %2").arg(n + 1).arg(hint));
        item->setData(Qt::UserRole, gi);
        m_pageList->addItem(item);
        if (gi == cur) rowToSelect = n;
    }
    if (rowToSelect >= 0)
        m_pageList->setCurrentRow(rowToSelect);

    m_updating = false;
}

void NotebookPanel::syncSelection()
{
    if (!m_doc || m_updating) return;
    const int cur = m_doc->currentIndex();
    if (cur < 0 || cur >= m_doc->pageCount()) return;
    const QString sec = m_doc->page(cur).section;

    if (selectedSectionName() != sec) {
        m_updating = true;
        for (int r = 0; r < m_sectionList->count(); ++r) {
            if (m_sectionList->item(r)->text() == sec) {
                m_sectionList->setCurrentRow(r);
                break;
            }
        }
        m_updating = false;
    }
    refreshPageList();
}

void NotebookPanel::onSectionRowChanged()
{
    if (m_updating || !m_doc) return;
    const QString sec = selectedSectionName();
    if (sec.isEmpty()) return;
    const QList<int> idxs = pagesInSection(sec);
    if (!idxs.isEmpty())
        m_doc->setCurrentIndex(idxs.first());
    else
        refreshPageList();
}

void NotebookPanel::onPageRowChanged()
{
    if (m_updating || !m_doc) return;
    const int gi = selectedPageIndex();
    if (gi >= 0 && gi < m_doc->pageCount())
        m_doc->setCurrentIndex(gi);
}

QString NotebookPanel::uniqueSectionName(const QString &desired, const QString &except) const
{
    const QStringList existing = sectionOrder();
    QString candidate = desired;
    int n = 2;
    while (existing.contains(candidate) && candidate != except)
        candidate = QStringLiteral("%1 (%2)").arg(desired).arg(n++);
    return candidate;
}

void NotebookPanel::selectSectionRow(const QString &name)
{
    for (int r = 0; r < m_sectionList->count(); ++r) {
        if (m_sectionList->item(r)->text() == name) {
            m_updating = true;
            m_sectionList->setCurrentRow(r);
            m_updating = false;
            refreshPageList();
            break;
        }
    }
}

void NotebookPanel::addSection()
{
    if (!m_doc) return;
    const QString suggestion = tr("Section %1").arg(sectionOrder().size() + 1);
    bool ok = false;
    const QString input = QInputDialog::getText(this, tr("New Section"),
        tr("Section name:"), QLineEdit::Normal, suggestion, &ok);
    if (!ok) return;
    const QString trimmed = input.trimmed();
    const QString finalName = uniqueSectionName(trimmed.isEmpty() ? suggestion : trimmed,
                                                QString());

    m_doc->addPage();
    const int gi = m_doc->currentIndex();
    if (gi >= 0 && gi < m_doc->pageCount()) {
        m_doc->page(gi).section = finalName;
        m_doc->markChanged();
    }
    rebuild();
    selectSectionRow(finalName);
}

void NotebookPanel::renameSection()
{
    if (!m_doc) return;
    const QString oldName = selectedSectionName();
    if (oldName.isEmpty()) return;
    bool ok = false;
    const QString input = QInputDialog::getText(this, tr("Rename Section"),
        tr("Section name:"), QLineEdit::Normal, oldName, &ok);
    if (!ok) return;
    const QString trimmed = input.trimmed();
    if (trimmed.isEmpty() || trimmed == oldName) return;
    const QString finalName = uniqueSectionName(trimmed, oldName);

    for (int i = 0; i < m_doc->pageCount(); ++i)
        if (m_doc->page(i).section == oldName)
            m_doc->page(i).section = finalName;
    m_doc->markChanged();
    rebuild();
    selectSectionRow(finalName);
}

void NotebookPanel::deleteSection()
{
    if (!m_doc) return;
    const QString sec = selectedSectionName();
    if (sec.isEmpty()) return;
    const QList<int> idxs = pagesInSection(sec);
    if (idxs.isEmpty()) return;
    if (idxs.size() >= m_doc->pageCount()) {
        QMessageBox::information(this, tr("Delete Section"),
            tr("This is the only section - it can't be deleted."));
        return;
    }
    if (QMessageBox::question(this, tr("Delete Section"),
            tr("Delete section \"%1\" and its %n page(s)?", nullptr,
               static_cast<int>(idxs.size())).arg(sec))
        != QMessageBox::Yes)
        return;

    for (int k = static_cast<int>(idxs.size()) - 1; k >= 0; --k)
        m_doc->removePage(idxs[k]);
    rebuild();
}

void NotebookPanel::addPage()
{
    if (!m_doc) return;
    QString sec = selectedSectionName();
    if (sec.isEmpty()) sec = QStringLiteral("Section 1");
    m_doc->addPage();
    const int gi = m_doc->currentIndex();
    if (gi >= 0 && gi < m_doc->pageCount()) {
        m_doc->page(gi).section = sec;
        m_doc->markChanged();
    }
    rebuild();
    selectSectionRow(sec);
    for (int r = 0; r < m_pageList->count(); ++r) {
        if (m_pageList->item(r)->data(Qt::UserRole).toInt() == gi) {
            m_updating = true;
            m_pageList->setCurrentRow(r);
            m_updating = false;
            break;
        }
    }
}

void NotebookPanel::deletePage()
{
    if (!m_doc) return;
    const int gi = selectedPageIndex();
    if (gi < 0 || gi >= m_doc->pageCount()) return;
    if (m_doc->pageCount() <= 1) {
        QMessageBox::information(this, tr("Delete Page"),
            tr("The document must keep at least one page."));
        return;
    }
    m_doc->removePage(gi);
    rebuild();
}

} // namespace ib
EOF

# 4) Register the new widget with CMake (anchored, no rewrite) -----------------
sed -i \
  -e '/src\/ui\/PreferencesDialog\.cpp/a\    src/ui/NotebookPanel.cpp' \
  -e '/src\/ui\/PreferencesDialog\.h/a\    src/ui/NotebookPanel.h' \
  CMakeLists.txt

# 5) Dock the panel into MainWindow (anchored includes + one-line dock) --------
sed -i \
  -e '/#include "ui\/PreferencesDialog\.h"/a #include "ui/NotebookPanel.h"\n#include <QDockWidget>' \
  -e '/setCentralWidget(m_canvas);/a { QDockWidget *nbDock = new QDockWidget(tr("Notebook"), this); nbDock->setObjectName(QStringLiteral("notebookDock")); nbDock->setAllowedAreas(Qt::LeftDockWidgetArea | Qt::RightDockWidgetArea); nbDock->setWidget(new NotebookPanel(m_doc, this)); addDockWidget(Qt::LeftDockWidgetArea, nbDock); }' \
  src/ui/MainWindow.cpp

log "PART 17 complete: notebook sections + pages sidebar (add/rename/delete sections, page create/delete, live two-way sync, per-page orientation hints; section persisted in .iboard, old files load unchanged)"


# ---------------------------------------------------------------------------
#  PART 18 : Fix toolbar/menu legibility. Tool buttons (Pen, Eraser, ...) were
#            rendering white text on a white/near-white background on hover and
#            when checked. Scoped app stylesheet guarantees contrast in every
#            state (normal / hover / checked) plus menus and tooltips.
#            Overwrites src/main.cpp only.
# ---------------------------------------------------------------------------
log "PART 18: toolbar + menu readability (no more white-on-white)"

cat > src/main.cpp <<'EOF'
#include <QApplication>
#include "ui/MainWindow.h"

int main(int argc, char **argv)
{
    QApplication app(argc, argv);
    QCoreApplication::setOrganizationName("InkBoard");
    QCoreApplication::setApplicationName("InkBoard");
#ifdef INKBOARD_VERSION
    QCoreApplication::setApplicationVersion(INKBOARD_VERSION);
#endif

    // Scoped so only toolbar/menu/tooltip chrome is affected (never the canvas
    // or dialog contents): always-dark label text, clear hover, high-contrast
    // checked state.
    app.setStyleSheet(QStringLiteral(
        "QToolBar { spacing: 4px; }"
        "QToolBar QToolButton { color: #1e1e1e; padding: 4px 6px; border-radius: 4px; }"
        "QToolBar QToolButton:hover { background: #d9e6ff; color: #10233f; }"
        "QToolBar QToolButton:checked { background: #2f6fed; color: #ffffff; }"
        "QToolBar QToolButton:checked:hover { background: #285fce; color: #ffffff; }"
        "QToolBar QToolButton:pressed { background: #285fce; color: #ffffff; }"
        "QMenuBar::item { color: #1e1e1e; }"
        "QMenuBar::item:selected { background: #d9e6ff; color: #10233f; }"
        "QMenu { color: #1e1e1e; }"
        "QMenu::item:selected { background: #2f6fed; color: #ffffff; }"
        "QToolTip { color: #1e1e1e; background: #ffffdc; "
        "border: 1px solid #b0b0b0; padding: 2px; }"
    ));

    ib::MainWindow window;
    window.show();
    return app.exec();
}
EOF

log "PART 18 complete: tool buttons, menus and tooltips are always readable (dark text; high-contrast checked/hover states)"


# ---------------------------------------------------------------------------
#  PART 19 : Navigation fixes.
#    (1) Bare mouse wheel / two-finger trackpad scroll now PANS (vertical and
#        horizontal) instead of zooming. Zoom moves to Ctrl + wheel.
#    (2) Arrow keys pan the view (Shift = faster). 
#    Patches only Canvas::wheelEvent and Canvas::keyPressEvent in place.
# ---------------------------------------------------------------------------
log "PART 19: scroll-to-pan + arrow-key panning (Ctrl+wheel = zoom)"

# --- (1) replace the whole wheelEvent body -------------------------------
NEW_WHEEL=$(cat <<'CPP'
void Canvas::wheelEvent(QWheelEvent *e)
{
	// Ctrl / Cmd + wheel = zoom. Bare wheel or two-finger scroll = pan.
	if (e->modifiers() & (Qt::ControlModifier | Qt::MetaModifier)) {
		const QPoint ad = e->angleDelta();
		const int dz = (ad.y() != 0) ? ad.y() : ad.x();
		if (dz != 0)
			zoomAround(e->position(), std::pow(1.0015, dz));
		e->accept();
		return;
	}

	QPointF delta;
	const QPoint pd = e->pixelDelta();
	if (!pd.isNull()) {
		delta = QPointF(pd);                          // trackpad: pixel-precise
	} else {
		const QPoint ad = e->angleDelta();            // wheel: ~48px per notch
		delta = QPointF(ad.x(), ad.y()) * (48.0 / 120.0);
	}

	// Vertical-only wheels: hold Shift to scroll sideways.
	if ((e->modifiers() & Qt::ShiftModifier) && qFuzzyIsNull(delta.x()))
		delta = QPointF(delta.y(), 0.0);

	if (!delta.isNull()) {
		m_translate += delta;
		update();
		emit viewChanged();
	}
	e->accept();
}
CPP
)
export NEW_WHEEL
perl -0777 -i -pe 'BEGIN{$r=$ENV{NEW_WHEEL}} s/void\s+Canvas::wheelEvent\s*\(\s*QWheelEvent\s*\*\s*e\s*\)\s*\{.*?\n\}/$r/s' src/canvas/Canvas.cpp
grep -q "e->pixelDelta()" src/canvas/Canvas.cpp \
	|| { echo "PART 19 ERROR: wheelEvent patch did not apply"; exit 1; }

# --- (2) insert arrow-key panning before the base keyPressEvent call -----
NEW_ARROW=$(cat <<'CPP'
	if (e->key() == Qt::Key_Left || e->key() == Qt::Key_Right ||
	    e->key() == Qt::Key_Up   || e->key() == Qt::Key_Down) {
		const double step = (e->modifiers() & Qt::ShiftModifier) ? 240.0 : 60.0;
		QPointF d;
		if (e->key() == Qt::Key_Left)  d.setX( step);
		if (e->key() == Qt::Key_Right) d.setX(-step);
		if (e->key() == Qt::Key_Up)    d.setY( step);
		if (e->key() == Qt::Key_Down)  d.setY(-step);
		m_translate += d;
		update();
		emit viewChanged();
		e->accept();
		return;
	}
	QWidget::keyPressEvent(e);
CPP
)
export NEW_ARROW
perl -0777 -i -pe 'BEGIN{$r=$ENV{NEW_ARROW}} s/\n[ \t]*QWidget::keyPressEvent\s*\(\s*e\s*\)\s*;/\n$r/s' src/canvas/Canvas.cpp
grep -q "Qt::Key_Left" src/canvas/Canvas.cpp \
	|| { echo "PART 19 ERROR: arrow-key patch did not apply"; exit 1; }

log "PART 19 complete: bare wheel/two-finger scroll pans (H+V), Ctrl+wheel zooms, arrow keys pan (Shift = faster)"


# ---------------------------------------------------------------------------
#  PART 20 : Stop drawing the brush-preview overlay that followed the cursor
#            (dot for pen/highlighter/shapes, soft glow for laser). It was
#            distracting while drawing. The eraser keeps its dashed ring only,
#            because its system cursor is hidden and the ring is its sole size
#            indicator. Rewrites Canvas::drawBrushPreview only.
# ---------------------------------------------------------------------------
log "PART 20: remove pointer-follow preview circles (keep eraser ring only)"

NEW_PREVIEW=$(cat <<'CPP'
void Canvas::drawBrushPreview(QPainter &p)
{
	// Only the eraser shows a cursor ring; its system cursor is hidden, so the
	// ring is the sole size indicator. No preview dot/glow for other tools -
	// this keeps the drawing surface clean under the pen.
	if (!m_hoverValid || m_panning)
		return;
	if (m_settings.tool != ToolId::Eraser)
		return;

	const double r = m_settings.eraserRadius * m_scale;
	QPen pen(QColor(70, 70, 70));
	pen.setStyle(Qt::DashLine);
	p.setPen(pen);
	p.setBrush(Qt::NoBrush);
	p.drawEllipse(m_cursorWidget, r, r);
}
CPP
)
export NEW_PREVIEW
perl -0777 -i -pe 'BEGIN{$r=$ENV{NEW_PREVIEW}} s/void\s+Canvas::drawBrushPreview\s*\(\s*QPainter\s*&\s*p\s*\)\s*\{.*?\n\}/$r/s' src/canvas/Canvas.cpp
grep -q "sole size indicator" src/canvas/Canvas.cpp \
	|| { echo "PART 20 ERROR: drawBrushPreview patch did not apply"; exit 1; }

log "PART 20 complete: no more preview circles under the pointer (eraser ring kept)"

# ---------------------------------------------------------------------------
#  PART 21 : Dark toolbar theme. Toolbar is dark with white labels; on hover
#            the button turns white with dark text (never white-on-white); the
#            active tool is a clear blue. Toolbar QLabels ("Size") go white too.
#            Swatches are icon-based, so a transparent button bg doesn't hurt
#            them. Overwrites src/main.cpp only.
# ---------------------------------------------------------------------------
log "PART 21: dark toolbar theme (white text, white-on-hover with dark text)"

cat > src/main.cpp <<'EOF'
#include <QApplication>
#include "ui/MainWindow.h"

int main(int argc, char **argv)
{
    QApplication app(argc, argv);
    QCoreApplication::setOrganizationName("InkBoard");
    QCoreApplication::setApplicationName("InkBoard");
#ifdef INKBOARD_VERSION
    QCoreApplication::setApplicationVersion(INKBOARD_VERSION);
#endif

    app.setStyleSheet(QStringLiteral(
        "QToolBar { background: #2b2d31; border: none; spacing: 4px; padding: 3px; }"
        "QToolBar QLabel { color: #f5f5f5; }"
        "QToolBar QToolButton { color: #f5f5f5; background: transparent;"
        " padding: 4px 9px; border-radius: 5px; }"
        "QToolBar QToolButton:hover,"
        "QToolBar QToolButton:checked:hover { background: #ffffff; color: #1a1a1a; }"
        "QToolBar QToolButton:checked { background: #3d7be0; color: #ffffff; }"
        "QToolBar QToolButton:pressed { background: #dfe7f5; color: #10233f; }"
        "QMenu::item:selected { background: #3d7be0; color: #ffffff; }"
        "QToolTip { color: #1e1e1e; background: #ffffdc;"
        " border: 1px solid #b0b0b0; padding: 2px; }"
    ));

    ib::MainWindow window;
    window.show();
    return app.exec();
}
EOF

log "PART 21 complete: dark toolbar, white labels, white-on-hover dark text, blue active tool"

# ============================================================
# PART 24 — restore pen-tip dot, kill the tap rings
# ============================================================
log "PART 24: fixing brush preview (tip dot back, no rings)"

BRUSH_BODY=$(cat <<'CPP'
    if (!m_hoverValid)
        return;

    // Eraser keeps its dashed ring as the sole size indicator.
    if (m_settings.tool == ToolId::Eraser) {
        double r = m_settings.eraserRadius * m_scale;
        if (r < 4.0)
            r = 4.0;
        p.save();
        p.setRenderHint(QPainter::Antialiasing, true);
        QPen ring(QColor(90, 90, 90), 1.0, Qt::DashLine);
        p.setPen(ring);
        p.setBrush(Qt::NoBrush);
        p.drawEllipse(m_cursorWidget, r, r);
        p.restore();
        return;
    }

    // These tools show no hover marker at all.
    if (m_settings.tool == ToolId::Select ||
        m_settings.tool == ToolId::Laser ||
        m_settings.tool == ToolId::Text)
        return;

    // Pen / Highlighter / shape tools: ONE tiny dot marks the exact tip.
    // No concentric size rings (the tap rings that were confusing).
    QColor c;
    switch (m_settings.tool) {
    case ToolId::Highlighter: c = m_settings.hlColor;    break;
    case ToolId::Line:
    case ToolId::Rectangle:
    case ToolId::Ellipse:     c = m_settings.shapeColor; break;
    default:                  c = m_settings.penColor;   break;
    }
    c.setAlpha(235);
    p.save();
    p.setRenderHint(QPainter::Antialiasing, true);
    p.setPen(Qt::NoPen);
    p.setBrush(c);
    p.drawEllipse(m_cursorWidget, 2.5, 2.5);  // sole tip indicator, no rings
    p.restore();
CPP
)
export BRUSH_BODY

perl -0777 -i -pe 'BEGIN{$b=$ENV{BRUSH_BODY}} s/(void\s+Canvas::drawBrushPreview\s*\([^)]*\)\s*(?:const\s*)?\{).*?\n\}/$1\n$b\n}/s' src/canvas/Canvas.cpp

grep -q "sole tip indicator, no rings" src/canvas/Canvas.cpp || { echo "PART 24 ERROR: drawBrushPreview was not patched"; exit 1; }

log "PART 24 complete: tip dot restored, preview rings removed"

# ============================================================
# PART 25 — kill the Windows pen "press-and-hold" gesture ring
# ============================================================
log "PART 25: disabling Windows pen press-and-hold ring"

# --- MainWindow.h: declare nativeEvent override ---
grep -q "nativeEvent" src/ui/MainWindow.h || \
perl -0777 -i -pe 's/(void\s+closeEvent\s*\(\s*QCloseEvent\s*\*\s*e\s*\)\s*override\s*;)/$1\n\tbool nativeEvent(const QByteArray &eventType, void *message, qintptr *result) override;/s' src/ui/MainWindow.h
grep -q "nativeEvent" src/ui/MainWindow.h || { echo "PART 25 ERROR: MainWindow.h nativeEvent decl not added"; exit 1; }

# --- MainWindow.cpp: Windows tablet gesture constants (before namespace) ---
MW_WIN_BLOCK=$(cat <<'CPP'
#ifdef Q_OS_WIN
#  ifndef NOMINMAX
#    define NOMINMAX
#  endif
#  ifndef WIN32_LEAN_AND_MEAN
#    define WIN32_LEAN_AND_MEAN
#  endif
#  include <windows.h>
#  ifndef WM_TABLET_DEFBASE
#    define WM_TABLET_DEFBASE 0x02C0
#  endif
#  ifndef WM_TABLET_QUERYSYSTEMGESTURESTATUS
#    define WM_TABLET_QUERYSYSTEMGESTURESTATUS (WM_TABLET_DEFBASE + 12)
#  endif
#  ifndef TABLET_DISABLE_PRESSANDHOLD
#    define TABLET_DISABLE_PRESSANDHOLD 0x00000001
#  endif
#  ifndef TABLET_DISABLE_PENTAPFEEDBACK
#    define TABLET_DISABLE_PENTAPFEEDBACK 0x00000008
#  endif
#  ifndef TABLET_DISABLE_PENBARRELFEEDBACK
#    define TABLET_DISABLE_PENBARRELFEEDBACK 0x00000010
#  endif
#endif

CPP
)
export MW_WIN_BLOCK
grep -q "TABLET_DISABLE_PRESSANDHOLD" src/ui/MainWindow.cpp || \
perl -0777 -i -pe 'BEGIN{$b=$ENV{MW_WIN_BLOCK}} s/(\nnamespace ib \{)/\n$b$1/' src/ui/MainWindow.cpp
grep -q "TABLET_DISABLE_PRESSANDHOLD" src/ui/MainWindow.cpp || { echo "PART 25 ERROR: tablet defines not inserted"; exit 1; }

# --- MainWindow.cpp: nativeEvent implementation (before closing namespace) ---
MW_NATIVE_IMPL=$(cat <<'CPP'
bool MainWindow::nativeEvent(const QByteArray &eventType, void *message, qintptr *result)
{
#ifdef Q_OS_WIN
    MSG *msg = static_cast<MSG *>(message);
    if (msg && msg->message == WM_TABLET_QUERYSYSTEMGESTURESTATUS) {
        // Turn off the Windows pen "press-and-hold" right-click ring plus the
        // pen tap / barrel feedback, so no gesture rings appear under the pen.
        *result = TABLET_DISABLE_PRESSANDHOLD
                | TABLET_DISABLE_PENTAPFEEDBACK
                | TABLET_DISABLE_PENBARRELFEEDBACK;
        return true;
    }
#endif
    return QMainWindow::nativeEvent(eventType, message, result);
}

CPP
)
export MW_NATIVE_IMPL
grep -q "MainWindow::nativeEvent" src/ui/MainWindow.cpp || \
perl -0777 -i -pe 'BEGIN{$i=$ENV{MW_NATIVE_IMPL}} s/(\}\s*\/\/\s*namespace ib)/$i$1/s' src/ui/MainWindow.cpp
grep -q "MainWindow::nativeEvent" src/ui/MainWindow.cpp || { echo "PART 25 ERROR: MainWindow.cpp nativeEvent impl missing"; exit 1; }

log "PART 25 complete: pen press-and-hold gesture ring disabled"


# ============================================================
# PART 26 — recoverable Notebook sidebar (toolbar button + View toggle)
# ============================================================
log "PART 26: adding Show Sidebar toggle"

# --- MainWindow.h: forward declare QDockWidget + hold the dock as a member ---
grep -q "class QDockWidget;" src/ui/MainWindow.h || \
perl -0777 -i -pe 's/(class QToolBar;)/$1\nclass QDockWidget;/' src/ui/MainWindow.h

grep -q "m_nbDock" src/ui/MainWindow.h || \
perl -0777 -i -pe 's/(Canvas\s*\*\s*m_canvas\s*=\s*nullptr;)/$1\n\tQDockWidget *m_nbDock = nullptr;/' src/ui/MainWindow.h

grep -q "m_nbDock" src/ui/MainWindow.h || { echo "PART 26 ERROR: MainWindow.h member not added"; exit 1; }

# --- MainWindow.cpp: make the dock a member (assignment, not a new local) ---
perl -0777 -i -pe 's/QDockWidget\s*\*\s*nbDock\s*=\s*new\s+QDockWidget/m_nbDock = new QDockWidget/' src/ui/MainWindow.cpp
perl -0777 -i -pe 's/\bnbDock\b/m_nbDock/g' src/ui/MainWindow.cpp
grep -q "m_nbDock = new QDockWidget" src/ui/MainWindow.cpp || { echo "PART 26 ERROR: dock not converted to member"; exit 1; }

# --- MainWindow.cpp: add the toggle to the View menu ---
VIEW_TOGGLE=$(cat <<'CPP'
	if (m_nbDock) {
		QAction *toggleSidebar = m_nbDock->toggleViewAction();
		toggleSidebar->setText(tr("Show &Sidebar"));
		toggleSidebar->setShortcut(QKeySequence(Qt::CTRL | Qt::Key_B));
		view->addAction(toggleSidebar);
		view->addSeparator();
	}
CPP
)
export VIEW_TOGGLE
grep -q "Show &Sidebar" src/ui/MainWindow.cpp || \
perl -0777 -i -pe 'BEGIN{$t=$ENV{VIEW_TOGGLE}} s/(QMenu\s*\*\s*view\s*=\s*menuBar\(\)->addMenu\(tr\("&View"\)\);)/$1\n$t/' src/ui/MainWindow.cpp
grep -q "Show &Sidebar" src/ui/MainWindow.cpp || { echo "PART 26 ERROR: View toggle not inserted"; exit 1; }

# --- MainWindow.cpp: add the same toggle as a toolbar button ---
TB_TOGGLE=$(cat <<'CPP'
	if (m_nbDock) {
		toolBar->addSeparator();
		toolBar->addAction(m_nbDock->toggleViewAction());
	}
CPP
)
export TB_TOGGLE
grep -q "toolBar->addAction(m_nbDock->toggleViewAction());" src/ui/MainWindow.cpp || \
perl -0777 -i -pe 'BEGIN{$t=$ENV{TB_TOGGLE}} s/(toolBar->addAction\(pair\.second\);)/$1\n$t/' src/ui/MainWindow.cpp
grep -q "toolBar->addAction(m_nbDock->toggleViewAction());" src/ui/MainWindow.cpp || { echo "PART 26 ERROR: toolbar toggle not inserted"; exit 1; }

log "PART 26 complete: Notebook sidebar can be reopened (toolbar button + Ctrl+B)"
