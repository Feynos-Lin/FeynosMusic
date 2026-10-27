# Feynos Music for Apple TV

The Apple TV version of Feynos Music, a Navidrome client with ListenBrainz history,
weekly mixes and a cover art finder.

## Install it on your Apple TV (free Apple ID)

You need a Mac with **Xcode** (free in the Mac App Store).

1. On GitHub, tap **Code → Download ZIP**, unzip it, and open
   `appletv/FeynosMusicTV.xcodeproj` in Xcode.
2. Click **FeynosMusicTV** at the top of the file list → **Signing & Capabilities** →
   choose your Apple ID under **Team** (Xcode → Settings → Accounts to add it).
   If Xcode says the bundle identifier is taken, change `com.feynos.music.tv` to
   something unique, e.g. `com.yourname.music.tv`.
3. Pair the Apple TV (same Wi-Fi as the Mac):
   - Apple TV: **Settings → Remotes and Devices → Remote App and Devices**
   - Xcode: **Window → Devices and Simulators**, select the Apple TV, click **Pair**
     and type the code shown on the TV.
4. Pick the Apple TV as the run destination at the top of Xcode and press **▶ Run**.

With a free Apple ID the app stops opening after 7 days. Just press **Run** again from
the Mac to renew it. A paid Apple Developer account removes that limit.

## Notes
- tvOS only lets apps keep data in a cache that the system may clear when storage
  runs low. Your listens are also sent to Navidrome and ListenBrainz, so history and
  mixes recover.
- Use the Apple TV Remote on your iPhone/iPad (or the Siri Remote keyboard) to type
  your server address and ListenBrainz token.
