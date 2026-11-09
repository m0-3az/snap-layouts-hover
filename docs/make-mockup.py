#!/usr/bin/env python3
"""Generate docs/flyout.svg, a mockup of the hover flyout.

The layout fractions mirror the catalog in
snap11hover/contents/ui/HoverBar.qml.
"""
from pathlib import Path

LAYOUTS = [
    [  # halves
        {"x": 0, "y": 0, "w": 1 / 2, "h": 1},
        {"x": 1 / 2, "y": 0, "w": 1 / 2, "h": 1},
    ],
    [  # 2/3 + 1/3
        {"x": 0, "y": 0, "w": 2 / 3, "h": 1},
        {"x": 2 / 3, "y": 0, "w": 1 / 3, "h": 1},
    ],
    [  # thirds
        {"x": 0, "y": 0, "w": 1 / 3, "h": 1},
        {"x": 1 / 3, "y": 0, "w": 1 / 3, "h": 1},
        {"x": 2 / 3, "y": 0, "w": 1 / 3, "h": 1},
    ],
    [  # 1/4 + 1/2 + 1/4
        {"x": 0, "y": 0, "w": 1 / 4, "h": 1},
        {"x": 1 / 4, "y": 0, "w": 1 / 2, "h": 1},
        {"x": 3 / 4, "y": 0, "w": 1 / 4, "h": 1},
    ],
    [  # left + right stacked
        {"x": 0, "y": 0, "w": 1 / 2, "h": 1},
        {"x": 1 / 2, "y": 0, "w": 1 / 2, "h": 1 / 2},
        {"x": 1 / 2, "y": 1 / 2, "w": 1 / 2, "h": 1 / 2},
    ],
    [  # quarters
        {"x": 0, "y": 0, "w": 1 / 2, "h": 1 / 2},
        {"x": 1 / 2, "y": 0, "w": 1 / 2, "h": 1 / 2},
        {"x": 0, "y": 1 / 2, "w": 1 / 2, "h": 1 / 2},
        {"x": 1 / 2, "y": 1 / 2, "w": 1 / 2, "h": 1 / 2},
    ],
    [  # right + left stacked
        {"x": 0, "y": 0, "w": 1 / 2, "h": 1 / 2},
        {"x": 0, "y": 1 / 2, "w": 1 / 2, "h": 1 / 2},
        {"x": 1 / 2, "y": 0, "w": 1 / 2, "h": 1},
    ],
    [  # main 2/3 + right stacked
        {"x": 0, "y": 0, "w": 2 / 3, "h": 1},
        {"x": 2 / 3, "y": 0, "w": 1 / 3, "h": 1 / 2},
        {"x": 2 / 3, "y": 1 / 2, "w": 1 / 3, "h": 1 / 2},
    ],
]

TILE_W, TILE_H = 210, 155
COLS, ROWS = 4, 2
TILE_GAP = 20
PAD = 20
GAP = 6


def pane_rects(layout):
    rects = []
    for s in layout:
        left = s["x"] > 0.001
        right = s["x"] + s["w"] < 0.999
        top = s["y"] > 0.001
        bottom = s["y"] + s["h"] < 0.999
        x = s["x"] * TILE_W + (GAP / 2 if left else 0)
        y = s["y"] * TILE_H + (GAP / 2 if top else 0)
        w = s["w"] * TILE_W - (GAP / 2 if left else 0) - (GAP / 2 if right else 0)
        h = s["h"] * TILE_H - (GAP / 2 if top else 0) - (GAP / 2 if bottom else 0)
        rects.append((x, y, w, h))
    return rects


def main():
    panel_w = 2 * PAD + COLS * TILE_W + (COLS - 1) * TILE_GAP
    panel_h = 2 * PAD + ROWS * TILE_H + (ROWS - 1) * TILE_GAP
    out = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{panel_w}" height="{panel_h}" '
        f'viewBox="0 0 {panel_w} {panel_h}" role="img" '
        'aria-label="Snap layout flyout with eight layouts">',
        f'  <rect x="0.5" y="0.5" width="{panel_w - 1}" height="{panel_h - 1}" rx="24" '
        'fill="#1b1e24" stroke="#3a3f49"/>',
    ]
    for i, layout in enumerate(LAYOUTS):
        tx = PAD + (i % COLS) * (TILE_W + TILE_GAP)
        ty = PAD + (i // COLS) * (TILE_H + TILE_GAP)
        out.append(f'  <g transform="translate({tx} {ty})">')
        for (x, y, w, h) in pane_rects(layout):
            out.append(
                f'    <rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" '
                'rx="10" fill="#2f333b" stroke="#9aa1ad" stroke-opacity="0.55"/>'
            )
        out.append("  </g>")
    out.append("</svg>")
    path = Path(__file__).resolve().parent / "flyout.svg"
    path.write_text("\n".join(out) + "\n")
    print(path)


if __name__ == "__main__":
    main()
