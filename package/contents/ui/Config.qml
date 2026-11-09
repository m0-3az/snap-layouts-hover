/*
 * Options, read from the script's config page (System Settings > Window
 * Management > KWin Scripts > Snap Layouts Hover > Configure).
 */
import QtQuick
import org.kde.kwin

QtObject {
    property bool enabled: true
    // Width of the caption strip that triggers the flyout, from the right edge.
    property int zoneWidth: 72
    // 0 means "use the titlebar height".
    property int zoneHeight: 0
    // How long the pointer must rest on the strip.
    property int delay: 250
    // Fill the other zones after a zone was clicked.
    property bool autoFill: true
    // Hide the flyout while only one window is open.
    property bool needsOthers: true

    function load() {
        enabled = KWin.readConfig("HoverEnabled", true);
        zoneWidth = KWin.readConfig("ZoneWidth", 72);
        zoneHeight = KWin.readConfig("ZoneHeight", 0);
        delay = KWin.readConfig("HoverDelay", 250);
        autoFill = KWin.readConfig("AutoFill", true);
        needsOthers = KWin.readConfig("NeedsOthers", true);
    }

    Component.onCompleted: load()
}
