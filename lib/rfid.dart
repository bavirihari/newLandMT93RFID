import 'dart:async';
import 'package:flutter/services.dart';

class Rfid {
  // Define channels to match Kotlin
  static const MethodChannel _channel = MethodChannel('rfid');
  static const EventChannel _stream = EventChannel('rfid/scan_stream');

  /// Powers on the RFID Module
  Future<bool> connect() async {
    final bool? success = await _channel.invokeMethod('connect');
    return success ?? false;
  }

  /// Powers off the RFID Module
  Future<bool> disconnect() async {
    final bool? success = await _channel.invokeMethod('disconnect');
    return success ?? false;
  }

  /// Starts reading tags
  Future<bool> startScan() async {
    final bool? success = await _channel.invokeMethod('startScan');
    return success ?? false;
  }

  /// Stops reading tags
  Future<bool> stopScan() async {
    final bool? success = await _channel.invokeMethod('stopScan');
    return success ?? false;
  }

  /// Set Antenna Power
  /// Range: Usually 500 - 3300 (5dBm to 33dBm)
  /// Example: 3000 = 30dBm
  Future<void> setPower(int readPower, int writePower) async {
    await _channel.invokeMethod('setPower', {"readPower": readPower, "writePower": writePower});
  }

  /// Get standard Android version string (Default template method)
  Future<String?> getPlatformVersion() {
    return _channel.invokeMethod('getPlatformVersion');
  }

  /// Stream of scanned tags.
  /// Returns a List of Maps containing EPC, RSSI, etc.
  Stream<List<UHFTag>> get onTagsRead {
    return _stream.receiveBroadcastStream().map((dynamic event) {
      List<dynamic> list = event;
      return list.map((map) => UHFTag.fromMap(map)).toList();
    });
  }
}

/// Helper class to hold Tag Data
class UHFTag {
  final String epc;
  final int rssi;
  final int readCount;
  final String? tid;

  UHFTag({required this.epc, required this.rssi, required this.readCount, this.tid});

  factory UHFTag.fromMap(dynamic map) {
    return UHFTag(epc: map['epc'] ?? '', rssi: map['rssi'] ?? 0, readCount: map['readCount'] ?? 1, tid: map['tid']);
  }
}
