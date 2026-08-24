// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';
import '../database/recovery_database.dart';
import '../services/recovery_pet_service.dart';
import '../services/sponsor_link_service.dart';

/// The Twelve Steps — reader, guided worksheets, literature links, and
/// sponsor sign-off tracking. Completion feeds pet Sparks and adds a star
/// to the user's constellation.
class StepsViewerScreen extends StatefulWidget {
  final RecoveryDatabase? database;

  const StepsViewerScreen({super.key, this.database});

  @override
  State<StepsViewerScreen> createState() => _StepsViewerScreenState();
}

class _StepData {
  final int number;
  final String title;
  final String text;
  final List<String> worksheetPrompts;
  const _StepData(this.number, this.title, this.text, this.worksheetPrompts);
}

class _StepsViewerScreenState extends State<StepsViewerScreen> {
  static const String _prefsKey = 'steps_completed_v1';
  static const String _worksheetKey = 'steps_worksheets_v1';
  static const String _signoffKey = 'steps_signoffs_v1';

  // The Twelve Steps (Alcoholics Anonymous, 1st ed., public domain).
  static const List<_StepData> _steps = [
    _StepData(1, 'Honesty',
        'We admitted we were powerless over alcohol — that our lives had become unmanageable.',
        ['Where was my life unmanageable?', 'What did powerlessness feel like?', 'What changes when I admit it?']),
    _StepData(2, 'Hope',
        'Came to believe that a Power greater than ourselves could restore us to sanity.',
        ['What does "greater power" mean to me?', 'When have I seen sanity return?', 'What do I hope for?']),
    _StepData(3, 'Faith',
        'Made a decision to turn our will and our lives over to the care of God as we understood Him.',
        ['What am I turning over?', 'What am I afraid to let go of?', 'What does "care" look like day to day?']),
    _StepData(4, 'Courage',
        'Made a searching and fearless moral inventory of ourselves.',
        ['Resentments I am holding:', 'My part in each:', 'My strengths I overlook:']),
    _StepData(5, 'Integrity',
        'Admitted to God, to ourselves, and to another human being the exact nature of our wrongs.',
        ['Who will I share my inventory with?', 'What feels hardest to say out loud?', 'How might I feel after?']),
    _StepData(6, 'Willingness',
        'Were entirely ready to have God remove all these defects of character.',
        ['Which defect am I most ready to release?', 'What has it cost me?', 'What replaces it?']),
    _StepData(7, 'Humility',
        'Humbly asked Him to remove our shortcomings.',
        ['What does humility ask of me?', 'Where does pride still run?', 'A prayer or intention:']),
    _StepData(8, 'Brotherly Love',
        'Made a list of all persons we had harmed, and became willing to make amends to them all.',
        ['Names on my list:', 'The harm in each case:', 'Am I willing — honestly?']),
    _StepData(9, 'Justice',
        'Made direct amends to such people wherever possible, except when to do so would injure them or others.',
        ['Amends I can make directly:', 'Amends I must NOT make (and why):', 'What I will say:']),
    _StepData(10, 'Perseverance',
        'Continued to take personal inventory and when we were wrong promptly admitted it.',
        ['Today\'s inventory:', 'Where was I wrong recently?', 'How did I admit it?']),
    _StepData(11, 'Spirituality',
        'Sought through prayer and meditation to improve our conscious contact with God as we understood Him, praying only for knowledge of His will for us and the power to carry that out.',
        ['My practice:', 'What I am asking for:', 'What I heard / felt:']),
    _StepData(12, 'Service',
        'Having had a spiritual awakening as the result of these steps, we tried to carry this message to alcoholics, and to practice these principles in all our affairs.',
        ['How has my life changed?', 'Who can I carry this message to?', 'Where do I practice principles daily?']),
  ];

  Set<int> _completed = {};
  Map<String, List<String>> _worksheets = {};
  Set<int> _signoffs = {};
  Map<int, String> _bundles = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    final wsRaw = prefs.getString(_worksheetKey);
    final soRaw = prefs.getString(_signoffKey);
    final bundleRaw = prefs.getString('step_bundles_v1');
    if (!mounted) return;
    setState(() {
      _completed = raw == null
          ? <int>{}
          : (jsonDecode(raw) as List).map((e) => e as int).toSet();
      _worksheets = wsRaw == null
          ? {}
          : (jsonDecode(wsRaw) as Map<String, dynamic>)
              .map((k, v) => MapEntry(k, (v as List).map((e) => e.toString()).toList()));
      _signoffs = soRaw == null
          ? <int>{}
          : (jsonDecode(soRaw) as List).map((e) => e as int).toSet();
      if (bundleRaw != null) {
        final decoded = jsonDecode(bundleRaw) as Map<String, dynamic>;
        _bundles = decoded
            .map((k, v) => MapEntry(int.parse(k), v as String));
      }
    });
  }

  Future<void> _toggleWorked(int number) async {
    final wasDone = _completed.contains(number);
    setState(() {
      if (!_completed.add(number)) _completed.remove(number);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_completed.toList()));

    if (!wasDone) {
      // Milestone: pet Sparks + a constellation star for the worked step.
      await RecoveryPetService.logStar('Step $number — worked');
      final db = widget.database;
      if (db != null) {
        final step = _steps.firstWhere((s) => s.number == number);
        final angle = number * (3.141592653589793 / 6);
        await db.addConstellationPoint(
          ConstellationPoint(
            id: 'step_$number',
            title: 'Step $number: ${step.title}',
            category: 'step_work',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            positionX: 0.5 + 0.35 * cos(angle),
            positionY: 0.5 + 0.35 * sin(angle),
          ),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E293B),
            content: Text(
                'Step $number worked · star added to your constellation · +${RecoveryPetService.sparksStar} Sparks'),
          ),
        );
      }
    }
  }

  Future<List<String>> _worksheetFor(int number) async {
    return _worksheets['$number'] ?? const ['', '', ''];
  }

  Future<void> _saveWorksheet(int number, List<String> answers) async {
    _worksheets['$number'] = answers;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_worksheetKey, jsonEncode(_worksheets));
    await RecoveryPetService.logWorksheet(number);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1E293B),
          content:
              Text('Worksheet saved · +${RecoveryPetService.sparksWorksheet} Sparks'),
        ),
      );
    }
  }

  Future<String> _bundleFor(int number) async {
    final step = _steps.firstWhere((s) => s.number == number);
    final answers = await _worksheetFor(number);
    return jsonEncode({
      'v': 1,
      'step': number,
      'title': step.title,
      'text': step.text,
      'answers': answers,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _copyForSponsor(int number) async {
    final bundle = await _bundleFor(number);
    _bundles[number] = bundle;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('step_bundles_v1',
        jsonEncode(_bundles.map((k, v) => MapEntry(k.toString(), v))));
    final step = _steps.firstWhere((s) => s.number == number);
    final readable = StringBuffer()
      ..writeln('RC-BUNDLE')
      ..writeln('Step $number — ${step.title}')
      ..writeln(step.text)
      ..writeln('');
    final answers = await _worksheetFor(number);
    for (var i = 0; i < step.worksheetPrompts.length; i++) {
      readable.writeln(step.worksheetPrompts[i]);
      readable.writeln(answers.length > i && answers[i].isNotEmpty ? answers[i] : '(in bundle)');
      readable.writeln('');
    }
    readable.writeln(payloadMarker(bundle));
    readable.writeln('RC-END');
    await Clipboard.setData(ClipboardData(text: readable.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF1E293B),
        content: Text(
            'Bundle copied — send it to your sponsor. Redeem their signed code here after.'),
      ),
    );
  }

  static String payloadMarker(String bundle) =>
      '[RC-PAYLOAD]$bundle[/RC-PAYLOAD]';

  Future<void> _redeemSignOff(int number) async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Redeem sign-off', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Paste the RC-SIGNOFF code your sponsor sent back.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 4,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Verify', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (raw == null || raw.isEmpty) return;
    final start = raw.indexOf('RC-SIGNOFF');
    final end = raw.indexOf('RC-END');
    final codeBlock = (start >= 0 && end > start)
        ? raw.substring(start + 10, end).trim()
        : raw.trim();
    final confirmation = SignedConfirmation.tryDecode(codeBlock);
    final bundle = _bundles[number];
    if (confirmation == null || bundle == null ||
        confirmation.stepNumber != number) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('That code did not match this step\'s bundle.')),
      );
      return;
    }
    final ok = await SponsorLinkService.verifyConfirmation(confirmation, bundle);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Signature check failed — ask your sponsor to re-sign.')),
      );
      return;
    }
    await SponsorLinkService.recordSignOff(
      stepNumber: number,
      contentHashB64: confirmation.contentHashB64,
      signatureB64: confirmation.signatureB64,
    );
    setState(() => _signoffs.add(number));
    await RecoveryPetService.logSignOff(number);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E293B),
        content: Text(
            'Step $number sponsor-verified · +${RecoveryPetService.sparksSignOff} Sparks · Bond +5'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('The Twelve Steps', style: TextStyle(color: Colors.white)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _steps.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final step = _steps[index];
          final done = _completed.contains(step.number);
          final signed = _signoffs.contains(step.number);
          return Container(
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: signed
                    ? AppColors.success.withValues(alpha: 0.6)
                    : done
                        ? AppColors.success.withValues(alpha: 0.35)
                        : AppColors.border,
              ),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                iconColor: AppColors.accent,
                collapsedIconColor: AppColors.textMuted,
                title: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: signed
                            ? AppColors.success
                            : done
                                ? AppColors.success.withValues(alpha: 0.5)
                                : AppColors.accent.withValues(alpha: 0.15),
                      ),
                      child: Text(
                        '${step.number}',
                        style: TextStyle(
                          color: done || signed ? Colors.white : AppColors.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(step.title,
                          style: const TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                    if (signed)
                      const Icon(Icons.verified, size: 18, color: AppColors.success),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(step.text,
                        style: TextStyle(
                            color: AppColors.textPrimary, fontSize: 15, height: 1.5)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(color: AppColors.border),
                        const Text('Worksheet',
                            style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _WorksheetFields(
                          stepNumber: step.number,
                          prompts: step.worksheetPrompts,
                          loadAnswers: _worksheetFor,
                          onSave: (answers) => _saveWorksheet(step.number, answers),
                        ),
                        const Divider(color: AppColors.border),
                        Row(
                          children: [
                            const Icon(Icons.menu_book,
                                size: 15, color: AppColors.textMuted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: InkWell(
                                onTap: () => launchUrl(
                                  Uri.parse('https://www.aa.org/the-twelve-steps'),
                                  mode: LaunchMode.externalApplication,
                                ),
                                child: const Text(
                                  'Literature: aa.org — the Twelve Steps',
                                  style: TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 12,
                                      decoration: TextDecoration.underline),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () => _toggleWorked(step.number),
                                icon: Icon(
                                    done ? Icons.check_box : Icons.check_box_outline_blank,
                                    size: 18,
                                    color: done ? AppColors.success : AppColors.accent),
                                label: Text(done ? 'Worked' : 'Mark worked',
                                    style: TextStyle(
                                        color: done
                                            ? AppColors.success
                                            : AppColors.accent,
                                        fontSize: 13)),
                              ),
                            ),
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () => _copyForSponsor(step.number),
                                icon: const Icon(Icons.copy_all_outlined,
                                    size: 16, color: AppColors.textMuted),
                                label: const Text('Copy bundle',
                                    style: TextStyle(
                                        color: AppColors.textMuted, fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12, bottom: 10),
                            child: TextButton.icon(
                              onPressed: () => _redeemSignOff(step.number),
                              icon: Icon(
                                signed ? Icons.verified : Icons.verified_outlined,
                                size: 18,
                                color: signed ? AppColors.success : AppColors.textMuted,
                              ),
                              label: Text(
                                  signed
                                      ? 'Sponsor verified'
                                      : 'Redeem sign-off',
                                  style: TextStyle(
                                      color: signed
                                          ? AppColors.success
                                          : AppColors.textMuted,
                                      fontSize: 13)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WorksheetFields extends StatefulWidget {
  final int stepNumber;
  final List<String> prompts;
  final Future<List<String>> Function(int) loadAnswers;
  final void Function(List<String>) onSave;

  const _WorksheetFields({
    required this.stepNumber,
    required this.prompts,
    required this.loadAnswers,
    required this.onSave,
  });

  @override
  State<_WorksheetFields> createState() => _WorksheetFieldsState();
}

class _WorksheetFieldsState extends State<_WorksheetFields> {
  final List<TextEditingController> _controllers = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final answers = await widget.loadAnswers(widget.stepNumber);
    if (!mounted) return;
    for (var i = 0; i < widget.prompts.length; i++) {
      _controllers.add(TextEditingController(
          text: answers.length > i ? answers[i] : ''));
    }
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(
            child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < widget.prompts.length; i++) ...[
          Text(widget.prompts[i],
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _controllers[i],
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF0F172A),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.accent),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => widget
                .onSave(_controllers.map((c) => c.text.trim()).toList()),
            icon: const Icon(Icons.save_outlined,
                size: 16, color: AppColors.accent),
            label: const Text('Save worksheet',
                style: TextStyle(color: AppColors.accent, fontSize: 13)),
          ),
        ),
      ],
    );
  }
}
