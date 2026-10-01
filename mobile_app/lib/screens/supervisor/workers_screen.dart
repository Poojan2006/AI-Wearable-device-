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
                  return const Center(
                    child: Text(
                      "No workers match the specified filters.",
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: workers.length,
                  padding: const EdgeInsets.symmetric(vertical: 6),
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
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _statusFilter = val);
      },
    );
  }
}
