import 'dart:convert';
import 'dart:io';

import 'package:class_manager/config/release_metadata.dart';
import 'package:class_manager/models/update_manifest.dart';
import 'package:class_manager/services/quark_update_service.dart';

/// Explicit read-only smoke check, using exactly the app's anonymous transport.
Future<void> main() async {
  try {
    final release = await QuarkUpdateService().fetchLatest();
    final pubspec = await File('pubspec.yaml').readAsString();
    final installed = RegExp(
      r'^version: ([^+\s]+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1)!;
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert({
        'latest-version': 'v${release.version.label}',
        'update-time': formatReleaseTime(release.updatedAt),
        'describe': release.description,
        'needs-update': release.isNewerThan(
          installed,
          parseReleaseTime(appReleaseUpdateTime),
        ),
      }),
    );
  } catch (error) {
    stderr.writeln('检查失败：$error');
    exitCode = 1;
  }
}
