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

log "PART 11 complete: laser vanishing mode fades + clears when the pen leaves range"
