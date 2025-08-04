// lib/widgets/custom_map_marker.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:capstone_app/utils/colors.dart';

/// Generates a custom [BitmapDescriptor] marker icon with a text label.
class CustomMapMarker {
  /// Create a custom marker with the given [label] and [color].
  static Future<BitmapDescriptor> createTextMarker({
    required String label,
    Color color = AppColors.primaryTeal,
    double fontSize = 20,
  }) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      // textAlign: TextAlign.center,
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: fontSize,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    )..layout();

    // final double markerWidth = 160;
    // final double markerHeight = 60;

    // final recorder = ui.PictureRecorder();
    // final canvas = Canvas(
    //   recorder,
    //   Rect.fromLTWH(0, 0, markerWidth, markerHeight),
    // );

    // final Paint paint = Paint()..color = color;
    // final RRect rrect = RRect.fromRectAndRadius(
    //   Rect.fromLTWH(0, 0, markerWidth, markerHeight),
    //   const Radius.circular(12),
    // );
    // canvas.drawRRect(rrect, paint);

    // textPainter.text = TextSpan(
    //   text: label,
    //   style: const TextStyle(
    //     color: Colors.white,
    //     fontSize: 18,
    //     fontWeight: FontWeight.bold,
    //   ),
    // );
    // textPainter.layout(minWidth: 0, maxWidth: markerWidth);
    // final double xCenter = (markerWidth - textPainter.width) / 2;
    // final double yCenter = (markerHeight - textPainter.height) / 2;
    // textPainter.paint(canvas, Offset(xCenter, yCenter));

    // final picture = recorder.endRecording();
    // final image = await picture.toImage(
    //   markerWidth.toInt(),
    //   markerHeight.toInt(),
    // );
    // final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    // return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());

    final width = textPainter.width + 20;
    final height = textPainter.height + 20;

    final paint = Paint()..color = color;
    final rrect = RRect.fromLTRBR(0, 0, width, height, Radius.circular(12));
    canvas.drawRRect(rrect, paint);

    textPainter.paint(canvas, Offset(10, 10));

    final image = await pictureRecorder.endRecording().toImage(width.toInt(), height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }
}
