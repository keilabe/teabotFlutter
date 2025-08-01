import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

class LocationService {
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('\n=== Initializing Location Service ===');
    debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');

    try {
      // Check location permissions
      final permissionStatus = await _checkLocationPermission();
      
      if (permissionStatus == LocationPermission.denied) {
        debugPrint('Location permission denied');
        return;
      }
      
      _isInitialized = true;
      debugPrint('Location service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing location service: $e');
    }
  }

  static Future<LocationPermission> _checkLocationPermission() async {
    debugPrint('Checking location permissions...');
    
    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled');
      return LocationPermission.denied;
    }

    // Check permission status
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      // Request permission
      permission = await Geolocator.requestPermission();
      debugPrint('Location permission requested: $permission');
    }
    
    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permission denied forever');
      return LocationPermission.deniedForever;
    }
    
    debugPrint('Location permission status: $permission');
    return permission;
  }

  // Get current location
  static Future<Position?> getCurrentLocation() async {
    try {
      debugPrint('Getting current location...');
      
      if (!_isInitialized) {
        await initialize();
      }
      
      final permission = await _checkLocationPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        debugPrint('Location permission not granted');
        return null;
      }
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      debugPrint('Current location obtained:');
      debugPrint('- Latitude: ${position.latitude}');
      debugPrint('- Longitude: ${position.longitude}');
      debugPrint('- Accuracy: ${position.accuracy}m');
      debugPrint('- Timestamp: ${position.timestamp}');
      
      return position;
    } catch (e) {
      debugPrint('Error getting current location: $e');
      return null;
    }
  }

  // Get last known location
  static Future<Position?> getLastKnownLocation() async {
    try {
      debugPrint('Getting last known location...');
      
      final position = await Geolocator.getLastKnownPosition();
      
      if (position != null) {
        debugPrint('Last known location:');
        debugPrint('- Latitude: ${position.latitude}');
        debugPrint('- Longitude: ${position.longitude}');
        debugPrint('- Timestamp: ${position.timestamp}');
      } else {
        debugPrint('No last known location available');
      }
      
      return position;
    } catch (e) {
      debugPrint('Error getting last known location: $e');
      return null;
    }
  }

  // Calculate distance between two points
  static double calculateDistance({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  // Get location name from coordinates (reverse geocoding)
  static Future<String?> getLocationName({
    required double latitude,
    required double longitude,
  }) async {
    try {
      debugPrint('Getting location name for coordinates: $latitude, $longitude');
      
      final placemarks = await geocoding.placemarkFromCoordinates(latitude, longitude,);
      
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final locationName = [
          placemark.locality,
          placemark.administrativeArea,
          placemark.country,
        ].where((element) => element != null && element.toString().isNotEmpty).join(', ');
        
        debugPrint('Location name: $locationName');
        return locationName.isNotEmpty ? locationName : null;
      }
      
      debugPrint('No location name found');
      return null;
    } catch (e) {
      debugPrint('Error getting location name: $e');
      return null;
    }
  }

  // Check if location is within a region
  static bool isLocationInRegion({
    required double latitude,
    required double longitude,
    required Map<String, dynamic> regionBounds,
  }) {
    final north = regionBounds['north'] as double;
    final south = regionBounds['south'] as double;
    final east = regionBounds['east'] as double;
    final west = regionBounds['west'] as double;
    
    return latitude >= south && 
           latitude <= north && 
           longitude >= west && 
           longitude <= east;
  }

  // Get region ID from coordinates
  static String? getRegionIdFromCoordinates({
    required double latitude,
    required double longitude,
  }) {
    // Define regions (this should come from a database or configuration)
    final regions = [
      {
        'id': 'colombo',
        'name': 'Colombo',
        'bounds': {'north': 7.0, 'south': 6.8, 'east': 80.0, 'west': 79.8}
      },
      {
        'id': 'kandy',
        'name': 'Kandy',
        'bounds': {'north': 7.3, 'south': 7.1, 'east': 80.7, 'west': 80.5}
      },
      {
        'id': 'nuwara_eliya',
        'name': 'Nuwara Eliya',
        'bounds': {'north': 7.0, 'south': 6.8, 'east': 80.8, 'west': 80.6}
      },
    ];
    
    for (final region in regions) {
      if (isLocationInRegion(
        latitude: latitude,
        longitude: longitude,
        regionBounds: region['bounds'] as Map<String, dynamic>,
      )) {
        debugPrint('Location belongs to region: ${region['name']}');
        return region['id'] as String;
      }
    }
    
    debugPrint('Location not found in any defined region');
    return null;
  }

  // Watch location changes
  static Stream<Position> watchLocation({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10, // meters
  }) {
    debugPrint('Starting location watch...');
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    );
  }

  // Stop watching location
  static void stopLocationWatch() {
    debugPrint('Stopping location watch...');
    // The stream will automatically close when the app is disposed
  }

  // Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // Open location settings
  static Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  // Open app settings
  static Future<bool> openAppSettings() async {
    return await openAppSettings();
  }

  // Dispose resources
  static void dispose() {
    debugPrint('Disposing location service...');
    _isInitialized = false;
    debugPrint('Location service disposed');
  }
} 