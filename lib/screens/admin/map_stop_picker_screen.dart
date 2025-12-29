import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/location_service.dart';
import '../../models/route_model.dart';

/// Map picker screen for admin to select route stops
class MapStopPickerScreen extends StatefulWidget {
  final List<BusStop> existingStops;

  const MapStopPickerScreen({super.key, this.existingStops = const []});

  @override
  State<MapStopPickerScreen> createState() => _MapStopPickerScreenState();
}

class _MapStopPickerScreenState extends State<MapStopPickerScreen> {
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _stopNameController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  GoogleMapController? _mapController;
  List<BusStop> _stops = [];
  final Set<Marker> _markers = {};

  LatLng? _selectedLocation;
  String? _selectedPlaceName;
  LatLng _currentCenter = const LatLng(12.9716, 77.5946); // Default: Bangalore
  bool _isLoading = true;
  bool _isSearching = false;
  String? _searchError;
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _stops = List.from(widget.existingStops);
    _getCurrentLocation();
    _updateMarkers();
  }

  Future<void> _getCurrentLocation() async {
    final position = await _locationService.getCurrentPosition();
    if (position != null && mounted) {
      setState(() {
        _currentCenter = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(_currentCenter));
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateMarkers() {
    final newMarkers = <Marker>{};

    // Add existing stop markers
    for (int i = 0; i < _stops.length; i++) {
      final stop = _stops[i];
      newMarkers.add(
        Marker(
          markerId: MarkerId('stop_$i'),
          position: LatLng(stop.lat, stop.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: '${i + 1}. ${stop.name}',
            snippet: 'Tap to remove',
          ),
          onTap: () => _confirmRemoveStop(i),
        ),
      );
    }

    // Add selected location marker (red)
    if (_selectedLocation != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('selected'),
          position: _selectedLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: _selectedPlaceName ?? 'Selected Location',
          ),
        ),
      );
    }

    setState(() {
      _markers.clear();
      _markers.addAll(newMarkers);
    });
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchPlaces(query.trim());
    });
  }

  Future<void> _searchPlaces(String query) async {
    try {
      final locations = await locationFromAddress(query);

      if (!mounted) return;

      if (locations.isEmpty) {
        setState(() {
          _searchResults = [];
          _searchError = 'No places found for "$query"';
          _isSearching = false;
        });
        return;
      }

      final results = <Map<String, dynamic>>[];

      for (var location in locations.take(5)) {
        // Try to get place name from coordinates
        try {
          final placemarks = await placemarkFromCoordinates(
            location.latitude,
            location.longitude,
          );

          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            final nameParts = <String>[];
            if (place.name != null && place.name!.isNotEmpty) {
              nameParts.add(place.name!);
            }
            if (place.subLocality != null && place.subLocality!.isNotEmpty) {
              nameParts.add(place.subLocality!);
            }
            if (place.locality != null && place.locality!.isNotEmpty) {
              nameParts.add(place.locality!);
            }
            if (place.administrativeArea != null &&
                place.administrativeArea!.isNotEmpty) {
              nameParts.add(place.administrativeArea!);
            }

            final name = nameParts.isNotEmpty ? nameParts.join(', ') : query;

            results.add({
              'name': name,
              'lat': location.latitude,
              'lng': location.longitude,
            });
          } else {
            results.add({
              'name': query,
              'lat': location.latitude,
              'lng': location.longitude,
            });
          }
        } catch (e) {
          results.add({
            'name': query,
            'lat': location.latitude,
            'lng': location.longitude,
          });
        }
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
          _searchError = results.isEmpty
              ? 'No places found for "$query"'
              : null;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _searchError =
              'No places found. Try a more specific search like "MG Road, Bangalore"';
          _isSearching = false;
        });
      }
    }
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    final lat = result['lat'] as double;
    final lng = result['lng'] as double;
    final name = result['name'] as String;

    setState(() {
      _selectedLocation = LatLng(lat, lng);
      _selectedPlaceName = name;
      _searchResults = [];
      _searchController.clear();
    });

    _searchFocusNode.unfocus();
    _updateMarkers();

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16),
    );

    _showAddStopDialog(suggestedName: name);
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _selectedLocation = position;
      _selectedPlaceName = null;
      _searchResults = [];
    });
    _searchController.clear();
    _searchFocusNode.unfocus();
    _updateMarkers();
    _showAddStopDialog();
  }

  void _showAddStopDialog({String? suggestedName}) {
    if (_selectedLocation == null) return;

    _stopNameController.text = suggestedName ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Stop'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _stopNameController,
              autofocus: suggestedName == null,
              decoration: const InputDecoration(
                labelText: 'Stop Name',
                hintText: 'e.g., Main Gate, Library',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            Text(
              'Location: ${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedLocation = null;
                _selectedPlaceName = null;
              });
              _updateMarkers();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_stopNameController.text.trim().isNotEmpty) {
                final stop = BusStop(
                  name: _stopNameController.text.trim(),
                  lat: _selectedLocation!.latitude,
                  lng: _selectedLocation!.longitude,
                );
                setState(() {
                  _stops.add(stop);
                  _selectedLocation = null;
                  _selectedPlaceName = null;
                });
                _updateMarkers();
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Stop "${stop.name}" added'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3949AB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Stop'),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveStop(int index) {
    final stop = _stops[index];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Stop'),
        content: Text('Remove "${stop.name}" from the route?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _stops.removeAt(index);
              });
              _updateMarkers();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _saveAndReturn() {
    Navigator.pop(context, _stops);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _stopNameController.dispose();
    _searchFocusNode.dispose();
    _mapController?.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Stops'),
        backgroundColor: const Color(0xFF3949AB),
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: _stops.isNotEmpty ? _saveAndReturn : null,
            icon: const Icon(Icons.check, color: Colors.white),
            label: Text(
              'Done (${_stops.length})',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Google Map
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentCenter,
                    zoom: 15,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  onTap: _onMapTap,
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),

                // Search bar
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    children: [
                      // Search input
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(25),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Search places...',
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Color(0xFF3949AB),
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchResults = [];
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),

                      // Search results
                      if (_isSearching)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(25),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Searching...'),
                            ],
                          ),
                        )
                      else if (_searchResults.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          constraints: const BoxConstraints(maxHeight: 250),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(25),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _searchResults.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final result = _searchResults[index];
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF3949AB,
                                    ).withAlpha(25),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Color(0xFF3949AB),
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  result['name'],
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${(result['lat'] as double).toStringAsFixed(4)}, ${(result['lng'] as double).toStringAsFixed(4)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                onTap: () => _selectSearchResult(result),
                              );
                            },
                          ),
                        ),

                      // No results / error message
                      if (_searchError != null &&
                          !_isSearching &&
                          _searchResults.isEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(25),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.search_off,
                                  color: Colors.orange.shade700,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _searchError!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Hint card (shown when not searching)
                      if (_searchResults.isEmpty &&
                          !_isSearching &&
                          _searchError == null &&
                          _searchController.text.isEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(25),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3949AB).withAlpha(25),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.touch_app,
                                  color: Color(0xFF3949AB),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Search for a place or tap on the map',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // My location button
                Positioned(
                  right: 16,
                  bottom: _stops.isNotEmpty ? 180 : 100,
                  child: FloatingActionButton.small(
                    heroTag: 'my_location',
                    onPressed: () {
                      if (_currentCenter != const LatLng(12.9716, 77.5946)) {
                        _mapController?.animateCamera(
                          CameraUpdate.newLatLng(_currentCenter),
                        );
                      }
                    },
                    backgroundColor: Colors.white,
                    child: const Icon(
                      Icons.my_location,
                      color: Color(0xFF3949AB),
                    ),
                  ),
                ),

                // Stops list
                if (_stops.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(25),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
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
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Text(
                                  'Route Stops (${_stops.length})',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _stops.clear();
                                    });
                                    _updateMarkers();
                                  },
                                  icon: const Icon(Icons.clear_all, size: 18),
                                  label: const Text('Clear All'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 80,
                            child: ReorderableListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: _stops.length,
                              onReorder: (oldIndex, newIndex) {
                                setState(() {
                                  if (newIndex > oldIndex) newIndex--;
                                  final stop = _stops.removeAt(oldIndex);
                                  _stops.insert(newIndex, stop);
                                });
                                _updateMarkers();
                              },
                              itemBuilder: (context, index) {
                                final stop = _stops[index];
                                return Container(
                                  key: ValueKey('stop_$index'),
                                  width: 140,
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF3949AB),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          stop.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => _confirmRemoveStop(index),
                                        child: Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
