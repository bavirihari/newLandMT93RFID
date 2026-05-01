import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'rfid_method_channel.dart';

abstract class RfidPlatform extends PlatformInterface {
  /// Constructs a RfidPlatform.
  RfidPlatform() : super(token: _token);

  static final Object _token = Object();

  static RfidPlatform _instance = MethodChannelRfid();

  /// The default instance of [RfidPlatform] to use.
  ///
  /// Defaults to [MethodChannelRfid].
  static RfidPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [RfidPlatform] when
  /// they register themselves.
  static set instance(RfidPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
