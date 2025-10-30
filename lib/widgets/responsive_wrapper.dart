import 'package:flutter/material.dart';

class ResponsiveWrapper extends StatelessWidget {
  final Widget? child;
  const ResponsiveWrapper({super.key, required this.child});

  // Padding helper left intact for future use on specific pages if needed.

  @override
  Widget build(BuildContext context) {
    // Full-bleed content to avoid white margins for maps and large layouts on web/desktop.
    // If you want constrained content for specific pages, wrap those pages manually.
    return ScrollConfiguration(
      behavior: const _NoGlowScrollBehavior(),
      child: child ?? const SizedBox.shrink(),
    );
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}



