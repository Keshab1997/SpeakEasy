import 'package:flutter/material.dart';
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
  }

  void _selectRole(Map<String, dynamic> role) {
    setState(() {
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
    });
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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_selectedRole!['title']} (Role Play)',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('Practice English conversation',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45)),
                    ],
                  ),
                ],
              )
            : const Text('Conversation Practice', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _roleSelected
              ? () => setState(() {
                    _roleSelected = false;
                    _selectedRole = null;
                    _messages.clear();
                  })
              : () => Navigator.pop(context),
        ),
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
