import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

Widget buildQrScanner({required void Function(String) onDetect}) {
  return MobileScanner(
    onDetect: (capture) {
      if (capture.barcodes.isNotEmpty) {
        final code = capture.barcodes.first.rawValue;
        if (code != null) {
          onDetect(code);
        }
      }
    },
  );
}
