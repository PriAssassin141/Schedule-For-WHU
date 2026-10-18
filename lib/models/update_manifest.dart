import 'dart:convert';

/// Version precedence follows numeric components and SemVer prerelease rules.
class AppVersion implements Comparable<AppVersion> {
  final List<int> numbers;
  final List<String> prerelease;
  final String label;

  AppVersion._(this.numbers, this.prerelease, this.label);

  factory AppVersion.parse(String value) {
    final text = value.trim();
    final match = RegExp(
      r'^[vV]?(\d{1,9})\.(\d{1,9})\.(\d{1,9})(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$',
    ).firstMatch(text);
    if (match == null) throw const FormatException('版本号应类似 v1.0.4');
    final prerelease = match[4]?.split('.') ?? <String>[];
    if (prerelease.any((part) => part.isEmpty)) {
      throw const FormatException('预发布版本号格式错误');
    }
    return AppVersion._(
      [for (var i = 1; i <= 3; i++) int.parse(match[i]!)],
      prerelease,
      text.replaceFirst(RegExp(r'^[vV]'), ''),
    );
  }

  @override
  int compareTo(AppVersion other) {
    for (var i = 0; i < 3; i++) {
      final difference = numbers[i].compareTo(other.numbers[i]);
      if (difference != 0) return difference;
    }
    if (prerelease.isEmpty || other.prerelease.isEmpty) {
      if (prerelease.isEmpty && other.prerelease.isEmpty) return 0;
      return prerelease.isEmpty ? 1 : -1;
    }
    for (var i = 0; i < prerelease.length; i++) {
      if (i >= other.prerelease.length) return 1;
      final a = prerelease[i];
      final b = other.prerelease[i];
      final aNumber = BigInt.tryParse(a);
      final bNumber = BigInt.tryParse(b);
      final difference = aNumber != null && bNumber != null
          ? aNumber.compareTo(bNumber)
          : aNumber != null
          ? -1
          : bNumber != null
          ? 1
          : a.compareTo(b);
      if (difference != 0) return difference;
    }
    return prerelease.length.compareTo(other.prerelease.length);
  }
}

/// The manifest uses Beijing time, YYYYMMDDHHmm, as supplied by the publisher.
DateTime parseReleaseTime(Object? value) {
  final text = value?.toString() ?? '';
  if (!RegExp(r'^\d{12}$').hasMatch(text)) {
    throw const FormatException('update-time 应为12位年月日时分');
  }
  final year = int.parse(text.substring(0, 4));
  final month = int.parse(text.substring(4, 6));
  final day = int.parse(text.substring(6, 8));
  final hour = int.parse(text.substring(8, 10));
  final minute = int.parse(text.substring(10, 12));
  final date = DateTime.utc(year, month, day, hour, minute);
  if (year < 2000 ||
      date.year != year ||
      date.month != month ||
      date.day != day ||
      date.hour != hour ||
      date.minute != minute) {
    throw const FormatException('update-time 日期或时间无效');
  }
  return date.subtract(const Duration(hours: 8));
}

String formatReleaseTime(DateTime value) {
  final date = value.toUtc().add(const Duration(hours: 8));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}';
}

class UpdateManifest implements Comparable<UpdateManifest> {
  final AppVersion version;
  final DateTime updatedAt;
  final String description;

  UpdateManifest({
    required this.version,
    required this.updatedAt,
    required this.description,
  });

  factory UpdateManifest.parse(String text) {
    final value = jsonDecode(text.replaceFirst(RegExp('^\uFEFF'), ''));
    if (value is! Map<String, dynamic> || value['latest-version'] is! String) {
      throw const FormatException('缺少 latest-version 版本号');
    }
    final description = value['describe'];
    if (description != null && description is! String) {
      throw const FormatException('describe 应为更新说明文字');
    }
    return UpdateManifest(
      version: AppVersion.parse(value['latest-version'] as String),
      updatedAt: parseReleaseTime(value['update-time']),
      description: (description as String? ?? '').trim(),
    );
  }

  @override
  int compareTo(UpdateManifest other) {
    final difference = version.compareTo(other.version);
    return difference == 0 ? updatedAt.compareTo(other.updatedAt) : difference;
  }

  bool isNewerThan(String installedVersion, DateTime installedReleaseTime) {
    final difference = version.compareTo(AppVersion.parse(installedVersion));
    return difference > 0 ||
        (difference == 0 && updatedAt.isAfter(installedReleaseTime));
  }
}
