import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService instance = LocationService._internal();

  LocationService._internal();

  Position? _lastPosition;
  Position? get lastPosition => _lastPosition;

  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return _lastPosition;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return _lastPosition;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return _lastPosition;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      _lastPosition = pos;
      return pos;
    } catch (_) {
      return _lastPosition;
    }
  }

  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    );
  }
}
