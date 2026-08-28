# Privacy Policy — SimplySpectrum

**Last updated: August 28, 2026**

SimplySpectrum is an open-source visual spectrum analyzer and color detector
developed by [igrowing](https://github.com/igrowing/SimplySpectrum). This policy
explains what data the app accesses, why, and what it does (and does not) do
with it.

---

## 1. Summary (TL;DR)

- SimplySpectrum **does not collect, store, transmit, or share any personal data**.
- All image and light analysis happens **locally on your device in real time**.
  Camera frames are processed in memory and never saved unless *you* tap
  "Snapshot".
- The app has **no internet permission**. It cannot send anything anywhere.
- There are **no ads, no analytics, no tracking, no telemetry, no accounts**.
- The app is **open source** — you can inspect every line of code at
  [github.com/igrowing/SimplySpectrum](https://github.com/igrowing/SimplySpectrum).

---

## 2. Permissions and Why They Are Used

### Camera (CAMERA / NSCameraUsageDescription)

The core function of the app. SimplySpectrum reads the live camera feed to:

- Compute the visible-light spectrum histogram (400–700 nm).
- Compute the luminosity histogram and approximate lux readout.
- Detect the average color, color peaks, and the brightest/darkest spots.
- Show the camera preview (and, optionally, a color-enhanced preview) on screen.

Camera frames are analyzed **frame by frame in memory** and then discarded.
They are **never** written to disk, cached, or transmitted. Nothing in the app
performs face detection, object recognition, or any form of identification.

### Photo Library / Storage (write access)

Used **only** when you tap the **Snapshot** button, to save a screenshot of the
app (charts + camera view) to your device gallery.

- **Android 13+ (API 33+):** the snapshot is written through the system media
  store; no broad storage permission is requested.
- **Android 9–12:** `WRITE_EXTERNAL_STORAGE` / `READ_EXTERNAL_STORAGE` /
  `READ_MEDIA_IMAGES` are requested at the moment you first save a snapshot,
  because older Android versions require them to write into the public
  `Pictures` folder. `WRITE_EXTERNAL_STORAGE` is capped at `maxSdkVersion=29`.
- **iOS:** `NSPhotoLibraryAddUsageDescription` covers add-only access to save
  the snapshot.

The app never reads, browses, or uploads your existing photos. It only adds the
image you explicitly asked it to save.

### No Internet, Location, Microphone, or Background Access

SimplySpectrum does **not** declare the `INTERNET` permission and has no network
code. It does **not** request location, microphone, contacts, phone state,
notifications, or any background/foreground service. The "Buy me a coffee" link
in Settings opens your normal web browser via the operating system — the app
itself makes no connection.

### Keep Screen On

The "Keep screen on" toggle sets a standard window flag
(`FLAG_KEEP_SCREEN_ON` on Android, `isIdleTimerDisabled` on iOS) so the display
does not dim while you watch the live charts. This involves no data of any kind.

---

## 3. Data Storage

SimplySpectrum stores only the following, entirely **on your device**:

| What | Where | Why |
|------|-------|-----|
| App settings (theme, main-screen layout order, detection toggles, "keep screen on") | Android SharedPreferences / iOS `NSUserDefaults` | Persist your preferences across sessions |
| Snapshots you save | Your device photo gallery (`Pictures/SimplySpectrum` album) | Only created when you tap "Snapshot"; managed by you afterwards |

No data is stored in the cloud. No account is required. No registration.
Diagnostic log messages, when present, are routed only to the developer
debug console and are never written to a file. Uninstalling the app removes all
app settings; snapshots you saved to your gallery remain until you delete them.

---

## 4. Third-Party Libraries

SimplySpectrum uses the following **open-source libraries**. None of them
collect, transmit, or process personal data, and none contain advertising or
analytics SDKs.

| Library | License | Purpose |
|---------|---------|---------|
| [Flutter](https://flutter.dev) | BSD 3-Clause | UI framework |
| [camera](https://pub.dev/packages/camera) | BSD 3-Clause | Access the camera feed for analysis |
| [provider](https://pub.dev/packages/provider) | MIT | State management |
| [get_it](https://pub.dev/packages/get_it) | MIT | Dependency injection / service locator |
| [equatable](https://pub.dev/packages/equatable) | MIT | Value equality for model classes |
| [shared_preferences](https://pub.dev/packages/shared_preferences) | BSD 3-Clause | Local settings storage |
| [permission_handler](https://pub.dev/packages/permission_handler) | MIT | Request camera / storage permissions at runtime |
| [gal](https://pub.dev/packages/gal) | MIT | Save snapshots to the device gallery |
| [package_info_plus](https://pub.dev/packages/package_info_plus) | BSD 3-Clause | Read the app version for the Settings screen |
| [url_launcher](https://pub.dev/packages/url_launcher) | BSD 3-Clause | Open the "Buy me a coffee" link in an external browser |
| [cupertino_icons](https://pub.dev/packages/cupertino_icons) | MIT | Icon font |

There are **no third-party advertising SDKs**, **no crash reporting services**,
and **no analytics platforms** integrated in SimplySpectrum.

---

## 5. Children's Privacy

SimplySpectrum is a technical utility and educational tool. It does not target
children, shows no ads, and does not knowingly collect any data from anyone.

---

## 6. Changes to This Policy

If the app ever changes in a way that affects privacy (e.g., a new permission is
added), this policy will be updated and the "Last updated" date will change.
The policy is always available at:
[https://igrowing.github.io/SimplySpectrum/PRIVACY_POLICY.md](https://igrowing.github.io/SimplySpectrum/PRIVACY_POLICY.md)

---

## 7. Contact

Questions about this privacy policy:
[GitHub Issues](https://github.com/igrowing/SimplySpectrum/issues) or open a
discussion at the repository above.
