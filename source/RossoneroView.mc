using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Lang;
using Toybox.ActivityMonitor;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Application.Properties;
using Toybox.Timer;
using Toybox.Math;

//
// RossoneroView.mc - draws the whole watch face.
//
// Store-submittable sibling of milan-personal: same layout and code
// structure, but the background is a plain vertical red/black stripe
// pattern, a generic soccer-ball icon (not the club crest), and a
// perimeter tick ring - no crest bitmap, no club wordmark/founding year
// anywhere. See README.md for why that split exists.
//
class RossoneroView extends WatchUi.WatchFace {

    private var _isAwake as Lang.Boolean = false;
    private var _tickTimer as Timer.Timer?;
    private var _ballIcon as Graphics.BitmapType?;

    // ---- Layout constants (fractions of screen width/height) ------------
    // Second pass after seeing this run in the simulator: added a top icon
    // (soccer ball, replacing the empty space that used to sit above the
    // date), which pushed DATE_Y/TIME_Y down from the original values
    // (0.225/0.40). Kept the same proven TIME_Y - DATE_Y gap of 0.175 used
    // throughout this project's siblings. STATS_RADIUS bumped from 0.09 to
    // 0.10 (see drawStatBadge for the bigger fix - the numbers were
    // rendering too close to the badge's bottom edge because drawText's
    // default top-anchor doesn't account for font height, not really a
    // sizing problem - VCENTER fixes the root cause, the radius bump just
    // gives a bit more breathing room on top of that).
    // Fourth pass: the 0.40 TIME_Y from the previous round still
    // overlapped in your next screenshot. That means FONT_NUMBER_HOT
    // actually renders taller than the ~0.21h I'd assumed twice now -
    // going by the overlap visible in that screenshot, it's closer to
    // 0.30h. Rather than nudge by another few hundredths and risk a third
    // near-miss, recalculated the whole icon-through-battery stack around
    // that larger number: icon shrunk and pulled up a bit, TIME_Y moved
    // up to 0.32 so its bottom (~0.62) sits clear of the badges (top at
    // STATS_Y 0.745 - STATS_RADIUS 0.095 = 0.65), and DATE_Y put back at
    // the original pre-icon value of 0.225 to make the room for that
    // without touching the icon-to-date gap much. Still paper math, not a
    // device measurement - if this is still tight, the font really is
    // that tall and the next move would be dropping to FONT_NUMBER_MEDIUM
    // instead of chasing the gap further.
    // Icon grown from 0.12 to 0.15 and pulled up to 0.05 to compensate
    // (bottom edge stays at the same 0.20 as before, so nothing below it
    // needed to move) - the ball's pentagon detail was rendering as
    // blobby dots at the smaller size. See Icons.mc for the redesigned,
    // bolder ball pattern that goes with the bigger icon.
    const ICON_Y = 0.05;
    const ICON_SIZE = 0.15;
    const DATE_Y = 0.225;
    const TIME_Y = 0.32;
    const STATS_Y = 0.745;
    const STATS_RADIUS = 0.095;
    const STATS_SPACING = 0.24;
    // Badge bottom is now STATS_Y + STATS_RADIUS = 0.84; kept a bit more
    // gap above the bottom bezel than the last pass.
    const BATTERY_Y = 0.875;

    // Perimeter tick ring - same radius Ritmo's step-goal ring used
    // (0.46, proven to hug the bezel without clipping on a round display),
    // repurposed here as a static ring of tick marks instead of a
    // progress arc. Every 5th tick is a longer/thicker red "major" tick;
    // the rest are short dim ones - approximates the reference mockup's
    // red/white dash ring without needing to match it tick-for-tick.
    const TICK_RADIUS = 0.46;
    const TICK_COUNT = 40;
    const TICK_LEN_MINOR = 0.018;
    const TICK_LEN_MAJOR = 0.032;
    const TICK_MAJOR_EVERY = 5;

    const FG = 0xf5f5f5;
    const DIM = 0xd8b8b8;
    const ACCENT = 0xe23b3b;

    function initialize() {
        WatchFace.initialize();
        // Loaded once here rather than per-frame - same reasoning as
        // milan-personal's crest and santorini-sunset's background photo.
        _ballIcon = WatchUi.loadResource(Rez.Drawables.SoccerBall) as Graphics.BitmapType;
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onShow() as Void {
    }

    function onHide() as Void {
        stopTicking();
    }

    function onExitSleep() as Void {
        _isAwake = true;
        startTicking();
    }

    function onEnterSleep() as Void {
        _isAwake = false;
        stopTicking();
        WatchUi.requestUpdate();
    }

    function startTicking() as Void {
        if (_tickTimer == null) {
            _tickTimer = new Timer.Timer();
        }
        _tickTimer.start(method(:onTick), 1000, true);
    }

    function stopTicking() as Void {
        if (_tickTimer != null) {
            _tickTimer.stop();
        }
    }

    function onTick() as Void {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        draw(dc, _isAwake);
    }

    function draw(dc as Graphics.Dc, awake as Lang.Boolean) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (awake) {
            drawStripes(dc, w, h);
            drawPerimeterTicks(dc, w, h);
        }
        // Always-on/low-power: no full-canvas stripe fill or tick ring -
        // same AMOLED battery/burn-in reasoning as Ritmo/Arctic Peak's
        // dimmed always-on frame. Plain black background instead.

        var now = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);

        drawTopIcon(dc, w, h, awake);
        drawDate(dc, w, h, now, awake);
        drawTime(dc, w, h, awake);

        if (awake) {
            drawStats(dc, w, h);
            drawBattery(dc, w, h);
        } else {
            drawLowPowerStats(dc, w, h);
        }
    }

    // ---- Background: vertical red/black stripes ---------------------------
    // Plain color-block stripes, no imagery, no wordmark - this is the
    // whole reason milan-personal and this project are split. See
    // README.md.
    function drawStripes(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number) as Void {
        var stripeCount = 7;
        var stripeW = w.toFloat() / stripeCount;
        for (var i = 0; i < stripeCount; i += 1) {
            if (i % 2 == 0) {
                // Bumped from 0x1a0000 - that was close enough to pure
                // black that the stripe pattern barely read on the actual
                // screen. Still dark, just a bit more visibly red now.
                dc.setColor(0x330000, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            }
            dc.fillRectangle(i * stripeW, 0, stripeW + 1, h);
        }

        // REMOVED: two vertical accent dashes used to be drawn here at
        // h*0.30-0.35 and h*0.62-0.67, meant to flank the time. They were
        // never repositioned when the top icon was added and DATE_Y/TIME_Y
        // moved down (see the layout-constants comment above) - the first
        // one ended up landing right on top of the date text, exactly the
        // "vertical dash on top of the day of the week" bug reported from
        // a real screenshot. Rather than re-tune two more magic numbers
        // into an already-tight vertical layout, just dropped them - the
        // date-flanking dashes in drawDate() and the perimeter tick ring
        // already provide the red accent-line flourish this was going for.
    }

    // Ring of small tick marks hugging the bezel, alternating a short dim
    // tick with a longer/thicker red one every 5th position - the
    // "circumference red/white dashes" from the reference mockup. Uses
    // the same radius Ritmo's step-goal ring used at this same distance
    // from center without clipping.
    function drawPerimeterTicks(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number) as Void {
        var cx = w * 0.5;
        var cy = h * 0.5;
        var r = w * TICK_RADIUS;

        for (var i = 0; i < TICK_COUNT; i += 1) {
            var angleDeg = i * (360.0 / TICK_COUNT);
            var rad = Math.toRadians(angleDeg);
            var cosA = Math.cos(rad);
            var sinA = Math.sin(rad);
            var isMajor = (i % TICK_MAJOR_EVERY == 0);
            var len = w * (isMajor ? TICK_LEN_MAJOR : TICK_LEN_MINOR);

            var outerX = cx + cosA * r;
            var outerY = cy + sinA * r;
            var innerX = cx + cosA * (r - len);
            var innerY = cy + sinA * (r - len);

            dc.setColor(isMajor ? ACCENT : DIM, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(isMajor ? 3 : 1);
            dc.drawLine(innerX, innerY, outerX, outerY);
        }
    }

    // ---- Top icon: generic soccer ball, not the club crest -----------------
    // See README.md for why - this project is the Store-submittable half
    // of the split with milan-personal, so no team-specific imagery here
    // at all, just a generic sport symbol nobody owns.
    // FOURTH revision of this icon: three rounds of hand-drawn Monkey C
    // vector pentagons (a flower, then a pinwheel, then something that
    // read as a spider) all looked wrong at this render size, and I have
    // no way to preview Monkey C vector output before shipping it. Now a
    // rasterized bitmap generated and visually checked ahead of time
    // (tools/gen_soccer_ball.py) - see README.md. Its colors (black/
    // white) are fixed rather than following FG/ACCENT like the rest of
    // the face, same as a real ball's colors wouldn't change with the
    // watch face's theme.
    function drawTopIcon(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number, awake as Lang.Boolean) as Void {
        if (_ballIcon == null) {
            return;
        }
        var size = w * ICON_SIZE;
        var x = w * 0.5 - size * 0.5;
        var y = h * ICON_Y;
        dc.drawScaledBitmap(x, y, size, size, _ballIcon);
    }

    // ---- Date -------------------------------------------------------------

    function drawDate(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number, now as Gregorian.Info, awake as Lang.Boolean) as Void {
        var weekday = now.day_of_week as Lang.String;
        var day = now.day as Lang.Number;
        var str = weekday.toUpper() + " " + day.format("%d");
        var color = awake ? DIM : 0x777777;

        var textWidth = dc.getTextWidthInPixels(str, Graphics.FONT_SMALL);
        var dashGap = textWidth * 0.5 + w * 0.03;

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w * 0.5, h * DATE_Y, Graphics.FONT_SMALL, str, Graphics.TEXT_JUSTIFY_CENTER);

        if (awake) {
            // BUG FIXED: this used to draw with whatever color drawText()
            // above left set (DIM), rendering as a pale dash instead of
            // the intended red accent - caught from a real screenshot
            // where these came out white. setColor(ACCENT, ...) here is
            // the fix.
            dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            var y = h * DATE_Y + dc.getTextDimensions(str, Graphics.FONT_SMALL)[1] * 0.5;
            dc.drawLine(w * 0.5 - dashGap - w * 0.05, y, w * 0.5 - dashGap, y);
            dc.drawLine(w * 0.5 + dashGap, y, w * 0.5 + dashGap + w * 0.05, y);
        }
    }

    // ---- Time: hour in fg white, colon+minute in accent red ---------------

    function drawTime(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number, awake as Lang.Boolean) as Void {
        var clockTime = System.getClockTime();
        var hour = clockTime.hour;
        if (!System.getDeviceSettings().is24Hour) {
            var h12 = hour % 12;
            if (h12 == 0) { h12 = 12; }
            hour = h12;
        }
        var hourStr = hour.format("%02d");
        var minStr = clockTime.min.format("%02d");

        var showColon = true;
        var showSeconds = Properties.getValue("ShowSeconds") as Lang.Boolean?;
        if (awake && showSeconds != null && showSeconds) {
            showColon = (clockTime.sec % 2 == 0);
        }
        var colonStr = showColon ? ":" : " ";

        var timeStr = hourStr + colonStr + minStr;
        var totalWidth = dc.getTextWidthInPixels(timeStr, Graphics.FONT_NUMBER_HOT);
        var hourWidth = dc.getTextWidthInPixels(hourStr, Graphics.FONT_NUMBER_HOT);
        var startX = w * 0.5 - totalWidth / 2;
        var y = h * TIME_Y;

        var fgColor = awake ? FG : 0xdddddd;
        var accentColor = awake ? ACCENT : 0x996666;

        dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX, y, Graphics.FONT_NUMBER_HOT, hourStr, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(accentColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX + hourWidth, y, Graphics.FONT_NUMBER_HOT, colonStr + minStr, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // ---- Stats: fixed steps / heart rate / calories badges -----------------

    function drawStats(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number) as Void {
        var info = ActivityMonitor.getInfo();
        var steps = (info.steps != null) ? info.steps : 0;
        var calories = (info.calories != null) ? info.calories : 0;
        var hr = readHeartRate();
        var hrText = (hr != null) ? hr.format("%d") : "--";

        var cy = h * STATS_Y;
        var r = w * STATS_RADIUS;
        var spacing = w * STATS_SPACING;
        var cxMid = w * 0.5;

        drawStatBadge(dc, cxMid - spacing, cy, r, :steps, formatSteps(steps));
        drawStatBadge(dc, cxMid, cy, r, :heart, hrText);
        drawStatBadge(dc, cxMid + spacing, cy, r, :flame, calories.format("%d"));
    }

    function formatSteps(steps as Lang.Number) as Lang.String {
        if (steps >= 1000) {
            var thousands = steps / 1000.0;
            return thousands.format("%.1f") + "K";
        }
        return steps.format("%d");
    }

    // FIXED after a real screenshot showed the numbers sitting too close
    // to each badge's bottom edge: the old code drew the number with
    // drawText's default top-anchor at a small offset below center,
    // without accounting for the font's actual rendered height - on a
    // circle this small (r is only ~9-10% of screen width), FONT_TINY
    // turned out to occupy a much bigger fraction of that space than the
    // eyeballed offset assumed, pushing the number almost to the rim.
    // Switched to TEXT_JUSTIFY_VCENTER, which centers on the anchor point
    // regardless of actual font height, so this doesn't depend on
    // guessing a pixel height at all. Icon and number are now placed
    // symmetrically above/below the badge's vertical center instead.
    function drawStatBadge(dc as Graphics.Dc, cx as Lang.Float, cy as Lang.Float, r as Lang.Float, icon as Lang.Symbol, text as Lang.String) as Void {
        dc.setColor(0x1a0000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(cx, cy, r);

        var iconSize = r * 0.42;
        var iconTopY = cy - r * 0.62;
        if (icon == :steps) {
            Icons.drawSteps(dc, cx - iconSize * 0.5, iconTopY, iconSize, ACCENT);
        } else if (icon == :heart) {
            Icons.drawHeart(dc, cx - iconSize * 0.5, iconTopY, iconSize, ACCENT);
        } else if (icon == :flame) {
            Icons.drawFlame(dc, cx - iconSize * 0.5, iconTopY, iconSize, ACCENT);
        }

        dc.setColor(FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + r * 0.28, Graphics.FONT_TINY, text,
            Graphics.TEXT_JUSTIFY_CENTER + Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawLowPowerStats(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number) as Void {
        var info = ActivityMonitor.getInfo();
        var steps = (info.steps != null) ? info.steps : 0;
        var battery = System.getSystemStats().battery;
        var line = steps.format("%d") + " · " + battery.format("%d") + "%";
        dc.setColor(0x999999, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w * 0.5, h * STATS_Y, Graphics.FONT_TINY, line, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ---- Battery readout ----------------------------------------------------

    // Icon and text now share one explicit vertical center (battYCenter)
    // instead of two separately-eyeballed offsets - a small polish after
    // feedback that this looked less tidy than the reference mockup's
    // battery readout.
    function drawBattery(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number) as Void {
        var battery = System.getSystemStats().battery;
        var text = battery.format("%d") + "%";
        var iconSize = w * 0.055;
        var textWidth = dc.getTextWidthInPixels(text, Graphics.FONT_XTINY);
        var groupWidth = iconSize + w * 0.02 + textWidth;
        var x = w * 0.5 - groupWidth * 0.5;
        var battYCenter = h * BATTERY_Y;

        Icons.drawBattery(dc, x, battYCenter - iconSize * 0.5, iconSize, battery, DIM, ACCENT);
        dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + iconSize + w * 0.02, battYCenter, Graphics.FONT_XTINY, text,
            Graphics.TEXT_JUSTIFY_LEFT + Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function readHeartRate() as Lang.Number? {
        if (!(Toybox has :ActivityMonitor) || !(ActivityMonitor has :getHeartRateHistory)) {
            return null;
        }
        var it = ActivityMonitor.getHeartRateHistory(1, true);
        var sample = it.next();
        if (sample == null || sample.heartRate == null) { return null; }
        if (sample.heartRate == ActivityMonitor.INVALID_HR_SAMPLE) { return null; }
        return sample.heartRate;
    }
}
