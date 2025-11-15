// ===========================================
// lib/screens/tourist/trips/widgets/progress_statistics_view.dart
// ===========================================
// Progress and statistics view widget for trip adherence tracking

import 'package:flutter/material.dart';
import '../../../../models/trip_model.dart' as firestoretrip;
import '../../../../utils/colors.dart';
import '../constants/trip_constants.dart';
import '../utils/trip_helpers.dart';
import 'progress_stat_card.dart';
import 'save_method_card.dart';
import 'best_adherence_list.dart';

/// Progress statistics view showing trip adherence and analytics
class ProgressStatisticsView extends StatelessWidget {
  final List<firestoretrip.Trip> allTrips;

  const ProgressStatisticsView({
    super.key,
    required this.allTrips,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate statistics
    final activeTrips = allTrips
        .where((t) => t.status != TripConstants.archivedStatus)
        .toList();
    final completedTrips = allTrips
        .where((t) => t.status == TripConstants.archivedStatus)
        .toList();

    // Calculate overall adherence
    double overallAdherence = 0.0;
    int totalSpots = 0;
    int totalVisited = 0;
    int autoSavedCount = 0;
    int manualSavedCount = 0;

    for (final trip in allTrips) {
      totalSpots += trip.spots.length;
      totalVisited += trip.visitedSpots.length;
      if (trip.autoSaved) {
        autoSavedCount++;
      } else {
        manualSavedCount++;
      }
    }

    if (totalSpots > 0) {
      overallAdherence = totalVisited / totalSpots;
    }

    // Calculate average progress for active trips
    double avgActiveProgress = 0.0;
    if (activeTrips.isNotEmpty) {
      double sum = 0.0;
      for (final trip in activeTrips) {
        sum += getTripProgress(trip);
      }
      avgActiveProgress = sum / activeTrips.length;
    }

    // Calculate average progress for completed trips
    double avgCompletedProgress = 0.0;
    if (completedTrips.isNotEmpty) {
      double sum = 0.0;
      for (final trip in completedTrips) {
        sum += getTripProgress(trip);
      }
      avgCompletedProgress = sum / completedTrips.length;
    }

    // Get trips sorted by progress (best adherence first)
    final sortedByProgress = List<firestoretrip.Trip>.from(allTrips)
      ..sort((a, b) => getTripProgress(b).compareTo(getTripProgress(a)));

    // Empty state if no trips
    if (allTrips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.analytics_outlined,
                size: 64,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Progress Data Yet',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.textLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Start visiting places from your trips to see your progress here!\n\nThis shows how well you follow your travel plans.',
                style: TextStyle(
                  color: AppColors.textLight.withOpacity(0.8),
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Adherence Card
          _buildOverallAdherenceCard(
            overallAdherence,
            totalVisited,
            totalSpots,
            allTrips.length,
          ),
          const SizedBox(height: 20),
          // Progress Statistics Cards
          Row(
            children: [
              Expanded(
                child: ProgressStatCard(
                  title: 'Active Trips',
                  subtitle: 'In progress',
                  percentage: '${(avgActiveProgress * 100).toStringAsFixed(0)}%',
                  progress: avgActiveProgress,
                  count: activeTrips.length,
                  color: AppColors.primaryOrange,
                  icon: Icons.explore_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ProgressStatCard(
                  title: 'Completed Trips',
                  subtitle: 'Finished',
                  percentage: '${(avgCompletedProgress * 100).toStringAsFixed(0)}%',
                  progress: avgCompletedProgress,
                  count: completedTrips.length,
                  color: AppColors.primaryTeal,
                  icon: Icons.check_circle_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Save Method Statistics
          _buildSaveMethodSection(autoSavedCount, manualSavedCount, allTrips.length),
          const SizedBox(height: 20),
          // Best Adherence Trips
          if (sortedByProgress.isNotEmpty)
            BestAdherenceList(trips: sortedByProgress.take(3).toList()),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// Builds the overall adherence card
  Widget _buildOverallAdherenceCard(
    double adherence,
    int visited,
    int total,
    int tripCount,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryTeal,
            AppColors.primaryTeal.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryTeal.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall Progress',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(adherence * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'How well you follow your plans',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Places Visited',
                  '$visited / $total',
                  Icons.place_rounded,
                  Colors.white.withOpacity(0.9),
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.3),
              ),
              Expanded(
                child: _buildStatItem(
                  'Total Trips',
                  '$tripCount',
                  Icons.luggage_rounded,
                  Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds a stat item for the overall adherence card
  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// Builds the save method statistics section
  Widget _buildSaveMethodSection(int autoSaved, int manualSaved, int total) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.save_rounded,
                  color: AppColors.primaryTeal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Save Method',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'How your trips are saved',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SaveMethodCard(
                  label: 'Auto-Saved',
                  subtitle: 'Automatically',
                  count: autoSaved,
                  total: total,
                  color: AppColors.primaryTeal,
                  icon: Icons.cloud_done_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SaveMethodCard(
                  label: 'Manual Save',
                  subtitle: 'Saved by you',
                  count: manualSaved,
                  total: total,
                  color: AppColors.primaryOrange,
                  icon: Icons.save_alt_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

