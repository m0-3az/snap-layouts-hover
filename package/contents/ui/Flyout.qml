/*
 * The layout flyout: a dark panel with a 4 x 2 grid of layout previews.
 *
 * It is opened on hover, so unlike the drag-time overlays it is a real
 * window and takes mouse input: the MouseArea below tracks the hovered
 * zone and reports clicks.
 */
import QtQuick
import org.kde.plasma.core as PlasmaCore

PlasmaCore.Dialog {
    id: flyout

    required property QtObject cfg

    // Every layout is a list of zones in screen fractions:
    // { x, y, w, h }. Row-major in the preview grid.
    readonly property var layouts: [
        // 1. halves
        [
            { "x": 0, "y": 0, "w": 1 / 2, "h": 1 },
            { "x": 1 / 2, "y": 0, "w": 1 / 2, "h": 1 }
        ],
        // 2. two thirds + one third
        [
            { "x": 0, "y": 0, "w": 2 / 3, "h": 1 },
            { "x": 2 / 3, "y": 0, "w": 1 / 3, "h": 1 }
        ],
        // 3. thirds
        [
            { "x": 0, "y": 0, "w": 1 / 3, "h": 1 },
            { "x": 1 / 3, "y": 0, "w": 1 / 3, "h": 1 },
            { "x": 2 / 3, "y": 0, "w": 1 / 3, "h": 1 }
        ],
        // 4. wide middle
        [
            { "x": 0, "y": 0, "w": 1 / 4, "h": 1 },
            { "x": 1 / 4, "y": 0, "w": 1 / 2, "h": 1 },
            { "x": 3 / 4, "y": 0, "w": 1 / 4, "h": 1 }
        ],
        // 5. left half, right split
        [
            { "x": 0, "y": 0, "w": 1 / 2, "h": 1 },
            { "x": 1 / 2, "y": 0, "w": 1 / 2, "h": 1 / 2 },
            { "x": 1 / 2, "y": 1 / 2, "w": 1 / 2, "h": 1 / 2 }
        ],
        // 6. quarters
        [
            { "x": 0, "y": 0, "w": 1 / 2, "h": 1 / 2 },
            { "x": 1 / 2, "y": 0, "w": 1 / 2, "h": 1 / 2 },
            { "x": 0, "y": 1 / 2, "w": 1 / 2, "h": 1 / 2 },
            { "x": 1 / 2, "y": 1 / 2, "w": 1 / 2, "h": 1 / 2 }
        ],
        // 7. right half, left split
        [
            { "x": 0, "y": 0, "w": 1 / 2, "h": 1 / 2 },
            { "x": 0, "y": 1 / 2, "w": 1 / 2, "h": 1 / 2 },
            { "x": 1 / 2, "y": 0, "w": 1 / 2, "h": 1 }
        ],
        // 8. main 2/3, right split
        [
            { "x": 0, "y": 0, "w": 2 / 3, "h": 1 },
            { "x": 2 / 3, "y": 0, "w": 1 / 3, "h": 1 / 2 },
            { "x": 2 / 3, "y": 1 / 2, "w": 1 / 3, "h": 1 / 2 }
        ]
    ]

    // Panel geometry: 4 columns, 96 x 62 previews.
    readonly property int columns: 4
    readonly property int rows: Math.ceil(layouts.length / columns)
    readonly property int tileWidth: 96
    readonly property int tileHeight: 62
    readonly property int padding: 14
    readonly property int spacing: 12
    readonly property int zoneGap: 5
    readonly property int panelWidth: 2 * padding + columns * tileWidth + (columns - 1) * spacing
    readonly property int panelHeight: 2 * padding + rows * tileHeight + (rows - 1) * spacing

    property rect area: Qt.rect(0, 0, 0, 0)
    property var screen: null
    property int hoverLayout: -1
    property int hoverZone: -1

    signal zoneClicked(int layoutIndex, int zoneIndex)

    function showAt(anchor, areaRect, output) {
        area = areaRect;
        screen = output;
        hoverLayout = -1;
        hoverZone = -1;
        visible = true;
        // A Dialog re-centers itself when shown, so place it afterwards.
        x = Math.max(area.x + 4, Math.min(Math.round(anchor.x), area.x + area.width - panelWidth - 4));
        y = Math.max(area.y + 4, Math.min(Math.round(anchor.y), area.y + area.height - panelHeight - 4));
    }

    function hide() {
        visible = false;
        hoverLayout = -1;
        hoverZone = -1;
    }

    function contains(p) {
        const m = 6;
        return visible && p.x >= x - m && p.x < x + width + m
            && p.y >= y - m && p.y < y + height + m;
    }

    // Zone under a point inside the panel.
    function updateHover(px, py) {
        hoverLayout = -1;
        hoverZone = -1;
        for (let li = 0; li < layouts.length; li++) {
            const tx = padding + (li % columns) * (tileWidth + spacing);
            const ty = padding + Math.floor(li / columns) * (tileHeight + spacing);
            if (px < tx || px >= tx + tileWidth || py < ty || py >= ty + tileHeight)
                continue;
            const fx = (px - tx) / tileWidth;
            const fy = (py - ty) / tileHeight;
            const zones = layouts[li];
            for (let zi = 0; zi < zones.length; zi++) {
                const z = zones[zi];
                if (fx >= z.x && fx < z.x + z.w && fy >= z.y && fy < z.y + z.h) {
                    hoverLayout = li;
                    hoverZone = zi;
                    return;
                }
            }
        }
    }

    // A zone as a screen rectangle inside the target screen's work area.
    function zoneRect(li, zi) {
        const z = layouts[li][zi];
        const x0 = Math.round(area.x + z.x * area.width);
        const x1 = Math.round(area.x + (z.x + z.w) * area.width);
        const y0 = Math.round(area.y + z.y * area.height);
        const y1 = Math.round(area.y + (z.y + z.h) * area.height);
        return Qt.rect(x0, y0, x1 - x0, y1 - y0);
    }

    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    location: PlasmaCore.Types.Floating
    backgroundHints: PlasmaCore.Types.NoBackground
    type: PlasmaCore.Dialog.Normal
    visible: false

    Rectangle {
        width: flyout.panelWidth
        height: flyout.panelHeight
        radius: 14
        color: "#1b1e24"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.14)

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: function(mouse) { flyout.updateHover(mouse.x, mouse.y) }
            onExited: {
                flyout.hoverLayout = -1;
                flyout.hoverZone = -1;
            }
            onClicked: {
                if (flyout.hoverLayout >= 0 && flyout.hoverZone >= 0)
                    flyout.zoneClicked(flyout.hoverLayout, flyout.hoverZone);
            }
        }

        Grid {
            x: flyout.padding
            y: flyout.padding
            columns: flyout.columns
            spacing: flyout.spacing

            Repeater {
                model: flyout.layouts.length

                delegate: Item {
                    id: preview

                    required property int index
                    readonly property var zones: flyout.layouts[index]

                    width: flyout.tileWidth
                    height: flyout.tileHeight

                    Repeater {
                        model: preview.zones.length

                        delegate: Rectangle {
                            required property int index
                            readonly property var zone: preview.zones[index]
                            readonly property bool active: flyout.hoverLayout === preview.index
                                                          && flyout.hoverZone === index
                            readonly property int gap: flyout.zoneGap
                            readonly property real x0: Math.round(zone.x * preview.width)
                            readonly property real x1: Math.round((zone.x + zone.w) * preview.width)
                            readonly property real y0: Math.round(zone.y * preview.height)
                            readonly property real y1: Math.round((zone.y + zone.h) * preview.height)

                            x: x0 + (zone.x > 0.001 ? Math.floor(gap / 2) : 0)
                            y: y0 + (zone.y > 0.001 ? Math.floor(gap / 2) : 0)
                            width: Math.max(2, x1 - x0
                                            - (zone.x > 0.001 ? Math.floor(gap / 2) : 0)
                                            - (zone.x + zone.w < 0.999 ? Math.ceil(gap / 2) : 0))
                            height: Math.max(2, y1 - y0
                                             - (zone.y > 0.001 ? Math.floor(gap / 2) : 0)
                                             - (zone.y + zone.h < 0.999 ? Math.ceil(gap / 2) : 0))
                            radius: 6
                            color: active ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(1, 1, 1, 0.10)
                            border.width: 1
                            border.color: active ? "white" : Qt.rgba(1, 1, 1, 0.34)

                            Behavior on color {
                                ColorAnimation { duration: 90 }
                            }
                        }
                    }
                }
            }
        }
    }
}
