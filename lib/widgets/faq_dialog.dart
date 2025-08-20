import 'package:flutter/material.dart';
import 'package:capstone_app/utils/colors.dart';

class FAQDialog extends StatefulWidget {
  const FAQDialog({super.key});

  @override
  State<FAQDialog> createState() => _FAQDialogState();
}

class _FAQDialogState extends State<FAQDialog> {
  final List<FAQItem> faqItems = [
    FAQItem(
      question: "How do I add a destination to my favorites?",
      answer: "To add a destination to your favorites, simply tap the heart icon on any tourist spot or business listing. The heart will turn red to indicate it's been added to your favorites list.",
    ),
    FAQItem(
      question: "How can I view my visited destinations?",
      answer: "You can view all your visited destinations by tapping on 'Visited Destinations' in your profile. This shows all the places you've checked into during your travels.",
    ),
    FAQItem(
      question: "What information do I need to create an account?",
      answer: "To create an account, you'll need your full name, email address, and a password. You can also optionally add a profile photo to personalize your account.",
    ),
    FAQItem(
      question: "How do I edit my profile information?",
      answer: "Tap on 'Edit Profile Information' in your profile screen to modify your personal details, including your name, email, and profile photo.",
    ),
    FAQItem(
      question: "Can I use the app without creating an account?",
      answer: "Yes, you can explore the app in guest mode, but you'll need to create an account to save favorites, track visited destinations, and access all features.",
    ),
    FAQItem(
      question: "How do I remove a destination from my favorites?",
      answer: "To remove a destination from your favorites, go to your favorites list and tap the 'Remove' button on any item. The destination will be immediately removed from your list.",
    ),
    FAQItem(
      question: "What should I do if I encounter an error?",
      answer: "If you encounter any issues, try refreshing the app or logging out and back in. For persistent problems, please contact our support team.",
    ),
    FAQItem(
      question: "How do I log out of my account?",
      answer: "To log out, simply tap the 'Log Out' button at the bottom of your profile screen. You'll be redirected to the login screen.",
    ),
    FAQItem(
    question: "Does this map apply to all provinces in Mindanao?",
    answer: "Currently, the map is specific to Bukidnon province. However, we plan to expand coverage to other provinces in Mindanao in the future.",
  ),
  ];

  int? expandedIndex;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 8,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: AppColors.backgroundGradient,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.help_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Frequently Asked Questions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // FAQ Content
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: ListView.builder(
                  itemCount: faqItems.length,
                  itemBuilder: (context, index) {
                    final item = faqItems[index];
                    final isExpanded = expandedIndex == index;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ExpansionTile(
                        initiallyExpanded: isExpanded,
                        onExpansionChanged: (expanded) {
                          setState(() {
                            expandedIndex = expanded ? index : null;
                          });
                        },
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primaryTeal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.help_outline,
                            color: AppColors.primaryTeal,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          item.question,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: AppColors.textDark,
                          ),
                        ),
                        trailing: Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: AppColors.primaryTeal,
                        ),
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.white.withOpacity(0.7),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                            ),
                            child: Text(
                              item.answer,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textLight,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white.withOpacity(0.8),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.primaryTeal,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Still have questions? Contact our support team.',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 12,
                      ),
                    ),
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

class FAQItem {
  final String question;
  final String answer;

  FAQItem({
    required this.question,
    required this.answer,
  });
}
