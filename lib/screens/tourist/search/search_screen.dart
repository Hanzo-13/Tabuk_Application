// // ===========================================
// // lib/screens/tourist_module/search/search_screen.dart
// // ===========================================
// // Screen for searching hotspots with filters.

// import 'package:flutter/material.dart';
// import 'package:capstone_app/services/recommender_system.dart';
// import 'package:capstone_app/models/destination_model.dart';
// import '../../../utils/constants.dart';
// import '../../../utils/colors.dart';

// /// Screen for searching hotspots with filters.
// class SearchScreen extends StatefulWidget {
//   const SearchScreen({super.key});

//   @override
//   State<SearchScreen> createState() => _SearchScreenState();
// }

// class _SearchScreenState extends State<SearchScreen> {
//   final TextEditingController _searchController = TextEditingController();
//   final Set<String> _selectedDistricts = {};
//   final Set<String> _selectedMunicipalities = {};
//   final Set<String> _selectedCategories = {};
//   List<Hotspot> _results = [];
//   bool _isLoading = false;

//   static const List<String> _districts = AppConstants.districts;
//   static const List<String> _municipalities = AppConstants.municipalities;
//   static const List<String> _categories = AppConstants.hotspotCategories;

//   /// Handles the search logic, using the recommender system.
//   // void _onSearch() async {
//   //   setState(() => _isLoading = true);
//   //   final query = _searchController.text.trim();
//   //   // final results = await SimpleRecommenderService.searchHotspots(
//   //   //   query,
//   //   //   districts: _selectedDistricts.toList(),
//   //   //   municipalities: _selectedMunicipalities.toList(),
//   //   //   categories: _selectedCategories.toList(),
//   //   // );
//   //   setState(() {
//   //     _results = results;
//   //     _isLoading = false;
//   //   });
//   // }

//   Widget _buildFilterChips(List<String> options, Set<String> selected, void Function(String) onTap) {
//     return Wrap(
//       spacing: AppConstants.searchChipSpacing,
//       runSpacing: AppConstants.searchChipSpacing,
//       children: options.map((option) {
//         final isSelected = selected.contains(option);
//         return FilterChip(
//           label: Text(option),
//           selected: isSelected,
//           onSelected: (_) {
//             setState(() {
//               if (isSelected) {
//                 selected.remove(option);
//               } else {
//                 selected.add(option);
//               }
//             });
//           },
//         );
//       }).toList(),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: TextField(
//           controller: _searchController,
//           decoration: const InputDecoration(
//             hintText: AppConstants.searchHint,
//             border: InputBorder.none,
//           ),
//           onSubmitted: (_) => _onSearch(),
//         ),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.cancel),
//             onPressed: () {
//               _searchController.clear();
//               setState(() => _results = []);
//             },
//             tooltip: AppConstants.clearSearch,
//           ),
//         ],
//         backgroundColor: AppColors.backgroundColor,
//         iconTheme: const IconThemeData(color: AppColors.textDark),
//         elevation: 0,
//       ),
//       body: ListView(
//         padding: const EdgeInsets.all(AppConstants.searchScreenPadding),
//         children: [
//           const Text(AppConstants.searchFiltersTitle, style: TextStyle(fontSize: AppConstants.searchSectionTitleFontSize, fontWeight: FontWeight.bold)),
//           const SizedBox(height: AppConstants.searchSectionSpacing),
//           const Text(AppConstants.searchDistrictsTitle, style: TextStyle(fontWeight: FontWeight.bold)),
//           _buildFilterChips(_districts, _selectedDistricts, (v) {}),
//           const SizedBox(height: AppConstants.searchSectionSpacing),
//           const Text(AppConstants.searchMunicipalitiesTitle, style: TextStyle(fontWeight: FontWeight.bold)),
//           _buildFilterChips(_municipalities, _selectedMunicipalities, (v) {}),
//           const SizedBox(height: AppConstants.searchSectionSpacing),
//           const Text(AppConstants.searchCategoriesTitle, style: TextStyle(fontWeight: FontWeight.bold)),
//           _buildFilterChips(_categories, _selectedCategories, (v) {}),
//           const SizedBox(height: AppConstants.searchSectionSpacing),
//           ElevatedButton(
//             onPressed: _onSearch,
//             child: const Text(AppConstants.searchButton),
//           ),
//           const SizedBox(height: AppConstants.searchResultsSpacing),
//           const Text(AppConstants.searchResultsTitle, style: TextStyle(fontSize: AppConstants.searchSectionTitleFontSize, fontWeight: FontWeight.bold)),
//           const SizedBox(height: AppConstants.searchSectionSpacing),
//           if (_isLoading)
//             const Center(child: CircularProgressIndicator()),
//           if (!_isLoading && _results.isEmpty)
//             const Text(AppConstants.searchNoResults),
//           if (!_isLoading && _results.isNotEmpty)
//             ..._results.map((hotspot) => Card(
//                   child: ListTile(
//                     title: Text(hotspot.name),
//                     subtitle: Text(hotspot.description),
//                   ),
//                 )),
//         ],
//       ),
//     );
//   }
// }
