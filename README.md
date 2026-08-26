# Darter

**Keyboard shortcuts for Adobe Lightroom Classic.** Nudge Develop sliders, open
tools, and apply presets without touching the mouse — edit the way power users
drive a spreadsheet, hands never leaving the keys.

Darter is a spiritual successor to VSCO Keys, the free Lightroom shortcut tool
that was discontinued years ago. It's an independent, open-source project built
from scratch on Adobe's public Lightroom SDK — not affiliated with, endorsed by,
or derived from VSCO or any other company's software.

Requires **Lightroom Classic** (not the cloud "Lightroom" app) and **macOS 13+**.

---

## What it does

| | |
|---|---|
| **Sliders** | Tap a key to nudge Temperature, Exposure, Contrast, Highlights, Shadows, etc. by a configurable amount. Hold a modifier for finer or coarser steps. |
| **Tools** | One key each for Crop, Auto Straighten, Rotate Crop Aspect, Reset Crop, White Balance picker, Remove, Masking. |
| **Presets** | Assign any Develop preset to ⌘1–⌘0 and apply it instantly. |
| **Profiles** | Bundled starter layouts, plus import/export so you can back up or share a setup. |

No mouse movement, no typing into slider fields, and no per-session "binding"
step when Lightroom launches.

### Default shortcuts

| Slider | Decrease | Increase | Step |
|---|---|---|---|
| Temperature | Q | W | 100 |
| Tint | A | S | 3 |
| Exposure | E | R | 0.1 |
| Contrast | D | F | 10 |
| Highlights | Z | X | 10 |
| Shadows | C | V | 10 |
| Saturation | B | N | 10 |
| Crop Angle | - | = | 0.5 |

| Tool | Key |
|---|---|
| Crop | Tab |
| Auto Straighten | L |
| Rotate Crop Aspect | ⇧Tab |
| White Balance Picker | I |
| Info Overlay | ⇧I |
| Reset Crop / Remove / Masking | unbound — set your own |

Hold **Option** for a smaller step (×0.5), **Shift** for a larger one (×2.5) —
both modifiers are configurable, including turning them off so combinations like
Option+S stay available to other apps. **Shift+Esc** toggles everything on/off.

---

## Install

Grab the latest zip from [Releases](../../releases), or
[build it yourself](#build-from-source).

### 1. Install the Lightroom plugin

1. Lightroom Classic → **File → Plug-in Manager → Add**
2. Select `Darter.lrdevplugin`
3. **Done**

Keep that folder somewhere permanent — Lightroom loads it from wherever it sits,
so don't leave it in Downloads or the Trash.

### 2. Install the app (and get past Gatekeeper)

Drag `Darter.app` into your Applications folder.

Release builds are signed with a self-signed certificate but **not notarized by
Apple** — notarization requires a paid Apple Developer account. macOS will
therefore refuse to open it the first time. To allow it:

1. Double-click `Darter.app`. macOS blocks it — dismiss the warning.
2. Open **System Settings → Privacy & Security**.
3. Scroll to **Security**. You'll see *"Darter.app was blocked to protect your Mac."*
4. Click **Open Anyway** and confirm with Touch ID or your password.
5. Click **Open** on the final dialog.

One-time only; it opens normally afterwards.

<details>
<summary>Alternatives if that doesn't work</summary>

On **older macOS**, right-click (or Control-click) the app → **Open** → **Open**.
Newer macOS removed that bypass, which is why the System Settings route above is
the reliable one.

If the app was downloaded through a browser it carries a quarantine flag, which
you can clear directly:

```bash
xattr -d com.apple.quarantine /Applications/Darter.app
```

Or avoid Gatekeeper entirely by [building from source](#build-from-source) —
a locally built app isn't quarantined.
</details>

### 3. Grant Accessibility permission

Darter needs **Accessibility** to see key presses while Lightroom is frontmost.
This is required for any global-shortcut app, and it's the only permission used.

macOS should prompt on first launch. If not:
**System Settings → Privacy & Security → Accessibility → +** → select Darter → toggle **on**.

> Input Monitoring is *not* required. An active `CGEventTap` and the Accessibility
> API are both gated on Accessibility alone.

### 4. Try it

Open a photo in the **Develop** module and press **Q** or **W** — Temperature
should move. Configure everything from the menu bar icon → **Settings**.

---

## Build from source

No Xcode project needed — it's a Swift package.

```bash
git clone https://github.com/af1/darter.git
cd darter/mac-app
./scripts/build-app.sh
open Darter.app
```

That produces `mac-app/Darter.app`. Because you built it locally it has no
quarantine flag, so Gatekeeper won't block it.

Then install the plugin from `lightroom-plugin/Darter.lrdevplugin` as described
above.

### Stable code signing (optional but recommended)

`build-app.sh` falls back to ad-hoc signing, which re-hashes the binary on every
build — macOS then treats each rebuild as a new app and **drops your Accessibility
grant**. Creating a local self-signed identity keeps that grant stable:

```bash
mkdir -p mac-app/signing && cd mac-app/signing

openssl req -x509 -newkey rsa:2048 -keyout darter-dev.key -out darter-dev.crt \
  -days 3650 -nodes -subj "/CN=Darter Local Dev" \
  -addext "extendedKeyUsage=critical,codeSigning" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "basicConstraints=critical,CA:false"

openssl pkcs12 -export -out darter-dev.p12 -inkey darter-dev.key \
  -in darter-dev.crt -passout pass:darter -legacy

security import darter-dev.p12 -k ~/Library/Keychains/login.keychain-db \
  -P darter -T /usr/bin/codesign -T /usr/bin/security
security add-trusted-cert -d -r trustRoot -p codeSign \
  -k ~/Library/Keychains/login.keychain-db darter-dev.crt
```

`build-app.sh` picks the identity up automatically on the next build.

> The `-legacy` flag matters: OpenSSL 3.x's default PKCS#12 encryption isn't
> compatible with macOS's importer and fails with "MAC verification failed".

`scripts/make-share.sh` builds a distributable zip (app + plugin + install
instructions) named from the app's version.

---

## How it works

Two cooperating pieces:

**`lightroom-plugin/Darter.lrdevplugin`** registers as a Lightroom `URLHandler`.
Lightroom is already the system handler for `lightroom://` URLs, so the plugin
receives requests addressed to its own toolkit identifier and applies them with
`LrDevelopController`. One-time install, no per-session setup.

**`mac-app`** is a SwiftUI menu bar app. It installs a global `CGEventTap`,
matches key presses against your config, and fires the matching `lightroom://`
URL — fire-and-forget, no socket or persistent connection to manage.

A couple of actions have no SDK hook at all (the crop panel's *Auto* straighten
button, and rotate-crop-aspect). Those are driven through the Accessibility API
or by synthesizing Lightroom's own native shortcut, guarded so they only fire in
the right context.

### Notes on behavior

- Shortcuts only fire while Lightroom Classic is frontmost, and are suppressed
  while a text field — or a launcher overlay like Raycast or Spotlight — has
  keyboard focus.
- Holding an arrow key in Lightroom can keep scrolling after you release; that's
  Lightroom queueing photos faster than it renders them, not Darter. **Settings →
  Tools → Photo Navigation** offers a *Paced* mode that bounds it, and building
  Standard-Sized Previews reduces it at the source.

---

## Contributing

Issues and pull requests welcome. The Lua plugin side is small and readable;
the Swift side is a standard SwiftUI + AppKit menu bar app with no dependencies.

## License

[MIT](LICENSE) — use it, fork it, modify it, share it. Provided as-is, with no
warranty and no support.

Lightroom, Lightroom Classic, and Adobe are trademarks of Adobe Inc. VSCO is a
trademark of Visual Supply Company. This project is independent and unaffiliated
with either.
