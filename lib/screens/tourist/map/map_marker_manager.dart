import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:capstone_app/models/destination_model.dart';
import 'package:capstone_app/widgets/custom_map_marker.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Manages map markers, icons, and filtering
class MapMarkerManager {
  final Map<String, BitmapDescriptor> _categoryMarkerIcons = {};
  final Map<String, Map<String, dynamic>> _destinationData = {};
  Set<Marker> _allMarkers = {};
  
  final Function(Map<String, dynamic> data) onMarkerTap;
  bool _iconsInitialized = false;

  static const double _categoryMarkerSize = 100.0; // Larger for iOS visibility
  
  static const Map<String, IconData> _categoryIcons = {
    'Natural Attraction': Icons.park,
    'Cultural Site': Icons.museum,
    'Adventure Spot': Icons.forest,
    'Restaurant': Icons.restaurant,
    'Accommodation': Icons.hotel,
    'Shopping': Icons.shopping_cart,
    'Entertainment': Icons.theater_comedy,
  };
  
  static const Map<String, Color> _categoryColors = {
    'Natural Attraction': Colors.green,
    'Cultural Site': Colors.purple,
    'Adventure Spot': Colors.orange,
    'Restaurant': Colors.red,
    'Accommodation': Colors.blueGrey,
    'Shopping': Colors.blue,
    'Entertainment': Colors.pink,
  };

  MapMarkerManager({required this.onMarkerTap});

  /// Initialize category marker icons
  Future<void> initializeCategoryMarkerIcons() async {
    if (_iconsInitialized) return;
    
    try {
      for (final entry in _categoryIcons.entries) {
        final String key = entry.key;
        final IconData icon = entry.value;
        final Color color = _categoryColors[key] ?? Colors.blue;
        final bitmap = await _createCategoryMarker(icon, color);
        _categoryMarkerIcons[key] = bitmap;
      }
      _iconsInitialized = true;
    } catch (e) {
      print('Error initializing category icons: $e');
    }
  }

  /// Create a custom category marker with better iOS rendering
  Future<BitmapDescriptor> _createCategoryMarker(
    IconData iconData,
    Color color,
  ) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final double radius = _categoryMarkerSize / 2;

    // Shadow (more pronounced for iOS)
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(radius + 2, radius + 2), radius - 6, shadowPaint);

    // Main circle with gradient effect
    final Paint mainPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(radius, radius),
        radius - 6,
        [color.withOpacity(0.9), color],
        [0.0, 1.0],
      )
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(radius, radius), radius - 6, mainPaint);

    // White border (thicker for iOS)
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(Offset(radius, radius), radius - 6, borderPaint);

    // Icon with shadow
    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: _categoryMarkerSize * 0.45,
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: Colors.white,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            offset: const Offset(1, 1),
            blurRadius: 2,
            color: Colors.black.withOpacity(0.3),
          ),
        ],
      ),
    );
    textPainter.layout();
    final Offset iconOffset = Offset(
      radius - textPainter.width / 2,
      radius - textPainter.height / 2,
    );
    textPainter.paint(canvas, iconOffset);

    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(
      _categoryMarkerSize.toInt(),
      _categoryMarkerSize.toInt(),
    );
    final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  /// Create markers from destination data
  Future<Set<Marker>> createMarkersFromDestinations(
    List<Map<String, dynamic>> rawDocs,
  ) async {
    final markers = <Marker>{};
    
    for (final data in rawDocs) {
      final id = data['hotspot_id']?.toString() ?? data['id']?.toString() ?? '';
      final hotspot = Hotspot.fromMap(data, id);
      final double? lat = hotspot.latitude;
      final double? lng = hotspot.longitude;
      final String name = hotspot.name.isNotEmpty ? hotspot.name : 'Tourist Spot';

      if (lat != null && lng != null) {
        final position = LatLng(lat, lng);

        // Get category-based icon
        final categoryRaw = hotspot.category.isNotEmpty ? hotspot.category : hotspot.type;
        final normalizedCategory = _normalizeCategory(categoryRaw);
        final categoryIcon = _getCategoryMarkerIcon(normalizedCategory);
        
        // Fallback to text marker if no category icon
        final customIcon = categoryIcon ??
            await CustomMapMarker.createTextMarker(
              label: name,
              color: Colors.orange,
            );

        final markerIdValue = hotspot.hotspotId.isNotEmpty ? hotspot.hotspotId : id;
        final markerId = MarkerId(markerIdValue);
        
        // Store destination data for ALL markers (not just on tap) for filtering
        final dataWithId = Map<String, dynamic>.from(data)
          ..putIfAbsent('hotspot_id', () => markerIdValue)
          ..putIfAbsent('destinationName', () => name)
          ..putIfAbsent('destinationCategory', () => hotspot.category)
          ..putIfAbsent('destinationType', () => hotspot.type)
          ..putIfAbsent('destinationDistrict', () => hotspot.district)
          ..putIfAbsent('destinationMunicipality', () => hotspot.municipality);
        
        _destinationData[markerId.value] = dataWithId;
        
        final marker = Marker(
          markerId: markerId,
          position: position,
          icon: customIcon,
          infoWindow: InfoWindow(title: name),
          onTap: () {
            onMarkerTap(dataWithId);
          },
        );

        markers.add(marker);
      }
    }
    
    _allMarkers = markers;
    return markers;
  }

  /// Normalize category names
  String _normalizeCategory(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return '';
    if (value.contains('adventure')) return 'Adventure Spot';
    if (value.contains('culture')) return 'Cultural Site';
    if (value.contains('natural')) return 'Natural Attraction';
    if (value.contains('museum')) return 'Cultural Site';
    if (value.contains('eco')) return 'Natural Attraction';
    if (value.contains('park')) return 'Natural Attraction';
    if (value.contains('restaurant') || value.contains('food')) return 'Restaurant';
    if (value.contains('accommodation') || value.contains('hotel')) return 'Accommodation';
    if (value.contains('shopping')) return 'Shopping';
    if (value.contains('entertain')) return 'Entertainment';
    return raw.trim();
  }

  /// Get category marker icon
  BitmapDescriptor? _getCategoryMarkerIcon(String category) {
    if (category.isEmpty) return null;
    final key = category.trim();
    if (_categoryMarkerIcons.containsKey(key)) return _categoryMarkerIcons[key];
    
    // Try fuzzy matching
    for (final entry in _categoryMarkerIcons.entries) {
      if (key.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return null;
  }

  /// Filter markers by search query
  Set<Marker> filterMarkersByQuery(String query) {
    if (query.isEmpty) return _allMarkers;
    
    return _allMarkers.where((marker) {
      final name = marker.infoWindow.title?.toLowerCase() ?? '';
      return name.contains(query.toLowerCase());
    }).toSet();
  }

  /// Get all markers
  Set<Marker> getAllMarkers() => _allMarkers;

  /// Get destination data by hotspot ID
  Map<String, dynamic>? getDestinationData(String hotspotId) {
    return _destinationData[hotspotId];
  }

  // In map_marker_manager.dart, inside the MapMarkerManager class

  /// Creates a custom user location marker bitmap, styled like the Google Maps dot.
  static Future<BitmapDescriptor> createLocationDotBitmap() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 100;
    const double radius = size / 2;

    final Paint ripplePaint = Paint()..color = const Color(0x334285F4)..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(radius, radius), radius, ripplePaint);

    final Paint dotPaint = Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(radius, radius), radius * 0.45, dotPaint);

    final Paint borderPaint = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = size * 0.05;
    canvas.drawCircle(const Offset(radius, radius), radius * 0.45, borderPaint);

    final img = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  /// Creates a custom user location chevron bitmap, styled like the Google Maps arrow.
  static Future<BitmapDescriptor> createLocationChevronBitmap() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 80;
    const double radius = size / 2;

    final Path path = Path();
    path.moveTo(radius, 0); // Top point
    path.lineTo(size, size); // Bottom-right
    path.lineTo(radius, radius * 0.85); // Center point
    path.lineTo(0, size); // Bottom-left
    path.close();

    canvas.drawShadow(path.shift(const Offset(0, 2)), Colors.black.withOpacity(0.5), 5.0, true);
    final Paint chevronPaint = Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill;
    canvas.drawPath(path, chevronPaint);

    final img = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }
}