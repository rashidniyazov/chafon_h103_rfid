import 'package:chafon_h103_rfid/chafon_h103_rfid.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';

class Functions2Screen extends StatefulWidget {
  const Functions2Screen({super.key});

  @override
  State<Functions2Screen> createState() => _FunctionsScreenState();
}

class _FunctionsScreenState extends State<Functions2Screen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoading = false;
  Map<String, Map<String, dynamic>> tagMap = {};
  String lastTagInfo = 'Tag oxunmayıb';
  String log = '';
  String selectedMemoryBank = 'EPC';
  final memoryBankOptions = ['TID', 'EPC'];
  int? outputPower;
  int? batteryLevel;

  TextEditingController epcController = TextEditingController();
  double radarProgress = 0.0;
  Color radarColor = Colors.grey;
  String radarEpc = '';
  String lastRadarEpc = '';
  bool isRadarActive = false;

  Future<void> loadDeviceConfig() async {
    setState(() => isLoading = true);
    try {
      final config = await ChafonH103RfidService.getAllDeviceConfig();
      setState(() {
        outputPower = config['power'];
      });
    } catch (e) {
      debugPrint("\u{1F534} Konfiqurasiya oxunmadı: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Cihaz konfiqurasiyası oxunmadı: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> sendConfigToDevice() async {
    try {
      final result = await ChafonH103RfidService.sendAndSaveAllParams(
        power: outputPower!,
        region: 1,
        qValue: 4,
        session: 1,
      );

      if (result == "flash_saved" || result == "params_saved_to_flash") {
        debugPrint("✅ Parametrlər uğurla FLASH yaddaşa yazıldı");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Parametrlər yadda saxlanıldı (FLASH)"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        debugPrint("⚠️ Parametrlər yazıla bilmədi: $result");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("⚠️ Parametrlər yazılmadı: $result"),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("❌ Yazı zamanı xəta: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Xəta baş verdi: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  @override
  void initState() {
    super.initState();
    loadDeviceConfig();
    epcController = TextEditingController();
    _tabController = TabController(length: 4, vsync: this);

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
          lastTagInfo =
              'Tək tag oxundu: \nEPC: ${epc.isEmpty ? "<boş>" : epc}\nData: $data\nStatus: $status';
        });
      },
      onBatteryLevel: (map) {
        final level = map['level'];
        setState(() {
          batteryLevel = level;
        });
      },
      onBatteryTimeout: () {
        print("⚠️ Batareya cavabı gəlmədi (timeout)");
      },
      onFlashSaved: () {
        debugPrint("✅ FLASH yaddaşa yazıldı və cihaz yenidən başladı.");
      },
    );
  }

  @override
  void dispose() {
    epcController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Funksiyalar"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.wifi), text: "Axınlı Oxuma"),
            Tab(icon: Icon(Icons.radio_button_checked), text: "Tək Oxuma"),
            Tab(icon: Icon(Icons.radar), text: "Radar Axtarış"),
            Tab(icon: Icon(Icons.settings), text: "Parametrlər"),
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildContinuousInventoryTab(),
          _buildSingleReadTab(),
          _buildRadarTab(),
          _buildSettingsTab(),
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
                        Text("Oxunma sayı: ${data['count']}"),
                        Text("Son: ${data['lastSeen']}"),
                      ],
                    ),
                  ),
                );
              },
            )
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
                    log = '📡 Başladı: $result';
                  });
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.cleaning_services_rounded),
                label: const Text("Təmizlə"),
                onPressed: () => setState(() => tagMap.clear()),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.stop),
                label: const Text("Stop"),
                onPressed: () async {
                  final result = await ChafonH103RfidService.stopInventory();
                  setState(() {
                    log = '🛑 Dayandırıldı: $result';
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
            label: const Text("Tək Tag Oxu"),
            onPressed: () async {
              await ChafonH103RfidService.readSingleTag(
                bank: selectedMemoryBank,
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            "Oxunan nəticə:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
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
            items: memoryBankOptions.map((bank) {
              return DropdownMenuItem<String>(
                value: bank,
                child: Text("Yaddaş: $bank"),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  selectedMemoryBank = value;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRadarTab() {

    int normalizeRssi(int rssi, {int min = -90, int max = -40}) {
      if (rssi < min) return 0;
      if (rssi > max) return 100;
      return ((rssi - min) * 100 / (max - min)).toInt();
    }

    void handleRadar(String epc, int rssi) {
      final strength = normalizeRssi(rssi);
      print("📡 EPC=$epc | RADAR EPC=$radarEpc | Güc=$strength");

      // ✅ Yalnız seçilmiş radar EPC üçün səs ver
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
      } else {
        // ✅ Yoxla ki, progress və səs **yalnız düzgün EPC** üçün dəyişsin
        debugPrint("⚠️ Uyğunsuz EPC, səs və progress dəyişmir: $epc");
      }
    }


    Future<void> startRadar() async {
      final epc = epcController.text.trim();
      if (epc.isEmpty) return;

      await ChafonH103RfidService.startRadar(epc);
      setState(() {
        isRadarActive = true;
      });

      ChafonH103RfidService.initCallbacks(
        onTagRead: (_) {},
        onRadarResult: (tag) {
          final epc = tag['epc'] ?? '';
          final rssi = tag['rssi'] ?? -99;
          handleRadar(epc, rssi);
        },
      );
    }

    Future<void> stopRadar() async {
      await ChafonH103RfidService.stopRadar();
      setState(() {
        isRadarActive = false;
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
              labelText: "Axtarılacaq EPC",
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
          Text("Tapılan EPC: $lastRadarEpc"),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: isRadarActive ? null : startRadar,
                icon: const Icon(Icons.location_searching),
                label: const Text("Radar Başla"),
              ),
              ElevatedButton.icon(
                onPressed: isRadarActive ? stopRadar : null,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text("Dayandır"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "📶 Güc (Output Power)",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Slider(
            value: outputPower?.toDouble() ?? 20,
            min: 1,
            max: 33,
            divisions: 32,
            label: '${outputPower?.toInt() ?? 20} dBm',
            onChanged: (value) => setState(() => outputPower = value.toInt()),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text("Parametrləri Yaz"),
            onPressed: () async => await sendConfigToDevice(),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              await ChafonH103RfidService.getBatteryLevel();
            },
            child: const Text("🔋 Batareya yoxla"),
          ),
          Text(log),
        ],
      ),
    );
  }
}
