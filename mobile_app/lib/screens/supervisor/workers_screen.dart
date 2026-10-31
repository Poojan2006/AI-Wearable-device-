import 'package:flutter/material.dart';

import '../../repositories/supervisor_repository.dart';
import '../../widgets/worker_status_card.dart';
import '../../core/theme/app_theme.dart';
import 'worker_details_screen.dart';

class WorkersScreen extends StatefulWidget {
  const WorkersScreen({super.key});

  @override
  State<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends State<WorkersScreen> {
  String _searchQuery = '';
  String _statusFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.textPrimary(context);
    final textSub = AppTheme.textSub(context);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(title: const Text("Fleet Worker Roster")),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              style: TextStyle(color: textPrimary, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: "Search by worker name or ID...",
                prefixIcon: Icon(Icons.search_rounded, color: textSub),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
              onChanged: (val) =>
                  setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),

          // Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('ALL', 'All'),
                const SizedBox(width: 8),
                _buildFilterChip('SAFE', 'Safe'),
                const SizedBox(width: 8),
                _buildFilterChip('WARNING', 'Warning'),
                const SizedBox(width: 8),
                _buildFilterChip('DANGER', 'Danger'),
                const SizedBox(width: 8),
                _buildFilterChip('EMERGENCY', 'Emergency'),
              ],
            ),
          ),
          const SizedBox(height: 6),

          Expanded(
            child: StreamBuilder<List<FleetWorker>>(
              stream: SupervisorRepository.instance.workersStream,
              initialData: SupervisorRepository.instance.currentWorkers,
              builder: (context, snapshot) {
                final allWorkers = snapshot.data ?? [];
                final workers = allWorkers.where((w) {
                  final matchesSearch =
                      w.name.toLowerCase().contains(_searchQuery) ||
                      w.workerId.toLowerCase().contains(_searchQuery);
                  final matchesFilter =
                      _statusFilter == 'ALL' ||
                      w.status.toUpperCase() == _statusFilter;
                  return matchesSearch && matchesFilter;
                }).toList();

                if (workers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search_rounded,
                            color: textSub.withAlpha(100),
                            size: 48,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            "No Workers Found",
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Try adjusting your search query or filter chip selection.",
                            style: TextStyle(color: textSub, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: workers.length,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  itemBuilder: (context, index) {
                    final worker = workers[index];
                    return WorkerStatusCard(
                      worker: worker,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WorkerDetailsScreen(worker: worker),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String val, String label) {
    final isSelected = _statusFilter == val;
    final isDark = AppTheme.isDark(context);

    final Color activeColor = val == 'EMERGENCY'
        ? AppTheme.dangerRed
        : val == 'DANGER'
        ? AppTheme.dangerRed
        : val == 'WARNING'
        ? AppTheme.warningAmber
        : val == 'SAFE'
        ? AppTheme.safeGreen
        : AppTheme.primary;

    return InkWell(
      onTap: () => setState(() => _statusFilter = val),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
