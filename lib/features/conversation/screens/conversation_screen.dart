import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../core/constants/app_colors.dart';
import '../../../services/ai_service.dart';
import '../../../services/hive_service.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;
  bool _roleSelected = false;
  Map<String, dynamic>? _selectedRole;
  String _userName = '';
  String? _currentSessionId;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  String _locale = 'en_US';
  final List<String> _locales = ['en_US', 'bn_BD'];
  final List<String> _localeLabels = ['EN', 'BN'];

  final List<Map<String, dynamic>> _roles = [
    {'title': 'Waiter', 'subtitle': 'Restaurant', 'icon': Icons.restaurant_rounded, 'emoji': '🍽️',
     'prompt': 'You are a friendly waiter at an English restaurant. Ask the customer step-by-step questions about ordering food. STRICT: If they give incomplete answers (like "pizza", "yes", "water"), do NOT move on. Correct them: tell them to use full sentences like "I would like pizza" or "I want water, please." Explain in Bangla. Only move to next question when they give a complete sentence.'},
    {'title': 'Shopkeeper', 'subtitle': 'Clothing Store', 'icon': Icons.shopping_bag_rounded, 'emoji': '🛍️',
     'prompt': 'You are a friendly shopkeeper at an English clothing store. Ask step-by-step questions about shopping. STRICT: If they give incomplete answers (like "blue", "small", "yes"), do NOT move on. Correct them: tell them to use full sentences like "I am looking for a blue shirt" or "My size is small." Explain in Bangla. Only move to next question when they give a complete sentence.'},
    {'title': 'Doctor', 'subtitle': 'Hospital', 'icon': Icons.local_hospital_rounded, 'emoji': '🏥',
     'prompt': 'You are a friendly doctor at an English-speaking clinic. Ask step-by-step questions about symptoms. STRICT: If they give incomplete answers (like "headache", "yes", "fever"), do NOT move on. Correct them: tell them to use full sentences like "I have a headache" or "Yes, I have a fever." Explain in Bangla. Only move to next question when they give a complete sentence.'},
    {'title': 'Friend', 'subtitle': 'Casual Chat', 'icon': Icons.people_rounded, 'emoji': '🤝',
     'prompt': 'You are a friendly English-speaking friend. Ask step-by-step questions about their day, hobbies, etc. STRICT: If they give incomplete answers (like "good", "fine", "cricket", "music"), do NOT move on. Correct them: tell them to use full sentences like "My day was good" or "I like cricket." Explain in Bangla. Only move to next question when they give a complete sentence.'},
    {'title': 'Hotel Receptionist', 'subtitle': 'Hotel', 'icon': Icons.hotel_rounded, 'emoji': '🏨',
     'prompt': 'You are a friendly hotel receptionist at an English-speaking hotel. Ask step-by-step questions about booking. STRICT: If they give incomplete answers (like "2 nights", "yes", "credit card"), do NOT move on. Correct them: tell them to use full sentences like "I want to stay for 2 nights" or "I will pay by credit card." Explain in Bangla. Only move to next question when they give a complete sentence.'},
    {'title': 'Bank Manager', 'subtitle': 'Bank', 'icon': Icons.account_balance_rounded, 'emoji': '🏦',
     'prompt': 'You are a friendly bank manager at an English-speaking bank. Ask step-by-step questions about banking. STRICT: If they give incomplete answers (like "savings", "deposit", "yes"), do NOT move on. Correct them: tell them to use full sentences like "I want to open a savings account" or "I want to deposit money." Explain in Bangla. Only move to next question when they give a complete sentence.'},
    {'title': 'Teacher', 'subtitle': 'School', 'icon': Icons.school_rounded, 'emoji': '👨‍🏫',
     'prompt': 'You are a friendly English teacher at a school. Ask step-by-step questions about studies. STRICT: If they give incomplete answers (like "English", "yes", "homework"), do NOT move on. Correct them: tell them to use full sentences like "My favorite subject is English" or "Yes, I did my homework." Explain in Bangla. Only move to next question when they give a complete sentence.'},
    {'title': 'Street Vendor', 'subtitle': 'Market', 'icon': Icons.storefront_rounded, 'emoji': '🛵',
     'prompt': 'You are a friendly street food vendor at an English-speaking market. Ask step-by-step questions about food orders. STRICT: If they give incomplete answers (like "noodles", "2", "spicy"), do NOT move on. Correct them: tell them to use full sentences like "I want noodles" or "I want it spicy, please." Explain in Bangla. Only move to next question when they give a complete sentence.'},
  ];

  @override
  void initState() {
    super.initState();
    _userName = HiveService.getUserName();
    _tryRestoreLastSession();
    _initSpeech();
  }

  void _initSpeech() async {
    _speechAvailable = await _speech.initialize();
    setState(() {});
  }

  void _tryRestoreLastSession() {
    final lastId = HiveService.getLastActiveConversationId();
    if (lastId.isEmpty) return;
    final sessions = HiveService.getChatSessions();
    final session = sessions.where((s) => s['id'] == lastId).firstOrNull;
    if (session != null && session['role'] != null) {
      _currentSessionId = session['id'] as String;
      _selectedRole = Map<String, dynamic>.from(session['role'] as Map);
      _roleSelected = true;
      _messages.addAll(
        (session['messages'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
    }
  }

  void _startNewChat() {
    _autoSaveSession();
    setState(() {
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      _messages.clear();
      _isTyping = true;
    });
    final role = _selectedRole;
    if (role == null) {
      setState(() => _isTyping = false);
      return;
    }
    final displayName = _userName.isNotEmpty ? _userName : 'there';
    final roleEmoji = role['emoji'] as String;
    final roleTitle = role['title'] as String;
    final systemPrompt = role['prompt'] as String;
    final fullPrompt = '$systemPrompt\n\n'
        'IMPORTANT: Always respond in English first, then provide Bangla translation below.\n'
        'Format: [English]\\n\\nবাংলা: [Bangla translation]\\n---\n'
        'Start the conversation now by greeting $displayName as a $roleTitle. '
        'Ask your first question.';

    AIService().sendMessageWithSystem(
      'Start the conversation as $roleTitle. Greet me and ask the first question.',
      systemPrompt: fullPrompt,
      history: [],
    ).then((response) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add({
          'text': '$roleEmoji $response',
          'isMe': false,
          'time': _formatTime(DateTime.now()),
        });
      });
      _scrollToBottom();
      _autoSaveSession();
    });
  }

  void _selectRole(Map<String, dynamic> role) {
    setState(() {
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      _selectedRole = role;
      _roleSelected = true;
      _messages.clear();
      _isTyping = true;
    });
    final displayName = _userName.isNotEmpty ? _userName : 'there';
    final roleEmoji = role['emoji'] as String;
    final roleTitle = role['title'] as String;
    final systemPrompt = role['prompt'] as String;
    final fullPrompt = '$systemPrompt\n\n'
        'IMPORTANT: Always respond in English first, then provide Bangla translation below.\n'
        'Format: [English]\\n\\nবাংলা: [Bangla translation]\\n---\n'
        'Start the conversation now by greeting $displayName as a $roleTitle. '
        'Ask your first question.';

    AIService().sendMessageWithSystem(
      'Start the conversation as $roleTitle. Greet me and ask the first question.',
      systemPrompt: fullPrompt,
      history: [],
    ).then((response) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add({
          'text': '$roleEmoji $response',
          'isMe': false,
          'time': _formatTime(DateTime.now()),
        });
      });
      _scrollToBottom();
      _autoSaveSession();
    });
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
    });
    _scrollToBottom();

    final role = _selectedRole;
    if (role == null) return;
    final roleTitle = role['title'] as String;
    final systemPrompt = role['prompt'] as String;
    final displayName = _userName.isNotEmpty ? _userName : 'there';

    final history = _buildMessageHistory();
    final fullPrompt = '$systemPrompt\n\n'
        'IMPORTANT: Always respond in English first, then provide Bangla translation below.\n'
        'Format: [English]\\n\\nবাংলা: [Bangla translation]\\n---\n'
        'You are currently talking to $displayName as a $roleTitle.\n'
        'RULES:\n'
        '1. If the student says "I don\'t know", "ami janina", "ki bole uttor dibo", "kivabe bolbo", '
        'or any similar phrase in English or Bangla showing they are stuck — HELP them immediately. '
        'Give them the correct answer in English, explain it in Bangla, and ask them to repeat after you.\n'
        '2. If the student asks for help in Bangla (e.g. "eta ki?", "mane ki?", "kivabe bole?"), '
        'always respond helpfully: tell them the English word/sentence, explain the meaning in Bangla, '
        'and encourage them to try saying it.\n'
        '3. If the student gives a completely wrong answer (unrelated to your question), '
        'tell them gently: "I asked about [your question], but you talked about [their topic]. Here is the correct way..." '
        'Explain in Bangla. Give them the right answer and ask them to try.\n'
        '4. If the answer is relevant but has grammar issues: correct the grammar, explain in Bangla, '
        'and ask them to try with the correction.\n'
        '5. If the answer is a complete, correct sentence — praise them and move to the next question.\n'
        '6. If the response is JUST 1-2 words with no subject or verb (e.g. just "nice", "good", "yes"), '
        'ask them to use a full sentence, show an example, explain in Bangla.\n'
        '7. If they use Bangla words in an English sentence, help them find the English equivalent.\n'
        '8. Keep friendly and encouraging.';

    AIService().sendMessageWithSystem(text, systemPrompt: fullPrompt, history: history).then((response) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add({
          'text': response,
          'isMe': false,
          'time': _formatTime(DateTime.now()),
        });
      });
      _scrollToBottom();
      _autoSaveSession();
    });
  }

  void _autoSaveSession() {
    if (_currentSessionId == null || _selectedRole == null || _messages.isEmpty) return;
    final firstUserMsg = _messages.firstWhere(
      (m) => m['isMe'] == true,
      orElse: () => const {'text': 'Conversation Practice'},
    );
    final title = '${_selectedRole!['emoji']} ${_selectedRole!['title']} — ${(firstUserMsg['text'] as String).length > 30 ? '${(firstUserMsg['text'] as String).substring(0, 30)}...' : firstUserMsg['text'] as String}';
    HiveService.saveChatSession({
      'id': _currentSessionId,
      'title': title,
      'messages': List<Map<String, dynamic>>.from(_messages),
      'role': _selectedRole,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    HiveService.setLastActiveConversationId(_currentSessionId!);
  }

  void _loadSession(Map<String, dynamic> session) {
    setState(() {
      _currentSessionId = session['id'] as String;
      _selectedRole = Map<String, dynamic>.from(session['role'] as Map);
      _roleSelected = true;
      _messages.clear();
      _messages.addAll(
        (session['messages'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
    });
    _scrollToBottom();
    Navigator.pop(context);
  }

  void _deleteSession(String id) {
    HiveService.deleteChatSession(id);
    if (HiveService.getLastActiveConversationId() == id) {
      HiveService.setLastActiveConversationId('');
    }
    if (id == _currentSessionId) {
      _startNewChat();
    }
  }

  List<Map<String, String>> _buildMessageHistory() {
    final result = <Map<String, String>>[];
    for (final msg in _messages) {
      result.add({
        'role': msg['isMe'] == true ? 'user' : 'assistant',
        'content': (msg['text'] as String).replaceAll(RegExp(r'^[🍽️🛍️🏥🤝🏨🏦👨‍🏫🛵]\s*'), ''),
      });
    }
    return result;
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
                      const Text('Conversation History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (sessions.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.delete_sweep_rounded, size: 22, color: Colors.red),
                          tooltip: 'Delete all',
                          onPressed: () {
                            showDialog(
                              context: ctx,
                              builder: (dCtx) => AlertDialog(
                                title: const Text('Delete all conversations?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
                                  TextButton(
                                    onPressed: () {
                                      HiveService.deleteAllChatSessions();
                                      HiveService.setLastActiveConversationId('');
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
                          Text('No conversation history yet', style: TextStyle(color: Colors.grey[500], fontSize: 15)),
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
                              child: Icon(Icons.forum_rounded, size: 18,
                                  color: isActive ? Colors.white : (isDark ? Colors.white54 : Colors.grey[600])),
                            ),
                            title: Text(
                              s['title'] as String? ?? 'Conversation',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: _roleSelected && _selectedRole != null
            ? Row(
                children: [
                  Text(_selectedRole!['emoji'] as String, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_selectedRole!['title']} (Role Play)',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        Text('Practice English conversation',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45)),
                      ],
                    ),
                  ),
                ],
              )
            : const Text('Conversation Practice', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _roleSelected
              ? () {
                  _autoSaveSession();
                  setState(() {
                    _roleSelected = false;
                    _selectedRole = null;
                    _messages.clear();
                  });
                }
              : () => Navigator.pop(context),
        ),
        actions: [
          if (_roleSelected) ...[
            IconButton(
              icon: const Icon(Icons.history_rounded, size: 24),
              tooltip: 'History',
              onPressed: _showHistoryDrawer,
            ),
            IconButton(
              icon: const Icon(Icons.add_comment_rounded, size: 24),
              tooltip: 'New Chat',
              onPressed: _startNewChat,
            ),
          ],
        ],
      ),
      body: _roleSelected ? _buildChatUI(isDark) : _buildRoleSelection(isDark),
    );
  }

  Widget _buildRoleSelection(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _roles.length,
      itemBuilder: (context, index) {
        final role = _roles[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight, width: 0.5)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: Text(role['emoji'] as String, style: const TextStyle(fontSize: 26))),
            ),
            title: Text(role['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text('${role['subtitle']} — practice ordering, asking, and replying',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () => _selectRole(role),
          ),
        );
      },
    );
  }

  Widget _buildChatUI(bool isDark) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            physics: const BouncingScrollPhysics(),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              final isMe = msg['isMe'] as bool;
              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primary : (isDark ? AppColors.surfaceDark : Colors.grey[100]),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(0),
                      bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(18),
                    ),
                    border: !isMe && isDark
                        ? Border.all(color: AppColors.borderDark, width: 0.5) : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(msg['text'] as String,
                          style: TextStyle(color: isMe ? Colors.white : (isDark ? Colors.white.withOpacity(0.9) : Colors.black87),
                              fontSize: 15, height: 1.35)),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(msg['time'] as String,
                            style: TextStyle(color: isMe ? Colors.white60 : Colors.grey, fontSize: 10)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_isTyping)
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  const SizedBox(width: 12, height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary))),
                  const SizedBox(width: 8),
                  Text('AI is typing...',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.backgroundDark : Colors.white,
            border: Border(top: BorderSide(color: isDark ? AppColors.borderDark : Colors.grey[100]!, width: 1.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Type your answer...',
                    hintStyle: const TextStyle(fontSize: 15),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
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
    );
  }
}
