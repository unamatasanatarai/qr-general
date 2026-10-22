<p align="center">
  <img src="Resources/Logo.png" width="160" alt="QR General app icon">
</p>

<h1 align="center">QR General</h1>

<p align="center">
  <strong>Branded, print-sharp QR codes on your Mac, from paste to PNG in seconds.</strong>
</p>

<p align="center">
  <a href="https://github.com/unamatasanatarai/qr-general/releases/latest"><strong>⬇ Download the latest release</strong></a>
</p>

<p align="center">
  <img alt="macOS 12+" src="https://img.shields.io/badge/macOS-12%2B-black?logo=apple">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-AppKit-F05138?logo=swift&logoColor=white">
  <img alt="Zero dependencies" src="https://img.shields.io/badge/dependencies-0-success">
  <img alt="License: GPL-2.0" src="https://img.shields.io/badge/license-GPL--2.0-blue">
</p>

QR General is a native macOS app that turns any text or URL into a QR code. Paste it in, drop your logo in the middle, pick an exact pixel size and save a crisp PNG. Everything happens on your Mac, with no account, no upload and no web service in between.

<p align="center">
  <img src="Resources/QR%20Code.png" width="360" alt="A 1000 × 1000 px QR code made with QR General, with a star emblem in the center">
  <br>
  <sub>Real output: 1000 × 1000 px, High error correction, centered emblem on a rounded backdrop.</sub>
</p>

---

## Why QR General

Making a QR code is easy. Making one that **carries your brand, comes out at exactly the size your layout needs and still scans** usually means a web generator, an upload and a blurry export.

QR General does the whole job locally. The preview redraws as you type, your logo sits in the center, and the final image renders at the exact size you ask for, with hard pixel-aligned edges.

## Built for Codes That Scan and Look Right

| | |
|---|---|
| ⚡ **Live preview** | The code redraws as you type or paste. A character counter and one-click **Clear** keep long URLs manageable. |
| 🎯 **Exact sizes, no blur** | Presets for **512**, **1K**, **2K** and **4K**, or any size up to **10,000 px**. The size includes the standard 4-module quiet zone, and module edges snap to whole pixels with anti-aliasing off. |
| ⭐ **Your logo in the center** | Drag an image onto the logo well or press ⌘O. PNG, JPEG, PDF and any other image format macOS can open will work. The logo sits on a white rounded backdrop sized from **10% to 40%** of the code width. |
| 🛡️ **Error correction handled for you** | All four levels (Low 7%, Medium 15%, Quartile 25%, High 30%), each with a one-line note on when to use it. Adding a logo switches to **High** automatically so the covered center still scans. |
| 📤 **Export at full size** | **Save PNG…** (⌘S or Return) writes the full-resolution image. **Copy QR Code** (⇧⌘C) puts it on the clipboard as PNG and TIFF, ready for a design tool, document or chat. |
| 🍎 **Pure Apple frameworks** | Swift, AppKit, Core Image and Core Graphics. No third-party packages, a translucent native window and full keyboard control. |

## How It Works

```text
1. Paste or type your text or URL        →  the preview appears instantly
2. Pick a size (preset or exact pixels)  →  edges snap to the pixel grid
3. Drop in a logo (optional)             →  error correction switches to High (30%)
4. Adjust the logo size                  →  10–40% of the code width
5. Save PNG… or Copy QR Code             →  full-size, ready-to-use image
```

> **No silent failures.** Empty input, text too long for the chosen correction level, and sizes too small to fit the code are caught with a clear message, and export stays disabled until the input is fixed.

## Proven to Decode

The test suite renders real codes and reads them back with Apple's QR detector. It verifies that:

- the rendered code decodes back to the original text
- codes with a logo at the default size **and at the maximum 40% size** still decode
- output is exactly the requested pixel size, including unusual sizes
- the symbol is upright, with finder patterns in the correct corners
- empty and over-capacity input and out-of-range sizes are rejected
- the main window regenerates from pasted text and saves a full-size PNG

```bash
make test
```

## Keyboard Shortcuts

| Action | Shortcut |
|---|---|
| Choose Logo… | ⌘O |
| Save PNG… | ⌘S / Return |
| Copy QR Code | ⇧⌘C |
| Close window | ⌘W |

## Quick Start

### Download

Get the DMG from the [latest release](https://github.com/unamatasanatarai/qr-general/releases/latest) and drag **QR General** into Applications. Requires **macOS 12 or later**.

### Build from source

Requires macOS with the Xcode command-line tools (`swiftc`, `xcrun`).

```bash
git clone https://github.com/unamatasanatarai/qr-general.git
cd qr-general
make run
```

`make run` builds `build/QR General.app` and launches it.

## Developer Commands

| Target | What it does |
|---|---|
| `make help` | List all targets |
| `make setup` | Set the app name and bundle identifier in `scripts/config.sh` |
| `make build` | Compile the `.app` bundle into `build/` and increment `BUILD_NUMBER` |
| `make run` | Quit running copies, rebuild and launch |
| `make kill` | Quit running copies of the app |
| `make test` | Compile and run the native Swift test suite |
| `make dmg` | Build a styled DMG with a custom background and an Applications shortcut |
| `make release <x.y.z>` | Test, bump `VERSION`, build the DMG, tag and publish a GitHub release |
| `make revoke` | Reset macOS permissions and flush LaunchServices and QuickLook caches |
| `make clean` | Remove build output and temporary test binaries |

## Configuration

App identity lives in [`scripts/config.sh`](scripts/config.sh). Edit it directly or run `make setup`:

```bash
export APP_NAME="${APP_NAME:-QR General}"
export BUNDLE_ID="${BUNDLE_ID:-com.unamatasanatarai.QRGeneral}"
export MIN_MACOS_VERSION="${MIN_MACOS_VERSION:-12.0}"
export LS_UI_ELEMENT="${LS_UI_ELEMENT:-false}" # "true" for menu-bar-only / agent apps
```

- **Version:** the `VERSION` file (`X.Y.Z`) is the single source of the app version, written to `CFBundleShortVersionString`.
- **Build number:** every build increments `BUILD_NUMBER` and writes it to `CFBundleVersion`.
- **Signing:** builds are ad-hoc signed with a designated requirement pinned to the bundle ID, so macOS permissions persist across rebuilds without a certificate. `make revoke` resets them.

## Releasing

```bash
export GEMINI_API_KEY="your-api-key"
make release 1.2.3
```

Releases follow a **gather → ask → do** flow:

1. **Gather** (read-only): validate that the version is higher than both `VERSION` and the latest tag, confirm the branch is in sync with `origin` and `gh` is logged in, draft release notes (a Gemini summary, the full commit list and a compare link) and run the tests.
2. **Ask:** print a full release preview. Nothing changes until you type `yes`.
3. **Do:** set `VERSION`, build the DMG, commit, tag `vX.Y.Z`, push and publish the GitHub release. If a step fails before the commit, `VERSION` is restored.

The working tree must be clean, apart from `BUILD_NUMBER`.

## Project Structure

```text
Sources/App/
├── QRRenderer.swift          # QR matrix generation and pixel-exact rendering with logo
├── QRWindowController.swift  # Main window: input, size, error correction, logo, preview, export
├── MainMenu.swift            # File / Edit / Window menus and shortcuts
├── AppDelegate.swift, Main.swift, AppConfig.swift
Tests/AppTests/               # Rendering, sizing, decode and window tests
scripts/                      # Build, test, DMG, setup and release scripts
Resources/                    # App icon, logo, sample QR code, DMG artwork
```

## License

Released under the [GNU General Public License v2.0](LICENSE).
