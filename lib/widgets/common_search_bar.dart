// lib/widgets/common_search_bar.dart

import 'package:flutter/material.dart';
import 'package:capstone_app/utils/colors.dart';

class UniversalSearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback? onFilterTap;
  final hintText;

  const UniversalSearchBar({
    super.key,
    required this.onChanged,
    required this.onClear,
    this.onFilterTap,
    this.hintText = 'Search Destinations...',
  });

  @override
  State<UniversalSearchBar> createState() => _UniversalSearchBarState();
}

class _UniversalSearchBarState extends State<UniversalSearchBar> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 16, 0),
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(30),
          child: TextField(
            controller: _searchController,
            onChanged: widget.onChanged,
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 16,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              prefixIcon: IconButton(
                icon: const Icon(Icons.search, color: AppColors.primaryTeal),
                onPressed: null,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        widget.onClear();
                        widget.onChanged('');
                      },
                    ),
                  // This now conditionally shows the filter button
                  if (widget.onFilterTap != null)
                    IconButton(
                      icon: const Icon(Icons.filter_list, color: AppColors.primaryTeal),
                      onPressed: widget.onFilterTap,
                    ),
                ],
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


  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}