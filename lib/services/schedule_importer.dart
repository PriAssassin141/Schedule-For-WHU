import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart';

import 'package:class_manager/models/periods.dart';
import 'package:class_manager/services/schedule_parser.dart';
import 'package:class_manager/utils/weeks.dart';

/// 导入结果。
class ImportResult {
  final List<ParsedCourse> courses;
  final String note;
  ImportResult(this.courses, {this.note = ''});
}

/// 根据文件名与内容解析课表，返回解析出的课程列表。
/// 支持：.doc / .docx / .xls / .xlsx（含教务系统导出的 MHTML 伪 .doc）。
Future<ImportResult> importScheduleFile(
    String fileName, Uint8List bytes) async {
  final ext = fileName.toLowerCase().split('.').last;
  try {
    if (_looksLikeHtml(bytes)) {
      return _importHtml(bytes);
    }
    if (_isZip(bytes)) {
      return _importZip(bytes, ext);
    }
    return _importBinaryDoc(bytes);
  } catch (e) {
    return ImportResult([], note: '解析失败：$e');
  }
}

// ---------- 文件嗅探 ----------

bool _isZip(Uint8List bytes) =>
    bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B;

bool _looksLikeHtml(Uint8List bytes) {
  final head = utf8.decode(bytes.sublist(0, bytes.length.clamp(0, 4096)),
      allowMalformed: true);
  return head.startsWith('Mime-Version') ||
      head.contains('Content-Type: text/html') ||
      head.contains('<html') ||
      head.contains('<!DOCTYPE') ||
      head.contains('<table') ||
      head.contains('<TABLE');
}

String _decodeText(Uint8List bytes) {
  final s = utf8.decode(bytes, allowMalformed: true);
  final bad = s.split('').where((c) => c == '\uFFFD').length;
  if (bad > 0 && bad > s.length * 0.02) {
    try {
      return gbk.decode(bytes);
    } catch (_) {}
  }
  return s;
}

// ---------- HTML / MHTML ----------

ImportResult _importHtml(Uint8List bytes) {
  var text = _decodeText(bytes);
  // MHTML 时抽取 HTML 部分（边界为 --NEXT.ITEM-BOUNDARY）
  if (text.startsWith('Mime-Version') ||
      text.contains('Content-Type: text/html')) {
    final starts = [text.indexOf('<!DOCTYPE'), text.indexOf('<html')]
        .where((i) => i >= 0)
        .toList()
      ..sort();
    if (starts.isNotEmpty) {
      final start = starts.first;
      final endBoundary = text.indexOf('--NEXT.ITEM-BOUNDARY', start);
      text = text.substring(start, endBoundary > start ? endBoundary : text.length);
    }
  }
  final doc = html_parser.parse(text);
  final tables = doc.querySelectorAll('table');
  if (tables.isEmpty) {
    return ImportResult([], note: '未在文件中找到表格');
  }
  // 选表：优先含「星期」的表头 + 单元格最多的表（避免选中标题表）
  dom.Element table = tables.first;
  var bestScore = -1;
  for (final t in tables) {
    final tds = t.querySelectorAll('td').length;
    var score = tds;
    if (t.text.contains('星期')) score += 100000;
    if (t.text.contains('节次')) score += 50000;
    if (score > bestScore) {
      bestScore = score;
      table = t;
    }
  }

  // 快路径：教务系统导出表格带 jc / xq / rowspan 属性
  final cells = table.querySelectorAll('td');
  final hasAttrs = cells.any((td) {
    final attrs = td.attributes;
    return RegExp(r'^\d+$').hasMatch(attrs['jc'] ?? '') &&
        RegExp(r'^\d+$').hasMatch(attrs['xq'] ?? '');
  });
  if (hasAttrs) {
    return _parseHtmlAuthoritative(cells);
  }
  return _parseHtmlGrid(table);
}

List<String> _tdLines(dom.Element? td) {
  if (td == null) return [];
  // 只取叶子 div（避免外层容器 div.text 拼接全部内容）
  final divs = td
      .querySelectorAll('div')
      .where((d) => d.querySelector('div') == null)
      .toList();
  if (divs.isNotEmpty) {
    final lines = <String>[];
    for (final d in divs) {
      final t = d.text.replaceAll('\u00a0', ' ').trim();
      lines.add(t);
    }
    return lines;
  }
  // 无 div：按节点遍历，<br> 转换行
  final sb = StringBuffer();
  for (final node in td.nodes) {
    if (node is dom.Text) {
      sb.write(node.text);
    } else if (node is dom.Element) {
      if (node.localName == 'br') sb.write('\n');
      sb.write(node.text);
    }
  }
  return sb
      .toString()
      .replaceAll('\u00a0', ' ')
      .split(RegExp(r'[\r\n]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// 教务系统 fast path：利用 jc/xq/rowspan 属性精确定位。
ImportResult _parseHtmlAuthoritative(List<dom.Element> cells) {
  final result = <ParsedCourse>[];
  for (final td in cells) {
    final attrs = td.attributes;
    final jc = int.tryParse(attrs['jc'] ?? '');
    final xq = int.tryParse(attrs['xq'] ?? '');
    if (jc == null ||
        xq == null ||
        jc < 1 ||
        jc > kPeriodCount ||
        xq < 1 ||
        xq > 7) {
      continue;
    }
    final span =
        (int.tryParse(attrs['rowspan'] ?? '1') ?? 1).clamp(1, kPeriodCount - jc + 1);
    final lines = _tdLines(td);
    for (final chunk in splitEntries(lines)) {
      final pc = fillCourseEntry(chunk, xq, jc, jc + span - 1);
      if (pc.name.isNotEmpty) result.add(pc);
    }
  }
  return ImportResult(result, note: '已识别教务系统课表标记（节次/星期/合并行）');
}

/// 通用 HTML 表格：虚拟网格展开 rowspan/colspan。
ImportResult _parseHtmlGrid(dom.Element table) {
  final grid = <List<RawCell>>[];
  final trs = table.querySelectorAll('tr');
  final occupancy = <int, int>{}; // col → 剩余行数
  for (final tr in trs) {
    final row = <RawCell>[];
    final tds =
        tr.children.where((e) => e.localName == 'td').toList();
    var col = 0;
    for (final td in tds) {
      while (occupancy.containsKey(col)) {
        row.add(const RawCell(lines: []));
        final left = occupancy[col]! - 1;
        if (left <= 0) {
          occupancy.remove(col);
        } else {
          occupancy[col] = left;
        }
        col++;
      }
      final attrs = td.attributes;
      final rs = (int.tryParse(attrs['rowspan'] ?? '1') ?? 1).clamp(1, 20);
      final cs = (int.tryParse(attrs['colspan'] ?? '1') ?? 1).clamp(1, 12);
      final lines = _tdLines(td);
      row.add(RawCell(lines: lines, rowspan: rs, colspan: cs));
      for (var k = 1; k < cs; k++) {
        row.add(const RawCell(lines: []));
      }
      if (rs > 1) {
        for (var k = 0; k < cs; k++) {
          occupancy[col + k] = rs - 1;
        }
      }
      col += cs;
    }
    while (occupancy.containsKey(col)) {
      row.add(const RawCell(lines: []));
      final left = occupancy[col]! - 1;
      if (left <= 0) {
        occupancy.remove(col);
      } else {
        occupancy[col] = left;
      }
      col++;
    }
    grid.add(row);
  }
  return ImportResult(parseScheduleGrid(grid), note: '已从 HTML 表格解析');
}

// ---------- zip 类（docx / xlsx） ----------

ImportResult _importZip(Uint8List bytes, String ext) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final names = archive.files.where((f) => f.isFile).map((f) => f.name).toList();
  if (ext == 'docx' || names.any((n) => n == 'word/document.xml')) {
    final entry = archive.files.firstWhere((f) => f.name == 'word/document.xml',
        orElse: () => throw StateError('不是有效的 docx 文件'));
    return _parseDocx(entry.content);
  }
  return _parseXlsx(archive);
}

ImportResult _parseDocx(Uint8List xmlBytes) {
  final doc = XmlDocument.parse(utf8.decode(xmlBytes, allowMalformed: true));
  final tbls = doc.findAllElements('tbl', namespaceUri: '*').toList();
  if (tbls.isEmpty) {
    return ImportResult([], note: 'docx 中没有表格');
  }
  var best = tbls.first;
  var bestScore = -1;
  for (final t in tbls) {
    final score = t.findAllElements('tc', namespaceUri: '*').length;
    if (score > bestScore) {
      bestScore = score;
      best = t;
    }
  }
  return ImportResult(parseScheduleGrid(_docxGrid(best)),
      note: '已从 docx 表格解析');
}

List<List<RawCell>> _docxGrid(XmlElement tbl) {
  final grid = <List<RawCell>>[];
  // col → 处于纵向合并期（剩余应补的空行数）
  final pending = <int, int>{};
  for (final tr in tbl.findElements('tr', namespaceUri: '*')) {
    final row = <RawCell>[];
    final tcs = tr.findElements('tc', namespaceUri: '*').toList();
    var col = 0;
    for (final tc in tcs) {
      while (pending.containsKey(col)) {
        row.add(const RawCell(lines: []));
        final left = pending[col]! - 1;
        if (left <= 0) {
          pending.remove(col);
        } else {
          pending[col] = left;
        }
        col++;
      }
      final lines = _cellDocxLines(tc);
      final tcPr = tc.findElements('tcPr', namespaceUri: '*').isEmpty
          ? null
          : tc.findElements('tcPr', namespaceUri: '*').first;
      final vMerge =
          tcPr?.findElements('vMerge', namespaceUri: '*').firstOrNull;
      final gridSpan = int.tryParse(tcPr
                  ?.findElements('gridSpan', namespaceUri: '*')
                  .firstOrNull
                  ?.getAttribute('w:val') ??
              '1') ??
          1;
      var rowspan = 1;
      if (vMerge != null) {
        final val = vMerge.getAttribute('w:val');
        if (val == 'restart') {
          rowspan = 2; // 至少两行，遇到 continue 继续延长
          pending[col] = 1;
        } else if (val == 'continue') {
          pending[col] = (pending[col] ?? 1) + 0;
        }
      }
      row.add(RawCell(lines: lines, rowspan: rowspan, colspan: gridSpan.clamp(1, 12)));
      for (var k = 1; k < gridSpan; k++) {
        row.add(const RawCell(lines: []));
      }
      col += gridSpan;
      // continue 单元格自身占位
      if (vMerge?.getAttribute('w:val') == 'continue') {
        pending[col - 1] = (pending[col - 1] ?? 1);
      }
    }
    while (pending.isNotEmpty && pending.containsKey(col)) {
      row.add(const RawCell(lines: []));
      final left = pending[col]! - 1;
      if (left <= 0) {
        pending.remove(col);
      } else {
        pending[col] = left;
      }
      col++;
    }
    grid.add(row);
  }
  return grid;
}

List<String> _cellDocxLines(XmlElement tc) {
  final lines = <String>[];
  for (final p in tc.findAllElements('p', namespaceUri: '*')) {
    final sb = StringBuffer();
    for (final node in p.descendants.whereType<XmlText>()) {
      sb.write(node.value);
    }
    if (p.findAllElements('br', namespaceUri: '*').isNotEmpty) {
      sb.write('\n');
    }
    final t = sb.toString().replaceAll('\u00a0', ' ').trim();
    if (t.isNotEmpty) lines.add(t);
  }
  return lines;
}

ImportResult _parseXlsx(Archive archive) {
  final sharedStrings = <String>[];
  try {
    final sst =
        archive.files.firstWhere((f) => f.name == 'xl/sharedStrings.xml');
    final doc =
        XmlDocument.parse(utf8.decode(sst.content, allowMalformed: true));
    for (final si in doc.findAllElements('si')) {
      final sb = StringBuffer();
      for (final t in si.findAllElements('t')) {
        sb.write(t.innerText);
      }
      sharedStrings.add(sb.toString());
    }
  } catch (_) {}

  final sheetFiles = archive.files
      .where((f) =>
          f.isFile &&
          f.name.startsWith('xl/worksheets/sheet') &&
          f.name.endsWith('.xml'))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  if (sheetFiles.isEmpty) {
    return ImportResult([], note: 'xlsx 中没有工作表');
  }
  final sheet = sheetFiles.first;
  final doc = XmlDocument.parse(utf8.decode(sheet.content, allowMalformed: true));

  String cellText(XmlElement c) {
    final t = c.getAttribute('t') ?? '';
    final v = c.findElements('v').firstOrNull?.innerText ?? '';
    if (t == 's') {
      final i = int.tryParse(v) ?? -1;
      return i >= 0 && i < sharedStrings.length ? sharedStrings[i] : '';
    }
    if (t == 'inlineStr') {
      final sb = StringBuffer();
      for (final tx in c.findAllElements('t')) {
        sb.write(tx.innerText);
      }
      return sb.toString();
    }
    return v;
  }

  // 合并单元格：ref 如 "D6:G9"
  final merges = <String, (int rows, int cols)>{};
  for (final mc in doc.findAllElements('mergeCell')) {
    final ref = mc.getAttribute('ref') ?? '';
    final parts = ref.split(':');
    if (parts.length != 2) continue;
    final a = cellRef(parts[0]);
    final b = cellRef(parts[1]);
    if (a == null || b == null) continue;
    merges['${a.$2}:${a.$1}'] =
        (b.$2 - a.$2 + 1, b.$1 - a.$1 + 1);
  }

  final cellsRaw = <String, String>{};
  var maxR = 0, maxC = 0;
  for (final row in doc.findAllElements('row')) {
    for (final c in row.findElements('c')) {
      final ref = c.getAttribute('r') ?? '';
      final pos = cellRef(ref);
      if (pos == null) continue;
      final text = cellText(c);
      cellsRaw['${pos.$2}:${pos.$1}'] = text;
      if (pos.$2 > maxR) maxR = pos.$2;
      if (pos.$1 > maxC) maxC = pos.$1;
    }
  }
  if (maxR == 0) return ImportResult([], note: 'xlsx 为空表');

  final grid = <List<RawCell>>[];
  for (var r = 1; r <= maxR; r++) {
    final row = <RawCell>[];
    for (var c = 1; c <= maxC; c++) {
      final key = '$r:$c';
      final merge = merges[key];
      final text = cellsRaw[key] ?? '';
      final lines = text
              .split(RegExp(r'[\r\n]+'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
      if (merge != null) {
        row.add(RawCell(lines: lines, rowspan: merge.$1, colspan: merge.$2));
        for (var k = 1; k < merge.$2; k++) {
          row.add(const RawCell(lines: []));
        }
      } else {
        row.add(RawCell(lines: lines));
      }
    }
    grid.add(row);
  }
  return ImportResult(parseScheduleGrid(grid), note: '已从 xlsx 表格解析');
}

(int, int)? cellRef(String ref) {
  final m = RegExp(r'^([A-Za-z]+)(\d+)$').firstMatch(ref.trim());
  if (m == null) return null;
  var c = 0;
  for (final ch in m.group(1)!.toUpperCase().split('')) {
    c = c * 26 + (ch.codeUnitAt(0) - 64);
  }
  return (c, int.parse(m.group(2)!));
}

// ---------- 二进制 .doc（OLE，非 MHTML）启发式 ----------

ImportResult _importBinaryDoc(Uint8List bytes) {
  final text = _decodeUtf16Heuristic(bytes);
  if (text.isEmpty) {
    return ImportResult([], note: '无法从该 .doc 提取文本，请另存为 .docx 后重试');
  }
  final lines = text
      .split(RegExp(r'[\r\n\x07]+'))
      .map((s) => s.replaceAll(RegExp(r'[\x00-\x1f]'), ' ').trim())
      .where((s) => s.isNotEmpty)
      .toList();

  final result = <ParsedCourse>[];
  var currentPeriod = 0;
  var rowEntryCount = 0;
  CellChunk? cur;
  for (final line in lines) {
    final pn = RegExp(r'^第([一二三四五六七八九十]{1,2})节').firstMatch(line);
    if (pn != null) {
      currentPeriod = chineseNumber(pn.group(1)!) ?? 0;
      rowEntryCount = 0;
      cur = null;
      continue;
    }
    final weekM = weekPrefixRe.firstMatch(line);
    if (weekM != null) {
      if (cur != null) {
        _pushHeuristic(result, cur, currentPeriod, rowEntryCount);
        rowEntryCount++;
      }
      cur = CellChunk(Weeks.canonical(weekM.group(1)!), []);
      final rest = line.substring(weekM.end).trim();
      if (rest.isNotEmpty) cur.lines.add(rest);
      continue;
    }
    cur?.lines.add(line);
  }
  if (cur != null) {
    _pushHeuristic(result, cur, currentPeriod, rowEntryCount);
  }
  return ImportResult(
    result,
    note: '从 .doc 提取文本解析，星期/节次可能不准，请在预览页核对',
  );
}

void _pushHeuristic(
    List<ParsedCourse> target, CellChunk chunk, int period, int idx) {
  final day = idx % 7 + 1;
  final p = period.clamp(1, kPeriodCount);
  final pc = fillCourseEntry(chunk, day, p, p);
  if (pc.name.isEmpty) return;
  pc.note = pc.note.isEmpty ? '（.doc 解析，请核对时间/星期）' : pc.note;
  target.add(pc);
}

String _decodeUtf16Heuristic(Uint8List bytes) {
  String? best;
  var bestScore = 0;
  for (final offset in [0, 1]) {
    final sb = StringBuffer();
    var cjk = 0;
    for (var i = offset; i + 1 < bytes.length; i += 2) {
      final code = bytes[i] | (bytes[i + 1] << 8);
      if (code >= 0x3400 && code <= 0x9FFF) cjk++;
      if (code == 0) {
        sb.write(' ');
      } else {
        sb.writeCharCode(code);
      }
    }
    if (cjk > bestScore) {
      bestScore = cjk;
      best = sb.toString();
    }
  }
  final s = best ?? '';
  final idx = s.indexOf('节次');
  if (idx < 0 || s.length < 2000) return s;
  final start = (idx - 4000).clamp(0, s.length);
  final end = (idx + 16000).clamp(0, s.length);
  return s.substring(start, end);
}
