import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:characters/characters.dart';

import 's_io.dart' if (dart.library.js_util) 's_web.dart';

const bool releaseMode =
    bool.fromEnvironment('dart.vm.product', defaultValue: false);
const kDartIsWeb = identical(0, 0.0);
const bool profileMode =
    bool.fromEnvironment('dart.vm.profile', defaultValue: false);
const bool debugMode = !releaseMode && !profileMode;

typedef LogFn = void Function(Object? message, LogLevel minLevel,
    LogLevel level, LogColor color, String path);

final class LogLevel {
  final int level;
  const LogLevel(this.level);
  static const debug = LogLevel(100);
  static const info = LogLevel(200);
  static const warn = LogLevel(300);
  static const error = LogLevel(400);
  static const ignore = LogLevel(500);

  String get name {
    return switch (this) {
      < debug => 'none',
      < info => 'debug',
      < warn => 'info',
      < error => 'warn',
      < ignore => 'error',
      _ => 'ignore',
    };
  }

  operator <(LogLevel other) {
    return level < other.level;
  }

  operator >=(LogLevel other) {
    return level >= other.level;
  }
}

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

  String get logName {
    return switch (this) {
      LogColor.info => "[info]",
      LogColor.orange => '[warn]',
      LogColor.red => '[error]',
      LogColor.black ||
      LogColor.green ||
      LogColor.blue ||
      LogColor.magenta ||
      LogColor.cyan ||
      LogColor.grey =>
        '[$name]',
    };
  }

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

extension Log on Logger {
  static final defaultLogger = Logger();
  static int functionLength = 18;

  static bool d(
    Object? info, {
    int position = 0,
    Zone? zone,
    LogBgColor? bgColor,
  }) {
    return defaultLogger._log(
      LogColor.info,
      info,
      zone,
      level: LogLevel.debug,
      position: ++position,
      bgColor: bgColor,
    );
  }

  static bool i(
    Object? info, {
    int position = 0,
    Zone? zone,
    LogBgColor? bgColor,
  }) {
    return defaultLogger._log(
      LogColor.info,
      info,
      zone,
      level: LogLevel.info,
      position: ++position,
      bgColor: bgColor,
    );
  }

  static bool w(
    Object? warn, {
    int position = 0,
    Zone? zone,
    LogBgColor? bgColor,
  }) {
    return defaultLogger._log(
      LogColor.warn,
      warn,
      zone,
      level: LogLevel.warn,
      position: ++position,
      bgColor: bgColor,
    );
  }

  static bool e(
    Object? error, {
    int position = 0,
    Zone? zone,
    LogBgColor? bgColor,
  }) {
    return defaultLogger._log(
      LogColor.error,
      error,
      zone,
      level: LogLevel.error,
      position: ++position,
      bgColor: bgColor,
    );
  }
}

final class Logger {
  static int get functionLength => Log.functionLength;
  LogLevel minLevel = LogLevel.debug;

  Logger({this.label});
  final String? label;

  bool canLog(LogLevel log) {
    return minLevel.level <= log.level;
  }

  /// {@template Logger.logPathFn}
  /// Example:
  /// ```dart
  ///   final log = Logger();
  ///   ...
  ///  final reg = RegExp(r'\((package:)(.+?)/(.*)');
  ///  log.logPathFn = (path) {
  ///    final match = reg.firstMatch(path);
  ///    return switch (match?[2]) {
  ///      == 'hide other package' => false,
  ///      _ => path,
  ///    };
  ///  };
  /// ```
  ///
  /// ```dart
  /// Log.lopPathFn = (path) => path;
  /// ```
  /// ret: false or String?
  /// {@endtemplate}
  LogPathFn? logPathFn;

  LogFn? logFn;

  bool showPath = true;
  int lines = 0;
  bool split = true;
  bool showTag = true;

  bool d(
    Object? info, {
    int lines = 0,
    int position = 0,
    Zone? zone,
    LogBgColor? bgColor,
  }) {
    return _log(
      LogColor.info,
      info,
      zone,
      level: LogLevel.debug,
      position: ++position,
      bgColor: bgColor,
    );
  }

  bool i(
    Object? info, {
    int position = 0,
    Zone? zone,
    LogBgColor? bgColor,
  }) {
    return _log(
      LogColor.info,
      info,
      zone,
      level: LogLevel.info,
      position: ++position,
      bgColor: bgColor,
    );
  }

  bool w(
    Object? warn, {
    int position = 0,
    Zone? zone,
    LogBgColor? bgColor,
  }) {
    return _log(
      LogColor.warn,
      warn,
      zone,
      level: LogLevel.warn,
      position: ++position,
      bgColor: bgColor,
    );
  }

  bool e(
    Object? error, {
    int position = 0,
    Zone? zone,
    LogBgColor? bgColor,
  }) {
    return _log(
      LogColor.error,
      error,
      zone,
      level: LogLevel.error,
      position: ++position,
      bgColor: bgColor,
    );
  }

  bool log(
    LogColor? color,
    Object? message, {
    required LogLevel level,
    int position = 0,
    Zone? zone,
    LogBgColor? bgColor,
  }) {
    color ??= LogColor.info;
    return _log(
      color,
      message,
      zone,
      level: level,
      position: ++position,
      bgColor: bgColor,
    );
  }

  static final reg = RegExp(r' +');

  bool _log(
    LogColor terminalColor,
    Object? message,
    Zone? zone, {
    required LogLevel level,
    int position = 1,
    LogBgColor? bgColor,
  }) {
    if (!canLog(level)) return true;

    position++;
    zone ??= Zone.current;
    var start = '';
    var end = '';

    var label = '';
    if (this.label case var l? when l.isNotEmpty) {
      label = '[$l] ';
    }
    var path = '',
        //  name = '',
        fullFnName = '';

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

      // if (fullFnName.isNotEmpty) {
      //   name = fullFnName.split('.').last;
      //   var padLength = functionLength - label.length;
      //   padLength = padLength.maxThan(0);
      //   if (name.length > padLength) {
      //     final end = (padLength - 3).maxThan(0);
      //     name = '${name.substring(0, end)}...';
      //   } else {
      //     name = name.padRight(padLength);
      //   }
      // }
    } else {
      data = logPathFn?.call('');
    }

    switch (data) {
      case String newPath:
        path = newPath;
      case false:
        return true;
    }

    var color = '';

    if (kDartIsWeb || !isIOS) {
      color = switch (bgColor) {
        LogBgColor color => '\x1B[${terminalColor.code};${color.code}m',
        _ => '\x1B[${terminalColor.code}m',
      };
      start = '$start$color';
      end = '\x1B[0m';
    }

    if (showPath && path.isNotEmpty) {
      end = '$end $path';
    }

    if (logFn case var fn?) {
      try {
        fn(message, minLevel, level, terminalColor, path);
      } catch (_) {}
    }

    final messageLines = switch (message) {
      String message when split => splitString(message),
      String m => LineSplitter.split(m),
      Iterable message when split => message.expand((e) => splitString(e)),
      Iterable<Object?> message => message,
      Object message when split => splitString(message),
      var message => LineSplitter.split(message.toString()),
    };

    final it = messageLines.iterator;

    var index = 0;
    Object? lastLine;
    final limited = lines > 0;
    var printmore = false;
    while (it.moveNext()) {
      index += 1;
      if (limited && index > lines) {
        printmore = true;
        break;
      }
      final currentLine = lastLine;
      lastLine = it.current;
      if (currentLine == null) continue;
      zone.print('$color$currentLine');
    }

    if (showTag) {
      final time = DateTime.now();
      final timeLabel = '${time.year}.${time.month.toString().padLeft(2, '0')}'
          '.${time.day.toString().padLeft(2, '0')} '
          '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}:'
          '${time.second.toString().padLeft(2, '0')}';

      start = '$timeLabel$color ';
    }

    if (lastLine != null) {
      if (path.isNotEmpty) {
        zone.print('$color$lastLine');
        if (printmore) zone.print('...');
        if (showTag) {
          zone.print('$start| $label$fullFnName$end');
        } else {
          zone.print('$color$label$fullFnName$end');
        }
      } else if (showTag) {
        zone.print('$color$lastLine');
        if (printmore) zone.print('...');
        zone.print('$start| $label$fullFnName$end');
      } else {
        zone.print('$label$lastLine$end');
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

  static Iterable<String> splitString(Object source) sync* {
    final sourceStr = source.toString();
    if (_reg.hasMatch(sourceStr) || sourceStr.isEmpty) {
      yield* LineSplitter.split(sourceStr);
      return;
    }
    final rawSource = sourceStr.characters;
    final length = rawSource.length;
    const maxLength = 110;
    const halfLength = maxLength / 2;

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
    }
  }
}
