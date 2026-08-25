// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../database/recovery_database.dart';
import '../services/journal_crypto_service.dart';
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

enum _JournalGate { loading, setupPin, confirmPin, unlock, open }

const int kPinDigits = JournalCryptoService.pinLength;

class _JournalScreenState extends State<JournalScreen> {
  final TextEditingController _contentController = TextEditingController();
  int _selectedMood = 3; // Neutral default mood (3 = Okay)
  _JournalGate _gate = _JournalGate.loading;
  final TextEditingController _pinController = TextEditingController();

  /// Master key held only for this unlocked session.
  Uint8List? _masterKey;
  String _firstEntryPin = '';
  bool _pinError = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final hasPin = await JournalCryptoService.hasPin();
    if (!mounted) return;
    setState(() {
      _gate = hasPin ? _JournalGate.unlock : _JournalGate.setupPin;
    });
  }

  Future<void> _submitPin(String pin) async {
    if (pin.length != JournalCryptoService.pinLength) {
      setState(() => _pinError = true);
      _pinController.clear();
      return;
    }
    switch (_gate) {
      case _JournalGate.setupPin:
        setState(() {
          _firstEntryPin = pin;
          _gate = _JournalGate.confirmPin;
          _pinError = false;
          _pinController.clear();
        });
      case _JournalGate.confirmPin:
        if (pin != _firstEntryPin) {
          setState(() {
            _firstEntryPin = '';
            _gate = _JournalGate.setupPin;
            _pinError = true;
            _pinController.clear();
          });
          return;
        }
        await JournalCryptoService.setPin(pin);
        await _openSession();
      case _JournalGate.unlock:
        final ok = await JournalCryptoService.verifyPin(pin);
        if (!ok) {
          setState(() {
            _pinError = true;
            _pinController.clear();
          });
          return;
        }
        await _openSession();
      default:
        break;
    }
  }

  Future<void> _openSession() async {
    final key = await JournalCryptoService.loadMasterKey();
    if (!mounted) return;
    setState(() {
      _masterKey = key;
      _gate = _JournalGate.open;
      _pinError = false;
      _pinController.clear();
    });
  }

  void _relock() {
    setState(() {
      _masterKey = null; // Key leaves memory with the lock.
      _gate = _JournalGate.unlock;
      _contentController.clear();
    });
  }

  Future<void> _saveEntry() async {
    final text = _contentController.text.trim();
    if (text.isEmpty || _masterKey == null) return;

    final encryptedReflection =
        await JournalCryptoService.encrypt(text, _masterKey!);

    final entry = JournalEntry(
      id: UniqueKey().toString(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
      moodRating: _selectedMood,
      contentEncrypted: encryptedReflection,
      isSyncedToCloud: false,
    );

    final sparksBefore = (await RecoveryPetService.ensureHatched()).sparks;
    await widget.database.addJournalEntry(entry);
    await RecoveryPetService.logJournalEntry();
    final sparksDelta =
        (await RecoveryPetService.ensureHatched()).sparks - sparksBefore;
    _contentController.clear();
    setState(() {
      _selectedMood = 3;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sparksDelta > 0
              ? 'Reflection securely encrypted and saved · +$sparksDelta Sparks'
              : 'Reflection securely encrypted and saved'),
        ),
      );
    }
  }

  Future<String> _decryptContent(String ciphertext) async {
    final key = _masterKey;
    if (key == null) {
      return JournalCryptoService.decryptLegacy(ciphertext) ??
          '[Locked — unlock the journal to read this entry]';
    }
    return await JournalCryptoService.decrypt(ciphertext, key) ??
        '[Encrypted entry could not be opened with this key]';
  }

  @override
  Widget build(BuildContext context) {
    if (_gate != _JournalGate.open) {
      final (title, hint, buttonLabel) = switch (_gate) {
        _JournalGate.loading => (
            'Journal Privacy Wall',
            'Checking your vault…',
            '…'
          ),
        _JournalGate.setupPin => (
            'Choose Your Journal PIN',
            'Pick a $kPinDigits-digit PIN to seal your sanctuary. '
                'You will enter it each time you return.',
            'Continue'
          ),
        _JournalGate.confirmPin => (
            'Confirm Your PIN',
            'Enter the same $kPinDigits digits once more.',
            'Seal My Journal'
          ),
        _JournalGate.unlock => (
            'Journal Privacy Wall',
            _pinError
                ? 'That PIN did not match. Try again.'
                : 'Enter your $kPinDigits-digit PIN to open your sanctuary.',
            'Unlock Journal'
          ),
        _JournalGate.open => ('', '', ''),
      };

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
                    border: Border.all(
                        color: _pinError
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF334155)),
                  ),
                  child: Icon(
                    _gate == _JournalGate.setupPin ||
                            _gate == _JournalGate.confirmPin
                        ? Icons.key
                        : Icons.lock_outline,
                    color: _pinError
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF38BDF8),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 24),
                if (_gate != _JournalGate.loading)
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: kPinDigits,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          letterSpacing: 8),
                      decoration: const InputDecoration(
                        counterText: "",
                        enabledBorder: UnderlineInputBorder(
                            borderSide:
                                BorderSide(color: Color(0xFF334155))),
                        focusedBorder: UnderlineInputBorder(
                            borderSide:
                                BorderSide(color: Color(0xFF38BDF8))),
                      ),
                      onSubmitted: _submitPin,
                    ),
                  ),
                const SizedBox(height: 24),
                if (_gate == _JournalGate.setupPin ||
                    _gate == _JournalGate.confirmPin ||
                    _gate == _JournalGate.unlock)
                  ElevatedButton(
                    onPressed: () => _submitPin(_pinController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: const Color(0xFF38BDF8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side:
                            const BorderSide(color: Color(0xFF334155)),
                      ),
                    ),
                    child: Text(buttonLabel),
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
            onPressed: _relock,
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
                            _EntryText(
                              future:
                                  _decryptContent(entry.contentEncrypted),
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

/// Decrypts lazily per card — AES-GCM auth happens off the build path.
class _EntryText extends StatelessWidget {
  final Future<String> future;

  const _EntryText({required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF334155)),
            ),
          );
        }
        return Text(
          snapshot.data ?? '[Encrypted entry could not be opened]',
          style:
              const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
        );
      },
    );
  }
}
