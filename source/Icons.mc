using Toybox.Graphics;
using Toybox.Lang;

//
// Icons.mc - small vector icons drawn with basic Graphics.Dc primitives only.
// Copied from Ritmo/Arctic Peak's Icons.mc (generic, not theme-specific).
//
module Icons {

    function drawSteps(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var soleW = size * 0.55;
        var soleH = size * 0.75;
        dc.fillRoundedRectangle(x + size * 0.20, y + size * 0.20, soleW, soleH, soleW * 0.45);
        var toeR = size * 0.10;
        dc.fillCircle(x + size * 0.30, y + size * 0.14, toeR);
        dc.fillCircle(x + size * 0.50, y + size * 0.08, toeR * 0.9);
        dc.fillCircle(x + size * 0.68, y + size * 0.14, toeR * 0.8);
    }

    function drawBattery(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, percent as Lang.Numeric, outlineColor as Lang.Number, fillColor as Lang.Number) as Void {
        var w = size;
        var h = size * 0.5;
        var nubW = size * 0.08;
        var nubH = h * 0.4;

        dc.setColor(outlineColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(x, y, w - nubW, h, 3);
        dc.fillRectangle(x + w - nubW, y + (h - nubH) / 2, nubW, nubH);

        var pct = percent;
        if (pct < 0) { pct = 0; }
        if (pct > 100) { pct = 100; }
        var pad = 3;
        var innerW = (w - nubW - pad * 2) * (pct / 100.0);
        if (innerW > 0) {
            dc.setColor(fillColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + pad, y + pad, innerW, h - pad * 2);
        }
    }

    function drawHeart(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var r = size * 0.28;
        dc.fillCircle(x + size * 0.32, y + size * 0.36, r);
        dc.fillCircle(x + size * 0.68, y + size * 0.36, r);
        dc.fillPolygon([
            [x + size * 0.06, y + size * 0.40],
            [x + size * 0.94, y + size * 0.40],
            [x + size * 0.50, y + size * 0.94]
        ]);
    }

    function drawFlame(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [x + size * 0.50, y + size * 0.02],
            [x + size * 0.78, y + size * 0.42],
            [x + size * 0.66, y + size * 0.40],
            [x + size * 0.80, y + size * 0.70],
            [x + size * 0.50, y + size * 0.98],
            [x + size * 0.20, y + size * 0.70],
            [x + size * 0.34, y + size * 0.40],
            [x + size * 0.22, y + size * 0.42]
        ]);
    }

    // Six new icons for the selectable stat-badge fields - same geometry
    // (and the same pre-shipping actual-size sanity check) as
    // santorini-sunset's Icons.mc, which added these first; see that
    // file's comment for the fuller reasoning.

    function drawDistance(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var y0 = y + size * 0.5;
        dc.drawLine(x + size * 0.05, y0, x + size * 0.35, y0);
        dc.drawLine(x + size * 0.50, y0, x + size * 0.72, y0);
        dc.fillPolygon([
            [x + size * 0.72, y0 - size * 0.14],
            [x + size * 0.72, y0 + size * 0.14],
            [x + size * 0.95, y0]
        ]);
    }

    function drawFloors(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var stepW = size * 0.26;
        var stepH = size * 0.22;
        var gap = size * 0.02;
        var i = 0;
        while (i < 3) {
            var sx = x + size * 0.08 + i * (stepW + gap);
            var sy = y + size - (i + 1) * (stepH + gap) + gap;
            dc.fillRectangle(sx, sy, stepW, (y + size) - sy);
            i += 1;
        }
    }

    function drawActiveMinutes(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var cx = x + size * 0.5;
        var cy = y + size * 0.55;
        var r = size * 0.36;
        dc.setPenWidth(2);
        dc.drawCircle(cx, cy, r);
        dc.fillRectangle(cx - size * 0.09, y + size * 0.02, size * 0.18, size * 0.12);
        dc.drawLine(cx, cy, cx, cy - r * 0.7);
    }

    function drawStress(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var y0 = y + size * 0.55;
        dc.drawLine(x + size * 0.05, y0, x + size * 0.28, y0);
        dc.drawLine(x + size * 0.28, y0, x + size * 0.40, y0 - size * 0.30);
        dc.drawLine(x + size * 0.40, y0 - size * 0.30, x + size * 0.55, y0 + size * 0.30);
        dc.drawLine(x + size * 0.55, y0 + size * 0.30, x + size * 0.68, y0);
        dc.drawLine(x + size * 0.68, y0, x + size * 0.95, y0);
    }

    function drawTemperature(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var tubeW = size * 0.22;
        var tubeX = x + size * 0.5 - tubeW * 0.5;
        var tubeTop = y + size * 0.05;
        var tubeBottom = y + size * 0.62;
        dc.fillRoundedRectangle(tubeX, tubeTop, tubeW, tubeBottom - tubeTop, tubeW * 0.5);
        dc.fillCircle(x + size * 0.5, y + size * 0.80, size * 0.20);
    }

    function drawWorldClock(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var cx = x + size * 0.5;
        var cy = y + size * 0.5;
        var r = size * 0.42;
        dc.setPenWidth(2);
        dc.drawCircle(cx, cy, r);
        dc.setPenWidth(1);
        dc.drawLine(cx, cy - r, cx, cy + r);
        dc.drawLine(cx - r, cy, cx + r, cy);
    }

    // Three more icons for the "second hand / move bar / sunrise-sunset /
    // step ring" round's two new selectable fields - same pre-shipping
    // actual-size check as the six above (see verify/new_badge_fields.png
    // and verify/sun_icons_v2_zoomed.png), not just eyeballed at full size.

    // 5-bar ascending chart, filled up to `level` (0-5, Garmin's own
    // MOVE_BAR_LEVEL_MIN/MAX range for ActivityMonitor.Info.moveBarLevel -
    // see View.mc's moveBarText()). Unfilled bars are outline-only rather
    // than a second dim color, matching every other icon in this file
    // (all take a single `color` - only drawBattery needs a second color,
    // passed from the call site instead of hardcoded here).
    function drawMoveBar(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, level as Lang.Number, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var barW = size * 0.15;
        var gap = size * 0.06;
        var baseY = y + size;
        var heights = [0.35, 0.5, 0.65, 0.8, 1.0];
        var i = 0;
        while (i < 5) {
            var bx = x + i * (barW + gap);
            var bh = size * 0.55 * heights[i];
            if (i < level) {
                dc.fillRectangle(bx, baseY - bh, barW, bh);
            } else {
                dc.setPenWidth(1);
                dc.drawRectangle(bx, baseY - bh, barW, bh);
            }
            i += 1;
        }
    }

    // Shared horizon-line-plus-sun motif for drawSunrise/drawSunset, direction
    // told apart by a bold arrow to the right (up for sunrise, down for
    // sunset) rather than by anything above/below the sun itself - an
    // earlier version stacked a thin arrow directly above a small sun and it
    // was unreadable at ~17px real badge-icon size (see
    // verify/new_badge_fields.png's first version vs
    // verify/sun_icons_v2_zoomed.png's fix). Not a real physical horizon -
    // see View.mc's sunriseText()/sunsetText() for what these fields
    // actually compute and the honest caveats around it (needs a location,
    // which a watch face may not have).
    function drawSunHorizon(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, color as Lang.Number, rising as Lang.Boolean) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var horizonY = y + size * 0.62;
        dc.setPenWidth(2);
        dc.drawLine(x + size * 0.02, horizonY, x + size * 0.62, horizonY);
        var sunR = size * 0.22;
        var scx = x + size * 0.32;
        dc.fillCircle(scx, horizonY, sunR);

        var ax = x + size * 0.82;
        if (rising) {
            dc.fillPolygon([
                [ax, y + size * 0.05],
                [ax - size * 0.16, y + size * 0.42],
                [ax + size * 0.16, y + size * 0.42]
            ]);
        } else {
            dc.fillPolygon([
                [ax, y + size * 0.42],
                [ax - size * 0.16, y + size * 0.05],
                [ax + size * 0.16, y + size * 0.05]
            ]);
        }
    }

    function drawSunrise(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, color as Lang.Number) as Void {
        drawSunHorizon(dc, x, y, size, color, true);
    }

    function drawSunset(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, color as Lang.Number) as Void {
        drawSunHorizon(dc, x, y, size, color, false);
    }

    // drawSoccerBall() removed: after three rounds of this hand-drawn
    // vector version all looking wrong once actually rendered (a flower,
    // a pinwheel, then something that read as a spider), the ball is now
    // a rasterized bitmap resource instead
    // (resources/drawables/soccer_ball.png, generated and visually
    // checked ahead of time by tools/gen_soccer_ball.py - see
    // RossoneroView.mc's drawTopIcon() and README.md).
}
