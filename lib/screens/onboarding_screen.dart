// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================
import 'package:flutter/material.dart';
import 'dart:convert';
import '../database/recovery_database.dart';
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
  final List<String> _goalsPool = [
    'Alcohol', 'Opioids', 'Nicotine', 'Cannabis', 'Stimulants', 
    'Prescription Meds', 'Vaporizers', 'Gambling', 'Gaming'
  ];
  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
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
        anonymousUsername: _usernameController.text.isNotEmpty ? _usernameController.text : 'Anonymous',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        biometricLockEnabled: false,
        selectedGoals: jsonEncode(_selectedGoals.toList()),
        activePaths: jsonEncode(_selectedPaths.toList()),
        selectedValues: jsonEncode(_selectedValues),
      );
      await widget.database.saveProfile(profile);
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
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
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
    final List<Map<String, String>> pathways = [
      {
        'name': 'AA (Alcoholics Anonymous)',
        'description': '12-step fellowship focused on spiritual principles',
        'icon': '📖'
      },
      {
        'name': 'SMART Recovery',
        'description': 'Science-based 4-point program for self-empowerment',
        'icon': '🧠'
      },
      {
        'name': 'Recovery Dharma',
        'description': 'Buddhist-inspired recovery with mindfulness practices',
        'icon': '🙏'
      },
      {
        'name': 'Wellbriety',
        'description': 'Native American healing and wellness approach',
        'icon': '🌿'
      },
      {
        'name': 'Secular/Custom',
        'description': 'Build your own path with resources you choose',
        'icon': '🛠️'
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What community alignments resonate with you?',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select one or more pathways that feel right for your recovery journey.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: pathways.length,
              itemBuilder: (context, index) {
                final pathway = pathways[index]['name']!;
                final isSelected = _selectedPaths.contains(pathway);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedPaths.remove(pathway);
                      } else {
                        _selectedPaths.add(pathway);
                      }
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF1F2937) : const Color(0xFF1E293B),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF475569),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(pathways[index]['icon']!, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pathway,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pathways[index]['description']!,
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: Color(0xFF38BDF8), size: 24),
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
    final List<Map<String, dynamic>> availableTools = [
      {
        'name': 'Private Journal',
        'description': 'Encrypted daily reflections & mood tracking',
        'icon': '📔',
        'category': 'reflection'
      },
      {
        'name': 'Recovery Companion AI',
        'description': 'Local AI for peer support & check-ins',
        'icon': '🤖',
        'category': 'support'
      },
      {
        'name': 'Meeting Finder',
        'description': 'Find local recovery meetings nearby',
        'icon': '📍',
        'category': 'connection'
      },
      {
        'name': 'Sobriety Counter',
        'description': 'Track multiple recovery milestones',
        'icon': '⏰',
        'category': 'milestone'
      },
      {
        'name': 'Urge Coping Tools',
        'description': 'Emergency crisis management techniques',
        'icon': '🛡️',
        'category': 'crisis'
      },
      {
        'name': 'Daily Gratitude',
        'description': 'Shift focus to abundance and growth',
        'icon': '🙌',
        'category': 'wellness'
      },
      {
        'name': 'Step Tracker',
        'description': 'Track recovery program steps progress',
        'icon': '🪜',
        'category': 'structure'
      },
      {
        'name': 'Wellness Wheel',
        'description': '6-dimension wellness assessment',
        'icon': '⚖️',
        'category': 'wellness'
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select your recovery toolbox',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose the tools that will support your unique recovery journey.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: availableTools.length,
              itemBuilder: (context, index) {
                final tool = availableTools[index];
                final toolName = tool['name'] as String;
                final isSelected = _selectedValues.contains(toolName);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedValues.remove(toolName);
                      } else {
                        _selectedValues.add(toolName);
                      }
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF1F2937) : const Color(0xFF1E293B),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF475569),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(tool['icon'] as String, style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 8),
                        Text(
                          toolName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isSelected)
                          const Padding(
                            padding: EdgeInsets.only(top: 4.0),
                            child: Icon(Icons.check_circle, color: Color(0xFF38BDF8), size: 16),
                          ),
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
  Widget _buildStep4Values() {
    // Schwartz framework of human values
    final List<String> valuesList = [
      'Compassion', 'Honesty', 'Integrity', 'Authenticity', 'Resilience',
      'Growth', 'Connection', 'Freedom', 'Purpose', 'Gratitude',
      'Forgiveness', 'Courage', 'Wisdom', 'Humility', 'Service',
      'Family', 'Creativity', 'Health', 'Joy', 'Peace',
      'Acceptance', 'Balance', 'Trust', 'Respect', 'Contribution',
      'Celebration', 'Learning', 'Mindfulness', 'Excellence', 'Love'
    ];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose your top 5 core values',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Selected: ${_selectedValues.length}/5',
            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: valuesList.map((value) {
                final isSelected = _selectedValues.contains(value);
                final canSelect = !isSelected && _selectedValues.length < 5;
                return GestureDetector(
                  onTap: canSelect || isSelected
                      ? () {
                          setState(() {
                            if (isSelected) {
                              _selectedValues.remove(value);
                            } else if (_selectedValues.length < 5) {
                              _selectedValues.add(value);
                            }
                          });
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF1E293B),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF38BDF8)
                            : (canSelect ? const Color(0xFF475569) : const Color(0xFF0F172A)),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      value,
                      style: TextStyle(
                        color: isSelected ? Colors.white : (canSelect ? Colors.white : const Color(0xFF475569)),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildStep5Purpose() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Create your recovery identity',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose an anonymous username for your recovery journey. This keeps your identity private while tracking your progress.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          ),
          const SizedBox(height: 32),
          const Text(
            'Anonymous username',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. Phoenix, SoberStar, StayStrong...',
              hintStyle: const TextStyle(color: Color(0xFF475569)),
              prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF94A3B8)),
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
          const SizedBox(height: 16),
          const Text(
            '💡 Tip: Choose something meaningful that reminds you of your commitment. This name is only visible to you.',
            style: TextStyle(color: Color(0xFF34D399), fontSize: 12, fontStyle: FontStyle.italic),
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
          const Text(
            'Understanding your stress response',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'How do you typically process stress or challenging emotions?',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF475569)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Inward',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Outward',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Slider(
                  value: _stressResponse,
                  activeColor: const Color(0xFF38BDF8),
                  inactiveColor: const Color(0xFF334155),
                  onChanged: (val) {
                    setState(() {
                      _stressResponse = val;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  _stressResponse < 0.5
                      ? 'You tend to reflect inwardly and process internally'
                      : 'You tend to seek connection and external accountability',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '💡 There\'s no right answer. This helps us suggest appropriate tools and community connections for your style.',
            style: TextStyle(color: Color(0xFF34D399), fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
  Widget _buildStep7Provisioning() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Color(0xFF38BDF8)),
            const SizedBox(height: 32),
            const Text(
              'Building Your Recovery Platform',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Initializing secure local storage...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF475569)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProvisioningStep('Drift SQLite Schema', _isFinalizing),
                  _buildProvisioningStep('Database Encryption', _isFinalizing),
                  _buildProvisioningStep('Privacy Configuration', _isFinalizing),
                  _buildProvisioningStep('Recovery Profile', _isFinalizing),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '🔒 All your data stays on your device. Always encrypted. Never shared.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF34D399), fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProvisioningStep(String label, bool isLoading) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                )
              : const Icon(Icons.check_circle, color: Color(0xFF34D399), size: 16),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
        ],
      ),
    );
  }
}