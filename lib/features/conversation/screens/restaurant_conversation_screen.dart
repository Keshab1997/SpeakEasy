import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class RestaurantConversationScreen extends StatelessWidget {
  const RestaurantConversationScreen({super.key});

  final List<Map<String, String>> dialogues = const [
    {'speaker': 'Customer', 'en': 'Excuse me, can I have a table for two?', 'bn': ' excuse me, কি আমি দুজনের জন্য একটি টেবিল পেতে পারি?'},
    {'speaker': 'Waiter', 'en': 'Yes, please follow me.', 'bn': 'হ্যাঁ, দয়া করে আমাকে অনুসরণ করুন।'},
    {'speaker': 'Waiter', 'en': 'Here is your menu. What would you like to order?', 'bn': 'এই নিন আপনার মেনু। আপনি কী অর্ডার করতে চান?'},
    {'speaker': 'Customer', 'en': 'I would like the grilled chicken with rice.', 'bn': 'আমি গ্রিলড চিকেন সাথে ভাত খেতে চাই।'},
    {'speaker': 'Waiter', 'en': 'Would you like any appetizer?', 'bn': 'আপনি কি কোনো ক্ষুধাবর্ধক চান?'},
    {'speaker': 'Customer', 'en': 'Yes, spring rolls please.', 'bn': 'হ্যাঁ, স্প্রিং রোলস দয়া করে।'},
    {'speaker': 'Waiter', 'en': 'What would you like to drink?', 'bn': 'আপনি কী পান করতে চান?'},
    {'speaker': 'Customer', 'en': 'A glass of lemonade, please.', 'bn': 'এক গ্লাস লেমোনেড, দয়া করে।'},
    {'speaker': 'Waiter', 'en': 'Great. I will bring your order shortly.', 'bn': 'চমৎকার। আমি খুব শীঘ্রই আপনার অর্ডার নিয়ে আসছি।'},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Restaurant Conversation', style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: dialogues.length,
        itemBuilder: (context, index) {
          final d = dialogues[index];
          final isCustomer = d['speaker'] == 'Customer';
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isCustomer
                  ? (isDark ? AppColors.surfaceDark : AppColors.surfaceLight)
                  : AppColors.secondary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isCustomer ? 16 : 4),
                bottomRight: Radius.circular(isCustomer ? 4 : 16),
              ),
              border: Border.all(
                color: isCustomer
                    ? (isDark ? AppColors.borderDark : AppColors.borderLight)
                    : AppColors.secondary.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d['speaker']!,
                  style: TextStyle(
                    color: isCustomer ? Colors.grey : AppColors.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(d['en']!, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(d['bn']!, style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13)),
              ],
            ),
          );
        },
      ),
    );
  }
}
