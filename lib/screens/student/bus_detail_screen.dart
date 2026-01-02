import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/bus_model.dart';
import '../../models/route_model.dart';
import '../../models/live_tracking_model.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../services/directions_service.dart';
import 'report_issue_screen.dart';
import 'set_alarm_screen.dart';
import 'student_chat_screen.dart';

/// Detailed bus information screen
class BusDetailScreen extends StatefulWidget {
  final BusModel bus;
  final RouteModel? route;

  const BusDetailScreen({super.key, required this.bus, this.route});

  @override
  State<BusDetailScreen> createState() => _BusDetailScreenState();
}

class _BusDetailScreenState extends State<BusDetailScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final LocationService _locationService = LocationService();
  final DirectionsService _directionsService = DirectionsService();

  LiveTrackingModel? _tracking;
  UserModel? _driver;
  LatLng? _currentPosition;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Get current position
    final position = await _locationService.getCurrentPosition();
    if (position != null && mounted) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
    }

    // Listen to live tracking
    _databaseService.getLiveTracking(widget.bus.id).listen((tracking) {
      if (mounted) {
        setState(() {
          _tracking = tracking;
          _updateMap();
        });
      }
    });

    // Load driver info if bus has assigned driver
    if (widget.bus.driverId != null) {
      final driver = await _databaseService.getDriverById(widget.bus.driverId!);
      if (mounted) {
        setState(() {
          _driver = driver;
        });
      }
    }

    _updateMap();
  }

  void _updateMap() {
    final newMarkers = <Marker>{};
    final newPolylines = <Polyline>{};

    // Bus marker
    if (_tracking != null && !_tracking!.isStale) {
      newMarkers.add(
        Marker(
          markerId: MarkerId('bus_${widget.bus.id}'),
          position: LatLng(_tracking!.lat, _tracking!.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(title: 'Bus ${widget.bus.busNumber}'),
        ),
      );
    }

    // Stop markers
    if (widget.route != null) {
      for (int i = 0; i < widget.route!.stops.length; i++) {
        final stop = widget.route!.stops[i];
        newMarkers.add(
          Marker(
            markerId: MarkerId('stop_$i'),
            position: LatLng(stop.lat, stop.lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue,
            ),
            infoWindow: InfoWindow(title: '${i + 1}. ${stop.name}'),
          ),
        );
      }

      // Route polyline
      if (widget.route!.stops.length >= 2) {
        newPolylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: widget.route!.stops
                .map((s) => LatLng(s.lat, s.lng))
                .toList(),
            color: const Color(0xFF3949AB),
            width: 4,
          ),
        );
      }
    }

    setState(() {
      _markers = newMarkers;
      _polylines = newPolylines;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLive = _tracking != null && !_tracking!.isStale;

    return Scaffold(
      appBar: AppBar(
        title: Text('Bus ${widget.bus.busNumber}'),
        backgroundColor: const Color(0xFF3949AB),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentChatScreen(bus: widget.bus),
                ),
              );
            },
            tooltip: 'Bus Group Chat',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map section
            SizedBox(
              height: 250,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _tracking != null
                      ? LatLng(_tracking!.lat, _tracking!.lng)
                      : widget.route?.stops.isNotEmpty == true
                      ? LatLng(
                          widget.route!.stops.first.lat,
                          widget.route!.stops.first.lng,
                        )
                      : const LatLng(12.9716, 77.5946),
                  zoom: 14,
                ),
                onMapCreated: (controller) => _mapController = controller,
                markers: _markers,
                polylines: _polylines,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
              ),
            ),

            // Status card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isLive ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isLive
                      ? Colors.green.shade200
                      : Colors.orange.shade200,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isLive
                          ? Colors.green.shade100
                          : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isLive ? Icons.location_on : Icons.location_off,
                      color: isLive
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isLive ? 'Bus is Active' : 'Bus is Offline',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isLive
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isLive
                              ? 'Speed: ${_tracking!.speed?.toStringAsFixed(1) ?? '0'} km/h'
                              : 'Check back later for live tracking',
                          style: TextStyle(
                            fontSize: 14,
                            color: isLive
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bus info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bus Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoTile(
                    icon: Icons.directions_bus,
                    title: 'Bus Number',
                    value: widget.bus.busNumber,
                  ),
                  _buildInfoTile(
                    icon: Icons.route,
                    title: 'Route',
                    value: widget.route?.routeName ?? 'No route assigned',
                  ),
                  if (widget.route != null)
                    _buildInfoTile(
                      icon: Icons.pin_drop,
                      title: 'Stops',
                      value: '${widget.route!.stops.length} stops',
                    ),
                ],
              ),
            ),

            // Driver info (if available and live)
            if (_driver != null && isLive) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Driver Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(0xFF3949AB),
                            child: Text(
                              _driver!.name.isNotEmpty
                                  ? _driver!.name[0].toUpperCase()
                                  : 'D',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _driver!.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Driver',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Route stops
            if (widget.route != null && widget.route!.stops.isNotEmpty) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Route Stops',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...widget.route!.stops.asMap().entries.map((entry) {
                      final index = entry.key;
                      final stop = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF3949AB).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF3949AB),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                stop.name,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            if (_currentPosition != null)
                              Text(
                                '${_calculateDistance(stop).toStringAsFixed(1)} km',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],

            // Action buttons
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _setAlarm(),
                      icon: const Icon(Icons.alarm_add),
                      label: const Text('Set Alarm'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3949AB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _reportIssue(),
                      icon: const Icon(Icons.report_outlined),
                      label: const Text('Report Issue'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                        side: BorderSide(color: Colors.orange.shade700),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF3949AB), size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _calculateDistance(BusStop stop) {
    if (_currentPosition == null) return 0;
    return Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          stop.lat,
          stop.lng,
        ) /
        1000; // Convert to km
  }

  void _setAlarm() {
    if (widget.route == null || widget.route!.stops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No route assigned to this bus')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SetAlarmScreen(bus: widget.bus, route: widget.route!),
      ),
    );
  }

  void _reportIssue() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportIssueScreen(selectedBus: widget.bus),
      ),
    );
  }
}
