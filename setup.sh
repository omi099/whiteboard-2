#!/usr/bin/env bash
set -euo pipefail

echo ">> Chunk 1: project skeleton + CMake"
mkdir -p src .github/workflows

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

find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets)
qt_standard_project_setup()

qt_add_executable(Whiteboard WIN32
    src/main.cpp
    src/Stroke.h
    src/CanvasWidget.h
    src/CanvasWidget.cpp
    src/MainWindow.h
    src/MainWindow.cpp
)

target_link_libraries(Whiteboard PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
)
EOF

cat > .gitignore << 'EOF'
/build/
*.user
*.autosave
CMakeCache.txt
CMakeFiles/
EOF

echo ">> Chunk 1 done."

#!/usr/bin/env bash
set -euo pipefail
echo ">> Chunk 2: main.cpp + Stroke.h"

cat > src/main.cpp << 'EOF'
#include <QApplication>
#include "MainWindow.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    QApplication::setApplicationName("Whiteboard");
    QApplication::setOrganizationName("Whiteboard");

    MainWindow w;
    w.resize(1280, 800);
    w.show();
    return app.exec();
}
EOF

cat > src/Stroke.h << 'EOF'
#pragma once

#include <QColor>
#include <QPointF>
#include <QRectF>
#include <QVector>
#include <QtGlobal>

enum class ToolType { Pen, Highlighter, Eraser };

struct StrokePoint {
    QPointF pos;
    qreal   pressure = 1.0;
};

struct Stroke {
    QVector<StrokePoint> points;
    QColor color = Qt::black;
    qreal  width = 3.0;
    bool   highlighter = false;

    QRectF bounds() const {
        if (points.isEmpty())
            return QRectF();
        qreal minX = points.first().pos.x(), maxX = minX;
        qreal minY = points.first().pos.y(), maxY = minY;
        for (const auto &p : points) {
            minX = qMin(minX, p.pos.x());
            maxX = qMax(maxX, p.pos.x());
            minY = qMin(minY, p.pos.y());
            maxY = qMax(maxY, p.pos.y());
        }
        return QRectF(QPointF(minX, minY), QPointF(maxX, maxY))
            .adjusted(-width, -width, width, width);
    }
};
EOF

echo ">> Chunk 2 done."


#!/usr/bin/env bash
set -euo pipefail
echo ">> Chunk 3: CanvasWidget.h + CanvasWidget.cpp"

cat > src/CanvasWidget.h << 'EOF'
#pragma once

#include <QWidget>
#include <QVector>
#include "Stroke.h"

class CanvasWidget : public QWidget
{
    Q_OBJECT
public:
    explicit CanvasWidget(QWidget *parent = nullptr);

    void setTool(ToolType t);
    void setPenColor(const QColor &c);
    void setPenWidth(qreal w);

    void clearCanvas();
    void undo();
    void redo();

    bool exportPdf(const QString &path);
    bool exportPng(const QString &path);
    bool saveDocument(const QString &path);
    bool loadDocument(const QString &path);

    QRectF contentBounds() const;

signals:
    void statusChanged(const QString &msg);

protected:
    void paintEvent(QPaintEvent *) override;
    void mousePressEvent(QMouseEvent *) override;
    void mouseMoveEvent(QMouseEvent *) override;
    void mouseReleaseEvent(QMouseEvent *) override;
    void tabletEvent(QTabletEvent *) override;
    void wheelEvent(QWheelEvent *) override;

private:
    // view transform (canvas -> screen)
    qreal   m_scale  = 1.0;
    QPointF m_offset = QPointF(0, 0);

    // current tool state
    ToolType m_tool  = ToolType::Pen;
    QColor   m_color = Qt::black;
    qreal    m_width = 3.0;

    // document + history
    QVector<Stroke> m_strokes;
    QVector<QVector<Stroke>> m_undo;
    QVector<QVector<Stroke>> m_redo;

    // in-progress stroke
    bool   m_drawing = false;
    Stroke m_current;

    // panning
    bool    m_panning = false;
    QPointF m_lastPan;

    QPointF toCanvas(const QPointF &screen) const;
    void pushUndo();
    void beginStroke(const QPointF &c, qreal pressure);
    void extendStroke(const QPointF &c, qreal pressure);
    void endStroke();
    void eraseAt(const QPointF &c);
    void drawStroke(QPainter &p, const Stroke &s) const;
};
EOF

cat > src/CanvasWidget.cpp << 'EOF'
#include "CanvasWidget.h"

#include <QPainter>
#include <QPainterPath>
#include <QMouseEvent>
#include <QTabletEvent>
#include <QWheelEvent>
#include <QPointingDevice>
#include <QLineF>
#include <QPdfWriter>
#include <QPageSize>
#include <QPageLayout>
#include <QMarginsF>
#include <QImage>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QtMath>

CanvasWidget::CanvasWidget(QWidget *parent) : QWidget(parent)
{
    setTabletTracking(true);
    setMouseTracking(false);
    setCursor(Qt::CrossCursor);
    setFocusPolicy(Qt::StrongFocus);
    setAutoFillBackground(true);
    QPalette pal = palette();
    pal.setColor(QPalette::Window, Qt::white);
    setPalette(pal);
}

void CanvasWidget::setTool(ToolType t) { m_tool = t; }
void CanvasWidget::setPenColor(const QColor &c) { m_color = c; }
void CanvasWidget::setPenWidth(qreal w) { m_width = w; }

QPointF CanvasWidget::toCanvas(const QPointF &s) const
{
    return (s - m_offset) / m_scale;
}

void CanvasWidget::pushUndo()
{
    m_undo.push_back(m_strokes);
    if (m_undo.size() > 100)
        m_undo.removeFirst();
    m_redo.clear();
}

void CanvasWidget::clearCanvas()
{
    pushUndo();
    m_strokes.clear();
    update();
    emit statusChanged("Canvas cleared");
}

void CanvasWidget::undo()
{
    if (m_undo.isEmpty())
        return;
    m_redo.push_back(m_strokes);
    m_strokes = m_undo.takeLast();
    update();
    emit statusChanged("Undo");
}

void CanvasWidget::redo()
{
    if (m_redo.isEmpty())
        return;
    m_undo.push_back(m_strokes);
    m_strokes = m_redo.takeLast();
    update();
    emit statusChanged("Redo");
}

void CanvasWidget::beginStroke(const QPointF &c, qreal pressure)
{
    pushUndo();
    m_drawing = true;
    m_current = Stroke();
    m_current.color = m_color;
    m_current.width = m_width;
    m_current.highlighter = (m_tool == ToolType::Highlighter);
    m_current.points.push_back({c, pressure});
}

void CanvasWidget::extendStroke(const QPointF &c, qreal pressure)
{
    if (!m_drawing)
        return;
    const QPointF last = m_current.points.last().pos;
    const qreal minDist = 1.0 / m_scale; // ~1px in canvas units
    if (QLineF(last, c).length() < minDist) {
        m_current.points.last().pressure = pressure;
        return;
    }
    m_current.points.push_back({c, pressure});
}

void CanvasWidget::endStroke()
{
    if (!m_drawing)
        return;
    m_drawing = false;
    if (!m_current.points.isEmpty())
        m_strokes.push_back(m_current);
    m_current = Stroke();
}

void CanvasWidget::eraseAt(const QPointF &c)
{
    const qreal radius = qMax<qreal>(6.0, m_width * 2.0);
    for (int i = m_strokes.size() - 1; i >= 0; --i) {
        bool hit = false;
        for (const auto &p : m_strokes[i].points) {
            if (QLineF(p.pos, c).length() <= radius + m_strokes[i].width / 2.0) {
                hit = true;
                break;
            }
        }
        if (hit)
            m_strokes.removeAt(i);
    }
}

void CanvasWidget::drawStroke(QPainter &p, const Stroke &s) const
{
    if (s.points.isEmpty())
        return;

    QColor col = s.color;

    if (s.highlighter) {
        col.setAlphaF(0.35);
        if (s.points.size() == 1) {
            p.setPen(Qt::NoPen);
            p.setBrush(col);
            p.drawEllipse(s.points.first().pos, s.width / 2.0, s.width / 2.0);
            return;
        }
        QPainterPath path(s.points.first().pos);
        for (int i = 1; i < s.points.size(); ++i)
            path.lineTo(s.points[i].pos);
        QPen pen(col, s.width, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin);
        p.setPen(pen);
        p.setBrush(Qt::NoBrush);
        p.drawPath(path);
        return;
    }

    if (s.points.size() == 1) {
        p.setPen(Qt::NoPen);
        p.setBrush(col);
        qreal r = qMax<qreal>(0.5, s.width * s.points.first().pressure / 2.0);
        p.drawEllipse(s.points.first().pos, r, r);
        return;
    }

    for (int i = 1; i < s.points.size(); ++i) {
        qreal pr = (s.points[i - 1].pressure + s.points[i].pressure) / 2.0;
        qreal w  = qMax<qreal>(0.5, s.width * pr);
        QPen pen(col, w, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin);
        p.setPen(pen);
        p.drawLine(s.points[i - 1].pos, s.points[i].pos);
    }
}

void CanvasWidget::paintEvent(QPaintEvent *)
{
    QPainter p(this);
    p.fillRect(rect(), Qt::white);
    p.setRenderHint(QPainter::Antialiasing, true);
    p.translate(m_offset);
    p.scale(m_scale, m_scale);

    for (const auto &s : m_strokes)
        drawStroke(p, s);
    if (m_drawing)
        drawStroke(p, m_current);
}

void CanvasWidget::mousePressEvent(QMouseEvent *e)
{
    if (e->button() == Qt::MiddleButton) {
        m_panning = true;
        m_lastPan = e->position();
        setCursor(Qt::ClosedHandCursor);
        return;
    }
    if (e->button() != Qt::LeftButton)
        return;

    const QPointF c = toCanvas(e->position());
    if (m_tool == ToolType::Eraser) {
        pushUndo();
        eraseAt(c);
    } else {
        beginStroke(c, 1.0);
    }
    update();
}

void CanvasWidget::mouseMoveEvent(QMouseEvent *e)
{
    if (m_panning) {
        m_offset += (e->position() - m_lastPan);
        m_lastPan = e->position();
        update();
        return;
    }
    const QPointF c = toCanvas(e->position());
    if (m_drawing) {
        extendStroke(c, 1.0);
        update();
    } else if (m_tool == ToolType::Eraser && (e->buttons() & Qt::LeftButton)) {
        eraseAt(c);
        update();
    }
}

void CanvasWidget::mouseReleaseEvent(QMouseEvent *e)
{
    if (e->button() == Qt::MiddleButton) {
        m_panning = false;
        setCursor(Qt::CrossCursor);
        return;
    }
    if (m_drawing)
        endStroke();
    update();
}

void CanvasWidget::tabletEvent(QTabletEvent *e)
{
    const QPointF c = toCanvas(e->position());
    qreal pressure = e->pressure();
    if (pressure <= 0.0)
        pressure = 0.5;

    const bool eraserTip =
        (e->pointerType() == QPointingDevice::PointerType::Eraser);

    switch (e->type()) {
    case QEvent::TabletPress:
        if (eraserTip || m_tool == ToolType::Eraser) {
            pushUndo();
            eraseAt(c);
        } else {
            beginStroke(c, pressure);
        }
        break;
    case QEvent::TabletMove:
        if (m_drawing)
            extendStroke(c, pressure);
        else if ((eraserTip || m_tool == ToolType::Eraser) &&
                 (e->buttons() & Qt::LeftButton))
            eraseAt(c);
        break;
    case QEvent::TabletRelease:
        if (m_drawing)
            endStroke();
        break;
    default:
        break;
    }
    e->accept();
    update();
}

void CanvasWidget::wheelEvent(QWheelEvent *e)
{
    const double factor = (e->angleDelta().y() > 0) ? 1.15 : (1.0 / 1.15);
    const QPointF before = toCanvas(e->position());
    m_scale = qBound(0.05, m_scale * factor, 40.0);
    m_offset = e->position() - before * m_scale; // keep point under cursor fixed
    update();
    emit statusChanged(QString("Zoom: %1%").arg(int(m_scale * 100)));
}

QRectF CanvasWidget::contentBounds() const
{
    QRectF r;
    for (const auto &s : m_strokes) {
        const QRectF b = s.bounds();
        r = r.isNull() ? b : r.united(b);
    }
    return r;
}

bool CanvasWidget::exportPdf(const QString &path)
{
    QPdfWriter writer(path);
    writer.setPageSize(QPageSize(QPageSize::A4));
    writer.setResolution(300);
    writer.setPageMargins(QMarginsF(10, 10, 10, 10), QPageLayout::Millimeter);

    QPainter painter(&writer);
    if (!painter.isActive())
        return false;
    painter.setRenderHint(QPainter::Antialiasing, true);

    QRectF content = contentBounds();
    if (content.isNull())
        content = QRectF(0, 0, 100, 100);

    const QRectF page(0, 0, writer.width(), writer.height());
    const qreal s = qMin(page.width() / content.width(),
                         page.height() / content.height());

    painter.translate(page.center());
    painter.scale(s, s);
    painter.translate(-content.center());

    for (const auto &stroke : m_strokes)
        drawStroke(painter, stroke);

    painter.end();
    return true;
}

bool CanvasWidget::exportPng(const QString &path)
{
    QRectF content = contentBounds();
    if (content.isNull())
        content = QRectF(0, 0, 100, 100);

    const int   margin = 20;
    const qreal scale  = 2.0;
    QSize sz(int((content.width() + 2 * margin) * scale),
             int((content.height() + 2 * margin) * scale));
    if (sz.width() <= 0 || sz.height() <= 0)
        return false;

    QImage img(sz, QImage::Format_ARGB32_Premultiplied);
    img.fill(Qt::white);

    QPainter p(&img);
    p.setRenderHint(QPainter::Antialiasing, true);
    p.scale(scale, scale);
    p.translate(margin - content.left(), margin - content.top());
    for (const auto &s : m_strokes)
        drawStroke(p, s);
    p.end();

    return img.save(path, "PNG");
}

bool CanvasWidget::saveDocument(const QString &path)
{
    QJsonArray arr;
    for (const auto &s : m_strokes) {
        QJsonObject so;
        so["color"] = s.color.name(QColor::HexArgb);
        so["width"] = s.width;
        so["highlighter"] = s.highlighter;
        QJsonArray pts;
        for (const auto &p : s.points) {
            QJsonObject po;
            po["x"] = p.pos.x();
            po["y"] = p.pos.y();
            po["p"] = p.pressure;
            pts.append(po);
        }
        so["points"] = pts;
        arr.append(so);
    }
    QJsonObject root;
    root["version"] = 1;
    root["strokes"] = arr;

    QFile f(path);
    if (!f.open(QIODevice::WriteOnly))
        return false;
    f.write(QJsonDocument(root).toJson(QJsonDocument::Compact));
    return true;
}

bool CanvasWidget::loadDocument(const QString &path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return false;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    if (!doc.isObject())
        return false;

    pushUndo();
    m_strokes.clear();

    const QJsonArray arr = doc.object()["strokes"].toArray();
    for (const auto &v : arr) {
        const QJsonObject so = v.toObject();
        Stroke s;
        s.color = QColor(so["color"].toString());
        s.width = so["width"].toDouble(3.0);
        s.highlighter = so["highlighter"].toBool();
        for (const auto &pv : so["points"].toArray()) {
            const QJsonObject po = pv.toObject();
            s.points.push_back({QPointF(po["x"].toDouble(), po["y"].toDouble()),
                                po["p"].toDouble(1.0)});
        }
        m_strokes.push_back(s);
    }
    update();
    return true;
}
EOF

echo ">> Chunk 3 done."


#!/usr/bin/env bash
set -euo pipefail
echo ">> Chunk 4: MainWindow.h + MainWindow.cpp"

cat > src/MainWindow.h << 'EOF'
#pragma once

#include <QMainWindow>
#include <QColor>

class CanvasWidget;

class MainWindow : public QMainWindow
{
    Q_OBJECT
public:
    explicit MainWindow(QWidget *parent = nullptr);

private slots:
    void chooseColor();
    void doExportPdf();
    void doExportPng();
    void doSave();
    void doOpen();

private:
    void setupUi();

    CanvasWidget *m_canvas = nullptr;
    QColor        m_color  = Qt::black;
};
EOF

cat > src/MainWindow.cpp << 'EOF'
#include "MainWindow.h"
#include "CanvasWidget.h"

#include <QToolBar>
#include <QAction>
#include <QActionGroup>
#include <QMenuBar>
#include <QStatusBar>
#include <QColorDialog>
#include <QFileDialog>
#include <QMessageBox>
#include <QSpinBox>
#include <QLabel>
#include <QKeySequence>

MainWindow::MainWindow(QWidget *parent) : QMainWindow(parent)
{
    setupUi();
}

void MainWindow::setupUi()
{
    m_canvas = new CanvasWidget(this);
    setCentralWidget(m_canvas);

    QToolBar *tb = addToolBar("Tools");
    tb->setMovable(false);

    QAction *penAct = tb->addAction("Pen");
    penAct->setCheckable(true);
    penAct->setChecked(true);
    QAction *hlAct = tb->addAction("Highlighter");
    hlAct->setCheckable(true);
    QAction *erAct = tb->addAction("Eraser");
    erAct->setCheckable(true);

    QActionGroup *grp = new QActionGroup(this);
    grp->addAction(penAct);
    grp->addAction(hlAct);
    grp->addAction(erAct);

    connect(penAct, &QAction::triggered, this,
            [this] { m_canvas->setTool(ToolType::Pen); });
    connect(hlAct, &QAction::triggered, this,
            [this] { m_canvas->setTool(ToolType::Highlighter); });
    connect(erAct, &QAction::triggered, this,
            [this] { m_canvas->setTool(ToolType::Eraser); });

    tb->addSeparator();
    QAction *colorAct = tb->addAction("Color");
    connect(colorAct, &QAction::triggered, this, &MainWindow::chooseColor);

    tb->addWidget(new QLabel(" Width "));
    QSpinBox *widthSpin = new QSpinBox(this);
    widthSpin->setRange(1, 50);
    widthSpin->setValue(3);
    connect(widthSpin, &QSpinBox::valueChanged, this,
            [this](int v) { m_canvas->setPenWidth(v); });
    tb->addWidget(widthSpin);

    tb->addSeparator();
    QAction *undoAct = tb->addAction("Undo");
    undoAct->setShortcut(QKeySequence::Undo);
    connect(undoAct, &QAction::triggered, m_canvas, &CanvasWidget::undo);
    QAction *redoAct = tb->addAction("Redo");
    redoAct->setShortcut(QKeySequence::Redo);
    connect(redoAct, &QAction::triggered, m_canvas, &CanvasWidget::redo);
    QAction *clearAct = tb->addAction("Clear");
    connect(clearAct, &QAction::triggered, m_canvas, &CanvasWidget::clearCanvas);

    QMenu *fileMenu = menuBar()->addMenu("&File");
    QAction *openAct = fileMenu->addAction("&Open...");
    openAct->setShortcut(QKeySequence::Open);
    connect(openAct, &QAction::triggered, this, &MainWindow::doOpen);
    QAction *saveAct = fileMenu->addAction("&Save...");
    saveAct->setShortcut(QKeySequence::Save);
    connect(saveAct, &QAction::triggered, this, &MainWindow::doSave);
    fileMenu->addSeparator();
    QAction *pdfAct = fileMenu->addAction("Export &PDF...");
    connect(pdfAct, &QAction::triggered, this, &MainWindow::doExportPdf);
    QAction *pngAct = fileMenu->addAction("Export P&NG...");
    connect(pngAct, &QAction::triggered, this, &MainWindow::doExportPng);
    fileMenu->addSeparator();
    QAction *quitAct = fileMenu->addAction("&Quit");
    quitAct->setShortcut(QKeySequence::Quit);
    connect(quitAct, &QAction::triggered, this, &QWidget::close);

    statusBar()->showMessage("Ready  |  Pen draws, middle-drag pans, wheel zooms");
    connect(m_canvas, &CanvasWidget::statusChanged, this,
            [this](const QString &m) { statusBar()->showMessage(m, 4000); });

    setWindowTitle("Whiteboard");
}

void MainWindow::chooseColor()
{
    QColor c = QColorDialog::getColor(m_color, this, "Choose pen color");
    if (c.isValid()) {
        m_color = c;
        m_canvas->setPenColor(c);
    }
}

void MainWindow::doExportPdf()
{
    QString path = QFileDialog::getSaveFileName(
        this, "Export PDF", "whiteboard.pdf", "PDF Files (*.pdf)");
    if (path.isEmpty())
        return;
    if (!path.endsWith(".pdf", Qt::CaseInsensitive))
        path += ".pdf";
    if (m_canvas->exportPdf(path))
        statusBar()->showMessage("Exported PDF: " + path, 5000);
    else
        QMessageBox::warning(this, "Export PDF", "Failed to export PDF.");
}

void MainWindow::doExportPng()
{
    QString path = QFileDialog::getSaveFileName(
        this, "Export PNG", "whiteboard.png", "PNG Files (*.png)");
    if (path.isEmpty())
        return;
    if (!path.endsWith(".png", Qt::CaseInsensitive))
        path += ".png";
    if (m_canvas->exportPng(path))
        statusBar()->showMessage("Exported PNG: " + path, 5000);
    else
        QMessageBox::warning(this, "Export PNG", "Failed to export PNG.");
}

void MainWindow::doSave()
{
    QString path = QFileDialog::getSaveFileName(
        this, "Save Whiteboard", "whiteboard.wbd", "Whiteboard (*.wbd)");
    if (path.isEmpty())
        return;
    if (!path.endsWith(".wbd", Qt::CaseInsensitive))
        path += ".wbd";
    if (m_canvas->saveDocument(path))
        statusBar()->showMessage("Saved: " + path, 5000);
    else
        QMessageBox::warning(this, "Save", "Failed to save file.");
}

void MainWindow::doOpen()
{
    QString path = QFileDialog::getOpenFileName(
        this, "Open Whiteboard", QString(), "Whiteboard (*.wbd)");
    if (path.isEmpty())
        return;
    if (m_canvas->loadDocument(path))
        statusBar()->showMessage("Opened: " + path, 5000);
    else
        QMessageBox::warning(this, "Open", "Failed to open file.");
}
EOF

echo ">> Chunk 4 done."


#!/usr/bin/env bash
set -euo pipefail
echo ">> Chunk 5: GitHub Actions workflow"

cat > .github/workflows/build-windows.yml << 'EOF'
name: Build Windows EXE

on:
  push:
    branches: [ main, master ]
    tags: [ 'v*' ]
  pull_request:
    branches: [ main, master ]
  workflow_dispatch:

concurrency:
  group: $ github.workflow -$ github.ref 
  cancel-in-progress: true

env:
  QT_VERSION: 6.8.1
  APP_NAME: Whiteboard

jobs:
  build-windows:
    runs-on: windows-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up MSVC (x64)
        uses: ilammy/msvc-dev-cmd@v1
        with:
          arch: x64

      - name: Install Qt
        uses: jurplel/install-qt-action@v4
        with:
          version: $ env.QT_VERSION 
          host: windows
          target: desktop
          arch: win64_msvc2022_64
          cache: true
          setup-python: false

      - name: Configure (CMake + Ninja)
        run: >
          cmake -S . -B build
          -G Ninja
          -DCMAKE_BUILD_TYPE=Release
          -DCMAKE_PREFIX_PATH="$env:QT_ROOT_DIR"

      - name: Build
        run: cmake --build build --config Release --parallel

      - name: Deploy Qt runtime (windeployqt)
        shell: pwsh
        run: |
          $ErrorActionPreference = "Stop"
          $exe = Get-ChildItem -Path build -Recurse -Filter "$env:APP_NAME.exe" | Select-Object -First 1
          if (-not $exe) {
            Write-Error "Could not find $env:APP_NAME.exe under build/."
            exit 1
          }
          Write-Host "Found exe: $($exe.FullName)"
          New-Item -ItemType Directory -Force -Path dist | Out-Null
          Copy-Item $exe.FullName -Destination dist\
          & "$env:QT_ROOT_DIR\bin\windeployqt.exe" --release --dir dist --no-translations --compiler-runtime "dist\$env:APP_NAME.exe"

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: Whiteboard-windows-x64
          path: dist/**
          if-no-files-found: error
          retention-days: 14

      - name: Zip for release
        if: startsWith(github.ref, 'refs/tags/v')
        shell: pwsh
        run: Compress-Archive -Path dist\* -DestinationPath "Whiteboard-windows-x64.zip" -Force

      - name: Publish GitHub Release
        if: startsWith(github.ref, 'refs/tags/v')
        uses: softprops/action-gh-release@v2
        with:
          files: Whiteboard-windows-x64.zip
        env:
          GITHUB_TOKEN: $ secrets.GITHUB_TOKEN 
EOF

echo ">> Chunk 5 done. Project scaffolded."
echo ">> Commit & push, then download the artifact from the Actions tab."
