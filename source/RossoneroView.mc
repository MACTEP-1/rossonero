using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Lang;
using Toybox.ActivityMonitor;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Application.Properties;
using Toybox.Timer;

//
// RossoneroView.mc - draws the whole watch face.
//
// Store-submittable sibling of milan-personal: same layout and code
// structure, but the background is a plain vertical red/black stripe
// pattern (no crest bitmap, no club wordmark/founding year) - see
// README.md for why that split exists. Architecture mirrors Arctic Peak
// (fraction-of-screen layout, awake/asleep split, 1Hz timer only while
// awake) - see that project's comments for the reasoning, not repeated
// here.
//
class RossoneroView extends WatchUi.WatchFace {

    private var _isAwake as Lang.Boolean = false;
    private var _tickTimer as Timer.Timer?;

    // ---- Layout constants (fractions of screen width/height) ------------
    // Deliberately reusing Arctic Peak's exact proportions (see that
    // project's ArcticPeakView.mc for the chord-width reasoning) even
    // though this face has no top icon and could technically start a
    // little higher - matching numbers that already got that reasoning
    // pass felt lower-risk than inventing new ones, and the small gap of
    // empty space above the date is harmless.
    const DATE_Y = 0.225;
    const TIME_Y = 0.40;
    const STATS_Y = 0.76;
    const STATS_RADIUS = 0.09;
    const STATS_SPACING = 0.24;
    const BATTERY_Y = 0.905;

    const FG = 0xf5f5f5;
    const DIM = 0xd8b8b8;
    const ACCENT = 0xe23b3b;

    function initialize() {
        WatchFace.initialize();
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
        }
        // Always-on/low-power: no full-canvas stripe fill - same AMOLED
        // battery/burn-in reasoning as Ritmo/Arctic Peak's dimmed
        // always-on frame. Plain black background instead.

        var now = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);

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
                dc.setColor(0x1a0000, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            }
            dc.fillRectangle(i * stripeW, 0, stripeW + 1, h);
        }

        // Two thin accent lines flanking the time, a small flourish rather
        // than flat stripes-only.
        dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(w * 0.5, h * 0.30, w * 0.5, h * 0.35);
        dc.drawLine(w * 0.5, h * 0.62, w * 0.5, h * 0.67);
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

    function drawStatBadge(dc as Graphics.Dc, cx as Lang.Float, cy as Lang.Float, r as Lang.Float, icon as Lang.Symbol, text as Lang.String) as Void {
        dc.setColor(0x1a0000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(cx, cy, r);

        var iconSize = r * 2.0 * 0.30;
        var iconY = cy - r * 0.55;
        if (icon == :steps) {
            Icons.drawSteps(dc, cx - iconSize * 0.5, iconY, iconSize, ACCENT);
        } else if (icon == :heart) {
            Icons.drawHeart(dc, cx - iconSize * 0.5, iconY, iconSize, ACCENT);
        } else if (icon == :flame) {
            Icons.drawFlame(dc, cx - iconSize * 0.5, iconY, iconSize, ACCENT);
        }

        dc.setColor(FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + r * 0.08, Graphics.FONT_TINY, text, Graphics.TEXT_JUSTIFY_CENTER);
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

    function drawBattery(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number) as Void {
        var battery = System.getSystemStats().battery;
        var text = battery.format("%d") + "%";
        var iconSize = w * 0.05;
        var textWidth = dc.getTextWidthInPixels(text, Graphics.FONT_XTINY);
        var groupWidth = iconSize + w * 0.02 + textWidth;
        var x = w * 0.5 - groupWidth * 0.5;
        var y = h * BATTERY_Y;

        Icons.drawBattery(dc, x, y - iconSize * 0.25, iconSize, battery, DIM, ACCENT);
        dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + iconSize + w * 0.02, y - iconSize * 0.15, Graphics.FONT_XTINY, text, Graphics.TEXT_JUSTIFY_LEFT);
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
