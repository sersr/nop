extension LogMapPrettyExt on Map {
  String logPretty(
      {StringBuffer? buffer, int space = 2, int level = 0, bool isTop = true}) {
    buffer ??= StringBuffer();
    if (isTop) {
      buffer.write('${' ' * space * level}{');
    } else {
      buffer.write('{');
    }
    final childLevel = level + 1;
    final childSpace = ' ' * space * childLevel;
    var isFirst = true;

    for (var MapEntry(key: key, value: value) in entries) {
      if (isFirst) {
        isFirst = false;
        buffer.write('\n$childSpace$key: ');
      } else {
        buffer.write(',\n$childSpace$key: ');
      }

      _logPretty(buffer, value, space, childLevel);
    }

    buffer.write('\n${' ' * space * level}}');

    if (isTop) {
      return buffer.toString();
    }
    return '';
  }
}

void _logPretty(StringBuffer buffer, dynamic value, int space, int level) {
  if (value is Map) {
    if (value.isNotEmpty) {
      value.logPretty(buffer: buffer, space: space, level: level, isTop: false);
      return;
    }
  } else if (value is List) {
    if (value.isNotEmpty) {
      value.logPretty(buffer: buffer, space: space, level: level, isTop: false);
      return;
    }
  }
  buffer.write(value);
}

extension LogListPrettyExt on List {
  String logPretty(
      {StringBuffer? buffer, int space = 2, int level = 0, bool isTop = true}) {
    buffer ??= StringBuffer();
    if (isTop) {
      buffer.write('${' ' * space * level}[');
    } else {
      buffer.write('[');
    }
    final childLevel = level + 1;
    final childSpace = ' ' * space * childLevel;
    var isFirst = true;
    for (var value in this) {
      if (isFirst) {
        isFirst = false;
        buffer.write('\n$childSpace');
      } else {
        buffer.write(',\n$childSpace');
      }

      _logPretty(buffer, value, space, childLevel);
    }

    buffer.write('\n${' ' * space * level}]');
    if (isTop) {
      return buffer.toString();
    }
    return '';
  }
}
