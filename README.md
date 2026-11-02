# Feynos Music

A Navidrome music player with ListenBrainz history, weekly mixes, jams, themes, layouts and
visualizers.

| App | Where to get it | Notes |
| --- | --- | --- |
| Android phone | [Releases](../../releases) → `FeynosMusic-<version>.apk` | Updates itself from GitHub releases |
| Wear OS watch | Installed from the phone app, see [wear/README.md](wear/README.md) | Remote for the phone app |
| Linux (Fedora and other RPM distros) | [Releases](../../releases?q=linux-v) → `.rpm` | `sudo dnf install ./feynos-music-<version>.x86_64.rpm` |
| Windows 10/11 | [Releases](../../releases?q=windows-v) → `Feynos-Music-Setup-<version>.exe` | Click **More info → Run anyway** if SmartScreen warns |
| Apple TV | Build with Xcode, see [appletv/README.md](appletv/README.md) | Free Apple ID works |

## Wear OS watch (e.g. OnePlus Watch 2)

Quick version:

1. Watch: **Settings › System › About › Versions** → tap **Build number** 7 times, then
   **Settings › Developer options** → turn on **ADB debugging** and **Wireless debugging**
   (same Wi-Fi as the phone).
2. Phone: **Feynos Music › Settings › Watch › Install or update the watch app**.
3. Watch: **Wireless debugging › Pair new device** → type the 6-digit code into the phone and
   tap **Pair** (first time only).
4. Phone: tap **Install on watch**.

Other ways to install (Wear Installer 2, or `adb` from a computer) and troubleshooting are in
[wear/README.md](wear/README.md).
