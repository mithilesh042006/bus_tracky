import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Service for fetching road-based directions from Google Directions API
class DirectionsService {
  // Use the same API key as Google Maps
  static const String _apiKey = 'AIzaSyDfFhFGIBUpYrG03ZiY0JRL5qJP5rTYVnk';
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  /// Fetch route polyline points between origin and destination
  /// Returns a list of LatLng points representing the road path
  Future<List<LatLng>> getRoutePolyline({
    required LatLng origin,
    required LatLng destination,
    String mode = 'driving', // driving, walking, bicycling, transit
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl?'
        'origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=$mode'
        '&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final overviewPolyline = route['overview_polyline']['points'];
          return _decodePolyline(overviewPolyline);
        } else {
          // If no route found, return direct line
          return [origin, destination];
        }
      } else {
        // On error, return direct line
        return [origin, destination];
      }
    } catch (e) {
      // On exception, return direct line
      return [origin, destination];
    }
  }

  /// Decode Google's encoded polyline format into list of LatLng
  /// Algorithm: https://developers.google.com/maps/documentation/utilities/polylinealgorithm
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      // Decode latitude
      int shift = 0;
      int result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      // Decode longitude
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }

  /// Get route info including distance and duration
  Future<Map<String, dynamic>?> getRouteInfo({
    required LatLng origin,
    required LatLng destination,
    String mode = 'driving',
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl?'
        'origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=$mode'
        '&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          return {
            'distance': leg['distance']['text'],
            'distanceValue': leg['distance']['value'], // in meters
            'duration': leg['duration']['text'],
            'durationValue': leg['duration']['value'], // in seconds
            'polyline': _decodePolyline(route['overview_polyline']['points']),
          };
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
