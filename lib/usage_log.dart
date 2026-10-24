import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Usage events for improving the app, kept only when the user agreed.
/// Records which actions happened and when, never photos, memo text or
/// translations. Stays on this device for now (one JSON line per event).
class UsageLog {
  final File? _file;
  final List<String> _lines = [];

  UsageLog(this._file);

  List<String> get lines => List.unmodifiable(_lines);

  Future<void> load() async {
    final f = _file;
    if (f == null || !await f.exists()) return;
    try {
      _lines
        ..clear()
        ..addAll((await f.readAsLines()).where((l) => l.trim().isNotEmpty));
    } catch (e) {
      debugPrint('CamTrip: could not read usage log: $e');
    }
  }

  Future<void> add(String event, [Map<String, Object?> props = const {}]) async {
    final line = jsonEncode({'t': DateTime.now().toIso8601String(), 'e': event, ...props});
    _lines.add(line);
    final f = _file;
    if (f == null) return;
    try {
      await f.writeAsString('$line\n', mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint('CamTrip: could not write usage log: $e');
    }
  }

  Future<void> clear() async {
    _lines.clear();
    final f = _file;
    if (f != null && await f.exists()) await f.delete();
  }
}
