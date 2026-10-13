// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../database/recovery_database.dart';
import '../services/journal_crypto_service.dart';

class DailyReflectionScreen extends StatefulWidget {
  final RecoveryDatabase database;

  const DailyReflectionScreen({
    super.key,
    required this.database,
  });

  @override
  State<DailyReflectionScreen> createState() => _DailyReflectionScreenState();
}

class _DailyReflectionScreenState extends State<DailyReflectionScreen> with WidgetsBindingObserver {
  final TextEditingController _reflectionController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  int _selectedMood = 3;
  int _selectedGratitude = 0;
  List<String> _journalEntries = [];
  bool _isLoading = true;
  bool _isJournalLocked = false;
  bool _isVaultInaccessible = false;
  bool _pinError = false;

  final List<String> _moodLabels = ['Terrible', 'Bad', 'Okay', 'Good', 'Great'];
  final List<Color> _moodColors = AppColors.moodScale;

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
    WidgetsBinding.instance.addObserver(this);
    JournalCryptoService.sessionUnlockedNotifier.addListener(_onSessionUnlockChanged);
    _loadJournalEntries();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    JournalCryptoService.sessionUnlockedNotifier.removeListener(_onSessionUnlockChanged);
    _reflectionController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _onSessionUnlockChanged() {
    if (!JournalCryptoService.isSessionUnlocked && mounted) {
      setState(() {
        _isJournalLocked = true;
        _journalEntries = [];
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      JournalCryptoService.lockSession();
      if (mounted) {
        setState(() {
          _isJournalLocked = true;
          _journalEntries = [];
          _pinController.clear();
        });
      }
    }
  }

  Future<void> _loadJournalEntries() async {
    try {
      final status = await JournalCryptoService.checkPinStatus();
      if (status != JournalPinStatus.unconfigured && !JournalCryptoService.isSessionUnlocked) {
        if (mounted) {
          setState(() {
            _isJournalLocked = true;
            _isVaultInaccessible = (status == JournalPinStatus.corruptedOrInaccessible);
            _isLoading = false;
            _journalEntries = [];
          });
        }
        return;
      }

      final entries = await widget.database.getRecentJournals();
      // DECRYPT before display. This list previously rendered
      // `e.contentEncrypted` raw, so users saw ciphertext instead of their own
      // writing. Mirrors journal_screen.dart `_decryptContent`.
      final key = await JournalCryptoService.loadMasterKey(
        hasExistingEntries: entries.isNotEmpty,
      );
      // Opportunistically and idempotently upgrade any historical plaintext/legacy entries
      // if the master key was successfully verified. Non-destructive: fails closed.
      await JournalCryptoService.upgradeHistoricalEntries(
        widget.database,
        key,
      );
      final refreshed = await widget.database.getRecentJournals();
      final readable = <String>[];
      for (final e in refreshed) {
        // `decrypt` already falls back to `decryptLegacy` for pre-ENC2_ rows.
        final plain = await JournalCryptoService.decrypt(e.contentEncrypted, key);
        readable.add(plain ?? '[Locked \u2014 unlock the journal to read this entry]');
      }

      if (!mounted) return;
      if (status != JournalPinStatus.unconfigured && !JournalCryptoService.isSessionUnlocked) {
        setState(() {
          _isJournalLocked = true;
          _isLoading = false;
          _journalEntries = [];
        });
        return;
      }

      setState(() {
        _isJournalLocked = false;
        _isVaultInaccessible = false;
        _journalEntries = readable;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyAndUnlockPin(String pin) async {
    if (pin.length != JournalCryptoService.pinLength) {
      setState(() => _pinError = true);
      _pinController.clear();
      return;
    }
    final ok = await JournalCryptoService.verifyPin(pin);
    if (!ok) {
      if (mounted) {
        setState(() {
          _pinError = true;
          _pinController.clear();
        });
      }
      return;
    }
    JournalCryptoService.unlockSession();
    if (mounted) {
      setState(() {
        _isJournalLocked = false;
        _pinError = false;
        _pinController.clear();
        _isLoading = true;
      });
      await _loadJournalEntries();
    }
  }

  Future<void> _saveReflection() async {
    final text = _reflectionController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a reflection')),
      );
      return;
    }

    try {
      final entries = await widget.database.getRecentJournals();
      final masterKey = await JournalCryptoService.loadMasterKey(
        hasExistingEntries: entries.isNotEmpty,
      );
      final encryptedContent =
          await JournalCryptoService.encrypt(text, masterKey);

      final entry = JournalEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        contentEncrypted: encryptedContent,
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

        if (!_isJournalLocked) {
          _loadJournalEntries();
        }
      }
    } on MasterKeyInaccessibleException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Encryption key inaccessible. Existing journal data preserved: ${e.message}',
            ),
          ),
        );
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        elevation: 0,
        title: Text(
          'Daily Reflections',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How are you feeling today?',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
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
                    return Semantics(
                      button: true,
                      selected: isSelected,
                      label: _moodLabels[index],
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedMood = index;
                          });
                        },
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _moodColors[index].withValues(alpha: 0.3)
                                : Theme.of(context).colorScheme.surfaceContainer,
                            border: Border.all(
                              color: _moodColors[index],
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ExcludeSemantics(
                                child: Text(
                                  _getMoodEmoji(index),
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                              if (isSelected)
                                Text(
                                  _moodLabels[index],
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Choose today\'s reflection',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
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
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                        selectedColor: Theme.of(context).colorScheme.primary,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Your Reflection',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reflectionController,
                maxLines: 8,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Write your thoughts and feelings...',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.outline),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainer,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveReflection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Reflection', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Recent Reflections',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildRecentReflections(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentReflections() {
    if (_isJournalLocked) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _pinError || _isVaultInaccessible ? AppColors.moodNeedHelp : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          children: [
            Icon(
              _isVaultInaccessible ? Icons.error_outline : Icons.lock_outline,
              size: 36,
              color: _pinError || _isVaultInaccessible ? AppColors.moodNeedHelp : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              _isVaultInaccessible ? 'Vault Storage Inaccessible' : 'Past Reflections Locked',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isVaultInaccessible
                  ? 'Secure storage could not verify your PIN metadata. Past reflections remain sealed to protect your privacy.'
                  : _pinError
                      ? 'Incorrect PIN. Please try again.'
                      : 'Enter your 6-digit Journal PIN to view recent reflections.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _pinError || _isVaultInaccessible ? AppColors.moodNeedHelp : Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            if (!_isVaultInaccessible) ...[
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: JournalCryptoService.pinLength,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    letterSpacing: 6,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '\u2022\u2022\u2022\u2022\u2022\u2022',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      letterSpacing: 6,
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  onSubmitted: _verifyAndUnlockPin,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _verifyAndUnlockPin(_pinController.text),
                icon: const Icon(Icons.key, size: 18),
                label: const Text('Unlock Past Reflections'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: _loadJournalEntries,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry Vault Check'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
    }

    if (_journalEntries.isEmpty) {
      return Center(
        child: Text(
          'No reflections yet. Start by writing your first one!',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _journalEntries.length,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Text(
            _journalEntries[index],
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        );
      },
    );
  }

  String _getMoodEmoji(int index) {
    const emojis = ['\ud83d\ude22', '\ud83d\ude1e', '\ud83d\ude10', '\ud83d\ude0a', '\ud83d\ude04'];
    return emojis[index];
  }
}
