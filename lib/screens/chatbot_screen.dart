// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import '../services/ollama_service.dart';
import '../services/safety_guardrail_service.dart'; // Import Safety Service
import '../database/recovery_database.dart';

// ... (StatefulWidget boilerplate remains clean and unchanged)

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

    // 1. Run the input through the deterministic safety gate
    final SafetyAssessment assessment = SafetyGuardrailService.assessInput(text);

    if (assessment.isCrisisTriggered) {
      // 🚀 THE HARD HALT: Bypass the generative LLM entirely!
      setState(() {
        _isLoading = false;
      });

      // 2. Perform Data Minimization: Log a minimal risk event without sensitive transcript storage
      final entry = JournalEntry(
        id: UniqueKey().toString(),
        timestamp: DateTime.now().millisecondsSinceEpoch,
        moodRating: 1, // Minimum rating indicating critical crisis alert
        contentEncrypted: '[CRISIS GUARDRAIL TRIGGERED: ${assessment.matchedPattern}]',
        isSyncedToCloud: false,
      );
      await widget.database.addJournalEntry(entry);

      // 3. Immediately trigger the Emergency SOS sheet or route change
      if (mounted) {
        _showSOSBottomSheet(context);
      }
      return;
    }

    // 4. Safe input: Proceed with normal RAG-grounded dialog generation
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
                onPressed: () {
                  // TODO: Invoke native dialer to 988
                },
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
                onPressed: () {
                  // TODO: Invoke native dialer to sponsor phone number from DB
                },
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
  
  // ... rest of chatbot screen state logic remains pristine
}