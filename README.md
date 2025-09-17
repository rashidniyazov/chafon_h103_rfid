# chafon\_h103\_rfid

Flutter plugin for **Chafon H103 Bluetooth UHF RFID Sled Reader** (and compatible Chafon BLE UHF devices). Provides a high‑level Dart API over the official Android SDK (.aar), including connect/disconnect, continuous inventory, single‑tag read, battery level, power & region configuration, and saving parameters to device flash.

> **Status**: Android ✅ (BLE). iOS ❌ (not supported by vendor SDK at the moment).

---

## ✨ Features

* Connect / disconnect via Bluetooth Low Energy (BLE)
* Start / stop **continuous inventory** (EPC/TID) with stream callbacks
* **Single‑tag read** with memory bank & start address options
* Get **battery level**
* Set **output power** & **region**
* Read current device configuration (RAM)
* Save parameters to **flash** and **reboot** device
* Optional “radar / find tag” mode using beeps (proximity hint)

---

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  chafon_h103_rfid: ^0.0.1
```

> Replace version with the latest published on pub.dev.

If using directly from GitHub while developing:

```yaml
dependencies:
  chafon_h103_rfid:
    git:
      url: https://github.com/rashidniyazov/chafon_h103_rfid.git
      ref: main
```

---

## 🧰 Android setup

Because the vendor SDK is Android‑only, extra setup is required in the **host app**.

### 1) Min/Target SDK

* **minSdkVersion**: 23+
* **compile/targetSdk**: 33+ (tested up to 34)

### 2) Permissions (AndroidManifest.xml)

Add *exactly what you need* based on target SDK. For **SDK 31+**:

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-feature android:name="android.hardware.bluetooth_le" android:required="true" />

<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />

<!-- For scanning on Android 12+, you must declare usesPermissionFlags / neverForLocation if applicable -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

> Note: For Android 12+ you must request **BLUETOOTH\_CONNECT** and **BLUETOOTH\_SCAN** at runtime. For Android < 12, Location may be required for BLE scan.

### 3) Vendor SDK (.aar)

This plugin bundles the Chafon SDK `.aar` internally under its `android/libs`. If you fork or replace the SDK, make sure `android/build.gradle` includes:

```gradle
repositories {
    flatDir { dirs 'libs' }
}

dependencies {
    implementation files('libs/cf-sdk-v1.0.0.aar')
}
```

> If you use a different SDK version/name, adjust the file path accordingly.

### 4) ProGuard / R8 (release builds)

If you enable minification, add rules to keep the SDK classes (adjust package if vendor changes):

```pro
-keep class com.chafon.** { *; }
-dontwarn com.chafon.**
```

---

## 🚀 Quick start

```dart
import 'package:chafon_h103_rfid/chafon_h103_rfid.dart';

final reader = ChafonH103.instance;

Future<void> initAndConnect() async {
  // 1) Ensure runtime permissions are granted (see section below)

  // 2) Connect by MAC address
  final ok = await reader.connect(mac: 'AA:BB:CC:DD:EE:FF');
  if (!ok) throw Exception('Failed to connect');

  // 3) Read battery
  final battery = await reader.getBatteryLevel();
  print('Battery: $battery%');
}

Future<void> startInventoryStream() async {
  // Listen EPC/TID stream
  final sub = reader.inventoryStream.listen((tag) {
    // tag.epc, tag.tid, tag.rssi, etc.
    print('TAG: ${tag.epc}  RSSI: ${tag.rssi}');
  });

  await reader.startInventory(
    memory: MemoryBank.epc, // or MemoryBank.tid
    withBeep: true,
  );

  // ... later
  await reader.stopInventory();
  await sub.cancel();
}

Future<void> readSingle() async {
  final res = await reader.readSingleTag(
    memory: MemoryBank.tid,
    startAddress: 0x00,
    length: 6, // words
  );
  print('Single read: ${res.dataHex}');
}

Future<void> configurePowerAndSave() async {
  await reader.setOutputPower(25); // 0..30 (device dependent)
  await reader.setRegion(Region.eu3); // example

  // Writes to RAM first, then saves to FLASH & reboots (if supported)
  final saved = await reader.saveParamsToFlash();
  print('Saved: $saved');
}

Future<void> disconnect() => reader.disconnect();
```

> The exact enums and method names are part of this plugin’s Dart API. See **API reference** and the **example** app in this repo for more.

---

## 🔐 Runtime permissions helper

Use your favorite permission plugin (e.g. `permission_handler`) to request at runtime:

```dart
import 'package:permission_handler/permission_handler.dart';

Future<bool> ensureBlePermissions() async {
  final req = await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.locationWhenInUse, // for Android <12 or some devices
  ].request();
  return req.values.every((s) => s.isGranted);
}
```

Call `ensureBlePermissions()` before scanning/connecting.

---

## 🧪 Example app

This repository contains a minimal example under `example/` showing:

* Connect / disconnect
* Battery level
* Start/stop inventory and render live tag list
* Single‑tag read dialog (EPC/TID)
* Output power slider & region selector
* Save to flash + reboot

Run it with:

```bash
flutter run -d <your-android-device>
```

---

## ❓ Troubleshooting

* **`PlatformException(TIMEOUT)` after save to flash**: ensure you wait for device ACK (0x79) and avoid parallel requests while saving. Try increasing internal timeouts.
* **No tags**: verify antenna and output power; confirm correct memory bank.
* **BLE scan finds nothing**: check runtime permissions; on Android 12+ you need `BLUETOOTH_SCAN` with proper flags; some devices require Location enabled.
* **`app not installed` on debug APK**: if you’re building
  `app-x86_64-release.apk`, use a matching ABI or build a universal/split APK for your device.

---

## 🗺️ Roadmap

* Write EPC / lock / kill support
* iOS support (if/when vendor SDK is provided)
* Better radar mode with signal smoothing
* Unit tests & integration tests (mock BLE layer)

---

## 🤝 Contributing

PRs and issues are welcome! Please open an issue with device logs if you hit a bug. For feature requests, outline your use case and device firmware version.

---

## 📄 License

Apache-2.0 (see [LICENSE](LICENSE)).

---

## 🧾 Changelog

See [CHANGELOG.md](CHANGELOG.md).

---

## 🔗 Links

* Repository: [https://github.com/rashidniyazov/chafon\_h103\_rfid](https://github.com/rashidniyazov/chafon_h103_rfid)
* Issues: [https://github.com/rashidniyazov/chafon\_h103\_rfid/issues](https://github.com/rashidniyazov/chafon_h103_rfid/issues)
* Pub.dev: [https://pub.dev/packages/chafon\_h103\_rfid](https://pub.dev/packages/chafon_h103_rfid) (after publish)
