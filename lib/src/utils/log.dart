import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:nop/utils.dart';

import 'max_min.dart';

const bool releaseMode =
    bool.fromEnvironment('dart.vm.product', defaultValue: false);
const kDartIsWeb = identical(0, 0.0);
const bool profileMode =
    bool.fromEnvironment('dart.vm.profile', defaultValue: false);
const bool debugMode = !releaseMode && !profileMode;

enum LogColor {
  black('30'),
  red('31'),
  green('32'),
  orange('33'),
  blue('34'),
  magenta('35'),
  cyan('36'),
  grey('37'),
  info('39'); // default

  static LogColor get error => red;
  static LogColor get warn => orange;

  final String code;
  const LogColor(this.code);
}

enum LogBgColor {
  black('40'),
  red('41'),
  green('42'),
  orange('43'),
  blue('44'),
  magenta('45'),
  cyan('46'),
  grey('47'),
  original('49'), // default

  darkGrey('100'),
  lightRed('101'),
  lightGreen('102'),
  yellow('103'),
  lightBlue('104'),
  lightPurple('105'),
  blueGreen('106'),
  white('107');

  final String code;
  const LogBgColor(this.code);
}

typedef LogPathFn = dynamic Function(String path);

abstract class Log {
  static const int info = 9;
  static const int warn = 3;
  static const int error = 1;
  static int level = 0;
  static int functionLength = 18;
  static final zonePrintLabel = Object();

  /// Example:
  /// ```dart
  ///  final reg = RegExp(r'\((package:)(.+?)/(.*)');
  ///  Log.logPathFn = (path) {
  ///    final match = reg.firstMatch(path);
  ///    return switch (match?[2]) {
  ///      == 'hide other package' => false,
  ///      _ => path,
  ///    };
  ///  };
  /// ```
  ///
  /// ret: false or String?
  static LogPathFn? logPathFn;

  static R logRun<R>(R Function() body,
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
    LogBgColor? bgColor,
  }) {
    return _log(
      LogColor.info,
      info,
      showPath,
      onlyDebug,
      zone,
      lines: lines,
      position: ++position,
      split: split,
      showTag: showTag,
      bgColor: bgColor,
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
    LogBgColor? bgColor,
  }) {
    return _log(
      LogColor.warn,
      warn,
      showPath,
      onlyDebug,
      zone,
      lines: lines,
      position: ++position,
      split: split,
      showTag: showTag,
      bgColor: bgColor,
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
    LogBgColor? bgColor,
  }) {
    return _log(
      LogColor.error,
      error,
      showPath,
      onlyDebug,
      zone,
      lines: lines,
      position: ++position,
      split: split,
      showTag: showTag,
      bgColor: bgColor,
    );
  }

  static bool log(
    LogColor? color,
    Object? message, {
    bool showPath = true,
    bool onlyDebug = true,
    int lines = 0,
    int position = 0,
    bool split = true,
    bool showTag = true,
    Zone? zone,
    LogBgColor? bgColor,
  }) {
    color ??= LogColor.info;
    return _log(
      color,
      message,
      showPath,
      onlyDebug,
      zone,
      lines: lines,
      position: ++position,
      split: split,
      showTag: showTag,
      bgColor: bgColor,
    );
  }

  static final reg = RegExp(r' +');

  static bool _log(
    LogColor terminalColor,
    Object? message,
    bool showPath,
    bool onlyDebug,
    Zone? zone, {
    int lines = 0,
    int position = 1,
    bool split = true,
    bool showTag = true,
    LogBgColor? bgColor,
  }) {
    if (!debugMode && onlyDebug) return true;
    position++;
    zone ??= Zone.current;
    var start = '';
    var end = '';
    var label = '';
    final zoneLabel = zone[zonePrintLabel];
    if (zoneLabel is String && zoneLabel.isNotEmpty) {
      label = '$zoneLabel | ';
    }
    var path = '', name = '', fullFnName = '';

    if (kDartIsWeb) {
      position += 1;
    }

    final sp = LineSplitter.split(StackTrace.current.toString());

    final currentPath = sp.elementAtOrNull(position)?.split(reg);

    dynamic data;

    if (currentPath case [String first, String second, ..., String last]) {
      if (kDartIsWeb) {
        assert(() {
          fullFnName = last;
          final head = first.replaceFirst('packages/', 'package:');
          data = logPathFn?.call('($head:$second)');

          return true;
        }());
        if (!debugMode) {
          assert(data == null);
          data = logPathFn?.call('') ?? false;
        }
      } else {
        fullFnName = second;
        if (!debugMode) {
          last = last.replaceFirst(RegExp('\\)\$'), ':1)');
        }
        data = logPathFn?.call(last);
      }

      if (fullFnName.isNotEmpty) {
        name = fullFnName.split('.').last;
        var padLength = functionLength - label.length;
        padLength = padLength.maxThan(0);
        if (name.length > padLength) {
          final end = (padLength - 3).maxThan(0);
          name = '${name.substring(0, end)}...';
        } else {
          name = name.padRight(padLength);
        }
      }
    } else {
      data = logPathFn?.call('');
    }

    switch (data) {
      case String newPath:
        path = newPath;
      case false:
        return true;
    }

    if (!showTag || name.isEmpty) {
      start = '$start$label';
    } else {
      start = '$start$label$name|';
    }

    var color = '';

    if (kDartIsWeb || !Platform.isIOS) {
      color = switch (bgColor) {
        LogBgColor color => '\x1B[${terminalColor.code};${color.code}m',
        _ => '\x1B[${terminalColor.code}m',
      };
      start = '$color$start';
      end = '\x1B[0m';
    }

    if (showPath && path.isNotEmpty) {
      end = '$end $path';
    }

    final messageLines = switch (message) {
      String message when split => splitString(message, lines: lines),
      String message => LineSplitter.split(message),
      Iterable message when split =>
        message.expand((e) => splitString(e, lines: lines)),
      Iterable<Object?> message => message,
      Object message when split => splitString(message, lines: lines),
      var message => [message.toString()],
    };

    final it = messageLines.iterator;

    var index = 0;
    Object? lastLine;
    final limited = lines > 0;
    while (it.moveNext()) {
      index += 1;
      final currentLine = lastLine;
      lastLine = it.current;
      if (limited && index >= lines) {
        break;
      }
      if (currentLine == null) continue;
      zone.print('$color$currentLine');
    }

    if (lastLine != null) {
      if (index == 1) {
        zone.print('$start$lastLine$end');
      } else if (path.isNotEmpty) {
        zone.print('$color$lastLine');
        if (!kDartIsWeb) zone.print('$color==> $label$fullFnName$end');
      } else if (showTag) {
        zone.print('$color$lastLine ==> $label$fullFnName$end');
      } else {
        zone.print('$color$lastLine$end');
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
        yield* LineSplitter.split(sub);
        i = end;
      } else {
        final buffer = StringBuffer();
        var hasLength = maxLength;
        for (var item in subC) {
          if (hasLength <= 0) break;
          if (item == '\n') {
            i += 1;
            break;
          }

          buffer.write(item);
          if (item.length > 1) {
            hasLength -= 2;
            continue;
          }
          final itemCode = item.codeUnits.first;
          if (itemCode >= 19968 && itemCode <= 40869) {
            hasLength -= 2;
            continue;
          }
          hasLength -= 1;
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
