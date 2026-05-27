/// Flutter plugin for UHF RFID handheld scanners.
///
/// Supports NewLand MT93 and Urovo DT610. Provides methods to
/// connect, scan UHF tags, adjust antenna power, and receive tag data
/// via streams.
library;

import 'dart:async';
import 'package:flutter/services.dart';

class Rfid {
  static const MethodChannel _channel = MethodChannel('rfid');
  static const EventChannel _stream = EventChannel('rfid/scan_stream');

  /// Powers on the RFID Module.
  Future<bool> connect() async {
    final bool? success = await _channel.invokeMethod('connect');
    return success ?? false;
  }

  /// Powers off the RFID Module.
  Future<bool> disconnect() async {
    final bool? success = await _channel.invokeMethod('disconnect');
    return success ?? false;
  }

  /// Starts reading tags.
  Future<bool> startScan() async {
    final bool? success = await _channel.invokeMethod('startScan');
    return success ?? false;
  }

  /// Stops reading tags.
  Future<bool> stopScan() async {
    final bool? success = await _channel.invokeMethod('stopScan');
    return success ?? false;
  }

  /// Sets antenna power for read and write operations.
  ///
  /// Range: 500–3300 (i.e. 5 dBm to 33 dBm).
  /// Example: 3000 = 30 dBm.
  Future<void> setPower(int readPower, int writePower) async {
    await _channel.invokeMethod('setPower', {
      "readPower": readPower,
      "writePower": writePower,
    });
  }

  /// Returns the Android version string.
  Future<String?> getPlatformVersion() {
    return _channel.invokeMethod('getPlatformVersion');
  }

  Stream<List<UHFTag>>? _cachedTagStream;

  /// Stream of scanned tags, emitting a list of [UHFTag] on each read cycle.
  Stream<List<UHFTag>> get onTagsRead {
    _cachedTagStream ??= _stream.receiveBroadcastStream().map((dynamic event) {
      List<dynamic> list = event;
      return list.map((map) => UHFTag.fromMap(map)).toList();
    }).asBroadcastStream();
    return _cachedTagStream!;
  }
}

/// Represents a UHF RFID tag read from the scanner.
class UHFTag {
  final String epc;
  final int rssi;
  final int readCount;
  final String? tid;

  /// EAN-13 barcode decoded from SGTIN-96 EPC, or null if EPC is not SGTIN-96.
  late final String? ean;

  UHFTag({
    required this.epc,
    required this.rssi,
    required this.readCount,
    this.tid,
  }) {
    ean = Sgtin96Decoder.decode(epc);
  }

  factory UHFTag.fromMap(dynamic map) {
    return UHFTag(
      epc: map['epc'] ?? '',
      rssi: map['rssi'] ?? 0,
      readCount: map['readCount'] ?? 1,
      tid: map['tid'],
    );
  }
}

/// Decodes SGTIN-96 EPC hex strings into EAN-13 barcodes.
///
/// SGTIN-96 is a 96-bit (24 hex char) encoding. See GS1 EPC Tag Data Standard
/// for the full bit layout specification.
class Sgtin96Decoder {
  // Partition table: [companyPrefixBits, companyPrefixDigits, itemRefBits, itemRefDigits]
  static const List<List<int>> _partitionTable = [
    [40, 12, 4, 1],
    [37, 11, 7, 2],
    [34, 10, 10, 3],
    [30, 9, 14, 4],
    [27, 8, 17, 5],
    [24, 7, 20, 6],
    [20, 6, 24, 7],
  ];

  /// Decodes a SGTIN-96 EPC hex string to EAN-13.
  /// Returns null if the EPC is not a valid SGTIN-96.
  static String? decode(String epcHex) {
    epcHex = epcHex.replaceAll(' ', '').toUpperCase();

    if (epcHex.length != 24) return null;

    final BigInt epc;
    try {
      epc = BigInt.parse(epcHex, radix: 16);
    } catch (_) {
      return null;
    }

    // Header (bits 95-88) must be 0x30 for SGTIN-96
    final int header = _extractBits(epc, 95, 88);
    if (header != 0x30) return null;

    final int partition = _extractBits(epc, 84, 82);
    if (partition > 6) return null;

    final prefixBits = _partitionTable[partition][0];
    final prefixDigits = _partitionTable[partition][1];
    final itemRefBits = _partitionTable[partition][2];
    final itemRefDigits = _partitionTable[partition][3];

    final int companyPrefix = _extractBits(epc, 81, 81 - prefixBits + 1);

    final int itemRefStart = 81 - prefixBits;
    final int itemRef = _extractBits(
      epc,
      itemRefStart,
      itemRefStart - itemRefBits + 1,
    );

    // indicator_digit * 10^(itemRefDigits-1) + actual_item_ref
    final int indicatorDivisor = _pow10(itemRefDigits - 1);
    final int indicator = itemRef ~/ indicatorDivisor;
    final int actualItemRef = itemRef % indicatorDivisor;

    // GTIN-13: indicator + companyPrefix + itemRef
    final String prefixStr = companyPrefix.toString().padLeft(
      prefixDigits,
      '0',
    );
    final String itemRefStr = actualItemRef.toString().padLeft(
      itemRefDigits - 1,
      '0',
    );
    final String gtinWithoutCheck = '$indicator$prefixStr$itemRefStr';

    if (gtinWithoutCheck.length != 13) return null;

    final int checkDigit = _computeCheckDigit(gtinWithoutCheck.substring(1));
    final String ean13 = '${gtinWithoutCheck.substring(1)}$checkDigit';

    return ean13;
  }

  /// Extracts bits [highBit..lowBit] from a BigInt (0-indexed from LSB).
  static int _extractBits(BigInt value, int highBit, int lowBit) {
    final int numBits = highBit - lowBit + 1;
    final BigInt mask = (BigInt.one << numBits) - BigInt.one;
    return ((value >> lowBit) & mask).toInt();
  }

  /// Computes GS1 check digit for a 12-digit string.
  static int _computeCheckDigit(String digits) {
    int sum = 0;
    for (int i = 0; i < digits.length; i++) {
      int digit = int.parse(digits[i]);
      sum += (i.isOdd) ? digit * 3 : digit;
    }
    return (10 - (sum % 10)) % 10;
  }

  static int _pow10(int exp) {
    int result = 1;
    for (int i = 0; i < exp; i++) {
      result *= 10;
    }
    return result;
  }
}
