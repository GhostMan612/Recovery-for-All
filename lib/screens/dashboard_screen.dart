// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';
import '../database/recovery_database.dart';
import '../services/sos_notification_service.dart';
import 'chatbot_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  final RecoveryDatabase database;

  const DashboardScreen({super.key, required this.database});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _username = "GhostMan G";
  bool _isLoading = true;
  Profile? _profile;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final profile = await widget.database.getProfile('active_user_profile');

    if (mounted) {
      setState(() {
        _profile = profile;
        if (profile != null && profile.anonymousUsername != null) {
          _username = profile.anonymousUsername!;
        }
        _isLoading = false;
      });

      // Start persistent SOS if we have any contact numbers
      if (profile != null) {
        final hasContacts = (profile.sponsorPhone?.isNotEmpty ?? false) ||
            (profile.customHelpPhone?.isNotEmpty ?? false);
        if (hasContacts) {
          await SosNotificationService.startPersistentSos(
            sponsorPhone: profile.sponsorPhone,
            customHelpPhone: profile.customHelpPhone,
          );
        }
      }
    }
  }

  final List<Map<String, dynamic>> _dashboardTools = [
    {'title': 'Private Journal', 'icon': Icons.book_outlined, 'color': const Color(0xFF38BDF8)},
    {'title': 'Meeting Finder', 'icon': Icons.map_outlined, 'color': const Color(0xFF10B981)},
    {'title': 'Urge Coping', 'icon': Icons.shield_outlined, 'color': const Color(0xFFF59E0B)},
    {'title': 'Daily Gratitude', 'icon': Icons.favorite_border, 'color': const Color(0xFFF43F5E)},
    {'title': 'Step Tracker', 'icon': Icons.check_circle_outline, 'color': const Color(0xFF8B5CF6)},
    {'title': 'Reflections', 'icon': Icons.wb_sunny_outlined, 'color': const Color(0xFFEAB308)},
  ];

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text(
          'My Recovery Path',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.settings_outlined, color: Color(0xFF38BDF8)),
              tooltip: 'SOS & Support Settings',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(database: widget.database),
                  ),
                );
                // Reload in case numbers changed
                _loadUserData();
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF38BDF8)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatbotScreen(database: widget.database),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome back,',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                _username,
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF334155)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Intention',
                      style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '"Recovery is not one path. Recovery is the path you build."',
                      style: TextStyle(color: Colors.white, fontSize: 18, height: 1.4, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'My Toolbox',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemCount: _dashboardTools.length,
                itemBuilder: (context, index) {
                  final tool = _dashboardTools[index];
                  return InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Opening ${tool['title']}...')),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(tool['icon'] as IconData, size: 36, color: tool['color'] as Color),
                          const SizedBox(height: 12),
                          Text(
                            tool['title'] as String,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const Text('Emergency Assistance', style: TextStyle(color: Colors.white)),
              content: const Text(
                'You are not alone. Do you want to call the 988 Crisis Lifeline or contact your sponsor?',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
                  onPressed: () => Navigator.pop(context),
                ),
                TextButton(
                  child: const Text('Settings', style: TextStyle(color: Color(0xFF38BDF8))),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SettingsScreen(database: widget.database),
                      ),
                    );
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                  onPressed: () async {
                    Navigator.pop(context);
                    // Ensure notification is up; user can also tap 988 from shade
                    await SosNotificationService.startPersistentSos(
                      sponsorPhone: _profile?.sponsorPhone,
                      customHelpPhone: _profile?.customHelpPhone,
                    );
                  },
                  child: const Text('Call 988', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
        backgroundColor: const Color(0xFFDC2626),
        icon: const Icon(Icons.sos, color: Colors.white),
        label: const Text('SOS Help', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
