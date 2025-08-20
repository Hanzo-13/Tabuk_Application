// lib/widgets/common_search_bar.dart

import 'package:flutter/material.dart';

class UniversalSearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onFilterTap;

  const UniversalSearchBar({
    super.key,
    required this.onChanged,
    required this.onClear,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(30),
          child: TextField(
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: 'Search',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              prefixIcon: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: onFilterTap, // 👈 Opens filter modal/sheet
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: onClear,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}