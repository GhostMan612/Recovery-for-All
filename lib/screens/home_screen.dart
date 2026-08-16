// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';

class RecoveryHomeScreen extends StatefulWidget {
  final List<String> activePaths;
  final String username;

  const RecoveryHomeScreen({
    super.key,
    required this.activePaths,
    required this.username,
  });

  @override
  State<RecoveryHomeScreen> createState() => _RecoveryHomeScreenState();
}

class _RecoveryHomeScreenState extends State<RecoveryHomeScreen> {
  String? _selectedMood;
  final PageController _counterPageController = PageController();

  final List<Map<String, dynamic>> _sobrietyCounters = [
    {"label": "Alcohol", "days": 418, "time": "12h 04m"},
    {"label": "Nicotine", "days": 90, "time": "04h 32m"},
    {"label": "Self-Care Streak", "days": 12, "time": "20h 15m"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    expandedHeight: 80.0,
                    floating: false,
                    pinned: true,
                    elevation: 0,
                    backgroundColor: const Color(0xFFF7F9FB),
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                      title: Text(
                        "Welcome back, ${widget.username}",
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.bold,
                          fontSize: 16.0,
                        ),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: Colors.white,
                        child: Column(
                          children: [
                            SizedBox(
                              height: 180,
                              child: PageView.builder(
                                controller: _counterPageController,
                                itemCount: _sobrietyCounters.length,
                                itemBuilder: (context, index) {
                                  final counter = _sobrietyCounters[index];
                                  return _buildCounterPage(counter);
                                },
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                _sobrietyCounters.length,
                                (index) => Container(
                                  width: 8.0,
                                  height: 8.0,
                                  margin: const EdgeInsets.only(bottom: 12.0, left: 4.0, right: 4.0),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF1E293B).withValues(alpha: index == 0 ? 0.8 : 0.2),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "What does your recovery need today?",
                            style: TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMoodButton("😀", "Great", const Color(0xFFE2F0D9)),
                              _buildMoodButton("🙂", "Good", const Color(0xFFF2F5E8)),
                              _buildMoodButton("😐", "Okay", const Color(0xFFFEF9E7)),
                              _buildMoodButton("😞", "Struggling", const Color(0xFFFDEDEC)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(
                        _buildModularToolbox(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            _buildPersistentActionCenter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCounterPage(Map<String, dynamic> counter) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            counter["label"].toUpperCase(),
            style: const TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "${counter["days"]}",
                style: const TextStyle(
                  fontSize: 54.0,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "days",
                style: TextStyle(fontSize: 18.0, color: Color(0xFF64748B)),
              ),
            ],
          ),
          Text(
            counter["time"],
            style: const TextStyle(
              fontSize: 14.0,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodButton(String emoji, String label, Color bgColor) {
    final isSelected = _selectedMood == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMood = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : bgColor,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
          boxShadow: isSelected ? [const BoxShadow(color: Colors.black12, blurRadius: 4)] : null,
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildModularToolbox() {
    final List<Widget> list = [];
    
    list.add(
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          "Active Toolbox Components",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
      ),
    );

    if (widget.activePaths.contains("AA") || widget.activePaths.contains("NA")) {
      list.add(_buildPathTile("Twelve-Step Reading & Steps", "Pillar 2: Library", "📖", const Color(0xFFFEF3C7)));
    }
    if (widget.activePaths.contains("WELLBRIETY")) {
      list.add(_buildPathTile("Medicine Wheel & Grandfather Teachings", "Pillar 2: Toolbox", "🦬", const Color(0xFFD1FAE5)));
    }
    if (widget.activePaths.contains("DHARMA")) {
      list.add(_buildPathTile("15-Minute Guided Meditation Timer", "Pillar 2: Toolbox", "🧘", const Color(0xFFE0F2FE)));
    }
    if (widget.activePaths.contains("SMART")) {
      list.add(_buildPathTile("Cost/Benefit Analysis (CBA) Tool", "Pillar 2: Toolbox", "📊", const Color(0xFFF3E8FF)));
    }

    list.add(_buildPathTile("Gratitude Journaling Exercise", "Pillar 5: Growth", "📝", Colors.white));

    return list;
  }

  Widget _buildPathTile(String title, String subtitle, String iconEmoji, Color bgColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 1, offset: Offset(0, 1))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        leading: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Text(iconEmoji, style: const TextStyle(fontSize: 24)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF64748B)),
        onTap: () {},
      ),
    );
  }

  Widget _buildPersistentActionCenter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.location_on),
              label: const Text("Find Local Meeting"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => _showSOSBottomSheet(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("SOS", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSOSBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Emergency Support Routing",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "You are never alone on this path. If you are struggling, please connect with a live support representative immediately.",
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.phone_in_talk),
                label: const Text("Call 988 Crisis Lifeline (24/7)"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.star),
                label: const Text("Call Sponsor (Quick Dial)"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E293B),
                  side: const BorderSide(color: Color(0xFF1E293B)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}