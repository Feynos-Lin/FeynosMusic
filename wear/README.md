# Feynos Music for Wear OS

A watch remote for Feynos Music on your Android phone. Tested target: **OnePlus Watch 2**
(works on any Wear OS 3+ watch).

- **Now Playing:** song, artist, album art, progress ring, previous / play-pause / next, like.
  Turn the crown to change the phone's volume.
- **Up next:** jump to any queued song, shuffle and repeat.
- **Library:** Shuffle all, Liked songs, Pinned, Made for you, Playlists, Recently played,
  Recently added and Liked albums. Tap one and it starts playing on the phone.
- Works in jams too (commands go to whoever is hosting).

The phone app must be **version 1.0.27 or newer**. The watch and phone apps share the same
package name and signing key, which Wear OS requires before they can talk to each other.

## Install it

### Option 1 — from the Feynos Music phone app (no computer)

1. **Turn on wireless debugging on the watch**
   - Watch: **Settings › System › About › Versions** → tap **Build number** 7 times.
   - Watch: **Settings › Developer options** → turn on **ADB debugging**, then
     **Wireless debugging**.
   - Put the watch and phone on the **same Wi-Fi**.
2. **Pair (first time only)**
   - Phone: **Feynos Music › Settings › Watch › Install or update the watch app**.
   - Watch: **Wireless debugging › Pair new device**. The phone usually finds the pairing
     address by itself; type the **6-digit code** from the watch and tap **Pair**.
3. **Install**
   - The phone fills in the watch's address from the **Wireless debugging** screen
     (the IP address & port at the top, not the pairing one). Tap **Install on watch**.
   - It downloads the newest watch app from this repo's releases and installs it.
4. To **update** later: turn Wireless debugging back on, open the same screen and tap
   **Update watch app**. No need to pair again.

### Option 2 — Wear Installer 2 (phone)

1. Do step 1 above on the watch.
2. Install **Wear Installer 2** from the Play Store on your phone.
3. Download `FeynosMusicWear-<version>.apk` from the
   [releases page](../../releases?q=wear-v) to your phone.
4. In Wear Installer 2, enter the watch's IP address, pair with the code from
   **Pair new device**, choose the APK and install.

### Option 3 — a computer with adb

```bash
# Fedora:  sudo dnf install android-tools
# Windows: install "SDK Platform-Tools" from developer.android.com
adb pair <ip:port from "Pair new device"> <6-digit code>
adb connect <ip:port from the Wireless debugging screen>
adb install -r FeynosMusicWear-<version>.apk
```

## Tips

- The watch turns **Wireless debugging** off when it restarts or changes Wi-Fi; turn it on
  again before installing or updating.
- When you're done you can turn **ADB debugging** off to save battery.
- "Can't reach Feynos Music on your phone" on the watch: update the phone app, open it once,
  and keep the watch connected to the phone in the Wear OS / OnePlus Health app.
