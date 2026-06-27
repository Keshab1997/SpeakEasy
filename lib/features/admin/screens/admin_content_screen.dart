import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class AdminContentScreen extends StatefulWidget {
  const AdminContentScreen({super.key});

  @override
  State<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends State<AdminContentScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Management'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
          tabs: const [
            Tab(icon: Icon(Icons.book_rounded), text: 'Vocabulary'),
            Tab(icon: Icon(Icons.text_snippet_rounded), text: 'Grammar'),
            Tab(icon: Icon(Icons.today_rounded), text: 'Daily Word'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _VocabularyTab(),
          _GrammarTab(),
          _DailyWordTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? const _VocabularyTabFab()
          : null,
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Vocabulary Tab
// ──────────────────────────────────────────────────────────────

class _VocabularyTab extends StatelessWidget {
  const _VocabularyTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('content_vocabulary_chapters')
          .orderBy('chapterNumber', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}',
                style: const TextStyle(color: AppColors.error)),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final chapters = snapshot.data!.docs;

        if (chapters.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.book_outlined,
                    size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text('No vocabulary chapters yet.',
                    style: TextStyle(
                        fontSize: 16, color: Colors.grey.shade500)),
                const SizedBox(height: 8),
                Text('Tap + to add one.',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade400)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          itemCount: chapters.length,
          itemBuilder: (context, index) {
            final doc = chapters[index];
            final data = doc.data();
            final chapterNumber = data['chapterNumber'] as int? ?? 0;
            final title = data['title'] as String? ?? '';
            final level = data['level'] as String? ?? '';
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Card(
              elevation: 0,
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  child: Text('$chapterNumber',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                ),
                title: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('$level • ${doc.id}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 20),
                      color: AppColors.info,
                      onPressed: () => _editChapter(context, doc.id, data),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_rounded, size: 20),
                      color: AppColors.error,
                      onPressed: () => _deleteChapter(context, doc.id, title),
                    ),
                  ],
                ),
                onTap: () => _openWordList(context, doc.id, title),
              ),
            );
          },
        );
      },
    );
  }

  void _openWordList(BuildContext context, String chapterId, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _WordsScreen(chapterId: chapterId, chapterTitle: title),
      ),
    );
  }

  void _editChapter(BuildContext context, String docId, Map<String, dynamic> data) {
    _showChapterForm(context, existingId: docId, existingData: data);
  }

  void _deleteChapter(BuildContext context, String docId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Chapter?'),
        content: Text('Are you sure you want to delete "$title"?\n'
            'This will NOT delete the associated words.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('content_vocabulary_chapters')
                  .doc(docId)
                  .delete();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _VocabularyTabFab extends StatelessWidget {
  const _VocabularyTabFab();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showChapterForm(context),
      backgroundColor: AppColors.primary,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }
}

void _showChapterForm(BuildContext context,
    {String? existingId, Map<String, dynamic>? existingData}) {
  final numberController =
      TextEditingController(text: existingData?['chapterNumber']?.toString() ?? '');
  final titleController =
      TextEditingController(text: existingData?['title'] as String? ?? '');
  String? selectedLevel = existingData?['level'] as String? ?? 'Beginner';
  final isEditing = existingId != null;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Edit Chapter' : 'Add Chapter',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: numberController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Chapter Number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedLevel,
                  decoration: const InputDecoration(
                    labelText: 'Level',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Beginner', child: Text('Beginner')),
                    DropdownMenuItem(
                        value: 'Intermediate', child: Text('Intermediate')),
                    DropdownMenuItem(value: 'Advanced', child: Text('Advanced')),
                  ],
                  onChanged: (v) => setState(() => selectedLevel = v),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final chapterNum = int.tryParse(numberController.text);
                          if (chapterNum == null ||
                              titleController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Chapter number and title are required.'),
                                  backgroundColor: AppColors.error),
                            );
                            return;
                          }
                          final data = {
                            'chapterNumber': chapterNum,
                            'title': titleController.text.trim(),
                            'level': selectedLevel ?? 'Beginner',
                          };
                          final firestore = FirebaseFirestore.instance;
                          if (isEditing) {
                            firestore
                                .collection('content_vocabulary_chapters')
                                .doc(existingId)
                                .update(data);
                          } else {
                            firestore
                                .collection('content_vocabulary_chapters')
                                .add(data);
                          }
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        child: Text(
                          isEditing ? 'Save' : 'Add',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

// ──────────────────────────────────────────────────────────────
// Words Screen (pushed from vocabulary chapter tap)
// ──────────────────────────────────────────────────────────────

class _WordsScreen extends StatelessWidget {
  final String chapterId;
  final String chapterTitle;

  const _WordsScreen({
    required this.chapterId,
    required this.chapterTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Words: $chapterTitle')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('content_vocabulary_words')
            .where('chapterId', isEqualTo: chapterId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: AppColors.error)),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final words = snapshot.data!.docs;

          if (words.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.abc, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('No words yet.',
                      style:
                          TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  Text('Tap + to add one.',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            itemCount: words.length,
            itemBuilder: (context, index) {
              final doc = words[index];
              final data = doc.data();
              final word = data['word'] as String? ?? '';
              final meaning = data['meaning'] as String? ?? '';
              final isDark = Theme.of(context).brightness == Brightness.dark;

              return Card(
                elevation: 0,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color:
                    isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color:
                          isDark ? AppColors.borderDark : AppColors.borderLight),
                ),
                child: ListTile(
                  title: Text(word,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(meaning, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 20),
                        color: AppColors.info,
                        onPressed: () =>
                            _editWord(context, doc.id, data),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_rounded, size: 20),
                        color: AppColors.error,
                        onPressed: () =>
                            _deleteWord(context, doc.id, word),
                      ),
                    ],
                  ),
                  onTap: () => _viewWordDetail(context, data),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addWord(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _viewWordDetail(BuildContext context, Map<String, dynamic> data) {
    final word = data['word'] as String? ?? '';
    final meaning = data['meaning'] as String? ?? '';
    final banglaMeaning = data['banglaMeaning'] as String? ?? '';
    final pronunciation = data['pronunciation'] as String? ?? '';
    final exampleSentence = data['exampleSentence'] as String? ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(word),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (meaning.isNotEmpty) Text('📖 $meaning'),
            if (banglaMeaning.isNotEmpty) Text('🇧🇩 $banglaMeaning'),
            if (pronunciation.isNotEmpty) Text('🗣️ $pronunciation'),
            if (exampleSentence.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('💬 $exampleSentence',
                    style: const TextStyle(fontStyle: FontStyle.italic)),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
        ],
      ),
    );
  }

  void _addWord(BuildContext context) {
    _showWordForm(context, chapterId: chapterId);
  }

  void _editWord(
      BuildContext context, String docId, Map<String, dynamic> data) {
    _showWordForm(context, chapterId: chapterId, existingId: docId, existingData: data);
  }

  void _deleteWord(BuildContext context, String docId, String word) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Word?'),
        content: Text('Delete "$word"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('content_vocabulary_words')
                  .doc(docId)
                  .delete();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

void _showWordForm(BuildContext context,
    {required String chapterId,
    String? existingId,
    Map<String, dynamic>? existingData}) {
  final wordController =
      TextEditingController(text: existingData?['word'] as String? ?? '');
  final meaningController =
      TextEditingController(text: existingData?['meaning'] as String? ?? '');
  final banglaMeaningController =
      TextEditingController(text: existingData?['banglaMeaning'] as String? ?? '');
  final pronunciationController =
      TextEditingController(text: existingData?['pronunciation'] as String? ?? '');
  final exampleController =
      TextEditingController(text: existingData?['exampleSentence'] as String? ?? '');
  final isEditing = existingId != null;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? 'Edit Word' : 'Add Word',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: wordController,
                decoration: const InputDecoration(
                  labelText: 'Word',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: meaningController,
                decoration: const InputDecoration(
                  labelText: 'Meaning (English)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: banglaMeaningController,
                decoration: const InputDecoration(
                  labelText: 'Bangla Meaning',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pronunciationController,
                decoration: const InputDecoration(
                  labelText: 'Pronunciation',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: exampleController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Example Sentence',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (wordController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Word is required.'),
                                backgroundColor: AppColors.error),
                          );
                          return;
                        }
                        final data = {
                          'chapterId': chapterId,
                          'word': wordController.text.trim(),
                          'meaning': meaningController.text.trim(),
                          'banglaMeaning': banglaMeaningController.text.trim(),
                          'pronunciation': pronunciationController.text.trim(),
                          'exampleSentence': exampleController.text.trim(),
                        };
                        final firestore = FirebaseFirestore.instance;
                        if (isEditing) {
                          firestore
                              .collection('content_vocabulary_words')
                              .doc(existingId)
                              .update(data);
                        } else {
                          firestore
                              .collection('content_vocabulary_words')
                              .add(data);
                        }
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      child: Text(
                        isEditing ? 'Save' : 'Add',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ──────────────────────────────────────────────────────────────
// Grammar Tab
// ──────────────────────────────────────────────────────────────

class _GrammarTab extends StatelessWidget {
  const _GrammarTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('content_grammar_chapters')
          .orderBy('chapterNumber', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}',
                style: const TextStyle(color: AppColors.error)),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final chapters = snapshot.data!.docs;

        if (chapters.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.text_snippet_outlined,
                    size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text('No grammar chapters yet.',
                    style: TextStyle(
                        fontSize: 16, color: Colors.grey.shade500)),
                const SizedBox(height: 8),
                Text('Use the Seed button on the dashboard to import.',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade400)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: chapters.length,
          itemBuilder: (context, index) {
            final doc = chapters[index];
            final data = doc.data();
            final chapterNumber = data['chapterNumber'] as int? ?? 0;
            final title = data['title'] as String? ?? '';
            final content = data['content'] as String? ?? '';
            final contentPreview = content.length > 80
                ? '${content.substring(0, 80)}...'
                : content;
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Card(
              elevation: 0,
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.accent.withOpacity(0.12),
                  child: Text('$chapterNumber',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent)),
                ),
                title: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(contentPreview,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  color: AppColors.info,
                  onPressed: () => _editGrammarContent(
                      context, doc.id, title, content),
                ),
                onTap: () => _editGrammarContent(
                    context, doc.id, title, content),
              ),
            );
          },
        );
      },
    );
  }

  void _editGrammarContent(
      BuildContext context, String docId, String title, String currentContent) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _GrammarEditorScreen(
          docId: docId,
          chapterTitle: title,
          initialContent: currentContent,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Grammar Markdown Editor Screen
// ──────────────────────────────────────────────────────────────

class _GrammarEditorScreen extends StatefulWidget {
  final String docId;
  final String chapterTitle;
  final String initialContent;

  const _GrammarEditorScreen({
    required this.docId,
    required this.chapterTitle,
    required this.initialContent,
  });

  @override
  State<_GrammarEditorScreen> createState() => _GrammarEditorScreenState();
}

class _GrammarEditorScreenState extends State<_GrammarEditorScreen> {
  late TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chapterTitle),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_rounded),
            label: Text(_saving ? 'Saving...' : 'Save'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceDark.withOpacity(0.5)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16),
                  const SizedBox(width: 8),
                  const Text('Markdown supported',
                      style: TextStyle(fontSize: 12)),
                  const Spacer(),
                  Text('${_controller.text.length} chars',
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'Write markdown content here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? AppColors.surfaceDark
                      : AppColors.surfaceLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('content_grammar_chapters')
          .doc(widget.docId)
          .update({
        'content': _controller.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Content saved!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ──────────────────────────────────────────────────────────────
// Daily Word Tab
// ──────────────────────────────────────────────────────────────

class _DailyWordTab extends StatefulWidget {
  const _DailyWordTab();

  @override
  State<_DailyWordTab> createState() => _DailyWordTabState();
}

class _DailyWordTabState extends State<_DailyWordTab> {
  String? _selectedChapterId;
  String _selectedChapterTitle = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Current Config Card ──
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('app_config')
              .doc('daily_word_config')
              .snapshots(),
          builder: (context, snapshot) {
            final config = snapshot.data?.data();
            final activeId = config?['activeChapterId'] as String? ?? '';

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.primaryGradient),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.today_rounded, color: Colors.white, size: 24),
                      SizedBox(width: 8),
                      Text('Daily Word Configuration',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    activeId.isEmpty
                        ? '⚠️ No chapter selected. Words will not be shown.'
                        : '✅ Active Chapter ID: $activeId',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 20),

        // ── Chapter Picker ──
        const Text('Select Chapter for Daily Words',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('content_vocabulary_chapters')
              .orderBy('chapterNumber', descending: false)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                  height: 40,
                  child: Center(child: CircularProgressIndicator()));
            }

            final chapters = snapshot.data!.docs;

            return Column(
              children: [
                ...chapters.map((doc) {
                  final data = doc.data();
                  final chapterNumber =
                      data['chapterNumber'] as int? ?? 0;
                  final title = data['title'] as String? ?? '';
                  final level = data['level'] as String? ?? '';
                  final isSelected =
                      _selectedChapterId == doc.id;

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.1)
                        : isDark
                            ? AppColors.surfaceDark
                            : AppColors.surfaceLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Text('#$chapterNumber',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? AppColors.primary
                                  : null)),
                      title: Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(level, style: const TextStyle(fontSize: 12)),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle,
                              color: AppColors.primary)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedChapterId = doc.id;
                          _selectedChapterTitle = title;
                        });
                      },
                    ),
                  );
                }),
              ],
            );
          },
        ),

        const SizedBox(height: 16),

        // ── Save & Preview Buttons ──
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _selectedChapterId == null
                    ? null
                    : () => _saveDailyConfig(_selectedChapterId!),
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save Config'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ── Preview Today's Words ──
        if (_selectedChapterId != null) ...[
          Row(
            children: [
              const Icon(Icons.visibility_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 6),
              Text('Preview: $_selectedChapterTitle',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 8),
          _buildWordsPreview(_selectedChapterId!),
        ],
      ],
    );
  }

  Widget _buildWordsPreview(String chapterId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('content_vocabulary_words')
          .where('chapterId', isEqualTo: chapterId)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final words = snapshot.data!.docs;
        if (words.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No words in this chapter.',
                  style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Row(
                children: [
                  const Text('Word',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const Spacer(),
                  const Text('Meaning',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            ...words.take(5).map((doc) {
              final data = doc.data();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                        color: Colors.grey.shade200, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(data['word'] as String? ?? '',
                          style:
                              const TextStyle(fontWeight: FontWeight.w500)),
                    ),
                    Expanded(
                      child: Text(data['meaning'] as String? ?? '',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.volume_up_rounded, size: 18),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: AppColors.primary,
                    ),
                  ],
                ),
              );
            }),
            if (words.length > 5)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('+${words.length - 5} more words',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
              ),
          ],
        );
      },
    );
  }

  Future<void> _saveDailyConfig(String chapterId) async {
    try {
      await FirebaseFirestore.instance
          .collection('app_config')
          .doc('daily_word_config')
          .set({
        'activeChapterId': chapterId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daily word config updated!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}