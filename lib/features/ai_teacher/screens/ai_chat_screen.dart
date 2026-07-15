import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/ai_service.dart';
import '../../../services/hive_service.dart';
import '../../../services/translation_service.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToHome;
  
  const AiChatScreen({super.key, this.onNavigateToHome});

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
  double _voiceConfidence = 0.0;
  List<String> _suggestedQuestions = [];
  
  // --- Typing Animation State ---
  String _streamingText = '';
  bool _isStreaming = false;
  
  // --- Quick Actions ---
  final List<Map<String, String>> _quickActions = [
    {'label': '📝 Check Grammar', 'prompt': 'Please check this sentence for grammar errors: '},
    {'label': '📖 New Word', 'prompt': 'Teach me a new English word with meaning and example.'},
    {'label': '💬 Practice', 'prompt': 'Let\'s do a conversation practice. You start.'},
    {'label': '✍️ Correct This', 'prompt': 'Please correct this sentence and explain the grammar rules: '},
    {'label': '🔊 Pronunciation', 'prompt': 'Give me one English sentence to practice pronunciation. Just the sentence, no explanation.'},
    {'label': '📊 Evaluate', 'prompt': 'Please evaluate my English writing. I will paste a paragraph. Give me: Grammar Score (0-100), Vocabulary Level (A1-C2), Fluency Score (0-100), and a corrected version.'},
    {'label': '🎯 Challenge', 'prompt': 'Give me a quick daily English challenge. It should be one of: write 5 sentences in past tense, find errors in a sentence, or describe something. Keep it short and fun!'},
    {'label': '📝 Exercise', 'prompt': 'Generate a fun English exercise for me. Choose one type: Fill in the blanks, Multiple Choice, Error Detection, or Sentence Reordering. Show the exercise first, then provide answers separately.'},
  ];

  // --- Grammar Correction Mode ---
  bool _grammarMode = false;
  
  // --- Lesson Templates ---
  String? _selectedLesson;
  final List<Map<String, String>> _lessons = [
    {'id': 'intro', 'icon': '👋', 'label': 'Introduce Yourself', 'desc': '5 min', 'prompt': 'We are starting an "Introduce Yourself" lesson. Follow this EXACT format: Ask ONE question. Wait for my answer. If I make mistakes, gently correct me and show the right way. Give brief feedback (1-2 sentences). Then ask the NEXT question. Never answer for me. Never skip ahead. Be patient and encouraging.'},
    {'id': 'food', 'icon': '🍽️', 'label': 'Ordering Food', 'desc': '5 min', 'prompt': 'We are starting an "Ordering Food" lesson. You play the waiter, I play the customer. Ask ONE question about my order. Wait for my answer. If my English is wrong, correct me gently and show the proper phrase. Then ask the next question. Never answer for me. Stay in character.'},
    {'id': 'interview', 'icon': '💼', 'label': 'Job Interview', 'desc': '10 min', 'prompt': 'We are starting a "Job Interview" lesson. You are the interviewer. Ask ONE question at a time. Wait for my answer. If I make grammar mistakes, give 1 sentence of feedback. Suggest a better way to say it. Then ask the next question. Keep going for at least 5 questions. Be encouraging.'},
    {'id': 'routine', 'icon': '🌅', 'label': 'Daily Routine', 'desc': '5 min', 'prompt': 'We are starting a "Daily Routine" lesson. Ask ONE question at a time about my day. Wait for my answer. If I make mistakes, correct me gently and teach better expressions. If I cannot answer, give me the words I need. Then ask the next question. Cover morning, afternoon, evening.'},
    {'id': 'past', 'icon': '📖', 'label': 'Past Events', 'desc': '5 min', 'prompt': 'We are starting a "Past Events" lesson. Ask ONE question about my yesterday/weekend. Wait for my answer. If I use wrong tense, say "Good try! We say: [correct sentence]". Explain briefly. Then ask the next question. Do not correct every single mistake, just the important ones.'},
  ];
  
  // --- Pronunciation Practice ---
  bool _pronunciationMode = false;
  String _pronunciationSentence = '';
  bool _isPlaying = false;
  String _userSpeechResult = '';
  double? _pronunciationAccuracy;
  final FlutterTts _flutterTts = FlutterTts();
  
  // --- Vocabulary Learning ---
  Map<String, String>? _detectedVocab;
  
  // --- Voice Conversation Mode ---
  bool _voiceMode = false;
  bool _voiceModeSpeaking = false;
  
  // --- Writing Evaluation ---
  bool _writingEvalMode = false;
  Map<String, dynamic>? _writingEvalResult;
  
  // --- Daily Challenge ---
  int _challengeStreak = 0;
  bool _challengeCompleted = false;
  
  // --- UI State ---
  bool _showQuickActions = false;
  
  // --- Translation ---
  bool _isTranslating = false;
  
  String _locale = 'en_US';
  final List<String> _locales = ['en_US', 'bn_BD'];
  final List<String> _localeLabels = ['EN', 'BN'];

  @override
  void initState() {
    super.initState();
    _userName = HiveService.getUserName();
    _tryRestoreLastSession();
    _initSpeech();
    _initTts();
    _loadChallengeStreak();
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
    _cancelStreaming();
    setState(() {
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      _messages.clear();
      _isTyping = false;
      _isStreaming = false;
      _streamingText = '';
      _showQuickActions = false;
    });
    _addGreeting();
  }

  void _cancelStreaming() {
    _isStreaming = false;
    _streamingText = '';
  }

  void _addGreeting() {
    final displayName = _userName.isNotEmpty ? _userName : 'there';
    final greetingText = 'Hello $displayName! 👋\n\n'
        'I am Keshab, your AI English Teacher. '
        'You can ask me anything about English — grammar, vocabulary, '
        'pronunciation, or just chat with me in English or Bangla. '
        'I am here to help you improve!\n\n'
        'How are you doing today?';
    setState(() {
      _messages.add({
        'text': greetingText,
        'isMe': false,
        'time': _formatTime(DateTime.now()),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
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
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      _messageController.clear();
      FocusManager.instance.primaryFocus?.unfocus();
      _isTyping = true;
      _suggestedQuestions = [];
    });

    _scrollToBottom();

    // Auto-complete daily challenge if user responds
    if (!_challengeCompleted && _messages.length >= 2) {
      final lastAiMsg = _messages.where((m) => m['isMe'] == false).lastOrNull;
      if (lastAiMsg != null) {
        final lastText = (lastAiMsg['text'] as String).toLowerCase();
        if (lastText.contains('challenge') || lastText.contains('write 5') || lastText.contains('find 3 errors')) {
          _completeChallenge();
        }
      }
    }

    final String? systemPrompt;
    if (_grammarMode) {
      systemPrompt = 'You are a strict but friendly English grammar teacher named Keshab. '
          "Your student's name is $_userName. "
          'Your ONLY job is to correct grammar errors and explain grammar rules. '
          'When the student sends a sentence, analyze it and respond with this EXACT format:\n\n'
          '📝 **Grammar Correction**\n\n'
          '🔴 **Error**: [what the student wrote wrong]\n'
          '🟢 **Correction**: [the correct version]\n'
          '📖 **Rule**: [grammar rule explanation, include Bangla translation]\n'
          '💡 **Try**: [a similar sentence for practice]\n\n'
          'If there are multiple errors, list each one in the format above. '
          'If the sentence is correct, say: ✅ "Your sentence is grammatically correct!" '
          'and give a small tip. '
          'Do NOT suggest follow-up questions. '
          'Do NOT add extra conversation. Stay focused on grammar correction.';
    } else if (_userName.isNotEmpty) {
      String basePrompt = 'You are a friendly AI English teacher named Keshab. '
          "Your student's name is $_userName. "
          'Your job is to help the student learn and practice English in a natural, fun way. '
          'The student can ask questions in English or Bangla (Bengali). '
          'IMPORTANT RULES:\n'
          '1. Always respond in English only by default.\n'
          '2. If the student asks "what does X mean?" or "X এর অর্থ কি?" in Bangla, '
          'then explain the meaning in Bangla with example.\n'
          '3. Do NOT repeat the student\'s name in every response. Use it occasionally, not in every sentence.\n'
          '4. Keep responses friendly, concise, and encouraging.\n';

      // Lesson Mode: Enforce structured Q&A flow
      if (_selectedLesson != null) {
        basePrompt += '5. LESSON MODE ACTIVE: You are conducting a structured lesson. '
            'Follow these rules STRICTLY:\n'
            '   - Ask ONE question at a time. Never ask multiple questions in one message.\n'
            '   - Wait for my answer. Never answer on my behalf.\n'
            '   - After I answer, give brief feedback (1-2 sentences).\n'
            '   - Then ask the NEXT question. Keep the lesson moving forward.\n'
            '   - NEVER skip ahead or complete the lesson early.\n'
            '   - If I ask something off-topic, politely steer back to the lesson.\n'
            '   - Do NOT suggest follow-up questions at the end. Just continue the lesson.\n\n'
            'WHEN STUDENT MAKES A MISTAKE:\n'
            '   - Be VERY encouraging and patient. Never scold.\n'
            '   - Say "Good try!" or "Almost correct!" first.\n'
            '   - Then gently show the correct answer.\n'
            '   - Explain the mistake in 1 simple sentence.\n'
            '   - If the student cannot answer, give them the correct answer and ask them to repeat it.\n'
            '   - Then move to the next question. Do not dwell on mistakes.\n'
            '   - The goal is confidence building, not perfection.';
      } else {
        basePrompt += '5. At the end of your response, suggest 2-4 related follow-up questions. '
            'Format them as a numbered or bulleted list, each ending with a question mark. '
            'Example:\n'
            '- What is present perfect tense?\n'
            '- How do I use past tense?\n'
            '- Can you explain future tense?';
      }

      systemPrompt = basePrompt;
    } else {
      systemPrompt = null;
    }

    void addResponse(String response) {
      if (!mounted) return;
      final suggestions = _extractSuggestions(response);
      final cleanResponse = _removeSuggestions(response);
      setState(() {
        _isTyping = false;
        _isStreaming = true;
        _streamingText = '';
      });
      _simulateTyping(cleanResponse, suggestions);
    }

    void handleError(Object error) {
      if (!mounted) return;
      _cancelStreaming();
      setState(() {
        _isTyping = false;
        _messages.add({
          'text': 'AI service not available',
          'isMe': false,
          'time': _formatTime(DateTime.now()),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      });
      _scrollToBottom();
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

  void _simulateTyping(String fullText, List<String> suggestions) {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < fullText.length; i++) {
      Future.delayed(Duration(milliseconds: 15 * i), () {
        if (!mounted || !_isStreaming) return;
        setState(() {
          _streamingText = fullText.substring(0, i + 1);
        });
        if (i == fullText.length - 1) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!mounted) return;
            // Extract sentence for pronunciation practice
            if (_pronunciationMode) {
              _startPronunciationPractice(fullText.trim());
            }
            // Detect vocabulary words
            _detectVocabulary(fullText);
            // Parse writing evaluation results
            if (_writingEvalMode) {
              _parseWritingEvaluation(fullText);
            }
            setState(() {
              _isStreaming = false;
              _messages.add({
                'text': fullText,
                'isMe': false,
                'time': _formatTime(DateTime.now()),
                'timestamp': now,
              });
              _suggestedQuestions = suggestions;
              _streamingText = '';
            });
            _scrollToBottom();
            _autoSaveSession();
            // Voice Mode: Speak response then auto-listen
            if (_voiceMode && mounted) {
              _startVoiceModeResponse(fullText);
            }
          });
        }
      });
    }
  }

  // --- Pronunciation Practice Methods ---
  void _initTts() {
    _flutterTts.setCompletionHandler(() {
      setState(() => _isPlaying = false);
      if (_voiceMode && mounted) {
        _startVoiceModeListening();
      }
    });
    _flutterTts.setErrorHandler((_) => setState(() => _isPlaying = false));
  }

  Future<void> _speakSentence(String sentence) async {
    setState(() => _isPlaying = true);
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.speak(sentence);
  }

  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    setState(() => _isPlaying = false);
  }

  Future<void> _startPronunciationListening() async {
    if (!_speechAvailable) {
      _speechAvailable = await _speech.initialize();
      if (!_speechAvailable) return;
    }
    setState(() {
      _userSpeechResult = '';
      _pronunciationAccuracy = null;
    });
    await _speech.listen(
      onResult: (result) {
        setState(() => _userSpeechResult = result.recognizedWords);
      },
      localeId: 'en_US',
    );
  }

  void _stopPronunciationListening() {
    _speech.stop();
    _calculatePronunciationAccuracy();
  }

  void _calculatePronunciationAccuracy() {
    if (_pronunciationSentence.isEmpty || _userSpeechResult.isEmpty) return;
    
    final expected = _pronunciationSentence.toLowerCase().split(' ');
    final spoken = _userSpeechResult.toLowerCase().split(' ');
    
    if (expected.isEmpty || spoken.isEmpty) {
      setState(() => _pronunciationAccuracy = 0);
      return;
    }
    
    int matches = 0;
    for (var word in spoken) {
      if (expected.contains(word)) matches++;
    }
    
    final accuracy = (matches / expected.length) * 100;
    setState(() => _pronunciationAccuracy = accuracy.clamp(0, 100));
  }

  void _startPronunciationPractice(String sentence) {
    setState(() {
      _pronunciationMode = true;
      _pronunciationSentence = sentence;
      _userSpeechResult = '';
      _pronunciationAccuracy = null;
    });
  }

  void _stopPronunciationPractice() {
    _flutterTts.stop();
    _speech.stop();
    setState(() {
      _pronunciationMode = false;
      _pronunciationSentence = '';
      _userSpeechResult = '';
      _pronunciationAccuracy = null;
      _isPlaying = false;
    });
  }

  // --- Vocabulary Detection ---
  void _detectVocabulary(String text) {
    // Look for patterns like: 'word' means, 'word' is, "word" means
    final wordPattern = RegExp(r"[']([^']+)[']+\s+means?\s+", caseSensitive: false);
    final match = wordPattern.firstMatch(text);
    if (match != null) {
      final w = match.group(1)!.trim();
      if (w.split(' ').length <= 3 && w.length > 1) {
        setState(() {
          _detectedVocab = <String, String>{
            'word': w,
            'context': text.length > 120 ? '${text.substring(0, 120)}...' : text,
          };
        });
      }
    }
  }

  void _saveDetectedVocab() {
    if (_detectedVocab == null) return;
    HiveService.saveAiVocabWord({
      'word': _detectedVocab!['word'],
      'context': _detectedVocab!['context'],
      'savedAt': DateTime.now().toIso8601String(),
    });
    setState(() => _detectedVocab = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Word saved to vocabulary!'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
      ),
    );
  }

  // --- Translate to Bangla ---
  Future<void> _translateToBangla(String text, Map<String, dynamic> msg) async {
    if (_isTranslating) return;
    setState(() => _isTranslating = true);
    msg['translating'] = true;
    try {
      final translation = await TranslationService().translate(
        text: text,
        fromLang: 'en',
        toLang: 'bn',
      );
      if (!mounted) return;
      msg['translatedText'] = translation ?? '(Could not translate. Please try again.)';
      msg['translating'] = false;
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      msg['translating'] = false;
      msg['translatedText'] = '(Could not translate. Please try again.)';
      setState(() {});
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  // --- Writing Evaluation ---
  void _parseWritingEvaluation(String text) {
    final grammarScore = RegExp(r'Grammar\s*Score[:\s]*(\d+)', caseSensitive: false).firstMatch(text);
    final vocabLevel = RegExp(r'Vocabulary\s*Level[:\s]*([A-C][12]?)', caseSensitive: false).firstMatch(text);
    final fluencyScore = RegExp(r'Fluency\s*Score[:\s]*(\d+)', caseSensitive: false).firstMatch(text);
    
    if (grammarScore != null || vocabLevel != null) {
      setState(() {
        _writingEvalResult = {
          'grammarScore': grammarScore?.group(1) != null ? int.tryParse(grammarScore!.group(1)!) ?? 0 : null,
          'vocabLevel': vocabLevel?.group(1),
          'fluencyScore': fluencyScore?.group(1) != null ? int.tryParse(fluencyScore!.group(1)!) ?? 0 : null,
        };
      });
    } else {
      setState(() => _writingEvalMode = false);
    }
  }

  Widget _buildEvalScoreCard(Map<String, dynamic> result) {
    final gs = result['grammarScore'] as int?;
    final vl = result['vocabLevel'] as String?;
    final fs = result['fluencyScore'] as int?;
    
    Color scoreColor(int score) {
      if (score >= 80) return Colors.green;
      if (score >= 60) return Colors.orange;
      return Colors.red;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(0.08), AppColors.primary.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.assessment_rounded, size: 18, color: AppColors.primary),
              SizedBox(width: 6),
              Text('Writing Evaluation', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          if (gs != null) ...[
            _buildScoreRow('Grammar', gs, scoreColor(gs)),
            const SizedBox(height: 6),
          ],
          if (fs != null) ...[
            _buildScoreRow('Fluency', fs, scoreColor(fs)),
            const SizedBox(height: 6),
          ],
          if (vl != null)
            Row(
              children: [
                const Text('Vocabulary Level: ', style: TextStyle(fontSize: 13)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    vl,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildScoreRow(String label, int score, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text('$label:', style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$score%',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  // --- Daily Challenge ---
  void _loadChallengeStreak() {
    // In-memory streak for this session
    setState(() => _challengeStreak = 0);
  }

  void _completeChallenge() {
    if (_challengeCompleted) return;
    setState(() {
      _challengeCompleted = true;
      _challengeStreak++;
    });
  }

  // --- Voice Conversation Mode ---
  Future<void> _startVoiceModeResponse(String text) async {
    setState(() => _voiceModeSpeaking = true);
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.speak(text);
  }

  Future<void> _startVoiceModeListening() async {
    if (!_voiceMode || !mounted) return;
    setState(() => _voiceModeSpeaking = false);
    
    if (!_speechAvailable) {
      _speechAvailable = await _speech.initialize();
      if (!_speechAvailable) return;
    }
    
    await _speech.listen(
      onResult: (result) {
        if (!_voiceMode || !mounted) return;
        final text = result.recognizedWords.trim();
        if (result.finalResult && text.isNotEmpty) {
          _messageController.text = text;
          _speech.stop();
          _sendMessage();
        }
      },
      localeId: 'en_US',
      listenFor: const Duration(seconds: 10),
    );
  }

  void _stopVoiceMode() {
    _speech.stop();
    _flutterTts.stop();
    setState(() {
      _voiceMode = false;
      _voiceModeSpeaking = false;
    });
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
    _cancelStreaming();
    _flutterTts.stop();
    _messageController.dispose();
    _scrollController.dispose();
    _speech.stop();
    super.dispose();
  }

  Widget _buildPronButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

	  void _startListening() async {
	    if (!_speechAvailable) {
	      _speechAvailable = await _speech.initialize();
	      if (!_speechAvailable) return;
	    }
	    final existingText = _messageController.text.trim();
	    _isListening = true;
	    _voiceConfidence = 0.0;
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
	          _voiceConfidence = result.confidence;
	        });
	      },
	      localeId: _locale,
	    );
	  }

	  void _stopListening() async {
	    await _speech.stop();
	    setState(() => _isListening = false);
	    // Text stays in field — user can edit or tap send manually
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;


    return WillPopScope(
      onWillPop: () async {
        _autoSaveSession();
        if (widget.onNavigateToHome != null) {
          widget.onNavigateToHome!();
          return false;
        }
        return true;
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
            const Text(
              'Keshab',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          // Tools Popup Menu (Grammar Mode, Voice Mode)
          PopupMenuButton<String>(
            icon: Icon(
              Icons.tune_rounded,
              size: 24,
              color: (_grammarMode || _voiceMode) ? AppColors.primary : null,
            ),
            tooltip: 'Tools',
            onSelected: (value) {
              switch (value) {
                case 'grammar':
                  setState(() => _grammarMode = !_grammarMode);
                  break;
                case 'voice':
                  if (_voiceMode) {
                    _stopVoiceMode();
                  } else {
                    setState(() => _voiceMode = true);
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'grammar',
                child: Row(
                  children: [
                    Icon(
                      Icons.spellcheck_rounded,
                      size: 20,
                      color: _grammarMode ? AppColors.primary : null,
                    ),
                    const SizedBox(width: 10),
                    Text(_grammarMode ? 'Grammar Mode: ON' : 'Grammar Mode: OFF'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'voice',
                child: Row(
                  children: [
                    Icon(
                      Icons.headset_mic_rounded,
                      size: 20,
                      color: _voiceMode ? AppColors.primary : null,
                    ),
                    const SizedBox(width: 10),
                    Text(_voiceMode ? 'Voice Mode: ON' : 'Voice Mode: OFF'),
                  ],
                ),
              ),
            ],
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
                  // --- Lesson Templates Carousel (only on empty chat) ---
                  if (_messages.length <= 1 && !_isTyping && !_isStreaming)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.school_rounded, size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                'Quick Lessons',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.grey[700],
                                ),
                              ),
                              const Spacer(),
                              if (_challengeStreak > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.local_fire_department_rounded, size: 12, color: Colors.orange),
                                      const SizedBox(width: 3),
                                      Text(
                                        '$_challengeStreak day streak',
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 72,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: _lessons.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final lesson = _lessons[index];
                                final isActiveLesson = _selectedLesson == lesson['id'];
                                return GestureDetector(
                                  onTap: () {
                                    setState(() => _selectedLesson = lesson['id']);
                                    _messageController.text = lesson['prompt']!;
                                    _sendMessage();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Starting: ${lesson['label']}'),
                                        duration: const Duration(seconds: 1),
                                        behavior: SnackBarBehavior.floating,
                                        margin: const EdgeInsets.all(16),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 130,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isActiveLesson
                                          ? AppColors.primary.withOpacity(0.1)
                                          : (isDark ? AppColors.surfaceDark : Colors.white),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isActiveLesson
                                            ? AppColors.primary
                                            : AppColors.primary.withOpacity(0.2),
                                        width: isActiveLesson ? 1.5 : 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(lesson['icon']!, style: const TextStyle(fontSize: 16)),
                                            const Spacer(),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                                child: Text(
                                                lesson['desc']!,
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ).copyWith(
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          lesson['label']!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  ..._messages.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final msg = entry.value;
                    final isMe = msg['isMe'] as bool;
                    
                    // --- Timestamp Grouping ---
                    bool showTimestamp = true;
                    if (idx > 0) {
                      final prev = _messages[idx - 1];
                      if (prev['isMe'] == msg['isMe']) {
                        final prevTs = prev['timestamp'] as int? ?? 0;
                        final currTs = msg['timestamp'] as int? ?? 0;
                        if (currTs - prevTs < 120000) { // 2 minutes
                          showTimestamp = false;
                        }
                      }
                    }
                    
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: () {
                          Clipboard.setData(ClipboardData(text: msg['text'] as String));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Message copied'),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              margin: EdgeInsets.all(16),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 4),
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
                                  style: const TextStyle(
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
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (showTimestamp)
                                    Text(
                                      msg['time'] as String,
                                      style: TextStyle(
                                        color: isMe ? Colors.white60 : Colors.grey,
                                        fontSize: 10,
                                      ),
                                    ),
                                  if (!isMe) ...[
                                    // --- Vocabulary Save Button ---
                                    if (_detectedVocab != null && idx == _messages.length - 1)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: InkWell(
                                          onTap: _saveDetectedVocab,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.amber.withOpacity(0.4)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                                                SizedBox(width: 3),
                                                Text(
                                                  'Save',
                                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    // --- Translate to Bangla Button ---
                                    Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: InkWell(
                                        onTap: _isTranslating
                                            ? null
                                            : () => _translateToBangla(msg['text'] as String, msg),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 300),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: msg['translating'] == true
                                                ? AppColors.primary.withOpacity(0.2)
                                                : AppColors.primary.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: msg['translating'] == true
                                                  ? AppColors.primary
                                                  : AppColors.primary.withOpacity(0.3),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              msg['translating'] == true
                                                  ? SizedBox(
                                                      width: 12,
                                                      height: 12,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 1.5,
                                                        color: AppColors.primary,
                                                      ),
                                                    )
                                                  : Icon(Icons.translate_rounded, size: 14, color: AppColors.primary),
                                              const SizedBox(width: 4),
                                              Text(
                                                msg['translating'] == true ? 'Translating...' : 'বাংলা',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  InkWell(
                                    child: Icon(
                                      Icons.copy_rounded,
                                      size: 14,
                                      color: isDark ? Colors.white38 : Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ),
                              if (msg['translatedText'] != null && msg['translatedText'] != '')
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border(
                                        left: BorderSide(
                                          color: AppColors.primary.withOpacity(0.5),
                                          width: 3,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.translate_rounded, size: 12, color: AppColors.primary),
                                            const SizedBox(width: 4),
                                            Text(
                                              'বাংলা অনুবাদ',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          msg['translatedText'] as String,
                                          style: TextStyle(
                                            fontSize: 13,
                                            height: 1.5,
                                            color: isDark ? Colors.white70 : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  if (_isTyping && !_isStreaming)
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

                  // --- Typing Animation (Streaming Message) ---
                  if (_isStreaming)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.78,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceDark : Colors.grey[100],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(18),
                              topRight: Radius.circular(18),
                              bottomRight: Radius.circular(18),
                              bottomLeft: Radius.circular(0),
                            ),
                          ),
                          child: MarkdownBody(
                            data: _streamingText.isEmpty ? '▊' : '$_streamingText▊',
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(
                                color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                                fontSize: 15,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // --- Writing Evaluation Score Card ---
                  if (_writingEvalResult != null && !_isStreaming)
                    _buildEvalScoreCard(_writingEvalResult!),

                  // Suggested questions above input
                  if (_suggestedQuestions.isNotEmpty && !_isTyping && !_isStreaming)
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

          // Voice Mode Status Indicator (Compact)
          if (_voiceMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: AppColors.primary.withOpacity(0.08),
              child: Row(
                children: [
                  Icon(
                    _voiceModeSpeaking ? Icons.volume_up_rounded : Icons.mic_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _voiceModeSpeaking
                          ? 'Keshab is speaking...'
                          : _isListening
                              ? 'Listening... Speak now'
                              : 'Voice Mode Active',
                      style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
                    ),
                  ),
                  InkWell(
                    onTap: _stopVoiceMode,
                    child: const Icon(Icons.close_rounded, size: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),

          // Quick Action Buttons (Collapsible)
          if (!_isStreaming && !_isTyping && _messages.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Toggle row
                  InkWell(
                    onTap: () => setState(() => _showQuickActions = !_showQuickActions),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_fix_high_rounded,
                            size: 14,
                            color: isDark ? Colors.white38 : Colors.grey[500],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Quick Actions',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white38 : Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            _showQuickActions ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                            size: 18,
                            color: isDark ? Colors.white38 : Colors.grey[500],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Action chips
                  if (_showQuickActions)
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _quickActions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final action = _quickActions[index];
                          final isPronunciation = action['label'] == '🔊 Pronunciation';
                          final isEvaluate = action['label'] == '📊 Evaluate';
                          return ActionChip(
                            avatar: Text(action['label']!.substring(0, 2)),
                            label: Text(
                              action['label']!.substring(3),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            backgroundColor: isPronunciation && _pronunciationMode
                                ? AppColors.primary.withOpacity(0.15)
                                : (isEvaluate && _writingEvalMode
                                    ? AppColors.primary.withOpacity(0.15)
                                    : (isDark ? AppColors.surfaceDark : Colors.white)),
                            side: BorderSide(
                              color: isPronunciation && _pronunciationMode
                                  ? AppColors.primary
                                  : (isEvaluate && _writingEvalMode
                                      ? AppColors.primary
                                      : AppColors.primary.withOpacity(0.2)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            onPressed: () {
                              if (isPronunciation && _pronunciationMode) {
                                _stopPronunciationPractice();
                                return;
                              }
                              _messageController.text = action['prompt']!;
                              setState(() {
                                _suggestedQuestions = [];
                                if (isPronunciation) _pronunciationMode = true;
                                if (isEvaluate) _writingEvalMode = true;
                              });
                              _sendMessage();
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

          // Pronunciation Practice Card (Compact)
          if (_pronunciationMode && _pronunciationSentence.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.borderDark : Colors.grey[100]!,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.record_voice_over_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      const Text('Practice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      InkWell(
                        onTap: _stopPronunciationPractice,
                        child: Icon(Icons.close_rounded, size: 16, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Text(
                      _pronunciationSentence,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: _buildPronButton(
                        icon: _isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                        label: _isPlaying ? 'Stop' : 'Listen',
                        color: AppColors.primary,
                        onTap: () => _isPlaying ? _stopSpeaking() : _speakSentence(_pronunciationSentence),
                      )),
                      const SizedBox(width: 6),
                      Expanded(child: _buildPronButton(
                        icon: _userSpeechResult.isNotEmpty ? Icons.check_circle_rounded : Icons.mic_rounded,
                        label: _userSpeechResult.isNotEmpty ? 'Done' : 'Speak',
                        color: _userSpeechResult.isNotEmpty ? Colors.green : Colors.orange,
                        onTap: () => _userSpeechResult.isNotEmpty ? setState(() => _userSpeechResult = '') : _startPronunciationListening(),
                      )),
                      if (_pronunciationAccuracy != null) ...[
                        const SizedBox(width: 6),
                        Expanded(child: _buildPronButton(
                          icon: _pronunciationAccuracy! >= 70 ? Icons.emoji_events_rounded : Icons.trending_up_rounded,
                          label: '${_pronunciationAccuracy!.toInt()}%',
                          color: _pronunciationAccuracy! >= 70 ? Colors.green : Colors.orange,
                          onTap: null,
                        )),
                      ],
                    ],
                  ),
                  if (_userSpeechResult.isNotEmpty && _pronunciationAccuracy == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: _stopPronunciationListening,
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Check Accuracy', style: TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                ],
              ),
            ),

          // Message input bar with suggestions below
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
                    // Voice Input - Hold to Talk
                    GestureDetector(
                      onTapDown: (_) {
                        if (!_isListening) _startListening();
                      },
                      onTapUp: (_) {
                        if (_isListening) _stopListening();
                      },
                      onTapCancel: () {
                        if (_isListening) _stopListening();
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isListening
                              ? Colors.red
                              : (isDark ? Colors.white12 : Colors.grey[300]),
                          border: _isListening
                              ? Border.all(color: Colors.redAccent, width: 2)
                              : null,
                          boxShadow: _isListening
                              ? [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              _isListening
                                  ? Icons.mic_rounded
                                  : Icons.mic_none_rounded,
                              color: _isListening
                                  ? Colors.white
                                  : (isDark ? Colors.white54 : Colors.black54),
                              size: 20,
                            ),
                            // Confidence indicator ring
                            if (_isListening)
                              Positioned(
                                bottom: 6,
                                child: Container(
                                  width: 16,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: _voiceConfidence > 0.7
                                        ? Colors.green
                                        : _voiceConfidence > 0.4
                                            ? Colors.orange
                                            : Colors.red,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                          ],
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
