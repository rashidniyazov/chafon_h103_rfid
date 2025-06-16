import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chafon_h103_rfid/chafon_h103_rfid_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelChafonH103Rfid platform = MethodChannelChafonH103Rfid();
  const MethodChannel channel = MethodChannel('chafon_h103_rfid');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
