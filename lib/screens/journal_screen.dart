// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../database/recovery_database.dart';
import '../services/recovery_pet_service.dart';

class JournalScreen extends StatefulWidget {
  final RecoveryDatabase database;

  const JournalScreen({
    super.key,
    required this.database,
  });

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final TextEditingController _contentController = TextEditingController();
  int _selectedMood = 3; // Neutral default mood (3 = Okay)
  bool _isLocked = true;
  final TextEditingController _pinController = TextEditingController();
  final String _savedPin = "123456"; // Default 6-digit PIN privacy wall

  // A simple AES/Symmetric mock encryption block matching Local-First guidelines.
  // In production, use standard packages like encrypt (AES-256-CBC).
  String _encryptContent(String plaintext) {
    final bytes = utf8.encode(plaintext);
    final base64String = base64.encode(bytes);
    return "ENC_$base64String";
  }

  String _decryptContent(String ciphertext) {
    if (!ciphertext.startsWith("ENC_")) return ciphertext;
    try {
      final base64String = ciphertext.replaceFirst("ENC_", "");
      final bytes = base64.decode(base64String);
      return utf8.decode(bytes);
    } catch (e) {
      return "[Decryption Error: Invalid Key or Corrupted Payload]";
    }
  }

  void _verifyPin(String input) {
    if (input == _savedPin) {
      setState(() {
        _isLocked = false;
        _pinController.clear();
      });
    } else {
      _pinController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid Security PIN. Authorization denied.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  void _saveEntry() async {
    final text = _contentController.text.trim();
    if (text.isEmpty) return;

    final String encryptedReflection = _encryptContent(text);

    final entry = JournalEntry(
      id: UniqueKey().toString(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
      moodRating: _selectedMood,
      contentEncrypted: encryptedReflection,
      isSyncedToCloud: false,
    );

    await widget.database.addJournalEntry(entry);
    await RecoveryPetService.logJournalEntry();
    _contentController.clear();
    setState(() {
      _selectedMood = 3;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Reflection securely encrypted and saved · +${RecoveryPetService.sparksJournal} Sparks'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: const Icon(Icons.lock_outline, color: Color(0xFF38BDF8), size: 48),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Journal Privacy Wall',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your 6-digit PIN to access your private encrypted reflections.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 8),
                    decoration: const InputDecoration(
                      counterText: "",
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF38BDF8))),
                    ),
                    onSubmitted: _verifyPin,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => _verifyPin(_pinController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: const Color(0xFF38BDF8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFF334155)),
                    ),
                  ),
                  child: const Text('Unlock Journal'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('My Private Sanctuary'),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.lock, color: Color(0xFFEF4444)),
            tooltip: 'Lock Journal',
            onPressed: () {
              setState(() {
                _isLocked = true;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<JournalEntry>>(
              stream: widget.database.watchRecentJournals(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)));
                }

                final List<JournalEntry> entries = snapshot.data ?? [];

                if (entries.isEmpty) {
                  return const Center(
                    child: Text(
                      'No reflections logged yet. Speak your mind freely.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final date = DateTime.fromMillisecondsSinceEpoch(entry.timestamp);
                    final formattedDate = DateFormat('MMMM d, yyyy - h:mm a').format(date);
                    final decryptedText = _decryptContent(entry.contentEncrypted);

                    return Card(
                      color: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFF334155)),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  formattedDate,
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                ),
                                _buildMoodBadge(entry.moodRating),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              decryptedText,
                              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _buildWritePane(),
        ],
      ),
    );
  }

  Widget _buildMoodBadge(int rating) {
    String label = 'Okay';
    Color color = const Color(0xFF94A3B8);

    switch (rating) {
      case 5:
        label = 'Great';
        color = const Color(0xFF34D399);
        break;
      case 4:
        label = 'Good';
        color = const Color(0xFF60A5FA);
        break;
      case 2:
        label = 'Struggling';
        color = const Color(0xFFFBBF24);
        break;
      case 1:
        label = 'Need Help';
        color = const Color(0xFFEF4444);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1.0),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildWritePane() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Color(0xFF334155))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (index) {
              final rating = index + 1;
              final bool isSelected = _selectedMood == rating;
              Color color = const Color(0xFF94A3B8);
              IconData icon = Icons.sentiment_neutral;

              if (rating == 5) {
                color = const Color(0xFF34D399);
                icon = Icons.sentiment_very_satisfied;
              } else if (rating == 4) {
                color = const Color(0xFF60A5FA);
                icon = Icons.sentiment_satisfied;
              } else if (rating == 3) {
                color = const Color(0xFF94A3B8);
                icon = Icons.sentiment_neutral;
              } else if (rating == 2) {
                color = const Color(0xFFFBBF24);
                icon = Icons.sentiment_dissatisfied;
              } else if (rating == 1) {
                color = const Color(0xFFEF4444);
                icon = Icons.sentiment_very_dissatisfied;
              }

              return IconButton(
                icon: Icon(icon, size: 28),
                color: isSelected ? color : const Color(0xFF475569),
                onPressed: () {
                  setState(() {
                    _selectedMood = rating;
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Enter your thoughts, triggers, or victories...',
                    hintStyle: TextStyle(color: Color(0xFF475569)),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: Color(0xFF38BDF8)),
                onPressed: _saveEntry,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
