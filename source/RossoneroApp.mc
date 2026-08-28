using Toybox.Application;
using Toybox.Lang;
using Toybox.WatchUi;

class RossoneroApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }
    function onStart(state as Lang.Dictionary?) as Void {
    }
    function onStop(state as Lang.Dictionary?) as Void {
    }
    function getInitialView() as [ WatchUi.Views ] or [ WatchUi.Views, WatchUi.InputDelegates ] {
        // WatchFaceInputDelegate (shared-src) wires up long-press-to-swap-
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
    // selection mode) - see shared-src/SettingsMenu.mc for the full
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
