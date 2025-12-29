import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../models/bus_model.dart';
import '../../models/route_model.dart';
import '../auth/login_screen.dart';

/// Driver home screen with trip management and location streaming
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final LocationService _locationService = LocationService();

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  BusModel? _assignedBus;
  RouteModel? _assignedRoute;
  BusStop? _directionStop; // Stop to show directions to
  bool _isLoading = true;
  bool _isTripActive = false;
  bool _isStartingTrip = false;
  LatLng? _currentPosition;
  String? _errorMessage;

  StreamSubscription<Position>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  Future<void> _loadDriverData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) {
        _signOut();
        return;
      }

      // Get assigned bus for this driver
      final bus = await _databaseService.getBusForDriver(user.uid);

      if (bus != null) {
        _assignedBus = bus;
        _isTripActive = bus.isActive;

        // Get assigned route
        if (bus.routeId != null) {
          _assignedRoute = await _databaseService.getRouteById(bus.routeId!);
          _updatePolylines();
        }
      }

      // Get current location
      await _getCurrentLocation();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    final position = await _locationService.getCurrentPosition();
    if (position != null && mounted) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      _updateMarkers();

      _mapController?.animateCamera(CameraUpdate.newLatLng(_currentPosition!));
    }
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
            _isTripActive ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
          ),
          infoWindow: InfoWindow(
            title: _isTripActive ? 'Trip Active' : 'Trip Inactive',
          ),
        ),
      );
    }

    // Add stop markers
    if (_assignedRoute != null) {
      for (int i = 0; i < _assignedRoute!.stops.length; i++) {
        final stop = _assignedRoute!.stops[i];
        newMarkers.add(
          Marker(
            markerId: MarkerId('stop_$i'),
            position: LatLng(stop.lat, stop.lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue,
            ),
            infoWindow: InfoWindow(title: stop.name),
          ),
        );
      }
    }

    setState(() {
      _markers.clear();
      _markers.addAll(newMarkers);
    });
  }

  void _updatePolylines() {
    final newPolylines = <Polyline>{};

    // Route polyline (connecting all stops)
    if (_assignedRoute != null && _assignedRoute!.stops.isNotEmpty) {
      final points = _assignedRoute!.stops
          .map((s) => LatLng(s.lat, s.lng))
          .toList();
      newPolylines.add(
        Polyline(
          polylineId: PolylineId('route_${_assignedRoute!.id}'),
          points: points,
          color: const Color(0xFF3949AB),
          width: 4,
        ),
      );
    }

    // Direction polyline (from current location to selected stop)
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

  Future<void> _toggleTrip() async {
    if (_assignedBus == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No bus assigned to you')));
      return;
    }

    setState(() {
      _isStartingTrip = true;
    });

    try {
      if (_isTripActive) {
        // End trip
        await _stopLocationStreaming();
        await _databaseService.setBusActive(_assignedBus!.id, false);
        await _databaseService.deleteLiveTracking(_assignedBus!.id);

        setState(() {
          _isTripActive = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip ended successfully'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // Start trip
        final hasPermission = await _locationService
            .requestLocationPermission();
        if (!hasPermission) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission is required'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        await _databaseService.setBusActive(_assignedBus!.id, true);
        _startLocationStreaming();

        setState(() {
          _isTripActive = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip started! Sharing location...'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      _updateMarkers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isStartingTrip = false;
        });
      }
    }
  }

  void _startLocationStreaming() {
    _locationSubscription?.cancel();
    _locationSubscription = _locationService.getPositionStream().listen(
      (position) async {
        if (!mounted || _assignedBus == null) return;

        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });

        // Update location in Firestore
        await _databaseService.updateLiveLocation(
          busId: _assignedBus!.id,
          lat: position.latitude,
          lng: position.longitude,
          speed: position.speed * 3.6, // Convert m/s to km/h
          heading: position.heading,
        );

        _updateMarkers();
      },
      onError: (error) {
        debugPrint('Location stream error: $error');
      },
    );
  }

  Future<void> _stopLocationStreaming() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  /// Find the nearest stop from current bus location
  BusStop? _findNearestStop() {
    if (_currentPosition == null || _assignedRoute == null) return null;
    if (_assignedRoute!.stops.isEmpty) return null;

    BusStop? nearest;
    double minDistance = double.infinity;

    for (var stop in _assignedRoute!.stops) {
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
    _updatePolylines();

    // Zoom to show both bus location and stop
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
              const Icon(Icons.navigation, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Next stop: ${stop.name} - $distanceText')),
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

  /// Navigate to nearest stop
  void _navigateToNearestStop() {
    final nearest = _findNearestStop();
    if (nearest != null) {
      _showDirectionsToStop(nearest);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No stops available')));
    }
  }

  Future<void> _signOut() async {
    if (_isTripActive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('End Trip First'),
          content: const Text(
            'You have an active trip. Please end the trip before signing out.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await _toggleTrip();
                if (mounted) Navigator.pop(context, true);
              },
              child: const Text('End Trip & Sign Out'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

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
    _locationSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        backgroundColor: const Color(0xFF3949AB),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDriverData,
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _signOut),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(_errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadDriverData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _assignedBus == null
          ? _buildNoBusAssigned()
          : _buildDriverDashboard(),
    );
  }

  Widget _buildNoBusAssigned() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_bus_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 24),
          const Text(
            'No Bus Assigned',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Please contact the administrator\nto get a bus assigned to you.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadDriverData,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3949AB),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverDashboard() {
    return Column(
      children: [
        // Bus and Route Info Card
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
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
                          'Bus ${_assignedBus!.busNumber}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _assignedRoute?.routeName ?? 'No route assigned',
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
                      color: _isTripActive
                          ? Colors.green.shade100
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isTripActive)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Text(
                          _isTripActive ? 'LIVE' : 'OFFLINE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _isTripActive
                                ? Colors.green.shade700
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Start/End Trip Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isStartingTrip ? null : _toggleTrip,
                  icon: _isStartingTrip
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Icon(_isTripActive ? Icons.stop : Icons.play_arrow),
                  label: Text(_isTripActive ? 'End Trip' : 'Start Trip'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isTripActive ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Map
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition ?? const LatLng(12.9716, 77.5946),
                zoom: 14,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                if (_currentPosition != null) {
                  controller.animateCamera(
                    CameraUpdate.newLatLng(_currentPosition!),
                  );
                }
              },
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: false,
              zoomControlsEnabled: true,
              mapToolbarEnabled: false,
            ),
          ),
        ),

        // Route stops (if available)
        if (_assignedRoute != null && _assignedRoute!.stops.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                // Header with Nearest button
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Route Stops',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _navigateToNearestStop,
                        icon: const Icon(Icons.near_me, size: 16),
                        label: const Text('Nearest'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                ),
                // Stop cards
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _assignedRoute!.stops.length,
                    itemBuilder: (context, index) {
                      final stop = _assignedRoute!.stops[index];
                      final isSelected = _directionStop?.name == stop.name;
                      return GestureDetector(
                        onTap: () => _showDirectionsToStop(stop),
                        child: Container(
                          width: 140,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.green.shade50
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.green
                                  : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(13),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.green
                                          : const Color(0xFF3949AB),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: isSelected
                                          ? const Icon(
                                              Icons.navigation,
                                              color: Colors.white,
                                              size: 14,
                                            )
                                          : Text(
                                              '${index + 1}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                stop.name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected
                                      ? Colors.green.shade700
                                      : Colors.black87,
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
            ),
          ),
      ],
    );
  }
}
