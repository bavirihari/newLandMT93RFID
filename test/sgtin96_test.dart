// Quick test to verify SGTIN-96 decoding against known EPC → EAN pairs
import 'package:uhf_rfid_scanner/rfid.dart';

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

  int passed = 0;
  int failed = 0;

  testCases.forEach((epc, expectedEan) {
    final decoded = Sgtin96Decoder.decode(epc);
    if (decoded == expectedEan) {
      print('✓ $epc → $decoded');
      passed++;
    } else {
      print('✗ $epc → $decoded (expected $expectedEan)');
      failed++;
    }
  });

  print('\nResults: $passed passed, $failed failed');
}
