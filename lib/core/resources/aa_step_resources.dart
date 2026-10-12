// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

/// A distinct, explicit source map for the twelve AA chapter resources.
///
/// Candidate official endpoints. No durable live-response evidence is shipped
/// with the app, so endpoint availability and content must be verified before
/// release. The app streams a temporary per-user copy and deletes it when the
/// reader closes; this does not establish redistribution rights.
class AaStepResource {
  final int step;
  final String stepTitle;
  final String url;

  const AaStepResource({
    required this.step,
    required this.stepTitle,
    required this.url,
  });

  Uri get uri => Uri.parse(url);

  String get sourceId => 'aa-step-$step';

  String get readerTitle => 'Read Step $step — AA chapter (PDF)';
}

abstract final class AaStepResources {
  static const Set<String> officialHosts = {'aa.org', 'www.aa.org'};

  static const List<AaStepResource> all = [
    AaStepResource(
      step: 1,
      stepTitle: 'Honesty',
      url: 'https://www.aa.org/sites/default/files/2022-01/en_step1.pdf',
    ),
    AaStepResource(
      step: 2,
      stepTitle: 'Hope',
      url: 'https://www.aa.org/sites/default/files/2022-01/en_step2.pdf',
    ),
    AaStepResource(
      step: 3,
      stepTitle: 'Faith',
      url: 'https://www.aa.org/sites/default/files/2022-01/en_step3.pdf',
    ),
    AaStepResource(
      step: 4,
      stepTitle: 'Courage',
      url: 'https://www.aa.org/sites/default/files/2022-01/en_step4.pdf',
    ),
    AaStepResource(
      step: 5,
      stepTitle: 'Integrity',
      url: 'https://www.aa.org/sites/default/files/2022-01/en_step5.pdf',
    ),
    AaStepResource(
      step: 6,
      stepTitle: 'Willingness',
      url: 'https://www.aa.org/sites/default/files/2022-01/en_step6.pdf',
    ),
    AaStepResource(
      step: 7,
      stepTitle: 'Humility',
      url: 'https://www.aa.org/sites/default/files/2022-01/en_step7.pdf',
    ),
    AaStepResource(
      step: 8,
      stepTitle: 'Brotherly Love',
      url: 'https://www.aa.org/sites/default/files/2022-01/en_step8.pdf',
    ),
    AaStepResource(
      step: 9,
      stepTitle: 'Justice',
      url: 'https://www.aa.org/sites/default/files/2022-01/en_step9.pdf',
    ),
    AaStepResource(
      step: 10,
      stepTitle: 'Perseverance',
      url: 'https://www.aa.org/sites/default/files/2022-01/en_step10.pdf',
    ),
    AaStepResource(
      step: 11,
      stepTitle: 'Spirituality',
      url: 'https://www.aa.org/sites/default/files/2022-01/en_step11.pdf',
    ),
    AaStepResource(
      step: 12,
      stepTitle: 'Service',
      url: 'https://www.aa.org/sites/default/files/2022-01/en_step12.pdf',
    ),
  ];

  static AaStepResource forStep(int step) {
    if (step < 1 || step > all.length) {
      throw RangeError.range(step, 1, all.length, 'step');
    }
    return all[step - 1];
  }
}
