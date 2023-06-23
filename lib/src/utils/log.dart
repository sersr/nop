import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:characters/characters.dart';

import 'max_min.dart';

const bool releaseMode =
    bool.fromEnvironment('dart.vm.product', defaultValue: false);
const kDartIsWeb = identical(0, 0.0);
const bool profileMode =
    bool.fromEnvironment('dart.vm.profile', defaultValue: false);
const bool debugMode = !releaseMode && !profileMode;
const _colors = ['\x1B[39m', '\x1B[33m', '\x1B[31m'];

typedef LogPathFn = String? Function(String path);

abstract class Log {
  static const int info = 0;
  static const int warn = 1;
  static const int error = 2;
  static int level = 0;
  static int functionLength = 18;
  static final zonePrintLable = Object();

  /// Example:
  /// ```dart
  /// final reg = RegExp(r'\((package:)(.+?)/(.*)');
  /// Log.logPathFn = (path) {
  ///   final newPath = path.replaceFirstMapped(reg, (match) {
  ///     final package = match[2];
  ///     if (package == 'demo') {
  ///       return '(./lib/${match[3]}';
  ///     }
  ///
  ///     return '';
  ///   });
  ///   if (newPath.isEmpty) {
  ///     return null;
  ///   }
  ///   return newPath;
  /// };
  /// ```
  static LogPathFn? logPathFn;

  static Future<R> logRun<R>(Future<R> Function() body,
      {bool canPrint = true, Map<Object, Object>? zoneValues}) {
    var lastPrint = '';
    var count = 1;

    return runZoned(body,
        zoneSpecification: ZoneSpecification(print: (s, d, z, line) {
      if (!canPrint) return;
      if (!debugMode) {
        d.print(z, line);
        return;
      }
      if (lastPrint != line) {
        d.print(z, line);
        lastPrint = line;
        count = 1;
        return;
      } else {
        if (line.length > 24) {
          count++;
          final func = line.substring(0, 24);
          final message = line.substring(24);
          d.print(z, '$func$count>$message');
          return;
        }
        d.print(z, line);
      }
    }), zoneValues: zoneValues);
  }

  static bool i(
    Object? info, {
    bool showPath = true,
    bool onlyDebug = true,
    int lines = 0,
    int position = 0,
    Zone? zone,
    bool split = true,
    bool showTag = true,
  }) {
    return _log(
      Log.info,
      info,
      showPath,
      onlyDebug,
      zone,
      lines: lines,
      position: ++position,
      split: split,
      showTag: showTag,
    );
  }

  static bool w(
    Object? warn, {
    bool showPath = true,
    bool onlyDebug = true,
    int lines = 0,
    int position = 0,
    Zone? zone,
    bool split = true,
    bool showTag = true,
  }) {
    return _log(
      Log.warn,
      warn,
      showPath,
      onlyDebug,
      zone,
      lines: lines,
      position: ++position,
      split: split,
      showTag: showTag,
    );
  }

  static bool e(
    Object? error, {
    bool showPath = true,
    bool onlyDebug = true,
    int lines = 0,
    int position = 0,
    Zone? zone,
    bool split = true,
    bool showTag = true,
  }) {
    return _log(
      Log.error,
      error,
      showPath,
      onlyDebug,
      zone,
      lines: lines,
      position: ++position,
      split: split,
      showTag: showTag,
    );
  }

  static bool log(
    int lv,
    Object? message, {
    bool showPath = true,
    bool onlyDebug = true,
    int lines = 0,
    int position = 0,
    bool split = true,
    bool showTag = true,
    Zone? zone,
  }) {
    return _log(
      lv,
      message,
      showPath,
      onlyDebug,
      zone,
      lines: lines,
      position: ++position,
      split: split,
      showTag: showTag,
    );
  }

  static final reg = RegExp(r' +');

  static bool _log(
    int lv,
    Object? message,
    bool showPath,
    bool onlyDebug,
    Zone? zone, {
    int lines = 0,
    int position = 1,
    bool split = true,
    bool showTag = true,
  }) {
    if (!debugMode && onlyDebug) return true;
    position++;
    zone ??= Zone.current;
    var start = '';
    var end = '';
    var lable = '';
    final zoneLable = zone[zonePrintLable];
    if (zoneLable is String && zoneLable.isNotEmpty) {
      lable = '$zoneLable | ';
    }
    var path = '', name = '';
    if (kDartIsWeb) {
      position += 1;
    }
    if (showTag) {
      final st = StackTrace.current.toString();
      final sp = LineSplitter.split(st);
      var count = -1;
      for (var item in sp) {
        count++;
        if (count == position) {
          final spl = item.split(reg);
          if (spl.length >= 3) {
            String nameList;
            if (kDartIsWeb) {
              nameList = spl.last;
              final head = spl[0].replaceFirst('packages/', 'package:');
              path = logPathFn?.call('($head:${spl[1]})') ?? path;
            } else {
              nameList = spl[1];
              path = logPathFn?.call(spl.last) ?? path;
            }
            final splitted = nameList.split('.');
            name = splitted
                .sublist(
                    splitted.length <= 1 ? 0 : 1, math.min(2, splitted.length))
                .join('.');

            var padLength = functionLength - lable.length;
            padLength = padLength.maxThan(0);
            if (name.length > padLength) {
              final max = (padLength - 3).maxThan(0);
              name = '${name.substring(0, max)}...';
            } else {
              name = name.padRight(padLength);
            }
          }
          break;
        }
      }
    }

    if (!showTag) {
      start = '$start$lable';
    } else {
      start = '$start$lable$name|';
    }

    var color = '';
    if (kDartIsWeb || !Platform.isIOS) {
      if (lv <= 2) {
        color = _colors[lv];
      }
      start = '$color$start';
      end = '\x1B[0m';
    }
    if (showPath) {
      if (debugMode) {
        end = '$end $path';
      } else if (path.isNotEmpty) {
        var pathRemoved = path.replaceAll(')', '');
        end = '$end $pathRemoved:1)';
      }
    }

    List<String> splits;
    if (message is Iterable) {
      var s =
          message.expand((e) => '$e'.split('\n').where((e) => e.isNotEmpty));
      if (split) {
        s = s.expand((e) => splitString(e, lines: lines));
      }
      splits = s.toList();
    } else {
      var s = '$message'.split('\n').where((e) => e.isNotEmpty);
      if (split) {
        s = s.expand((e) => splitString(e, lines: lines));
      }
      splits = s.toList();
    }
    var limitLength = splits.length - 1;
    if (lines > 0) {
      limitLength = math.min(lines, limitLength);
    }
    for (var i = 0; i < splits.length; i++) {
      if (i < limitLength) {
        zone.print('$color${splits[i]}');
      } else {
        var data = splits[i];
        if (data.contains(_reg)) {
          if (!debugMode) {
            data = data.replaceAll(')', '');
            data = '$data:1)';
          }
          data = '$data\n';
        }
        zone.print('$start$data$end');
        break;
      }
    }
    return true;
  }

  static String getLineFromStack({int position = 1}) {
    final st = StackTrace.current.toString();

    final sp = LineSplitter.split(st);
    var count = -1;

    for (var item in sp) {
      count++;
      if (count == position) {
        return item;
      }
    }
    return '';
  }

  static final _reg = RegExp(r'\((package|dart):.*\)');

  static Iterable<String> splitString(Object source, {int lines = 0}) sync* {
    final sourceStr = source.toString();
    if (_reg.hasMatch(sourceStr) || sourceStr.isEmpty) {
      // final first = _reg.firstMatch(_s);
      // print('first: ${first?[0]}');
      yield sourceStr;
      return;
    }
    final rawSource = sourceStr.characters;
    final length = rawSource.length;
    const maxLength = 110;
    const halfLength = maxLength / 2;
    var lineCount = 0;

    for (var i = 0; i < length;) {
      final end = math.min(i + maxLength, length);
      final subC = rawSource.getRange(i, end);
      final sub = subC.toString();

      if (sub.length <= halfLength) {
        yield sub;
        i = end;
      } else {
        final buffer = StringBuffer();
        var hasLenght = maxLength;
        for (var item in subC) {
          if (hasLenght <= 0) break;
          buffer.write(item);
          if (item.length > 1) {
            hasLenght -= 2;
            continue;
          }
          final itemCode = item.codeUnits.first;
          if (itemCode >= 19968 && itemCode <= 40869) {
            hasLenght -= 2;
            continue;
          }
          hasLenght -= 1;
        }
        final source = buffer.toString();
        i += source.characters.length;
        yield source;
      }
      lineCount++;
      if (lines > 0 && lineCount >= lines) {
        break;
      }
    }
  }
}
