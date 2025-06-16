import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'chafon_h103_rfid_platform_interface.dart';

/// An implementation of [ChafonH103RfidPlatform] that uses method channels.
class MethodChannelChafonH103Rfid extends ChafonH103RfidPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('chafon_h103_rfid');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
