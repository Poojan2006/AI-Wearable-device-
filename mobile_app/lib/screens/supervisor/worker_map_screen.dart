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
                bottom: 20,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withAlpha(230),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildLegendItem(SafetyStatus.safe.color, "Safe"),
                      _buildLegendItem(SafetyStatus.warning.color, "Warning"),
                      _buildLegendItem(SafetyStatus.danger.color, "Danger"),
                      _buildLegendItem(SafetyStatus.emergency.color, "Emergency"),
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
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
