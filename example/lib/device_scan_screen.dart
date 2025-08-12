import 'package:chafon_h103_rfid/chafon_h103_rfid.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'BluetoothDeviceModel.dart';
import 'functions.dart';

class DeviceScanScreen extends StatefulWidget {
  const DeviceScanScreen({super.key});

  @override
  State<DeviceScanScreen> createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends State<DeviceScanScreen> {
  final List<BluetoothDeviceModel> devices = [];
  String? connectedAddress;
  bool isLoading = false;

  Future<void> checkPermissions() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.location.request();
  }

  @override
  void initState() {
    super.initState();
    checkPermissions();

    ChafonH103RfidService.isConnected().then((connected) {
      if (connected == true && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Functions()),
        );
      }
    });

    ChafonH103RfidService.initCallbacks(
      onDeviceFound: (device) {
        final newDevice = BluetoothDeviceModel(
          name: device['name'] ?? 'Unknown',
          address: device['address']!,
          rssi: device['rssi'] ?? 0,
        );


        if (!devices.any((d) => d.address == newDevice.address)) {
          setState(() {
            devices.add(newDevice);
          });
        }
      },
      onDisconnected: () {
        setState(() {
          connectedAddress = null;
        });
      },
    );

    _startScan();
  }

  Future<void> _startScan() async {
    await ChafonH103RfidService.startScan();
  }

  Future<void> _stopScan() async {
    await ChafonH103RfidService.stopScan();
  }

  Future<void> _connectToDevice(BluetoothDeviceModel device) async {
    setState(() => isLoading = true);
    await _stopScan();

    final success = await ChafonH103RfidService.connect(device.address);
    setState(() {
      isLoading = false;
      if (success == true) {
        connectedAddress = device.address;
      }
    });
  }

  @override
  void dispose() {
    ChafonH103RfidService.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bluetooth Device')),
      body: Column(
        children: [
          if (isLoading) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                final isConnected = device.address == connectedAddress;

                return ListTile(
                  title: Text(device.name),
                  subtitle: Text("RSSI: ${device.rssi}"),
                  trailing: isConnected
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : ElevatedButton(
                          onPressed: () => _connectToDevice(device),
                          child: const Text("Connect"),
                        ),
                );
              },
            ),
          ),
          if (connectedAddress != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context)=>Functions()));
                },
                icon: const Icon(Icons.play_circle),
                label: const Text("Functions"),
              ),
            ),
        ],
      ),
    );
  }
}
