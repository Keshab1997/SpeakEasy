import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class PrepositionScreen extends StatefulWidget {
  const PrepositionScreen({super.key});

  @override
  State<PrepositionScreen> createState() => _PrepositionScreenState();
}

class _PrepositionScreenState extends State<PrepositionScreen> {
  int _selectedIndex = 0;

  final categories = [
    {
      'title': 'Place (স্থান)',
      'icon': Icons.place_rounded,
      'items': [
        {'prep': 'In', 'meaning': 'ভিতরে', 'example': 'The book is in the bag.'},
        {'prep': 'On', 'meaning': 'উপরে', 'example': 'The cat is on the table.'},
        {'prep': 'At', 'meaning': 'এ/তে', 'example': 'I am at the station.'},
        {'prep': 'Under', 'meaning': 'নিচে', 'example': 'The ball is under the chair.'},
        {'prep': 'Between', 'meaning': 'মাঝে', 'example': 'She sits between them.'},
        {'prep': 'Next to', 'meaning': 'পাশে', 'example': 'My house is next to the park.'},
      ],
    },
    {
      'title': 'Time (সময়)',
      'icon': Icons.access_time_rounded,
      'items': [
        {'prep': 'At', 'meaning': 'এ (সময়)', 'example': 'I wake up at 6 AM.'},
        {'prep': 'In', 'meaning': 'মধ্যে', 'example': 'I will go in the morning.'},
        {'prep': 'On', 'meaning': 'এ (দিন)', 'example': 'We meet on Monday.'},
        {'prep': 'Before', 'meaning': 'আগে', 'example': 'Finish before 5 PM.'},
        {'prep': 'After', 'meaning': 'পরে', 'example': 'We eat after the class.'},
        {'prep': 'During', 'meaning': 'সময়', 'example': 'He slept during the movie.'},
      ],
    },
    {
      'title': 'Movement (গতি)',
      'icon': Icons.directions_run_rounded,
      'items': [
        {'prep': 'To', 'meaning': 'দিকে', 'example': 'Go to the market.'},
        {'prep': 'From', 'meaning': 'থেকে', 'example': 'I come from Dhaka.'},
        {'prep': 'Into', 'meaning': 'ভিতরে', 'example': 'She jumped into the pool.'},
        {'prep': 'Onto', 'meaning': 'উপরে', 'example': 'He climbed onto the roof.'},
        {'prep': 'Through', 'meaning': 'মাধ্যমে', 'example': 'Walk through the door.'},
        {'prep': 'Across', 'meaning': 'পার', 'example': 'Run across the road.'},
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final category = categories[_selectedIndex];

    return Scaffold(
      appBar: AppBar(title: const Text('Prepositions', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedIndex == index;
                final cat = categories[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cat['icon'] as IconData, size: 18, color: isSelected ? Colors.white : null),
                        const SizedBox(width: 6),
                        Text(cat['title'] as String),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedIndex = index),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : null, fontWeight: FontWeight.w600),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: (category['items'] as List).length,
              itemBuilder: (context, index) {
                final item = (category['items'] as List)[index] as Map<String, dynamic>;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            item['prep'] as String,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item['meaning'] as String} - ${item['prep'] as String}',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['example'] as String,
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: isDark ? Colors.white60 : Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
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
