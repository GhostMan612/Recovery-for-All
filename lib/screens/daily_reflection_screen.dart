// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import '../database/recovery_database.dart';

class DailyReflectionScreen extends StatefulWidget {
  final RecoveryDatabase database;

  const DailyReflectionScreen({
    super.key,
    required this.database,
  });

  @override
  State<DailyReflectionScreen> createState() => _DailyReflectionScreenState();
}

class _DailyReflectionScreenState extends State<DailyReflectionScreen> {
  final TextEditingController _reflectionController = TextEditingController();
  int _selectedMood = 3;
  int _selectedGratitude = 0;
  List<String> _journalEntries = [];
  bool _isLoading = true;

  final List<String> _moodLabels = ['Terrible', 'Bad', 'Okay', 'Good', 'Great'];
  final List<Color> _moodColors = [
    const Color(0xFFEF4444),
    const Color(0xFFF97316),
    const Color(0xFFEAB308),
    const Color(0xFF10B981),
    const Color(0xFF3B82F6),
  ];

  final List<String> _reflectionPrompts = [
    'What am I grateful for today?',
    'What challenge did I overcome?',
    'How did I practice self-care today?',
    'What progress did I make in my recovery?',
    'How did I show up for myself today?',
    'What brought me joy today?',
    'How did I support someone else?',
    'What am I proud of today?',
  ];

  @override
  void initState() {
    super.initState();
    _loadJournalEntries();
  }

  Future<void> _loadJournalEntries() async {
    try {
      final entries = await widget.database.watchRecentJournals().first;
      if (mounted) {
        setState(() {
          _journalEntries = entries.map((e) => e.contentEncrypted).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveReflection() async {
    if (_reflectionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a reflection')),
      );
      return;
    }

    try {
      final entry = JournalEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        contentEncrypted: _reflectionController.text,
        moodRating: _selectedMood,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        isSyncedToCloud: false,
      );

      await widget.database.addJournalEntry(entry);

      if (mounted) {
        setState(() {
          _reflectionController.clear();
          _selectedMood = 3;
          _selectedGratitude = 0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reflection saved to your journal')),
        );

        _loadJournalEntries();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving reflection: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _reflectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text(
          'Daily Reflections',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How are you feeling today?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(5, (index) {
                    final isSelected = _selectedMood == index;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMood = index;
                        });
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _moodColors[index].withValues(alpha: 0.3)
                              : const Color(0xFF1E293B),
                          border: Border.all(
                            color: _moodColors[index],
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _getMoodEmoji(index),
                              style: const TextStyle(fontSize: 20),
                            ),
                            if (isSelected)
                              Text(
                                _moodLabels[index],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Choose today\'s reflection',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _reflectionPrompts.length,
                  itemBuilder: (context, index) {
                    final isSelected = _selectedGratitude == index;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(
                          _reflectionPrompts[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedGratitude = index;
                          });
                        },
                        backgroundColor: const Color(0xFF1E293B),
                        selectedColor: const Color(0xFF38BDF8),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Your Reflection',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reflectionController,
                maxLines: 8,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Write your thoughts and feelings...',
                  hintStyle: const TextStyle(color: Color(0xFF475569)),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF475569)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF475569)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveReflection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Reflection', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Recent Reflections',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
              else if (_journalEntries.isEmpty)
                const Center(
                  child: Text(
                    'No reflections yet. Start by writing your first one!',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _journalEntries.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF475569)),
                      ),
                      child: Text(
                        _journalEntries[index],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getMoodEmoji(int index) {
    const emojis = ['😢', '😞', '😐', '😊', '😄'];
    return emojis[index];
  }
}
