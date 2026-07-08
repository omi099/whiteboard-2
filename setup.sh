#!/usr/bin/env bash
set -euo pipefail
echo ">> Part 1: build system + theme"

mkdir -p src src/model src/canvas src/ui resources/style .github/workflows

# ---------- CMakeLists.txt ----------
cat > CMakeLists.txt << 'EOF'
cmake_minimum_required(VERSION 3.21)
project(Whiteboard VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets Svg)
qt_standard_project_setup()

qt_add_executable(Whiteboard WIN32
    src/main.cpp
    src/Theme.h
    src/Theme.cpp

    src/model/Item.h
    src/model/Document.h
    src/model/Document.cpp

    src/canvas/Tools.h
    src/canvas/CanvasWidget.h
    src/canvas/CanvasWidget.cpp

    src/ui/MainWindow.h
    src/ui/MainWindow.cpp
    src/ui/ColorButton.h
    src/ui/ColorButton.cpp

    resources/resources.qrc
)

target_include_directories(Whiteboard PRIVATE src)

target_link_libraries(Whiteboard PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    Qt6::Svg
)
EOF

# ---------- resource bundle ----------
cat > resources/resources.qrc << 'EOF'
<RCC>
    <qresource prefix="/">
        <file>style/dark.qss</file>
        <file>style/light.qss</file>
    </qresource>
</RCC>
EOF

# ---------- dark theme ----------
cat > resources/style/dark.qss << 'EOF'
* {
    font-family: "Segoe UI", "Inter", sans-serif;
    font-size: 13px;
    color: #e6e6f0;
    outline: none;
}
QMainWindow, QWidget#Root {
    background: #16161f;
}
QWidget#ToolRail {
    background: #1c1c28;
    border-right: 1px solid #2a2a3a;
}
QWidget#PropertyPanel {
    background: #1c1c28;
    border-left: 1px solid #2a2a3a;
}
QLabel#PanelHeader {
    color: #9a9ab5;
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 1px;
    padding: 10px 4px 4px 4px;
}
QToolBar {
    background: #1c1c28;
    border: none;
    spacing: 6px;
    padding: 6px;
}
QToolButton {
    background: transparent;
    border: 1px solid transparent;
    border-radius: 8px;
    padding: 8px;
    min-width: 34px;
    min-height: 34px;
}
QToolButton:hover {
    background: #26263a;
    border: 1px solid #33334d;
}
QToolButton:checked {
    background: #7c5cff;
    color: #ffffff;
    border: 1px solid #7c5cff;
}
QPushButton {
    background: #26263a;
    border: 1px solid #33334d;
    border-radius: 8px;
    padding: 7px 14px;
}
QPushButton:hover { background: #30304a; }
QPushButton:pressed { background: #7c5cff; border-color: #7c5cff; }
QPushButton#Accent {
    background: #7c5cff;
    border: none;
    color: #ffffff;
    font-weight: 600;
}
QPushButton#Accent:hover { background: #8f74ff; }
QSpinBox, QDoubleSpinBox, QComboBox {
    background: #22223200;
    background-color: #22222f;
    border: 1px solid #33334d;
    border-radius: 6px;
    padding: 4px 8px;
    min-height: 22px;
}
QComboBox::drop-down { border: none; width: 18px; }
QComboBox QAbstractItemView {
    background: #22222f;
    border: 1px solid #33334d;
    selection-background-color: #7c5cff;
}
QSlider::groove:horizontal {
    height: 4px; background: #33334d; border-radius: 2px;
}
QSlider::handle:horizontal {
    width: 14px; margin: -6px 0; border-radius: 7px; background: #7c5cff;
}
QMenuBar { background: #16161f; }
QMenuBar::item { padding: 6px 12px; background: transparent; }
QMenuBar::item:selected { background: #26263a; border-radius: 6px; }
QMenu {
    background: #1c1c28; border: 1px solid #33334d; border-radius: 8px; padding: 4px;
}
QMenu::item { padding: 6px 22px; border-radius: 6px; }
QMenu::item:selected { background: #7c5cff; }
QStatusBar { background: #1c1c28; color: #9a9ab5; border-top: 1px solid #2a2a3a; }
QToolTip {
    background: #26263a; color: #e6e6f0; border: 1px solid #33334d;
    border-radius: 6px; padding: 4px 8px;
}
EOF

# ---------- light theme ----------
cat > resources/style/light.qss << 'EOF'
* {
    font-family: "Segoe UI", "Inter", sans-serif;
    font-size: 13px;
    color: #1c1c28;
    outline: none;
}
QMainWindow, QWidget#Root { background: #f4f4f8; }
QWidget#ToolRail { background: #ffffff; border-right: 1px solid #e3e3ee; }
QWidget#PropertyPanel { background: #ffffff; border-left: 1px solid #e3e3ee; }
QLabel#PanelHeader {
    color: #7a7a90; font-size: 11px; font-weight: 600; letter-spacing: 1px;
    padding: 10px 4px 4px 4px;
}
QToolBar { background: #ffffff; border: none; spacing: 6px; padding: 6px; }
QToolButton {
    background: transparent; border: 1px solid transparent; border-radius: 8px;
    padding: 8px; min-width: 34px; min-height: 34px;
}
QToolButton:hover { background: #eeeef6; border: 1px solid #e3e3ee; }
QToolButton:checked { background: #7c5cff; color: #ffffff; border: 1px solid #7c5cff; }
QPushButton {
    background: #eeeef6; border: 1px solid #e3e3ee; border-radius: 8px; padding: 7px 14px;
}
QPushButton:hover { background: #e4e4f0; }
QPushButton#Accent { background: #7c5cff; border: none; color: #ffffff; font-weight: 600; }
QPushButton#Accent:hover { background: #8f74ff; }
QSpinBox, QDoubleSpinBox, QComboBox {
    background-color: #ffffff; border: 1px solid #d8d8e6; border-radius: 6px;
    padding: 4px 8px; min-height: 22px;
}
QComboBox QAbstractItemView {
    background: #ffffff; border: 1px solid #d8d8e6; selection-background-color: #7c5cff;
}
QSlider::groove:horizontal { height: 4px; background: #d8d8e6; border-radius: 2px; }
QSlider::handle:horizontal { width: 14px; margin: -6px 0; border-radius: 7px; background: #7c5cff; }
QMenuBar { background: #ffffff; }
QMenuBar::item:selected { background: #eeeef6; border-radius: 6px; }
QMenu { background: #ffffff; border: 1px solid #d8d8e6; border-radius: 8px; padding: 4px; }
QMenu::item:selected { background: #7c5cff; color: #ffffff; }
QStatusBar { background: #ffffff; color: #7a7a90; border-top: 1px solid #e3e3ee; }
EOF

# ---------- Theme helper ----------
cat > src/Theme.h << 'EOF'
#pragma once
#include <QString>
class QApplication;

class Theme {
public:
    enum Mode { Dark, Light };
    static void apply(QApplication &app, Mode mode);
    static Mode current();
    static void toggle(QApplication &app);
private:
    static Mode s_mode;
};
EOF

cat > src/Theme.cpp << 'EOF'
#include "Theme.h"
#include <QApplication>
#include <QFile>
#include <QStyleFactory>

Theme::Mode Theme::s_mode = Theme::Dark;

void Theme::apply(QApplication &app, Mode mode)
{
    s_mode = mode;
    app.setStyle(QStyleFactory::create("Fusion"));
    const QString path = (mode == Dark) ? ":/style/dark.qss" : ":/style/light.qss";
    QFile f(path);
    if (f.open(QIODevice::ReadOnly | QIODevice::Text))
        app.setStyleSheet(QString::fromUtf8(f.readAll()));
}

Theme::Mode Theme::current() { return s_mode; }

void Theme::toggle(QApplication &app)
{
    apply(app, s_mode == Dark ? Light : Dark);
}
EOF

# ---------- main.cpp ----------
cat > src/main.cpp << 'EOF'
#include <QApplication>
#include "Theme.h"
#include "ui/MainWindow.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    QApplication::setApplicationName("Whiteboard");
    QApplication::setOrganizationName("Whiteboard");

    Theme::apply(app, Theme::Dark);

    MainWindow w;
    w.resize(1440, 900);
    w.show();
    return app.exec();
}
EOF

echo ">> Part 1 done. (Won't compile yet — needs Parts 2-5.)"

#!/usr/bin/env bash
set -euo pipefail
echo ">> Part 2: data model (items, layers, pages, document, undo/redo, serialization)"

# ---------- src/model/Item.h ----------
cat > src/model/Item.h << 'EOF'
#pragma once

#include <QColor>
#include <QPointF>
#include <QRectF>
#include <QSizeF>
#include <QString>
#include <QVector>
#include <QImage>
#include <QtGlobal>

enum class ItemType { Stroke, Line, Arrow, Rect, Ellipse, Text, Image };

struct StrokePoint {
    QPointF pos;
    qreal   pressure = 1.0;
};

// A single drawable object. One struct covers all types to keep
// rendering (switch on type) and serialization simple and robust.
struct Item {
    ItemType type = ItemType::Stroke;

    // shared style
    QColor color   = QColor("#e6e6f0");
    qreal  width   = 3.0;
    qreal  opacity = 1.0;
    bool   highlighter = false;
    bool   filled  = false;   // shapes: fill vs outline

    // freehand stroke
    QVector<StrokePoint> points;

    // shapes / image: two defining corners (or endpoints)
    QPointF p1;
    QPointF p2;

    // text
    QString text;
    QString fontFamily = "Segoe UI";
    qreal   fontSize   = 28.0;

    // image (embedded)
    QImage image;

    // transient editor state (not serialized)
    bool selected = false;

    QRectF bounds() const {
        switch (type) {
        case ItemType::Stroke: {
            if (points.isEmpty())
                return QRectF();
            qreal minX = points[0].pos.x(), maxX = minX;
            qreal minY = points[0].pos.y(), maxY = minY;
            for (const auto &p : points) {
                minX = qMin(minX, p.pos.x());
                maxX = qMax(maxX, p.pos.x());
                minY = qMin(minY, p.pos.y());
                maxY = qMax(maxY, p.pos.y());
            }
            return QRectF(QPointF(minX, minY), QPointF(maxX, maxY))
                .adjusted(-width, -width, width, width);
        }
        case ItemType::Text: {
            const qreal w = qMax<qreal>(20.0, text.length() * fontSize * 0.6);
            return QRectF(p1, QSizeF(w, fontSize * 1.4));
        }
        case ItemType::Image:
            return QRectF(p1, p2).normalized();
        default: // Line, Arrow, Rect, Ellipse
            return QRectF(p1, p2).normalized().adjusted(-width, -width, width, width);
        }
    }
};

struct Background {
    enum Grid { None, Lines, Dots, Squares };
    QColor color     = QColor("#ffffff");
    Grid   grid      = None;
    qreal  spacing   = 32.0;
    QColor gridColor = QColor("#dfe3ea");
};

struct Layer {
    QString       name    = "Layer 1";
    bool          visible = true;
    bool          locked  = false;
    qreal         opacity = 1.0;
    QVector<Item> items;
};

struct Page {
    QVector<Layer> layers;
    int            activeLayer = 0;
    Background     background;
    Page() { layers.push_back(Layer{}); }
};
EOF

# ---------- src/model/Document.h ----------
cat > src/model/Document.h << 'EOF'
#pragma once

#include "Item.h"
#include <QJsonObject>
#include <QVector>

// Owns all pages/layers/items and the undo-redo history.
// Undo is a full snapshot of every page (simple + always-correct).
class Document {
public:
    Document();

    // pages
    int  pageCount() const { return m_pages.size(); }
    int  currentPageIndex() const { return m_current; }
    void setCurrentPage(int i);
    void addPage();
    void deleteCurrentPage();

    Page       &currentPage();
    const Page &currentPage() const;

    // layers (on current page)
    Layer       &activeLayer();
    const Layer &activeLayer() const;
    void addLayer();
    void deleteLayer(int i);
    void setActiveLayer(int i);

    // editing (each pushes undo)
    void addItem(const Item &it);
    void replaceItems(const QVector<Item> &items); // for select/erase edits
    void clearCurrentPage();

    // history
    void pushUndo();
    bool undo();
    bool redo();
    bool canUndo() const { return !m_undo.isEmpty(); }
    bool canRedo() const { return !m_redo.isEmpty(); }

    // persistence
    QJsonObject toJson() const;
    bool        fromJson(const QJsonObject &obj);

private:
    QVector<Page>            m_pages;
    int                      m_current = 0;
    QVector<QVector<Page>>   m_undo;
    QVector<QVector<Page>>   m_redo;
    int                      m_layerCounter = 1;
};
EOF

# ---------- src/model/Document.cpp ----------
cat > src/model/Document.cpp << 'EOF'
#include "Document.h"

#include <QBuffer>
#include <QByteArray>
#include <QJsonArray>
#include <QJsonValue>

static QString colorToStr(const QColor &c) { return c.name(QColor::HexArgb); }
static QColor  strToColor(const QString &s) { return QColor(s); }

Document::Document()
{
    m_pages.push_back(Page{});
}

void Document::setCurrentPage(int i)
{
    if (i >= 0 && i < m_pages.size())
        m_current = i;
}

void Document::addPage()
{
    pushUndo();
    m_pages.push_back(Page{});
    m_current = m_pages.size() - 1;
}

void Document::deleteCurrentPage()
{
    if (m_pages.size() <= 1)
        return;
    pushUndo();
    m_pages.removeAt(m_current);
    if (m_current >= m_pages.size())
        m_current = m_pages.size() - 1;
}

Page &Document::currentPage() { return m_pages[m_current]; }
const Page &Document::currentPage() const { return m_pages[m_current]; }

Layer &Document::activeLayer()
{
    Page &pg = currentPage();
    if (pg.activeLayer < 0 || pg.activeLayer >= pg.layers.size())
        pg.activeLayer = 0;
    return pg.layers[pg.activeLayer];
}
const Layer &Document::activeLayer() const
{
    const Page &pg = currentPage();
    int idx = qBound(0, pg.activeLayer, pg.layers.size() - 1);
    return pg.layers[idx];
}

void Document::addLayer()
{
    pushUndo();
    Layer l;
    l.name = QString("Layer %1").arg(++m_layerCounter);
    currentPage().layers.push_back(l);
    currentPage().activeLayer = currentPage().layers.size() - 1;
}

void Document::deleteLayer(int i)
{
    Page &pg = currentPage();
    if (pg.layers.size() <= 1 || i < 0 || i >= pg.layers.size())
        return;
    pushUndo();
    pg.layers.removeAt(i);
    pg.activeLayer = qBound(0, pg.activeLayer, pg.layers.size() - 1);
}

void Document::setActiveLayer(int i)
{
    Page &pg = currentPage();
    if (i >= 0 && i < pg.layers.size())
        pg.activeLayer = i;
}

void Document::addItem(const Item &it)
{
    pushUndo();
    activeLayer().items.push_back(it);
}

void Document::replaceItems(const QVector<Item> &items)
{
    pushUndo();
    activeLayer().items = items;
}

void Document::clearCurrentPage()
{
    pushUndo();
    for (Layer &l : currentPage().layers)
        l.items.clear();
}

void Document::pushUndo()
{
    m_undo.push_back(m_pages);
    if (m_undo.size() > 60)
        m_undo.removeFirst();
    m_redo.clear();
}

bool Document::undo()
{
    if (m_undo.isEmpty())
        return false;
    m_redo.push_back(m_pages);
    m_pages = m_undo.takeLast();
    m_current = qBound(0, m_current, m_pages.size() - 1);
    return true;
}

bool Document::redo()
{
    if (m_redo.isEmpty())
        return false;
    m_undo.push_back(m_pages);
    m_pages = m_redo.takeLast();
    m_current = qBound(0, m_current, m_pages.size() - 1);
    return true;
}

// ---------------- serialization ----------------

QJsonObject Document::toJson() const
{
    QJsonArray pagesArr;
    for (const Page &pg : m_pages) {
        QJsonObject po;
        QJsonObject bg;
        bg["color"]     = colorToStr(pg.background.color);
        bg["grid"]      = int(pg.background.grid);
        bg["spacing"]   = pg.background.spacing;
        bg["gridColor"] = colorToStr(pg.background.gridColor);
        po["background"] = bg;
        po["activeLayer"] = pg.activeLayer;

        QJsonArray layersArr;
        for (const Layer &l : pg.layers) {
            QJsonObject lo;
            lo["name"]    = l.name;
            lo["visible"] = l.visible;
            lo["locked"]  = l.locked;
            lo["opacity"] = l.opacity;

            QJsonArray itemsArr;
            for (const Item &it : l.items) {
                QJsonObject o;
                o["type"]        = int(it.type);
                o["color"]       = colorToStr(it.color);
                o["width"]       = it.width;
                o["opacity"]     = it.opacity;
                o["highlighter"] = it.highlighter;
                o["filled"]      = it.filled;

                if (it.type == ItemType::Stroke) {
                    QJsonArray pts;
                    for (const auto &p : it.points) {
                        pts.append(p.pos.x());
                        pts.append(p.pos.y());
                        pts.append(p.pressure);
                    }
                    o["points"] = pts;
                } else if (it.type == ItemType::Text) {
                    o["x"] = it.p1.x();
                    o["y"] = it.p1.y();
                    o["text"] = it.text;
                    o["fontFamily"] = it.fontFamily;
                    o["fontSize"] = it.fontSize;
                } else if (it.type == ItemType::Image) {
                    o["x1"] = it.p1.x(); o["y1"] = it.p1.y();
                    o["x2"] = it.p2.x(); o["y2"] = it.p2.y();
                    if (!it.image.isNull()) {
                        QByteArray ba;
                        QBuffer buf(&ba);
                        buf.open(QIODevice::WriteOnly);
                        it.image.save(&buf, "PNG");
                        o["image"] = QString::fromLatin1(ba.toBase64());
                    }
                } else { // shapes
                    o["x1"] = it.p1.x(); o["y1"] = it.p1.y();
                    o["x2"] = it.p2.x(); o["y2"] = it.p2.y();
                }
                itemsArr.append(o);
            }
            lo["items"] = itemsArr;
            layersArr.append(lo);
        }
        po["layers"] = layersArr;
        pagesArr.append(po);
    }

    QJsonObject root;
    root["version"] = 2;
    root["current"] = m_current;
    root["pages"]   = pagesArr;
    return root;
}

bool Document::fromJson(const QJsonObject &root)
{
    const QJsonArray pagesArr = root["pages"].toArray();
    if (pagesArr.isEmpty())
        return false;

    QVector<Page> pages;
    for (const auto &pv : pagesArr) {
        const QJsonObject po = pv.toObject();
        Page pg;
        pg.layers.clear();

        const QJsonObject bg = po["background"].toObject();
        pg.background.color     = strToColor(bg["color"].toString("#ffffff"));
        pg.background.grid      = Background::Grid(bg["grid"].toInt(0));
        pg.background.spacing   = bg["spacing"].toDouble(32.0);
        pg.background.gridColor = strToColor(bg["gridColor"].toString("#dfe3ea"));
        pg.activeLayer          = po["activeLayer"].toInt(0);

        for (const auto &lv : po["layers"].toArray()) {
            const QJsonObject lo = lv.toObject();
            Layer l;
            l.name    = lo["name"].toString("Layer 1");
            l.visible = lo["visible"].toBool(true);
            l.locked  = lo["locked"].toBool(false);
            l.opacity = lo["opacity"].toDouble(1.0);

            for (const auto &iv : lo["items"].toArray()) {
                const QJsonObject o = iv.toObject();
                Item it;
                it.type        = ItemType(o["type"].toInt(0));
                it.color       = strToColor(o["color"].toString("#e6e6f0"));
                it.width       = o["width"].toDouble(3.0);
                it.opacity     = o["opacity"].toDouble(1.0);
                it.highlighter = o["highlighter"].toBool(false);
                it.filled      = o["filled"].toBool(false);

                if (it.type == ItemType::Stroke) {
                    const QJsonArray pts = o["points"].toArray();
                    for (int i = 0; i + 2 < pts.size() + 0 && i + 2 < pts.size(); i += 3) {
                        it.points.push_back({QPointF(pts[i].toDouble(),
                                                     pts[i + 1].toDouble()),
                                             pts[i + 2].toDouble(1.0)});
                    }
                } else if (it.type == ItemType::Text) {
                    it.p1 = QPointF(o["x"].toDouble(), o["y"].toDouble());
                    it.text = o["text"].toString();
                    it.fontFamily = o["fontFamily"].toString("Segoe UI");
                    it.fontSize = o["fontSize"].toDouble(28.0);
                } else if (it.type == ItemType::Image) {
                    it.p1 = QPointF(o["x1"].toDouble(), o["y1"].toDouble());
                    it.p2 = QPointF(o["x2"].toDouble(), o["y2"].toDouble());
                    const QByteArray ba =
                        QByteArray::fromBase64(o["image"].toString().toLatin1());
                    it.image.loadFromData(ba, "PNG");
                } else {
                    it.p1 = QPointF(o["x1"].toDouble(), o["y1"].toDouble());
                    it.p2 = QPointF(o["x2"].toDouble(), o["y2"].toDouble());
                }
                l.items.push_back(it);
            }
            pg.layers.push_back(l);
        }
        if (pg.layers.isEmpty())
            pg.layers.push_back(Layer{});
        pages.push_back(pg);
    }

    m_pages = pages;
    m_current = qBound(0, root["current"].toInt(0), m_pages.size() - 1);
    m_undo.clear();
    m_redo.clear();
    return true;
}
EOF

echo ">> Part 2 done. (Still needs Parts 3-5 to compile.)"

#!/usr/bin/env bash
set -euo pipefail
echo ">> Part 3: canvas engine (interface + rendering + pan/zoom + grid + input + freehand)"

# ---------- src/canvas/Tools.h ----------
cat > src/canvas/Tools.h << 'EOF'
#pragma once
#include <QColor>
#include <QString>

enum class Tool {
    Pen, Highlighter, Eraser, Select,
    Line, Arrow, Rect, Ellipse, Text, Laser
};

struct ToolSettings {
    QColor  color      = QColor("#e6e6f0");
    qreal   width      = 3.0;
    qreal   opacity    = 1.0;
    bool    fillShapes = false;
    qreal   fontSize   = 28.0;
    QString fontFamily = "Segoe UI";
};

inline QString toolName(Tool t) {
    switch (t) {
    case Tool::Pen: return "Pen";
    case Tool::Highlighter: return "Highlighter";
    case Tool::Eraser: return "Eraser";
    case Tool::Select: return "Select";
    case Tool::Line: return "Line";
    case Tool::Arrow: return "Arrow";
    case Tool::Rect: return "Rectangle";
    case Tool::Ellipse: return "Ellipse";
    case Tool::Text: return "Text";
    case Tool::Laser: return "Laser";
    }
    return "Tool";
}
EOF

# ---------- src/canvas/CanvasWidget.h ----------
cat > src/canvas/CanvasWidget.h << 'EOF'
#pragma once

#include <QWidget>
#include <QElapsedTimer>
#include <QVector>
#include <QPointF>
#include <QtGlobal>
#include "model/Document.h"
#include "Tools.h"

class QTimer;
class QLineEdit;
class QPaintEvent;
class QMouseEvent;
class QTabletEvent;
class QWheelEvent;
class QKeyEvent;

class CanvasWidget : public QWidget
{
    Q_OBJECT
public:
    explicit CanvasWidget(QWidget *parent = nullptr);

    Document     &document();
    Tool          tool() const;
    ToolSettings &settings();

    void setTool(Tool t);
    void setColor(const QColor &c);
    void setWidth(qreal w);
    void setOpacity(qreal o);
    void setFillShapes(bool f);
    void setFontSize(qreal s);

    void undo();
    void redo();
    void clearPage();
    void deleteSelection();
    void selectAll();
    void clearSelection();

    void setBackgroundColor(const QColor &c);
    void setGrid(int gridType);
    void setGridSpacing(qreal s);

    void addPage();
    void nextPage();
    void prevPage();
    void deletePage();

    void zoomIn();
    void zoomOut();
    void resetView();
    void fitToContent();

    void insertImageFromFile();
    void insertImage(const QImage &img);

    bool exportPdf(const QString &path);
    bool exportPng(const QString &path);
    bool exportSvg(const QString &path);
    bool saveDocument(const QString &path);
    bool loadDocument(const QString &path);

    QRectF contentBounds() const;
    void   refresh();

signals:
    void statusChanged(const QString &msg);
    void zoomChanged(int percent);
    void toolChanged(Tool t);
    void pageChanged(int index, int count);
    void documentChanged();

protected:
    void paintEvent(QPaintEvent *) override;
    void mousePressEvent(QMouseEvent *) override;
    void mouseMoveEvent(QMouseEvent *) override;
    void mouseReleaseEvent(QMouseEvent *) override;
    void mouseDoubleClickEvent(QMouseEvent *) override;
    void tabletEvent(QTabletEvent *) override;
    void wheelEvent(QWheelEvent *) override;
    void keyPressEvent(QKeyEvent *) override;
    void keyReleaseEvent(QKeyEvent *) override;

private slots:
    void updateLaser();

private:
    QPointF toCanvas(const QPointF &s) const;
    QPointF toScreen(const QPointF &c) const;

    void pointerPress(const QPointF &c, qreal pressure, bool eraserTip);
    void pointerMove(const QPointF &c, qreal pressure, bool eraserTip, bool buttonDown);
    void pointerRelease(const QPointF &c);

    void beginStroke(const QPointF &c, qreal pressure, bool highlighter);
    void extendStroke(const QPointF &c, qreal pressure);
    void endStroke();

    void beginShape(const QPointF &c);
    void updateShape(const QPointF &c);
    void endShape();

    void eraseAt(const QPointF &c);

    int  hitTest(const QPointF &c) const;
    void updateMarqueeSelection();
    void moveSelection(const QPointF &delta);

    void beginTextEdit(const QPointF &c);
    void commitTextEdit();

    void addLaserPoint(const QPointF &c);

    void drawBackground(QPainter &p, const Page &pg);
    void drawItem(QPainter &p, const Item &it) const;
    void drawSelectionOverlay(QPainter &p);
    void drawLaserTrail(QPainter &p);

    void renderPageToPainter(QPainter &p, const Page &pg);
    Item makeStyledItem(ItemType t) const;

    // model
    Document     m_doc;
    Tool         m_tool = Tool::Pen;
    ToolSettings m_set;

    // view transform
    qreal   m_scale  = 1.0;
    QPointF m_offset = QPointF(40, 40);

    // gesture state
    bool m_hasPreview = false;
    Item m_current;

    bool    m_panning  = false;
    QPointF m_lastPan;
    bool    m_spaceDown = false;

    // selection
    QVector<int> m_selection;
    bool         m_movingSel = false;
    QPointF      m_moveStart;
    bool         m_marquee   = false;
    QPointF      m_marqueeStart;
    QPointF      m_marqueeCur;

    // text editing
    QLineEdit *m_textEditor = nullptr;
    QPointF    m_textPos;

    // laser
    struct LaserPt { QPointF pos; qint64 t; };
    QVector<LaserPt> m_laser;
    QTimer          *m_laserTimer = nullptr;
    QElapsedTimer    m_clock;
    qreal            m_laserFadeMs = 650.0;

    // hover
    bool    m_hover = false;
    QPointF m_hoverPos;
};
EOF

# ---------- src/canvas/CanvasWidget.cpp (part 1; Part 4 appends) ----------
cat > src/canvas/CanvasWidget.cpp << 'EOF'
#include "CanvasWidget.h"

#include <QPainter>
#include <QPainterPath>
#include <QMouseEvent>
#include <QTabletEvent>
#include <QWheelEvent>
#include <QKeyEvent>
#include <QPointingDevice>
#include <QTimer>
#include <QLineEdit>
#include <QLineF>
#include <QFont>
#include <QKeySequence>
#include <QtMath>
#include <cmath>

CanvasWidget::CanvasWidget(QWidget *parent) : QWidget(parent)
{
    setObjectName("Canvas");
    setTabletTracking(true);
    setMouseTracking(true);
    setCursor(Qt::CrossCursor);
    setFocusPolicy(Qt::StrongFocus);
    setAttribute(Qt::WA_OpaquePaintEvent, true);

    m_clock.start();
    m_laserTimer = new QTimer(this);
    m_laserTimer->setInterval(16);
    connect(m_laserTimer, &QTimer::timeout, this, &CanvasWidget::updateLaser);
}

Document &CanvasWidget::document() { return m_doc; }
Tool CanvasWidget::tool() const { return m_tool; }
ToolSettings &CanvasWidget::settings() { return m_set; }

Item CanvasWidget::makeStyledItem(ItemType t) const
{
    Item it;
    it.type       = t;
    it.color      = m_set.color;
    it.width      = m_set.width;
    it.opacity    = m_set.opacity;
    it.filled     = m_set.fillShapes;
    it.fontFamily = m_set.fontFamily;
    it.fontSize   = m_set.fontSize;
    return it;
}

void CanvasWidget::setTool(Tool t)
{
    commitTextEdit();
    if (m_tool == Tool::Select && t != Tool::Select)
        clearSelection();
    m_tool = t;
    setCursor(t == Tool::Select ? Qt::ArrowCursor : Qt::CrossCursor);
    emit toolChanged(t);
    emit statusChanged("Tool: " + toolName(t));
    update();
}

void CanvasWidget::setColor(const QColor &c)
{
    m_set.color = c;
    if (!m_selection.isEmpty()) {
        m_doc.pushUndo();
        Layer &l = m_doc.activeLayer();
        for (int idx : m_selection)
            if (idx >= 0 && idx < l.items.size())
                l.items[idx].color = c;
        update();
        emit documentChanged();
    }
}

void CanvasWidget::setWidth(qreal w)
{
    m_set.width = w;
    if (!m_selection.isEmpty()) {
        m_doc.pushUndo();
        Layer &l = m_doc.activeLayer();
        for (int idx : m_selection)
            if (idx >= 0 && idx < l.items.size())
                l.items[idx].width = w;
        update();
    }
}

void CanvasWidget::setOpacity(qreal o)
{
    m_set.opacity = o;
    if (!m_selection.isEmpty()) {
        m_doc.pushUndo();
        Layer &l = m_doc.activeLayer();
        for (int idx : m_selection)
            if (idx >= 0 && idx < l.items.size())
                l.items[idx].opacity = o;
        update();
    }
}

void CanvasWidget::setFillShapes(bool f) { m_set.fillShapes = f; }
void CanvasWidget::setFontSize(qreal s) { m_set.fontSize = s; }

void CanvasWidget::undo() { if (m_doc.undo()) { clearSelection(); refresh(); } }
void CanvasWidget::redo() { if (m_doc.redo()) { clearSelection(); refresh(); } }
void CanvasWidget::clearPage() { m_doc.clearCurrentPage(); clearSelection(); refresh(); }

void CanvasWidget::setBackgroundColor(const QColor &c)
{
    m_doc.pushUndo();
    m_doc.currentPage().background.color = c;
    update();
}

void CanvasWidget::setGrid(int gridType)
{
    m_doc.pushUndo();
    m_doc.currentPage().background.grid = Background::Grid(gridType);
    update();
}

void CanvasWidget::setGridSpacing(qreal s)
{
    m_doc.currentPage().background.spacing = qMax<qreal>(4.0, s);
    update();
}

void CanvasWidget::addPage() { m_doc.addPage(); clearSelection(); refresh(); }
void CanvasWidget::nextPage()
{
    if (m_doc.currentPageIndex() < m_doc.pageCount() - 1) {
        m_doc.setCurrentPage(m_doc.currentPageIndex() + 1);
        clearSelection(); refresh();
    }
}
void CanvasWidget::prevPage()
{
    if (m_doc.currentPageIndex() > 0) {
        m_doc.setCurrentPage(m_doc.currentPageIndex() - 1);
        clearSelection(); refresh();
    }
}
void CanvasWidget::deletePage() { m_doc.deleteCurrentPage(); clearSelection(); refresh(); }

void CanvasWidget::zoomIn()
{
    QPointF c(width() / 2.0, height() / 2.0);
    QPointF before = toCanvas(c);
    m_scale = qBound(0.05, m_scale * 1.2, 40.0);
    m_offset = c - before * m_scale;
    refresh();
}
void CanvasWidget::zoomOut()
{
    QPointF c(width() / 2.0, height() / 2.0);
    QPointF before = toCanvas(c);
    m_scale = qBound(0.05, m_scale / 1.2, 40.0);
    m_offset = c - before * m_scale;
    refresh();
}
void CanvasWidget::resetView()
{
    m_scale = 1.0;
    m_offset = QPointF(40, 40);
    refresh();
}
void CanvasWidget::fitToContent()
{
    QRectF b = contentBounds();
    if (b.isNull() || b.width() < 1 || b.height() < 1) { resetView(); return; }
    const qreal m = 60.0;
    qreal sx = (width() - 2 * m) / b.width();
    qreal sy = (height() - 2 * m) / b.height();
    m_scale = qBound(0.05, qMin(sx, sy), 40.0);
    QPointF center(width() / 2.0, height() / 2.0);
    m_offset = center - b.center() * m_scale;
    refresh();
}

void CanvasWidget::refresh()
{
    update();
    emit zoomChanged(int(m_scale * 100));
    emit pageChanged(m_doc.currentPageIndex(), m_doc.pageCount());
    emit documentChanged();
}

QRectF CanvasWidget::contentBounds() const
{
    QRectF r;
    const Page &pg = m_doc.currentPage();
    for (const Layer &l : pg.layers) {
        if (!l.visible) continue;
        for (const Item &it : l.items) {
            QRectF b = it.bounds();
            r = r.isNull() ? b : r.united(b);
        }
    }
    return r;
}

QPointF CanvasWidget::toCanvas(const QPointF &s) const { return (s - m_offset) / m_scale; }
QPointF CanvasWidget::toScreen(const QPointF &c) const { return c * m_scale + m_offset; }

// ---------------- rendering ----------------

void CanvasWidget::drawBackground(QPainter &p, const Page &pg)
{
    p.fillRect(rect(), pg.background.color);
    const Background &bg = pg.background;
    if (bg.grid == Background::None)
        return;

    const qreal step = bg.spacing * m_scale;
    if (step < 4.0)
        return;

    qreal ox = std::fmod(m_offset.x(), step);
    if (ox < 0) ox += step;
    qreal oy = std::fmod(m_offset.y(), step);
    if (oy < 0) oy += step;

    if (bg.grid == Background::Dots) {
        p.setPen(Qt::NoPen);
        p.setBrush(bg.gridColor);
        for (qreal x = ox; x < width(); x += step)
            for (qreal y = oy; y < height(); y += step)
                p.drawEllipse(QPointF(x, y), 1.3, 1.3);
    } else {
        QPen pen(bg.gridColor, 1.0);
        p.setPen(pen);
        for (qreal y = oy; y < height(); y += step)
            p.drawLine(QPointF(0, y), QPointF(width(), y));
        if (bg.grid == Background::Squares)
            for (qreal x = ox; x < width(); x += step)
                p.drawLine(QPointF(x, 0), QPointF(x, height()));
    }
}

void CanvasWidget::drawItem(QPainter &p, const Item &it) const
{
    p.save();
    qreal op = it.opacity;
    if (it.highlighter) op *= 0.4;
    p.setOpacity(qBound<qreal>(0.0, op, 1.0));
    const QColor col = it.color;

    switch (it.type) {
    case ItemType::Stroke: {
        if (it.points.isEmpty()) break;
        if (it.highlighter) {
            if (it.points.size() == 1) {
                p.setPen(Qt::NoPen); p.setBrush(col);
                p.drawEllipse(it.points.first().pos, it.width / 2, it.width / 2);
            } else {
                QPainterPath path(it.points.first().pos);
                for (int i = 1; i < it.points.size(); ++i)
                    path.lineTo(it.points[i].pos);
                p.setBrush(Qt::NoBrush);
                p.setPen(QPen(col, it.width, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin));
                p.drawPath(path);
            }
        } else if (it.points.size() == 1) {
            p.setPen(Qt::NoPen); p.setBrush(col);
            qreal r = qMax<qreal>(0.5, it.width * it.points.first().pressure / 2.0);
            p.drawEllipse(it.points.first().pos, r, r);
        } else {
            for (int i = 1; i < it.points.size(); ++i) {
                qreal pr = (it.points[i - 1].pressure + it.points[i].pressure) / 2.0;
                qreal w  = qMax<qreal>(0.5, it.width * pr);
                p.setPen(QPen(col, w, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin));
                p.drawLine(it.points[i - 1].pos, it.points[i].pos);
            }
        }
        break;
    }
    case ItemType::Line:
        p.setPen(QPen(col, it.width, Qt::SolidLine, Qt::RoundCap));
        p.drawLine(it.p1, it.p2);
        break;
    case ItemType::Arrow: {
        p.setPen(QPen(col, it.width, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin));
        p.drawLine(it.p1, it.p2);
        QLineF line(it.p2, it.p1);
        qreal ang = qAtan2(-line.dy(), line.dx());
        qreal ah  = qMax<qreal>(9.0, it.width * 3.0);
        QPointF a1 = it.p2 + QPointF(qCos(ang + M_PI / 6) * ah, -qSin(ang + M_PI / 6) * ah);
        QPointF a2 = it.p2 + QPointF(qCos(ang - M_PI / 6) * ah, -qSin(ang - M_PI / 6) * ah);
        p.drawLine(it.p2, a1);
        p.drawLine(it.p2, a2);
        break;
    }
    case ItemType::Rect: {
        QRectF r = QRectF(it.p1, it.p2).normalized();
        p.setPen(QPen(col, it.width));
        p.setBrush(it.filled ? QBrush(col) : Qt::NoBrush);
        p.drawRect(r);
        break;
    }
    case ItemType::Ellipse: {
        QRectF r = QRectF(it.p1, it.p2).normalized();
        p.setPen(QPen(col, it.width));
        p.setBrush(it.filled ? QBrush(col) : Qt::NoBrush);
        p.drawEllipse(r);
        break;
    }
    case ItemType::Text: {
        QFont f(it.fontFamily);
        f.setPixelSize(qMax(1, int(it.fontSize)));
        p.setFont(f);
        p.setPen(col);
        p.drawText(QRectF(it.p1, QSizeF(6000, 6000)),
                   Qt::AlignLeft | Qt::AlignTop | Qt::TextDontClip, it.text);
        break;
    }
    case ItemType::Image:
        if (!it.image.isNull())
            p.drawImage(QRectF(it.p1, it.p2).normalized(), it.image);
        break;
    }
    p.restore();
}

void CanvasWidget::renderPageToPainter(QPainter &p, const Page &pg)
{
    for (const Layer &l : pg.layers) {
        if (!l.visible) continue;
        for (const Item &it : l.items)
            drawItem(p, it);
    }
}

void CanvasWidget::paintEvent(QPaintEvent *)
{
    QPainter p(this);
    p.setRenderHint(QPainter::Antialiasing, true);
    p.setRenderHint(QPainter::TextAntialiasing, true);
    p.setRenderHint(QPainter::SmoothPixmapTransform, true);

    const Page &pg = m_doc.currentPage();
    drawBackground(p, pg);

    p.save();
    p.translate(m_offset);
    p.scale(m_scale, m_scale);
    renderPageToPainter(p, pg);
    if (m_hasPreview)
        drawItem(p, m_current);
    p.restore();

    drawSelectionOverlay(p);
    drawLaserTrail(p);
}

// ---------------- input ----------------

void CanvasWidget::mousePressEvent(QMouseEvent *e)
{
    if (e->button() == Qt::MiddleButton ||
        (e->button() == Qt::LeftButton && m_spaceDown)) {
        m_panning = true;
        m_lastPan = e->position();
        setCursor(Qt::ClosedHandCursor);
        return;
    }
    if (e->button() != Qt::LeftButton)
        return;
    setFocus();
    pointerPress(toCanvas(e->position()), 1.0, false);
}

void CanvasWidget::mouseMoveEvent(QMouseEvent *e)
{
    m_hover = true;
    m_hoverPos = e->position();
    if (m_panning) {
        m_offset += (e->position() - m_lastPan);
        m_lastPan = e->position();
        update();
        return;
    }
    pointerMove(toCanvas(e->position()), 1.0, false, (e->buttons() & Qt::LeftButton));
    if (m_tool == Tool::Laser)
        update();
}

void CanvasWidget::mouseReleaseEvent(QMouseEvent *e)
{
    if (m_panning && (e->button() == Qt::MiddleButton || e->button() == Qt::LeftButton)) {
        m_panning = false;
        setCursor(m_tool == Tool::Select ? Qt::ArrowCursor : Qt::CrossCursor);
        return;
    }
    if (e->button() != Qt::LeftButton)
        return;
    pointerRelease(toCanvas(e->position()));
}

void CanvasWidget::mouseDoubleClickEvent(QMouseEvent *e)
{
    if (e->button() != Qt::LeftButton)
        return;
    beginTextEdit(toCanvas(e->position()));
}

void CanvasWidget::tabletEvent(QTabletEvent *e)
{
    const QPointF c = toCanvas(e->position());
    qreal pr = e->pressure();
    if (pr <= 0.0) pr = 0.5;
    const bool eraserTip =
        (e->pointerType() == QPointingDevice::PointerType::Eraser);

    switch (e->type()) {
    case QEvent::TabletPress:
        setFocus();
        pointerPress(c, pr, eraserTip);
        break;
    case QEvent::TabletMove:
        m_hover = true;
        m_hoverPos = e->position();
        pointerMove(c, pr, eraserTip, (e->buttons() & Qt::LeftButton));
        break;
    case QEvent::TabletRelease:
        pointerRelease(c);
        break;
    default:
        break;
    }
    e->accept();
}

void CanvasWidget::wheelEvent(QWheelEvent *e)
{
    const double f = (e->angleDelta().y() > 0) ? 1.15 : (1.0 / 1.15);
    QPointF before = toCanvas(e->position());
    m_scale = qBound(0.05, m_scale * f, 40.0);
    m_offset = e->position() - before * m_scale;
    refresh();
}

void CanvasWidget::keyPressEvent(QKeyEvent *e)
{
    if (e->key() == Qt::Key_Space) {
        m_spaceDown = true;
        setCursor(Qt::OpenHandCursor);
    } else if (e->key() == Qt::Key_Delete || e->key() == Qt::Key_Backspace) {
        deleteSelection();
    } else if (e->matches(QKeySequence::Undo)) {
        undo();
    } else if (e->matches(QKeySequence::Redo)) {
        redo();
    } else if (e->matches(QKeySequence::SelectAll)) {
        selectAll();
    } else if (e->key() == Qt::Key_Escape) {
        clearSelection();
        commitTextEdit();
        update();
    } else {
        QWidget::keyPressEvent(e);
    }
}

void CanvasWidget::keyReleaseEvent(QKeyEvent *e)
{
    if (e->key() == Qt::Key_Space) {
        m_spaceDown = false;
        setCursor(m_tool == Tool::Select ? Qt::ArrowCursor : Qt::CrossCursor);
    } else {
        QWidget::keyReleaseEvent(e);
    }
}

void CanvasWidget::pointerPress(const QPointF &c, qreal pr, bool eraserTip)
{
    if (eraserTip) {
        m_doc.pushUndo();
        eraseAt(c);
        update();
        return;
    }
    switch (m_tool) {
    case Tool::Pen:         beginStroke(c, pr, false); break;
    case Tool::Highlighter: beginStroke(c, pr, true);  break;
    case Tool::Eraser:      m_doc.pushUndo(); eraseAt(c); break;
    case Tool::Line:
    case Tool::Arrow:
    case Tool::Rect:
    case Tool::Ellipse:     beginShape(c); break;
    case Tool::Text:        beginTextEdit(c); break;
    case Tool::Laser:       addLaserPoint(c); break;
    case Tool::Select: {
        int hit = hitTest(c);
        if (hit >= 0) {
            if (!m_selection.contains(hit)) {
                m_selection.clear();
                m_selection.push_back(hit);
            }
            m_movingSel = true;
            m_moveStart = c;
        } else {
            m_selection.clear();
            m_marquee = true;
            m_marqueeStart = c;
            m_marqueeCur = c;
        }
        break;
    }
    }
    update();
}

void CanvasWidget::pointerMove(const QPointF &c, qreal pr, bool eraserTip, bool down)
{
    if (eraserTip) {
        if (down) { eraseAt(c); update(); }
        return;
    }
    switch (m_tool) {
    case Tool::Pen:
    case Tool::Highlighter:
        if (m_hasPreview && down) { extendStroke(c, pr); update(); }
        break;
    case Tool::Eraser:
        if (down) { eraseAt(c); update(); }
        break;
    case Tool::Line:
    case Tool::Arrow:
    case Tool::Rect:
    case Tool::Ellipse:
        if (m_hasPreview) { updateShape(c); update(); }
        break;
    case Tool::Laser:
        if (down) addLaserPoint(c);
        update();
        break;
    case Tool::Select:
        if (m_movingSel && down) {
            moveSelection(c - m_moveStart);
            m_moveStart = c;
            update();
        } else if (m_marquee && down) {
            m_marqueeCur = c;
            updateMarqueeSelection();
            update();
        }
        break;
    default:
        break;
    }
}

void CanvasWidget::pointerRelease(const QPointF &c)
{
    Q_UNUSED(c);
    switch (m_tool) {
    case Tool::Pen:
    case Tool::Highlighter: endStroke(); break;
    case Tool::Line:
    case Tool::Arrow:
    case Tool::Rect:
    case Tool::Ellipse:     endShape(); break;
    case Tool::Select:      m_movingSel = false; m_marquee = false; break;
    default: break;
    }
    update();
    emit documentChanged();
}

// ---------------- freehand ----------------

void CanvasWidget::beginStroke(const QPointF &c, qreal pr, bool hl)
{
    m_current = makeStyledItem(ItemType::Stroke);
    m_current.highlighter = hl;
    m_current.points.push_back({c, pr});
    m_hasPreview = true;
}

void CanvasWidget::extendStroke(const QPointF &c, qreal pr)
{
    if (!m_hasPreview) return;
    const QPointF last = m_current.points.last().pos;
    const qreal minD = 1.0 / m_scale;
    if (QLineF(last, c).length() < minD) {
        m_current.points.last().pressure = pr;
        return;
    }
    m_current.points.push_back({c, pr});
}

void CanvasWidget::endStroke()
{
    if (!m_hasPreview) return;
    m_hasPreview = false;
    if (!m_current.points.isEmpty())
        m_doc.addItem(m_current);
    m_current = Item();
}

// ---------------- eraser ----------------

void CanvasWidget::eraseAt(const QPointF &c)
{
    const qreal radius = qMax<qreal>(6.0, m_set.width * 2.0);
    Layer &l = m_doc.activeLayer();
    for (int i = l.items.size() - 1; i >= 0; --i) {
        const Item &it = l.items[i];
        bool hit = false;
        if (it.type == ItemType::Stroke) {
            for (const auto &pt : it.points)
                if (QLineF(pt.pos, c).length() <= radius + it.width / 2.0) { hit = true; break; }
        } else {
            if (it.bounds().adjusted(-radius, -radius, radius, radius).contains(c))
                hit = true;
        }
        if (hit)
            l.items.removeAt(i);
    }
}
EOF

echo ">> Part 3 done. (Part 4 appends shapes/select/text/laser/export to this same .cpp.)"


#!/usr/bin/env bash
set -euo pipefail
echo ">> Part 4: shapes, selection, text, laser, image, export/save (appended to CanvasWidget.cpp)"

cat >> src/canvas/CanvasWidget.cpp << 'EOF'

// ================= Part 4: appended implementations =================

#include <QFileDialog>
#include <QMessageBox>
#include <QImage>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPdfWriter>
#include <QPageSize>
#include <QPageLayout>
#include <QMarginsF>
#include <QSvgGenerator>
#include <algorithm>

namespace { bool g_moveUndoPushed = false; }

// ---------------- shapes ----------------

void CanvasWidget::beginShape(const QPointF &c)
{
    ItemType t = ItemType::Line;
    switch (m_tool) {
    case Tool::Line:    t = ItemType::Line;    break;
    case Tool::Arrow:   t = ItemType::Arrow;   break;
    case Tool::Rect:    t = ItemType::Rect;    break;
    case Tool::Ellipse: t = ItemType::Ellipse; break;
    default: break;
    }
    m_current = makeStyledItem(t);
    m_current.p1 = c;
    m_current.p2 = c;
    m_hasPreview = true;
}

void CanvasWidget::updateShape(const QPointF &c)
{
    if (!m_hasPreview) return;
    m_current.p2 = c;
}

void CanvasWidget::endShape()
{
    if (!m_hasPreview) return;
    m_hasPreview = false;
    if (QLineF(m_current.p1, m_current.p2).length() >= 1.0)
        m_doc.addItem(m_current);
    m_current = Item();
}

// ---------------- selection ----------------

int CanvasWidget::hitTest(const QPointF &c) const
{
    g_moveUndoPushed = false; // reset per selection press
    const Layer &l = m_doc.activeLayer();
    const qreal tol = qMax<qreal>(6.0, 8.0 / m_scale);

    for (int i = l.items.size() - 1; i >= 0; --i) {
        const Item &it = l.items[i];
        if (it.type == ItemType::Stroke) {
            for (const auto &p : it.points)
                if (QLineF(p.pos, c).length() <= tol + it.width / 2.0)
                    return i;
        } else if (it.type == ItemType::Line || it.type == ItemType::Arrow) {
            const QPointF d = it.p2 - it.p1;
            const qreal len2 = QPointF::dotProduct(d, d);
            if (len2 < 1e-6) {
                if (QLineF(it.p1, c).length() <= tol) return i;
                continue;
            }
            qreal t = QPointF::dotProduct(c - it.p1, d) / len2;
            t = qBound<qreal>(0.0, t, 1.0);
            QPointF proj = it.p1 + t * d;
            if (QLineF(proj, c).length() <= tol + it.width / 2.0)
                return i;
        } else {
            if (it.bounds().contains(c))
                return i;
        }
    }
    return -1;
}

void CanvasWidget::updateMarqueeSelection()
{
    const QRectF r = QRectF(m_marqueeStart, m_marqueeCur).normalized();
    m_selection.clear();
    const Layer &l = m_doc.activeLayer();
    for (int i = 0; i < l.items.size(); ++i)
        if (r.intersects(l.items[i].bounds()))
            m_selection.push_back(i);
}

void CanvasWidget::moveSelection(const QPointF &delta)
{
    if (m_selection.isEmpty()) return;
    if (!g_moveUndoPushed) {
        m_doc.pushUndo();
        g_moveUndoPushed = true;
    }
    Layer &l = m_doc.activeLayer();
    for (int idx : m_selection) {
        if (idx < 0 || idx >= l.items.size()) continue;
        Item &it = l.items[idx];
        if (it.type == ItemType::Stroke) {
            for (auto &p : it.points) p.pos += delta;
        } else {
            it.p1 += delta;
            it.p2 += delta;
        }
    }
}

void CanvasWidget::deleteSelection()
{
    if (m_selection.isEmpty()) return;
    m_doc.pushUndo();
    Layer &l = m_doc.activeLayer();
    std::sort(m_selection.begin(), m_selection.end());
    for (int i = m_selection.size() - 1; i >= 0; --i) {
        int idx = m_selection[i];
        if (idx >= 0 && idx < l.items.size())
            l.items.removeAt(idx);
    }
    m_selection.clear();
    update();
    emit documentChanged();
}

void CanvasWidget::selectAll()
{
    m_selection.clear();
    const Layer &l = m_doc.activeLayer();
    for (int i = 0; i < l.items.size(); ++i)
        m_selection.push_back(i);
    if (m_tool != Tool::Select)
        setTool(Tool::Select);
    update();
}

void CanvasWidget::clearSelection()
{
    if (!m_selection.isEmpty()) {
        m_selection.clear();
        update();
    }
    m_movingSel = false;
    m_marquee = false;
}

void CanvasWidget::drawSelectionOverlay(QPainter &p)
{
    p.save();
    if (m_marquee) {
        QRectF r = QRectF(toScreen(m_marqueeStart), toScreen(m_marqueeCur)).normalized();
        QColor fill("#7c5cff");
        fill.setAlphaF(0.12);
        p.setBrush(fill);
        p.setPen(QPen(QColor("#7c5cff"), 1.0, Qt::DashLine));
        p.drawRect(r);
    }
    if (!m_selection.isEmpty()) {
        const Layer &l = m_doc.activeLayer();
        p.setBrush(Qt::NoBrush);
        p.setPen(QPen(QColor("#7c5cff"), 1.2, Qt::DashLine));
        for (int idx : m_selection) {
            if (idx < 0 || idx >= l.items.size()) continue;
            QRectF b = l.items[idx].bounds();
            QRectF sb = QRectF(toScreen(b.topLeft()), toScreen(b.bottomRight())).normalized();
            p.drawRect(sb.adjusted(-2, -2, 2, 2));
        }
    }
    p.restore();
}

// ---------------- text ----------------

void CanvasWidget::beginTextEdit(const QPointF &c)
{
    commitTextEdit();
    m_textPos = c;
    m_textEditor = new QLineEdit(this);
    m_textEditor->setStyleSheet(
        "QLineEdit{background:rgba(124,92,255,0.08);border:1px dashed #7c5cff;color:" +
        m_set.color.name() + ";padding:2px;}");
    QFont f(m_set.fontFamily);
    f.setPixelSize(qMax(1, int(m_set.fontSize * m_scale)));
    m_textEditor->setFont(f);
    QPointF sp = toScreen(c);
    m_textEditor->move(int(sp.x()), int(sp.y()));
    m_textEditor->resize(320, int(m_set.fontSize * m_scale * 1.7) + 6);
    m_textEditor->show();
    m_textEditor->setFocus();
    connect(m_textEditor, &QLineEdit::returnPressed, this, &CanvasWidget::commitTextEdit);
    connect(m_textEditor, &QLineEdit::editingFinished, this, &CanvasWidget::commitTextEdit);
}

void CanvasWidget::commitTextEdit()
{
    if (!m_textEditor) return;
    QLineEdit *ed = m_textEditor;
    m_textEditor = nullptr; // guard against re-entry from editingFinished
    const QString text = ed->text();
    ed->hide();
    ed->deleteLater();
    if (!text.trimmed().isEmpty()) {
        Item it = makeStyledItem(ItemType::Text);
        it.text = text;
        it.p1 = m_textPos;
        m_doc.addItem(it);
        update();
        emit documentChanged();
    }
}

// ---------------- laser ----------------

void CanvasWidget::addLaserPoint(const QPointF &c)
{
    m_laser.push_back({c, m_clock.elapsed()});
    if (m_laser.size() > 512)
        m_laser.removeFirst();
    if (!m_laserTimer->isActive())
        m_laserTimer->start();
    update();
}

void CanvasWidget::updateLaser()
{
    const qint64 now = m_clock.elapsed();
    while (!m_laser.isEmpty() && (now - m_laser.first().t) > qint64(m_laserFadeMs))
        m_laser.removeFirst();
    if (m_laser.isEmpty())
        m_laserTimer->stop();
    update();
}

void CanvasWidget::drawLaserTrail(QPainter &p)
{
    if (m_laser.isEmpty()) return;
    const qint64 now = m_clock.elapsed();
    p.save();
    p.setRenderHint(QPainter::Antialiasing, true);
    for (int i = 1; i < m_laser.size(); ++i) {
        qreal age = qreal(now - m_laser[i].t);
        qreal a = qBound<qreal>(0.0, 1.0 - age / m_laserFadeMs, 1.0);
        if (a <= 0.0) continue;
        QColor c = m_set.color;
        c.setAlphaF(a);
        qreal w = qMax<qreal>(3.0, m_set.width) * (0.5 + 0.5 * a);
        p.setPen(QPen(c, w, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin));
        p.drawLine(toScreen(m_laser[i - 1].pos), toScreen(m_laser[i].pos));
    }
    qreal a = qBound<qreal>(0.0, 1.0 - qreal(now - m_laser.last().t) / m_laserFadeMs, 1.0);
    QColor head = m_set.color;
    head.setAlphaF(a);
    p.setPen(Qt::NoPen);
    p.setBrush(head);
    qreal r = qMax<qreal>(5.0, m_set.width) * 1.4;
    p.drawEllipse(toScreen(m_laser.last().pos), r, r);
    p.restore();
}

// ---------------- image ----------------

void CanvasWidget::insertImageFromFile()
{
    const QString path = QFileDialog::getOpenFileName(
        this, "Insert Image", QString(),
        "Images (*.png *.jpg *.jpeg *.bmp *.gif)");
    if (path.isEmpty()) return;
    QImage img(path);
    if (img.isNull()) {
        QMessageBox::warning(this, "Insert Image", "Could not load that image.");
        return;
    }
    insertImage(img);
}

void CanvasWidget::insertImage(const QImage &img)
{
    if (img.isNull()) return;
    QPointF center = toCanvas(QPointF(width() / 2.0, height() / 2.0));
    const qreal maxW = 600.0;
    qreal s = (img.width() > maxW) ? (maxW / img.width()) : 1.0;
    QSizeF sz(img.width() * s, img.height() * s);
    Item it = makeStyledItem(ItemType::Image);
    it.image = img;
    it.p1 = center - QPointF(sz.width() / 2, sz.height() / 2);
    it.p2 = it.p1 + QPointF(sz.width(), sz.height());
    m_doc.addItem(it);
    setTool(Tool::Select);
    refresh();
}

// ---------------- export ----------------

bool CanvasWidget::exportPdf(const QString &path)
{
    QPdfWriter writer(path);
    writer.setPageSize(QPageSize(QPageSize::A4));
    writer.setResolution(300);
    writer.setPageMargins(QMarginsF(10, 10, 10, 10), QPageLayout::Millimeter);

    QPainter painter(&writer);
    if (!painter.isActive()) return false;
    painter.setRenderHint(QPainter::Antialiasing, true);
    painter.setRenderHint(QPainter::TextAntialiasing, true);

    const int saved = m_doc.currentPageIndex();
    const int n = m_doc.pageCount();
    const QRectF page(0, 0, writer.width(), writer.height());

    for (int i = 0; i < n; ++i) {
        if (i > 0) writer.newPage();
        m_doc.setCurrentPage(i);
        const Page &pg = m_doc.currentPage();

        QRectF content;
        for (const Layer &l : pg.layers) {
            if (!l.visible) continue;
            for (const Item &it : l.items) {
                QRectF b = it.bounds();
                content = content.isNull() ? b : content.united(b);
            }
        }

        painter.save();
        painter.fillRect(page, pg.background.color);
        if (!content.isNull() && content.width() > 0 && content.height() > 0) {
            qreal s = qMin(page.width() / content.width(),
                           page.height() / content.height());
            painter.translate(page.center());
            painter.scale(s, s);
            painter.translate(-content.center());
            for (const Layer &l : pg.layers) {
                if (!l.visible) continue;
                for (const Item &it : l.items)
                    drawItem(painter, it);
            }
        }
        painter.restore();
    }

    m_doc.setCurrentPage(saved);
    painter.end();
    return true;
}

bool CanvasWidget::exportPng(const QString &path)
{
    const Page &pg = m_doc.currentPage();
    QRectF content = contentBounds();
    if (content.isNull()) content = QRectF(0, 0, 400, 300);

    const int margin = 24;
    const qreal scale = 2.0;
    QSize sz(int((content.width() + 2 * margin) * scale),
             int((content.height() + 2 * margin) * scale));
    if (sz.width() <= 0 || sz.height() <= 0) return false;

    QImage img(sz, QImage::Format_ARGB32_Premultiplied);
    img.fill(pg.background.color);
    QPainter p(&img);
    p.setRenderHint(QPainter::Antialiasing, true);
    p.setRenderHint(QPainter::TextAntialiasing, true);
    p.scale(scale, scale);
    p.translate(margin - content.left(), margin - content.top());
    for (const Layer &l : pg.layers) {
        if (!l.visible) continue;
        for (const Item &it : l.items)
            drawItem(p, it);
    }
    p.end();
    return img.save(path, "PNG");
}

bool CanvasWidget::exportSvg(const QString &path)
{
    const Page &pg = m_doc.currentPage();
    QRectF content = contentBounds();
    if (content.isNull()) content = QRectF(0, 0, 400, 300);

    const int margin = 24;
    const QSize sz(int(content.width() + 2 * margin),
                   int(content.height() + 2 * margin));

    QSvgGenerator gen;
    gen.setFileName(path);
    gen.setSize(sz);
    gen.setViewBox(QRectF(0, 0, sz.width(), sz.height()));
    gen.setTitle("Whiteboard");

    QPainter p(&gen);
    if (!p.isActive()) return false;
    p.setRenderHint(QPainter::Antialiasing, true);
    p.translate(margin - content.left(), margin - content.top());
    for (const Layer &l : pg.layers) {
        if (!l.visible) continue;
        for (const Item &it : l.items)
            drawItem(p, it);
    }
    p.end();
    return true;
}

// ---------------- persistence ----------------

bool CanvasWidget::saveDocument(const QString &path)
{
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly)) return false;
    f.write(QJsonDocument(m_doc.toJson()).toJson(QJsonDocument::Compact));
    return true;
}

bool CanvasWidget::loadDocument(const QString &path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) return false;
    const QJsonDocument d = QJsonDocument::fromJson(f.readAll());
    if (!d.isObject()) return false;
    if (!m_doc.fromJson(d.object())) return false;
    clearSelection();
    resetView();
    refresh();
    return true;
}
EOF

echo ">> Part 4 done. CanvasWidget is now complete. (Needs Part 5 UI to compile/link the app.)"

#!/usr/bin/env bash
set -euo pipefail
echo ">> Part 5: modern UI shell (ColorButton + MainWindow)"

mkdir -p src/ui

# ---------------- ColorButton.h ----------------
cat > src/ui/ColorButton.h << 'EOF'
#pragma once
#include <QToolButton>
#include <QColor>

class ColorButton : public QToolButton
{
    Q_OBJECT
public:
    explicit ColorButton(const QColor &c, QWidget *parent = nullptr);
    QColor color() const { return m_color; }
    void setColor(const QColor &c);
    void setSelected(bool s);

signals:
    void picked(const QColor &c);

protected:
    void paintEvent(QPaintEvent *) override;

private:
    QColor m_color;
    bool m_selected = false;
};
EOF

# ---------------- ColorButton.cpp ----------------
cat > src/ui/ColorButton.cpp << 'EOF'
#include "ui/ColorButton.h"
#include <QPainter>
#include <QPaintEvent>

ColorButton::ColorButton(const QColor &c, QWidget *parent)
    : QToolButton(parent), m_color(c)
{
    setCheckable(false);
    setCursor(Qt::PointingHandCursor);
    setFixedSize(26, 26);
    setToolTip(c.name());
    connect(this, &QToolButton::clicked, this, [this]() { emit picked(m_color); });
}

void ColorButton::setColor(const QColor &c)
{
    m_color = c;
    setToolTip(c.name());
    update();
}

void ColorButton::setSelected(bool s)
{
    if (m_selected == s) return;
    m_selected = s;
    update();
}

void ColorButton::paintEvent(QPaintEvent *)
{
    QPainter p(this);
    p.setRenderHint(QPainter::Antialiasing, true);
    QRectF r = rect().adjusted(3, 3, -3, -3);

    if (m_selected) {
        QPen ring(QColor("#7c5cff"), 2.0);
        p.setPen(ring);
        p.setBrush(Qt::NoBrush);
        p.drawEllipse(rect().adjusted(1, 1, -1, -1));
    }

    p.setPen(QPen(QColor(0, 0, 0, 60), 1.0));
    p.setBrush(m_color);
    p.drawEllipse(r);

    // subtle check for white/very light swatches
    if (m_color.lightnessF() > 0.85) {
        p.setPen(QPen(QColor(0, 0, 0, 40), 1.0));
        p.setBrush(Qt::NoBrush);
        p.drawEllipse(r);
    }
}
EOF

# ---------------- MainWindow.h ----------------
cat > src/ui/MainWindow.h << 'EOF'
#pragma once
#include <QMainWindow>
#include "canvas/Tools.h"

class CanvasWidget;
class ColorButton;
class QLabel;
class QSlider;
class QToolButton;
class QButtonGroup;
class QCheckBox;
class QComboBox;
class QSpinBox;

class MainWindow : public QMainWindow
{
    Q_OBJECT
public:
    explicit MainWindow(QWidget *parent = nullptr);

private slots:
    void onNew();
    void onOpen();
    void onSave();
    void onExportPdf();
    void onExportPng();
    void onExportSvg();
    void onInsertImage();
    void onToolChanged(Tool t);
    void onZoomChanged(int pct);
    void onStatus(const QString &msg);
    void onPageChanged(int current, int total);
    void onToggleTheme();
    void onTogglePresent();

private:
    QWidget *buildToolRail();
    QWidget *buildPropertyPanel();
    void buildTopBar();
    void selectToolButton(Tool t);
    QToolButton *addToolButton(QButtonGroup *grp, const QString &glyph,
                               const QString &tip, Tool tool, const QString &sc);

    CanvasWidget *m_canvas = nullptr;
    QButtonGroup *m_toolGroup = nullptr;

    QSlider *m_width = nullptr;
    QLabel  *m_widthLbl = nullptr;
    QSlider *m_opacity = nullptr;
    QLabel  *m_opacityLbl = nullptr;
    QCheckBox *m_fill = nullptr;
    QSpinBox  *m_font = nullptr;
    QComboBox *m_grid = nullptr;
    QSpinBox  *m_gridSpacing = nullptr;

    QLabel *m_pageLbl = nullptr;
    QLabel *m_zoomLbl = nullptr;
    QLabel *m_status = nullptr;

    bool m_dark = true;
    bool m_present = false;
    QWidget *m_toolRail = nullptr;
    QWidget *m_panel = nullptr;
};
EOF

# ---------------- MainWindow.cpp ----------------
cat > src/ui/MainWindow.cpp << 'EOF'
#include "ui/MainWindow.h"
#include "ui/ColorButton.h"
#include "canvas/CanvasWidget.h"
#include "model/Item.h"
#include "Theme.h"

#include <QApplication>
#include <QToolBar>
#include <QAction>
#include <QStatusBar>
#include <QLabel>
#include <QSlider>
#include <QSpinBox>
#include <QCheckBox>
#include <QComboBox>
#include <QToolButton>
#include <QButtonGroup>
#include <QFrame>
#include <QScrollArea>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QGridLayout>
#include <QFileDialog>
#include <QColorDialog>
#include <QMessageBox>
#include <QFileInfo>

static QLabel *sectionHeader(const QString &text)
{
    auto *l = new QLabel(text);
    l->setObjectName("PanelHeader");
    return l;
}

MainWindow::MainWindow(QWidget *parent) : QMainWindow(parent)
{
    setWindowTitle("Whiteboard");

    m_canvas = new CanvasWidget(this);

    auto *central = new QWidget(this);
    central->setObjectName("Root");
    auto *row = new QHBoxLayout(central);
    row->setContentsMargins(0, 0, 0, 0);
    row->setSpacing(0);

    m_toolRail = buildToolRail();
    m_panel = buildPropertyPanel();

    row->addWidget(m_toolRail);
    row->addWidget(m_canvas, 1);
    row->addWidget(m_panel);
    setCentralWidget(central);

    buildTopBar();

    m_status = new QLabel("Ready");
    m_zoomLbl = new QLabel("100%");
    m_pageLbl = new QLabel("Page 1 / 1");
    statusBar()->addWidget(m_status, 1);
    statusBar()->addPermanentWidget(m_pageLbl);
    statusBar()->addPermanentWidget(m_zoomLbl);

    connect(m_canvas, &CanvasWidget::statusChanged, this, &MainWindow::onStatus);
    connect(m_canvas, &CanvasWidget::zoomChanged,   this, &MainWindow::onZoomChanged);
    connect(m_canvas, &CanvasWidget::toolChanged,   this, &MainWindow::onToolChanged);
    connect(m_canvas, &CanvasWidget::pageChanged,   this, &MainWindow::onPageChanged);

    selectToolButton(Tool::Pen);
    m_canvas->setFocus();
}

// ---------------- tool rail ----------------

QToolButton *MainWindow::addToolButton(QButtonGroup *grp, const QString &glyph,
                                       const QString &tip, Tool tool, const QString &sc)
{
    auto *b = new QToolButton;
    b->setText(glyph);
    b->setCheckable(true);
    b->setAutoRaise(true);
    b->setFixedSize(44, 44);
    b->setCursor(Qt::PointingHandCursor);
    b->setToolTip(sc.isEmpty() ? tip : QString("%1  (%2)").arg(tip, sc));
    QFont f = b->font();
    f.setPointSize(15);
    b->setFont(f);
    grp->addButton(b, int(tool));
    if (!sc.isEmpty()) {
        auto *a = new QAction(this);
        a->setShortcut(QKeySequence(sc));
        connect(a, &QAction::triggered, this, [this, tool]() { m_canvas->setTool(tool); });
        addAction(a);
    }
    return b;
}

QWidget *MainWindow::buildToolRail()
{
    auto *rail = new QFrame;
    rail->setObjectName("ToolRail");
    rail->setFixedWidth(60);
    auto *v = new QVBoxLayout(rail);
    v->setContentsMargins(8, 12, 8, 12);
    v->setSpacing(6);

    m_toolGroup = new QButtonGroup(this);
    m_toolGroup->setExclusive(true);

    v->addWidget(addToolButton(m_toolGroup, "\u270E", "Pen",        Tool::Pen,        "P"));
    v->addWidget(addToolButton(m_toolGroup, "\u2015", "Highlighter",Tool::Highlighter,"H"));
    v->addWidget(addToolButton(m_toolGroup, "\u232B", "Eraser",     Tool::Eraser,     "E"));
    v->addWidget(addToolButton(m_toolGroup, "\u21F1", "Select",     Tool::Select,     "V"));

    auto *sep1 = new QFrame; sep1->setFrameShape(QFrame::HLine); sep1->setObjectName("RailSep");
    v->addWidget(sep1);

    v->addWidget(addToolButton(m_toolGroup, "\u2571", "Line",       Tool::Line,       "L"));
    v->addWidget(addToolButton(m_toolGroup, "\u2192", "Arrow",      Tool::Arrow,      "A"));
    v->addWidget(addToolButton(m_toolGroup, "\u25AD", "Rectangle",  Tool::Rect,       "R"));
    v->addWidget(addToolButton(m_toolGroup, "\u25EF", "Ellipse",    Tool::Ellipse,    "O"));
    v->addWidget(addToolButton(m_toolGroup, "T",       "Text",      Tool::Text,       "T"));
    v->addWidget(addToolButton(m_toolGroup, "\u2727", "Laser",      Tool::Laser,      "X"));

    connect(m_toolGroup, &QButtonGroup::idClicked, this,
            [this](int id) { m_canvas->setTool(Tool(id)); });

    v->addStretch(1);

    auto *img = new QToolButton;
    img->setText("\u1F5BC");
    img->setAutoRaise(true);
    img->setFixedSize(44, 44);
    img->setToolTip("Insert Image  (I)");
    img->setCursor(Qt::PointingHandCursor);
    connect(img, &QToolButton::clicked, this, &MainWindow::onInsertImage);
    v->addWidget(img);

    auto *imgAct = new QAction(this);
    imgAct->setShortcut(QKeySequence("I"));
    connect(imgAct, &QAction::triggered, this, &MainWindow::onInsertImage);
    addAction(imgAct);

    return rail;
}

// ---------------- property panel ----------------

QWidget *MainWindow::buildPropertyPanel()
{
    auto *scroll = new QScrollArea;
    scroll->setObjectName("PropertyScroll");
    scroll->setWidgetResizable(true);
    scroll->setHorizontalScrollBarPolicy(Qt::ScrollBarAlwaysOff);
    scroll->setFixedWidth(240);

    auto *panel = new QFrame;
    panel->setObjectName("PropertyPanel");
    auto *v = new QVBoxLayout(panel);
    v->setContentsMargins(14, 14, 14, 14);
    v->setSpacing(10);

    // ---- Color ----
    v->addWidget(sectionHeader("Color"));
    auto *palette = new QGridLayout;
    palette->setSpacing(6);
    const QStringList cols = {
        "#e6e6f0", "#ffffff", "#ff3b30", "#ff9500", "#ffcc00",
        "#34c759", "#00c7be", "#0a84ff", "#5e5ce6", "#bf5af2",
        "#ff2d92", "#8e8e93", "#000000"};
    QList<ColorButton *> swatches;
    int r = 0, c = 0;
    for (const QString &name : cols) {
        auto *sw = new ColorButton(QColor(name));
        swatches.append(sw);
        connect(sw, &ColorButton::picked, this, [this, swatches](const QColor &col) {
            m_canvas->setColor(col);
            for (auto *s : swatches) s->setSelected(s->color() == col);
        });
        palette->addWidget(sw, r, c);
        if (++c >= 6) { c = 0; ++r; }
    }
    v->addLayout(palette);
    if (!swatches.isEmpty()) swatches.first()->setSelected(true);

    auto *custom = new QToolButton;
    custom->setText("Custom color\u2026");
    custom->setCursor(Qt::PointingHandCursor);
    connect(custom, &QToolButton::clicked, this, [this, swatches]() {
        QColor col = QColorDialog::getColor(Qt::white, this, "Pick a color");
        if (col.isValid()) {
            m_canvas->setColor(col);
            for (auto *s : swatches) s->setSelected(false);
        }
    });
    v->addWidget(custom);

    // ---- Width ----
    v->addWidget(sectionHeader("Width"));
    auto *wrow = new QHBoxLayout;
    m_width = new QSlider(Qt::Horizontal);
    m_width->setRange(1, 40);
    m_width->setValue(3);
    m_widthLbl = new QLabel("3 px");
    m_widthLbl->setFixedWidth(42);
    connect(m_width, &QSlider::valueChanged, this, [this](int v) {
        m_canvas->setWidth(v);
        m_widthLbl->setText(QString("%1 px").arg(v));
    });
    wrow->addWidget(m_width, 1);
    wrow->addWidget(m_widthLbl);
    v->addLayout(wrow);

    // ---- Opacity ----
    v->addWidget(sectionHeader("Opacity"));
    auto *orow = new QHBoxLayout;
    m_opacity = new QSlider(Qt::Horizontal);
    m_opacity->setRange(10, 100);
    m_opacity->setValue(100);
    m_opacityLbl = new QLabel("100%");
    m_opacityLbl->setFixedWidth(42);
    connect(m_opacity, &QSlider::valueChanged, this, [this](int v) {
        m_canvas->setOpacity(v / 100.0);
        m_opacityLbl->setText(QString("%1%").arg(v));
    });
    orow->addWidget(m_opacity, 1);
    orow->addWidget(m_opacityLbl);
    v->addLayout(orow);

    // ---- Shape / Text ----
    m_fill = new QCheckBox("Fill shapes");
    connect(m_fill, &QCheckBox::toggled, this, [this](bool on) { m_canvas->setFillShapes(on); });
    v->addWidget(m_fill);

    auto *frow = new QHBoxLayout;
    frow->addWidget(new QLabel("Font size"));
    m_font = new QSpinBox;
    m_font->setRange(8, 200);
    m_font->setValue(28);
    connect(m_font, qOverload<int>(&QSpinBox::valueChanged), this,
            [this](int v) { m_canvas->setFontSize(v); });
    frow->addWidget(m_font, 1);
    v->addLayout(frow);

    // ---- Background ----
    v->addWidget(sectionHeader("Background"));
    auto *bgColor = new QToolButton;
    bgColor->setText("Background color\u2026");
    bgColor->setCursor(Qt::PointingHandCursor);
    connect(bgColor, &QToolButton::clicked, this, [this]() {
        QColor col = QColorDialog::getColor(Qt::white, this, "Background color");
        if (col.isValid()) m_canvas->setBackgroundColor(col);
    });
    v->addWidget(bgColor);

    auto *grow = new QHBoxLayout;
    grow->addWidget(new QLabel("Grid"));
    m_grid = new QComboBox;
    m_grid->addItems({"None", "Lines", "Dots", "Squares"});
    connect(m_grid, qOverload<int>(&QComboBox::currentIndexChanged), this,
            [this](int i) { m_canvas->setGrid(Background::Grid(i)); });
    grow->addWidget(m_grid, 1);
    v->addLayout(grow);

    auto *gsrow = new QHBoxLayout;
    gsrow->addWidget(new QLabel("Spacing"));
    m_gridSpacing = new QSpinBox;
    m_gridSpacing->setRange(8, 200);
    m_gridSpacing->setValue(32);
    m_gridSpacing->setSuffix(" px");
    connect(m_gridSpacing, qOverload<int>(&QSpinBox::valueChanged), this,
            [this](int v) { m_canvas->setGridSpacing(v); });
    gsrow->addWidget(m_gridSpacing, 1);
    v->addLayout(gsrow);

    // ---- Pages ----
    v->addWidget(sectionHeader("Pages"));
    auto *prow = new QHBoxLayout;
    auto *prev = new QToolButton; prev->setText("\u2039"); prev->setToolTip("Previous page");
    auto *next = new QToolButton; next->setText("\u203A"); next->setToolTip("Next page");
    auto *add  = new QToolButton; add->setText("+");        add->setToolTip("Add page");
    auto *del  = new QToolButton; del->setText("\u2212");   del->setToolTip("Delete page");
    connect(prev, &QToolButton::clicked, this, [this]() { m_canvas->prevPage(); });
    connect(next, &QToolButton::clicked, this, [this]() { m_canvas->nextPage(); });
    connect(add,  &QToolButton::clicked, this, [this]() { m_canvas->addPage(); });
    connect(del,  &QToolButton::clicked, this, [this]() { m_canvas->deleteCurrentPage(); });
    prow->addWidget(prev); prow->addWidget(next);
    prow->addStretch(1);
    prow->addWidget(add); prow->addWidget(del);
    v->addLayout(prow);

    // ---- View ----
    v->addWidget(sectionHeader("View"));
    auto *vrow = new QHBoxLayout;
    auto *zin  = new QToolButton; zin->setText("+");  zin->setToolTip("Zoom in");
    auto *zout = new QToolButton; zout->setText("\u2212"); zout->setToolTip("Zoom out");
    auto *zrst = new QToolButton; zrst->setText("100%"); zrst->setToolTip("Reset zoom");
    auto *zfit = new QToolButton; zfit->setText("Fit"); zfit->setToolTip("Fit to content");
    connect(zin,  &QToolButton::clicked, this, [this]() { m_canvas->zoomIn(); });
    connect(zout, &QToolButton::clicked, this, [this]() { m_canvas->zoomOut(); });
    connect(zrst, &QToolButton::clicked, this, [this]() { m_canvas->resetView(); });
    connect(zfit, &QToolButton::clicked, this, [this]() { m_canvas->fitToContent(); });
    vrow->addWidget(zout); vrow->addWidget(zin);
    vrow->addWidget(zrst); vrow->addWidget(zfit);
    v->addLayout(vrow);

    v->addStretch(1);
    scroll->setWidget(panel);
    return scroll;
}

// ---------------- top bar ----------------

void MainWindow::buildTopBar()
{
    auto *tb = addToolBar("Main");
    tb->setObjectName("TopBar");
    tb->setMovable(false);
    tb->setFloatable(false);

    auto add = [&](const QString &text, const QString &sc, auto slot) {
        auto *a = tb->addAction(text);
        if (!sc.isEmpty()) a->setShortcut(QKeySequence(sc));
        connect(a, &QAction::triggered, this, slot);
        return a;
    };

    add("New",  "Ctrl+N", &MainWindow::onNew);
    add("Open", "Ctrl+O", &MainWindow::onOpen);
    add("Save", "Ctrl+S", &MainWindow::onSave);
    tb->addSeparator();
    add("Undo", "Ctrl+Z", [this]() { m_canvas->undo(); });
    add("Redo", "Ctrl+Shift+Z", [this]() { m_canvas->redo(); });
    tb->addSeparator();
    add("Export PDF", "Ctrl+E", &MainWindow::onExportPdf);
    add("Export PNG", "", &MainWindow::onExportPng);
    add("Export SVG", "", &MainWindow::onExportSvg);
    tb->addSeparator();
    add("Clear", "", [this]() {
        if (QMessageBox::question(this, "Clear page", "Clear everything on this page?")
            == QMessageBox::Yes)
            m_canvas->clearPage();
    });

    // spacer pushes theme/present to the right
    auto *spacer = new QWidget;
    spacer->setSizePolicy(QSizePolicy::Expanding, QSizePolicy::Preferred);
    tb->addWidget(spacer);

    add("Theme",   "Ctrl+T", &MainWindow::onToggleTheme);
    add("Present", "F5",     &MainWindow::onTogglePresent);

    // global edit shortcuts
    auto *selAll = new QAction(this);
    selAll->setShortcut(QKeySequence::SelectAll);
    connect(selAll, &QAction::triggered, this, [this]() { m_canvas->selectAll(); });
    addAction(selAll);

    auto *delAct = new QAction(this);
    delAct->setShortcut(QKeySequence(Qt::Key_Delete));
    connect(delAct, &QAction::triggered, this, [this]() { m_canvas->deleteSelection(); });
    addAction(delAct);

    auto *redoAlt = new QAction(this);
    redoAlt->setShortcut(QKeySequence("Ctrl+Y"));
    connect(redoAlt, &QAction::triggered, this, [this]() { m_canvas->redo(); });
    addAction(redoAlt);
}

// ---------------- slots ----------------

void MainWindow::onNew()
{
    if (QMessageBox::question(this, "New", "Start a new board? Unsaved changes will be lost.")
        == QMessageBox::Yes) {
        m_canvas->clearPage();
        m_canvas->resetView();
    }
}

void MainWindow::onOpen()
{
    const QString path = QFileDialog::getOpenFileName(
        this, "Open Board", QString(), "Whiteboard (*.wb *.json)");
    if (path.isEmpty()) return;
    if (!m_canvas->loadDocument(path))
        QMessageBox::warning(this, "Open", "Could not open that file.");
    else
        setWindowTitle("Whiteboard \u2014 " + QFileInfo(path).fileName());
}

void MainWindow::onSave()
{
    QString path = QFileDialog::getSaveFileName(
        this, "Save Board", "board.wb", "Whiteboard (*.wb *.json)");
    if (path.isEmpty()) return;
    if (!path.contains('.')) path += ".wb";
    if (!m_canvas->saveDocument(path))
        QMessageBox::warning(this, "Save", "Could not save the file.");
    else
        setWindowTitle("Whiteboard \u2014 " + QFileInfo(path).fileName());
}

void MainWindow::onExportPdf()
{
    QString path = QFileDialog::getSaveFileName(this, "Export PDF", "whiteboard.pdf", "PDF (*.pdf)");
    if (path.isEmpty()) return;
    if (!path.endsWith(".pdf", Qt::CaseInsensitive)) path += ".pdf";
    if (m_canvas->exportPdf(path))
        m_status->setText("Exported PDF: " + QFileInfo(path).fileName());
    else
        QMessageBox::warning(this, "Export PDF", "Export failed.");
}

void MainWindow::onExportPng()
{
    QString path = QFileDialog::getSaveFileName(this, "Export PNG", "whiteboard.png", "PNG (*.png)");
    if (path.isEmpty()) return;
    if (!path.endsWith(".png", Qt::CaseInsensitive)) path += ".png";
    if (m_canvas->exportPng(path))
        m_status->setText("Exported PNG: " + QFileInfo(path).fileName());
    else
        QMessageBox::warning(this, "Export PNG", "Export failed.");
}

void MainWindow::onExportSvg()
{
    QString path = QFileDialog::getSaveFileName(this, "Export SVG", "whiteboard.svg", "SVG (*.svg)");
    if (path.isEmpty()) return;
    if (!path.endsWith(".svg", Qt::CaseInsensitive)) path += ".svg";
    if (m_canvas->exportSvg(path))
        m_status->setText("Exported SVG: " + QFileInfo(path).fileName());
    else
        QMessageBox::warning(this, "Export SVG", "Export failed.");
}

void MainWindow::onInsertImage() { m_canvas->insertImageFromFile(); }

void MainWindow::onToolChanged(Tool t) { selectToolButton(t); }

void MainWindow::selectToolButton(Tool t)
{
    if (!m_toolGroup) return;
    if (auto *b = m_toolGroup->button(int(t))) {
        QSignalBlocker blk(m_toolGroup);
        b->setChecked(true);
    }
}

void MainWindow::onZoomChanged(int pct)
{
    if (m_zoomLbl) m_zoomLbl->setText(QString("%1%").arg(pct));
}

void MainWindow::onStatus(const QString &msg)
{
    if (m_status) m_status->setText(msg);
}

void MainWindow::onPageChanged(int current, int total)
{
    if (m_pageLbl) m_pageLbl->setText(QString("Page %1 / %2").arg(current + 1).arg(total));
}

void MainWindow::onToggleTheme()
{
    m_dark = !m_dark;
    Theme::apply(qApp, m_dark ? Theme::Dark : Theme::Light);
}

void MainWindow::onTogglePresent()
{
    m_present = !m_present;
    m_toolRail->setVisible(!m_present);
    m_panel->setVisible(!m_present);
    for (QToolBar *bar : findChildren<QToolBar *>()) bar->setVisible(!m_present);
    statusBar()->setVisible(!m_present);
    if (m_present) showFullScreen();
    else showNormal();
    m_canvas->setFocus();
}
EOF

echo ">> Part 5 done. UI shell (ColorButton + MainWindow) written."
