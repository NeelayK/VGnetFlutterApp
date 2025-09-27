import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/api.dart';
import '../theme.dart';

class QRScanScreen extends StatefulWidget {
  final VoidCallback onDone;
  final String scanMode; // "user" or "visitor"
  final String? visitorName;

  const QRScanScreen({
    super.key,
    required this.onDone,
    required this.scanMode,
    this.visitorName,
  });

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  bool scanned = false;
  final MobileScannerController _controller = MobileScannerController();
  Timer? _resetTimer;

  /// Mapping QR values → device endpoints
  final Map<String, String> doorMap = const {
    'Main Door': 'main_door',
    'Workshop Room': 'workshop_room',
    'Discussion Room': 'discussion_room',
  };

  /// Reset scan after a delay so user can rescan
  void _resetScan([int ms = 2000]) {
    _resetTimer?.cancel();
    _resetTimer = Timer(Duration(milliseconds: ms), () {
      if (mounted) setState(() => scanned = false);
    });
  }

  /// Called when QR is detected
  Future<void> _onDetect(BarcodeCapture capture) async {
    if (scanned) return; // Prevent duplicate scans

    final code = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (code == null || code.isEmpty) return;

    setState(() => scanned = true);

    final deviceKey = doorMap[code];
    if (deviceKey == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid QR: "$code" not recognized')),
      );
      _resetScan(2500);
      return;
    }

    try {
      if (widget.scanMode == 'user') {
        await sendCommand(device: deviceKey, action: 'open', context: context);
      } else {
        await sendCommand(
          device: deviceKey,
          action: 'open',
          visitorName: widget.visitorName?.trim(),
          context: context,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$code → Access Granted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send command: $e')),
      );
    }

    _resetScan(2000);
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: TextButton(
            style: TextButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.fill,
            ),
            onPressed: widget.onDone,
            child: const Text('← Back'),
          ),
        ),
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Column(
            children: [
              const Text(
                'Align the QR code inside the box',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.dark,),
              ),
              if (scanned)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: FilledButton(
                    onPressed: () => setState(() => scanned = false),
                    child: const Text('Scan Again'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Extension for safety
extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
