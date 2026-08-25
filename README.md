# Rossonero - a Connect IQ watch face

A watch face in a red/black stripe color scheme - a date row, a large
two-tone time readout (hour white, minute/colon red), three stat badges
(steps, heart rate, calories), and a battery readout, over a vertical
red/black striped background.

**This is the Store-submittable half of a two-project split** - see
"Why this is split from milan-personal" below. Same caveat as the other
projects in this set: written without access to the SDK compiler or a
real/simulated device - treat as a carefully-reasoned first draft, not
tested software.

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
```
