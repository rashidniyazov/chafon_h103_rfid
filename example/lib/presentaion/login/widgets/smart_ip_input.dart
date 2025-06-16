import 'package:flutter/services.dart';

class SmartIpInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final raw = newValue.text
        .replaceAll(' ', '.')
        .replaceAll(RegExp(r'[^0-9.]'), '');
    final blocks = raw.split('.');

    List<String> limitedBlocks = [];
    for (var block in blocks) {
      if (limitedBlocks.length >= 4) break; // max 4 blok
      if (block.length > 3) {
        block = block.substring(0, 3); // hər blokda max 3 rəqəm
      }
      limitedBlocks.add(block);
    }

    final result = limitedBlocks.join('.');
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}