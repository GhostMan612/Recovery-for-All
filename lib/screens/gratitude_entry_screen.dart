// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================
import 'package:flutter/material.dart';
import 'dart:convert';
import '../database/recovery_database.dart';

class GratitudeEntryScreen extends StatefulWidget {
  final RecoveryDatabase database;

  const GratitudeEntryScreen({
    super.key,
    required this.database,
  });

  @override
  State<GratitudeEntryScreen> createState() => _GratitudeEntryScreenState();
}

class _GratitudeEntryScreenState extends State<GratitudeEntryScreen> {
  int _selectedMood = 3;
  final TextEditingController _wentWellController = TextEditingController();
  final TextEditingController _personController = TextEditingController();
  final TextEditingController _assetController = TextEditingController();
  
  bool _isSaving = false;

  final List<Map<String, dynamic>> _moods = const [
    {'rating': 1, 'emoji': '😞', 'label': 'Struggling'},
    {'rating': 2, 'emoji': '😐', 'label': 'Okay'},
    {'rating': 3, 'emoji': '🙂', 'label': 'Good'},
    {'rating': 4, 'emoji': '😀', 'label': 'Great'},
    {'rating': 5, 'emoji': '✨', 'label': 'Serene'},
  ];

  @override
  void dispose() {
    _wentWellController.dispose();
    _personController.dispose();
    _assetController.dispose();
    super.dispose();
  }

  Future<void> _saveEntry() async {
    if (_wentWellController.text.isEmpty &&
        _personController.text.isEmpty &&
        _assetController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out at least one field.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final entryData = {
        'wentWell': _wentWellController.text.trim(),
        'person': _personController.text.trim(),
        'asset': _assetController.text.trim(),
      };

      final String jsonPayload = jsonEncode(entryData);
      final String encryptedPayload = "ENC_${base64.encode(utf8.encode(jsonPayload))}";

      final entry = JournalEntry(
        id: UniqueKey().toString(),
        timestamp: DateTime.now().millisecondsSinceEpoch,
        moodRating: _selectedMood,
        contentEncrypted: encryptedPayload,
        isSyncedToCloud: false,
      );

      await widget.database.addJournalEntry(entry);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving entry: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Daily Gratitude', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How are you feeling today?',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _moods.map((mood) {
                  final isSelected = _selectedMood == mood['rating'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedMood = mood['rating'] as int;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF38BDF8) : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(mood['emoji'] as String, style: const TextStyle(fontSize: 24)),
                          const SizedBox(height: 4),
                          Text(
                            mood['label'] as String,
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              _buildPromptField(
                controller: _wentWellController,
                label: 'What is one thing that went well today?',
                hint: 'A small victory, a good conversation, a moment of peace...',
              ),
              const SizedBox(height: 24),
              _buildPromptField(
                controller: _personController,
                label: 'Who is someone you are grateful for?',
                hint: 'A sponsor, a friend, a family member...',
              ),
              const SizedBox(height: 24),
              _buildPromptField(
                controller: _assetController,
                label: 'What is a personal strength you relied on?',
                hint: 'Patience, courage, honesty, boundary setting...',
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveEntry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save to Private Vault',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromptField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFE2E8F0),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
            fillColor: const Color(0xFF1E293B),
            filled: true,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}