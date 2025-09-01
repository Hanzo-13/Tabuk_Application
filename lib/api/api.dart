import 'package:flutter/foundation.dart';

class ApiEnvironment {
  static const String proxyBaseUrl = "http://localhost:3000/directions";
  static const String directionsBaseUrl = "https://maps.googleapis.com/maps/api/directions/json";
  static const String geocodeBaseUrl = "https://maps.googleapis.com/maps/api/geocode/json";
  static const String googleDirectionsApiKey = "AIzaSyCHDrbJrZHSeMFG40A-hQPB37nrmA6rUKE";

  static String getDirectionsUrl(String origin, String destination, {String mode = 'driving'}) {
    if (kIsWeb) {
      // Use proxy for web with safe query construction
      final uri = Uri.parse(proxyBaseUrl).replace(queryParameters: {
        'origin': origin,
        'destination': destination,
        'mode': mode,
        // Request a higher fidelity polyline for better on-map accuracy
        'overview': 'full',
        'units': 'metric',
        'alternatives': 'false',
        'region': 'ph',
      });
      return uri.toString();
    } else {
      // Use Google API directly for mobile with safe query construction
      final uri = Uri.parse(directionsBaseUrl).replace(queryParameters: {
        'origin': origin,
        'destination': destination,
        'key': googleDirectionsApiKey,
        'mode': mode,
        // Request a higher fidelity polyline for better on-map accuracy
        'overview': 'full',
        'units': 'metric',
        'alternatives': 'false',
        'region': 'ph',
      });
      return uri.toString();
    }
  }

  static String getGeocodeUrlForLatLng(String latlng) {
    // latlng format: "lat,lng"
    final uri = Uri.parse(geocodeBaseUrl).replace(queryParameters: {
      'latlng': latlng,
      'key': googleDirectionsApiKey,
    });
    return uri.toString();
  }
}