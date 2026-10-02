import 'package:flutter/material.dart';
import '../database/recovery_database.dart';

class CopingToolScreen extends StatefulWidget {
  final RecoveryDatabase database;
  const CopingToolScreen({super.key, required this.database});
  @override
  State<CopingToolScreen> createState() => _CopingToolScreenState();
}

class _CopingToolScreenState extends State<CopingToolScreen> {
  int _selectedToolIndex = -1;

  final List<Map<String, dynamic>> _copingTools = [
    {
      'title': '5-4-3-2-1 Grounding',
      'description': 'Engage your senses to anchor yourself in the present moment',
      'steps': ['5 things you can see', '4 things you can touch', '3 things you can hear', '2 things you can smell', '1 thing you can taste'],
      'duration': '5-10 min',
      'icon': '🌍',
    },
    {
      'title': 'Box Breathing',
      'description': 'Calm your nervous system with controlled breathing',
      'steps': ['Breathe in for 4 counts', 'Hold for 4 counts', 'Breathe out for 4 counts', 'Hold for 4 counts', 'Repeat 5-10 times'],
      'duration': '5 min',
      'icon': '💨',
    },
    {
      'title': 'Progressive Muscle Relaxation',
      'description': 'Release tension by systematically tensing and relaxing muscles',
      'steps': ['Tense your toes for 5 seconds', 'Release and notice the difference', 'Move up through your body', 'Continue through entire body'],
      'duration': '10-15 min',
      'icon': '💪',
    },
    {
      'title': 'Urge Surfing',
      'description': 'Observe your urge without acting on it - it will pass',
      'steps': ['Notice the urge without judgment', 'Observe where you feel it in your body', 'Rate its intensity 1-10', 'Wait 15-20 minutes and rate again'],
      'duration': '20 min',
      'icon': '🌊',
    },
    {
      'title': 'Cold Water Immersion',
      'description': 'Use cold water to interrupt urges through sensory shift',
      'steps': ['Splash cold water on your face', 'Or hold ice cubes in your hands', 'Or take a cold shower', 'The sensory shock interrupts the urge cycle'],
      'duration': '1-5 min',
      'icon': '🧊',
    },
    {
      'title': 'Mindfulness Meditation',
      'description': 'Observe thoughts without judgment and return to breath',
      'steps': ['Find a comfortable position', 'Close your eyes and breathe naturally', 'When thoughts arise, acknowledge and let them pass', 'Return focus to your breath'],
      'duration': '10+ min',
      'icon': '🧘',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        elevation: 0,
        title: Text('Urge Coping Tools', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _selectedToolIndex == -1 ? _buildToolList() : _buildToolDetail(_copingTools[_selectedToolIndex]),
      ),
    );
  }

  Widget _buildToolList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose a coping strategy for managing urges', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Different tools work for different situations. Try several to find what resonates with you.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
          const SizedBox(height: 24),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _copingTools.length,
            itemBuilder: (context, index) {
              final tool = _copingTools[index];
              return GestureDetector(
                onTap: () => setState(() => _selectedToolIndex = index),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.outline),
                  ),
                  child: Row(
                    children: [
                      Text(tool['icon'] as String, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tool['title'] as String, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(tool['description'] as String, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('Duration: ${tool['duration']}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: Theme.of(context).colorScheme.outline, size: 16),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolDetail(Map<String, dynamic> tool) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back to tools',
                onPressed: () => setState(() => _selectedToolIndex = -1),
                icon: Icon(Icons.arrow_back,
                    color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(tool['title'] as String, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(tool['description'] as String, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.primary),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, color: Theme.of(context).colorScheme.primary, size: 16),
                const SizedBox(width: 8),
                Text('Duration: ${tool['duration']}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Step-by-Step Guide', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...(tool['steps'] as List<String>).asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(50)),
                    child: Center(child: Text('${entry.key + 1}', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(entry.value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, height: 1.5)),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              await widget.database.addJournalEntry(
                JournalEntry(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  contentEncrypted: 'Used ${tool['title']} coping tool',
                  moodRating: 5,
                  timestamp: DateTime.now().millisecondsSinceEpoch,
                  isSyncedToCloud: false,
                ),
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Coping activity logged to your journal')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary, minimumSize: const Size(double.infinity, 50)),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Log This Session', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
