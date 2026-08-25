// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/data/worksheets_registry.dart
//
// R2 — guided worksheets for every recovery tool, data-driven so new
// worksheets are registry entries, not new screens.

class WorksheetEntry {
  final String id;
  final String title;
  final String tool;
  final String description;
  final List<String> prompts;

  const WorksheetEntry({
    required this.id,
    required this.title,
    required this.tool,
    required this.description,
    required this.prompts,
  });
}

class WorksheetsRegistry {
  WorksheetsRegistry._();

  static const List<WorksheetEntry> all = [
    WorksheetEntry(
      id: 'cba',
      title: 'Cost–Benefit Analysis',
      tool: 'SMART Recovery',
      description: 'Weigh using against staying the course, honestly.',
      prompts: [
        'Short-term benefits of using (be honest — this column is real):',
        'Short-term costs of using:',
        'Long-term benefits of NOT using:',
        'Long-term costs if I return to using:',
      ],
    ),
    WorksheetEntry(
      id: 'urge_surfing',
      title: 'Urge Surfing Log',
      tool: 'Urge Surfing Timer',
      description: 'Capture a wave after riding it — data for next time.',
      prompts: [
        'What triggered the urge?',
        'Where did I feel it in my body, and how strong (1–10)?',
        'How did the wave crest and fall? What helped me ride it?',
      ],
    ),
    WorksheetEntry(
      id: 'relapse_plan',
      title: 'Relapse Prevention Plan',
      tool: 'Safety',
      description: 'Written while calm — read when it matters.',
      prompts: [
        'My top 3 triggers:',
        'My first-line coping actions (in order):',
        'People I will contact (names/numbers):',
        'One sentence to my future self on a hard day:',
      ],
    ),
    WorksheetEntry(
      id: 'gratitude_deep',
      title: 'Deep Gratitude',
      tool: 'Gratitude',
      description: 'Beyond three good things — one thing, explored.',
      prompts: [
        'One person who changed my path, and how:',
        'A hard moment I am now grateful for:',
        'Something about today I never want to forget:',
      ],
    ),
    WorksheetEntry(
      id: 'grounding_log',
      title: 'Grounding Log',
      tool: 'Urge Surfing Timer',
      description: '5-4-3-2-1 technique — capture what worked.',
      prompts: [
        '5 things I could SEE:',
        '4 things I could TOUCH:',
        '3 things I could HEAR:',
        '2 things I could SMELL:',
        '1 thing I could TASTE:',
        'How did my body feel after?',
      ],
    ),
    WorksheetEntry(
      id: 'trigger_inventory',
      title: 'Trigger Inventory',
      tool: 'Safety',
      description: 'Know your patterns before they know you.',
      prompts: [
        'My top 3 triggers (people, places, feelings):',
        'What happens in my body when triggered:',
        'One action that interrupts the pattern:',
      ],
    ),
    WorksheetEntry(
      id: 'amends_prep',
      title: 'Amends Preparation',
      tool: 'Twelve Steps',
      description: 'Step 8–9 support — prepare with care.',
      prompts: [
        'Who am I making amends to?',
        'What harm was done (facts, not shame):',
        'What I will say (draft):',
        'What I will NOT say (and why):',
      ],
    ),
    WorksheetEntry(
      id: 'daily_intentions',
      title: 'Daily Intentions',
      tool: 'Daily Reflections',
      description: 'Start the day with direction, not reaction.',
      prompts: [
        'One thing I will do today for my recovery:',
        'One thing I will do today for someone else:',
        'One thing I will NOT do today:',
      ],
    ),
    WorksheetEntry(
      id: 'self_care_plan',
      title: 'Self-Care Plan',
      tool: 'Wellness',
      description: 'What fills your cup — written when you have capacity.',
      prompts: [
        'Three things that fill my cup:',
        'Two things that drain my cup (and how to limit them):',
        'One person I can call when my cup is empty:',
      ],
    ),
  ];

  static WorksheetEntry byId(String id) =>
      all.firstWhere((w) => w.id == id, orElse: () => all.first);
}
