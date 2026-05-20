// Pure Dart test - copy of decoder logic for standalone verification

class Sgtin96Decoder {
  static const List<List<int>> _partitionTable = [
    [40, 12, 4, 1], [37, 11, 7, 2], [34, 10, 10, 3],
    [30, 9, 14, 4], [27, 8, 17, 5], [24, 7, 20, 6], [20, 6, 24, 7],
  ];

  static String? decode(String epcHex) {
    epcHex = epcHex.replaceAll(' ', '').toUpperCase();
    if (epcHex.length != 24) return null;
    final BigInt epc;
    try { epc = BigInt.parse(epcHex, radix: 16); } catch (_) { return null; }
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
    final int itemRef = _extractBits(epc, itemRefStart, itemRefStart - itemRefBits + 1);
    final int indicatorDivisor = _pow10(itemRefDigits - 1);
    final int indicator = itemRef ~/ indicatorDivisor;
    final int actualItemRef = itemRef % indicatorDivisor;
    final String prefixStr = companyPrefix.toString().padLeft(prefixDigits, '0');
    final String itemRefStr = actualItemRef.toString().padLeft(itemRefDigits - 1, '0');
    final String gtinWithoutCheck = '$indicator$prefixStr$itemRefStr';
    if (gtinWithoutCheck.length != 13) return null;
    final int checkDigit = _computeCheckDigit(gtinWithoutCheck.substring(1));
    return '${gtinWithoutCheck.substring(1)}$checkDigit';
  }

  static int _extractBits(BigInt value, int highBit, int lowBit) {
    final int numBits = highBit - lowBit + 1;
    final BigInt mask = (BigInt.one << numBits) - BigInt.one;
    return ((value >> lowBit) & mask).toInt();
  }

  static int _computeCheckDigit(String digits) {
    int sum = 0;
    for (int i = 0; i < digits.length; i++) {
      int digit = int.parse(digits[i]);
      sum += (i.isOdd) ? digit * 3 : digit;
    }
    return (10 - (sum % 10)) % 10;
  }

  static int _pow10(int exp) { int r = 1; for (int i = 0; i < exp; i++) r *= 10; return r; }
}

void main() {
  final testCases = {
    '3036143C7C5E614124103607': '8720159966454',
    '3036143C7C5E618020000021': '8720159966461',
    '3016143C7C53F3402000003D': '8720159859657',
    '3016143C7C5FD0002000008C': '8720159981129',
    '3016143C7C5FD000200005DA': '8720159981129',
    '301614456C12388020000114': '8720731186584',
    '3016143C7C5FD00020000590': '8720159981129',
    '301614456C113F4124127838': '8720731176615',
    '301614456C02D6802000003D': '8720731029065',
    '3016143C7C57ABC020000056': '8720159897758',
  };
  int passed = 0, failed = 0;
  testCases.forEach((epc, expectedEan) {
    final decoded = Sgtin96Decoder.decode(epc);
    if (decoded == expectedEan) { print('✓ $epc → $decoded'); passed++; }
    else { print('✗ $epc → $decoded (expected $expectedEan)'); failed++; }
  });
  print('\n$passed passed, $failed failed');
}
