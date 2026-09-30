// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

import '../core/icon_registry.dart';
import '../core/dashboard_providers.dart';
import '../core/meeting_radius_logic.dart';
import '../core/theme/app_colors.dart';
import '../database/recovery_database.dart';
import '../services/community_feed_service.dart';
import '../services/meeting_finder_service.dart';
import '../services/feedback_service.dart';
import '../services/recovery_pet_service.dart';
import '../services/constellation_service.dart';
import '../services/sponsor_link_service.dart';
import '../services/sos_notification_service.dart';
import '../services/step_counter_service.dart';
import '../services/tutorial_chatbot_service.dart';
import 'avatar_dresser_screen.dart';
import 'chatbot_screen.dart';
import 'community_resources_screen.dart';
import 'community_feed_screen.dart';
import 'constellation_screen.dart';
import 'constellation_canvas_3d.dart';
import 'coping_tool_screen.dart';
import 'daily_reflection_screen.dart';
import 'gratitude_entry_screen.dart';
import 'grounding_screen.dart';
import 'journal_screen.dart';
import 'meeting_map_screen.dart';
import 'native_resources_screen.dart';
import 'literature_library_screen.dart';
import 'pet_home_screen.dart';
import 'settings_screen.dart';
import 'fellowship_sync_screen.dart';
import 'seventh_tradition_screen.dart';
import '../services/raid_service.dart';
import '../widgets/raid_boss_card.dart';
import '../widgets/skill_tree_modal.dart';
import 'sober_housing_locator.dart';
import 'sobriety_counter_screen.dart';
import 'steps_viewer_screen.dart';
import 'daily_motivation_screen.dart';
import 'wellbriety_circles_screen.dart';
import 'weekly_goals_screen.dart';
import 'wellness_check_in_screen.dart';
import '../widgets/walk_tracking_dialog.dart';
import '../widgets/tutorial_chatbot_dialog.dart';
import '../widgets/step_counter_card.dart';
import '../widgets/next_meeting_card.dart';
import '../widgets/dashboard_cards.dart';
import '../widgets/dashboard_sections.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final RecoveryDatabase database;
  final bool isFirstLaunch;

  const DashboardScreen({super.key, required this.database, this.isFirstLaunch = false});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  // Minnesota-first: when location permission is denied, the meeting finder
  // still reflects the state this app is built for (Twin Cities metro).
  static const _defaultCenter = (44.9778, -93.2650);


  // Constellation crown — the user's path, visible on open.
  List<ConstellationNode3D>? _skyNodes;

  // Ephemeral interaction state only. Everything persisted (card order, hidden
  // sets, radius preference, pledge, sky name) now lives in a notifier — see
  // lib/core/dashboard_providers.dart (Phase 7).
  bool _editingPath = false;
  bool _editingLibrary = false;

  final MeetingFinderService _meetingFinder = MeetingFinderService();

  DashboardLayout get _layout => ref.read(dashboardLayoutProvider);
  MeetingRadiusState get _radius => ref.read(meetingRadiusProvider);

  @override
  void initState() {
    super.initState();
    _tutorialChatbot = TutorialChatbotService.instance;
    // dashboardDataProvider loads profile + pet + raid on first watch.
    ref.watch(dashboardDataProvider);
    _loadSky();
    if (widget.isFirstLaunch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openTutorialChatbot();
      });
    }
  }

  List<ToolCard> _ordered(
      List<ToolCard> cards, List<String> order, Set<String> hidden) {
    return _layout.ordered(cards, (c) => c.label, order, hidden);
  }

  Future<void> _loadSky() async {
    try {
      final points = await widget.database.getConstellationPoints();
      final sorted = [...points]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('constellation_sky_name_v1') case final name?) {
        await ref.read(skyNameProvider.notifier).setName(name);
      }
      if (!mounted) return;
      setState(() {
        _skyNodes = sorted
            .map((p) => ConstellationNode3D(
                  id: p.id,
                  title: p.title,
                  category: p.category,
                  timestamp: DateTime.fromMillisecondsSinceEpoch(p.timestamp),
                  x: (p.positionX - 0.5) * 0.8,
                  y: (p.positionY - 0.5) * 0.6,
                  z: ((p.title.hashCode % 100) / 100 - 0.5) * 0.2,
                ))
            .toList();
      });
    } catch (_) {
      // The crown is decorative; never block the dashboard for it.
    }
  }

  /// Pathway → fellowship families for meeting tailoring.
  Set<String>? _allowedFellowships() {
    final set = <String>{};
    if (ref.watch(dashboardDataProvider).paths.contains('12-Step (AA/NA)')) set.addAll({'AA', 'NA'});
    if (ref.watch(dashboardDataProvider).paths.contains('Recovery Dharma')) set.add('Dharma');
    if (ref.watch(dashboardDataProvider).paths.contains('Wellbriety')) set.add('Wellbriety');
    return set.isEmpty ? null : set;
  }

  /// Real device location when permitted; neutral fallback otherwise.
  Future<(double, double)> _resolveLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _defaultCenter;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 8));
      unawaited(cacheLocation(pos.latitude, pos.longitude));
      return (pos.latitude, pos.longitude);
    } catch (_) {
      return _defaultCenter;
    }
  }

  Future<void> _refreshPet() async {
    await ref.read(dashboardDataProvider.notifier).refreshPet();
  }

  // ------------------------------------------------------------------
  // Pet check-in
  // ------------------------------------------------------------------

  Future<String?> showPetCheckInSheet(BuildContext context) async {
    return showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('How are you feeling?',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20)),
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
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
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
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      ),
    );
    if (moodLabel == 'Struggling') {
      _showSosSheet();
    }
  }

Future<void> _handleWalk() async {
    // Request activity recognition permission before starting walk
    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          content: const Text(
            'Activity recognition permission is required to track walks. Please enable it in settings.',
          ),
        ),
      );
      return;
    }

    // Start walk tracking
    await StepCounterService.instance.startWalkTracking();

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => WalkTrackingDialog(
        onStop: () async {
          await StepCounterService.instance.stopWalkTracking();
        },
        onFinish: () async {
          final verified = await StepCounterService.instance.stopWalkTracking();
          if (!verified) {
            if (!mounted) return false;
            if (!context.mounted) return false;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                content: const Text(
                  'Walk not verified — need at least 500 steps in 30 minutes. '
                  'Your companion understands, no Sparks this time.',
                ),
                action: SnackBarAction(
                  label: 'Override',
                  textColor: Theme.of(context).colorScheme.primary,
                  onPressed: () async {
                    await StepCounterService.instance.manuallyVerifyWalk();
                    await _completeWalk();
                  },
                ),
              ),
            );
            return false;
          }
          await _completeWalk();
          return true;
        },
      ),
    );

    if (confirmed == null) {
      await StepCounterService.instance.stopWalkTracking();
    }
    if (confirmed == true) {
      // Walk completed and verified
    }
  }

  Future<void> _completeWalk() async {
    final before = ref.watch(dashboardDataProvider).pet?.sparks ?? 0;
    await RecoveryPetService.logWalk(requireVerification: false);
    await ConstellationService.addWalkStar(widget.database);
    await _refreshPet();
    if (!mounted) return;
    final after = ref.watch(dashboardDataProvider).pet?.sparks ?? before;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        content: Text(
          after > before
              ? 'Walk verified · +${after - before} Sparks'
              : 'Walk appreciated · daily Sparks cap reached, see you tomorrow',
        ),
      ),
    );
  }

  void _openDresser() {
    final pet = ref.watch(dashboardDataProvider).pet;
    if (pet == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AvatarDresserScreen(
          initialPet: pet,
          onChanged: (updated) {
            unawaited(ref.read(dashboardDataProvider.notifier).setPet(updated));
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Daily pledge
  // ------------------------------------------------------------------

  Future<void> _confirmPledge() async {
    await ref.read(dailyPledgeProvider.notifier).markPledged();
    await FeedbackService.selection();
  }

  // ------------------------------------------------------------------
  // Toolbox
  // ------------------------------------------------------------------

  List<ToolCard> _buildToolCards() {
    Widget screenFor(String tool) {
      switch (tool) {
        case 'Encrypted Journal':
          return JournalScreen(database: widget.database);
        case 'Daily Reflections':
          return DailyReflectionScreen(database: widget.database);
        case 'Urge Surfing Timer':
        case 'Meditation Timer':
          return const GroundingScreen();
        case 'Cost-Benefit Analysis':
          return CopingToolScreen(database: widget.database);
        case 'Medicine Wheel':
          return ConstellationScreen(database: widget.database);
        case 'Wellness Check-In':
          return WellnessCheckInScreen(database: widget.database);
        default:
          return JournalScreen(database: widget.database);
      }
    }

    final cards = <ToolCard>[];

    // Universal tools (blueprint §2.3): Journal, Gratitude, Counters,
    // Meeting Finder, SOS.
    cards.add(ToolCard(
      label: 'Private Journal',
      subtitle: 'PIN-protected reflections',
      icon: Icons.lock_outline,
      onTap: () => _push(JournalScreen(database: widget.database)),
    ));
    cards.add(ToolCard(
      label: 'Gratitude',
      subtitle: 'Three good things',
      icon: Icons.volunteer_activism_outlined,
      onTap: () => _push(GratitudeEntryScreen(database: widget.database)),
    ));
    cards.add(ToolCard(
      label: 'Counters',
      subtitle: 'Your Day One clock',
      icon: Icons.timelapse,
      onTap: () => _push(SobrietyCounterScreen(database: widget.database)),
    ));
    cards.add(ToolCard(
      label: 'Meeting Finder',
      subtitle: 'Rooms near and virtual',
      icon: Icons.map_outlined,
      onTap: _openMeetings,
    ));
    // Step counter — shows daily steps, requests pedometer permission
    cards.add(ToolCard(
      label: 'Step Counter',
      subtitle: 'Track daily movement',
      icon: Icons.directions_walk,
      onTap: () {
        showModalBottomSheet<void>(
          context: context,
          useSafeArea: true,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Steps',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track movement. Verify walks. Earn Sparks.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  StepCounterCard(),
                ],
              ),
            ),
          ),
        );
      },
    ));

    for (final tool in ref.watch(dashboardDataProvider).tools) {
      if (tool == 'Encrypted Journal' || tool == 'Meeting Finder' || tool == 'Wellness Check-In') continue;
      cards.add(ToolCard(
        label: tool,
        subtitle: '',
        icon: IconRegistry.toolIcon(tool),
        onTap: () => _push(screenFor(tool)),
      ));
    }

    // Culturally specific pathway content, shown when selected onboarding.
    if (ref.watch(dashboardDataProvider).paths.contains('Wellbriety')) {
      cards.add(ToolCard(
        label: 'Wellbriety Circles',
        subtitle: 'White Bison gatherings',
        icon: Icons.circle_outlined,
        onTap: () => _push(const WellbrietyCirclesScreen()),
      ));
    }

    cards.add(ToolCard(
      label: 'Wellness Check-In',
      subtitle: 'Six-dimension wheel',
      icon: Icons.donut_large_outlined,
      onTap: () => _push(WellnessCheckInScreen(database: widget.database)),
    ));
    cards.add(ToolCard(
      label: 'Weekly Goals',
      subtitle: 'Small promises kept',
      icon: Icons.flag_outlined,
      onTap: () => _push(WeeklyGoalsScreen(database: widget.database)),
    ));
    cards.add(ToolCard(
      label: 'The Twelve Steps',
      subtitle: 'A reader, any path',
      icon: Icons.menu_book_outlined,
      onTap: () => _push(StepsViewerScreen(database: widget.database)),
    ));
    cards.add(ToolCard(
      label: 'Daily Motivation',
      subtitle: 'One reflection at a time',
      icon: Icons.wb_twilight_outlined,
      onTap: () => _push(const DailyMotivationScreen()),
    ));
    cards.add(ToolCard(
      label: 'Companion Home',
      subtitle: 'Stats, outfits, care log',
      icon: Icons.pets_outlined,
      onTap: () => _push(PetHomeScreen(database: widget.database)),
    ));
    cards.add(ToolCard(
      label: 'Recovery Circle',
      subtitle: 'Share shapes, not numbers',
      icon: Icons.forum_outlined,
      onTap: () => _push(CommunityFeedScreen(database: widget.database)),
    ));
    cards.add(ToolCard(
      label: 'Recovery Coach',
      subtitle: 'Offline guidance, always here',
      icon: Icons.support_agent,
      onTap: () => _push(ChatbotScreen(database: widget.database)),
    ));
    return cards;
  }

  Future<void> _openMeetings() async {
    final (lat, lng) = await _resolveLocation();
    var meetings = await _meetingFinder.findNearbyMeetings(lat, lng,
        fellowships: _allowedFellowships());
    if (meetings.isEmpty) {
      meetings = await _meetingFinder.findNearbyMeetings(lat, lng);
    }
    if (!mounted) return;
    _push(MeetingMapScreen(initialMeetings: meetings, database: widget.database));
  }

  /// Route push with tap acknowledgment + double-tap guard: a haptic tick
  /// fires instantly (the tap *felt* heard), and repeat taps inside 600 ms
  /// are swallowed so impatient taps never stack duplicate screens.
  DateTime _lastPushAt = DateTime.fromMillisecondsSinceEpoch(0);
  void _push(Widget screen) {
    final now = DateTime.now();
    if (now.difference(_lastPushAt) < const Duration(milliseconds: 600)) {
      return;
    }
    _lastPushAt = now;
    FeedbackService.selection();
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  // ------------------------------------------------------------------
  // SOS safety layer
  // ------------------------------------------------------------------

  /// When SOS fires and a sponsor is linked, write a care alert to
  /// Firestore so the sponsor's app can pick it up (v1: console-visible).
  Future<void> _writeCareAlert() async {
    final sponsor = await SponsorLinkService.registeredSponsor();
    if (sponsor == null) return;
    if (!CommunityFeedService.remoteReady) return;
    try {
      await FirebaseFirestore.instance
          .collection('care_alerts')
          .doc('alert_${DateTime.now().millisecondsSinceEpoch}')
          .set({
        'sponsorCode': sponsor.pairingCode,
        'sponsorAlias': sponsor.alias,
        'triggeredAt': DateTime.now().millisecondsSinceEpoch,
        'type': 'sos_triggered',
      });
    } catch (_) {
      // Care alerts are best-effort; SOS works regardless.
    }
  }

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
    // User gesture: prime the Android 13+ notifications permission so the
    // persistent SOS lifeline can display (one-shot; never at boot).
    unawaited(SosNotificationService.ensureNotificationPermission());
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final sponsorPhone = ref.watch(dashboardDataProvider).sponsorPhone;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with gear icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'You are not alone.',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      tooltip: 'My Support Circle',
                      icon: Icon(Icons.settings_outlined, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _push(SettingsScreen(database: widget.database));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Immediate support, one tap away.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 12),
                // Row 1: 988 + Sponsor
                Row(
                  children: [
                    Expanded(
                      child: SosTile(
                        icon: Icons.phone_in_talk,
                        color: Theme.of(context).colorScheme.error,
                        title: 'Call 988',
                        subtitle: 'Suicide & Crisis Lifeline · 24/7',
                        onTap: () {
                          Navigator.pop(sheetContext);
                          SosNotificationService.startPersistentSos();
                          _callNumber('988');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SosTile(
                        icon: Icons.person_pin_circle,
                        color: Theme.of(context).colorScheme.primary,
                        title: sponsorPhone == null ? 'Call Sponsor' : 'Call Sponsor',
                        subtitle: sponsorPhone ?? 'Add in Settings',
                        enabled: sponsorPhone != null,
                        onTap: sponsorPhone != null ? () {
                          Navigator.pop(sheetContext);
                          _callNumber(sponsorPhone);
                        } : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Row 2: Meetings + Crisis Resources
                Row(
                  children: [
                    Expanded(
                      child: SosTile(
                        icon: Icons.groups_2,
                        color: Theme.of(context).colorScheme.primary,
                        title: 'Nearest Meetings',
                        subtitle: 'Three rooms close to you',
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          final (lat, lng) = await _resolveLocation();
                          final fellowships = _allowedFellowships();
                          var all = await _meetingFinder
                              .findNearbyMeetings(lat, lng, fellowships: fellowships);
                          if (all.isEmpty) {
                            all = await _meetingFinder.findNearbyMeetings(lat, lng);
                          }
                          if (!mounted) return;
                          _push(MeetingMapScreen(
                              initialMeetings: all.take(3).toList(),
                              database: widget.database));
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SosTile(
                        icon: Icons.open_in_new,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        title: 'Crisis Resources',
                        subtitle: '988lifeline.org',
                        onTap: () {
                          Navigator.pop(sheetContext);
                          launchUrl(
                            Uri.parse('https://988lifeline.org'),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                      ),
                    ),
                  ],
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
  // Build — shell IA (dashboard-ia.md), four destinations
  // ------------------------------------------------------------------

  /// Selected destination. Phase 9 slice A: still only Path and Library have
  /// bodies; the enum carries all four so the bar and back handling are
  /// complete now and each destination lands as an independent slice.
  DashboardDestination _selected =
      DashboardDestination.backTarget;

  /// Kept for the ordering calls that index into [_layout] lists; the shell
  /// itself no longer uses an int.
  int get _selectedIndex => _selected.index;

  late final TutorialChatbotService _tutorialChatbot;

  void _openTutorialChatbot() {
    if (ref.watch(dashboardDataProvider).pet == null) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => TutorialChatbotDialog(
        pet: ref.watch(dashboardDataProvider).pet!,
        chatbotService: _tutorialChatbot,
        // Wired 2026-09-28. The dialog's close button calls `onClose`, and the
        // only call site never passed it, so the first-run tutorial's X was a
        // dead control: barrier-dismissible and system-back were the only ways
        // out of the very first screen a new user meets.
        onClose: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(dashboardDataProvider).loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        title: Text('Welcome, $ref.watch(dashboardDataProvider).username', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Tutorial Guide',
            icon: Icon(Icons.help_outline, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
            onPressed: _openTutorialChatbot,
          ),
          IconButton(
            tooltip: 'Settings',
            icon: Icon(Icons.settings_outlined, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
            onPressed: () => _push(SettingsScreen(database: widget.database)),
          ),
        ],
      ),
      // Slice A: an IndexedStack keeps every destination ALIVE, so a tab
      // switch no longer destroys and rebuilds the off-screen body. That is
      // what preserves scroll offset and per-tab edit mode, and it is the
      // precondition for parking a stateful screen (Settings) on a tab.
      //
      // Trade-off, recorded deliberately: a live Lottie aura or animated
      // painter keeps ticking while off-screen. The tree is not built twice
      // (children are lazy) and no state is re-fetched, which is the cost we
      // are paying instead.
      body: PopScope(
        // At the back target there is nothing to pop, so let Android exit the
        // app as it does today rather than swallowing the gesture.
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_selected != DashboardDestination.backTarget) {
            setState(() => _selected = DashboardDestination.backTarget);
          } else {
            // Back at the default destination: hand the gesture back to the
            // platform so Android exits, matching the pre-Phase-9 behavior.
            SystemNavigator.pop();
          }
        },
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            for (final destination in DashboardDestination.values)
              _bodyFor(destination),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        indicatorColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.22),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(
            () => _selected = DashboardDestination.values[i]),
        destinations: [
          for (final destination in DashboardDestination.values)
            NavigationDestination(
              icon: Icon(destination.icon,
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.7)),
              selectedIcon: Icon(destination.selectedIcon,
                  color: Theme.of(context).colorScheme.onSurface),
              label: destination.label,
            ),
        ],
      ),
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 360;
          return FloatingActionButton.extended(
            onPressed: () {
              _writeCareAlert();
              _showSosSheet();
            },
            backgroundColor: Theme.of(context).colorScheme.error,
            icon: Icon(Icons.sos, color: Theme.of(context).colorScheme.onSurface),
            label: Text(
              isSmallScreen ? 'SOS' : 'SOS Help',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
            ),
            extendedPadding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 16 : 24,
              vertical: 12,
            ),
          );
        },
      ),
    );
  }

  /// Maps a destination to its body. Slices B and C fill in Profile and
  /// Companion; until then those show an honest placeholder rather than a
  /// blank region, so a shipped build never looks broken.
  Widget _bodyFor(DashboardDestination destination) {
    switch (destination) {
      case DashboardDestination.path:
        return _buildPathTab();
      case DashboardDestination.library:
        return _buildLibraryTab();
      case DashboardDestination.profile:
        return SettingsScreen(database: widget.database);
      case DashboardDestination.companion:
        return const _DestinationPlaceholder(
          icon: Icons.pets,
          title: 'Companion',
          message: 'Your companion is moving here next.',
        );
    }
  }

  Widget _buildPathTab() {
    final pet = ref.watch(dashboardDataProvider).pet;
    final ordered = _ordered(_buildToolCards(), _layout.toolOrder, _layout.hiddenTools);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SkyCrown(
              nodes: _skyNodes ?? const [],
              skyName: ref.watch(skyNameProvider) ?? 'Your Constellation',
              onTap: () {
                _push(ConstellationScreen(database: widget.database));
                _loadSky();
              },
            ),
            const SizedBox(height: 12),
            PledgeCard(
              pledged: ref.watch(dailyPledgeProvider),
              onPledge: _confirmPledge,
            ),
            const SizedBox(height: 16),
            if (ref.watch(dashboardDataProvider).paths.isNotEmpty) ...[
              PathChips(paths: ref.watch(dashboardDataProvider).paths),
              const SizedBox(height: 16),
            ],
            if (pet != null)
              CompanionSection(
                pet: pet,
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => SkillTreeModal(database: widget.database),
                ),
                onCheckIn: _handleCheckIn,
                onWalk: _handleWalk,
                onOpen: _openDresser,
              ),
            const SizedBox(height: 16),
            // R27: Predictive Next-Meeting Widget — live or next today from cache.
            // Slice 3: the waiting/error/empty presentation now lives in
            // MeetingSpotlight instead of collapsing into a bare card.
            FutureBuilder<List<RecoveryMeeting>>(
              future: _meetingFinder.cachedMeetings(),
              builder: (context, snapshot) {
                final meetings = snapshot.data ?? const <RecoveryMeeting>[];
                var filtered = meetings;
                final allowed = _allowedFellowships();
                if (allowed != null && allowed.isNotEmpty && meetings.isNotEmpty) {
                  final tail = meetings
                      .where((m) => allowed.contains(m.fellowship))
                      .toList();
                  if (tail.isNotEmpty) filtered = tail;
                }
                var display = filtered;
                String? tierLabel;
                final cacheUsable = _radius.enforce &&
                    _radius.lat != null &&
                    _radius.lng != null &&
                    isCacheFresh(_radius.cachedAtMs);
                if (cacheUsable) {
                  final userLoc = ll.LatLng(_radius.lat!, _radius.lng!);
                  final tiered = applyRadiusTiers(filtered, userLoc);
                  display = sortMeetings(tiered.meetings, userLoc, DateTime.now());
                  tierLabel = tiered.tierLabel;
                }
                final pick = display.isEmpty
                    ? null
                    : NextMeetingCard.pickNext(display, DateTime.now());
                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onLongPress: () => _toggleRadiusFilter(),
                  child: MeetingSpotlight(
                    snapshot: snapshot,
                    pick: pick,
                    tierLabel: tierLabel,
                    onOpenMap: pick == null ? null : _openMeetingMap,
                    onFindMeetings: _openMeetingMap,
                    onRetry: () => setState(() {}),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            if (ref.watch(dashboardDataProvider).raid != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: RaidBossCard(
                  raid: ref.watch(dashboardDataProvider).raid!,
                  onStrike: () async {
                    final updated = await RaidService.dealDamage(widget.database, ref.watch(dashboardDataProvider).raid!.id, RaidService.strikeDamage);
                    if (!mounted) return;
                    if (updated != null) unawaited(ref.read(dashboardDataProvider.notifier).setRaid(updated));
                    if (updated != null && updated.currentHp <= 0) {
                      await _refreshPet();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Theme.of(context).colorScheme.surfaceContainer, content: Text('Boss defeated! +200 XP • Community triumph!')));
                    } else if (updated != null) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Theme.of(context).colorScheme.surfaceContainer, content: Text('Strike! -${RaidService.strikeDamage} HP • You: ${updated.userContribution} DMG')));
                    }
                  },
                ),
              ),
            ToolGrid(
              title: 'Your Toolbox',
              editing: _editingPath,
              hidden: _layout.hiddenTools,
              onToggleEditing: () =>
                  setState(() => _editingPath = !_editingPath),
              onRestore: _restoreHiddenTool,
              children: [
                for (var i = 0; i < ordered.length; i++)
                  _buildDraggableToolCard(ordered, i, isLibrary: false),
              ],
            ),
            const SizedBox(height: 20),
            SupportLinkRow(
              icon: Icons.qr_code_scanner,
              title: 'Fellowship Handshake',
              subtitle: 'QR connect • +50 XP • offline, private',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      FellowshipSyncScreen(database: widget.database),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SupportLinkRow(
              icon: Icons.volunteer_activism_outlined,
              title: '7th Tradition',
              subtitle: 'Voluntary support — keeps Recovery for All free',
              tint: AppColors.pink,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SeventhTraditionScreen(),
                ),
              ),
            ),
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryTab() {
    final ordered = _ordered(_buildLibraryCards(), _layout.libraryOrder, _layout.hiddenLibrary);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ToolGrid(
              title: 'Library',
              subtitle:
                  'Literature, housing, and community \u2014 always one tap away.',
              editing: _editingLibrary,
              hidden: _layout.hiddenLibrary,
              onToggleEditing: () =>
                  setState(() => _editingLibrary = !_editingLibrary),
              onRestore: _restoreHiddenLibraryItem,
              children: [
                for (var i = 0; i < ordered.length; i++)
                  _buildDraggableToolCard(ordered, i, isLibrary: true),
              ],
            ),
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }

  void _restoreHiddenTool(String id) {
    final l = _layout;
    ref
        .read(dashboardLayoutProvider.notifier)
        .saveToolOrder(
          l.toolOrder,
          Set<String>.from(l.hiddenTools)..remove(id),
        );
  }

  void _restoreHiddenLibraryItem(String id) {
    final l = _layout;
    ref
        .read(dashboardLayoutProvider.notifier)
        .saveLibraryOrder(
          l.libraryOrder,
          Set<String>.from(l.hiddenLibrary)..remove(id),
        );
  }

  /// Long-press on the meeting card toggles radius filtering and confirms it,
  /// so the toggle is never silent.
  Future<void> _toggleRadiusFilter() async {
    final next = !ref.read(meetingRadiusProvider).enforce;
    await ref.read(meetingRadiusProvider.notifier).setEnforce(next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        content: Text(
          'Meeting radius filtering: ${next ? 'ON' : 'OFF'}',
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }

  Future<void> _openMeetingMap() async {
    final (lat, lng) = await _resolveLocation();
    var all =
        await _meetingFinder.findNearbyMeetings(lat, lng, fellowships: _allowedFellowships());
    if (all.isEmpty) {
      all = await _meetingFinder.findNearbyMeetings(lat, lng);
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeetingMapScreen(
            initialMeetings: all, database: widget.database),
      ),
    );
  }

  /// Resource cards live in Library, never in the Path toolbox.
  Widget _buildDraggableToolCard(List<ToolCard> ordered, int index,
      {required bool isLibrary}) {
    final card = ordered[index];
    final editing = isLibrary ? _editingLibrary : _editingPath;
    if (!editing) return card;
    final isProtected = isLibrary
        ? card.label == 'Crisis Lines'
        : card.label == 'Meeting Finder';
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != card.label,
      onAcceptWithDetails: (details) {
        final from = ordered.indexWhere((c) => c.label == details.data);
        if (from == -1) return;
        final reordered = List<ToolCard>.from(ordered);
        final moved = reordered.removeAt(from);
        reordered.insert(index, moved);
        final labels = reordered.map((c) => c.label).toList();
        final notifier = ref.read(dashboardLayoutProvider.notifier);
        if (isLibrary) {
          unawaited(notifier.saveLibraryOrder(labels, _layout.hiddenLibrary));
        } else {
          unawaited(notifier.saveToolOrder(labels, _layout.hiddenTools));
        }
        setState(() {});
      },
      builder: (context, candidate, rejected) {
        final isTarget = candidate.isNotEmpty;
        return LongPressDraggable<String>(
          data: card.label,
          feedback: Opacity(
              opacity: 0.85,
              child: SizedBox(width: 160, height: 110, child: card)),
          childWhenDragging: Opacity(opacity: 0.3, child: card),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: isTarget
                    ? BoxDecoration(
                        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                        borderRadius: BorderRadius.circular(16),
                      )
                    : null,
                child: card,
              ),
              if (!isProtected)
                Positioned(
                  top: 6,
                  right: 6,
                  child: InkWell(
                    onTap: () {
                      final l = _layout;
                      final notifier =
                          ref.read(dashboardLayoutProvider.notifier);
                      if (isLibrary) {
                        unawaited(notifier.saveLibraryOrder(
                            l.libraryOrder,
                            Set<String>.from(l.hiddenLibrary)..add(card.label)));
                      } else {
                        unawaited(notifier.saveToolOrder(
                            l.toolOrder,
                            Set<String>.from(l.hiddenTools)..add(card.label)));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), shape: BoxShape.circle),
                      child: Icon(Icons.visibility_off,
                          size: 14, color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ),
                ),
              Positioned(
                bottom: 6,
                right: 6,
                child: Icon(Icons.drag_handle, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
              ),
            ],
          ),
        );
      },
    );
  }

  List<ToolCard> _buildLibraryCards() => [
        ToolCard(
          label: 'Literature Library',
          subtitle: 'Books and pamphlets, free',
          icon: Icons.menu_book_outlined,
          onTap: () => _push(const LiteratureLibraryScreen()),
        ),
        ToolCard(
          label: 'Community Support',
          subtitle: 'RCOs and online rooms',
          icon: Icons.volunteer_activism,
          onTap: () => _push(const CommunityResourcesScreen()),
        ),
        ToolCard(
          label: 'Native Resources',
          subtitle: 'MN culturally specific care',
          icon: Icons.spa_outlined,
          onTap: () => _push(const NativeResourcesScreen()),
        ),
        ToolCard(
          label: 'Sober Housing',
          subtitle: 'Structured homes directory',
          icon: Icons.home_work_outlined,
          onTap: () => _push(const SoberHousingLocatorScreen()),
        ),
        ToolCard(
          label: 'Crisis Lines',
          subtitle: '988, SAMHSA, Trevor — 24/7',
          icon: Icons.emergency_outlined,
          onTap: _showSosSheet,
        ),
      ];
}

/// Visible, explained placeholder for a destination that has not landed yet.
///
/// A blank `SizedBox` would read as a broken tab. This states plainly what is
/// coming so a half-finished navigation shell is never mistaken for a bug.
class _DestinationPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _DestinationPlaceholder({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: scheme.primary),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


