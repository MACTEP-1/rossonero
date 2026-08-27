# Rossonero - a Connect IQ watch face

A watch face in a red/black stripe color scheme - a generic soccer-ball
icon and date row at top (with a perimeter tick ring), a large two-tone
time readout (hour white, minute/colon red), three stat badges (steps,
heart rate, calories), and a battery readout, over a vertical red/black
striped background.

**This is the Store-submittable half of a two-project split** - see
"Why this is split from milan-personal" below. Same caveat as the other
projects in this set: written without access to the SDK compiler or a
real/simulated device - treat as a carefully-reasoned first draft, not
tested software.

## Fifteenth round: seconds hand, move bar, sunrise/sunset, steps ring

You asked for five things; four are new, one (stress) turned out to
already be there - `FIELD_STRESS` has been a selectable stat-badge field
since the Ninth round, reading `ActivityMonitor.Info.stressScore`
directly. Nothing to add for it, just worth knowing before you go
looking for it in Settings.

**Seconds hand (Analog only, awake only).** Reuses this project's
existing 1Hz `_tickTimer` - it already fires every second whenever awake
(originally for the digital mode's blinking-colon "Show Seconds" option),
so a smoothly-moving seconds hand needed no new timer. Same tapered
`drawHandPolygon` shape as the hour/minute hands but much thinner
(half-width 0.006 vs the minute hand's 0.015) with a small accent-colored
tip/tail, drawn and hub-capped last so it sits on top of the other two.
Checked via a new PIL mockup (`verify/step_ring_color_*.png`, drawn at
10:24:38) that the thinness alone reads as clearly distinct from the two
thicker hands without needing a different color.

**Move bar (new selectable field, id 10).** Garmin's own inactivity nudge
- `ActivityMonitor.Info.moveBarLevel`, confirmed against Garmin's API docs
as a real property with `MOVE_BAR_LEVEL_MIN=0`/`MOVE_BAR_LEVEL_MAX=5`.
Shown as "N/5" in the badge (0 = rested, 5 = Garmin's own max before its
on-device alert) with a small 5-bar chart icon, filled up to the current
level.

**Sunrise / Sunset (new selectable fields, ids 11/12) - the least certain
thing in this round.** `Weather.getSunrise()`/`getSunset()` are real
Garmin API (3.3.0+, confirmed against Toybox.Weather's own docs - not the
"no API for this" answer an older Garmin forum thread gives, which
predates these two methods), but both need a `Position.Location`, and a
watch face doesn't have a live GPS session to get one from cleanly.
`sunLocation()` tries `Activity.Info.currentLocation` first (a real forum
thread quotes Garmin's own docs describing this as available to watch
faces for a last-known location, though developers in that same thread
report it's inconsistent across devices/firmware), then falls back to
`Weather.CurrentConditions.observationLocationPosition` (the phone-synced
weather station's location, already used for the Temperature field).
Both need this round's new `Positioning` permission (see manifest.xml).
If neither location source comes back with anything, or the phone isn't
connected, both fields fall back to "--" rather than guessing - the same
pattern Temperature and World Clock already use. **Please check this one
specifically once you build** - it's the one piece of this round I have
the least confidence will resolve to a real time on your actual device.

**This round's first permission request.** Adding Sunrise/Sunset means
this Store-submittable app now declares `<iq:uses-permission
id="Positioning"/>` in manifest.xml - every previous round of this
project requested nothing. If you do submit this to the Store, both
Garmin's review and the install prompt surface requested permissions, so
it's worth knowing this isn't a silent addition.

**Steps-progress ring (Digital clock style only).** A second, inner ring
at radius 0.43 - green ticks for the completed fraction of
`steps`/`stepGoal`, a dark track for the rest - toggleable via the new
"Show step-goal ring" setting (default on). Deliberately Digital-only:
Analog mode already has the perimeter tick ring, the hour-number ring,
and now a seconds hand all sharing the narrow band between the stat
badges (~0.41 from center) and the hour-number ring (0.46); a mockup at
the only radius that fit between them read as a slightly thicker copy of
the existing tick ring, not a distinct progress indicator
(`verify/step_ring_debug_*.png`). Digital mode has the same gap free of
hour numbers, so the ring reads cleanly there
(`verify/step_ring_color_{low,mid,goal}.png`). Green rather than this
project's own red is deliberate, for the same "needs to look different
from the existing ring, not just be positioned differently" reason.
Skipped entirely (not drawn) if the device doesn't report a step goal,
rather than guessing a default one to show progress against.

All four new icons (move bar's bar chart, the shared sunrise/sunset
horizon-and-arrow glyph) were prototyped in Python at the real ~17px
badge-icon size before being ported to Monkey C, same habit as every
icon round before this one - see `verify/new_badge_fields.png` and
`verify/sun_icons_v2_zoomed.png`. The first sunrise/sunset icon design
(arrow stacked directly above the sun) was illegible at that size and
was redrawn with the arrow beside the sun instead - kept both mockups
around as a reminder of why.

## Fourteenth round: stat badges lifted into a gentle arc

You asked for the left/right circles to sit a little higher than the
middle one, so the row reads "in concert with" the round bezel instead
of looking like a flat line laid across it. Done: the outer two badges
now sit `STATS_OUTER_LIFT` (0.035, about 15px on the Venu 2) higher than
the middle one, which stays exactly where it was.

Same lift in both Digital and Analog mode on purpose, even though what
prompted this was how the row looked next to the round hour-number
dial - a lift that only applied in Analog would mean the badges visibly
jump position every time you switch Clock Style, which would look worse
than the plain row it replaces. Checked via a PIL render (same approach
as everything else touchy in this project) against both the digital
`FONT_NUMBER_HOT` time and the new hour-number ring, at a few different
lift amounts - turned out there was a lot more clearance in both
directions than expected: the digital time's actual bottom edge sits
well clear of where the badges start, and lifting the OUTER badges
specifically moves them away from the 4/5/7/8 o'clock numbers (the
tightest ones from the last round), not toward them. So the limit here
was purely taste - how much lift still reads as "a little" rather than a
dramatic rearrangement - not a collision risk.

## Thirteenth round: SettingsMenu.mc moved to a shared source folder

You pointed out that this project and santorini-sunset are essentially
the same watch face under different skins - correct, and it's exactly
why every settings-menu feature this session had to be hand-ported with
`sed` three separate times. Rather than merging the two projects
outright (which would have compiled your Santorini photo into this
project's binary, and orphaned this project's existing Store Beta
submission - see the conversation for the full tradeoff), the on-device
`SettingsMenu.mc` - which was already byte-identical across all three
projects except for a class-name prefix - now lives in
`garmin/shared-src/SettingsMenu.mc`, a folder alongside (not inside) this
project, milan-personal, and santorini-sunset. `monkey.jungle` pulls it
in via `base.sourcePath = source;../shared-src`; `RossoneroApp.mc`'s
`getSettingsView()` now references the shared, unprefixed
`SettingsMenu`/`SettingsDelegate` classes instead of
`RossoneroSettingsMenu`/`RossoneroSettingsDelegate`.

**This means `garmin/shared-src/` needs its own git history** - it's a
new sibling folder outside any of the three existing repos, not part of
this one. It's a plain folder with its own local git repo now; whether
you push it to a remote of its own is your call. **Practically**: from
now on, edit `garmin/shared-src/SettingsMenu.mc` directly rather than
this project's `source/` folder (which no longer has its own copy) when
a Settings-menu change is needed - one edit, all three projects pick it
up on their next build.

This first pass only moved the settings menu, deliberately - it's the
piece that was already 100% identical across projects, so the risk of
this refactor breaking something was low. The rest of View.mc (drawing
logic) still has real per-project differences (background, icon, tuned
layout constants) baked in throughout, and unifying that into a shared
base class would be a much bigger, riskier change to make without a
compiler to verify it - not done here, worth a separate conversation if
you want to go further.

## Twelfth round: nicer analog hands, hour ticks + numbers around the dial

You asked for the Analog clock style to look more like a real watch:
better-looking hands than plain sticks, and hash marks with numbers
around the circumference. Both done:

- **Hands** are now a tapered "dauphine" shape (wide near the pivot,
  pointed tip, a small tail poking out the back like a real hand's
  counterweight) drawn as a single filled shape, instead of the original
  plain line stroke. The center hub also picked up a thin outline ring
  in the opposite hand's color, instead of a flat filled dot.
- **Hour markers**: numbers 1 through 11 around the dial, reusing this
  project's existing perimeter tick ring's radius rather than adding a
  new one. "12" is skipped on purpose - the top soccer-ball icon already
  marks that spot, and a real collision check (below) showed the "12"
  text and the icon's bottom edge only about 1% of screen height apart,
  too tight to keep both.

The collision risk here was real, not hypothetical: this face already
packs an icon, date, time, three stat badges, and a battery readout into
a small vertical stack, and a first pass at the number ring landed the
4/5/7/8 o'clock numbers right on top of the side stat badges. Rendered
the whole dial with Python/PIL at the actual Venu 2 resolution (same
verify-before-shipping approach used for the original hand-angle math,
not committed to this repo - just a dev-time check) to check every
number position against the icon, date, badges, and battery before
settling on `FONT_XTINY` (small enough to clear the badges) and skipping
"12". Checked at five test times again, not just one, since which stat
badge is closest to trouble depends on the current time.

The hour-number ring only draws when awake, same as the existing tick
ring and stripe background - eleven lit numerals held on screen for up
to a minute at a time in always-on mode would cost more of the AMOLED
burn-in budget than this face can spare, so it follows the same
awake-only pattern already used elsewhere here.

## Eleventh round: an analog clock style option

You asked whether an analog watch option could be added to all three
projects. Scoped this deliberately narrow when asked: only the time
element itself switches (new Settings > Clock Style: Digital/Analog) -
the date row, the 3 stat badges, and the battery readout all stay exactly
where they are. Hour and minute hands only, no seconds hand - your call,
and it also means this needed zero new burn-in consideration: no extra
per-second redraw, awake or asleep, and the system's own once-a-minute
always-on refresh is already exactly the resolution this needs.

The hands pivot from the screen's true center (`w*0.5, h*0.5`), not from
`TIME_Y` where the digital text sits - `TIME_Y` is deliberately offset
upward from center to leave room for the stat badges below it, so an
analog clock centered there would either need its own layout pass or
accept some visual crossover near the date/badges depending on the time
of day. You picked the smaller, isolated change over a bigger layout
redesign, so that crossover is an accepted tradeoff, not an oversight.

Verified the actual hand-angle math (which direction is "12 o'clock,"
which way is clockwise, does the hour hand creep between hour marks as
minutes pass) with a quick Python/PIL render at five test times (10:10,
3:45, 12:00, 6:30, 9:15) before writing the Monkey C - same
verify-before-shipping habit as everywhere else in this project. All five
came out correct, including the one non-obvious case: at exactly 12:00:00
the hour and minute hands point the same direction, so the shorter hour
hand is fully hidden behind the longer minute hand drawn on top of it -
that's correct clock behavior, not a bug, and worth knowing so it doesn't
look like a missing hand if you spot it.

Also added to the on-device Customize menu (5th item, "Clock style") for
the same reason the rest of that menu exists - test it without needing
the phone-based Settings path.

## Tenth round: on-device "Customize" settings, no phone needed

You noticed some of your other installed watch faces show a gear icon/
"Customize" option when you hold the button in watch-face selection mode,
letting you edit their settings right on the watch, and asked if we could
do that here too for the 3 stat circles.

Good news: yes, and it's a real, separate Connect IQ API
(`AppBase.getSettingsView()`, since API 3.2.0 - this project targets
4.0.0, no issue) - researched properly against Garmin's docs and forum
threads before writing this rather than guessing (see `source/
SettingsMenu.mc`'s header comment for the sourcing). Crucially, it's
**independent of the phone-based Settings from settings.xml/
properties.xml** (the 9th-round feature below): this new one works while
sideloaded, no store/Beta publication required, which is exactly the
"test it right now" path you have. Hold the button in watch-face
selection mode, select the new one, and you should see "Customize"
alongside "Apply"/"Delete" - selecting it opens a menu: Left/Middle/
Right circle (each showing its current field, tap to change) and World
Clock Offset. Both mechanisms read/write the exact same underlying
Properties, so they can't get out of sync - whichever one you used most
recently is what's showing.

One real implementation detail worth flagging: Garmin's own bundled
"Analog" sample app (the canonical example most forum posts point to for
this feature) wraps its menu in an extra intermediate View, and multiple
independent bug reports trace a real double-back-press glitch on actual
hardware directly to that wrapper pattern. Not something I could catch
myself without a device, so this was deliberately built flatter instead -
`getSettingsView()` returns the real top-level menu/delegate pair
directly, matching the pattern a couple of forum threads confirmed
working cleanly, rather than copying Analog's structure.

The world-clock offset submenu shows plain "UTC+2"-style labels rather
than the city-name hints ("UTC+2 (Athens)") the phone-based Settings
show - simplification to keep this on-device submenu's code (and the
watch's tiny screen) simple, the offset number is what actually matters
functionally.

Like everything else in this project, this has not run on real hardware
or the simulator - the `Menu2`/`MenuItem`/`Menu2InputDelegate` API calls
are verified against Garmin's actual API docs and real forum code
samples, not guessed, but this is genuinely the largest chunk of
previously-unused API surface added in one round this whole project. If
"Customize" doesn't show up at all after a build, or a submenu comes back
empty, that's the first place to look.

## Ninth round: user-selectable stat-badge data, plus a world clock

You asked for the 3 stat circles to be customizable, and floated a
secondary screen as an option "if it's too hard" - otherwise just
settings. A quick look at Connect IQ's watch-face touch/tap support
didn't turn up a clean path to a second screen for a always-on watch
face without meaningfully more risk in code I can't compile-test, so per
your own stated fallback this went the settings route instead: each of
the 3 circles is now independently configurable in Settings (Left/
Middle/Right circle shows...) rather than fixed to steps/heart rate/
calories. Defaults are still steps/heart rate/calories, so an existing
install looks identical until you actually open Settings.

New options beyond the original three: distance (today, converts to km
or mi from your device's unit setting), floors climbed, active minutes,
battery %, stress score, temperature, and a world clock. Two of those are
worth flagging honestly rather than presenting as sure things, since none
of this has run on a real device or simulator:

- **Temperature** is not a physical sensor on any of these watches - it
  comes from `Weather.getCurrentConditions()`, which needs a Bluetooth-
  connected phone running Connect. **Correction, confirmed against a real
  compiler run:** the manifest originally declared a `Weather` permission,
  guessed from Garmin's usual module-name convention since I couldn't
  fully verify it from this sandbox - and monkeybrains rejected it outright
  ("Invalid permission provided: Weather") the first time you actually
  built this. Checked Garmin's actual `Toybox.Weather`/`CurrentConditions`
  docs afterward: no permission is needed at all for `.temperature` (the
  field this code reads) - the only fields that need a permission are
  `observationLocationPosition`/`observationLocationName`, which need
  `Positioning` instead. The `<iq:permissions>` block is removed from
  `manifest.xml` entirely now. No phone connected, and the field falls
  back to "--" rather than crashing.
- **World clock** is a fixed whole-hour UTC offset (new "World Clock
  Offset" setting, -12 to +14), not a real timezone lookup - Monkey C has
  no on-device timezone database, so there's no way to do automatic DST
  or half-hour-offset zones (India, Nepal, etc.) without one. If you
  pick, say, "UTC-5 (New York)" it'll drift an hour off during whichever
  side of DST New York isn't currently observing, until you manually
  change the offset.

New tiny icons for each of the new fields (distance arrow, stair-step
floors, stopwatch, zigzag stress line, thermometer, clock-face) were
prototyped in Python at the actual ~18px on-screen badge size before
being ported to Monkey C vector code, same verification habit as the
earlier icon rounds - see `tools/` if you want to see the mockups. Battery
reuses the existing battery icon rather than a new one.

## Eighth round: walking back the tick-ring gap - it's not needed anymore

You flagged that the hash marks at the bottom of the ring were missing.
That's a real regression I introduced myself: the "gap in the ring for
the battery" fix from the sixth round (below) was correct *at the time*,
when `BATTERY_Y` was 0.925 and there genuinely wasn't room. But the very
next round moved `BATTERY_Y` up to 0.875 to fix a different overlap (the
stat badges against the tick ring), and I never went back and checked
whether the now-redundant gap-in-the-ring exclusion was still needed. It
wasn't - at `BATTERY_Y=0.875` the battery row's bottom edge sits at
roughly y=0.90, a full ~0.025 above the bottom major tick's inner edge
(~0.928), so the exclusion was just removing real tick marks for no
reason. Removed the exclusion entirely; the ring draws all the way around
again. Checked this with a rendered mockup (battery box vs. tick
positions, not just the arithmetic) before shipping - same technique as
the original gap fix.

This is the same "recheck everything downstream of a change" lesson from
earlier rounds, just caught a round late and in the opposite direction -
worth being upfront about that rather than glossing over it.

## Seventh round: long step counts could overflow a badge

Caught on milan-personal's screenshot, but applies here too since the
badge-drawing code is identical: once `formatSteps()` switches to
"12.3K"-style text (anything >= 1000 steps), that string runs meaningfully
wider than a bare "0" or "80", and the badge text was always drawn at a
fixed font size regardless of how long it actually was. Fixed by
measuring the rendered text width at runtime and dropping to a smaller
font (`FONT_XTINY`) if the normal one (`FONT_TINY`) would run wider than
the badge can actually hold, instead of guessing at a length threshold
that might not hold up for every locale's number formatting.

Rossonero's badges don't have the tick-ring overlap milan-personal had
(checked the numbers - this project's `STATS_Y`/`STATS_RADIUS` keep the
badges comfortably inside the ring, margin ~0.022), so no layout changes
needed here this round, just the font fix.

## Sixth round: gap in the tick ring for the battery

Confirmed (via the same bug on milan-personal's screenshot) that the
perimeter tick ring's long "major" tick at exactly 90 degrees - straight
down - reaches deep enough to sit right behind the battery readout. Since
you said Rossonero itself "looks good," this hadn't been reported here
specifically, but the tick ring code and `BATTERY_Y` are the same in both
projects, so it's very likely present here too, just not looked at
closely. Rather than shrink the battery row or fight for a gap that
mostly isn't there between the badges and that tick, `drawPerimeterTicks`
now skips a small window of ticks (65-115 degrees) around the bottom,
opening a real gap in the ring for the battery to sit in - checked the
geometry with a quick script before shipping this one, not just paper
math. `BATTERY_Y` itself is unchanged.

## Fifth round: the ball is now a bitmap, not hand-drawn Monkey C

Three straight rounds of hand-coded vector pentagons all looked wrong
once you actually saw them rendered - a flower, then a pinwheel, then
(per your last screenshot) something that reads as a spider or crab. The
real problem was structural, not just wrong numbers: I was writing
Monkey C polygon math blind, with no way to see what it actually looked
like before you built it and reported back, so every "fix" was a guess
refined only after you'd already seen it fail.

Switched approach instead of tuning the geometry a fourth time: the ball
is now `resources/drawables/soccer_ball.png`, a bitmap generated by
`tools/gen_soccer_ball.py` (a small Python/PIL script, included in this
project for reference/future edits) and drawn with `Dc.drawScaledBitmap`,
the same technique already proven out for the Milan crest and the
Santorini Sunset background photo. The difference that actually matters:
I could open the generated PNG and look at it myself, at the actual
on-device size, before sending it - which I couldn't do for any of the
three vector attempts. It's a standard central-pentagon-plus-surrounding-
pentagons pattern, cropped to the ball's circle so the panels at the rim
show as partial shapes the way they do in real ball photos.

This bumps `minApiLevel` to 4.0.0 (from 3.3.0) for `drawScaledBitmap` -
every device in the product list is already CIQ4+, so nothing is dropped.
`Icons.drawSoccerBall` is removed from `Icons.mc` entirely rather than
left in unused.

## Fourth round: the ball, take three

Time/badge spacing looked right in your latest screenshot - no more
changes needed there. The ball still looked wrong though: with 5 equal
arms sharing the icon's small pixel budget, each tip pentagon rendered as
just a few pixels, too small to read as a pentagon - the whole icon came
out looking like a spiky asterisk with blobs on the ends, which matches
what you saw. Rather than try to fit more detail into the same tiny
space, went the other way: fewer, bigger shapes. Now there's one big
central pentagon, two large wedges lower-left/right (each connected to
the center with a thick solid bridge, sized to read clearly rather than
disappear), and just three thin seam stubs for the rest - closer to how
an actual ball looks head-on (2-3 visible panels, not 5 symmetric ones).
Also grew the icon itself (`ICON_SIZE` 0.12 -> 0.15, `ICON_Y` pulled up to
0.05 so the bottom edge - and everything below it - doesn't move) since
part of the problem was simply not enough pixels to work with. Still not
rebuilt/reverified - fourth time saying that, and it'll keep being true
until you can screenshot a version where I got the pattern actually right.

## Third round of fixes (your second screenshot)

The previous round's `TIME_Y` fix (0.45 -> 0.40) turned out to not be
enough - your next screenshot still showed the time overlapping the stat
badges. That means `FONT_NUMBER_HOT` renders taller than assumed twice
now (closer to ~0.30 of screen height, not the ~0.21 these constants were
first built around). Rather than nudge again and risk a third near-miss,
recalculated the whole icon-through-battery stack around that larger
number - see the layout-constants comment in `RossoneroView.mc` for the
exact numbers. Also rebuilt the soccer ball: the previous version's outer
pentagons sat disconnected from the center one (floating dots, not
touching anything), which is why it still looked wrong even with more
pentagons in it. This version connects each one to the center pentagon
with a thick bridge line so each arm reads as one continuous black shape,
closer to your reference images. Neither of these has been rebuilt/
reverified yet - same caveat as always.

## Second round of fixes (from your simulator screenshot)

- **Background too subtle.** The stripe color (`0x1a0000`) was close
  enough to pure black that the red/black pattern barely read on the
  actual screen. Bumped to `0x330000` - still dark, just visibly red now.
  Applied to milan-personal too (identical background code).
- **Time overlapping the stat badges.** Adding the soccer-ball icon in
  the previous round pushed `TIME_Y` down from 0.40 to 0.45, but nothing
  compensated for the fact that `FONT_NUMBER_HOT`'s rendered bottom edge
  now landed almost exactly on the badges' top edge (badge top = `STATS_Y`
  0.76 - `STATS_RADIUS` 0.10 = 0.66). Moved `TIME_Y` back to 0.40, which
  restores a real gap without needing to also push the badges (and then
  the battery row) further down toward the bottom bezel.
- **Stray vertical dash landing on the date text.** `drawStripes()` had
  two vertical accent-dash lines left over from before the icon/date/time
  layout shifted - meant to flank the time, but never repositioned when
  `DATE_Y`/`TIME_Y` moved. The first one (`h*0.30` to `h*0.35`) now sat
  right on top of the date row - exactly the "white dash on the day of
  the week" you saw. Removed both rather than re-tuning more magic
  numbers into an already tight layout; the date-flanking dashes and the
  perimeter tick ring already cover that accent-line role.
- **Soccer ball looked like a flower, not a ball.** The old icon was a
  single black pentagon with 5 lines radiating to the edge - technically
  a ball's *seams*, but with no other pentagons it read as a pinwheel.
  Added 5 smaller black pentagons ringed around the center, sitting in
  the gaps between the seam lines near the rim (see `Icons.mc`) - much
  closer to the actual truncated-icosahedron pattern everyone recognizes
  as "soccer ball."
- **Battery felt low.** Nudged `BATTERY_Y` from 0.905 to 0.885 - still a
  clear 0.025 below the stat badges, just a bit further from the bottom
  bezel.

None of this has been rebuilt/reverified in the simulator yet - reasoned
from your screenshot and the code, same caveat as everything else here.

## Fixes after the first real build

The first screenshot from the actual simulator surfaced a few real
issues, fixed in this version:

- **Numbers sitting too low in the stat badges.** The old code
  top-anchored the number text with a small guessed offset below center,
  which didn't account for how much of a small badge's height
  `FONT_TINY` actually renders at - on a badge this small (radius ~9-10%
  of screen width), that guess was well off. Switched to
  `TEXT_JUSTIFY_VCENTER`, which centers on the anchor point regardless of
  actual font height, and rebalanced the icon above it to match. Also
  bumped the badge radius slightly (0.09 -> 0.10) for a bit more room.
- **Date-flanking dashes rendering pale/white instead of red.** A real
  bug: the code never set the accent color before drawing those two
  small lines, so they inherited whatever color the date text left set.
  Fixed with an explicit `setColor(ACCENT, ...)` before drawing them.
- **Added the perimeter tick ring** (`drawPerimeterTicks()`) - a ring of
  small tick marks hugging the bezel, mostly dim with a longer/thicker
  red one every 5th position, approximating the reference mockup's
  red/white dash ring around the edge. Uses the same radius (0.46) as
  Ritmo's step-goal ring, which is proven to hug this bezel without
  clipping.
- **Added a generic soccer-ball icon at the top** (`Icons.drawSoccerBall`)
  in place of what used to be empty space - a plain white ball with a
  black pentagon and seam lines, the classic public-domain ball pattern
  that isn't anyone's trademark, unlike a club crest. Adding it pushed
  `DATE_Y`/`TIME_Y` down slightly to make room (see the layout-constants
  comment in the code).
- Small polish on the battery readout's icon/text vertical alignment.

None of this has been rebuilt/reverified in the simulator yet - it's
reasoned from the screenshot and the code, same "treat as a first draft"
caveat as everything else here.

## Why this is split from milan-personal

The design started from an AC Milan-themed mockup. The actual club crest
(shield, cross, "ACM 1899" wordmark) is a registered trademark, so it's
not something to build or ship in anything meant for public
distribution - that reasoning hasn't changed since earlier in this
project (see Ritmo's README for the fuller discussion). The color scheme
itself ("rossonero" is just Italian for "red-black") is a much lower-risk
choice, though it's worth being clear-eyed that it's not zero-risk: the
name and colors can still evoke the club to anyone familiar with Italian
football, which is a real (if much smaller) consideration for Store
review - not something I can rule on for you, and not legal advice, just
worth knowing going in.

This project (`rossonero/`) has **no crest image anywhere in it** - safe
to submit to the Store. The separate `milan-personal/` project has the
same layout plus a real crest image and is marked sideload-only, never
meant to be submitted. Keeping them as fully separate projects (not one
project with a toggle) matters here: even a togglable/hidden feature
still means the crest image ships inside the compiled binary, which
would be a problem for a Store submission regardless of whether the
toggle defaults off.

## Layout - not yet verified live

Deliberately reuses Arctic Peak's exact layout-constant values (see that
project's README/code comments for the chord-width reasoning) even
though this face has no top icon and could start a little higher -
reusing numbers that already got that reasoning pass felt lower-risk
than inventing new ones. Not yet seen on a real screen or simulator.

## Building

Same process as Ritmo/Arctic Peak: open this folder in VS Code with the
Monkey C extension, F5 to run in the simulator.

## Before you publish

- [ ] Confirm no overlap on a real screenshot, especially the date/dash
      flourishes near the top and the stat-badge row near the bottom -
      see the layout note above.
- [ ] Read the naming/trade-dress note above one more time and decide
      for yourself whether "Rossonero" and the stripe pattern are
      comfortable for your Store listing - I'm not able to give a
      definitive legal answer on this, only flag the consideration.
- [ ] Double-check `resources/drawables/` and `source/` really do
      contain no crest image or club wordmark before you submit - a
      quick `grep -ri milan` / `grep -ri crest` across the project is a
      good final check.
- [ ] Confirm on real hardware, not just the simulator.

## What's in here

```
manifest.xml              App metadata, target devices
monkey.jungle              Build file
resources/
  strings/strings.xml       App name + settings label
  settings/properties.xml   User-configurable settings (storage/defaults)
  settings/settings.xml     Settings screen UI
  drawables/                Launcher icon only - no crest, see above
source/
  RossoneroApp.mc            App entry point
  RossoneroView.mc           All drawing logic
  Icons.mc                   Small vector icons (steps/heart/flame/battery)

../shared-src/                (sibling folder, NOT inside this project)
  SettingsMenu.mc             On-device Customize menu - shared with
                               milan-personal and santorini-sunset, see
                               "Thirteenth round" above and its header
                               comment. Pulled in via monkey.jungle.
```
