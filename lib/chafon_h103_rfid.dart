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
          if (onTagRead != null) onTagRead(Map<String, dynamic>.from(call.arguments));
          break;
        case 'onTagReadSingle':
          if (onTagReadSingle != null) onTagReadSingle(Map<String, dynamic>.from(call.arguments));
          break;
        case 'onRadarSignal':
          if (onRadarResult != null) onRadarResult(Map<String, dynamic>.from(call.arguments));
          break;
        case 'onBatteryLevel':
          if (onBatteryLevel != null) onBatteryLevel(Map<String, dynamic>.from(call.arguments));
          break;
        case 'onBatteryTimeout':
          if (onBatteryTimeout != null) onBatteryTimeout();
          break;
        case 'onReadError':
          if (onReadError != null) onReadError(Map<String, dynamic>.from(call.arguments));
          break;
        case 'onDisconnected':
          if (onDisconnected != null) onDisconnected();
          break;
        case 'onDeviceFound':
          if (onDeviceFound != null) onDeviceFound(Map<String, dynamic>.from(call.arguments));
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

  /// Helper: gücü 5..33 aralığında saxla, 0 gələrsə 6 et
  static int _normalizePower(int power) {
    final p = (power == 0 ? 6 : power);
    return p.clamp(5, 33).toInt();
  }

  // ========== Metodlar ==========

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
    final result = await _channel.invokeMethod<Map>('getAllDeviceConfig');
    return result?.map((key, value) => MapEntry(key.toString(), value as int)) ?? {};
  }

  /// YENİ: Yalnız gücü yazan sadə API (native: setOnlyOutputPower)
  /// [saveToFlash]=true -> FLASH-a saxlayır, [resumeInventory]=true -> inventory işləyirdisə bərpa edir
  static Future<String?> setOnlyOutputPower({
    required int power,
    bool saveToFlash = true,
    bool resumeInventory = false,
    int? region,
  }) async {
    final int p = _normalizePower(power);
    try {
      final res = await _channel.invokeMethod<String>('setOnlyOutputPower', {
        'power': p,
        'saveToFlash': saveToFlash,
        'resumeInventory': resumeInventory,
        if (region != null) 'region': region, // <-- YENİ
      });
      debugPrint('setOnlyOutputPower: $res (p=$p save=$saveToFlash resume=$resumeInventory region=$region)');
      return res; // "ok" | "flash_saved"
    } catch (e) {
      debugPrint('setOnlyOutputPower error: $e');
      return null;
    }
  }


  /// Tam konfiqi yazan API. Artıq default olaraq YALNIZ power göndəririk.
  /// (Native tərəf region/q/session üçün defaultları özü qurur.)
  static Future<String?> sendAndSaveAllParams({
    required int power,
    int region = 2,
    int qValue = 4,
    int session = 0,
  }) async {
    final int p = _normalizePower(power);
    try {
      final result = await _channel.invokeMethod<String>(
        'sendAndSaveAllParams',
        {
          'power': p,
          'region': region,   // <-- YENİ
          'qValue': qValue,
          'session': session,
        },
      );
      debugPrint('sendAndSaveAllParams: $result (p=$p region=$region q=$qValue s=$session)');
      return result; // "flash_saved" və s.
    } catch (e) {
      debugPrint('sendAndSaveAllParams error: $e');
      return null;
    }
  }


  static Future<String?> startInventory() async {
    return await _channel.invokeMethod<String>('startInventory');
  }

  /// QEYD: Native tərəfdə 'startInventoryWithBank' yoxdursa, bunu istifadə etmə.
  /// Əvəzinə readSingleTagFromBank(...) yaz.
  @Deprecated('Native metodu yoxdursa istifadə etmə; readSingleTagFromBank istifadə et')
  static Future<String?> startInventoryWithBank(String memoryBank) async {
    return await _channel.invokeMethod<String>('startInventoryWithBank', {
      'memoryBank': memoryBank,
    });
  }

  static Future<String?> stopInventory() async {
    return await _channel.invokeMethod<String>('stopInventory');
  }

  /// EPC oxumaq (default EPC bank: 0x01). Lazım olsa parametrli variantdan istifadə et.
  static Future<String?> readSingleTag() async {
    return await _channel.invokeMethod<String>('readSingleTag', {
      'memoryBank': 0x01,
    });
  }

  /// Parametrli tək oxu (EPC=0x01, TID=0x02, USER=0x03 ...)
  static Future<String?> readSingleTagFromBank(int memBank) async {
    return await _channel.invokeMethod<String>('readSingleTag', {
      'memoryBank': memBank,
    });
  }

  static Future<void> startRadar(String epc) async {
    await _channel.invokeMethod('startRadarTracking', {'epc': epc});
  }

  static Future<void> stopRadar() async {
    await _channel.invokeMethod('stopRadarTracking');
  }
}
