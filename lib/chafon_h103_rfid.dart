import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class ChafonH103RfidService {
  static const MethodChannel _channel = MethodChannel('chafon_h103_rfid');

  /// Cihazdan gələn məlumatlar üçün stream event-lər:
  static void initCallbacks({
    Function(Map<String, dynamic>)? onTagRead,
    Function(Map<String, dynamic>)? onTagReadSingle,
    Function(Map<String, dynamic>)? onRadarResult,
    Function(Map<String, dynamic>)? onBatteryLevel,
    Function()? onBatteryTimeout,
    Function(Map<String, dynamic>)? onReadError,
    Function()? onDisconnected,
    Function(Map<String, dynamic>)? onDeviceFound,
    Function()? onFlashSaved,
    Function(String)? onScanError,
  }) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onTagRead':
          if (onTagRead != null)
            onTagRead(Map<String, dynamic>.from(call.arguments));
          break;
        case 'onTagReadSingle':
          if (onTagReadSingle != null)
            onTagReadSingle(Map<String, dynamic>.from(call.arguments));
          break;
        case 'onRadarSignal':
          if (onRadarResult != null)
            onRadarResult(Map<String, dynamic>.from(call.arguments));
          break;
        case 'onBatteryLevel':
          if (onBatteryLevel != null)
            onBatteryLevel(Map<String, dynamic>.from(call.arguments));
          break;
        case 'onBatteryTimeout':
          if (onBatteryTimeout != null) onBatteryTimeout();
          break;
        case 'onReadError':
          if (onReadError != null)
            onReadError(Map<String, dynamic>.from(call.arguments));
          break;
        case 'onDisconnected':
          if (onDisconnected != null) onDisconnected();
          break;
        case 'onDeviceFound':
          if (onDeviceFound != null)
            onDeviceFound(Map<String, dynamic>.from(call.arguments));
          break;
        case 'onFlashSaved':
          if (onFlashSaved != null) onFlashSaved();
          break;

        case 'onScanError':
          if (onScanError != null) onScanError(call.arguments as String);
          break;
      }
    });
  }

  // Metodlar
  static Future<String?> getPlatformVersion() async {
    return await _channel.invokeMethod<String>('getPlatformVersion');
  }

  static Future<String?> getBatteryLevel() async {
    return await _channel.invokeMethod<String>('getBatteryLevel');
  }

  static Future<String?> startScan() async {
    return await _channel.invokeMethod<String>('startScan');
  }

  static Future<String?> stopScan() async {
    return await _channel.invokeMethod<String>('stopScan');
  }

  static Future<bool?> connect(String address) async {
    return await _channel.invokeMethod<bool>('connect', {'address': address});
  }

  static Future<bool?> isConnected() async {
    return await _channel.invokeMethod<bool>('isConnected');
  }

  static Future<bool?> disconnect() async {
    return await _channel.invokeMethod<bool>('disconnect');
  }

  static Future<Map<String, int>> getAllDeviceConfig() async {
    final result = await _channel.invokeMethod<Map>("getAllDeviceConfig");
    return result?.map(
          (key, value) => MapEntry(key.toString(), value as int),
        ) ??
        {};
  }


  static Future<String?> sendAndSaveAllParams({required int power}) async {
    try {
      final result = await _channel.invokeMethod<String>('sendAndSaveAllParams', {
        'power': power,
        'region': 1,
        'qValue': 4,
        'session': 1,
      });
      debugPrint("sendAndSaveAllParams: $result");
      debugPrint("sendAndSaveAllParams: $power");
      return result;
    } catch (e) {
      debugPrint("sendAndSaveAllParams error: $e");
      return null;
}
  }


  static Future<String?> startInventory() async {
    return await _channel.invokeMethod<String>('startInventory');
  }

  static Future<String?> startInventoryWithBank(String memoryBank) async {
    return await _channel.invokeMethod<String>('startInventoryWithBank', {
      'memoryBank': memoryBank,
    });
  }

  static Future<String?> stopInventory() async {
    return await _channel.invokeMethod<String>('stopInventory');
  }

  static Future<String?> readSingleTag({required String bank}) async {
    int memoryBank = (bank == 'TID') ? 0x02 : 0x01;
    return await _channel.invokeMethod('readSingleTag', {
      'memoryBank': memoryBank,
    });
  }

  static Future<void> startRadar(String epc) async {
    await _channel.invokeMethod('startRadarTracking', {'epc': epc});
  }

  static Future<void> stopRadar() async {
    await _channel.invokeMethod('stopRadarTracking');
  }
}
