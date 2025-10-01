import 'package:chafon_h103_rfid/chafon_h103_rfid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'device_scan_screen.dart';

class Functions extends StatefulWidget {
  const Functions({super.key});

  @override
  State<Functions> createState() => _FunctionsState();
}

class _FunctionsState extends State<Functions> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool isLoading = false;
  Map<String, Map<String, dynamic>> tagMap = {};
  String lastTagInfo = 'Tag not read';
  String log = '';
  String selectedMemoryBank = 'EPC';
  final memoryBankOptions = ['TID', 'EPC'];
  int? outputPower;
  int? batteryLevel;

  final TextEditingController epcController = TextEditingController();

  // Radar state
  double radarProgress = 0.0;
  Color radarColor = Colors.grey;
  String radarEpc = '';
  String lastRadarEpc = '';
  bool isRadarActive = false;

  int _normalizePower(int? p) {
    final v = (p == null || p == 0) ? 6 : p;
    return v.clamp(5, 33);
  }

  int _memBankCode(String bank) {
    switch (bank) {
      case 'TID':
        return 0x02;
      case 'EPC':
      default:
        return 0x01;
    }
  }

  int _normalizeRssi(int rssi, {int min = -90, int max = -40}) {
    if (rssi < min) return 0;
    if (rssi > max) return 100;
    return ((rssi - min) * 100 / (max - min)).toInt();
  }

  void _handleRadar(String epc, int rssi) {
    if (!isRadarActive || radarEpc.isEmpty) return;

    final strength = _normalizeRssi(rssi);
    if (epc.toLowerCase() == radarEpc.toLowerCase()) {
      SystemSound.play(SystemSoundType.click);

      Color color;
      if (strength > 70) {
        color = Colors.green;
      } else if (strength > 40) {
        color = Colors.yellow;
      } else {
        color = Colors.red;
      }

      setState(() {
        radarProgress = strength / 100;
        radarColor = color;
        lastRadarEpc = epc;
      });
    }
  }

  Future<void> loadDeviceConfig() async {
    setState(() => isLoading = true);
    try {
      final config = await ChafonH103RfidService.getAllDeviceConfig();
      setState(() {
        // plugin ETSI-də 5..33 dBm
        outputPower = (config['power'] ?? 20).clamp(5, 33);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to get device configuration: $e")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> sendConfigToDevice() async {
    final power = _normalizePower(outputPower);
    try {
      // Yalnız gücü yaz və FLASH-a saxla (inventory işləyirdisə özün bərpa etmirik – settings tabındayıq)
      final result = await ChafonH103RfidService.setOnlyOutputPower(
        power: power,
        saveToFlash: true,
        resumeInventory: false,
      );

      if (!mounted) return;
      if (result == "flash_saved" || result == "ok" || result == "params_saved_to_flash") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Parameters saved (FLASH)"), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Parameters not written: $result"), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    loadDeviceConfig();

    // İlk callback init – təkrar init etməyək
    ChafonH103RfidService.initCallbacks(
      onTagRead: (tag) {
        final epc = tag['epc'];
        final rssi = tag['rssi'];

        setState(() {
          if (tagMap.containsKey(epc)) {
            tagMap[epc]!['count'] += 1;
            tagMap[epc]!['rssi'] = rssi;
            tagMap[epc]!['lastSeen'] = DateTime.now();
          } else {
            tagMap[epc] = {
              'count': 1,
              'rssi': rssi,
              'lastSeen': DateTime.now(),
            };
          }
        });
      },
      onTagReadSingle: (tag) {
        final status = tag['status'] ?? -1;
        final epc = tag['epc']?.toString() ?? '';
        final data = tag['data']?.toString() ?? '';

        if (data.trim().isEmpty) return;

        setState(() {
          lastTagInfo = 'Single tag read:\nEPC: ${epc.isEmpty ? "<empty>" : epc}\nData: $data\nStatus: $status';
        });
      },
      onRadarResult: (tag) {
        final epc = tag['epc'] ?? '';
        final rssi = tag['rssi'] ?? -99;
        _handleRadar(epc, rssi);
      },
      onBatteryLevel: (map) {
        final level = map['level'];
        setState(() {
          batteryLevel = level;
        });
      },
      onBatteryTimeout: () {},
      onFlashSaved: () {},
    );

    // İstəyə görə açılışda batareya soruş
    ChafonH103RfidService.getBatteryLevel();
  }

  @override
  void dispose() {
    epcController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final powLabel = outputPower?.toString() ?? '...';
    return Scaffold(
      appBar: AppBar(
        title: const Text("Functions"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.wifi), text: "Continuous Read "),
            Tab(icon: Icon(Icons.radio_button_checked), text: "Single read"),
            Tab(icon: Icon(Icons.radar), text: "Radar Search"),
            Tab(icon: Icon(Icons.settings), text: "Settings"),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                batteryLevel != null ? "🔋 $batteryLevel%" : "🔋 ...",
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _buildContinuousInventoryTab(),
          _buildSingleReadTab(),
          _buildRadarTab(),
          _buildSettingsTab(powLabel),
        ],
      ),
    );
  }

  Widget _buildContinuousInventoryTab() {
    final tagEntries = tagMap.entries.toList();
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: tagEntries.length,
              itemBuilder: (_, index) {
                final epc = tagEntries[index].key;
                final data = tagEntries[index].value;

                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.nfc),
                    title: Text("EPC: $epc"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("RSSI: ${data['rssi']} dBm"),
                        Text("Read Count: ${data['count']}"),
                        Text("Last Seen: ${data['lastSeen']}"),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text("Start"),
                onPressed: () async {
                  final result = await ChafonH103RfidService.startInventory();
                  setState(() {
                    log = '📡 Started: $result';
                  });
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.cleaning_services_rounded),
                label: const Text("Clear"),
                onPressed: () => setState(() => tagMap.clear()),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.stop),
                label: const Text("Stop"),
                onPressed: () async {
                  final result = await ChafonH103RfidService.stopInventory();
                  setState(() {
                    log = '🛑 Stopped: $result';
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(log, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildSingleReadTab() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.radio_button_checked),
            label: const Text("Read Single Tag"),
            onPressed: () async {
              // Seçilən bankdan oxu
              final bank = _memBankCode(selectedMemoryBank);
              await ChafonH103RfidService.readSingleTagFromBank(bank);
            },
          ),
          const SizedBox(height: 20),
          const Text("Read Result:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(lastTagInfo, style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(height: 20),
          DropdownButton<String>(
            value: selectedMemoryBank,
            items: memoryBankOptions
                .map((bank) => DropdownMenuItem<String>(value: bank, child: Text("Memory Bank: $bank")))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => selectedMemoryBank = value);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRadarTab() {
    Future<void> startRadar() async {
      final epc = epcController.text.trim();
      if (epc.isEmpty) return;

      await ChafonH103RfidService.startRadar(epc);
      setState(() {
        isRadarActive = true;
        radarEpc = epc;
        radarProgress = 0;
        radarColor = Colors.grey;
        lastRadarEpc = '';
      });
      // DİQQƏT: Burada initCallbacks ÇAĞIRMIRIQ – artıq initState-də verilib.
    }

    Future<void> stopRadar() async {
      await ChafonH103RfidService.stopRadar();
      setState(() {
        isRadarActive = false;
        radarEpc = '';
        radarProgress = 0;
        radarColor = Colors.grey;
        lastRadarEpc = '';
      });
    }

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: epcController,
            decoration: const InputDecoration(
              labelText: "EPC to Search",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: radarProgress,
            minHeight: 20,
            color: radarColor,
            backgroundColor: Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text("Detected EPC: $lastRadarEpc"),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: isRadarActive ? null : startRadar,
                icon: const Icon(Icons.location_searching),
                label: const Text("Start Radar"),
              ),
              ElevatedButton.icon(
                onPressed: isRadarActive ? stopRadar : null,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text("Stop Radar"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab(String powLabel) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("📶 Output Power ($powLabel dBm)", style: const TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            value: (outputPower ?? 20).toDouble(),
            min: 5,
            max: 33,
            divisions: 28, // 5..33
            label: '${outputPower?.toInt() ?? 20} dBm',
            onChanged: (value) => setState(() => outputPower = value.toInt()),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text("Save Parameters"),
            onPressed: () async => await sendConfigToDevice(),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              await ChafonH103RfidService.getBatteryLevel();
            },
            child: const Text("🔋 Check Battery"),
          ),
          const SizedBox(height: 16),
          Text(log),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.link_off),
            label: const Text("Disconnect"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ChafonH103RfidService.disconnect();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const DeviceScanScreen()),
                      (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
