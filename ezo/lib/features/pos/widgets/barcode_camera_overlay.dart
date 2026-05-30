import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeCameraOverlay extends StatefulWidget {
  final void Function(String)? onScanned;
  const BarcodeCameraOverlay({super.key, this.onScanned});

  @override
  State<BarcodeCameraOverlay> createState() => _BarcodeCameraOverlayState();
}

class _BarcodeCameraOverlayState extends State<BarcodeCameraOverlay> {
  final _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          final barcode = capture.barcodes.firstOrNull?.rawValue;
          if (barcode != null) {
            _controller.stop();
            Navigator.pop(context);
            widget.onScanned?.call(barcode);
          }
        },
      ),
    );
  }
}
