import 'package:flutter_test/flutter_test.dart';
import 'package:chafon_h103_rfid/chafon_h103_rfid.dart';
import 'package:chafon_h103_rfid/chafon_h103_rfid_platform_interface.dart';
import 'package:chafon_h103_rfid/chafon_h103_rfid_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockChafonH103RfidPlatform
    with MockPlatformInterfaceMixin
    implements ChafonH103RfidPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final ChafonH103RfidPlatform initialPlatform = ChafonH103RfidPlatform.instance;

  test('$MethodChannelChafonH103Rfid is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelChafonH103Rfid>());
  });

  test('getPlatformVersion', () async {
    MockChafonH103RfidPlatform fakePlatform = MockChafonH103RfidPlatform();
    ChafonH103RfidPlatform.instance = fakePlatform;

    expect(await ChafonH103RfidService.getPlatformVersion(), '42');
  });
}
