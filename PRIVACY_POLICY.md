# Privacy Policy — SimplySpectrum

**Last updated: July 3, 2026**

SimplySpectrum is an open-source visual spectrum analyzer developed by
[igrowing](https://github.com/igrowing/SimplySpectrum). This policy explains what
data the app accesses, why, and what it does (and does not) do with it.

---

## 1. Summary (TL;DR)

- SimplySpectrum **does not collect, store, transmit, or share any personal data**.
- All processing happens **locally on your device**. Nothing leaves your phone.
- There are **no ads, no analytics, no tracking, no telemetry**.
- The app is **open source** — you can inspect every line of code at
  [github.com/igrowing/SimplySpectrum](https://github.com/igrowing/SimplySpectrum).

---

## 2. Permissions and Why They Are Used

### Location (ACCESS_FINE_LOCATION / ACCESS_COARSE_LOCATION)

Android requires the **Location** permission for any app that reads Wi-Fi
scan results (e.g., SSID, BSSID, signal strength, channel). This is an
Android platform policy — SimplySpectrum cannot read Wi-Fi network information
without it.

SimplySpectrum uses this permission **only** to:

- Detect the current Wi-Fi network's subnet (CIDR range) for LAN scanning.
- Retrieve Wi-Fi channel and signal data for the "Wi-Fi Channels" screen.

The app **never** derives your physical location from this permission. It
does not use GPS. It does not record, transmit, or log your location.

### Network / Internet Access (INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE, CHANGE_WIFI_STATE)

Required to perform network scans, ping, traceroute, DNS lookup, speed
tests, and public IP detection. All of these operations are initiated
explicitly by you. Results are displayed on screen only.

### Foreground Service (FOREGROUND_SERVICE, WAKE_LOCK)

Used to keep long-running operations (network scan, ping) alive when the
phone screen dims. A notification is shown while a scan is running, as
required by Android. The notification disappears automatically when the
operation completes.

### Post Notifications (POST_NOTIFICATIONS — Android 13+)

Required on Android 13 and later to display the foreground service
notification described above.

### READ_PHONE_STATE

Declared for future use to read cellular network data (tower info, signal
quality). Not actively requested at runtime in the current version.

---

## 3. Data Storage

SimplySpectrum stores only **user-created data on your device**:

| What | Where | Why |
|------|-------|-----|
| App settings (screen timeout, logging toggle) | Android SharedPreferences | Persist your preferences across sessions |
| Scan and diagnostic logs | App internal storage (not accessible to other apps) | Optional — only when you enable "Logging" in Settings |

No data is stored in the cloud. No account is required. No registration.
Uninstalling the app removes all stored data.

---

## 4. Third-Party Libraries

SimplySpectrum uses the following **open-source libraries**. None of them collect,
transmit, or process personal data. All are distributed under permissive
open-source licenses.

| Library | License | Purpose |
|---------|---------|---------|
| [Flutter](https://flutter.dev) | BSD 3-Clause | UI framework |
| [provider](https://pub.dev/packages/provider) | MIT | State management |
| [shared_preferences](https://pub.dev/packages/shared_preferences) | BSD 3-Clause | Local settings storage |
| [path_provider](https://pub.dev/packages/path_provider) | BSD 3-Clause | Access app-scoped file paths |
| [permission_handler](https://pub.dev/packages/permission_handler) | MIT | Request runtime permissions |
| [network_info_plus](https://pub.dev/packages/network_info_plus) | BSD 3-Clause | Read Wi-Fi/network interface info |
| [url_launcher](https://pub.dev/packages/url_launcher) | BSD 3-Clause | Open links (About screen) |
| [http](https://pub.dev/packages/http) | BSD 3-Clause | Speed test and public IP lookup |
| [intl](https://pub.dev/packages/intl) | BSD 3-Clause | Date/number formatting |
| [flutter_foreground_task](https://pub.dev/packages/flutter_foreground_task) | MIT | Android foreground service |
| [mac_address_plus](https://pub.dev/packages/mac_address_plus) | MIT | Read device MAC address |

None of these libraries have their own privacy policy, analytics SDKs, or
network communication beyond what is described above.

There are **no third-party advertising SDKs**, **no crash reporting services**,
and **no analytics platforms** integrated in SimplySpectrum.

---

## 5. Children's Privacy

SimplySpectrum is a technical utility app intended for adults and design professionals.
It does not target children and does not knowingly collect any data from anyone.

---

## 6. Changes to This Policy

If the app ever changes in a way that affects privacy (e.g., a new permission
is added), this policy will be updated and the "Last updated" date will change.
The policy is always available at:
[https://igrowing.github.io/SimplySpectrum/PRIVACY_POLICY.md](https://igrowing.github.io/SimplySpectrum/PRIVACY_POLICY.md)

---

## 7. Contact

Questions about this privacy policy:
[GitHub Issues](https://github.com/igrowing/SimplySpectrum/issues) or open a
discussion at the repository above.
