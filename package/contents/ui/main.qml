/*
 * Snap Layouts Hover - Windows 11 style snap layouts for KDE Plasma 6.
 *
 * Rest the pointer on a window's caption buttons (top right) and a flyout
 * with eight layouts appears. Click a zone: the window goes there, and the
 * remaining zones are filled with the other windows on that screen.
 *
 * The flyout is pure hover UI; it does not change KDE's own edge snapping.
 *
 * Debug: journalctl --user -f | grep snaplayoutshover
 */
import QtQuick
import org.kde.kwin

Item {
    id: root

    // Development only: open the flyout on load, for screenshots.
    readonly property bool devShow: false

    // Window whose caption strip is hovered, and that strip.
    property var target: null
    property rect targetZone: Qt.rect(0, 0, 0, 0)
    // Hover is ignored for a moment after a drag or a pick.
    property double quietUntil: 0
    // Windows being dragged right now, keyed by internalId.
    property var moving: ({})
    // Pending placements after a layout was picked.
    property var fillQueue: []
    // Windows we listen to for drag signals.
    property var watched: []

    function log(msg) {
        console.info("snaplayoutflyout: " + msg);
    }

    function inside(r, p) {
        return p.x >= r.x && p.x < r.x + r.width && p.y >= r.y && p.y < r.y + r.height;
    }

    function usable(w) {
        return w && w.normalWindow && !w.specialWindow && !w.skipTaskbar
            && w.moveable && w.resizeable && !w.fullScreen && w.pid > 0;
    }

    function onThisDesktop(w) {
        if (w.onAllDesktops)
            return true;
        const cur = Workspace.currentDesktop;
        for (let i = 0; i < w.desktops.length; i++) {
            if (w.desktops[i] === cur)
                return true;
        }
        return false;
    }

    function workArea(output) {
        return Workspace.clientArea(KWin.MaximizeArea, output, Workspace.currentDesktop);
    }

    function windowAt(p) {
        const stack = Workspace.stackingOrder;
        for (let i = stack.length - 1; i >= 0; i--) {
            const w = stack[i];
            if (!usable(w) || w.minimized || !onThisDesktop(w))
                continue;
            const g = w.frameGeometry;
            if (inside(Qt.rect(g.x, g.y, g.width, g.height), p))
                return w;
        }
        return null;
    }

    // The caption strip. KWin does not expose the decoration button rects,
    // and apps with client-side decorations draw their own buttons, so the
    // trigger is the top-right strip of the frame: as wide as configured,
    // as tall as the titlebar.
    function captionZone(w) {
        const g = w.frameGeometry;
        const c = w.clientGeometry;
        let h = cfg.zoneHeight;
        if (h <= 0) {
            const deco = Math.round(c.y - g.y);
            h = deco > 10 ? Math.min(44, deco) : 34;
        }
        return Qt.rect(Math.round(g.x + g.width - cfg.zoneWidth), Math.round(g.y),
                       cfg.zoneWidth, h);
    }

    // Windows that can fill a free zone: same screen, current desktop,
    // topmost first.
    function fillers(exclude, output) {
        const list = [];
        const stack = Workspace.stackingOrder;
        for (let i = stack.length - 1; i >= 0; i--) {
            const w = stack[i];
            if (w === exclude || !usable(w) || !onThisDesktop(w))
                continue;
            if (output && w.output !== output)
                continue;
            list.push(w);
        }
        return list;
    }

    function dragging() {
        for (const key in root.moving)
            return true;
        return false;
    }

    function pointerMoved() {
        if (!cfg.enabled)
            return;
        if (flyout.visible) {
            checkLeave();
            return;
        }
        if (dragging() || Date.now() < quietUntil) {
            dwell.stop();
            return;
        }
        const p = Workspace.cursorPos;
        const w = windowAt(p);
        if (!w) {
            dwell.stop();
            target = null;
            return;
        }
        const z = captionZone(w);
        if (!inside(z, p)) {
            dwell.stop();
            target = null;
            return;
        }
        if (target !== w) {
            target = w;
            targetZone = z;
            dwell.restart();
        }
    }

    function openFlyout() {
        const w = target;
        if (!w || !cfg.enabled)
            return;
        const z = captionZone(w);
        if (!inside(z, Workspace.cursorPos))
            return;
        // Pointless while there is nothing to arrange.
        if (cfg.needsOthers && fillers(w, w.output).length === 0) {
            log("skipped: no other window");
            return;
        }
        targetZone = z;
        const g = w.frameGeometry;
        flyout.windows = [w].concat(fillers(w, w.output));
        flyout.showAt(Qt.point(Math.round(g.x + g.width - flyout.panelWidth),
                               Math.round(z.y + z.height + 6)),
                      workArea(w.output), w.output);
        log("open for '" + w.caption + "'");
    }

    function closeFlyout(reason) {
        if (!flyout.visible) {
            target = null;
            return;
        }
        log("closed (" + (reason || "done") + ")");
        flyout.hide();
        dwell.stop();
        leave.stop();
        target = null;
        quietUntil = Date.now() + 400;
    }

    function checkLeave() {
        const p = Workspace.cursorPos;
        if (flyout.contains(p) || inside(targetZone, p)) {
            leave.stop();
            return;
        }
        if (!leave.running)
            leave.restart();
    }

    function place(w, rect) {
        if (w.tile)
            w.tile = null;
        w.setMaximize(false, false);
        w.minimized = false;
        w.frameGeometry = rect;
    }

    function applyZone(li, zi) {
        const w = target;
        if (!w) {
            closeFlyout("no target");
            return;
        }
        const otherZones = [];
        for (let i = 0; i < flyout.layouts[li].length; i++) {
            if (i !== zi)
                otherZones.push(flyout.zoneRect(li, i));
        }
        const chosen = flyout.zoneRect(li, zi);
        closeFlyout("picked");
        place(w, chosen);
        if (!cfg.autoFill)
            return;
        const others = fillers(w, w.output);
        const queue = [];
        let ci = 0;
        // Every remaining zone gets the next window on the stack, whatever
        // sat there before: picking a layout means rearranging.
        for (let i = 0; i < otherZones.length && ci < others.length; i++, ci++)
            queue.push({ "window": others[ci], "rect": otherZones[i] });
        fillQueue = queue;
        log("fill " + queue.length + " of " + others.length + " window(s)");
        fillNext();
    }

    // One placement at a time; geometry requests are asynchronous.
    function fillNext() {
        if (fillQueue.length === 0)
            return;
        const item = fillQueue[0];
        fillQueue = fillQueue.slice(1);
        place(item.window, item.rect);
        if (fillQueue.length > 0)
            fillTimer.restart();
    }

    function refreshWatched() {
        const list = [];
        const stack = Workspace.stackingOrder;
        for (let i = 0; i < stack.length; i++) {
            if (stack[i].normalWindow)
                list.push(stack[i]);
        }
        watched = list;
    }

    Config {
        id: cfg
    }

    Flyout {
        id: flyout
        cfg: cfg
        onZoneClicked: function(li, zi) { root.applyZone(li, zi); }
    }

    Timer {
        id: dwell
        interval: cfg.delay
        onTriggered: root.openFlyout()
    }

    Timer {
        id: leave
        interval: 200
        onTriggered: {
            const p = Workspace.cursorPos;
            if (flyout.visible && !flyout.contains(p) && !root.inside(root.targetZone, p))
                root.closeFlyout("pointer left");
        }
    }

    Timer {
        id: fillTimer
        interval: 120
        onTriggered: root.fillNext()
    }

    Timer {
        id: devTimer
        interval: 900
        onTriggered: {
            let w = Workspace.activeWindow;
            if (!w || w.pid <= 0 || !root.usable(w)) {
                const stack = Workspace.stackingOrder;
                for (let i = stack.length - 1; i >= 0; i--) {
                    if (root.usable(stack[i]) && !stack[i].minimized) {
                        w = stack[i];
                        break;
                    }
                }
            }
            if (!w)
                return;
            root.target = w;
            root.targetZone = root.captionZone(w);
            const g = w.frameGeometry;
            flyout.windows = [w].concat(root.fillers(w, w.output));
            flyout.showAt(Qt.point(Math.round(g.x + g.width - flyout.panelWidth),
                                   Math.round(root.targetZone.y + root.targetZone.height + 6)),
                          root.workArea(w.output), w.output);
            // Keep it open for the screenshot; no cursor sits in the zone.
            root.targetZone = Qt.rect(0, 0, 100000, 100000);
            leave.stop();
        }
    }

    // Per-window drag signals; a Connections target disconnects cleanly
    // when the script is unloaded.
    Instantiator {
        model: root.watched
        delegate: Connections {
            required property var modelData
            target: modelData
            function onInteractiveMoveResizeStarted() {
                root.moving[modelData.internalId.toString()] = true;
                if (flyout.visible)
                    root.closeFlyout("drag");
                dwell.stop();
            }
            function onInteractiveMoveResizeFinished() {
                delete root.moving[modelData.internalId.toString()];
                root.quietUntil = Date.now() + 500;
            }
            function onMinimizedChanged() {
                if (root.target === modelData)
                    root.closeFlyout("minimized");
            }
            function onMaximizedChanged() {
                if (root.target === modelData)
                    root.closeFlyout("maximized");
            }
        }
    }

    Connections {
        target: Workspace
        function onCursorPosChanged() {
            root.pointerMoved();
        }
        function onWindowAdded(w) {
            root.refreshWatched();
        }
        function onWindowRemoved(w) {
            if (root.target === w)
                root.closeFlyout("window closed");
            root.refreshWatched();
        }
        function onWindowActivated(w) {
            if (flyout.visible && w && w.pid > 0 && w !== root.target)
                root.closeFlyout("other window activated");
        }
    }

    // Reload the options when they are applied in System Settings.
    Connections {
        target: Options
        function onConfigChanged() {
            cfg.load();
            root.log("options reloaded");
        }
    }

    Component.onCompleted: {
        refreshWatched();
        log("loaded, watching " + watched.length + " windows");
        if (devShow)
            devTimer.start();
    }
}
