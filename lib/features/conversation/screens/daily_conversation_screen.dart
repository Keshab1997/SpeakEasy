import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class DailyConversationScreen extends StatefulWidget {
  const DailyConversationScreen({super.key});

  @override
  State<DailyConversationScreen> createState() => _DailyConversationScreenState();
}

class _DailyConversationScreenState extends State<DailyConversationScreen> {
  int _selectedScenario = 0;

  final scenarios = [
    {
      'title': 'Greeting & Introduction',
      'emoji': '👋',
      'dialogues': [
        {'speaker': 'A', 'en': 'Hello! Good morning.', 'bn': 'হ্যালো! সুপ্রভাত।'},
        {'speaker': 'B', 'en': 'Good morning! How are you?', 'bn': 'সুপ্রভাত! আপনি কেমন আছেন?'},
        {'speaker': 'A', 'en': 'I am fine, thank you. And you?', 'bn': 'আমি ভালো আছি, ধন্যবাদ। আর আপনি?'},
        {'speaker': 'B', 'en': 'I am also fine. My name is John.', 'bn': 'আমিও ভালো আছি। আমার নাম জন।'},
        {'speaker': 'A', 'en': 'Nice to meet you, John.', 'bn': 'আপনার সাথে দেখা করে ভালো লাগলো, জন।'},
        {'speaker': 'B', 'en': 'Nice to meet you too.', 'bn': 'আমারও ভালো লাগলো।'},
      ],
    },
    {
      'title': 'Shopping',
      'emoji': '🛍️',
      'dialogues': [
        {'speaker': 'A', 'en': 'How much does this cost?', 'bn': 'এটার দাম কত?'},
        {'speaker': 'B', 'en': 'It is 500 Taka.', 'bn': 'এটা ৫০০ টাকা।'},
        {'speaker': 'A', 'en': 'Can you give me a discount?', 'bn': 'আপনি কি একটু কম দিতে পারবেন?'},
        {'speaker': 'B', 'en': 'Sorry, the price is fixed.', 'bn': 'দুঃখিত, দাম নির্ধারিত।'},
        {'speaker': 'A', 'en': 'Okay, I will take it.', 'bn': 'ঠিক আছে, আমি নেব।'},
      ],
    },
    {
      'title': 'At a Restaurant',
      'emoji': '🍽️',
      'dialogues': [
        {'speaker': 'A', 'en': 'Can I see the menu, please?', 'bn': 'আমি কি মেনু দেখতে পারি?'},
        {'speaker': 'B', 'en': 'Sure, here it is.', 'bn': 'নিশ্চয়ই, এই নিন।'},
        {'speaker': 'A', 'en': 'I would like to order biryani.', 'bn': 'আমি বিরিয়ানি অর্ডার করতে চাই।'},
        {'speaker': 'B', 'en': 'Would you like anything to drink?', 'bn': 'পানীয় কিছু চান?'},
        {'speaker': 'A', 'en': 'Yes, a glass of water, please.', 'bn': 'হ্যাঁ, এক গ্লাস পানি দয়া করে।'},
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scenario = scenarios[_selectedScenario];
    final dialogues = scenario['dialogues'] as List<Map<String, String>>;

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Conversation', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: scenarios.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedScenario == index;
                final sc = scenarios[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: Text(sc['emoji'] as String),
                    label: Text(sc['title'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    onPressed: () => setState(() => _selectedScenario = index),
                    backgroundColor: isSelected ? AppColors.primary : null,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : null, fontSize: 12),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: dialogues.length,
              itemBuilder: (context, index) {
                final d = dialogues[index];
                final isSpeakerA = d['speaker'] == 'A';
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSpeakerA
                        ? (isDark ? AppColors.surfaceDark : AppColors.surfaceLight)
                        : AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomRight: Radius.circular(isSpeakerA ? 16 : 4),
                      bottomLeft: Radius.circular(isSpeakerA ? 4 : 16),
                    ),
                    border: Border.all(
                      color: isSpeakerA
                          ? (isDark ? AppColors.borderDark : AppColors.borderLight)
                          : AppColors.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Person ${d['speaker']}',
                        style: TextStyle(
                          color: isSpeakerA ? (isDark ? Colors.white60 : Colors.black45) : AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        d['en']!,
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        d['bn']!,
                        style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
