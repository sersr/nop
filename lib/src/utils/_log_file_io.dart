import 'dart:io';

import 'package:path/path.dart';

import '../../utils.dart';
import 'log_file.dart' as l;

final class LogFile implements l.LogFile {
  LogFile(this.fileName);

  @override
  final String fileName;
  final _messages = <String>[];
  String? _fileDir;

  Future? _task;

  @override
  void log(
    Object? message,
    LogLevel minLevel,
    LogLevel level,
    LogColor color,
    String path,
  ) {
    final time = DateTime.timestamp();
    final header = '${time.toIso8601String()} | ${level.name} | $path';

    addMessage('$header\n${message.logPretter}'.trim());
  }

  void addMessage(String message) {
    _messages.add(message);
    _cache();
  }

  @override
  void updateLogDir(String dir) {
    _fileDir = dir;
    _cache();
  }

  void _cache() {
    if (_task != null) return;
    if (_fileDir == null) return;
    if (_messages.isEmpty) return;

    _task = _saveMessage()
      ..whenComplete(() {
        Future.delayed(const Duration(seconds: 5), () {
          _task = null;
          _cache();
        });
      });
  }

  Future<void> _saveMessage() async {
    final dir = _fileDir;
    if (dir == null) return;
    if (_messages.isEmpty) return;

    final time = DateTime.now();
    final part = switch (time.hour) {
      <= 6 => 1,
      <= 12 => 2,
      <= 18 => 3,
      _ => 4,
    };
    final date = '${time.year}.${time.month.toString().padLeft(2, '0')}'
        '.${time.day.toString().padLeft(2, '0')}';

    final file = File(join(dir, '$fileName-log-$date.p$part.log'));
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    final o = file.openWrite(mode: FileMode.append);
    final list = List.of(_messages);
    _messages.clear();
    o.writeAll(list, '\n');
    o.write('\n');
    await o.close();
  }
}
