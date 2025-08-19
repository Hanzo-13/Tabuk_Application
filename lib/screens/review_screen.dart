// ignore_for_file: use_build_context_synchronously

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:capstone_app/models/review_model.dart';
import 'package:capstone_app/services/review_service.dart';
import 'package:capstone_app/widgets/review_form_modal.dart';

class ReviewScreen extends StatefulWidget {
  final String businessId;
  final String businessName;

  const ReviewScreen({super.key, required this.businessId, required this.businessName,});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {

  Future<List<Review>> _fetchReviews() async {
    return await ReviewService.getBusinessReviews(widget.businessId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
              appBar: AppBar(title: Text('Reviews - ${widget.businessName}')),
      body: FutureBuilder<List<Review>>(
        future: _fetchReviews(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No reviews yet.'));
          }

          final reviews = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final review = reviews[index];
              final formattedDate = DateFormat.yMMMMd().format(review.datePosted);

              final isCurrentUserReview = review.userId == FirebaseAuth.instance.currentUser?.uid;
              
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: isCurrentUserReview ? Colors.blue[50] : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundImage: review.userPhotoUrl != null
                            ? NetworkImage(review.userPhotoUrl!)
                            : null,
                        child: review.userPhotoUrl == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  review.userName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (isCurrentUserReview) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'You',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _buildStarRating(review.rating),
                            const SizedBox(height: 6),
                            Text(
                              review.comment,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      if (isCurrentUserReview)
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') {
                              _showEditReviewForm(context, review);
                            } else if (value == 'delete') {
                              _showDeleteConfirmation(context, review);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 16),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 16),
                                  SizedBox(width: 8),
                                  Text('Delete'),
                                ],
                              ),
                            ),
                          ],
                          child: const Icon(Icons.more_vert, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddReviewForm(context),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddReviewForm(BuildContext context) async {
    final result = await ReviewFormModal.show(
      context: context,
      businessId: widget.businessId,
      businessName: widget.businessName,
      onReviewSubmitted: () {
        // Refresh the reviews
        setState(() {});
      },
    );
    
    // Return true to indicate a review was submitted
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  void _showEditReviewForm(BuildContext context, Review review) async {
    final result = await ReviewFormModal.show(
      context: context,
      businessId: widget.businessId,
      businessName: widget.businessName,
      existingReview: review,
      onReviewSubmitted: () {
        // Refresh the reviews
        setState(() {});
      },
    );
    
    // Return true to indicate a review was updated
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  void _showDeleteConfirmation(BuildContext context, Review review) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text('Are you sure you want to delete your review? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ReviewService.deleteReview(
                businessId: widget.businessId,
                reviewId: review.id,
              );
              
              if (mounted) {
                if (success) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Review deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete review'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildStarRating(double rating) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rating.round() ? Icons.star : Icons.star_border,
          size: 18,
          color: Colors.amber,
        );
      }),
    );
  }
}
