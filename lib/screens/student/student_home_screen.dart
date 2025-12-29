import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../models/bus_model.dart';
import '../../models/route_model.dart';
import '../../models/live_tracking_model.dart';
import '../auth/login_screen.dart';

/// Student home screen with live bus tracking map
class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final LocationService _locationService = LocationService();

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  List<BusModel> _buses = [];
  Map<String, LiveTrackingModel> _liveLocations = {};
  Map<String, RouteModel> _routes = {};

  BusModel? _selectedBus;
  BusStop? _directionStop; // Stop to show directions to
  bool _isLoading = true;
  LatLng? _currentPosition;

  StreamSubscription? _busSubscription;
  StreamSubscription? _liveTrackingSubscription;

  // Default center (can be your college location)
  static const LatLng _defaultCenter = LatLng(12.9716, 77.5946); // Bangalore

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _getCurrentLocation();
    _listenToBuses();
    _listenToLiveTracking();
  }

  Future<void> _getCurrentLocation() async {
    final position = await _locationService.getCurrentPosition();
    if (position != null && mounted) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
    }
  }

  void _listenToBuses() {
    _busSubscription = _databaseService.getActiveBuses().listen((buses) async {
      _buses = buses;

      // Fetch routes for each bus
      for (var bus in buses) {
        if (bus.routeId != null && !_routes.containsKey(bus.routeId)) {
          final route = await _databaseService.getRouteById(bus.routeId!);
          if (route != null) {
            _routes[bus.routeId!] = route;
          }
        }
      }

      _updateMarkers();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _listenToLiveTracking() {
    _liveTrackingSubscription = _databaseService.getAllLiveTracking().listen((
      trackingList,
    ) {
      _liveLocations = {for (var t in trackingList) t.busId: t};
      _updateMarkers();
    });
  }

  void _updateMarkers() {
    if (!mounted) return;

    final newMarkers = <Marker>{};

    // Add current location marker
    if (_currentPosition != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: const InfoWindow(title: 'You are here'),
        ),
      );
    }

    // Add bus markers
    for (var bus in _buses) {
      final tracking = _liveLocations[bus.id];
      if (tracking != null && !tracking.isStale) {
        newMarkers.add(
          Marker(
            markerId: MarkerId('bus_${bus.id}'),
            position: LatLng(tracking.lat, tracking.lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              _selectedBus?.id == bus.id
                  ? BitmapDescriptor.hueGreen
                  : BitmapDescriptor.hueOrange,
            ),
            infoWindow: InfoWindow(
              title: 'Bus ${bus.busNumber}',
              snippet: 'Tap for details',
            ),
            onTap: () => _selectBus(bus),
          ),
        );
      }
    }

    // Add stop markers when a bus is selected
    if (_selectedBus != null && _selectedBus!.routeId != null) {
      final route = _routes[_selectedBus!.routeId];
      if (route != null && route.stops.isNotEmpty) {
        for (int i = 0; i < route.stops.length; i++) {
          final stop = route.stops[i];
          newMarkers.add(
            Marker(
              markerId: MarkerId('stop_${route.id}_$i'),
              position: LatLng(stop.lat, stop.lng),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueBlue,
              ),
              infoWindow: InfoWindow(
                title: '${i + 1}. ${stop.name}',
                snippet: 'Bus Stop',
              ),
            ),
          );
        }
      }
    }

    setState(() {
      _markers.clear();
      _markers.addAll(newMarkers);
    });

    _updatePolylines();
  }

  void _updatePolylines() {
    final newPolylines = <Polyline>{};

    // Route polyline (connecting all stops)
    if (_selectedBus != null && _selectedBus!.routeId != null) {
      final route = _routes[_selectedBus!.routeId];
      if (route != null && route.stops.isNotEmpty) {
        final points = route.stops.map((s) => LatLng(s.lat, s.lng)).toList();
        newPolylines.add(
          Polyline(
            polylineId: PolylineId('route_${route.id}'),
            points: points,
            color: const Color(0xFF3949AB),
            width: 4,
          ),
        );
      }
    }

    // Direction polyline (from user to selected stop)
    if (_directionStop != null && _currentPosition != null) {
      newPolylines.add(
        Polyline(
          polylineId: const PolylineId('direction'),
          points: [
            _currentPosition!,
            LatLng(_directionStop!.lat, _directionStop!.lng),
          ],
          color: Colors.green,
          width: 5,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      );
    }

    setState(() {
      _polylines.clear();
      _polylines.addAll(newPolylines);
    });
  }

  void _selectBus(BusModel bus) {
    setState(() {
      _selectedBus = bus;
      _directionStop = null; // Clear direction when selecting new bus
    });
    _updateMarkers();
    _showBusDetails(bus);
  }

  /// Find the nearest stop from user's current location
  BusStop? _findNearestStop(List<BusStop> stops) {
    if (_currentPosition == null || stops.isEmpty) return null;

    BusStop? nearest;
    double minDistance = double.infinity;

    for (var stop in stops) {
      final distance = _locationService.calculateDistance(
        startLat: _currentPosition!.latitude,
        startLng: _currentPosition!.longitude,
        endLat: stop.lat,
        endLng: stop.lng,
      );
      if (distance < minDistance) {
        minDistance = distance;
        nearest = stop;
      }
    }
    return nearest;
  }

  /// Show directions to a specific stop
  void _showDirectionsToStop(BusStop stop) {
    setState(() {
      _directionStop = stop;
    });
    _updateMarkers();
    _updatePolylines();

    // Zoom to show both user and stop
    if (_currentPosition != null && _mapController != null) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          _currentPosition!.latitude < stop.lat
              ? _currentPosition!.latitude
              : stop.lat,
          _currentPosition!.longitude < stop.lng
              ? _currentPosition!.longitude
              : stop.lng,
        ),
        northeast: LatLng(
          _currentPosition!.latitude > stop.lat
              ? _currentPosition!.latitude
              : stop.lat,
          _currentPosition!.longitude > stop.lng
              ? _currentPosition!.longitude
              : stop.lng,
        ),
      );
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    }

    // Show distance info
    if (_currentPosition != null) {
      final distance = _locationService.calculateDistance(
        startLat: _currentPosition!.latitude,
        startLng: _currentPosition!.longitude,
        endLat: stop.lat,
        endLng: stop.lng,
      );
      final distanceText = distance >= 1000
          ? '${(distance / 1000).toStringAsFixed(1)} km'
          : '${distance.round()} m';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.directions_walk, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Directions to ${stop.name}: $distanceText'),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Clear',
            textColor: Colors.white,
            onPressed: _clearDirections,
          ),
        ),
      );
    }
  }

  /// Clear directions
  void _clearDirections() {
    setState(() {
      _directionStop = null;
    });
    _updatePolylines();
  }

  /// Show directions to nearest stop
  void _showDirectionsToNearestStop() {
    if (_selectedBus == null || _selectedBus!.routeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a bus first')),
      );
      return;
    }

    final route = _routes[_selectedBus!.routeId];
    if (route == null || route.stops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No stops available for this route')),
      );
      return;
    }

    final nearest = _findNearestStop(route.stops);
    if (nearest != null) {
      Navigator.pop(context); // Close bottom sheet
      _showDirectionsToStop(nearest);
    }
  }

  void _showBusDetails(BusModel bus) {
    final tracking = _liveLocations[bus.id];
    final route = bus.routeId != null ? _routes[bus.routeId] : null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Bus info header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3949AB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_bus,
                    color: Color(0xFF3949AB),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bus ${bus.busNumber}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (route != null)
                        Text(
                          route.routeName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: tracking != null && !tracking.isStale
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tracking != null && !tracking.isStale ? 'LIVE' : 'OFFLINE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: tracking != null && !tracking.isStale
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ETA info
            if (tracking != null &&
                !tracking.isStale &&
                _currentPosition != null) ...[
              _buildInfoRow(
                icon: Icons.timer_outlined,
                label: 'ETA',
                value: _calculateETA(tracking),
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.speed,
                label: 'Speed',
                value: tracking.speed != null
                    ? '${tracking.speed!.toStringAsFixed(1)} km/h'
                    : 'N/A',
              ),
            ],

            // Route stops
            if (route != null && route.stops.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Stops',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: _showDirectionsToNearestStop,
                    icon: const Icon(Icons.near_me, size: 18),
                    label: const Text('Nearest'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap a stop for directions',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: route.stops.length,
                  itemBuilder: (context, index) {
                    final stop = route.stops[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context); // Close bottom sheet
                        _showDirectionsToStop(stop);
                      },
                      child: Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.shade200,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.directions,
                              color: Colors.green.shade600,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              stop.name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: Colors.grey.shade600)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _calculateETA(LiveTrackingModel tracking) {
    if (_currentPosition == null) return 'N/A';

    final distance = _locationService.calculateDistance(
      startLat: tracking.lat,
      startLng: tracking.lng,
      endLat: _currentPosition!.latitude,
      endLng: _currentPosition!.longitude,
    );

    // Use default speed if tracking speed is null, 0, or invalid
    final speed = (tracking.speed != null && tracking.speed! > 0)
        ? tracking.speed!
        : 30.0;

    final etaMinutes = _locationService.calculateETA(
      distanceInMeters: distance,
      averageSpeedKmh: speed,
    );

    // Safety check for NaN or Infinity
    if (etaMinutes.isNaN || etaMinutes.isInfinite || etaMinutes < 0) {
      return 'Calculating...';
    }

    if (etaMinutes < 1) {
      return 'Less than 1 min';
    } else if (etaMinutes < 60) {
      return '${etaMinutes.round()} min';
    } else {
      final hours = (etaMinutes / 60).floor();
      final mins = (etaMinutes % 60).round();
      return '$hours hr $mins min';
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _busSubscription?.cancel();
    _liveTrackingSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Track'),
        backgroundColor: const Color(0xFF3949AB),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              if (_currentPosition != null && _mapController != null) {
                _mapController!.animateCamera(
                  CameraUpdate.newLatLng(_currentPosition!),
                );
              }
            },
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _signOut),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Google Map
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition ?? _defaultCenter,
                    zoom: 14,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),

                // Active buses count
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_liveLocations.length} Active Buses',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bus list button
                Positioned(
                  bottom: 24,
                  left: 16,
                  right: 16,
                  child: ElevatedButton.icon(
                    onPressed: _showBusList,
                    icon: const Icon(Icons.list),
                    label: const Text('View All Buses'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3949AB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showBusList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Active Buses',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: _buses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.directions_bus_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No active buses at the moment',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _buses.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final bus = _buses[index];
                          final tracking = _liveLocations[bus.id];
                          final route = bus.routeId != null
                              ? _routes[bus.routeId]
                              : null;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF3949AB,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.directions_bus,
                                  color: Color(0xFF3949AB),
                                ),
                              ),
                              title: Text(
                                'Bus ${bus.busNumber}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                route?.routeName ?? 'No route assigned',
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: tracking != null && !tracking.isStale
                                      ? Colors.green.shade100
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  tracking != null && !tracking.isStale
                                      ? 'LIVE'
                                      : 'OFFLINE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: tracking != null && !tracking.isStale
                                        ? Colors.green.shade700
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                if (tracking != null && !tracking.isStale) {
                                  _mapController?.animateCamera(
                                    CameraUpdate.newLatLng(
                                      LatLng(tracking.lat, tracking.lng),
                                    ),
                                  );
                                }
                                _selectBus(bus);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
