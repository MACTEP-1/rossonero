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

    // drawSoccerBall() removed: after three rounds of this hand-drawn
    // vector version all looking wrong once actually rendered (a flower,
    // a pinwheel, then something that read as a spider), the ball is now
    // a rasterized bitmap resource instead
    // (resources/drawables/soccer_ball.png, generated and visually
    // checked ahead of time by tools/gen_soccer_ball.py - see
    // RossoneroView.mc's drawTopIcon() and README.md).
}
