// ===========================================
// lib/screens/tourist/trips/widgets/trip_card.dart
// ===========================================
// Reusable trip card widget for displaying trip information

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/trip_model.dart' as firestoretrip;
import '../../../../utils/colors.dart';
import '../../../../screens/tourist/trips/trip_detailScreen.dart';
import '../utils/trip_helpers.dart';

/// Reusable trip card widget
class TripCard extends StatelessWidget {
  final firestoretrip.Trip trip;
  final bool isArchived;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onRestore;
  final VoidCallback? onDelete;

  const TripCard({
    super.key,
    required this.trip,
    required this.isArchived,
    this.onEdit,
    this.onArchive,
    this.onRestore,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final daysUntil = getDaysUntilTrip(trip.startDate);
    final duration = getTripDuration(trip.startDate, trip.endDate);
    final progress = getTripProgress(trip);
    final progressPercentage = (progress * 100).toInt();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TripDetailsScreen(trip: trip),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTeal.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.location_on,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  getTransportationIcon(trip.transportation),
                                  size: 16,
                                  color: AppColors.textLight,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  trip.transportation,
                                  style: TextStyle(
                                    color: AppColors.textLight,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: getStatusColor(trip.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          trip.status,
                          style: TextStyle(
                            color: getStatusColor(trip.status),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${DateFormat('MMM dd').format(trip.startDate)} - ${DateFormat('MMM dd, yyyy').format(trip.endDate)}',
                        style: TextStyle(color: AppColors.textLight),
                      ),
                      const Spacer(),
                      if (!isArchived && daysUntil >= 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: getUrgencyColor(daysUntil).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            daysUntil == 0
                                ? 'Today!'
                                : daysUntil == 1
                                ? 'Tomorrow'
                                : '$daysUntil days to go',
                            style: TextStyle(
                              color: getUrgencyColor(daysUntil),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$duration day${duration != 1 ? 's' : ''}',
                        style: TextStyle(color: AppColors.textLight),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.place,
                        size: 16,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${trip.spots.length} spot${trip.spots.length != 1 ? 's' : ''}',
                        style: TextStyle(color: AppColors.textLight),
                      ),
                    ],
                  ),
                  if (trip.spots.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    // Enhanced Progress Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            getProgressColor(progress).withOpacity(0.1),
                            getProgressColor(progress).withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: getProgressColor(progress).withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: getProgressColor(progress).withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: getProgressColor(progress)
                                            .withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        progress == 1.0
                                            ? Icons.check_circle_rounded
                                            : progress > 0
                                                ? Icons.trending_up_rounded
                                                : Icons.route_rounded,
                                        size: 20,
                                        color: getProgressColor(progress),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            progress == 1.0
                                                ? 'Trip Completed! 🎉'
                                                : 'Trip Progress',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: getProgressColor(progress),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                          if (progress > 0 && progress < 1.0)
                                            Text(
                                              'Keep going!',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textLight,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: getProgressColor(progress)
                                      .withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$progressPercentage%',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: getProgressColor(progress),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Prominent Progress Bar
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: progress),
                                  duration: const Duration(milliseconds: 800),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, child) {
                                    return Container(
                                      height: 20,
                                      width: MediaQuery.of(context).size.width *
                                          value *
                                          0.8,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            getProgressColor(progress),
                                            getProgressColor(progress)
                                                .withOpacity(0.8),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: getProgressColor(progress)
                                                .withOpacity(0.4),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              // Progress text overlay
                              Positioned.fill(
                                child: Center(
                                  child: Text(
                                    '${trip.visitedSpots.length} of ${trip.spots.length} spots visited',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: progress > 0.5
                                          ? Colors.white
                                          : AppColors.textDark,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!isArchived) ...[
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: onEdit,
                          tooltip: 'Edit Trip',
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.homeForYouColor
                                .withOpacity(0.1),
                            foregroundColor: AppColors.homeForYouColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.archive_outlined),
                          onPressed: onArchive,
                          tooltip: 'Complete Trip',
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primaryOrange
                                .withOpacity(0.1),
                            foregroundColor: AppColors.primaryOrange,
                          ),
                        ),
                      ] else ...[
                        IconButton(
                          icon: const Icon(Icons.restore_outlined),
                          onPressed: onRestore,
                          tooltip: 'Restore Trip',
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.homeNearbyColor
                                .withOpacity(0.1),
                            foregroundColor: AppColors.homeNearbyColor,
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: onDelete,
                        tooltip: 'Delete Trip',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.errorRed.withOpacity(0.1),
                          foregroundColor: AppColors.errorRed,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

