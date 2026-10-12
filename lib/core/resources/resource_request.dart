// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'aa_step_resources.dart';

enum ResourceKind { auto, pdf, web }

/// Immutable input to the resource-routing domain layer.
///
/// [sourceId] is a stable app-owned identifier, not a remote identity. The
/// request deliberately carries no recovery, profile, sponsor, or auth data.
class ResourceRequest {
  final Uri uri;
  final String title;
  final String sourceId;
  final ResourceKind kind;

  ResourceRequest({
    required this.uri,
    required this.title,
    required this.sourceId,
    this.kind = ResourceKind.auto,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    if (sourceId.trim().isEmpty) {
      throw ArgumentError.value(sourceId, 'sourceId', 'must not be empty');
    }
  }

  factory ResourceRequest.aaStep(int step) {
    final resource = AaStepResources.forStep(step);
    return ResourceRequest(
      uri: resource.uri,
      title: resource.readerTitle,
      sourceId: resource.sourceId,
      kind: ResourceKind.pdf,
    );
  }
}
