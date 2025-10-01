package com.example.chafon_h103_rfid;

import android.bluetooth.BluetoothDevice;
import android.bluetooth.le.ScanResult;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.cf.beans.AllParamBean;
import com.cf.beans.BatteryCapacityBean;
import com.cf.beans.CmdData;
import com.cf.beans.TagInfoBean;
import com.cf.beans.TagOperationBean;
import com.cf.ble.interfaces.IBtScanCallback;
import com.cf.ble.interfaces.IConnectDoneCallback;
import com.cf.ble.interfaces.IOnNotifyCallback;
import com.cf.zsdk.BleCore;
import com.cf.zsdk.CfSdk;
import com.cf.zsdk.SdkC;
import com.cf.zsdk.cmd.CmdBuilder;
import com.cf.zsdk.cmd.CmdType;

import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicBoolean;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class ChafonH103RfidPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
    private MethodChannel channel;
    private Context context;
    private BleCore bleCore;
    private final Map<String, BluetoothDevice> discoveredDevices = new HashMap<>();
    private IBtScanCallback scanCallback;
    private boolean isScanning = false;

    private MethodChannel.Result pendingGetConfigResult;
    private MethodChannel.Result pendingSaveFlashResult;
    // Qeyd: TYPE_SET_ALL_PARAM üçün istifadə olunmur, saveParamsToFlash birbaşa çağırılır
    private MethodChannel.Result pendingSendAndSaveResult;

    private String radarEpc = null;
    private boolean radarActive = false;

    private Handler batteryTimeoutHandler = new Handler(Looper.getMainLooper());
    private Runnable batteryTimeoutRunnable;

    private Handler flashTimeoutHandler = new Handler(Looper.getMainLooper());
    private Runnable flashTimeoutRunnable;

    private AllParamBean latestAllParam = null;

    // ---- NEW: BLE hazirlik və əməliyyat mutex-i ----
    private volatile boolean bleReady = false;                  // notify/CCCD aktiv olanda true
    private final AtomicBoolean opInProgress = new AtomicBoolean(false);

    private static final int POWER_MIN = 5;
    private static final int POWER_MAX = 30;

    private static final UUID SERVICE_UUID = UUID.fromString("0000ffe0-0000-1000-8000-00805f9b34fb");
    private static final UUID WRITE_UUID   = UUID.fromString("0000ffe3-0000-1000-8000-00805f9b34fb");
    private static final UUID NOTIFY_UUID  = UUID.fromString("0000ffe4-0000-1000-8000-00805f9b34fb");

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        context = flutterPluginBinding.getApplicationContext();
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "chafon_h103_rfid");
        channel.setMethodCallHandler(this);

        CfSdk.load();
        bleCore = (BleCore) CfSdk.get(SdkC.BLE);
        bleCore.init(context);
        bleCore.setOnNotifyCallback(universalNotifyCallback);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        try {
            Log.d("CHAFON_PLUGIN", "📞 Method çağırıldı: " + call.method);
            switch (call.method) {
                case "getPlatformVersion":
                    result.success("Android " + android.os.Build.VERSION.RELEASE);
                    break;

                case "getBatteryLevel":
                    getBatteryLevel(result);
                    break;

                case "startScan":
                    startScan(result);
                    break;

                case "stopScan":
                    stopScan(result);
                    break;

                case "connect": {
                    String address = call.argument("address");
                    if (address != null && !address.isEmpty()) {
                        connect(address, result);
                    } else {
                        result.error("INVALID_ARGUMENT", "Address is null or empty", null);
                    }
                    break;
                }

                case "isConnected":
                    result.success(bleCore != null && bleCore.isConnect());
                    break;

                case "disconnect":
                    disconnect(result);
                    break;

                case "getAllDeviceConfig":
                    getAllDeviceConfig(result);
                    break;

                case "sendAndSaveAllParams": {
                    Integer power  = call.argument("power");
                    Integer region = call.argument("region");
                    Integer qValue = call.argument("qValue");
                    Integer session= call.argument("session");

                    // Dart tərəfi yalnız power göndərsə belə, defaultlarla işləyəcəyik
                    int pwr = power != null ? power : 17;
                    int reg = region != null ? region : 2;  // 1=FCC, digəri=ETSI
                    int q   = qValue != null ? qValue : 4;
                    int ses = session != null ? session : 0;

                    sendAndSaveAllParams(pwr, reg, q, ses, result);
                    break;
                }

                case "startInventory":
                    startInventory(result);
                    break;

                case "stopInventory":
                    stopInventory(result);
                    break;

                case "readSingleTag": {
                    Integer memoryBank = call.argument("memoryBank");
                    if (memoryBank == null) {
                        result.error("INVALID_ARGUMENT", "Missing 'memoryBank'", null);
                        return;
                    }
                    readTagByMemoryBank(memoryBank.byteValue(), result);
                    break;
                }

                case "startRadarTracking": {
                    String radarEpcValue = call.argument("epc");
                    if (radarEpcValue == null || radarEpcValue.isEmpty()) {
                        result.error("INVALID_ARGUMENT", "EPC boş ola bilməz", null);
                    } else {
                        startRadarTracking(radarEpcValue, result);
                    }
                    break;
                }

                case "stopRadarTracking":
                    stopRadarTracking(result);
                    break;

                default:
                    result.error("UNSUPPORTED_METHOD",
                            "Method " + call.method + " not supported",
                            Arrays.asList("startScan", "stopScan"));
            }
        } catch (Exception e) {
            result.error("UNEXPECTED_ERROR", e.getMessage(), null);
        }
    }

    // ==== NOTIFY CALLBACK ====
    private final IOnNotifyCallback universalNotifyCallback = new IOnNotifyCallback() {
        @Override
        public void onNotify(int cmdType, CmdData cmdData) {
            try {
                Object obj = cmdData.getData();

                switch (cmdType) {
                    case CmdType.TYPE_GET_BATTERY_CAPACITY:
                        Log.d("CHAFON_PLUGIN", "📩 TYPE_BATTERY cavabı gəldi");
                        if (obj instanceof BatteryCapacityBean) {
                            int battery = ((BatteryCapacityBean) obj).mBatteryCapacity;

                            if (batteryTimeoutRunnable != null) {
                                batteryTimeoutHandler.removeCallbacks(batteryTimeoutRunnable);
                                batteryTimeoutRunnable = null;
                            }

                            Map<String, Object> batteryMap = new HashMap<>();
                            batteryMap.put("level", battery);

                            new Handler(Looper.getMainLooper()).post(() -> {
                                channel.invokeMethod("onBatteryLevel", batteryMap);
                            });
                        }
                        break;

                    case CmdType.TYPE_OUT_MODE:
                        Log.d("CHAFON_PLUGIN", "📤 Output mode dəyişdi");
                        break;

                    case CmdType.TYPE_KEY_STATE:
                        Log.d("CHAFON_PLUGIN", "🔘 Düymə statusu gəldi");
                        break;

                    case CmdType.TYPE_GET_DEVICE_INFO:
                        Log.d("CHAFON_PLUGIN", "📡 Cihaz məlumatı gəldi");
                        break;

                    case CmdType.TYPE_GET_ALL_PARAM:
                        if (obj instanceof AllParamBean && pendingGetConfigResult != null) {
                            AllParamBean param = (AllParamBean) obj;
                            latestAllParam = param;

                            Map<String, Object> config = new HashMap<>();
                            config.put("power",   (int) param.mRfidPower);
                            config.put("region",  (int) param.mRfidFreq.mREGION);
                            config.put("qValue",  (int) param.mQValue);
                            config.put("session", (int) param.mSession);

                            MethodChannel.Result callback = pendingGetConfigResult;
                            pendingGetConfigResult = null;
                            callback.success(config);
                        }
                        break;

                    case CmdType.TYPE_SET_ALL_PARAM:
                        Log.d("CHAFON_PLUGIN", "✅ Parametrlər uğurla RAM-a yazıldı");
                        // Bu branch-dan istifadə etmirik; RAM yazıldıqdan dərhal sonra sendAndSaveAllParams içində FLASH yazırıq.
                        if (pendingSendAndSaveResult != null) {
                            new Handler(Looper.getMainLooper()).postDelayed(() -> {
                                saveParamsToFlash(pendingSendAndSaveResult);
                            }, 1000);
                        }
                        break;

                    case CmdType.TYPE_INVENTORY:
                        if (obj instanceof TagInfoBean) {
                            TagInfoBean tag = (TagInfoBean) obj;
                            if (tag.mEPCNum == null || tag.mEPCNum.length == 0) return;

                            String epc = bytesToHexString(tag.mEPCNum);
                            int rssi = tag.mRSSI;

                            if (radarActive && radarEpc != null && epc.equalsIgnoreCase(radarEpc)) {
                                Log.d("CHAFON_PLUGIN", "🎯 RADAR TAPDI: EPC=" + epc + ", RSSI=" + rssi);

                                Map<String, Object> radarMap = new HashMap<>();
                                radarMap.put("epc", epc);
                                radarMap.put("rssi", rssi);

                                new Handler(Looper.getMainLooper()).post(() -> {
                                    channel.invokeMethod("onRadarSignal", radarMap);
                                });
                            } else {
                                Log.d("CHAFON_PLUGIN", "📡 Tag: EPC=" + epc);
                                Map<String, Object> tagMap = new HashMap<>();
                                tagMap.put("epc", epc);
                                tagMap.put("rssi", rssi);
                                tagMap.put("antenna", tag.mAntenna);
                                tagMap.put("timestamp", System.currentTimeMillis());

                                new Handler(Looper.getMainLooper()).post(() -> {
                                    channel.invokeMethod("onTagRead", tagMap);
                                });
                            }
                        }
                        break;

                    case CmdType.TYPE_READ_TAG:
                        if (obj instanceof TagOperationBean) {
                            TagOperationBean tagOp = (TagOperationBean) obj;

                            int status = tagOp.mTagStatus;
                            Log.d("CHAFON_PLUGIN", "📛 TagOperationBean status: " + status);

                            String epc = bytesToHexString(tagOp.mEPCNum);
                            String data = bytesToHexString(tagOp.mData);

                            Log.i("CHAFON_PLUGIN", "✅ EPC: " + epc + " | DATA: " + data);

                            if ((epc != null && !epc.trim().isEmpty()) || (data != null && !data.trim().isEmpty())) {
                                if (epc == null || epc.trim().isEmpty()) epc = "<boş>";
                                if (data == null) data = "";

                                Map<String, Object> tagMap = new HashMap<>();
                                tagMap.put("epc", epc);
                                tagMap.put("data", data);
                                tagMap.put("status", status);
                                tagMap.put("timestamp", System.currentTimeMillis());

                                new Handler(Looper.getMainLooper()).post(() -> {
                                    channel.invokeMethod("onTagReadSingle", tagMap);
                                });
                            } else {
                                Log.w("CHAFON_PLUGIN", "❌ READ_TAG cavabı keçərsizdir – nə EPC, nə də DATA var");
                            }
                        }
                        break;
                }
            } catch (Exception e) {
                Log.e("NOTIFY_ERROR", "Callback processing error", e);
                Map<String, Object> errorMap = new HashMap<>();
                errorMap.put("error", e.getMessage());
                channel.invokeMethod("onReadError", errorMap);
            }
        }

        @Override
        public void onNotify(byte[] bytes) {
            if (bytes == null || bytes.length == 0) return;

            int cmd = (bytes.length >= 4) ? (bytes[3] & 0xFF) : -1;
            Log.d("CHAFON_PLUGIN", "🔍 CMD Header: " + cmd);

            if (cmd == 0x79) {
                Log.d("CHAFON_PLUGIN", "💾 FLASH əmri uğurla təsdiqləndi");

                if (flashTimeoutRunnable != null) {
                    flashTimeoutHandler.removeCallbacks(flashTimeoutRunnable);
                    flashTimeoutRunnable = null;
                }

                if (pendingSaveFlashResult != null) {
                    pendingSaveFlashResult.success("flash_saved");
                    pendingSaveFlashResult = null;
                } else {
                    Log.w("CHAFON_PLUGIN", "⚠️ FLASH cavabı gəldi, amma pendingSaveFlashResult null idi");
                }
            }
        }
    };

    // ==== BLE əmrləri ====

    private void getBatteryLevel(MethodChannel.Result result) {
        if (bleCore == null || !bleCore.isConnect()) {
            result.error("DISCONNECTED", "Device not connected", null);
            return;
        }

        byte[] cmd = CmdBuilder.buildGetBatteryCapacityCmd();
        boolean sent = writeWithRetry(SERVICE_UUID, WRITE_UUID, cmd);

        if (sent) {
            Log.d("CHAFON_PLUGIN", "🔋 Battery səviyyə əmri göndərildi.");
            result.success("battery_request_sent");

            batteryTimeoutRunnable = () -> {
                Log.w("CHAFON_PLUGIN", "⏰ Battery cavabı gəlmədi (timeout)");
                channel.invokeMethod("onBatteryTimeout", null);
            };
            batteryTimeoutHandler.postDelayed(batteryTimeoutRunnable, 5000);

        } else {
            result.error("BATTERY_FAILED", "Unable to send battery command", null);
        }
    }

    private void startScan(MethodChannel.Result result) {
        Log.d("CHAFON_PLUGIN", "▶️ startScan metodu çağırıldı");

        if (isScanning) {
            Log.d("CHAFON_PLUGIN", "⚠️ Skan onsuz da davam edir");
            result.success("skan_onsuzda_davam_edir");
            return;
        }

        try {
            scanCallback = new IBtScanCallback() {
                @Override
                public void onBtScanResult(ScanResult pResult) {
                    Log.d("CHAFON_PLUGIN", "✅ Cihaz tapıldı: " + pResult.getDevice().getAddress());

                    BluetoothDevice device = pResult.getDevice();
                    if (device != null && device.getAddress() != null) {
                        if (!discoveredDevices.containsKey(device.getAddress())) {
                            discoveredDevices.put(device.getAddress(), device);
                            Map<String, Object> deviceInfo = new HashMap<>();
                            deviceInfo.put("name", device.getName() != null ? device.getName() : "Naməlum");
                            deviceInfo.put("address", device.getAddress());
                            deviceInfo.put("rssi", pResult.getRssi());

                            new Handler(Looper.getMainLooper()).post(() -> {
                                channel.invokeMethod("onDeviceFound", deviceInfo);
                            });
                        }
                    }
                }

                @Override
                public void onBtScanFail(int pErrorCode) {
                    Log.e("CHAFON_PLUGIN", "❌ Skan uğursuz oldu. Kod: " + pErrorCode);
                    new Handler(Looper.getMainLooper()).post(() -> {
                        channel.invokeMethod("onScanError", "Skan xətası: " + pErrorCode);
                    });
                }
            };

            bleCore.startScan(scanCallback);
            isScanning = true;
            Log.d("CHAFON_PLUGIN", "🚀 Skan başlatıldı!");
            result.success("skan_basladildi");
        } catch (Exception e) {
            Log.e("CHAFON_PLUGIN", "🔥 startScan xətası: " + e.getMessage());
            result.error("SCAN_ERROR", "Skan başladılmadı: " + e.getMessage(), null);
        }
    }

    private void stopScan(@Nullable MethodChannel.Result result) {
        if (!isScanning) {
            if (result != null) result.success("skan_onsuzda_dayandirilib");
            return;
        }

        try {
            bleCore.stopScan();
            isScanning = false;
            if (result != null) result.success("skan_dayandirildi");
        } catch (Exception e) {
            if (result != null) {
                result.error("STOP_SCAN_ERROR", "Skan dayandırılmadı: " + e.getMessage(), null);
            }
        }
    }

    private void connect(String address, MethodChannel.Result result) {
        if (isScanning) {
            stopScan(null);
        }

        BluetoothDevice device = discoveredDevices.get(address);
        if (device == null) {
            result.error("DEVICE_NOT_FOUND", "Device not found: " + address, null);
            return;
        }

        bleCore.setIConnectDoneCallback(new IConnectDoneCallback() {
            @Override
            public void onConnectDone(boolean success) {
                if (success) {
                    bleReady = false;
                    boolean notifySet = bleCore.setNotifyState(SERVICE_UUID, NOTIFY_UUID, true);
                    if (notifySet) {
                        // CCCD yazısı tam otursun deyə kiçik gecikmə verib sonra konfiqurasiya et
                        new Handler(Looper.getMainLooper()).postDelayed(() -> {
                            bleReady = true; // notify aktiv qəbul edirik
                            configureAfterConnection(result);
                        }, 200);
                    } else {
                        result.error("NOTIFY_FAILED", "Failed to enable notifications", null);
                    }
                } else {
                    result.error("CONNECTION_FAILED", "Connection failed", null);
                }
            }
        });

        try {
            bleCore.connectDevice(device, context, true);
        } catch (Exception e) {
            result.error("CONNECTION_EXCEPTION", "Connection error: " + e.getMessage(), null);
        }
    }

    private void configureAfterConnection(MethodChannel.Result result) {
        try {
            // İlk konfiq yazılarını da retry ilə göndərək
            writeWithRetry(SERVICE_UUID, WRITE_UUID, CmdBuilder.buildSetOutputModeCmd((byte) 0x01));
            writeWithRetry(SERVICE_UUID, WRITE_UUID, CmdBuilder.buildSetReadModeCmd((byte) 0x00, new byte[7]));
            writeWithRetry(SERVICE_UUID, WRITE_UUID, CmdBuilder.buildGetAllParamCmd());

            result.success(true);
        } catch (Exception e) {
            result.error("CONFIGURATION_FAILED", "Config error: " + e.getMessage(), null);
        }
    }

    private void disconnect(MethodChannel.Result result) {
        try {
            bleCore.setIConnectDoneCallback(null);
            bleCore.setOnNotifyCallback(null);
            bleCore.disconnectedDevice();

            bleReady = false;
            latestAllParam = null;

            result.success(true);

            new Handler(Looper.getMainLooper()).post(() -> {
                channel.invokeMethod("onDisconnected", null);
            });
        } catch (Exception e) {
            result.error("DISCONNECT_FAILED", "Bağlantı kəsilmədi: " + e.getMessage(), null);
        }
    }

    private void getAllDeviceConfig(MethodChannel.Result result) {
        try {
            if (!waitBleReady(1000)) {
                result.error("BLE_NOT_READY", "Notify hazır deyil", null);
                return;
            }
            byte[] cmd = CmdBuilder.buildGetAllParamCmd();
            boolean sent = writeWithRetry(SERVICE_UUID, WRITE_UUID, cmd);

            if (sent) {
                pendingGetConfigResult = result; // cavab notify-dən gələcək
            } else {
                result.error("READ_CONFIG_FAILED", "BLE oxuma əmri göndərilmədi", null);
            }
        } catch (Exception e) {
            result.error("READ_CONFIG_EXCEPTION", "Xəta: " + e.getMessage(), null);
        }
    }

    private void saveParamsToFlash(MethodChannel.Result result) {
        try {
            Log.d("CHAFON_PLUGIN", "💾 FLASH yaddaşa yazma əmri göndərilir...");

            pendingSaveFlashResult = result;

            byte[] cmd = new byte[]{ (byte) 0xCF, (byte) 0xFF, 0x00, (byte) 0x79, 0x00, 0x00, 0x00 };
            int crc = calculateCRC16(cmd, 5);
            cmd[5] = (byte) ((crc >> 8) & 0xFF);
            cmd[6] = (byte) (crc & 0xFF);

            // RAM əmri göndərildikdən sonra kiçik gecikmə ilə FLASH yaz
            new Handler(Looper.getMainLooper()).postDelayed(() -> {
                boolean sent = writeWithRetry(SERVICE_UUID, WRITE_UUID, cmd);
                if (!sent) {
                    pendingSaveFlashResult = null;
                    result.error("FLASH_WRITE_FAILED", "FLASH əmrini göndərmək alınmadı", null);
                }
            }, 200);

        } catch (Exception e) {
            result.error("FLASH_EXCEPTION", "Xəta baş verdi: " + e.getMessage(), null);
        }
    }

    // ==== ƏSAS DƏYİŞİKLİK: getAllDeviceConfig-siz işləyən versiya ====
    private void sendAndSaveAllParams(int power, int region, int qValue, int session, MethodChannel.Result result) {
        Log.d("CHAFON_PLUGIN", "📞 Method çağırıldı: sendAndSaveAllParams (no-read mode)");

        if (!opInProgress.compareAndSet(false, true)) {
            result.error("BUSY", "Başqa parametrlər əməliyyatı gedir", null);
            return;
        }

        try {
            if (!waitBleReady(1000)) {
                opInProgress.set(false);
                result.error("BLE_NOT_READY", "Notify/CCCD hazır deyil", null);
                return;
            }

            // latestAllParam yoxdursa, tam obyekt qur (defaults)
            if (latestAllParam == null) {
                latestAllParam = makeAllParamsFromDefaults(power, region, qValue, session);
            } else {
                int p = Math.max(POWER_MIN, Math.min(POWER_MAX, power));
                latestAllParam.mRfidPower = (byte) p;
                latestAllParam.mQValue    = (byte) qValue;
                latestAllParam.mSession   = (byte) session;
                latestAllParam.mRfidFreq  = buildFreqByRegion(region);
            }

            byte[] cmd = CmdBuilder.buildSetAllParamCmd(latestAllParam);
            Log.d("CHAFON_PLUGIN", "🧪 CMD: " + bytesToHexString(cmd));

            boolean sent = writeWithRetry(SERVICE_UUID, WRITE_UUID, cmd);
            if (!sent) {
                opInProgress.set(false);
                result.error("WRITE_FAILED", "Parametrlər RAM-a yazıla bilmədi", null);
                return;
            }

            Log.d("CHAFON_PLUGIN", "✅ Parametrlər RAM-a yazıldı → FLASH-a saxlanılır...");
            saveParamsToFlash(new MethodChannel.Result() {
                @Override public void success(Object res) {
                    opInProgress.set(false);
                    result.success(res); // "flash_saved"
                }
                @Override public void error(String code, String msg, Object details) {
                    opInProgress.set(false);
                    result.error(code, msg, details);
                }
                @Override public void notImplemented() {
                    opInProgress.set(false);
                    result.notImplemented();
                }
            });

        } catch (Exception e) {
            opInProgress.set(false);
            result.error("WRITE_EXCEPTION", "Xəta baş verdi: " + e.getMessage(), null);
        }
    }

    // ==== Helper-lər ====

    /** BLE hazır olana qədər maksimum timeout ms gözlə */
    private boolean waitBleReady(long timeoutMs) {
        long end = System.currentTimeMillis() + timeoutMs;
        while (!bleReady && System.currentTimeMillis() < end) {
            try { Thread.sleep(50); } catch (InterruptedException ignored) {}
        }
        return bleReady;
    }

    /** Yazını 3 dəfə cəhd et (qısa gecikmə ilə) */
    private boolean writeWithRetry(UUID service, UUID write, byte[] data) {
        for (int i = 0; i < 3; i++) {
            boolean ok = bleCore.writeData(service, write, data);
            if (ok) return true;
            try { Thread.sleep(120L * (i + 1)); } catch (InterruptedException ignored) {}
        }
        return false;
    }

    /** Region üçün freq parametrlərini qur */
    private AllParamBean.RfidFreq buildFreqByRegion(int region) {
        AllParamBean.RfidFreq freq = new AllParamBean.RfidFreq();
        freq.mSTRATFREI = new byte[2];
        freq.mSTRATFRED = new byte[2];
        freq.mSTEPFRE   = new byte[2];

        if (region == 1) { // FCC
            freq.mREGION = 0x01;
            freq.mSTRATFREI[0] = 0x03; freq.mSTRATFREI[1] = (byte) 0x86;
            freq.mSTRATFRED[0] = 0x02; freq.mSTRATFRED[1] = (byte) 0xEE;
            freq.mSTEPFRE[0]   = 0x01; freq.mSTEPFRE[1]   = (byte) 0xF4;
            freq.mCN = 0x32;
        } else {           // ETSI (default)
            freq.mREGION = 0x03;
            freq.mSTRATFREI[0] = 0x03; freq.mSTRATFREI[1] = (byte) 0x61;
            freq.mSTRATFRED[0] = 0x00; freq.mSTRATFRED[1] = (byte) 0x64;
            freq.mSTEPFRE[0]   = 0x00; freq.mSTEPFRE[1]   = (byte) 0xC8;
            freq.mCN = 0x0F;
        }
        return freq;
    }

    /** AllParamBean-i oxumadan, təhlükəsiz defaultlarla qur */
    private AllParamBean makeAllParamsFromDefaults(int power, int region, int qValue, int session) {
        AllParamBean b = new AllParamBean();

        int p = Math.max(POWER_MIN, Math.min(POWER_MAX, power));
        b.mRfidPower = (byte) p;
        b.mQValue    = (byte) qValue;   // məsələn 4
        b.mSession   = (byte) session;  // məsələn 0 (S0)
        b.mRfidFreq  = buildFreqByRegion(region);

        // Digər sahələr üçün təhlükəsiz defaultlar (SDK-na görə uyğunlaşdır)
//        b.mAntenna            = 0x01; // Antenna 1 aktiv
//        b.mBeep               = 0x01; // Bip aktiv
//        b.mWorkMode           = 0x00; // Continuous
//        b.mWriteMode          = 0x00;
//        b.mActiveModeInterval = 0x14; // ~20ms

        return b;
    }

    private int calculateCRC16(byte[] data, int length) {
        int crc = 0xFFFF;
        for (int i = 0; i < length; i++) {
            crc ^= data[i] & 0xFF;
            for (int j = 0; j < 8; j++) {
                if ((crc & 0x0001) != 0) {
                    crc = (crc >> 1) ^ 0x8408;
                } else {
                    crc >>= 1;
                }
            }
        }
        return crc;
    }

    private void startInventory(MethodChannel.Result result) {
        try {
            Log.d("CHAFON_PLUGIN", "🚀 Continuous inventory başlatılır...");
            byte[] invCmd = CmdBuilder.buildInventoryISOContinueCmd((byte) 0x00, 0);
            boolean sent = writeWithRetry(SERVICE_UUID, WRITE_UUID, invCmd);

            if (sent) {
                Log.d("CHAFON_PLUGIN", "📡 Inventory əmri uğurla göndərildi.");
                result.success("inventory_davamli_basladi");
            } else {
                result.error("INVENTORY_FAILED", "Inventory əmrini göndərmək alınmadı", null);
            }
        } catch (Exception e) {
            result.error("INVENTORY_EXCEPTION", "Inventory başlatma xətası: " + e.getMessage(), null);
        }
    }

    private void stopInventory(MethodChannel.Result result) {
        try {
            byte[] stopCmd = CmdBuilder.buildStopInventoryCmd();
            boolean sent = writeWithRetry(SERVICE_UUID, WRITE_UUID, stopCmd);

            if (sent) {
                Log.d("CHAFON_PLUGIN", "🛑 Inventory uğurla dayandırıldı.");
                result.success("inventory_dayandirildi");
            } else {
                result.error("INVENTORY_STOP_FAILED", "Stop əmri göndərilmədi", null);
            }
        } catch (Exception e) {
            result.error("INVENTORY_STOP_EXCEPTION", "Inventory stop xətası: " + e.getMessage(), null);
        }
    }

    private void readTagByMemoryBank(byte memBank, MethodChannel.Result result) {
        byte[] accPwd = new byte[]{0x00, 0x00, 0x00, 0x00}; // Default password
        byte[] wordPtr;

        if (memBank == 0x01) { // EPC
            wordPtr = new byte[]{0x00, 0x02};
        } else {               // TID/USER
            wordPtr = new byte[]{0x00, 0x00};
        }
        byte wordCount = 6;

        byte[] cmd = CmdBuilder.buildReadISOTagCmd(accPwd, memBank, wordPtr, wordCount);
        boolean sent = writeWithRetry(SERVICE_UUID, WRITE_UUID, cmd);

        if (sent) {
            Log.d("CHAFON_PLUGIN", "✅ readSingleTag əmri göndərildi");
            result.success("read_tag_command_sent");
        } else {
            Log.e("CHAFON_PLUGIN", "❌ readSingleTag əmri göndərilmədi");
            result.error("SEND_FAIL", "Unable to send readTag command", null);
        }
    }

    private String bytesToHex(byte[] bytes) {
        if (bytes == null) return "";
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(String.format("%02X", b));
        }
        return sb.toString();
    }

    public String bytesToHexString(byte[] bytes) {
        if (bytes == null || bytes.length == 0) return "";
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(String.format("%02X", b));
        }
        return sb.toString();
    }

    private void startRadarTracking(String epc, MethodChannel.Result result) {
        radarEpc = epc;
        radarActive = true;

        byte[] cmd = CmdBuilder.buildInventoryISOContinueCmd((byte) 0x00, 0); // time-based
        boolean sent = writeWithRetry(SERVICE_UUID, WRITE_UUID, cmd);

        if (sent) {
            result.success("radar_started");
        } else {
            result.error("RADAR_START_FAIL", "Radar izləməsi başladılmadı", null);
        }
    }

    private void stopRadarTracking(MethodChannel.Result result) {
        radarEpc = null;
        radarActive = false;

        byte[] stopCmd = CmdBuilder.buildStopInventoryCmd();
        writeWithRetry(SERVICE_UUID, WRITE_UUID, stopCmd);

        result.success("radar_stopped");
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (bleCore != null) {
            bleCore.disconnectedDevice();
            bleCore.setOnNotifyCallback(null);
            bleCore.setIConnectDoneCallback(null);
            bleCore.setIBleDisConnectCallback(null);
        }
        discoveredDevices.clear();
        channel.setMethodCallHandler(null);

        bleReady = false;
        latestAllParam = null;
    }
}
