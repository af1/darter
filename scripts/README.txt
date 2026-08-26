Darter — keyboard shortcuts for Lightroom Classic
======================================================

Nudge Develop sliders, open tools, and apply presets from the keyboard — no
mouse, no clicking into fields.

Requires Adobe Lightroom CLASSIC (not the cloud "Lightroom" app), macOS 13 or
newer.

There are two pieces to install: a small Lightroom plugin, and the menu bar
app. About 3 minutes total.


-------------------------------------------------------------------
STEP 1 — Install the Lightroom plugin
-------------------------------------------------------------------
1. Open Lightroom Classic.
2. File > Plug-in Manager.
3. Click "Add" (bottom left).
4. Select the "Darter.lrdevplugin" folder included in this zip.
5. Click "Done".

Keep the .lrdevplugin folder somewhere permanent (not the Downloads folder,
and not in the Trash) — Lightroom loads it from wherever it sits.


-------------------------------------------------------------------
STEP 2 — Install the app (and get past Gatekeeper)
-------------------------------------------------------------------
Drag "Darter.app" into your Applications folder.

This app is signed, but not notarized by Apple (that requires a paid Apple
Developer account). macOS will therefore refuse to open it the first time.
This is expected — here's how to allow it:

  1. Double-click Darter.app. macOS blocks it and shows a warning.
     Click "Done" / "OK" to dismiss.

  2. Open System Settings > Privacy & Security.

  3. Scroll down to the "Security" section. You'll see a message like
     "Darter.app was blocked to protect your Mac."

  4. Click "Open Anyway", then confirm with Touch ID or your password.

  5. If a final dialog appears, click "Open".

That's a one-time step. After this it opens normally, like any other app.

  On older macOS versions you can instead right-click (or Control-click) the
  app and choose "Open" > "Open". Newer macOS removed that shortcut, which is
  why the System Settings route above is the reliable one.

Once running, a small slider icon appears in your menu bar (top right of the
screen). That means it's working. There is no Dock icon — that's intentional.


-------------------------------------------------------------------
STEP 3 — Grant Accessibility permission
-------------------------------------------------------------------
The app needs "Accessibility" permission to detect key presses while
Lightroom is in front. This is normal and required for any keyboard-shortcut
app — it's the only permission Darter uses.

macOS should prompt you the first time. If it doesn't:

  System Settings > Privacy & Security > Accessibility > "+" >
  select Darter from Applications > make sure its toggle is ON.

(You do NOT need to grant "Input Monitoring" — Accessibility is enough.)


-------------------------------------------------------------------
STEP 4 — Try it
-------------------------------------------------------------------
1. In Lightroom Classic, open a photo in the Develop module.
2. Press Q or W — the Temperature slider should move.

Click the menu bar icon > Settings to see and change every shortcut.


-------------------------------------------------------------------
Default shortcuts
-------------------------------------------------------------------
Sliders (decrease / increase):

  Temperature   Q / W     (step: 100)
  Tint          A / S     (step: 3)
  Exposure      E / R     (step: 0.1)
  Contrast      D / F     (step: 10)
  Highlights    Z / X     (step: 10)
  Shadows       C / V     (step: 10)
  Saturation    B / N     (step: 10)
  Crop Angle    - / =     (step: 0.5)

  Hold Option  = smaller change (x0.5)
  Hold Shift   = larger change  (x2.5)
  Shift+Esc    = turn all shortcuts on/off

  Both modifier keys are configurable (Settings > Sliders). Set one to None
  or Control to free up e.g. Option+letter for another app.

Tools:

  Open Crop tool        Tab         (from Library, switches to Develop first)
  Auto Straighten       L
  Rotate Crop Aspect    Shift+Tab   (while the crop overlay is open)
  White Balance Picker  I
  Info Overlay          Shift+I
  Reset Crop            (unbound — set a key in Settings)
  Remove tool           (unbound — set a key in Settings)
  Masking tool          (unbound — set a key in Settings)

Presets — assign any Develop preset to Command + a number (1 through 0):

  1. Settings > Presets tab.
  2. Click "Refresh from Lightroom" (Lightroom must be running).
  3. Pick a preset for each slot. There's a search box — you may have a lot.
  4. In Lightroom, press Command + that number to apply it.

New here? Settings > Starter Profiles > "Big Steps" gives larger, more
obvious adjustments while you get a feel for it. Import/Export buttons let
you back up your setup or share it with someone else.


-------------------------------------------------------------------
Photo navigation (holding the arrow keys)
-------------------------------------------------------------------
Lightroom on its own can keep scrolling for many seconds after you release a
held arrow key — it queues up photos faster than it can render them. This is
Lightroom's own behavior, not something this app causes.

Settings > Tools > Photo Navigation lets you pick:

  Paced (default)  Darter advances photos itself at a set rate, so
                   scrolling stops the moment you let go.
  Native           Lightroom handles held arrows at its own speed, including
                   the run-on described above.

Building Standard-Sized Previews in Lightroom (Library > Previews) makes the
run-on much smaller, since it's caused by slow preview rendering.


-------------------------------------------------------------------
Troubleshooting
-------------------------------------------------------------------
Nothing happens when I press a key
  - Make sure Lightroom Classic is the frontmost app, with a photo open in
    the Develop module.
  - Check Accessibility permission is ON (Step 3).
  - Check the menu bar icon > "Enabled" is checked (Shift+Esc toggles it).

Sliders work but presets / crop tools don't
  - The plugin isn't loaded or is out of date. Lightroom > File >
    Plug-in Manager, select Darter, click "Reload Plug-in". Make sure
    it's the .lrdevplugin from THIS zip.

It stopped working after I updated the app
  - macOS ties Accessibility permission to the exact app version. Remove
    Darter from System Settings > Privacy & Security > Accessibility
    (select it, click "−"), then add it back and toggle it on.

Keys fire while I'm typing in Lightroom
  - Shouldn't happen — the app ignores keys while a text field or a
    launcher overlay (Raycast/Spotlight) has focus. If you hit a case where
    it doesn't, that's a bug worth reporting.
