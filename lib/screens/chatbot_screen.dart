// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import '../services/ollama_service.dart';
import '../services/safety_guardrail_service.dart';
import '../database/recovery_database.dart';

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
      setState(() {
        _isLoading = false;
      });

      final entry = JournalEntry(
        id: UniqueKey().toString(),
        timestamp: DateTime.now().millisecondsSinceEpoch,
        moodRating: 1,
        contentEncrypted: '[CRISIS GUARDRAIL TRIGGERED: ${assessment.matchedPattern}]',
        isSyncedToCloud: false,
      );
      await widget.database.addJournalEntry(entry);

      if (mounted) {
        _showSOSBottomSheet(context);
      }
      return;
    }

    try {
      final String chatPrompt = """
REALITY FILTER: ON
You are a non-sycophantic recovery companion chatbot.
Adhere strictly to evidence-based modalities like Motivational Interviewing (MI), CBT, and Wellbriety.
Do not provide medical diagnoses or flatter the user. Challenge unhelpful assumptions.
Factual truth always takes precedence over user agreement.
Respond directly and concisely:
$text
""";

      final ollama = OllamaService(
        baseUrl: 'http://192.168.4.144:8000',
        modelName: 'qwen2.5',
      );

      final botResponse = await ollama.generateResponse(chatPrompt);

      final journal = JournalEntry(
        id: UniqueKey().toString(),
        timestamp: DateTime.now().millisecondsSinceEpoch,
        moodRating: 3,
        contentEncrypted: text,
        isSyncedToCloud: false,
      );
      await widget.database.addJournalEntry(journal);

      setState(() {
        _messages.add({'sender': 'bot', 'text': botResponse});
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'sender': 'bot',
          'text': 'Network Error: Cannot reach local AI. Details: $e'
        });
        _isLoading = false;
      });
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
                'You are never alone on this path. Our private local AI has detected that you may be going through an intense struggle. We have paused automated chat to make sure you have direct, secure connection to professional care.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {},
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
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF38BDF8),
                  side: const BorderSide(color: Color(0xFF38BDF8)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.people_outline),
                label: const Text('Contact Support Sponsor'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Recovery Companion'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Ask for support, reflection, or a next step.',
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

                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: isUser ? const Color(0xFF38BDF8) : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            message['text'] as String,
                            style: TextStyle(
                              color: isUser ? Colors.white : const Color(0xFFE2E8F0),
                            ),
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
