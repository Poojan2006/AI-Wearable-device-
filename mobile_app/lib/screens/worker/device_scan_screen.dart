import 'package:flutter/material.dart';
import '../../services/ble_service.dart';
import '../../models/device_model.dart';

class DeviceScanScreen extends StatefulWidget {
  const DeviceScanScreen({super.key});

  @override
  State<DeviceScanScreen> createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends State<DeviceScanScreen> {
  final BleService _bleService = BleService.instance;
  bool _isScanning = false;
  String? _connectingDeviceId;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() => _isScanning = true);
    try {
      await _bleService.startScan();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("BLE Scan Notice: $e"),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _connect(DeviceModel device) async {
    setState(() => _connectingDeviceId = device.id);
    try {
      await _bleService.connect(device.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Connected to ${device.name}"),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Connection failed: $e"),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _connectingDeviceId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ESP32 Device Scanner"),
        actions: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Color(0xFFF97316), strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _startScan,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Virtual Node Quick Launcher Banner
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _bleService.isVirtualNodeActive
                      ? const Color(0xFF10B981)
                      : const Color(0xFF334155),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withAlpha(38),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.developer_board_rounded, color: Color(0xFF06B6D4), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "ESP32 Virtual Simulator",
                          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14),
                        ),
                        Text(
                          _bleService.isVirtualNodeActive
                              ? "Active: Streaming simulated sensor vitals"
                              : "Simulate ESP32 BLE without physical hardware",
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        if (_bleService.isVirtualNodeActive) {
                          _bleService.stopVirtualNode();
                        } else {
                          _bleService.startVirtualNode();
                          Navigator.pop(context);
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _bleService.isVirtualNodeActive
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: Text(
                      _bleService.isVirtualNodeActive ? "STOP" : "START",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.bluetooth_searching_rounded, size: 16, color: Color(0xFF94A3B8)),
                  SizedBox(width: 6),
                  Text(
                    "DISCOVERED BLUETOOTH LE NODES",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),

            // Discovered Devices List
            Expanded(
              child: StreamBuilder<List<DeviceModel>>(
                stream: _bleService.devicesListStream,
                builder: (context, snapshot) {
                  final devices = snapshot.data ?? [];

                  if (devices.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bluetooth_disabled_rounded, size: 54, color: Colors.white.withAlpha(51)),
                          const SizedBox(height: 12),
                          const Text(
                            "No ESP32 devices found in range",
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _startScan,
                            child: const Text("Scan Again"),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: devices.length,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemBuilder: (context, index) {
                      final d = devices[index];
                      final isCurrent = _bleService.connectedDeviceId == d.id;
                      final isConnecting = _connectingDeviceId == d.id;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent
                                ? const Color(0xFF10B981)
                                : const Color(0xFF334155),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isCurrent ? const Color(0xFF10B981) : const Color(0xFF06B6D4))
                                    .withAlpha(38),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.bluetooth_rounded,
                                color: isCurrent ? const Color(0xFF10B981) : const Color(0xFF06B6D4),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    "ID: ${d.id}  •  RSSI: ${d.rssi} dBm",
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isCurrent)
                              OutlinedButton(
                                onPressed: () async {
                                  await _bleService.disconnect();
                                  setState(() {});
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFEF4444),
                                  side: const BorderSide(color: Color(0xFFEF4444)),
                                ),
                                child: const Text("DISCONNECT", style: TextStyle(fontSize: 11)),
                              )
                            else
                              ElevatedButton(
                                onPressed: isConnecting ? null : () => _connect(d),
                                child: isConnecting
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text("CONNECT", style: TextStyle(fontSize: 11)),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
