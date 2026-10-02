// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================
import 'package:flutter/material.dart';
import 'dart:convert';
import '../database/recovery_database.dart';
import '../services/recovery_pet_service.dart';

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
    {'rating': 1, 'emoji': '🥺', 'label': 'Struggling'},
    {'rating': 2, 'emoji': '😐', 'label': 'Okay'},
    {'rating': 3, 'emoji': '🙂', 'label': 'Good'},
    {'rating': 4, 'emoji': '😊', 'label': 'Great'},
    {'rating': 5, 'emoji': '😌', 'label': 'Serene'},
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

      final sparksBefore = (await RecoveryPetService.ensureHatched()).sparks;
      await widget.database.addJournalEntry(entry);
      await RecoveryPetService.logGratitude();
      final sparksDelta =
          (await RecoveryPetService.ensureHatched()).sparks - sparksBefore;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(sparksDelta > 0
                ? 'Gratitude saved · +$sparksDelta Sparks'
                : 'Gratitude saved'),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          ),
        );
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        title: Text('Daily Gratitude', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How are you feeling today?',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Wrap, not Row+spaceBetween: five fixed-width mood cells
              // overflowed on a 320dp device at the default text scale.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 8,
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
                        color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(mood['emoji'] as String, style: const TextStyle(fontSize: 24)),
                          const SizedBox(height: 4),
                          Text(
                            mood['label'] as String,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
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
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? CircularProgressIndicator(color: Theme.of(context).colorScheme.onSurface)
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
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 3,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13),
            fillColor: Theme.of(context).colorScheme.surfaceContainer,
            filled: true,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
