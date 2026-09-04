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
using Toybox.Weather;
using Toybox.Activity;
using Toybox.Position;

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
    // Long-press-to-swap-fields state - toggled by WatchFaceInputDelegate.
    // Deliberately NOT persisted (no Properties.setValue here): resets to
    // the primary field set on every app relaunch, same behavior as most
    // watch faces with a similar toggle and simplest to reason about
    // without a compiler to check persistence edge cases against.
    private var _showAltFields as Lang.Boolean = false;

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

    // You asked for the left/right badges to sit a little higher than the
    // middle one, so the row echoes the round bezel instead of reading as
    // a flat line across it. The two outer badges get lifted by this many
    // screen-heights; the middle one stays at STATS_Y. Deliberately the
    // SAME in Digital and Analog mode - a lift that only applied to
    // Analog would mean the badges visibly jump position when you toggle
    // Clock Style, which is worse than the flat-row look this replaces.
    // Picked via the same PIL-mockup check as everything else added this
    // session: rendered the lifted row against both the digital
    // FONT_NUMBER_HOT time and the new hour-number ring, at several lift
    // values. Turned out there was a lot more headroom than expected in
    // both directions - the digital time's actual bottom edge sits well
    // above where the badges start, and lifting the OUTER badges moves
    // them away from the tight 4/5/7/8 o'clock numbers (nowhere near the
    // 1/2/10/11 numbers up near the icon) - so the limiting factor here
    // was purely "how much before it stops looking like 'a little'," not
    // a collision. 0.035 read as a clear, deliberate arc without looking
    // like a mistake.
    const STATS_OUTER_LIFT = 0.035;

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

    // Hour numbers for Analog clock style, reusing the perimeter tick
    // ring's own radius rather than tuning a second one from scratch.
    // Skips "12" on purpose - the top icon already occupies that spot,
    // and a real PIL-rendered mockup (verify/analog_dial_check.py) showed
    // the "12" text and the icon's bottom edge only ~0.01 apart, too
    // tight to keep. The same mockup is why the font is FONT_XTINY:
    // FONT_TINY's wider "4"/"5"/"7"/"8" glyphs landed right on top of the
    // side stat badges at this radius; the smaller font clears them.
    const HOUR_NUM_RADIUS = 0.46;

    const FG = 0xf5f5f5;
    const DIM = 0xd8b8b8;
    const ACCENT = 0xe23b3b;
    // Named so the new Moon Phase icon's "dark side" (drawn separately in
    // Icons.mc) can be handed the exact same color the badge circle itself
    // is filled with below, rather than a second hardcoded literal that
    // could drift out of sync with it.
    const BADGE_BG = 0x1a0000;
    // Amber, not red/green - reads clearly as "charging" against this
    // project's red/black palette without colliding with ACCENT (used for
    // plenty of non-charging things) or the step ring's green.
    const CHARGE_COLOR = 0xffcc00;

    // Selectable stat-badge fields - numeric IDs match the Field1/Field2/
    // Field3 settings.xml list values exactly, so don't renumber these
    // without updating settings.xml/strings.xml to match. Same feature/IDs
    // as santorini-sunset - see that project's SantoriniSunsetView.mc for
    // the fuller comments on each field's reasoning.
    const FIELD_STEPS = 0;
    const FIELD_HEART = 1;
    const FIELD_CALORIES = 2;
    const FIELD_DISTANCE = 3;
    const FIELD_FLOORS = 4;
    const FIELD_ACTIVE_MIN = 5;
    const FIELD_BATTERY = 6;
    const FIELD_STRESS = 7;
    const FIELD_TEMPERATURE = 8;
    const FIELD_WORLD_CLOCK = 9;
    // Added in the "second hand / move bar / sunrise-sunset / step ring"
    // round. FIELD_MOVE_BAR reads ActivityMonitor.Info.moveBarLevel
    // directly (confirmed via Garmin's own API docs: MOVE_BAR_LEVEL_MIN=0,
    // MOVE_BAR_LEVEL_MAX=5 - Garmin's move-bar/red-bar inactivity nudge,
    // not steps). FIELD_SUNRISE/FIELD_SUNSET are the least certain of the
    // four new things added this round - see sunriseText()/sunsetText()
    // below for why.
    const FIELD_MOVE_BAR = 10;
    const FIELD_SUNRISE = 11;
    const FIELD_SUNSET = 12;
    // Pure date math (garmin-shared-src/MoonPhase.mc), no Weather/
    // Positioning dependency unlike Sunrise/Sunset above.
    const FIELD_MOONPHASE = 13;

    // Steps-progress ring: a second, inner ring of ticks (green fill vs a
    // dark unfilled track) showing steps/stepGoal. Digital clock style
    // ONLY - deliberately not shown in Analog. Analog mode already has the
    // perimeter tick ring, the hour-number ring, and now a seconds hand
    // all fighting for room between the stat badges (reaching to about
    // 0.41 from center at their outer corner) and the hour-number ring
    // (0.46); a mockup at the only radius that fit between them (0.43)
    // showed the new ring visually merging with the existing tick ring
    // into what just read as "a slightly thicker ring", not a distinct
    // progress indicator (verify/step_ring_debug_*.png). Digital mode has
    // the same 0.41-0.46 gap free of hour numbers, so 0.43 there is
    // genuinely uncluttered - verified in
    // verify/step_ring_color_{low,mid,goal}.png. Green (not ACCENT red) is
    // deliberate: reusing the dial's existing red would have the same
    // "blends into the tick ring" problem the first color choice had.
    const STEP_RING_RADIUS = 0.43;
    const STEP_RING_TICK_LEN = 0.024;
    const STEP_RING_SEGMENTS = 32;
    const STEP_RING_GREEN = 0x3ddc84;
    const STEP_RING_TRACK = 0x3a2a2a;

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

    // Called by WatchFaceInputDelegate.onPress() (touch-and-hold anywhere
    // on the face) - see garmin-shared-src/WatchFaceInputDelegate.mc for the API
    // research (WatchFaceDelegate.onPress needs API 4.2.0+, touchscreen-
    // only) and RossoneroApp.mc's getInitialView() for how this view gets
    // wired to that delegate.
    function toggleAltFields() as Void {
        _showAltFields = !_showAltFields;
        WatchUi.requestUpdate();
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
            drawStepRing(dc, w, h);
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

            // Used to skip a window of ticks around the bottom here to
            // dodge the battery readout - that was needed back when
            // BATTERY_Y was 0.925, but BATTERY_Y moved up to 0.875 in a
            // later round (to match milan-personal's tick-ring/badge
            // overlap fix) and nobody re-checked whether the exclusion
            // was still necessary. It wasn't: the battery row's bottom
            // edge now sits at roughly y=0.90, a clear ~0.03 above the
            // major tick's inner edge (~0.928), so the full ring draws
            // again.

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
    // or an analog hour/minute-hand clock, per Settings > Clock Style.

    function drawTime(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number, awake as Lang.Boolean) as Void {
        var clockStyle = Properties.getValue("ClockStyle") as Lang.Number?;
        if (clockStyle != null && clockStyle == 1) {
            drawAnalogTime(dc, w, h, awake);
            return;
        }

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

    // ---- Analog clock hands, drawn from the screen's TRUE center -----------
    //
    // Added as an alternative to the digital time readout (Settings >
    // Clock Style). Deliberately minimal, per your own scope choice when
    // asked: only the time element changes - the date row, the 3 stat
    // badges, and the battery readout all stay exactly where they already
    // are. The hands pivot from (w*0.5, h*0.5), the screen's actual
    // center - NOT the same spot the digital time sits (TIME_Y is offset
    // upward from center to leave room for the stat badges below it), so
    // depending on the time of day a hand can visually pass near the date
    // or the badges. That's the accepted tradeoff of keeping this a small,
    // isolated change instead of redesigning the whole layout around a
    // bigger analog face.
    //
    // Hour + minute hands only, no seconds hand - your call, and it also
    // keeps this exactly as burn-in-safe as everything else on this face:
    // no per-second redraw to worry about, awake or asleep. The system's
    // own always-on refresh (about once a minute) is already exactly the
    // resolution an hour/minute-only clock needs, so there's nothing extra
    // to manage here versus the digital mode's 1Hz "Show Seconds" timer.
    function drawAnalogTime(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number, awake as Lang.Boolean) as Void {
        var clockTime = System.getClockTime();
        var hour12 = clockTime.hour % 12;
        var min = clockTime.min;

        var cx = w * 0.5;
        var cy = h * 0.5;
        var hourLen = w * 0.20;
        var minLen = w * 0.32;

        var minuteAngle = min * 6.0;
        var hourAngle = hour12 * 30.0 + min * 0.5;

        // Same dimmed asleep values as the digital mode's fgColor/
        // accentColor above - already tuned once this session for the
        // AMOLED burn-in luminance budget, reused as-is rather than
        // picking new numbers.
        var fgColor = awake ? FG : 0xdddddd;
        var accentColor = awake ? ACCENT : 0x996666;

        // Hour-number ring is awake-only, like drawStripes()/
        // drawPerimeterTicks() above - 11 lit numerals held on screen for
        // up to a minute at a time in always-on mode is a meaningfully
        // bigger lit area than the hands alone, so it follows the same
        // AMOLED burn-in reasoning already applied elsewhere on this face.
        if (awake) {
            drawHourNumbers(dc, w, h);
        }

        dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
        drawHandPolygon(dc, cx, cy, hourAngle, hourLen, w * 0.022, hourLen * 0.18);

        dc.setColor(accentColor, Graphics.COLOR_TRANSPARENT);
        drawHandPolygon(dc, cx, cy, minuteAngle, minLen, w * 0.015, minLen * 0.15);

        // Seconds hand: awake-only (this project's 1Hz `_tickTimer` already
        // fires every second whenever awake, for the digital mode's
        // blinking-colon "Show Seconds" option - that same per-second
        // onUpdate() is what lets a seconds hand move smoothly here without
        // any new timer). Thin (half-width 0.006 vs the minute hand's
        // 0.015) and a touch longer than the minute hand, with a small
        // accent-colored tip and tail counterweight - the thinness alone
        // reads as clearly distinct from the two thicker hands even in the
        // same fgColor, verified in verify/step_ring_color_*.png (drawn
        // there at 10:24:38).
        if (awake) {
            var secAngle = clockTime.sec * 6.0;
            var secLen = w * 0.34;
            var secRad = Math.toRadians(secAngle);
            dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
            drawHandPolygon(dc, cx, cy, secAngle, secLen, w * 0.006, secLen * 0.25);
            var tailX = cx - Math.sin(secRad) * secLen * 0.25;
            var tailY = cy + Math.cos(secRad) * secLen * 0.25;
            dc.setColor(accentColor, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(tailX, tailY, w * 0.012);
        }

        // Hub cap: filled center plus a thin outline ring in the other
        // hand's color - a small polish over the original plain fillCircle,
        // same idea as a real watch's center cap.
        dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, w * 0.022);
        dc.setColor(accentColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(cx, cy, w * 0.022);
    }

    // Tapered "dauphine"-style hand: wide near the pivot, pointed at the
    // tip, with a small tail poking out the back like a real hand's
    // counterweight - replaces the original plain drawLine() stroke.
    // angleDeg is clockwise degrees from 12 o'clock (0 = straight up).
    // Built as a single 4-point fillPolygon: baseLeft -> tip -> baseRight
    // -> tail. Verified visually via verify/analog_dial_check.py (renders
    // this exact shape at 5 test times) before writing this - the plain-
    // line version was checked the same way earlier this session.
    function drawHandPolygon(dc as Graphics.Dc, cx as Lang.Float, cy as Lang.Float, angleDeg as Lang.Float, length as Lang.Float, halfWidth as Lang.Float, tailLen as Lang.Float) as Void {
        var rad = Math.toRadians(angleDeg);
        var dirX = Math.sin(rad);
        var dirY = -Math.cos(rad);
        var perpX = Math.cos(rad);
        var perpY = Math.sin(rad);

        var tip = [cx + dirX * length, cy + dirY * length];
        var baseLeft = [cx + perpX * halfWidth, cy + perpY * halfWidth];
        var baseRight = [cx - perpX * halfWidth, cy - perpY * halfWidth];
        var tail = [cx - dirX * tailLen, cy - dirY * tailLen];

        dc.fillPolygon([baseLeft, tip, baseRight, tail]);
    }

    // 1 through 11 around the dial at HOUR_NUM_RADIUS - see that
    // constant's comment for why "12" and this specific radius/font were
    // chosen. Same angle convention as the hands (0deg = 12 o'clock,
    // clockwise).
    function drawHourNumbers(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number) as Void {
        var cx = w * 0.5;
        var cy = h * 0.5;
        var r = w * HOUR_NUM_RADIUS;

        dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
        var n = 1;
        while (n <= 11) {
            var rad = Math.toRadians(n * 30.0);
            var x = cx + r * Math.sin(rad);
            var y = cy - r * Math.cos(rad);
            dc.drawText(x, y, Graphics.FONT_XTINY, n.format("%d"),
                Graphics.TEXT_JUSTIFY_CENTER + Graphics.TEXT_JUSTIFY_VCENTER);
            n += 1;
        }
    }

    // ---- Stats: fixed steps / heart rate / calories badges -----------------

    // Used to be fixed steps/heart rate/calories. Each of the three
    // circles now independently shows whatever FIELD_* the user picked in
    // Settings (defaults are still steps/heart rate/calories, so an
    // existing install that hasn't touched Settings looks identical to
    // before this change).
    function drawStats(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number) as Void {
        var info = ActivityMonitor.getInfo();

        var field1;
        var field2;
        var field3;
        if (_showAltFields) {
            // Long-press "alternate" set - same defaults as garmin-shared-src/
            // SettingsMenu.mc's ALT_FIELD*_DEFAULT constants (floors,
            // stress, move bar); kept as separate literals here rather
            // than importing them since View.mc doesn't otherwise depend
            // on SettingsMenu.mc's internals.
            field1 = Properties.getValue("Field1Alt") as Lang.Number?;
            field2 = Properties.getValue("Field2Alt") as Lang.Number?;
            field3 = Properties.getValue("Field3Alt") as Lang.Number?;
            if (field1 == null) { field1 = FIELD_FLOORS; }
            if (field2 == null) { field2 = FIELD_STRESS; }
            if (field3 == null) { field3 = FIELD_MOVE_BAR; }
        } else {
            field1 = Properties.getValue("Field1") as Lang.Number?;
            field2 = Properties.getValue("Field2") as Lang.Number?;
            field3 = Properties.getValue("Field3") as Lang.Number?;
            if (field1 == null) { field1 = FIELD_STEPS; }
            if (field2 == null) { field2 = FIELD_HEART; }
            if (field3 == null) { field3 = FIELD_CALORIES; }
        }

        var cy = h * STATS_Y;
        var cyOuter = cy - h * STATS_OUTER_LIFT;
        var r = w * STATS_RADIUS;
        var spacing = w * STATS_SPACING;
        var cxMid = w * 0.5;

        drawStatBadge(dc, cxMid - spacing, cyOuter, r, field1, fieldText(field1, info));
        drawStatBadge(dc, cxMid, cy, r, field2, fieldText(field2, info));
        drawStatBadge(dc, cxMid + spacing, cyOuter, r, field3, fieldText(field3, info));
    }

    // Text for one FIELD_* id. info is the shared ActivityMonitor.getInfo()
    // snapshot from drawStats() - passed in rather than re-fetched per
    // field so all three badges reflect the exact same instant.
    function fieldText(fieldId as Lang.Number, info as ActivityMonitor.Info) as Lang.String {
        if (fieldId == FIELD_HEART) {
            var hr = readHeartRate();
            return (hr != null) ? hr.format("%d") : "--";
        } else if (fieldId == FIELD_CALORIES) {
            var cal = (info.calories != null) ? info.calories : 0;
            return cal.format("%d");
        } else if (fieldId == FIELD_DISTANCE) {
            // Info.distance is centimeters since midnight - convert to the
            // device's configured unit.
            var distCm = (info.distance != null) ? info.distance : 0;
            if (System.getDeviceSettings().distanceUnits == System.UNIT_METRIC) {
                return (distCm / 100000.0).format("%.1f") + "km";
            }
            return (distCm / 160934.4).format("%.1f") + "mi";
        } else if (fieldId == FIELD_FLOORS) {
            var floors = (info.floorsClimbed != null) ? info.floorsClimbed : 0;
            return floors.format("%d");
        } else if (fieldId == FIELD_ACTIVE_MIN) {
            var mins = 0;
            if (info.activeMinutesDay != null) {
                mins = info.activeMinutesDay.total;
            }
            return mins.format("%d") + "m";
        } else if (fieldId == FIELD_BATTERY) {
            return System.getSystemStats().battery.format("%d") + "%";
        } else if (fieldId == FIELD_STRESS) {
            var stress = info.stressScore;
            return (stress != null) ? stress.format("%d") : "--";
        } else if (fieldId == FIELD_TEMPERATURE) {
            return temperatureText();
        } else if (fieldId == FIELD_WORLD_CLOCK) {
            return worldClockText();
        } else if (fieldId == FIELD_MOVE_BAR) {
            return moveBarText(info);
        } else if (fieldId == FIELD_SUNRISE) {
            return sunriseText();
        } else if (fieldId == FIELD_SUNSET) {
            return sunsetText();
        } else if (fieldId == FIELD_MOONPHASE) {
            return moonPhaseText();
        }
        // FIELD_STEPS, and the fallback for any unrecognized value.
        var steps = (info.steps != null) ? info.steps : 0;
        return formatSteps(steps);
    }

    // Garmin's inactivity nudge (the "red bar"/move bar), 0-5
    // (ActivityMonitor.MOVE_BAR_LEVEL_MIN/MAX) - 0 is rested, 5 is Garmin's
    // own max before the on-device alert. Shown as "N/5" rather than a bare
    // digit so it doesn't get read as a score to maximize - it's the
    // opposite, you want this low.
    function moveBarText(info as ActivityMonitor.Info) as Lang.String {
        var level = (info.moveBarLevel != null) ? info.moveBarLevel : 0;
        return level.format("%d") + "/5";
    }

    // Best-effort last-known location for the sunrise/sunset fields below.
    // Tries Activity.Info.currentLocation first - a real forum thread
    // (forums.garmin.com/developer/connect-iq/f/discussion/7210) quotes
    // Garmin's own docs describing this as available to watch faces for a
    // last-known location, though the same thread has developers reporting
    // it's inconsistent across devices/firmware. Falls back to
    // Weather.getCurrentConditions().observationLocationPosition - the
    // phone-synced weather station's location, already used for
    // temperatureText() above, which needs the same Positioning permission
    // this now declares in manifest.xml. Returns null (not a guess) if
    // neither is available - genuinely can happen with no phone paired or
    // no location fix yet.
    function sunLocation() as Position.Location? {
        if ((Toybox has :Activity) && (Activity has :getActivityInfo)) {
            var actInfo = Activity.getActivityInfo();
            if (actInfo != null && actInfo.currentLocation != null) {
                return actInfo.currentLocation;
            }
        }
        if (Toybox has :Weather) {
            var conditions = Weather.getCurrentConditions();
            if (conditions != null && conditions.observationLocationPosition != null) {
                return conditions.observationLocationPosition;
            }
        }
        return null;
    }

    // Sunrise/sunset via Weather.getSunrise()/getSunset() (API 3.3.0+,
    // comfortably under this project's 4.0.0 floor) - real Garmin API,
    // confirmed against Toybox.Weather's docs, NOT the "no API for this"
    // answer an older Garmin forum post gives (that post predates these two
    // methods). The genuinely uncertain part is sunLocation() above, not
    // this call - falls back to "--" the same way temperature/world clock
    // already do if location or the sunrise/sunset call itself comes back
    // null. Least field-tested of everything in this round - see README.
    function sunriseText() as Lang.String {
        var loc = sunLocation();
        if (loc == null || !(Toybox has :Weather) || !(Weather has :getSunrise)) {
            return "--";
        }
        var moment = Weather.getSunrise(loc, Time.now());
        return sunMomentText(moment);
    }

    function sunsetText() as Lang.String {
        var loc = sunLocation();
        if (loc == null || !(Toybox has :Weather) || !(Weather has :getSunset)) {
            return "--";
        }
        var moment = Weather.getSunset(loc, Time.now());
        return sunMomentText(moment);
    }

    // Pure date math (garmin-shared-src/MoonPhase.mc) - no location, no
    // Weather permission, no null/"--" fallback needed at all, unlike
    // every other field in this function.
    function moonPhaseText() as Lang.String {
        return moonPhaseEmoji(moonPhaseIndex());
    }

    // Shared formatting for sunriseText()/sunsetText() - same is24Hour
    // handling as worldClockText().
    function sunMomentText(moment as Time.Moment?) as Lang.String {
        if (moment == null) {
            return "--";
        }
        var info = Gregorian.info(moment, Time.FORMAT_SHORT);
        var hour = info.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }
        return hour.format("%02d") + ":" + info.min.format("%02d");
    }

    // Steps-progress ring - see STEP_RING_* constants above for why this is
    // Digital-only and why it's a separate ring rather than recoloring the
    // existing perimeter ticks. Reuses the exact same clock-convention trig
    // (dirX=sin, dirY=-cos, 0deg=12 o'clock, clockwise) as
    // drawHandPolygon()/drawHourNumbers() above, not the perimeter tick
    // ring's plain cos/sin (that ring is purely decorative, not clock- or
    // progress-aligned) - deliberately reusing the convention already
    // proven correct in a real build rather than introducing dc.drawArc()'s
    // own separate angle convention (0deg=3 o'clock, counter-clockwise)
    // untested.
    function drawStepRing(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number) as Void {
        var clockStyle = Properties.getValue("ClockStyle") as Lang.Number?;
        if (clockStyle != null && clockStyle == 1) {
            return; // Analog - see the constant comment for why.
        }
        var showRing = Properties.getValue("ShowStepRing") as Lang.Boolean?;
        if (showRing != null && !showRing) {
            return;
        }

        var info = ActivityMonitor.getInfo();
        var goal = (info.stepGoal != null) ? info.stepGoal : 0;
        if (goal <= 0) {
            return; // No goal set - nothing meaningful to show progress against.
        }
        var steps = (info.steps != null) ? info.steps : 0;
        var progress = steps.toFloat() / goal;
        if (progress > 1.0) { progress = 1.0; }

        var cx = w * 0.5;
        var cy = h * 0.5;
        var r = w * STEP_RING_RADIUS;
        var tickLen = w * STEP_RING_TICK_LEN;

        var i = 0;
        while (i < STEP_RING_SEGMENTS) {
            var angleDeg = i * (360.0 / STEP_RING_SEGMENTS);
            var filled = (i.toFloat() / STEP_RING_SEGMENTS) <= progress;
            var rad = Math.toRadians(angleDeg);
            var dirX = Math.sin(rad);
            var dirY = -Math.cos(rad);
            var outerX = cx + dirX * r;
            var outerY = cy + dirY * r;
            var innerX = cx + dirX * (r - tickLen);
            var innerY = cy + dirY * (r - tickLen);

            dc.setColor(filled ? STEP_RING_GREEN : STEP_RING_TRACK, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(filled ? 3 : 2);
            dc.drawLine(innerX, innerY, outerX, outerY);
            i += 1;
        }
    }

    // Ambient temperature via the connected phone's weather data - NOT a
    // physical sensor on this device. Needs a Bluetooth-connected phone
    // with the Connect app and (per manifest.xml) the Weather permission,
    // and can legitimately come back null. Falls back to "--".
    function temperatureText() as Lang.String {
        var conditions = (Toybox has :Weather) ? Weather.getCurrentConditions() : null;
        if (conditions == null || conditions.temperature == null) {
            return "--";
        }
        var celsius = conditions.temperature;
        var metric = (System.getDeviceSettings().temperatureUnits == System.UNIT_METRIC);
        var value = metric ? celsius : (celsius * 9.0 / 5.0 + 32.0);
        return value.format("%d") + "°";
    }

    // A second timezone as a fixed UTC-offset-in-hours clock (Settings >
    // World Clock Offset), not a real timezone/DST lookup - Monkey C has
    // no on-device timezone database. Whole-hour offsets only.
    function worldClockText() as Lang.String {
        var offsetHours = Properties.getValue("WorldClockOffset") as Lang.Number?;
        if (offsetHours == null) { offsetHours = 0; }
        var shifted = Time.now().add(new Time.Duration(offsetHours * 3600));
        var wcInfo = Gregorian.utcInfo(shifted, Time.FORMAT_SHORT);
        var hour = wcInfo.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }
        return hour.format("%02d") + ":" + wcInfo.min.format("%02d");
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
    function drawStatBadge(dc as Graphics.Dc, cx as Lang.Float, cy as Lang.Float, r as Lang.Float, fieldId as Lang.Number, text as Lang.String) as Void {
        dc.setColor(BADGE_BG, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(cx, cy, r);

        var iconSize = r * 0.42;
        var iconTopY = cy - r * 0.62;
        var iconX = cx - iconSize * 0.5;
        if (fieldId == FIELD_HEART) {
            Icons.drawHeart(dc, iconX, iconTopY, iconSize, ACCENT);
        } else if (fieldId == FIELD_CALORIES) {
            Icons.drawFlame(dc, iconX, iconTopY, iconSize, ACCENT);
        } else if (fieldId == FIELD_DISTANCE) {
            Icons.drawDistance(dc, iconX, iconTopY, iconSize, ACCENT);
        } else if (fieldId == FIELD_FLOORS) {
            Icons.drawFloors(dc, iconX, iconTopY, iconSize, ACCENT);
        } else if (fieldId == FIELD_ACTIVE_MIN) {
            Icons.drawActiveMinutes(dc, iconX, iconTopY, iconSize, ACCENT);
        } else if (fieldId == FIELD_BATTERY) {
            var stats = System.getSystemStats();
            Icons.drawBattery(dc, iconX, iconTopY + iconSize * 0.25, iconSize, stats.battery, ACCENT, ACCENT);
            // Corner charging badge - placement checked against the battery
            // icon's own footprint in a PIL mockup first (both occupy the
            // same badge, and the icon isn't centered) rather than assumed
            // clear - see verify/new_icons_v3_battery_badge.png.
            if (stats.charging) {
                Icons.drawChargingBolt(dc, cx + r * 0.25, cy - r * 0.85, r * 0.30, CHARGE_COLOR);
            }
        } else if (fieldId == FIELD_STRESS) {
            Icons.drawStress(dc, iconX, iconTopY, iconSize, ACCENT);
        } else if (fieldId == FIELD_TEMPERATURE) {
            var cat = weatherIconCategory();
            if (cat == 0) {
                Icons.drawWeatherClear(dc, iconX, iconTopY, iconSize, ACCENT);
            } else if (cat == 1) {
                Icons.drawWeatherCloud(dc, iconX, iconTopY, iconSize, ACCENT);
            } else if (cat == 2) {
                Icons.drawWeatherRain(dc, iconX, iconTopY, iconSize, ACCENT);
            } else if (cat == 3) {
                Icons.drawWeatherSnow(dc, iconX, iconTopY, iconSize, ACCENT);
            } else if (cat == 4) {
                Icons.drawWeatherStorm(dc, iconX, iconTopY, iconSize, ACCENT);
            } else {
                // No current-conditions data available at all - fall back
                // to the original plain thermometer rather than guessing.
                Icons.drawTemperature(dc, iconX, iconTopY, iconSize, ACCENT);
            }
        } else if (fieldId == FIELD_WORLD_CLOCK) {
            Icons.drawWorldClock(dc, iconX, iconTopY, iconSize, ACCENT);
        } else if (fieldId == FIELD_MOVE_BAR) {
            var info2 = ActivityMonitor.getInfo();
            var level = (info2.moveBarLevel != null) ? info2.moveBarLevel : 0;
            Icons.drawMoveBar(dc, iconX, iconTopY, iconSize, level, ACCENT);
        } else if (fieldId == FIELD_SUNRISE) {
            Icons.drawSunrise(dc, iconX, iconTopY, iconSize, ACCENT);
        } else if (fieldId == FIELD_SUNSET) {
            Icons.drawSunset(dc, iconX, iconTopY, iconSize, ACCENT);
        } else if (fieldId == FIELD_MOONPHASE) {
            var phase = moonPhaseIndex();
            if (phase == 0) {
                Icons.drawMoonNew(dc, iconX, iconTopY, iconSize, ACCENT, BADGE_BG);
            } else if (phase == 1) {
                Icons.drawMoonWaxingCrescent(dc, iconX, iconTopY, iconSize, ACCENT, BADGE_BG);
            } else if (phase == 2) {
                Icons.drawMoonFirstQuarter(dc, iconX, iconTopY, iconSize, ACCENT, BADGE_BG);
            } else if (phase == 3) {
                Icons.drawMoonWaxingGibbous(dc, iconX, iconTopY, iconSize, ACCENT, BADGE_BG);
            } else if (phase == 4) {
                Icons.drawMoonFull(dc, iconX, iconTopY, iconSize, ACCENT, BADGE_BG);
            } else if (phase == 5) {
                Icons.drawMoonWaningGibbous(dc, iconX, iconTopY, iconSize, ACCENT, BADGE_BG);
            } else if (phase == 6) {
                Icons.drawMoonLastQuarter(dc, iconX, iconTopY, iconSize, ACCENT, BADGE_BG);
            } else {
                Icons.drawMoonWaningCrescent(dc, iconX, iconTopY, iconSize, ACCENT, BADGE_BG);
            }
        } else {
            Icons.drawSteps(dc, iconX, iconTopY, iconSize, ACCENT);
        }

        // FIX: steps can go well past 3 digits, and once formatSteps()
        // switches to "12.3K"-style text it's noticeably wider than a
        // bare "0" or "80" - never checked against how much horizontal
        // room this small a badge actually has. Measure the actual
        // rendered width at runtime and drop to a smaller font if
        // FONT_TINY would run wider than the badge's chord width at this
        // text row (r * 1.7, leaving a little padding inside the circle).
        var textFont = Graphics.FONT_TINY;
        var maxTextWidth = r * 1.7;
        if (dc.getTextWidthInPixels(text, textFont) > maxTextWidth) {
            textFont = Graphics.FONT_XTINY;
        }

        dc.setColor(FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + r * 0.28, textFont, text,
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
        var stats = System.getSystemStats();
        var battery = stats.battery;
        var charging = stats.charging;
        var text = battery.format("%d") + "%";
        var iconSize = w * 0.055;
        var textWidth = dc.getTextWidthInPixels(text, Graphics.FONT_XTINY);
        // Charging bolt tacks onto the end of the same centered group
        // (icon-gap-text) rather than floating independently, so the
        // whole readout stays centered whether or not it's showing.
        var boltSize = iconSize * 0.55;
        var boltGap = charging ? w * 0.015 : 0;
        var groupWidth = iconSize + w * 0.02 + textWidth + boltGap + (charging ? boltSize : 0);
        var x = w * 0.5 - groupWidth * 0.5;
        var battYCenter = h * BATTERY_Y;

        Icons.drawBattery(dc, x, battYCenter - iconSize * 0.5, iconSize, battery, DIM, ACCENT);
        dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + iconSize + w * 0.02, battYCenter, Graphics.FONT_XTINY, text,
            Graphics.TEXT_JUSTIFY_LEFT + Graphics.TEXT_JUSTIFY_VCENTER);
        if (charging) {
            var boltX = x + iconSize + w * 0.02 + textWidth + boltGap;
            Icons.drawChargingBolt(dc, boltX, battYCenter - boltSize * 0.5, boltSize, CHARGE_COLOR);
        }
    }

    // Maps Weather.CurrentConditions.condition (one of ~54 CONDITION_*
    // codes - confirmed via Garmin's own Toybox.Weather docs, full list
    // fetched and cross-checked before writing this) down to one of 5 icon
    // categories for the Temperature badge. Not a 1:1 mapping - severe/
    // rare conditions (tornado, hurricane, sandstorm, volcanic ash, etc.)
    // land in the closest visual bucket rather than getting their own
    // glyph, same tradeoff any weather app's tiny status-bar icon makes.
    // Returns -1 (fall back to the plain thermometer) if no current-
    // conditions data is available at all, same "--"-style honesty as
    // temperatureText()/sunriseText() already use elsewhere in this file.
    function weatherIconCategory() as Lang.Number {
        if (!(Toybox has :Weather)) { return -1; }
        var conditions = Weather.getCurrentConditions();
        if (conditions == null || conditions.condition == null) { return -1; }
        var c = conditions.condition;
        if (c == Weather.CONDITION_CLEAR || c == Weather.CONDITION_FAIR ||
            c == Weather.CONDITION_PARTLY_CLEAR || c == Weather.CONDITION_MOSTLY_CLEAR) {
            return 0; // clear
        }
        if (c == Weather.CONDITION_THUNDERSTORMS || c == Weather.CONDITION_SCATTERED_THUNDERSTORMS ||
            c == Weather.CONDITION_CHANCE_OF_THUNDERSTORMS ||
            c == Weather.CONDITION_TORNADO || c == Weather.CONDITION_HURRICANE ||
            c == Weather.CONDITION_TROPICAL_STORM || c == Weather.CONDITION_WINDY ||
            c == Weather.CONDITION_SQUALL) {
            return 4; // storm (also covers severe non-precipitation conditions - no dedicated icon for those)
        }
        if (c == Weather.CONDITION_SNOW || c == Weather.CONDITION_LIGHT_SNOW || c == Weather.CONDITION_HEAVY_SNOW ||
            c == Weather.CONDITION_CHANCE_OF_SNOW || c == Weather.CONDITION_FLURRIES ||
            c == Weather.CONDITION_CLOUDY_CHANCE_OF_SNOW || c == Weather.CONDITION_WINTRY_MIX ||
            c == Weather.CONDITION_LIGHT_RAIN_SNOW || c == Weather.CONDITION_HEAVY_RAIN_SNOW ||
            c == Weather.CONDITION_RAIN_SNOW || c == Weather.CONDITION_CHANCE_OF_RAIN_SNOW ||
            c == Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN_SNOW || c == Weather.CONDITION_FREEZING_RAIN ||
            c == Weather.CONDITION_SLEET || c == Weather.CONDITION_ICE_SNOW || c == Weather.CONDITION_ICE ||
            c == Weather.CONDITION_HAIL) {
            return 3; // snow / wintry mix
        }
        if (c == Weather.CONDITION_RAIN || c == Weather.CONDITION_LIGHT_RAIN || c == Weather.CONDITION_HEAVY_RAIN ||
            c == Weather.CONDITION_SCATTERED_SHOWERS || c == Weather.CONDITION_LIGHT_SHOWERS ||
            c == Weather.CONDITION_SHOWERS || c == Weather.CONDITION_HEAVY_SHOWERS ||
            c == Weather.CONDITION_CHANCE_OF_SHOWERS || c == Weather.CONDITION_DRIZZLE ||
            c == Weather.CONDITION_UNKNOWN_PRECIPITATION || c == Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN) {
            return 2; // rain / showers / drizzle
        }
        if (c == Weather.CONDITION_UNKNOWN) { return -1; }
        // Everything else - partly/mostly cloudy, cloudy, hazy, foggy,
        // misty, dusty, smoky, thin clouds, etc. - the plain cloud icon.
        return 1; // cloud
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
