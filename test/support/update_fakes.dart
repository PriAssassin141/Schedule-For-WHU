import 'dart:convert';

import 'package:class_manager/models/update_manifest.dart';
import 'package:class_manager/services/quark_update_service.dart';

UpdateManifest sampleUpdate({
  String version = 'v1.0.4',
  Object time = 202610170013,
  String description = '修复已知问题，优化课表体验。',
}) => UpdateManifest.parse(
  jsonEncode({
    'latest-version': version,
    'update-time': time,
    'describe': description,
  }),
);

class StubUpdateChecker implements UpdateChecker {
  final Future<UpdateManifest> Function() load;
  int closeCount = 0;
  StubUpdateChecker(this.load);
  @override
  Future<UpdateManifest> fetchLatest() => load();
  @override
  void close() => closeCount++;
}
