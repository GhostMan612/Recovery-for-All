// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Found on hardware, not in the test suite. Both SosNotificationService and
// GentleReminderService passed '@mipmap/ic_launcher' to
// AndroidInitializationSettings. flutter_local_notifications resolves the icon
// with
//
//     context.getResources().getIdentifier(name, "drawable", packageName)
//
// so it searched the DRAWABLE folder for a resource literally named
// "@mipmap/ic_launcher". That is 0 in every build, debug included; the plugin
// threw `invalid_icon`, and the boot-time catch turned it into a log line:
//
//     [boot] sos init skipped: PlatformException(invalid_icon,
//       The resource @mipmap/ic_launcher could not be found...)
//
// So the SOS lifeline had never initialised. No host test could catch it,
// because the failure is an Android resource lookup against a plugin's private
// Java. This is the gate for the two things that could regress it again.

const _services = [
  'lib/services/sos_notification_service.dart',
  'lib/services/gentle_reminder_service.dart',
];

/// The icon name the plugin actually receives. Must match the drawable file
/// asserted to exist below.
const _expectedIcon = 'ic_stat_sos';

const _drawablePath =
    'android/app/src/main/res/drawable/ic_stat_sos.xml';

void main() {
  group('notification icon resource', () {
    for (final path in _services) {
      test('$path passes a bare drawable name, not a mipmap reference', () {
        final source = File(path).readAsStringSync();

        expect(
          source.contains("AndroidInitializationSettings('@mipmap"),
          isFalse,
          reason: '$path passes an "@mipmap/..." icon. The plugin resolves the '
              'icon with getIdentifier(name, "drawable", packageName), so a '
              'mipmap reference can never resolve and initialization throws '
              'invalid_icon. Pass a bare drawable name like "$_expectedIcon".',
        );

        // Any '@' at all means a resource reference rather than a name.
        final matches =
            RegExp(r"AndroidInitializationSettings\('([^']*)'\)")
                .allMatches(source)
                .map((m) => m.group(1)!)
                .toList();
        expect(matches, isNotEmpty,
            reason: '$path no longer calls AndroidInitializationSettings with a '
                'literal — if this became a variable, this gate is now blind and '
                'must be updated rather than deleted.');
        for (final icon in matches) {
          expect(icon.contains('@'), isFalse,
              reason: 'icon "$icon" is a resource reference, not a drawable name');
          expect(icon.contains('/'), isFalse,
              reason: 'icon "$icon" must be a bare name in the drawable folder');
        }
      });
    }

    test('the notification drawable exists and is a white silhouette', () {
      final file = File(_drawablePath);
      expect(file.existsSync(), isTrue,
          reason: '$_drawablePath is missing; every notification below will '
              'throw invalid_icon again.');

      final xml = file.readAsStringSync();
      expect(xml.contains('<vector'), isTrue,
          reason: 'notification small icons should be vector drawables, not '
              'raster: the system masks and tints them.');
      // Android 8.0+ renders the small icon as a mask tinted to the status-bar
      // colour, so anything but white-on-transparent renders as a grey smudge.
      expect(xml.contains('android:fillColor="#FFFFFFFF"'), isTrue,
          reason: 'notification icons must be solid white; the system applies '
              'its own tint and a coloured icon becomes an unreadable blob.');
    });

    test('the manifest does not reference the orphaned ic_launcher mipmap', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest.contains('@mipmap/ic_launcher'), isFalse,
          reason: 'if the manifest referenced @mipmap/ic_launcher it would be '
              'kept, but it declares @mipmap/launcher_icon — which is why '
              'res/mipmap-*/ic_launcher.png is orphaned and stripped from '
              'release builds. Do not reintroduce a dependency on it.');
    });

    // The drawable existing on disk is NECESSARY BUT NOT SUFFICIENT. Release
    // resource shrinking works from the static reference graph, and this
    // resource is reached only by a runtime getIdentifier() from Dart, so the
    // shrinker deletes it. That was observed directly: the first release build
    // containing ic_stat_sos.xml compiled cleanly, installed cleanly, and then
    // still threw invalid_icon on device because aapt2 had stripped it.
    test('the drawable is explicitly kept against resource shrinking', () {
      final keep = File('android/app/src/main/res/raw/keep.xml');
      expect(keep.existsSync(), isTrue,
          reason: 'res/raw/keep.xml is missing. Nothing references '
              '@drawable/$_expectedIcon statically — it is looked up by name at '
              'runtime from Dart — so release resource shrinking removes it and '
              'the SOS lifeline fails on device with no compile error.');

      expect(keep.readAsStringSync().contains('tools:keep="@drawable/$_expectedIcon"'),
          isTrue,
          reason: 'keep.xml must declare tools:keep="@drawable/$_expectedIcon" '
              'or the shrinker strips the notification icon.');
    });
  });
}