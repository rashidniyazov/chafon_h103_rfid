// import 'package:chafon_h103_rfid/chafon_h103_rfid.dart';
// import 'package:flutter/material.dart';
//
// class FunctionsScreen extends StatefulWidget {
//   const FunctionsScreen({super.key});
//
//   @override
//   State<FunctionsScreen> createState() => _FunctionsScreenState();
// }
//
// class _FunctionsScreenState extends State<FunctionsScreen> {
//   String log = '';
//   String lastTagInfo = 'Tag oxunmayıb';
//   List<Map<String, dynamic>> readTags = [];
//   String? battery;
//   List<String> tagList = [];
//   double outputPower = 20;
//
//   int selectedRegion = 1; // default: FCC
//   final regionOptions = {
//     0: "CHINA",
//     1: "FCC (USA)",
//     2: "ETSI (EU)",
//     3: "KOREA",
//   };
//
//   String selectedMemoryBank = 'EPC'; // default
//
//   final memoryBankOptions = ['EPC', 'TID'];
//
//   @override
//   void initState() {
//     super.initState();
//     ChafonH103RfidService.initCallbacks(
//       onBatteryLevel: (data) {
//         setState(() {
//           battery = '${data['level']}%';
//           log = 'Batareya: $battery';
//         });
//       },
//       onTagRead: (tag) {
//         print("📡 Inventory EPC: ${tag['epc']}");
//         if (!readTags.any((e) => e['epc'] == tag['epc'])) {
//           readTags.add(tag);
//           setState(() {});
//         }
//       },
//       onTagReadSingle: (tag) {
//         debugPrint("TAG CAVABI: $tag");
//         final epc = tag['epc']?.toString() ?? '<boş>';
//         final data = tag['data']?.toString() ?? '<boş>';
//         final status = tag['status']?.toString() ?? '-1';
//
//         setState(() {
//           lastTagInfo =
//               'Tək tag oxundu:\nEPC: $epc\nData: $data\nStatus: $status';
//         });
//       },
//       onReadError: (err) {
//         setState(() {
//           log = 'Xəta: ${err['error']}';
//         });
//       },
//       onDisconnected: () {
//         setState(() {
//           log = 'Bağlantı kəsildi';
//         });
//         Navigator.pop(context);
//       },
//     );
//   }
//
//   Widget _buildButton(String title, VoidCallback onPressed, {Color? color}) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6.0),
//       child: ElevatedButton(
//         style: ElevatedButton.styleFrom(
//           backgroundColor: color ?? Colors.blue,
//           minimumSize: const Size.fromHeight(50),
//         ),
//         onPressed: onPressed,
//         child: Text(title),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Funksiyalar')),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             _buildButton('Batareya səviyyəsini al', () async {
//               final result = await ChafonH103RfidService.getBatteryLevel();
//               setState(() {
//                 log = 'Əmr göndərildi: $result';
//               });
//             }),
//             _buildButton('Gücü Təyin Et ($outputPower dBm)', () async {
//               final result = await ChafonH103RfidService.setOutputPower(
//                   outputPower.toInt());
//               setState(() {
//                 log = 'Güc ayarlandı: $result';
//               });
//             }),
//             Slider(
//               value: outputPower,
//               min: 1,
//               max: 33,
//               divisions: 32,
//               label: '${outputPower.toInt()} dBm',
//               onChanged: (value) {
//                 setState(() {
//                   outputPower = value;
//                 });
//               },
//             ),
//             DropdownButton<int>(
//               value: selectedRegion,
//               items: regionOptions.entries
//                   .map((entry) => DropdownMenuItem(
//                         value: entry.key,
//                         child: Text(entry.value),
//                       ))
//                   .toList(),
//               onChanged: (value) {
//                 if (value != null) {
//                   setState(() {
//                     selectedRegion = value;
//                   });
//                 }
//               },
//             ),
//             _buildButton('Region Təyin Et (${regionOptions[selectedRegion]})',
//                 () async {
//               final result =
//                   await ChafonH103RfidService.setRegion(selectedRegion);
//               setState(() {
//                 log = 'Region ayarlandı: $result';
//               });
//             }),
//             _buildButton('Inventar oxumağa başla', () async {
//               setState(() {
//                 log = 'Konfiqurasiya olunur...';
//               });
//
//               //await ChafonH103RfidService.configureDeviceDefaults();
//
//               await Future.delayed(const Duration(milliseconds: 600)); // cihazın hazır olması üçün
//
//               final result = await ChafonH103RfidService.startInventory();
//
//               setState(() {
//                 log = 'Əmr göndərildi: $result';
//               });
//             }),
//             ElevatedButton(
//               onPressed: () async {
//                 // final result = await ChafonH103RfidService.configureDeviceDefaults();
//                 // debugPrint("⚙️ Parametrlər quruldu: $result");
//               },
//               child: const Text("Configure Defaults"),
//             ),
//             _buildButton('Inventar oxumağı dayandır', () async {
//               final result = await ChafonH103RfidService.stopInventory();
//               setState(() {
//                 log = 'Əmr göndərildi: $result';
//               });
//             }),
//             DropdownButton<String>(
//               value: selectedMemoryBank,
//               onChanged: (value) {
//                 if (value != null) {
//                   setState(() {
//                     selectedMemoryBank = value;
//                   });
//                 }
//               },
//               items: memoryBankOptions.map((bank) {
//                 return DropdownMenuItem<String>(
//                   value: bank,
//                   child: Text(bank),
//                 );
//               }).toList(),
//             ),
//             _buildButton('Tək Tag oxu', () async {
//               await ChafonH103RfidService.readSingleTag(bank: selectedMemoryBank);
//               setState(() {
//                 log = 'Oxuma əmri göndərildi ($selectedMemoryBank)';
//               });
//             }),
//             _buildButton('Bağlantını kəs', () async {
//               final result = await ChafonH103RfidService.disconnect();
//               setState(() {
//                 log = 'Bağlantı kəsildi: $result';
//               });
//             }, color: Colors.red),
//             const SizedBox(height: 20),
//             const Divider(),
//             Expanded(
//               child: SingleChildScrollView(
//                 child: Text(
//                   lastTagInfo,
//                   style: const TextStyle(fontSize: 16),
//                 ),
//               ),
//             ),
//             Expanded(
//               child: Column(
//                 children: [
//                   const Text("Oxunan Tag-lar",
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   const SizedBox(height: 8),
//                   Expanded(
//                     child: ListView.builder(
//                       itemCount: readTags.length,
//                       itemBuilder: (_, i) {
//                         final tag = readTags[i];
//                         return ListTile(
//                           title: Text("EPC: ${tag['epc']}"),
//                           subtitle: Text("RSSI: ${tag['rssi']} dBm"),
//                         );
//                       },
//                     ),
//                   )
//                 ],
//               ),
//             )
//           ],
//         ),
//       ),
//     );
//   }
// }
