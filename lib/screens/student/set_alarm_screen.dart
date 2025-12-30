import 'package:flutter/material.dart';
import '../../models/alarm_model.dart';
import '../../models/bus_model.dart';
import '../../models/route_model.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';

/// Screen for students to set bus proximity alarms
class SetAlarmScreen extends StatefulWidget {
  final BusModel bus;
  final RouteModel route;

  const SetAlarmScreen({super.key, required this.bus, required this.route});

  @override
  State<SetAlarmScreen> createState() => _SetAlarmScreenState();
}

class _SetAlarmScreenState extends State<SetAlarmScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();

  BusStop? _selectedStop;
  double _selectedDistance = 500; // Default 500 meters
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    await _notificationService.initialize();
    await _notificationService.requestPermissions();
  }

  Future<void> _createAlarm() async {
    if (_selectedStop == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a stop')));
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('Please login to set an alarm');
      }

      final alarm = AlarmModel(
        id: '',
        studentId: user.uid,
        busId: widget.bus.id,
        busNumber: widget.bus.busNumber,
        stopId:
            _selectedStop!.name, // Using name as ID since stops don't have IDs
        stopName: _selectedStop!.name,
        stopLat: _selectedStop!.lat,
        stopLng: _selectedStop!.lng,
        alarmDistance: _selectedDistance,
        isActive: true,
        hasTriggered: false,
        createdAt: DateTime.now(),
      );

      await _databaseService.createAlarm(alarm);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Alarm set! You\'ll be notified when bus is ${alarm.distanceDisplay} from ${_selectedStop!.name}',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context, true);
      }
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
          _isCreating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Bus Alarm'),
        backgroundColor: const Color(0xFF3949AB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Bus info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF3949AB).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF3949AB).withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.directions_bus,
                  color: Color(0xFF3949AB),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bus ${widget.bus.busNumber}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.route.routeName,
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

          const SizedBox(height: 24),

          // Select stop
          const Text(
            'Select Stop',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'You\'ll be notified when the bus approaches this stop',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),

          // Stop list
          ...widget.route.stops.map((stop) {
            final isSelected = _selectedStop?.name == stop.name;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: isSelected ? Colors.green.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedStop = stop;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.green.shade400
                            : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: isSelected
                              ? Colors.green.shade600
                              : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            stop.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.location_on,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 24),

          // Select distance
          const Text(
            'Alert Distance',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'How far from the stop should the bus be to alert you?',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),

          // Distance options
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: AlarmModel.alarmDistances.map((distance) {
              final isSelected = _selectedDistance == distance;
              final distanceText = distance >= 1000
                  ? '${(distance / 1000).toStringAsFixed(1)} km'
                  : '${distance.round()} m';

              return ChoiceChip(
                label: Text(distanceText),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedDistance = distance;
                    });
                  }
                },
                selectedColor: Colors.green.shade100,
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.green.shade800
                      : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                backgroundColor: Colors.grey.shade100,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Create alarm button
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _isCreating || _selectedStop == null
                  ? null
                  : _createAlarm,
              icon: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.alarm_add),
              label: Text(
                _isCreating ? 'Setting Alarm...' : 'Set Alarm',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Info note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The alarm will trigger once per trip. Make sure notifications are enabled for this app.',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
