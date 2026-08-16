// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================
import 'package:flutter/material.dart';
import 'dart:convert';
import '../database/recovery_database.dart';
import '../services/recovery_pet_service.dart';
import '../widgets/themed_background.dart';

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
  final Set<String> _selectedGoals = {};
  final Set<String> _selectedPaths = {};
  final List<String> _selectedValues = [];
  double _stressResponse = 0.5;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _sponsorPhoneController = TextEditingController();
  final List<String> _goalsPool = [
    'Alcohol', 'Opioids', 'Nicotine', 'Cannabis', 'Stimulants',
    'Prescription Meds', 'Vaporizers', 'Gambling', 'Gaming'
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    _sponsorPhoneController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 7) {
      setState(() {
        _currentStep++;
      });
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
      setState(() {
        _currentStep--;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finalizeOnboarding() async {
    setState(() {
      _isFinalizing = true;
    });
    try {
      final profile = Profile(
        id: 'active_user_profile',
        anonymousUsername: _usernameController.text.isNotEmpty
            ? _usernameController.text
            : 'Anonymous',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        biometricLockEnabled: false,
        selectedGoals: jsonEncode(_selectedGoals.toList()),
        activePaths: jsonEncode(_selectedPaths.toList()),
        selectedValues: jsonEncode(_selectedValues),
        sponsorPhone: _sponsorPhoneController.text.trim().isEmpty
            ? null
            : _sponsorPhoneController.text.trim(),
        customHelpPhone: null,
      );
      await widget.database.saveProfile(profile);

      // Hatch Path Companion
      await RecoveryPetService.ensureHatched(
        name: _usernameController.text.isNotEmpty ? null : 'Kin',
      );

      widget.onOnboardingComplete();
    } catch (e) {
      setState(() {
        _isFinalizing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
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
        scrimOpacity: 0.75,
        child: Column(
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
                  _buildStep5Purpose(),
                  _buildStep6Dynamics(),
                  _buildStep7Provisioning(),
                ],
              ),
            ),
            if (_currentStep < 7) _buildNavigationControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationControls() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _previousStep,
              child: const Text('Back', style: TextStyle(color: Color(0xFF94A3B8))),
            )
          else
            const SizedBox(width: 64),
          ElevatedButton(
            onPressed: _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.white,
            ),
            child: Text(_currentStep == 6 ? 'Build My Path' : 'Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildStep0Welcome() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome back.\nRecovery is built one choice at a time.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24),
            Text(
              'We believe that recovery is deeply personal. No single program holds the monopoly on healing. This space is yours to build the combination of practices, teachings, and supports that keep you well.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
            ),
            SizedBox(height: 32),
            Text(
              'This app runs offline-first. Your entries, goals, and reflections are encrypted and saved strictly on your local device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF34D399), fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1Goals() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What are we focusing on?', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: Wrap(
              spacing: 8.0,
              runSpacing: 12.0,
              children: _goalsPool.map((goal) {
                final isSelected = _selectedGoals.contains(goal);
                return ChoiceChip(
                  label: Text(goal),
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
                  labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF94A3B8)),
                  backgroundColor: const Color(0xFF1E293B),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Paths() {
    return const Center(child: Text('Pathways Selection Placeholder', style: TextStyle(color: Colors.white)));
  }

  Widget _buildStep3Tools() {
    return const Center(child: Text('Toolbox Construction Placeholder', style: TextStyle(color: Colors.white)));
  }

  Widget _buildStep4Values() {
    return const Center(child: Text('Values Sorting Placeholder', style: TextStyle(color: Colors.white)));
  }

  Widget _buildStep5Purpose() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Choose an anonymous username', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _usernameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. Phoenix, SoberWarrior...',
              hintStyle: const TextStyle(color: Color(0xFF475569)),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Sponsor phone (optional)',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Used for one-tap Call / Text Sponsor in the SOS notification.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sponsorPhoneController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: 'e.g. 6125550199',
              hintStyle: const TextStyle(color: Color(0xFF475569)),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              prefixIcon: const Icon(Icons.phone, color: Color(0xFF64748B)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep6Dynamics() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('How do you process stress?', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Withdraw & Reflect', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              Text('Seek Accountability', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            ],
          ),
          Slider(
            value: _stressResponse,
            activeColor: const Color(0xFF38BDF8),
            onChanged: (val) {
              setState(() {
                _stressResponse = val;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep7Provisioning() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF38BDF8)),
            SizedBox(height: 24),
            Text(
              'Initializing Your Platform...',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Spinning up local Drift SQLite schemas and hatching your Path Companion.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}
