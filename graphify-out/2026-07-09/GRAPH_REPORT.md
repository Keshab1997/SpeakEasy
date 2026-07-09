# Flutter-Spoken-English-App — Knowledge Graph Report

**Generated:** 2026-07-09

## Overview

| Metric | Value |
|--------|-------|
| Total Nodes | 5328 |
| Total Edges | 7395 |
| Communities Detected | 244 |
| Corpus Files | 546 |
| Corpus Words | ~753,122 |

## File Type Distribution

| Type | Count |
|------|-------|
| code | 5114 |
| concept | 116 |
| rationale | 60 |
| document | 37 |
| image | 1 |

## Token Cost

| Step | Input Tokens | Output Tokens |
|------|-------------|--------------|
| AST Extraction | 0 (free) | 0 (free) |
| Semantic Extraction | 17400 | 5200 |
| **Total** | **17400** | **5200** |

## Architecture Overview

This is a **Flutter/Dart Spoken English learning app** with **Clean Architecture** (Riverpod + Hive + Firebase). The graph contains 5328 nodes across 244 communities, representing the full codebase structure, documentation, and design concepts.

## Communities

The graph was partitioned into **244 communities** using the Louvain algorithm.

### Top 10 Communities by Size

### Community 1: admin_repository.dart
- **Size:** 346 nodes
- **Key nodes:**
  - `lib_providers_game_game_provider_gameprovider` (gameProvider) [code]
  - `lib_features_game_screens_result_screen` (result_screen.dart) [code]
  - `lib_features_game_screens_mode_game_screen` (mode_game_screen.dart) [code]
  - `lib_providers_game_sound_provider_soundserviceprovider` (soundServiceProvider) [code]
  - `lib_features_game_screens_tense_categories_screen` (tense_categories_screen.dart) [code]

### Community 2: story_completion_mode.dart
- **Size:** 282 nodes
- **Key nodes:**
  - `lib_core_widgets_game_widgets` (game_widgets.dart) [code]
  - `statelesswidget` (StatelessWidget) [code]
  - `lib_features_game_screens_home_screen` (home_screen.dart) [code]
  - `lib_features_game_screens_statistics_screen` (statistics_screen.dart) [code]
  - `lib_features_game_screens_game_home_screen` (game_home_screen.dart) [code]

### Community 3: coin_provider.dart
- **Size:** 277 nodes
- **Key nodes:**
  - `lib_services_statistics_service` (statistics_service.dart) [code]
  - `lib_providers_game_game_provider` (game_provider.dart) [code]
  - `lib_services_streak_service` (streak_service.dart) [code]
  - `lib_services_coin_service` (coin_service.dart) [code]
  - `lib_services_game_service` (game_service.dart) [code]

### Community 4: settings_screen.dart
- **Size:** 250 nodes
- **Key nodes:**
  - `lib_features_game_screens_modes_grammar_detective_mode` (grammar_detective_mode.dart) [code]
  - `lib_features_game_screens_modes_bangla_to_english_mode` (bangla_to_english_mode.dart) [code]
  - `lib_features_game_screens_modes_story_completion_mode` (story_completion_mode.dart) [code]
  - `lib_features_game_screens_modes_fill_in_blanks_mode` (fill_in_blanks_mode.dart) [code]
  - `lib_repositories_wrong_question_repository` (wrong_question_repository.dart) [code]

### Community 5: fill_in_blanks_mode.dart
- **Size:** 234 nodes
- **Key nodes:**
  - `lib_features_home_screens_home_screen` (home_screen.dart) [code]
  - `lib_features_home_widgets_study_plan_section` (study_plan_section.dart) [code]
  - `materialpageroute` (MaterialPageRoute) [code]
  - `lib_features_practice_screens_practice_screen` (practice_screen.dart) [code]
  - `lib_features_verb_forms_screens_verb_forms_screen` (verb_forms_screen.dart) [code]

### Community 6: achievement_provider.dart
- **Size:** 232 nodes
- **Key nodes:**
  - `lib_features_admin_screens_admin_content_screen` (admin_content_screen.dart) [code]
  - `lib_features_practice_screens_bangla_english_practice_screen` (bangla_english_practice_screen.dart) [code]
  - `lib_features_admin_screens_admin_feedback_screen` (admin_feedback_screen.dart) [code]
  - `state` (State) [code]
  - `statefulwidget` (StatefulWidget) [code]

### Community 7: ConsumerState
- **Size:** 211 nodes
- **Key nodes:**
  - `lib_features_grammar_screens_grammar_master_screen` (grammar_master_screen.dart) [code]
  - `lib_features_grammar_screens_grammar_detail_screen` (grammar_detail_screen.dart) [code]
  - `lib_models_grammar_chapter_model` (grammar_chapter_model.dart) [code]
  - `lib_features_grammar_screens_grammar_test_screen` (grammar_test_screen.dart) [code]
  - `lib_providers_grammar_provider` (grammar_provider.dart) [code]

### Community 8: sentence_analyzer_screen.dart
- **Size:** 202 nodes
- **Key nodes:**
  - `lib_providers_game_coin_provider` (coin_provider.dart) [code]
  - `lib_providers_todo_list_provider` (todo_list_provider.dart) [code]
  - `lib_providers_game_xp_provider` (xp_provider.dart) [code]
  - `lib_providers_auth_provider` (auth_provider.dart) [code]
  - `lib_repositories_mock_test_repository` (mock_test_repository.dart) [code]

### Community 9: statistics_repository.dart
- **Size:** 193 nodes
- **Key nodes:**
  - `lib_repositories_progress_repository` (progress_repository.dart) [code]
  - `lib_repositories_statistics_repository` (statistics_repository.dart) [code]
  - `lib_repositories_achievement_repository` (achievement_repository.dart) [code]
  - `lib_repositories_game_repository` (game_repository.dart) [code]
  - `lib_models_vocabulary_chapter_model` (vocabulary_chapter_model.dart) [code]

### Community 10: game_provider.dart
- **Size:** 184 nodes
- **Key nodes:**
  - `lib_features_settings_screens_settings_screen` (settings_screen.dart) [code]
  - `lib_routes_app_routes` (app_routes.dart) [code]
  - `lib_features_game_screens_settings_screen` (settings_screen.dart) [code]
  - `lib_providers_game_sound_provider` (sound_provider.dart) [code]
  - `lib_features_homework_screens_homework_history_screen` (homework_history_screen.dart) [code]

## Hub Nodes (Highest Degree)

These are the most connected nodes in the graph — key architectural touchpoints:

| Rank | Node ID | Label | Type | Degree |
|------|---------|-------|------|--------|
| 1 | `lib_features_home_screens_home_screen` | home_screen.dart | code | 186 |
| 2 | `lib_services_hive_service` | hive_service.dart | code | 144 |
| 3 | `statelesswidget` | StatelessWidget | code | 133 |
| 4 | `package_flutter_material_dart` | package:flutter/material.dart | code | 131 |
| 5 | `lib_features_ai_teacher_screens_ai_chat_screen` | ai_chat_screen.dart | code | 104 |
| 6 | `core_constants_app_colors_dart` | ../../core/constants/app_colors.dart | code | 94 |
| 7 | `package_flutter_riverpod_flutter_riverpod_dart` | package:flutter_riverpod/flutter_riverpod.dart | code | 93 |
| 8 | `lib_core_widgets_game_widgets` | game_widgets.dart | code | 90 |
| 9 | `lib_features_game_screens_modes_grammar_detective_mode` | grammar_detective_mode.dart | code | 79 |
| 10 | `list` | List | code | 74 |
| 11 | `lib_features_game_screens_modes_bangla_to_english_mode` | bangla_to_english_mode.dart | code | 74 |
| 12 | `lib_features_game_screens_modes_story_completion_mode` | story_completion_mode.dart | code | 72 |
| 13 | `lib_providers_game_achievement_provider` | achievement_provider.dart | code | 72 |
| 14 | `lib_features_game_screens_modes_verb_learning_mode` | verb_learning_mode.dart | code | 71 |
| 15 | `lib_features_game_screens_modes_fill_in_blanks_mode` | fill_in_blanks_mode.dart | code | 69 |
| 16 | `lib_features_game_screens_modes_flashcard_mode` | flashcard_mode.dart | code | 69 |
| 17 | `lib_features_game_screens_home_screen` | home_screen.dart | code | 66 |
| 18 | `lib_features_game_screens_modes_quick_quiz_mode` | quick_quiz_mode.dart | code | 66 |
| 19 | `lib_features_game_screens_result_screen` | result_screen.dart | code | 62 |
| 20 | `lib_features_settings_screens_settings_screen` | settings_screen.dart | code | 62 |

---

*Generated by graphify. Graph data available in `graphify-out/graph.json`.*
