import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../repositories/supervisor_repository.dart';
import '../../models/prediction_result.dart';
import 'worker_details_screen.dart';

class WorkerMapScreen extends StatefulWidget {
  const WorkerMapScreen({super.key});

  @override
  State<WorkerMapScreen> createState() => _WorkerMapScreenState();
}

class _WorkerMapScreenState extends State<WorkerMapScreen> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fleet Geolocation Map"),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location_rounded),
            onPressed: () {
              _mapController.move(const LatLng(17.4485, 78.3742), 16.0);
            },
          ),
        ],
      ),
      body: StreamBuilder<List<FleetWorker>>(
        stream: SupervisorRepository.instance.workersStream,
        initialData: SupervisorRepository.instance.currentWorkers,
        builder: (context, snapshot) {
          final workers = snapshot.data ?? [];

          final markers = workers.map((w) {
            final status = SafetyStatus.fromString(w.status);
            final point = LatLng(w.latitude, w.longitude);

            return Marker(
              point: point,
              width: 80,
              height: 80,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => WorkerDetailsScreen(worker: w)),
                  );
                },
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: status.color),
                      ),
                      child: Text(
                        w.name.split(' ').first,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: status.color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: status.color.withAlpha(128),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person_pin_circle_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList();

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: LatLng(17.4485, 78.3742),
                  initialZoom: 15.5,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.workersafety.worker_safety_app',
                  ),
                  MarkerLayer(markers: markers),
                ],
              ),

              // Floating Map Legend
              Positioned(
                bottom: 24,
                left: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D1A).withAlpha(235),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF243350), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(120),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildLegendItem(const Color(0xFF10B981), "Safe"),
                      _buildLegendItem(const Color(0xFFF59E0B), "Warning"),
                      _buildLegendItem(const Color(0xFFEF4444), "Danger"),
                      _buildLegendItem(const Color(0xFFF43F5E), "SOS Alert"),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(160),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
