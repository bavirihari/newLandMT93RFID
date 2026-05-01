import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'rfid_platform_interface.dart';

/// An implementation of [RfidPlatform] that uses method channels.
class MethodChannelRfid extends RfidPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('rfid');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
