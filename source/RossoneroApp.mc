using Toybox.Application;
using Toybox.Lang;
using Toybox.WatchUi;

// App version - shown in the on-device Customize menu's title (see
// garmin-shared-src/SettingsMenu.mc) so a stale build is obvious at a
// glance instead of only discoverable by comparing screenshots against
// source, which has bitten this project before (santorini-sunset's
// date-contrast fix looked "not applied" in a screenshot that actually
// just predated the rebuild). Bump this on every push to the device or
// the Store dashboard, using the same value in both places. Scheme:
// MAJOR.MINOR.PATCH - MAJOR only for a real public-facing milestone
// (e.g. going from Beta to full Store release), MINOR for a round that
// adds a new field/feature, PATCH for a pure bug/visual fix. 1.0.0 is
// the informal baseline (everything through the Moon Phase round);
// 1.0.1 was the step-progress-ring rendering fix; 1.1.0 is this round -
// the ring is now also shown in Analog mode (previously Digital-only),
// a real behavior change so MINOR rather than PATCH. See the project
// status doc's "Versioning introduced" section for the full scheme and
// what to type into the Store dashboard on each submission.
const APP_VERSION = "1.1.0";

class RossoneroApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }
    function onStart(state as Lang.Dictionary?) as Void {
    }
    function onStop(state as Lang.Dictionary?) as Void {
    }
    function getInitialView() as [ WatchUi.Views ] or [ WatchUi.Views, WatchUi.InputDelegates ] {
        // WatchFaceInputDelegate (garmin-shared-src) wires up long-press-to-swap-
        // fields - see that file and RossoneroView.mc's toggleAltFields()
        // for the full explanation. Needs a live reference to the view
        // instance, so it's constructed here rather than inline in the
        // return array.
        var view = new RossoneroView();
        return [ view, new WatchFaceInputDelegate(view) ];
    }
    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
    // On-device "Customize" settings (hold the button in watch-face
    // selection mode) - see garmin-shared-src/SettingsMenu.mc for the full
    // explanation. SettingsMenu/SettingsDelegate now come from that
    // shared file (via monkey.jungle's sourcePath), not a per-project
    // class - class names dropped their "Rossonero" prefix accordingly.
    // Only applies to watch faces/data fields, which this is.
    function getSettingsView() as [ WatchUi.Views ] or [ WatchUi.Views, WatchUi.InputDelegates ] or Null {
        return [ new SettingsMenu(), new SettingsDelegate() ];
    }
}
function getApp() as RossoneroApp {
    return Application.getApp() as RossoneroApp;
}
