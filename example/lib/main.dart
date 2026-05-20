import 'package:flutter/material.dart';
import 'package:rfid/rfid.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NewLand RFID Demo',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const RfidScannerPage(),
    );
  }
}

class RfidScannerPage extends StatefulWidget {
  const RfidScannerPage({super.key});

  @override
  State<RfidScannerPage> createState() => _RfidScannerPageState();
}

class _RfidScannerPageState extends State<RfidScannerPage> {
  // Instance of our plugin
  final _rfidPlugin = Rfid();

  // State variables
  bool _isConnected = false;
  bool _isScanning = false;

  // Data storage: Map avoids duplicates, Key = EPC
  final Map<String, UHFTag> _scannedTags = {};
  StreamSubscription? _streamSubscription;

  // Configuration
  double _powerLevel = 30.0; // Default 30 dBm

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _rfidPlugin.stopScan();
    _rfidPlugin.disconnect();
    super.dispose();
  }

  // --- ACTIONS ---

  Future<void> _connect() async {
    try {
      final success = await _rfidPlugin.connect();
      setState(() {
        _isConnected = success;
      });
      _showSnackbar(success ? "Connected to UHF Module" : "Connection Failed");
    } catch (e) {
      _showSnackbar("Error connecting: $e");
    }
  }

  Future<void> _disconnect() async {
    try {
      await _stopScan(); // Always stop scanning before disconnecting
      final success = await _rfidPlugin.disconnect();
      setState(() {
        _isConnected = !success; // If success is true, isConnected becomes false
      });
      _showSnackbar("Disconnected");
    } catch (e) {
      _showSnackbar("Error disconnecting: $e");
    }
  }

  Future<void> _startScan() async {
    if (!_isConnected) {
      _showSnackbar("Please Connect First");
      return;
    }

    // Cancel any existing subscription before starting a new one
    await _streamSubscription?.cancel();
    _streamSubscription = null;

    // Clear list for new scan session
    setState(() {
      _scannedTags.clear();
      _isScanning = true;
    });

    try {
      // 1. Subscribe to stream (stream is cached internally, safe to call multiple times)
      _streamSubscription = _rfidPlugin.onTagsRead.listen(
        (List<UHFTag> incomingTags) {
          print('incomingTags: ${incomingTags.length} tags received');
          setState(() {
            for (var tag in incomingTags) {
              // Update or add tag to our map
              _scannedTags[tag.epc] = tag;
            }
          });
        },
        onError: (error) {
          print('Stream error: $error');
          _showSnackbar("Stream error: $error");
        },
      );

      // 2. Trigger hardware scan
      final success = await _rfidPlugin.startScan();
      if (!success) {
        setState(() => _isScanning = false);
        _showSnackbar("Failed to start scan command");
      }
    } catch (e) {
      setState(() => _isScanning = false);
      _showSnackbar("Error starting scan: $e");
    }
  }

  Future<void> _stopScan() async {
    try {
      await _rfidPlugin.stopScan();
      await _streamSubscription?.cancel();
      setState(() {
        _isScanning = false;
      });
    } catch (e) {
      _showSnackbar("Error stopping scan: $e");
    }
  }

  Future<void> _setPower(double value) async {
    if (!_isConnected) return;

    try {
      // SDK expects 3000 for 30dBm
      int powerInt = (value * 100).toInt();
      await _rfidPlugin.setPower(powerInt, powerInt);
      setState(() {
        _powerLevel = value;
      });
      _showSnackbar("Power set to $powerInt ($value dBm)");
    } catch (e) {
      _showSnackbar("Failed to set power: $e");
    }
  }

  void _clearData() {
    setState(() {
      _scannedTags.clear();
    });
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(milliseconds: 800)));
  }

  // --- UI BUILDER ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MT93-U RFID Scanner'),
        actions: [IconButton(icon: const Icon(Icons.delete_sweep), onPressed: _clearData, tooltip: "Clear Data")],
      ),
      body: Column(
        children: [
          // 1. Control Panel
          _buildControlPanel(),

          const Divider(height: 1),

          // 2. Stats
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Total Tags: ${_scannedTags.length}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (_isScanning)
                  const Row(
                    children: [
                      SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text("Scanning...", style: TextStyle(color: Colors.green)),
                    ],
                  )
                else
                  const Text("Idle", style: TextStyle(color: Colors.red)),
              ],
            ),
          ),

          // 3. List of Tags
          Expanded(
            child: _scannedTags.isEmpty
                ? const Center(child: Text("No tags scanned"))
                : ListView.builder(
                    itemCount: _scannedTags.length,
                    itemBuilder: (context, index) {
                      String key = _scannedTags.keys.elementAt(index);
                      UHFTag tag = _scannedTags[key]!;
                      return _buildTagTile(tag);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Row 1: Connection
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isConnected ? null : _connect,
                    icon: const Icon(Icons.bluetooth_connected),
                    label: const Text("Connect"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isConnected ? _disconnect : null,
                    icon: const Icon(Icons.bluetooth_disabled),
                    label: const Text("Disconnect"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Row 2: Scanning
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isConnected && !_isScanning) ? _startScan : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text("Start Scan"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isConnected && _isScanning) ? _stopScan : null,
                    icon: const Icon(Icons.stop),
                    label: const Text("Stop Scan"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Row 3: Power Slider
            Row(
              children: [
                const Text("Power: ", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("${_powerLevel.toInt()} dBm"),
                Expanded(
                  child: Slider(
                    value: _powerLevel,
                    min: 5,
                    max: 33,
                    divisions: 28,
                    label: "${_powerLevel.toInt()}",
                    onChanged: _isConnected ? (val) => setState(() => _powerLevel = val) : null,
                    onChangeEnd: (val) => _setPower(val),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagTile(UHFTag tag) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRssiColor(tag.rssi),
          child: Text("${tag.rssi}", style: const TextStyle(color: Colors.white, fontSize: 10)),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tag.ean != null)
              Row(
                children: [
                  const Icon(Icons.qr_code, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    "EAN: ${tag.ean}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                  ),
                ],
              ),
            Text(
              tag.epc,
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: tag.ean != null ? 11 : 14,
                color: tag.ean != null ? Colors.grey[600] : Colors.black,
              ),
            ),
          ],
        ),
        subtitle: tag.tid != null ? Text("TID: ${tag.tid}") : null,
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Count", style: TextStyle(fontSize: 10)),
              Text("${tag.readCount}", style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  // Visual helper for signal strength
  Color _getRssiColor(int rssi) {
    // RSSI is usually negative or near zero.
    // Newland might return positive values (dBm * 10 or similar).
    // Assuming standard negative RSSI for this logic, but adjusting just in case.

    // If logic: -30 (strong) to -90 (weak)
    // If Newland returns raw positives (e.g. 50-100%):
    double val = rssi.toDouble();
    if (val.abs() < 50) return Colors.green;
    if (val.abs() < 70) return Colors.orange;
    return Colors.red;
  }
}
