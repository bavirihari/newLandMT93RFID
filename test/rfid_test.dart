import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_rfid_scanner/rfid.dart';
import 'package:uhf_rfid_scanner/rfid_platform_interface.dart';
import 'package:uhf_rfid_scanner/rfid_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockRfidPlatform with MockPlatformInterfaceMixin implements RfidPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final RfidPlatform initialPlatform = RfidPlatform.instance;

  test('$MethodChannelRfid is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelRfid>());
  });

  test('getPlatformVersion', () async {
    const MethodChannel channel = MethodChannel('rfid');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'getPlatformVersion') return '42';
          return null;
        });

    Rfid rfidPlugin = Rfid();
    expect(await rfidPlugin.getPlatformVersion(), '42');
  });
}
