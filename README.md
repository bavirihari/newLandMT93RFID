# rfid

[![pub package](https://img.shields.io/pub/v/rfid.svg)](https://pub.dev/packages/rfid)
[![Platform](https://img.shields.io/badge/platform-android-green.svg)](https://developer.android.com)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A Flutter plugin for integrating **UHF RFID** scanning functionality exclusively for **Newland MT93** handheld devices. This plugin provides a simple, stream-based API to connect to the built-in UHF RFID module, perform real-time tag inventory scans, and configure antenna power — all from Dart.

---

## Table of Contents

- [Features](#features)
- [Supported Hardware](#supported-hardware)
- [Supported RFID Tags](#supported-rfid-tags)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [API Reference](#api-reference)
  - [Rfid Class](#rfid-class)
  - [UHFTag Class](#uhftag-class)
- [Full Example](#full-example)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)
- [Contributing](#contributing)
- [License](#license)

---

## Features

- 🔌 **Connect / Disconnect** — Power on/off the built-in UHF RFID module
- 📡 **Start / Stop Scan** — Trigger continuous tag inventory with a single method call
- 🔄 **Real-time Tag Stream** — Receive scanned tags via a Dart `Stream<List<UHFTag>>`
- ⚡ **Antenna Power Control** — Adjust read/write power (5 dBm – 33 dBm)
- 🏷️ **Rich Tag Data** — Retrieve EPC, RSSI, read count, and TID per tag
- 📦 **Zero Configuration** — Native SDKs and `.so` libraries are bundled inside the plugin

---

## Supported Hardware

| Device       | Model        | Status             |
| ------------ | ------------ | ------------------ |
| Newland MT93 | MT93-U (UHF) | ✅ Fully Supported |

> **Note:** This plugin relies on Newland's proprietary UHF SDK (`nls_uhf_lib.jar`, `aidc_uhf_sdk.jar`) and native libraries (`libaidc_uhf_pda.so`). It will **only** function on Newland MT93 devices with a built-in UHF RFID module. On unsupported devices, `connect()` will return an error.

---

## Supported RFID Tags

This plugin supports reading **EPC Gen2 (ISO 18000-6C)** UHF RFID tags, which is the global standard for passive UHF RFID. This includes:

| Tag Type            | Protocol     | Support |
| ------------------- | ------------ | ------- |
| EPC Class 1 Gen 2   | ISO 18000-6C | ✅ Full |
| EPC Global Gen 2 V2 | ISO 18000-63 | ✅ Full |

### What Can Be Read

| Data Field                        | Description                                         |      Always Available      |
| --------------------------------- | --------------------------------------------------- | :------------------------: |
| **EPC** (Electronic Product Code) | Unique tag identifier (hex string)                  |             ✅             |
| **RSSI**                          | Signal strength indicator                           |             ✅             |
| **Read Count**                    | Number of times the tag was read in current session |             ✅             |
| **TID** (Tag Identifier)          | Chip manufacturer/model data (embedded data)        | ⚠️ Only if tag supports it |

### Compatible Tag Chips

Any passive UHF RFID tag operating in the **860–960 MHz** frequency range, including but not limited to:

- **Impinj** Monza (R6, M700, M800)
- **NXP** UCODE (7, 8, 9, DNA)
- **Alien** Higgs (3, 4, EC)
- **EM Microelectronic** EM4325
- Inlay tags, hard tags, wristbands, labels, and cards conforming to EPC Gen2

---

## Requirements

| Requirement        | Version          |
| ------------------ | ---------------- |
| Flutter            | ≥ 3.3.0          |
| Dart SDK           | ≥ 3.9.2          |
| Android minSdk     | 24 (Android 7.0) |
| Android compileSdk | 36               |
| Device             | Newland MT93-U   |

---

## Installation

Add the plugin to your `pubspec.yaml`:

```yaml
dependencies:
  rfid: ^0.0.1
```

Then run:

```bash
flutter pub get
```

### Android Permissions

The plugin's `AndroidManifest.xml` already declares the required permissions. No additional setup is needed in your app:

```xml
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.VIBRATE" />
```

---

## Quick Start

```dart
import 'package:rfid/rfid.dart';
import 'dart:async';

// 1. Create an instance
final rfid = Rfid();

// 2. Connect to the UHF module
await rfid.connect();

// 3. Listen for tags
StreamSubscription? subscription;
subscription = rfid.onTagsRead.listen((List<UHFTag> tags) {
  for (var tag in tags) {
    print('EPC: ${tag.epc}, RSSI: ${tag.rssi}, Count: ${tag.readCount}');
  }
});

// 4. Start scanning
await rfid.startScan();

// ... scanning in progress ...

// 5. Stop scanning
await rfid.stopScan();
await subscription?.cancel();

// 6. Disconnect
await rfid.disconnect();
```

---

## API Reference

### Rfid Class

Import via:

```dart
import 'package:rfid/rfid.dart';
```

#### `connect()`

Powers on the UHF RFID module.

```dart
Future<bool> connect()
```

| Returns | Description                    |
| ------- | ------------------------------ |
| `true`  | Module powered on successfully |
| `false` | Connection failed              |

Throws a `PlatformException` with code `NO_HARDWARE` if the device does not have a compatible UHF module.

---

#### `disconnect()`

Powers off the UHF RFID module. Always call `stopScan()` before disconnecting.

```dart
Future<bool> disconnect()
```

| Returns | Description                     |
| ------- | ------------------------------- |
| `true`  | Module powered off successfully |
| `false` | Disconnection failed            |

---

#### `startScan()`

Begins a continuous tag inventory scan. Tags are delivered through the `onTagsRead` stream. Make sure to subscribe to the stream **before** calling `startScan()`.

```dart
Future<bool> startScan()
```

| Returns | Description               |
| ------- | ------------------------- |
| `true`  | Scan started successfully |
| `false` | Failed to start scanning  |

---

#### `stopScan()`

Stops the current tag inventory scan.

```dart
Future<bool> stopScan()
```

| Returns | Description               |
| ------- | ------------------------- |
| `true`  | Scan stopped successfully |
| `false` | Failed to stop scanning   |

---

#### `setPower(int readPower, int writePower)`

Adjusts the antenna read and write power levels.

```dart
Future<void> setPower(int readPower, int writePower)
```

| Parameter    | Type  | Range      | Description                                     |
| ------------ | ----- | ---------- | ----------------------------------------------- |
| `readPower`  | `int` | 500 – 3300 | Read power in centidBm (e.g., `3000` = 30 dBm)  |
| `writePower` | `int` | 500 – 3300 | Write power in centidBm (e.g., `3000` = 30 dBm) |

**Power Conversion:**

| Value  | Actual Power     |
| ------ | ---------------- |
| `500`  | 5 dBm            |
| `1500` | 15 dBm           |
| `2000` | 20 dBm           |
| `3000` | 30 dBm (default) |
| `3300` | 33 dBm (maximum) |

---

#### `onTagsRead`

A broadcast stream that emits batches of scanned UHF tags in real-time.

```dart
Stream<List<UHFTag>> get onTagsRead
```

Subscribe to this stream **before** calling `startScan()`. Each event contains a `List<UHFTag>` with one or more tags discovered in that scan cycle.

---

#### `getPlatformVersion()`

Returns the Android version string. Useful for diagnostic purposes.

```dart
Future<String?> getPlatformVersion()
```

---

### UHFTag Class

Represents a single RFID tag read from the scanner.

```dart
class UHFTag {
  final String epc;       // Electronic Product Code (hex string)
  final int rssi;         // Signal strength indicator
  final int readCount;    // Number of times read in this session
  final String? tid;      // Tag Identifier (optional, chip-dependent)
}
```

| Property    | Type      | Description                                                                 |
| ----------- | --------- | --------------------------------------------------------------------------- |
| `epc`       | `String`  | The tag's EPC in hexadecimal format (e.g., `"E200001A0B0C0D0E"`)            |
| `rssi`      | `int`     | Received Signal Strength Indicator — lower absolute value = stronger signal |
| `readCount` | `int`     | How many times the tag has been read during the active scan session         |
| `tid`       | `String?` | Tag Identifier Data — available only if the tag chip provides embedded data |

---

## Full Example

Below is a complete working example demonstrating connect, scan, power control, and tag display:

```dart
import 'package:flutter/material.dart';
import 'package:rfid/rfid.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RFID Scanner Demo',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const RfidScannerPage(),
    );
  }
}

class RfidScannerPage extends StatefulWidget {
  const RfidScannerPage({super.key});

  @override
  State<RfidScannerPage> createState() => _RfidScannerPageState();
}

class _RfidScannerPageState extends State<RfidScannerPage> {
  final _rfid = Rfid();
  bool _isConnected = false;
  bool _isScanning = false;
  final Map<String, UHFTag> _tags = {};
  StreamSubscription? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    _rfid.stopScan();
    _rfid.disconnect();
    super.dispose();
  }

  Future<void> _connect() async {
    final success = await _rfid.connect();
    setState(() => _isConnected = success);
  }

  Future<void> _disconnect() async {
    await _stopScan();
    final success = await _rfid.disconnect();
    setState(() => _isConnected = !success);
  }

  Future<void> _startScan() async {
    if (!_isConnected) return;
    setState(() {
      _tags.clear();
      _isScanning = true;
    });

    // 1. Subscribe to the tag stream FIRST
    _subscription = _rfid.onTagsRead.listen((List<UHFTag> incoming) {
      setState(() {
        for (var tag in incoming) {
          _tags[tag.epc] = tag; // Deduplicate by EPC
        }
      });
    });

    // 2. Then trigger the hardware scan
    final success = await _rfid.startScan();
    if (!success) {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _stopScan() async {
    await _rfid.stopScan();
    await _subscription?.cancel();
    setState(() => _isScanning = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RFID Scanner')),
      body: Column(
        children: [
          // Connection controls
          Row(
            children: [
              ElevatedButton(
                onPressed: _isConnected ? null : _connect,
                child: const Text('Connect'),
              ),
              ElevatedButton(
                onPressed: _isConnected ? _disconnect : null,
                child: const Text('Disconnect'),
              ),
            ],
          ),
          // Scan controls
          Row(
            children: [
              ElevatedButton(
                onPressed: (_isConnected && !_isScanning) ? _startScan : null,
                child: const Text('Start Scan'),
              ),
              ElevatedButton(
                onPressed: (_isConnected && _isScanning) ? _stopScan : null,
                child: const Text('Stop Scan'),
              ),
            ],
          ),
          // Tag count
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Total Tags: ${_tags.length}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          // Tag list
          Expanded(
            child: ListView.builder(
              itemCount: _tags.length,
              itemBuilder: (context, index) {
                final tag = _tags.values.elementAt(index);
                return ListTile(
                  title: Text(tag.epc),
                  subtitle: Text('RSSI: ${tag.rssi} | Count: ${tag.readCount}'),
                  trailing: tag.tid != null ? Text('TID: ${tag.tid}') : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

A more complete example with power control and RSSI visualization is available in the [example/](example/) directory.

---

---

## Troubleshooting

### `PlatformException(NO_HARDWARE, ...)`

The device does not have a compatible UHF module. This plugin only works on **Newland MT93-U** devices.

### `connect()` returns `false`

- Ensure the RFID module is not already in use by another app.
- Try restarting the device.
- Verify the device model is MT93 with a UHF module.

### `startScan()` returns `false`

- Make sure `connect()` was called and returned `true` first.
- Check that another scan session isn't already active.

### No tags appearing in the stream

- Verify that you subscribed to `onTagsRead` **before** calling `startScan()`.
- Ensure RFID tags are within range (typically 1–8 meters depending on power level and tag type).
- Try increasing the antenna power using `setPower()`.

### App crashes on non-Newland devices

The plugin gracefully handles missing hardware by catching SDK initialization errors. If `connect()` is called on an unsupported device, it will throw a `PlatformException` with code `NO_HARDWARE` instead of crashing. Always wrap calls in try-catch blocks.

---

## FAQ

**Q: Does this plugin work on iOS?**
A: No. The Newland MT93 is an Android-only device. This plugin only supports Android.

**Q: Can I use this on other Newland devices?**
A: This plugin is built and tested for the MT93-U model. Other Newland devices using the same UHF SDK may work, but are not officially supported.

**Q: Does this support writing to tags?**
A: The current version (0.0.1) supports **reading** (inventory scan) only. Tag writing may be added in future releases.

**Q: What is the maximum read range?**
A: Read range depends on the tag type and antenna power setting. At maximum power (33 dBm), typical range is **3–8 meters** for standard inlay tags.

**Q: Can I read multiple tags simultaneously?**
A: Yes. The plugin performs continuous inventory scanning and can detect **hundreds of tags** in a single scan session. Tags are delivered in batches through the stream.

---

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  Made with ❤️ for the Flutter community
</p>
