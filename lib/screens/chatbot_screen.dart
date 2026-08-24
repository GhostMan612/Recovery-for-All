// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/screens/chatbot_screen.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'meeting_map_screen.dart';
import 'steps_viewer_screen.dart';
import 'worksheets_screen.dart';

import '../database/recovery_database.dart';
import '../services/recovery_coach_service.dart';
import '../services/coach_tflite_intent_service.dart';
import '../services/ollama_service.dart';
import '../services/safety_guardrail_service.dart';

class ChatbotScreen extends StatefulWidget {
  final RecoveryDatabase database;

  const ChatbotScreen({
    super.key,
    required this.database,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _preferDeepChat = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _isLoading = true;
    });

    final SafetyAssessment assessment = SafetyGuardrailService.assessInput(text);
    if (assessment.isCrisisTriggered) {
      setState(() => _isLoading = false);
      final entry = JournalEntry(
        id: UniqueKey().toString(),
        timestamp: DateTime.now().millisecondsSinceEpoch,
        moodRating: 1,
        contentEncrypted: '[CRISIS GUARDRAIL TRIGGERED: ${assessment.matchedPattern}]',
        isSyncedToCloud: false,
      );
      await widget.database.addJournalEntry(entry);
      if (mounted) _showSOSBottomSheet(context);
      return;
    }

    try {
      // Optional on-device model refines intents; skills + keywords remain
      // the floor. A confident "unknown" also falls back to keywords.
      final modelIntent = await CoachTfliteIntentService.classify(text);
      final CoachReply coachReply =
          (modelIntent == null || modelIntent == CoachIntent.unknown)
              ? (RecoveryCoachService.matchSkill(text) ??
                  await RecoveryCoachService.reply(text))
              : await RecoveryCoachService.replyFromIntent(modelIntent);

      if (coachReply.isCrisis) {
        setState(() {
          _messages.add({
            'sender': 'bot',
            'text': coachReply.message,
            'action': coachReply.action,
            'actionLabel': coachReply.actionLabel,
          });
          _isLoading = false;
        });
        if (mounted) _showSOSBottomSheet(context);
        return;
      }

      String botText = coachReply.message;

      if (_preferDeepChat) {
        try {
          final ollama = OllamaService(
            baseUrl: 'http://192.168.4.144:8000',
            modelName: 'qwen2.5',
          );
          final chatPrompt = '''
REALITY FILTER: ON
You are a non-sycophantic recovery companion chatbot.
Adhere strictly to evidence-based modalities like Motivational Interviewing (MI), CBT, and Wellbriety.
Do not provide medical diagnoses or flatter the user. Challenge unhelpful assumptions.
Factual truth always takes precedence over user agreement.
Scripted intent hint: ${coachReply.intent.name}
Respond directly and concisely:
$text
''';
          final deep = await ollama.generateResponse(chatPrompt);
          if (deep.trim().isNotEmpty) {
            botText = deep.trim();
          }
        } catch (_) {
          // keep scripted reply
        }
      }

      final journal = JournalEntry(
        id: UniqueKey().toString(),
        timestamp: DateTime.now().millisecondsSinceEpoch,
        moodRating: 3,
        contentEncrypted: text,
        isSyncedToCloud: false,
      );
      await widget.database.addJournalEntry(journal);

      setState(() {
        _messages.add({
          'sender': 'bot',
          'text': botText,
          'action': coachReply.action,
          'actionLabel': coachReply.actionLabel,
        });
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'sender': 'bot',
          'text': 'Coach unavailable. Try again or use SOS if you need help now.',
        });
        _isLoading = false;
      });
    }
  }

  Future<void> _runAction(CoachActionType action) async {
    await RecoveryCoachService.runAction(action);
    if (!mounted) return;
    switch (action) {
      case CoachActionType.openSos:
        _showSOSBottomSheet(context);
        break;
      case CoachActionType.openDresser:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Open the companion card on Home to use the dresser.')),
        );
        break;
      case CoachActionType.openSettings:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Open Settings to manage SOS contacts and 988.')),
        );
        break;
      case CoachActionType.openSteps:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                StepsViewerScreen(database: widget.database),
          ),
        );
        break;
      case CoachActionType.openWorksheets:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const WorksheetsScreen(),
          ),
        );
        break;
      case CoachActionType.openMeetings:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MeetingMapScreen(
              initialMeetings: const [],
              database: widget.database,
            ),
          ),
        );
        break;
      case CoachActionType.logGrounding:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grounding logged for your companion.')),
        );
        break;
      case CoachActionType.suggestCheckIn:
      case CoachActionType.suggestWalk:
      case CoachActionType.none:
        break;
    }
  }

  Future<void> _launch988() async {
    final uri = Uri.parse('tel:988');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showSOSBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 28),
                  SizedBox(width: 12),
                  Text(
                    'SOS Crisis Safety Gate',
                    style: TextStyle(color: Color(0xFFEF4444), fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'You are never alone on this path. Automated chat is paused so you can reach professional care.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _launch988,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.phone_in_talk),
                label: const Text('Call 988 Crisis Lifeline (24/7)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF38BDF8),
                  side: const BorderSide(color: Color(0xFF38BDF8)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.people_outline),
                label: const Text('Close — use SOS contacts in Settings'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _insertQuickPrompt(String prompt) {
    _messageController.text = prompt;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: prompt.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prompts = RecoveryCoachService.quickPrompts();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Recovery Companion'),
        actions: [
          IconButton(
            tooltip: _preferDeepChat ? 'Deep chat on (local Ollama)' : 'Scripted coach only',
            onPressed: () {
              setState(() => _preferDeepChat = !_preferDeepChat);
            },
            icon: Icon(
              _preferDeepChat ? Icons.psychology : Icons.chat_bubble_outline,
              color: _preferDeepChat ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: prompts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                return ActionChip(
                  label: Text(prompts[i], style: const TextStyle(fontSize: 12)),
                  backgroundColor: const Color(0xFF1E293B),
                  labelStyle: const TextStyle(color: Color(0xFFE2E8F0)),
                  onPressed: () => _insertQuickPrompt(prompts[i]),
                );
              },
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Offline coach ready. Ask about your companion, urges, SOS, or check-in.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isUser = message['sender'] == 'user';
                      final action = message['action'] as CoachActionType?;
                      final actionLabel = message['actionLabel'] as String?;

                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.78,
                          ),
                          decoration: BoxDecoration(
                            color: isUser ? const Color(0xFF38BDF8) : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message['text'] as String,
                                style: TextStyle(
                                  color: isUser ? Colors.white : const Color(0xFFE2E8F0),
                                ),
                              ),
                              if (!isUser &&
                                  action != null &&
                                  action != CoachActionType.none &&
                                  actionLabel != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF38BDF8),
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 32),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () => _runAction(action),
                                    child: Text(actionLabel),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      onSubmitted: (_) => _isLoading ? null : _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    onPressed: _isLoading ? null : _sendMessage,
                    backgroundColor: const Color(0xFF38BDF8),
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
