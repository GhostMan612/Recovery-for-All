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
  ];

  static WorksheetEntry byId(String id) =>
      all.firstWhere((w) => w.id == id, orElse: () => all.first);
}
