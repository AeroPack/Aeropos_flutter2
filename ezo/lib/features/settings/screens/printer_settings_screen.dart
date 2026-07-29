import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:smart_printer_flutter/smart_printer_flutter.dart';

import 'package:aeropos/core/layout/pos_design_system.dart';
import 'package:aeropos/core/preferences/printer_preferences.dart';
import 'package:aeropos/core/services/thermal_printer_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final _service = ThermalPrinterService.instance;
  final _prefs = PrinterPreferences();

  StreamSubscription<List<Peripheral>>? _peripheralsSub;
  StreamSubscription<bool>? _scanningSub;

  List<Peripheral> _peripherals = [];
  bool _isScanning = false;
  bool _isConnected = false;
  String? _connectedName;
  DateTime? _lastPrinted;

  PrinterEngine _engine = PrinterEngine.escPos;
  int _paperWidthMm = 58;
  TsplLabelSize _labelSize = TsplLabelSize.mm58Cont;

  @override
  void initState() {
    super.initState();
    _peripheralsSub = _service.peripheralsStream.listen((peripherals) {
      if (mounted) setState(() => _peripherals = peripherals);
    });
    _scanningSub = _service.isScanningStream.listen((scanning) {
      if (mounted) setState(() => _isScanning = scanning);
    });
    _loadState();
  }

  @override
  void dispose() {
    _peripheralsSub?.cancel();
    _scanningSub?.cancel();
    super.dispose();
  }

  Future<void> _loadState() async {
    final printer = await _prefs.getPrinter();
    final lastPrinted = await _prefs.getLastPrinted();
    final engine = await _prefs.getEngine();
    final paperWidthMm = await _prefs.getPaperWidthMm();
    final labelSize = await _prefs.getLabelSize();
    final connected = await _service.isConnected;
    if (!mounted) return;
    setState(() {
      _connectedName = connected ? printer.name : null;
      _isConnected = connected;
      _lastPrinted = lastPrinted;
      _engine = engine;
      _paperWidthMm = paperWidthMm;
      _labelSize = labelSize;
    });
  }

  Future<bool> _requestBluetoothPermissions() async {
    if (!Platform.isAndroid) return true;

    var sdkInt = 33;
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      sdkInt = androidInfo.version.sdkInt;
    } catch (_) {
      // Fall through with the modern-SDK assumption above.
    }

    final Map<Permission, PermissionStatus> statuses;
    if (sdkInt >= 31) {
      statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();
    } else {
      statuses = await [
        Permission.bluetooth,
        Permission.locationWhenInUse,
      ].request();
    }

    return statuses.values.every((s) => s.isGranted);
  }

  Future<void> _startScan() async {
    final granted = await _requestBluetoothPermissions();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bluetooth permission is required to scan for printers'),
        ),
      );
      return;
    }
    setState(() => _peripherals = []);
    await _service.startScan();
  }

  Future<void> _connect(Peripheral peripheral) async {
    final address = peripheral.uuid;
    if (address == null) return;
    await _service.stopScan();
    try {
      await _service.connect(address);
      await _prefs.savePrinter(
        name: peripheral.name ?? address,
        address: address,
      );
      if (!mounted) return;
      setState(() {
        _isConnected = true;
        _connectedName = peripheral.name ?? address;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect: $e')),
      );
    }
  }

  Future<void> _disconnect() async {
    await _service.disconnect();
    if (!mounted) return;
    setState(() {
      _isConnected = false;
      _connectedName = null;
    });
  }

  Future<void> _forgetPrinter() async {
    await _service.disconnect();
    await _prefs.clearPrinter();
    if (!mounted) return;
    setState(() {
      _isConnected = false;
      _connectedName = null;
      _lastPrinted = null;
    });
  }

  Future<void> _testPrint() async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(2 * PdfPageFormat.inch, 1 * PdfPageFormat.inch),
        build: (context) => pw.Center(
          child: pw.Text(
            'AeroPOS Test Print',
            style: const pw.TextStyle(fontSize: 12),
            textAlign: pw.TextAlign.center,
          ),
        ),
      ),
    );
    final bytes = await doc.save();

    try {
      await _service.printLabelPdf(
        bytes,
        engine: _engine,
        paperWidthMm: _paperWidthMm,
        labelSize: _labelSize,
      );
      await _prefs.updateLastPrinted();
      if (!mounted) return;
      setState(() => _lastPrinted = DateTime.now());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test print sent')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test print failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PosColors.background,
      appBar: AppBar(
        title: const Text('Thermal Printer Settings'),
        backgroundColor: Colors.white,
        foregroundColor: PosColors.textMain,
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(16),
        children: [
          _SectionCard(
            title: 'Connection',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.bluetooth,
                      color: _isConnected ? const Color(0xFF16A34A) : PosColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isConnected ? const Color(0xFF16A34A) : PosColors.border,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isConnected ? (_connectedName ?? 'Connected') : 'Not connected',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (_isConnected)
                      TextButton(onPressed: _disconnect, child: const Text('Disconnect')),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isScanning ? null : _startScan,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(_isScanning ? 'Scanning...' : 'Scan Devices'),
                  ),
                ),
                if (_peripherals.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ..._peripherals.map(
                    (p) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.print_outlined),
                      title: Text(p.name ?? 'Unknown device'),
                      subtitle: Text(p.uuid ?? ''),
                      trailing: FilledButton(
                        onPressed: () => _connect(p),
                        child: const Text('Connect'),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Printer Type',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<PrinterEngine>(
                  segments: const [
                    ButtonSegment(
                      value: PrinterEngine.escPos,
                      label: Text('ESC/POS'),
                    ),
                    ButtonSegment(
                      value: PrinterEngine.tspl,
                      label: Text('TSPL Label'),
                    ),
                  ],
                  selected: {_engine},
                  onSelectionChanged: (selection) async {
                    final engine = selection.first;
                    await _prefs.setEngine(engine);
                    if (!mounted) return;
                    setState(() => _engine = engine);
                  },
                ),
                const SizedBox(height: 12),
                if (_engine == PrinterEngine.escPos) ...[
                  const Text('Paper width', style: TextStyle(color: PosColors.textMuted)),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 58, label: Text('58mm')),
                      ButtonSegment(value: 80, label: Text('80mm')),
                    ],
                    selected: {_paperWidthMm},
                    onSelectionChanged: (selection) async {
                      final width = selection.first;
                      await _prefs.setPaperWidthMm(width);
                      if (!mounted) return;
                      setState(() => _paperWidthMm = width);
                    },
                  ),
                ] else ...[
                  const Text('Label size', style: TextStyle(color: PosColors.textMuted)),
                  const SizedBox(height: 4),
                  const Text(
                    'Must match your physical label roll, or the print will be mis-scaled.',
                    style: TextStyle(fontSize: 12, color: PosColors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<TsplLabelSize>(
                    initialValue: _labelSize,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: TsplLabelSize.values
                        .map((size) => DropdownMenuItem(
                              value: size,
                              child: Text(size.displayName),
                            ))
                        .toList(),
                    onChanged: (size) async {
                      if (size == null) return;
                      await _prefs.setLabelSize(size);
                      if (!mounted) return;
                      setState(() => _labelSize = size);
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Status',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _lastPrinted == null
                      ? 'Never printed'
                      : 'Last printed: ${_lastPrinted!.toLocal()}',
                  style: const TextStyle(color: PosColors.textMuted),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isConnected ? _testPrint : null,
                    icon: const Icon(Icons.print),
                    label: const Text('Test Print'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Reset',
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _forgetPrinter,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Forget Printer'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: PosColors.textMain),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
