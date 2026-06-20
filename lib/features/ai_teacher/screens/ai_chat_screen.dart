import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/ai_service.dart';
import '../../../services/hive_service.dart';
import '../../settings/screens/api_setup_guide_screen.dart';
import '../../settings/screens/settings_screen.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;
  String _userName = '';
  String? _currentSessionId;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  bool _isAiConfigured = false;
  String _aiModel = '';
  List<String> _suggestedQuestions = [];
  String _locale = 'en_US';
  final List<String> _locales = ['en_US', 'bn_BD'];
  final List<String> _localeLabels = ['EN', 'BN'];

  @override
  void initState() {
    super.initState();
    _userName = HiveService.getUserName();
    final activeKey = HiveService.getActiveAiKey();
    _isAiConfigured = activeKey?['key']?.toString().isNotEmpty ?? false;
    _aiModel = activeKey?['model']?.toString() ?? '';
    _tryRestoreLastSession();
    _initSpeech();
  }

  void _initSpeech() async {
    _speechAvailable = await _speech.initialize();
    setState(() {});
  }

  void _tryRestoreLastSession() {
    final lastId = HiveService.getLastActiveChatId();
    if (lastId.isEmpty) return _startNewChat();
    final sessions = HiveService.getChatSessions();
    final session = sessions.where((s) => s['id'] == lastId).firstOrNull;
    if (session != null) {
      _currentSessionId = session['id'] as String;
      _messages.addAll(
        (session['messages'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
    } else {
      _startNewChat();
    }
  }

  void _startNewChat() {
    _autoSaveSession();
    setState(() {
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      _messages.clear();
      _isTyping = false;
    });
    _addGreeting();
  }

  void _addGreeting() {
    final displayName = _userName.isNotEmpty ? _userName : 'there';
    final greetingText = _isAiConfigured
        ? 'Hello $displayName! 👋\n\nI am Keshab, your AI English Teacher. '
            'You can ask me anything about English — grammar, vocabulary, '
            'pronunciation, or just chat with me in English or Bangla. '
            'I am here to help you improve!\n\n'
            'How are you doing today?'
        : 'Hello $displayName! 👋\n\nI am Keshab, your AI English Teacher. '
            'To get started, please set up your AI API key by tapping the '
            '🔧 Setup button above.\n\n'
            'Once configured, you can ask me anything about English!';
    setState(() {
      _messages.add({
        'text': greetingText,
        'isMe': false,
        'time': _formatTime(DateTime.now()),
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authState = ref.read(authProvider);
    final name = authState.valueOrNull?.name ?? '';
    if (name.isNotEmpty && name != _userName) {
      setState(() => _userName = name);
      HiveService.setUserName(name);
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({
        'text': text,
        'isMe': true,
        'time': _formatTime(DateTime.now()),
      });
      _messageController.clear();
      _isTyping = true;
      _suggestedQuestions = [];
    });

    _scrollToBottom();

    final systemPrompt = _userName.isNotEmpty
        ? 'You are a friendly AI English teacher named Keshab. '
            "Your student's name is $_userName. "
            'Your job is to help the student learn and practice English in a natural, fun way. '
            'The student can ask questions in English or Bangla (Bengali). '
            'IMPORTANT: Always respond in English first, then immediately provide the Bangla translation below. '
            'Format your response like this:\n'
            '[Your English response here]\n\n'
            'বাংলা: [Bangla translation]\n'
            '---\n'
            'When correcting grammar, first show the correction in English, then explain in Bangla. '
            'When introducing new vocabulary, give the English word with meaning and example in English, '
            'then translate the example to Bangla. '
            'Keep responses friendly, concise, and encouraging. '
            'Always address the student by name when possible. '
            'IMPORTANT: At the end of your response, suggest 2-4 related follow-up questions that the student might ask. '
            'Format them as a numbered or bulleted list, each ending with a question mark. '
            'Example:\n'
            '- What is present perfect tense?\n'
            '- How do I use past tense?\n'
            '- Can you explain future tense?'
        : null;

    void addResponse(String response) {
      if (!mounted) return;
      final suggestions = _extractSuggestions(response);
      final cleanResponse = _removeSuggestions(response);
      setState(() {
        _isTyping = false;
        _messages.add({
          'text': cleanResponse,
          'isMe': false,
          'time': _formatTime(DateTime.now()),
        });
        _suggestedQuestions = suggestions;
      });
      _scrollToBottom();
      _autoSaveSession();
    }

    void handleError(Object error) {
      if (!mounted) return;
      final activeKey = HiveService.getActiveAiKey();
      setState(() {
        _isTyping = false;
        _isAiConfigured = activeKey?['key']?.toString().isNotEmpty ?? false;
        _aiModel = activeKey?['model']?.toString() ?? '';
      });
      
      final errorStr = error.toString();
      if (errorStr.contains('API_KEY_MISSING')) {
        _showSetupDialog(
          'AI Model Not Configured',
          'Please set up your AI API key to use the AI teacher feature.',
        );
      } else if (errorStr.contains('API_CALL_FAILED')) {
        _showSetupDialog(
          'Connection Failed',
          'Unable to connect to AI service. Please check your API key configuration.',
        );
      }
    }

    if (systemPrompt != null) {
      AIService().sendMessageWithSystem(text, systemPrompt: systemPrompt)
          .then(addResponse)
          .catchError(handleError);
    } else {
      AIService().sendMessage(text)
          .then(addResponse)
          .catchError(handleError);
    }
  }

  void _autoSaveSession() {
    if (_currentSessionId == null || _messages.isEmpty) return;
    final firstUserMsg = _messages.firstWhere(
      (m) => m['isMe'] == true,
      orElse: () => const {'text': 'Chat with Keshab'},
    );
    final title = (firstUserMsg['text'] as String).length > 40
        ? '${(firstUserMsg['text'] as String).substring(0, 40)}...'
        : firstUserMsg['text'] as String;
    HiveService.saveChatSession({
      'id': _currentSessionId,
      'title': title,
      'messages': List<Map<String, dynamic>>.from(_messages),
      'updatedAt': DateTime.now().toIso8601String(),
    });
    HiveService.setLastActiveChatId(_currentSessionId!);
  }

  void _loadSession(Map<String, dynamic> session) {
    setState(() {
      _currentSessionId = session['id'] as String;
      _messages.clear();
      _messages.addAll(
        (session['messages'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
    });
    _scrollToBottom();
    Navigator.pop(context); // close drawer
  }

  void _deleteSession(String id) {
    HiveService.deleteChatSession(id);
    if (HiveService.getLastActiveChatId() == id) {
      HiveService.setLastActiveChatId('');
    }
    if (id == _currentSessionId) {
      _startNewChat();
    }
  }

  void _showHistoryDrawer() {
    final sessions = HiveService.getChatSessions();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: isDark ? AppColors.backgroundDark : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: isDark ? AppColors.borderDark : Colors.grey[200]!, width: 1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.history_rounded, size: 22, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text('Chat History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (sessions.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.delete_sweep_rounded, size: 22, color: Colors.red),
                          tooltip: 'Delete all',
                          onPressed: () {
                            showDialog(
                              context: ctx,
                              builder: (dCtx) => AlertDialog(
                                title: const Text('Delete all chats?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
                                  TextButton(
                                    onPressed: () {
                                      HiveService.deleteAllChatSessions();
                                      HiveService.setLastActiveChatId('');
                                      _startNewChat();
                                      Navigator.pop(dCtx);
                                      setSheetState(() {});
                                    },
                                    child: const Text('Delete All', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 22),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                if (sessions.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text('No chat history yet', style: TextStyle(color: Colors.grey[500], fontSize: 15)),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: sessions.length,
                      itemBuilder: (ctx, idx) {
                        final s = sessions[idx];
                        final isActive = s['id'] == _currentSessionId;
                        final updatedAt = s['updatedAt'] as String? ?? '';
                        final dateStr = updatedAt.isNotEmpty
                            ? _formatDate(DateTime.parse(updatedAt))
                            : '';
                        return Dismissible(
                          key: ValueKey(s['id']),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            color: Colors.red,
                            child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
                          ),
                          onDismissed: (_) {
                            _deleteSession(s['id'] as String);
                            setSheetState(() {});
                          },
                          child: ListTile(
                            selected: isActive,
                            selectedTileColor: AppColors.primary.withOpacity(0.08),
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: isActive ? AppColors.primary : (isDark ? Colors.white10 : Colors.grey[200]),
                              child: Icon(Icons.chat_rounded, size: 18,
                                  color: isActive ? Colors.white : (isDark ? Colors.white54 : Colors.grey[600])),
                            ),
                            title: Text(
                              s['title'] as String? ?? 'Chat with Keshab',
                              style: TextStyle(
                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: dateStr.isNotEmpty
                                ? Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey[500]))
                                : null,
                            trailing: IconButton(
                              icon: Icon(Icons.close_rounded, size: 18, color: Colors.grey[400]),
                              onPressed: () {
                                _deleteSession(s['id'] as String);
                                setSheetState(() {});
                              },
                            ),
                            onTap: () => _loadSession(s),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _startListening() async {
    if (!_speechAvailable) {
      _speechAvailable = await _speech.initialize();
      if (!_speechAvailable) return;
    }
    final existingText = _messageController.text.trim();
    _isListening = true;
    setState(() {});
    await _speech.listen(
      onResult: (result) {
        final words = result.recognizedWords;
        setState(() {
          if (existingText.isNotEmpty) {
            _messageController.text = '$existingText $words';
          } else {
            _messageController.text = words;
          }
        });
      },
      localeId: _locale,
    );
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  List<String> _extractSuggestions(String text) {
    final suggestions = <String>[];
    final lines = text.split('\n');
    
    for (var line in lines) {
      line = line.trim();
      if (line.startsWith('- ') && line.endsWith('?')) {
        suggestions.add(line.substring(2));
      } else if (RegExp(r'^\d+\.\s').hasMatch(line) && line.endsWith('?')) {
        suggestions.add(line.replaceFirst(RegExp(r'^\d+\.\s'), ''));
      }
    }
    
    return suggestions.take(4).toList();
  }

  String _removeSuggestions(String text) {
    final lines = text.split('\n');
    final cleanLines = <String>[];
    
    for (var line in lines) {
      final trimmed = line.trim();
      if ((trimmed.startsWith('- ') || RegExp(r'^\d+\.\s').hasMatch(trimmed)) && trimmed.endsWith('?')) {
        continue;
      }
      cleanLines.add(line);
    }
    
    return cleanLines.join('\n').trim();
  }

  void _showSetupDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ApiSetupGuideScreen()),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Setup Guide', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;


    return WillPopScope(
      onWillPop: () async {
        _autoSaveSession();
        Navigator.of(context).pop();
        return false;
      },
      child: Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Keshab',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isAiConfigured ? Colors.green : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _isAiConfigured 
                            ? (_aiModel.isNotEmpty ? _aiModel : 'Online')
                            : 'Setup Required',
                        style: TextStyle(
                          fontSize: 11,
                          color: _isAiConfigured ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            ),
          ],
        ),
        actions: [
          if (!_isAiConfigured)
            IconButton(
              icon: const Icon(Icons.settings_suggest_rounded, size: 24, color: Colors.orange),
              tooltip: 'Setup AI',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.history_rounded, size: 24),
            tooltip: 'Chat History',
            onPressed: _showHistoryDrawer,
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_rounded, size: 24),
            tooltip: 'New Chat',
            onPressed: _startNewChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages area
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  ..._messages.map((msg) {
                    final isMe = msg['isMe'] as bool;
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: () {
                          Clipboard.setData(ClipboardData(text: msg['text'] as String));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Message copied'),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.78,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isMe
                                ? AppColors.primary
                                : (isDark ? AppColors.surfaceDark : Colors.grey[100]),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(0),
                              bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(18),
                            ),
                            border: !isMe && isDark
                                ? Border.all(color: AppColors.borderDark, width: 0.5)
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isMe)
                                Text(
                                  msg['text'] as String,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    height: 1.35,
                                  ),
                                )
                              else
                                MarkdownBody(
                                  data: msg['text'] as String,
                                  selectable: false,
                                  styleSheet: MarkdownStyleSheet(
                                    p: TextStyle(
                                      color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                                      fontSize: 15,
                                      height: 1.35,
                                    ),
                                    strong: TextStyle(
                                      color: isDark ? Colors.white : Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    em: TextStyle(
                                      color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    code: TextStyle(
                                      backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                                      color: AppColors.primary,
                                      fontFamily: 'monospace',
                                    ),
                                    codeblockDecoration: BoxDecoration(
                                      color: isDark ? Colors.white10 : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    listBullet: TextStyle(
                                      color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  msg['time'] as String,
                                  style: TextStyle(
                                    color: isMe ? Colors.white60 : Colors.grey,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  if (_isTyping)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'AI is typing...',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Suggested questions above input
                  if (_suggestedQuestions.isNotEmpty && !_isTyping)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        height: 38,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _suggestedQuestions.length,
                          itemBuilder: (context, index) {
                            final question = _suggestedQuestions[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                avatar: const Icon(Icons.lightbulb_outline, size: 16),
                                label: Text(
                                  question.length > 40 ? '${question.substring(0, 40)}...' : question,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                                side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                onPressed: () {
                                  _messageController.text = question;
                                  setState(() => _suggestedQuestions = []);
                                  _sendMessage();
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Message input bar with suggestions below
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.backgroundDark : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppColors.borderDark : Colors.grey[100]!,
                      width: 1.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: 'Ask your teacher anything...',
                          hintStyle: const TextStyle(fontSize: 15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: isDark ? AppColors.surfaceDark : Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                    backgroundColor: _isListening ? Colors.red : (isDark ? Colors.white12 : Colors.grey[300]),
                    radius: 22,
                    child: IconButton(
                      onPressed: _isListening ? _stopListening : _startListening,
                      icon: Icon(
                        _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                        color: _isListening ? Colors.white : (isDark ? Colors.white54 : Colors.black54),
                        size: 20,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    final idx = _locales.indexOf(_locale);
                    setState(() => _locale = _locales[(idx + 1) % _locales.length]);
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.red.withOpacity(0.2) : (isDark ? Colors.white12 : Colors.grey[200]),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1),
                    ),
                    child: Text(
                      _localeLabels[_locales.indexOf(_locale)],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isListening ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  radius: 22,
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
          ],
        ),
        ],
      ),
      ),
    );
  }
}
