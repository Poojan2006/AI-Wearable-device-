import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/local_database.dart';
import '../../models/telemetry_model.dart';

class WorkerHistoryScreen extends StatefulWidget {
  final String workerId;

  const WorkerHistoryScreen({super.key, required this.workerId});

  @override
  State<WorkerHistoryScreen> createState() => _WorkerHistoryScreenState();
}

class _WorkerHistoryScreenState extends State<WorkerHistoryScreen> {
  List<Telemetry> _history = [];
  bool _isLoading = true;
  String _filter = 'ALL'; // 'ALL', 'UNSYNCED', 'SYNCED'

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final records = await LocalDatabase.instance.getTelemetryHistory(widget.workerId, limit: 100);
      setState(() => _history = records);
    } catch (_) {
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _history.where((t) {
      if (_filter == 'UNSYNCED') return !t.synced;
      if (_filter == 'SYNCED') return t.synced;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Local SQLite History"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildFilterChip('ALL', 'All (${_history.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip('UNSYNCED', 'Pending (${_history.where((t) => !t.synced).length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip('SYNCED', 'Synced (${_history.where((t) => t.synced).length})'),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? const Center(
                          child: Text(
                            "No telemetry records logged yet.",
                            style: TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final timeStr = DateFormat('MMM d, hh:mm:ss a').format(
                              DateTime.fromMillisecondsSinceEpoch(item.timestamp),
                            );

                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF131D33),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: item.synced
                                      ? const Color(0xFF243350)
                                      : const Color(0xFFF59E0B).withAlpha(80),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: item.synced
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFF59E0B),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              timeStr,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: (item.synced
                                                        ? const Color(0xFF10B981)
                                                        : const Color(0xFFF59E0B))
                                                    .withAlpha(25),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: (item.synced
                                                          ? const Color(0xFF10B981)
                                                          : const Color(0xFFF59E0B))
                                                      .withAlpha(60),
                                                ),
                                              ),
                                              child: Text(
                                                item.synced ? "CLOUD SYNCED" : "OFFLINE QUEUED",
                                                style: TextStyle(
                                                  color: item.synced
                                                      ? const Color(0xFF10B981)
                                                      : const Color(0xFFF59E0B),
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          "HR: ${item.heartRate} BPM  •  SpO2: ${item.spo2}%  •  Temp: ${item.temperature.toStringAsFixed(1)}°C  •  Gas: ${item.gasLevel} PPM",
                                          style: const TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filter == value;
    final activeColor = value == 'UNSYNCED' ? const Color(0xFFF59E0B) : const Color(0xFF6366F1);

    return InkWell(
      onTap: () => setState(() => _filter = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withAlpha(35) : const Color(0xFF131D33),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFF243350),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}
