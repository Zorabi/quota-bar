<div align="center">
  <img src="Resources/QuotaBar.svg" width="112" alt="QuotaBar icon">
  <h1>QuotaBar</h1>
  <p>Keep your remaining Codex usage visible in the macOS menu bar.</p>
  <p>
    <strong>English</strong> · <a href="README_CN.md">简体中文</a>
  </p>
  <p>
    <img src="https://img.shields.io/badge/macOS-14%2B-000000?logo=apple" alt="macOS 14+">
    <img src="https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white" alt="Swift 6.2">
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-Apache%202.0-D22128.svg" alt="Apache License 2.0"></a>
  </p>
</div>

QuotaBar is a lightweight macOS menu bar utility for tracking the remaining 5-hour and 7-day usage of your current Codex account, together with reset times, Plan, Credits, and Reset credits. It gets data through read-only Codex interfaces, does not inspect the private Codex Desktop database, and never resets usage or changes account state.

## Highlights

- **Usage at a glance**: shows the remaining 5h / 7d usage in the menu bar; when the 5-hour limit is temporarily disabled, QuotaBar automatically displays only the active 7d metric.
- **Detailed usage panel**: includes usage windows, reset times, Plan, Credits, Reset credits, and refresh status.
- **Desktop widget**: offers an in-app widget that can be shown, hidden, or pinned to the desktop layer.
- **Flexible presentation**: configure refresh interval, information density, menu bar density, the Codex prefix, status item, and Dock icon.
- **Launch at login**: register QuotaBar as a macOS login item.
- **Expiration lookup**: manually query the expiration times of all Reset credits from Settings.
- **Experimental native widget**: includes a WidgetKit extension; unsigned builds are not guaranteed to appear in the macOS widget gallery.

## Screenshots

<table>
  <tr>
    <td align="center"><strong>Menu bar panel</strong></td>
    <td align="center"><strong>Desktop widget</strong></td>
  </tr>
  <tr>
    <td><img src="marketing/assets/quota-bar-popover-clean.png" alt="QuotaBar menu bar panel"></td>
    <td><img src="marketing/assets/quota-bar-desktop-widget-clean.png" alt="QuotaBar desktop widget"></td>
  </tr>
</table>

<p align="center">
  <strong>Settings</strong><br>
  <img src="marketing/assets/quota-bar-settings-window-clean.png" width="720" alt="QuotaBar settings window">
</p>

> [!NOTE]
> The application UI shown above is currently in Chinese.

## Requirements

- Apple Silicon Mac (the current packaging script targets `arm64`)
- macOS 14 Sonoma or later
- ChatGPT or the legacy Codex macOS app installed and signed in
- Swift 6.2, Xcode Command Line Tools, and ImageMagick for source builds

## Quick Start

QuotaBar is currently distributed as a source build. Download or clone this repository, then run the following commands from its root:

```bash
brew install imagemagick
Scripts/build-app.sh
open .build/QuotaBar.app
```

The packaged application will be available at `.build/QuotaBar.app`. To use launch at login or the experimental native widget, move the app to `/Applications` and launch it once:

```bash
cp -R .build/QuotaBar.app /Applications/
open /Applications/QuotaBar.app
```

You can also run the main executable directly with Swift Package Manager. This does not create a complete `.app` bundle or package the native widget extension:

```bash
swift run CodexUsageWidgetApp
```

> [!NOTE]
> The current build uses ad-hoc code signing and is intended for local development and evaluation. macOS may warn that the app is from an unidentified developer, and the experimental WidgetKit extension may not be registered by the system.

## Usage

1. Make sure you are signed in to the ChatGPT or legacy Codex app.
2. Launch QuotaBar; the active usage windows will appear in the menu bar.
3. Click the menu bar text to view details, refresh now, or open Settings.
4. Use Settings to adjust display density, automatic refresh, the desktop widget, Dock icon, and launch at login.

## Data Sources and Privacy

QuotaBar uses the following data sources in a read-only manner:

- Regular usage is obtained from `account/rateLimits/read` through the local `codex app-server --stdio` bundled with the ChatGPT / Codex app.
- Only when explicitly requested by the user, the Reset credit expiration feature reads the access token from the local Codex credentials and sends a request to a read-only ChatGPT endpoint.

QuotaBar does not read the private Codex Desktop database, nor does it provide sign-in, purchasing, approval, rejection, or usage-reset actions. It does not save task content. Application settings and the latest usage snapshot used by WidgetKit are stored under `Application Support/QuotaBar`; Reset credit expiration results remain in memory for the current session only.

## Project Structure

```text
Sources/
├── CodexUsageCore/                  # Models, formatting, settings, and read-only providers
├── CodexUsageWidgetApp/             # SwiftUI / AppKit menu bar application
└── CodexUsageNativeWidgetExtension/ # Experimental WidgetKit extension
Tests/
└── CodexUsageCoreTests/             # Core logic tests
Scripts/
└── build-app.sh                     # Application packaging script
```

## Development and Verification

```bash
swift test
swift build
Scripts/build-app.sh
```

Make sure all commands pass before submitting a change. Feature work and bug fixes must follow [AGENTS.md](AGENTS.md) and the approved designs and plans under `docs/superpowers/`.

## Contributing

Issues and pull requests are welcome. In a PR, describe the purpose of the change, how it was verified, and include before-and-after screenshots for UI changes. New or updated code comments, documentation comments, and user-facing copy should be written in Chinese.

## License

This project is available under the [Apache License 2.0](LICENSE). See [NOTICE](NOTICE) for attribution information.
