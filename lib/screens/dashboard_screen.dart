// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';
import '../database/recovery_database.dart';
import '../services/meeting_finder_service.dart';
import '../services/recovery_pet_service.dart';
import '../services/sos_notification_service.dart';
import 'avatar_dresser_screen.dart';
import 'chatbot_screen.dart';
import 'community_resources_screen.dart';
import 'community_feed_screen.dart';
import 'constellation_screen.dart';
import 'coping_tool_screen.dart';
import 'daily_reflection_screen.dart';
import 'gratitude_entry_screen.dart';
import 'grounding_screen.dart';
import 'journal_screen.dart';
import 'meeting_map_screen.dart';
import 'pet_home_screen.dart';
import 'settings_screen.dart';
import 'sober_housing_locator.dart';
import 'sobriety_counter_screen.dart';
import 'steps_viewer_screen.dart';
import 'daily_motivation_screen.dart';
import 'wellbriety_circles_screen.dart';
import 'weekly_goals_screen.dart';
import 'wellness_check_in_screen.dart';
import '../widgets/recovery_pet_card.dart';

class DashboardScreen extends StatefulWidget {
  final RecoveryDatabase database;

  const DashboardScreen({super.key, required this.database});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _defaultCenter = (39.7392, -104.9903); // neutral fallback center

  String _username = 'Friend';
  bool _isLoading = true;
  Profile? _profile;
  RecoveryPet? _pet;
  List<String> _paths = [];
  List<String> _tools = [];

  final MeetingFinderService _meetingFinder = MeetingFinderService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final profile = await widget.database.getProfile('active_user_profile');
    final pet = await RecoveryPetService.ensureHatched();

    if (!mounted) return;
    setState(() {
      _profile = profile;
      if (profile?.anonymousUsername?.isNotEmpty ?? false) {
        _username = profile!.anonymousUsername!;
      }
      List<String> decode(String? json) {
        if (json == null || json.isEmpty) return [];
        try {
          return (jsonDecode(json) as List).map((e) => e.toString()).toList();
        } catch (_) {
          return [];
        }
      }

      _paths = profile == null ? [] : decode(profile.activePaths);
      _tools = profile == null ? [] : decode(profile.selectedValues);
      _pet = pet;
      _isLoading = false;
    });
  }

  Future<void> _refreshPet() async {
    final pet = await RecoveryPetService.ensureHatched();
    if (mounted) setState(() => _pet = pet);
  }

  // ------------------------------------------------------------------
  // Pet check-in
  // ------------------------------------------------------------------

  Future<String?> showPetCheckInSheet(BuildContext context) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How are you feeling?',
                  style: TextStyle(color: Colors.white, fontSize: 20)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _moodButton(context, 'Great', Icons.sentiment_very_satisfied, Colors.green),
                  _moodButton(context, 'Okay', Icons.sentiment_neutral, Colors.amber),
                  _moodButton(context, 'Struggling', Icons.sentiment_very_dissatisfied, Colors.red),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _moodButton(BuildContext context, String label, IconData icon, Color color) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, color: color, size: 40),
          onPressed: () => Navigator.pop(context, label),
        ),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  Future<void> _handleCheckIn() async {
    final moodLabel = await showPetCheckInSheet(context);
    if (moodLabel == null) return;

    final mood = switch (moodLabel) {
      'Great' => PetMoodX.happy,
      'Struggling' => PetMoodX.sad,
      _ => PetMoodX.neutral,
    };
    final sparksBefore = (await RecoveryPetService.ensureHatched()).sparks;
    await RecoveryPetService.logCheckIn(mood: mood);
    await _refreshPet();
    final sparksDelta =
        (await RecoveryPetService.ensureHatched()).sparks - sparksBefore;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          moodLabel == 'Struggling'
              ? 'Thank you for telling us. Your companion is resting beside you.'
              : sparksDelta > 0
                  ? 'Checked in · +$sparksDelta Sparks'
                  : 'Checked in',
        ),
        backgroundColor: const Color(0xFF1E293B),
      ),
    );
    if (moodLabel == 'Struggling') {
      _showSosSheet();
    }
  }

  Future<void> _handleWalk() async {
    final before = _pet?.sparks ?? 0;
    await RecoveryPetService.logWalk();
    await _refreshPet();
    if (!mounted) return;
    final after = _pet?.sparks ?? before;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          after > before
              ? 'Walk logged · +${after - before} Sparks'
              : 'Walk appreciated · daily Sparks cap reached, see you tomorrow',
        ),
        backgroundColor: const Color(0xFF1E293B),
      ),
    );
  }

  void _openDresser() {
    final pet = _pet;
    if (pet == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AvatarDresserScreen(
          initialPet: pet,
          onChanged: (updated) {
            setState(() => _pet = updated);
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Toolbox
  // ------------------------------------------------------------------

  List<_ToolCard> _buildToolCards() {
    Widget screenFor(String tool) {
      switch (tool) {
        case 'Encrypted Journal':
          return JournalScreen(database: widget.database);
        case 'Daily Reflections':
          return DailyReflectionScreen(database: widget.database);
        case 'Urge Surfing Timer':
          return const GroundingScreen();
        case 'Cost-Benefit Analysis':
          return CopingToolScreen(database: widget.database);
        case 'Medicine Wheel':
          return ConstellationScreen(database: widget.database);
        default:
          return JournalScreen(database: widget.database);
      }
    }

    IconData iconFor(String tool) {
      switch (tool) {
        case 'Encrypted Journal':
          return Icons.lock_outline;
        case 'Daily Reflections':
          return Icons.menu_book_outlined;
        case 'Urge Surfing Timer':
          return Icons.self_improvement;
        case 'Cost-Benefit Analysis':
          return Icons.balance;
        case 'Meeting Finder':
          return Icons.map_outlined;
        case 'Medicine Wheel':
          return Icons.auto_awesome_outlined;
        default:
          return Icons.handyman_outlined;
      }
    }

    final cards = <_ToolCard>[];

    // Universal tools (blueprint §2.3): Journal, Gratitude, Counters,
    // Meeting Finder, SOS.
    cards.add(_ToolCard(
      label: 'Private Journal',
      subtitle: 'PIN-protected reflections',
      icon: Icons.lock_outline,
      onTap: () => _push(JournalScreen(database: widget.database)),
    ));
    cards.add(_ToolCard(
      label: 'Gratitude',
      subtitle: 'Three good things',
      icon: Icons.volunteer_activism_outlined,
      onTap: () => _push(GratitudeEntryScreen(database: widget.database)),
    ));
    cards.add(_ToolCard(
      label: 'Counters',
      subtitle: 'Your Day One clock',
      icon: Icons.timelapse,
      onTap: () => _push(SobrietyCounterScreen(database: widget.database)),
    ));
    cards.add(_ToolCard(
      label: 'Meeting Finder',
      subtitle: 'Rooms near and virtual',
      icon: Icons.map_outlined,
      onTap: _openMeetings,
    ));
    cards.add(_ToolCard(
      label: 'Sober Housing',
      subtitle: 'Structured homes directory',
      icon: Icons.home_work_outlined,
      onTap: () => _push(const SoberHousingLocatorScreen()),
    ));

    for (final tool in _tools) {
      if (tool == 'Encrypted Journal' || tool == 'Meeting Finder') continue;
      cards.add(_ToolCard(
        label: tool,
        subtitle: '',
        icon: iconFor(tool),
        onTap: () => _push(screenFor(tool)),
      ));
    }

    // Culturally specific pathway content, shown when selected onboarding.
    if (_paths.contains('Wellbriety')) {
      cards.add(_ToolCard(
        label: 'Wellbriety Circles',
        subtitle: 'White Bison gatherings',
        icon: Icons.circle_outlined,
        onTap: () => _push(const WellbrietyCirclesScreen()),
      ));
    }

    cards.add(_ToolCard(
      label: 'Wellness Check-In',
      subtitle: 'Six-dimension wheel',
      icon: Icons.donut_large_outlined,
      onTap: () => _push(WellnessCheckInScreen(database: widget.database)),
    ));
    cards.add(_ToolCard(
      label: 'Weekly Goals',
      subtitle: 'Small promises kept',
      icon: Icons.flag_outlined,
      onTap: () => _push(WeeklyGoalsScreen(database: widget.database)),
    ));
    cards.add(_ToolCard(
      label: 'The Twelve Steps',
      subtitle: 'A reader, any path',
      icon: Icons.menu_book_outlined,
      onTap: () => _push(const StepsViewerScreen()),
    ));
    cards.add(_ToolCard(
      label: 'Daily Motivation',
      subtitle: 'One reflection at a time',
      icon: Icons.wb_twilight_outlined,
      onTap: () => _push(const DailyMotivationScreen()),
    ));
    cards.add(_ToolCard(
      label: 'Companion Home',
      subtitle: 'Stats, outfits, care log',
      icon: Icons.pets_outlined,
      onTap: () => _push(PetHomeScreen(database: widget.database)),
    ));
    cards.add(_ToolCard(
      label: 'Community Support',
      subtitle: 'RCOs, meditations, online rooms',
      icon: Icons.volunteer_activism,
      onTap: () => _push(const CommunityResourcesScreen()),
    ));
    cards.add(_ToolCard(
      label: 'Recovery Circle',
      subtitle: 'Share shapes, not numbers',
      icon: Icons.forum_outlined,
      onTap: () => _push(CommunityFeedScreen(database: widget.database)),
    ));
    cards.add(_ToolCard(
      label: 'Recovery Coach',
      subtitle: 'Offline guidance, always here',
      icon: Icons.support_agent,
      onTap: () => _push(ChatbotScreen(database: widget.database)),
    ));
    return cards;
  }

  Future<void> _openMeetings() async {
    final meetings =
        await _meetingFinder.findNearbyMeetings(_defaultCenter.$1, _defaultCenter.$2);
    if (!mounted) return;
    _push(MeetingMapScreen(initialMeetings: meetings, database: widget.database));
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  // ------------------------------------------------------------------
  // SOS safety layer
  // ------------------------------------------------------------------

  Future<void> _callNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not dial $number from this device')),
      );
    }
  }

  void _showSosSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final sponsorPhone = _profile?.sponsorPhone;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'You are not alone.',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Immediate support, one tap away.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                _SosTile(
                  icon: Icons.phone_in_talk,
                  color: const Color(0xFFDC2626),
                  title: 'Call 988 Suicide & Crisis Lifeline',
                  subtitle: 'Free · 24/7 · Confidential',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    SosNotificationService.startPersistentSos();
                    _callNumber('988');
                  },
                ),
                _SosTile(
                  icon: Icons.person_pin_circle,
                  color: AppColors.accent,
                  title: sponsorPhone == null ? 'Call Sponsor' : 'Call Sponsor · $sponsorPhone',
                  subtitle: sponsorPhone == null ? 'Add a sponsor phone in Settings' : null,
                  enabled: sponsorPhone != null,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _callNumber(sponsorPhone!);
                  },
                ),
                _SosTile(
                  icon: Icons.groups_2,
                  color: AppColors.accent,
                  title: 'Nearest Meetings',
                  subtitle: 'Three rooms close to you right now',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final all = await _meetingFinder
                        .findNearbyMeetings(_defaultCenter.$1, _defaultCenter.$2)
                        .then((m) => m.take(3).toList());
                    if (!mounted) return;
                    _push(MeetingMapScreen(initialMeetings: all, database: widget.database));
                  },
                ),
                _SosTile(
                  icon: Icons.contacts_outlined,
                  color: AppColors.accent,
                  title: 'My Support Circle',
                  subtitle: 'Emergency contacts & settings',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _push(SettingsScreen(database: widget.database));
                  },
                ),
                _SosTile(
                  icon: Icons.open_in_new,
                  color: AppColors.textMuted,
                  title: 'Crisis Resources Online',
                  subtitle: '988lifeline.org',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    launchUrl(
                      Uri.parse('https://988lifeline.org'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8))),
      );
    }

    final pet = _pet;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Welcome, $_username', style: const TextStyle(color: Colors.white)),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: () => _push(SettingsScreen(database: widget.database)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_paths.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final path in _paths)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          path,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              if (pet != null)
                RecoveryPetCard(
                  pet: pet,
                  onCheckIn: _handleCheckIn,
                  onWalk: _handleWalk,
                  onOpen: _openDresser,
                ),
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Your Toolbox',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [for (final card in _buildToolCards()) card],
              ),
              const SizedBox(height: 90),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSosSheet,
        backgroundColor: const Color(0xFFDC2626),
        icon: const Icon(Icons.sos, color: Colors.white),
        label: const Text(
          'SOS Help',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ToolCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.accent, size: 28),
              const SizedBox(height: 10),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SosTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final bool enabled;
  final VoidCallback onTap;

  const _SosTile({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: enabled ? AppColors.bgCard : AppColors.bgCard.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            leading: Icon(icon, color: color),
            title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
            subtitle: subtitle == null
                ? null
                : Text(subtitle!, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
        ),
      ),
    );
  }
}
