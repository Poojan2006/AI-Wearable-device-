import 'package:flutter/material.dart';
import '../../repositories/supervisor_repository.dart';
import '../../widgets/worker_status_card.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fleet Worker Roster"),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search by worker name or ID...",
                prefixIcon: const Icon(Icons.search_rounded),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),

          // Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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

          Expanded(
            child: StreamBuilder<List<FleetWorker>>(
              stream: SupervisorRepository.instance.workersStream,
              initialData: SupervisorRepository.instance.currentWorkers,
              builder: (context, snapshot) {
                final allWorkers = snapshot.data ?? [];
                final workers = allWorkers.where((w) {
                  final matchesSearch = w.name.toLowerCase().contains(_searchQuery) ||
                      w.workerId.toLowerCase().contains(_searchQuery);
                  final matchesFilter =
                      _statusFilter == 'ALL' || w.status.toUpperCase() == _statusFilter;
                  return matchesSearch && matchesFilter;
                }).toList();

                if (workers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF6366F1).withAlpha(25),
                              border: Border.all(color: const Color(0xFF6366F1).withAlpha(60), width: 1.5),
                            ),
                            child: const Icon(Icons.people_alt_outlined, color: Color(0xFF6366F1), size: 30),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            "No Workers Found",
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Try adjusting your search criteria or filter category.",
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: workers.length,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
    final Color activeColor = val == 'EMERGENCY'
        ? const Color(0xFFF43F5E)
        : val == 'DANGER'
            ? const Color(0xFFEF4444)
            : val == 'WARNING'
                ? const Color(0xFFF59E0B)
                : val == 'SAFE'
                    ? const Color(0xFF10B981)
                    : const Color(0xFF6366F1);

    return InkWell(
      onTap: () => setState(() => _statusFilter = val),
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
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
