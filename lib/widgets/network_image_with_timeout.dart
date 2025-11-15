import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'dart:async';

/// A network image widget with timeout handling and error fallback
/// This prevents connection timeout errors from breaking the UI
class NetworkImageWithTimeout extends StatefulWidget {
  final String imageUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Duration timeout;
  final Widget? placeholder;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final Color? placeholderColor;

  const NetworkImageWithTimeout({
    super.key,
    required this.imageUrl,
    this.fit,
    this.width,
    this.height,
    this.timeout = const Duration(seconds: 10),
    this.placeholder,
    this.errorBuilder,
    this.placeholderColor,
  });

  @override
  State<NetworkImageWithTimeout> createState() => _NetworkImageWithTimeoutState();
}

class _NetworkImageWithTimeoutState extends State<NetworkImageWithTimeout> {
  bool _hasError = false;
  bool _isLoading = true;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    // Set a timeout to prevent indefinite loading
    _timeoutTimer = Timer(widget.timeout, () {
      if (mounted && _isLoading) {
        if (kDebugMode) {
          debugPrint('Image load timeout for: ${widget.imageUrl}');
        }
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  Widget _buildPlaceholder() {
    if (widget.placeholder != null) {
      return widget.placeholder!;
    }
    return Container(
      width: widget.width,
      height: widget.height,
      color: widget.placeholderColor ?? Colors.grey[300],
      child: Icon(
        Icons.image,
        size: (widget.height ?? 100) * 0.3,
        color: Colors.grey[600],
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, Object error, StackTrace? stackTrace) {
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(context, error, stackTrace);
    }
    return Container(
      width: widget.width,
      height: widget.height,
      color: widget.placeholderColor ?? Colors.grey[300],
      child: Icon(
        Icons.broken_image,
        size: (widget.height ?? 100) * 0.3,
        color: Colors.grey[600],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorWidget(context, 'Connection timeout', null);
    }

    return Image.network(
      widget.imageUrl,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          // Image loaded successfully
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _timeoutTimer?.cancel();
              });
            }
          });
          return child;
        }
        // Still loading - show placeholder
        return widget.placeholder ?? _buildPlaceholder();
      },
      errorBuilder: (context, error, stackTrace) {
        if (kDebugMode) {
          debugPrint('Image load error for ${widget.imageUrl}: $error');
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _hasError = true;
              _isLoading = false;
              _timeoutTimer?.cancel();
            });
          }
        });
        return _buildErrorWidget(context, error, stackTrace);
      },
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          // Image is ready
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _timeoutTimer?.cancel();
              });
            }
          });
          return child;
        }
        // Frame not ready yet - show placeholder
        return widget.placeholder ?? _buildPlaceholder();
      },
    );
  }
}

