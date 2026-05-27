# UHF RFID Scanner

[![pub package](https://img.shields.io/pub/v/uhf_rfid_scanner.svg)](https://pub.dev/packages/uhf_rfid_scanner)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-android-green.svg)](https://flutter.dev)

Flutter plugin for UHF RFID handheld scanners. Communicate with RFID hardware over method channels to scan tags, control antenna power, and decode SGTIN-96 EPCs to EAN-13 barcodes.

## Supported Devices

| Device | Status |
|---|---|
| NewLand MT93 | ✅ Supported |
| Urovo DT610 | ✅ Supported |

> **Auto-detection:** The plugin automatically detects the device manufacturer at runtime and uses the correct RFID SDK. No configuration needed — just call `connect()` and it works on both devices.

## Features

- **Connect / Disconnect** — Power on/off the UHF RFID module
- **Tag Scanning** — Start/stop inventory scan with real-time tag stream
- **Tag Data** — EPC, RSSI, read count, and TID for each tag
- **Power Control** — Adjust antenna read/write power (5–33 dBm)
- **SGTIN-96 Decoding** — Automatically decode SGTIN-96 EPC to EAN-13 barcode

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  uhf_rfid_scanner: ^3.0.0
```

Or install via command line:

```bash
flutter pub add uhf_rfid_scanner
```

## Usage

```dart
import 'package:uhf_rfid_scanner/rfid.dart';

final rfid = Rfid();

// Connect to the RFID module
await rfid.connect();

// Set antenna power (value in dBm × 100, e.g. 3000 = 30 dBm)
await rfid.setPower(3000, 3000);

// Listen for scanned tags
rfid.onTagsRead.listen((tags) {
  for (var tag in tags) {
    print('EPC: ${tag.epc}');
    print('RSSI: ${tag.rssi}');
    print('Read Count: ${tag.readCount}');
    if (tag.ean != null) {
      print('EAN-13: ${tag.ean}');
    }
  }
});

// Start scanning
await rfid.startScan();

// Stop scanning
await rfid.stopScan();

// Disconnect
await rfid.disconnect();
```

## API Reference

### `Rfid` class

| Method | Return Type | Description |
|---|---|---|
| `connect()` | `Future<bool>` | Powers on the RFID module |
| `disconnect()` | `Future<bool>` | Powers off the RFID module |
| `startScan()` | `Future<bool>` | Starts tag inventory |
| `stopScan()` | `Future<bool>` | Stops tag inventory |
| `setPower(int readPower, int writePower)` | `Future<void>` | Sets antenna power (range: 500–3300) |
| `onTagsRead` | `Stream<List<UHFTag>>` | Stream of scanned tags |

### `UHFTag` class

| Field | Type | Description |
|---|---|---|
| `epc` | `String` | Electronic Product Code (hex) |
| `rssi` | `int` | Signal strength |
| `readCount` | `int` | Number of times the tag was read |
| `tid` | `String?` | Tag identifier (if available) |
| `ean` | `String?` | EAN-13 barcode (auto-decoded from SGTIN-96 EPC) |

### `Sgtin96Decoder`

| Method | Description |
|---|---|
| `Sgtin96Decoder.decode(String epcHex)` | Decodes a 24-char SGTIN-96 hex string to EAN-13. Returns `null` if not a valid SGTIN-96. |

## Platform Support

| Platform | Supported |
|---|---|
| Android | ✅ (min SDK 24) |
| iOS | ❌ |
| Web | ❌ |

## Requirements

- Physical **NewLand MT93** or **Urovo DT610** device (RFID hardware is not available on emulators)
- Android API 24+
- The NewLand and Urovo UHF SDK libraries are bundled with this plugin

## Contributing

Contributions are welcome! Please open an issue or submit a pull request on [GitHub](https://github.com/bavirihari/newLandMT93RFID).

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
