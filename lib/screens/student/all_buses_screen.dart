import 'package:flutter/material.dart';
import '../../models/bus_model.dart';
import '../../models/route_model.dart';
import '../../models/live_tracking_model.dart';
import '../../services/database_service.dart';
import 'bus_detail_screen.dart';

/// Screen to display all buses (including offline)
class AllBusesScreen extends StatefulWidget {
  const AllBusesScreen({super.key});

  @override
  State<AllBusesScreen> createState() => _AllBusesScreenState();
}

class _AllBusesScreenState extends State<AllBusesScreen> {
  final DatabaseService _databaseService = DatabaseService();
  Map<String, RouteModel> _routes = {};
  Map<String, LiveTrackingModel> _liveLocations = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Buses'),
        backgroundColor: const Color(0xFF3949AB),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<List<BusModel>>(
        stream: _databaseService.getAllBuses(),
        builder: (context, busSnapshot) {
          if (busSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (busSnapshot.hasError) {
            return Center(child: Text('Error: ${busSnapshot.error}'));
          }

          final buses = busSnapshot.data ?? [];

          if (buses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.directions_bus_outlined,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No buses available',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          // Load routes for buses
          _loadRoutes(buses);

          return StreamBuilder<List<LiveTrackingModel>>(
            stream: _databaseService.getAllLiveTracking(),
            builder: (context, trackingSnapshot) {
              if (trackingSnapshot.hasData) {
                _liveLocations = {
                  for (var t in trackingSnapshot.data!) t.busId: t,
                };
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: buses.length,
                itemBuilder: (context, index) {
                  final bus = buses[index];
                  return _buildBusCard(bus);
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _loadRoutes(List<BusModel> buses) async {
    for (var bus in buses) {
      if (bus.routeId != null && !_routes.containsKey(bus.routeId)) {
        final route = await _databaseService.getRouteById(bus.routeId!);
        if (route != null && mounted) {
          setState(() {
            _routes[bus.routeId!] = route;
          });
        }
      }
    }
  }

  Widget _buildBusCard(BusModel bus) {
    final route = bus.routeId != null ? _routes[bus.routeId] : null;
    final tracking = _liveLocations[bus.id];
    final isLive = tracking != null && !tracking.isStale;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        onTap: () => _showBusDetails(bus, route, tracking),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Bus icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isLive
                          ? Colors.green.shade100
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.directions_bus,
                      color: isLive
                          ? Colors.green.shade700
                          : Colors.grey.shade600,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Bus info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bus ${bus.busNumber}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          route?.routeName ?? 'No route assigned',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isLive
                          ? Colors.green.shade100
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isLive ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isLive ? 'LIVE' : 'OFFLINE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isLive
                                ? Colors.green.shade700
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Route stops preview
              if (route != null && route.stops.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.route, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${route.stops.length} stops: ${route.stops.map((s) => s.name).take(3).join(' → ')}${route.stops.length > 3 ? '...' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // Live info
              if (isLive && tracking != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.speed, size: 16, color: Colors.blue.shade500),
                    const SizedBox(width: 6),
                    Text(
                      '${tracking.speed?.toStringAsFixed(1) ?? '0'} km/h',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.blue.shade500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Updated ${_formatTime(tracking.updatedAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${diff.inHours}h ago';
    }
  }

  void _showBusDetails(
    BusModel bus,
    RouteModel? route,
    LiveTrackingModel? tracking,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusDetailScreen(bus: bus, route: route),
      ),
    );
  }
}
