import 'package:flutter/material.dart';
import 'package:capstone_app/utils/colors.dart';

class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  final List<Map<String, String>> faqItems = [
    {
      'question': 'How do I create an account?',
      'answer': 'To create an account, tap on "Sign Up" on the login screen and fill in your details including email, password, and personal information.'
    },
    {
      'question': 'How do I add places to my favorites?',
      'answer': 'When viewing a destination, tap the heart icon to add it to your favorites. You can view all your favorites in the Profile section.'
    },
    {
      'question': 'How do I write a review?',
      'answer': 'Visit a destination page and scroll down to find the "Write a Review" section. Rate the place and add your comments.'
    },
    {
      'question': 'Can I edit my profile information?',
      'answer': 'Yes, go to your Profile and tap "Edit Profile Information" to update your details including name, photo, and contact information.'
    },
    {
      'question': 'How do I view my visited destinations?',
      'answer': 'Go to Profile > Visited Destinations to see a list of all places you\'ve been to during your trips.'
    },
    {
      'question': 'What should I do if I forget my password?',
      'answer': 'On the login screen, tap "Forgot Password" and enter your email. You\'ll receive instructions to reset your password.'
    },
    {
      'question': 'How do I delete my account?',
      'answer': 'Currently, account deletion must be requested through customer support. Contact us for assistance with account deletion.'
    },
    {
      'question': 'Can I use the app without creating an account?',
      'answer': 'Yes, you can browse destinations as a guest, but you won\'t be able to save favorites, write reviews, or access personalized features.'
    },
    {
      'question': 'Does this map apply to all provinces in mindanao?',
      'answer': 'Currently, the map is specific to Bukidnon province. However, we are working on expanding it to other provinces in Mindanao in the future.'
    },
    
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text(
          'Frequently Asked Questions',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primaryTeal,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: faqItems.length,
        itemBuilder: (context, index) {
          final item = faqItems[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            child: ExpansionTile(
              title: Text(
                item['question']!,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryTeal.withOpacity(0.1),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: AppColors.primaryTeal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              childrenPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item['answer']!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}