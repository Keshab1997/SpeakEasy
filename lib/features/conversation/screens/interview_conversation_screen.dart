import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class InterviewConversationScreen extends StatelessWidget {
  const InterviewConversationScreen({super.key});

  final List<Map<String, String>> dialogues = const [
    {'speaker': 'Interviewer', 'en': 'Good morning. Please introduce yourself.', 'bn': 'সুপ্রভাত। দয়া করে নিজের পরিচয় দিন।'},
    {'speaker': 'Candidate', 'en': 'Good morning. I am Robin, a graduate in Computer Science.', 'bn': 'সুপ্রভাত। আমি রবিন, কম্পিউটার সায়েন্সে গ্র্যাজুয়েট।'},
    {'speaker': 'Interviewer', 'en': 'What are your strengths?', 'bn': 'আপনার শক্তিগুলো কী কী?'},
    {'speaker': 'Candidate', 'en': 'I am hardworking, punctual, and a quick learner.', 'bn': 'আমি পরিশ্রমী, সময়নিষ্ঠ এবং দ্রুত শিক্ষানবিশ।'},
    {'speaker': 'Interviewer', 'en': 'Why do you want to work here?', 'bn': 'আপনি কেন এখানে কাজ করতে চান?'},
    {'speaker': 'Candidate', 'en': 'I admire your company\'s vision and growth.', 'bn': 'আমি আপনার কোম্পানির দৃষ্টিভঙ্গি এবং উন্নতির প্রশংসা করি।'},
    {'speaker': 'Interviewer', 'en': 'Where do you see yourself in 5 years?', 'bn': 'আপনি ৫ বছরে নিজেকে কোথায় দেখতে চান?'},
    {'speaker': 'Candidate', 'en': 'I want to grow as a professional and contribute to the team.', 'bn': 'আমি একজন পেশাদার হিসেবে বাড়তে চাই এবং দলে অবদান রাখতে চাই।'},
    {'speaker': 'Interviewer', 'en': 'Thank you. We will let you know.', 'bn': 'ধন্যবাদ। আমরা আপনাকে জানাব।'},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Interview Conversation', style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: dialogues.length,
        itemBuilder: (context, index) {
          final d = dialogues[index];
          final isInterviewer = d['speaker'] == 'Interviewer';
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isInterviewer
                  ? AppColors.primary.withValues(alpha: 0.05)
                  : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isInterviewer ? 4 : 16),
                bottomRight: Radius.circular(isInterviewer ? 16 : 4),
              ),
              border: Border.all(
                color: isInterviewer
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : (isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d['speaker']!,
                  style: TextStyle(
                    color: isInterviewer ? AppColors.primary : Colors.grey,
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
