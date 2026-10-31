import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../database/local_database.dart';
import '../../models/telemetry_model.dart';
import '../../core/theme/app_theme.dart';
import '../../services/sync_service.dart';

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
      final records = await LocalDatabase.instance.getTelemetryHistory(
        widget.workerId,
        limit: 100,
      );
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

    final isDark = AppTheme.isDark(context);
    final cardBg = AppTheme.cardBg(context);
    final textPrimary = AppTheme.textPrimary(context);
    final textSub = AppTheme.textSub(context);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        title: const Text("SQLite Offline Audit History"),
        actions: [
          IconButton(
            tooltip: "Force Cloud Sync",
            icon: const Icon(Icons.cloud_upload_rounded),
            onPressed: () async {
              await SyncService.instance.syncPendingRecords();
              await _loadHistory();
            },
          ),
          IconButton(
            tooltip: "Refresh Records",
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _buildFilterChip('ALL', 'All (${_history.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'UNSYNCED',
                    'Queued (${_history.where((t) => !t.synced).length})',
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'SYNCED',
                    'Synced (${_history.where((t) => t.synced).length})',
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 42,
                            color: textSub.withAlpha(100),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "No telemetry records found for this filter.",
                            style: TextStyle(color: textSub, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final timeStr = DateFormat('MMM d, hh:mm:ss a').format(
                          DateTime.fromMillisecondsSinceEpoch(item.timestamp),
                        );

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: item.synced
                                  ? AppTheme.border(context)
                                  : AppTheme.warningAmber.withAlpha(
                                      isDark ? 90 : 70,
                                    ),
                              width: 1,
                            ),
                            boxShadow: [
                              if (!isDark)
                                BoxShadow(
                                  color: Colors.black.withAlpha(4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: item.synced
                                      ? AppTheme.safeGreen
                                      : AppTheme.warningAmber,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          timeStr,
                                          style: TextStyle(
                                            color: textPrimary,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                (item.synced
                                                        ? AppTheme.safeGreen
                                                        : AppTheme.warningAmber)
                                                    .withAlpha(
                                                      isDark ? 30 : 20,
                                                    ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color:
                                                  (item.synced
                                                          ? AppTheme.safeGreen
                                                          : AppTheme
                                                                .warningAmber)
                                                      .withAlpha(
                                                        isDark ? 70 : 50,
                                                      ),
                                            ),
                                          ),
                                          child: Text(
                                            item.synced
                                                ? "CLOUD SYNCED"
                                                : "OFFLINE BUFFER",
                                            style: TextStyle(
                                              color: item.synced
                                                  ? AppTheme.safeGreen
                                                  : AppTheme.warningAmber,
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
                                      style: TextStyle(
                                        color: textSub,
                                        fontSize: 11.5,
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
    final isDark = AppTheme.isDark(context);
    final activeColor = value == 'UNSYNCED'
        ? AppTheme.warningAmber
        : AppTheme.primary;

    return InkWell(
      onTap: () => setState(() => _filter = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withAlpha(isDark ? 40 : 25)
              : AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : AppTheme.border(context),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? activeColor : AppTheme.textSub(context),
          ),
        ),
      ),
    );
  }
}
