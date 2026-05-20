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
    await _channel.invokeMethod('setPower', {
      "readPower": readPower,
      "writePower": writePower,
    });
  }

  /// Get standard Android version string (Default template method)
  Future<String?> getPlatformVersion() {
    return _channel.invokeMethod('getPlatformVersion');
  }

  // Cached stream — receiveBroadcastStream() must only be called once per EventChannel
  Stream<List<UHFTag>>? _cachedTagStream;

  /// Stream of scanned tags.
  /// Returns a List of Maps containing EPC, RSSI, etc.
  Stream<List<UHFTag>> get onTagsRead {
    _cachedTagStream ??= _stream.receiveBroadcastStream().map((dynamic event) {
      List<dynamic> list = event;
      return list.map((map) => UHFTag.fromMap(map)).toList();
    }).asBroadcastStream();
    return _cachedTagStream!;
  }
}

/// Helper class to hold Tag Data
class UHFTag {
  final String epc;
  final int rssi;
  final int readCount;
  final String? tid;

  /// The decoded EAN-13 (GTIN-13) from the SGTIN-96 EPC, or null if not decodable.
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

/// Decodes SGTIN-96 EPC hex strings into GTIN-13 (EAN-13) barcodes.
///
/// SGTIN-96 bit layout (96 bits = 24 hex chars):
///   Header(8) | Filter(3) | Partition(3) | CompanyPrefix(var) | ItemRef(var) | Serial(38)
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

  /// Decodes a SGTIN-96 EPC hex string to a GTIN-13 (EAN-13).
  /// Returns null if the EPC is not a valid SGTIN-96.
  static String? decode(String epcHex) {
    // Remove spaces and ensure uppercase
    epcHex = epcHex.replaceAll(' ', '').toUpperCase();

    // SGTIN-96 = 96 bits = 24 hex chars
    if (epcHex.length != 24) return null;

    // Parse hex to a BigInt for bit manipulation
    final BigInt epc;
    try {
      epc = BigInt.parse(epcHex, radix: 16);
    } catch (_) {
      return null;
    }

    // Header (bits 95-88, 8 bits) — must be 0x30 for SGTIN-96
    final int header = _extractBits(epc, 95, 88);
    if (header != 0x30) return null;

    // Filter (bits 87-85, 3 bits) — not needed for GTIN
    // Partition (bits 84-82, 3 bits)
    final int partition = _extractBits(epc, 84, 82);
    if (partition > 6) return null;

    final prefixBits = _partitionTable[partition][0];
    final prefixDigits = _partitionTable[partition][1];
    final itemRefBits = _partitionTable[partition][2];
    final itemRefDigits = _partitionTable[partition][3];

    // Company Prefix (starts at bit 81, length = prefixBits)
    final int companyPrefix = _extractBits(epc, 81, 81 - prefixBits + 1);

    // Item Reference (follows company prefix)
    final int itemRefStart = 81 - prefixBits;
    final int itemRef = _extractBits(
      epc,
      itemRefStart,
      itemRefStart - itemRefBits + 1,
    );

    // The item reference field encodes: indicator_digit * 10^(itemRefDigits-1) + actual_item_ref
    final int indicatorDivisor = _pow10(itemRefDigits - 1);
    final int indicator = itemRef ~/ indicatorDivisor;
    final int actualItemRef = itemRef % indicatorDivisor;

    // Build the 13-digit GTIN (without check digit = 12 digits)
    // GTIN-14 = indicator + companyPrefix + itemRef → for GTIN-13, indicator is 0
    final String prefixStr = companyPrefix.toString().padLeft(
      prefixDigits,
      '0',
    );
    final String itemRefStr = actualItemRef.toString().padLeft(
      itemRefDigits - 1,
      '0',
    );
    final String gtinWithoutCheck = '$indicator$prefixStr$itemRefStr';

    // For GTIN-13: indicator should be 0, giving us 12 digits + check digit = 13
    if (gtinWithoutCheck.length != 13) return null;

    // Compute GS1 check digit
    final int checkDigit = _computeCheckDigit(
      gtinWithoutCheck.substring(1),
    ); // skip indicator for EAN-13
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
      // Positions: odd (0-indexed) multiply by 3, even by 1
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
