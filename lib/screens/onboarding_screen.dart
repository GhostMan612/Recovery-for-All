// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/screens/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import '../database/recovery_database.dart';
import '../services/recovery_pet_service.dart';
import '../widgets/themed_background.dart';
import '../widgets/avatar_visual_layer.dart';
import '../services/pet_cosmetic_catalog.dart';

class OnboardingScreen extends StatefulWidget {
  final RecoveryDatabase database;
  final VoidCallback onOnboardingComplete;
  
  const OnboardingScreen({
    super.key,
    required this.database,
    required this.onOnboardingComplete,
  });
  
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isFinalizing = false;
  
  // State Data
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _sponsorPhoneController = TextEditingController();
  final Set<String> _selectedGoals = {};
  final Set<String> _selectedPaths = {};
  final Set<String> _selectedTools = {};
  final Set<String> _selectedCoreValues = {};
  double _stressResponse = 0.5;
  double _coachTone = 0.6;
  double _spiritualOpenness = 0.5;

  static const int _valuesStepIndex = 4;
  static const int _lastStepIndex = 6;

  String? _selectedPreset;
  RecoveryPet? _draftPet;

  // Blueprint Data Pools
  final List<String> _goalsPool = [
    'Alcohol', 'Opioids', 'Nicotine', 'Cannabis', 'Stimulants',
    'Prescription Meds', 'Vaporizers', 'Gambling', 'Gaming', 'Self-Harm'
  ];

  final List<String> _coreValuesPool = const [
    'Self-Direction', 'Benevolence', 'Universalism', 'Security', 'Tradition',
    'Conformity', 'Hedonism', 'Achievement', 'Power', 'Stimulation',
  ];

  final Map<String, String> _pathwaysPool = {
    '12-Step (AA/NA)': 'Traditional step-based community and sponsorship.',
    'SMART Recovery': 'CBT-based practical tools for behavior change.',
    'Recovery Dharma': 'Buddhist-inspired mindfulness and meditation.',
    'Wellbriety': 'Indigenous cultural teachings and Medicine Wheel.',
    'Secular/Agnostic': 'Science-based, non-spiritual approaches.',
    'Clinical/Therapy': 'Professional psychological support and CBT.'
  };

  final Map<String, String> _toolsPool = {
    'Urge Surfing Timer': 'Visual tool to ride out cravings.',
    'Daily Reflections': 'Morning readings and intentions.',
    'Cost-Benefit Analysis': 'SMART tool to weigh choices.',
    'Medicine Wheel': 'Track balance across 4 quadrants.',
    'Meeting Finder': 'Locate local and virtual rooms.',
    'Encrypted Journal': 'Private space for deep reflection.',
  };

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    _sponsorPhoneController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == _valuesStepIndex && _selectedCoreValues.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick at least 3 values that guide you.'),
          backgroundColor: Color(0xFF1E293B),
        ),
      );
      return;
    }
    if (_currentStep < _lastStepIndex) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else if (!_isFinalizing) {
      _finalizeOnboarding();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finalizeOnboarding() async {
    setState(() => _isFinalizing = true);
    try {
      final profile = Profile(
        id: 'active_user_profile',
        anonymousUsername: _usernameController.text.isNotEmpty
            ? _usernameController.text.trim()
            : 'Anonymous',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        biometricLockEnabled: false,
        selectedGoals: jsonEncode(_selectedGoals.toList()),
        activePaths: jsonEncode(_selectedPaths.toList()),
        selectedValues: jsonEncode(_selectedTools.toList()), // Storing tools in values column for MVP
        sponsorPhone: _sponsorPhoneController.text.trim().isEmpty
            ? null
            : _sponsorPhoneController.text.trim(),
        customHelpPhone: null,
        personalityJson: jsonEncode({
          'coreValues': _selectedCoreValues.toList(),
          'stressResponse': _stressResponse,
          'coachTone': _coachTone,
          'spiritualOpenness': _spiritualOpenness,
        }),
      );
      
      // 1. Provision Local Drift Database
      await widget.database.saveProfile(profile);

      // 2. Hatch Local Companion
      await RecoveryPetService.ensureHatched(
        name: _usernameController.text.isNotEmpty
            ? _usernameController.text.trim()
            : null,
      );
      if (_selectedPreset != null) {
        await RecoveryPetService.applyStarterPreset(_selectedPreset!);
      }
      if (_draftPet != null) {
        await RecoveryPetService.save(_draftPet!);
      }

      // 3. Complete and Route to Dashboard
      widget.onOnboardingComplete();
    } catch (e) {
      setState(() => _isFinalizing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing platform: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ThemedBackground(
        enableKenBurns: _currentStep == 0,
        scrimOpacity: 0.85,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildStep0Welcome(),
                        _buildStep1Goals(),
                        _buildStep2Paths(),
                        _buildStep3Tools(),
                        _buildStep4Values(),
                        _buildStep5Dynamics(),
                        _buildStep6Avatar(),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentStep > 0)
                          TextButton(
                            onPressed: _isFinalizing ? null : _previousStep,
                            child: const Text('Back', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16)),
                          )
                        else
                          const SizedBox(width: 64),
                        ElevatedButton(
                          onPressed: _isFinalizing ? null : _nextStep,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF38BDF8),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                          child: Text(
                            _currentStep < _lastStepIndex ? 'Next' : 'Initialize Platform',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_isFinalizing)
                Container(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF38BDF8)),
                        SizedBox(height: 24),
                        Text(
                          'Constructing Your Path...',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Encrypting databases & hatching companion',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
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
  }

  Widget _buildStep0Welcome() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.terrain, size: 80, color: Color(0xFF38BDF8)),
          const SizedBox(height: 32),
          const Text(
            'The Path You Build.',
            style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, height: 1.2),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const Text(
            'Recovery is deeply personal. No single program holds the monopoly on healing. This space is yours to build the exact combination of practices, teachings, and supports that keep you well.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline, color: Color(0xFF34D399)),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Zero-Knowledge Environment. Your data stays securely encrypted on this device.',
                    style: TextStyle(color: Color(0xFF34D399), fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStep1Goals() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Focus Areas', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          const Text('What are we overcoming?', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('Select all that apply. Your counters will be built based on these.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16)),
          const SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12.0,
                runSpacing: 16.0,
                children: _goalsPool.map((goal) {
                  final isSelected = _selectedGoals.contains(goal);
                  return FilterChip(
                    label: Text(goal, style: const TextStyle(fontSize: 15)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedGoals.add(goal);
                        } else {
                          _selectedGoals.remove(goal);
                        }
                      });
                    },
                    selectedColor: const Color(0xFF38BDF8),
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF94A3B8), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                    backgroundColor: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Paths() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Communities', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          const Text('Select Your Pathways', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('Mix and match. We will use these to find meetings and filter literature.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16)),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: _pathwaysPool.keys.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final path = _pathwaysPool.keys.elementAt(index);
                final desc = _pathwaysPool[path]!;
                final isSelected = _selectedPaths.contains(path);
                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedPaths.remove(path);
                      } else {
                        _selectedPaths.add(path);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF38BDF8).withValues(alpha: 0.15) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF38BDF8) : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(path, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(desc, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                            ],
                          ),
                        ),
                        if (isSelected) const Icon(Icons.check_circle, color: Color(0xFF38BDF8)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Tools() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('The Toolbox', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          const Text('Assemble Your Dashboard', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('Toggle the specific tools you want readily available on your home screen.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16)),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: _toolsPool.keys.length,
              separatorBuilder: (_, __) => const Divider(color: Color(0xFF334155)),
              itemBuilder: (context, index) {
                final tool = _toolsPool.keys.elementAt(index);
                final desc = _toolsPool[tool]!;
                final isSelected = _selectedTools.contains(tool);
                return SwitchListTile(
                  title: Text(tool, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text(desc, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  value: isSelected,
                  activeColor: const Color(0xFF38BDF8),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (bool value) {
                    setState(() {
                      if (value) {
                        _selectedTools.add(tool);
                      } else {
                        _selectedTools.remove(tool);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4Values() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Compass', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          const Text('What Guides You?', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            'Choose 3 to 5 core values. These shape how your coach speaks and what your path celebrates.',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
          const SizedBox(height: 16),
          Text(
            '${_selectedCoreValues.length} of 5 selected · minimum 3',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12.0,
                runSpacing: 16.0,
                children: _coreValuesPool.map((value) {
                  final isSelected = _selectedCoreValues.contains(value);
                  return FilterChip(
                    label: Text(value, style: const TextStyle(fontSize: 15)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          if (_selectedCoreValues.length >= 5) return;
                          _selectedCoreValues.add(value);
                        } else {
                          _selectedCoreValues.remove(value);
                        }
                      });
                    },
                    selectedColor: const Color(0xFF38BDF8),
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF94A3B8), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                    backgroundColor: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep5Dynamics() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Safety & Identity', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            const Text('Personal Dynamics', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            const Text('Anonymous Alias (Optional)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _usernameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'What should your companion call you?',
                hintStyle: const TextStyle(color: Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Sponsor / Lifeline Phone (Optional)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _sponsorPhoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'For the immediate SOS dialer.',
                hintStyle: const TextStyle(color: Color(0xFF64748B)),
                prefixIcon: const Icon(Icons.phone, color: Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 32),
            const Text('Base Stress Response', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('How do you typically react under immense pressure?', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            const SizedBox(height: 16),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: const Color(0xFF38BDF8),
                inactiveTrackColor: const Color(0xFF334155),
                thumbColor: Colors.white,
                overlayColor: const Color(0xFF38BDF8).withValues(alpha: 0.2),
              ),
              child: Slider(
                value: _stressResponse,
                onChanged: (val) => setState(() => _stressResponse = val),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Isolate / Withdraw', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                Text('Reactive / Impulsive', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ],
            ),
            const SizedBox(height: 32),
            const Text('Coach Tone', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('How direct should your coach be when things get hard?', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            const SizedBox(height: 16),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: const Color(0xFF38BDF8),
                inactiveTrackColor: const Color(0xFF334155),
                thumbColor: Colors.white,
                overlayColor: const Color(0xFF38BDF8).withValues(alpha: 0.2),
              ),
              child: Slider(
                value: _coachTone,
                onChanged: (val) => setState(() => _coachTone = val),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Gentle & Soft', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                Text('Direct & Grounded', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ],
            ),
            const SizedBox(height: 32),
            const Text('Spiritual Openness', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('How much spiritual framing feels right for you?', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            const SizedBox(height: 16),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: const Color(0xFF38BDF8),
                inactiveTrackColor: const Color(0xFF334155),
                thumbColor: Colors.white,
                overlayColor: const Color(0xFF38BDF8).withValues(alpha: 0.2),
              ),
              child: Slider(
                value: _spiritualOpenness,
                onChanged: (val) => setState(() => _spiritualOpenness = val),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Secular / Practical', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                Text('Deeply Spiritual', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep6Avatar() {
    final presets = RecoveryPetService.starterPresets.keys.toList();
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('The Guide', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          const Text('Your Companion', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Pick a starter look. You can earn sparks to unlock everything else later.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
          const SizedBox(height: 24),
          if (_draftPet != null)
            Center(child: AvatarVisualLayer(pet: _draftPet!, size: 140))
          else
            const Center(child: SizedBox(height: 140, child: Icon(Icons.auto_awesome, size: 64, color: Color(0xFF334155)))),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: presets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final id = presets[index];
                final emoji = PetCosmeticCatalog.presetEmojis[id] ?? '✨';
                final reaction = PetCosmeticCatalog.presetReactions[id] ?? 'A steady presence.';
                final selected = _selectedPreset == id;
                return InkWell(
                  onTap: () async {
                    setState(() => _selectedPreset = id);
                    var pet = await RecoveryPetService.ensureHatched(
                      name: _usernameController.text.isNotEmpty ? _usernameController.text.trim() : null,
                    );
                    pet = await RecoveryPetService.applyStarterPreset(id);
                    setState(() => _draftPet = pet);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF38BDF8).withValues(alpha: 0.1) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected ? const Color(0xFF38BDF8) : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 32)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                id[0].toUpperCase() + id.substring(1),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(reaction, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                            ],
                          ),
                        ),
                        if (selected) const Icon(Icons.check_circle, color: Color(0xFF38BDF8)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}