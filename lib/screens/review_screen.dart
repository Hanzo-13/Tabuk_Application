import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReviewScreen extends StatelessWidget {
  final String businessId;
  final String businessName;

  const ReviewScreen({super.key, required this.businessId, required this.businessName,});

  Future<List<Map<String, dynamic>>> _fetchReviews() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('destination')
            .doc(businessId)
            .collection('reviews')
            .orderBy('date_posted', descending: true)
            .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reviews - $businessName')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
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
              final date = (review['date_posted'] as Timestamp?)?.toDate();
              final formattedDate =
                  date != null
                      ? DateFormat.yMMMMd().format(date)
                      : 'Unknown date';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundImage:
                            review['user_photo_url'] != null
                                ? NetworkImage(review['user_photo_url'])
                                : null,
                        child:
                            review['user_photo_url'] == null
                                ? const Icon(Icons.person)
                                : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              review['user_name'] ?? 'Anonymous',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _buildStarRating(review['rating'] ?? 0),
                            const SizedBox(height: 6),
                            Text(
                              review['comment'] ?? '',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
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
