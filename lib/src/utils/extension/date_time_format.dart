extension DateTimeFormat on DateTime {
  String get toStringFormat {
    return '$month/$day/$year ${hour.timePadLeft}:${minute.timePadLeft}:${second.timePadLeft} ${hour < 12 || hour >= 24 ? 'AM' : 'PM'}';
  }

  String get hourAndMinuteFormat {
    return '${hour.timePadLeft}:${minute.timePadLeft}';
  }
}

extension DurationAgo on Duration {
  String get ago {
    if (inDays != 0) {
      final day = inDays.abs();
      if (day > 1) {
        return '$day days ago';
      } else {
        return '$day day ago';
      }
    }

    if (inHours != 0) {
      final hour = inHours.abs();
      if (hour > 1) {
        return '$hour hours ago';
      } else {
        return '$hour hour ago';
      }
    }
    if (inMinutes != 0) {
      final minute = inMinutes.abs();
      if (minute > 1) {
        return '$minute minutes ago';
      } else {
        return '$minute minute ago';
      }
    }
    return 'now';
  }
}

extension on int {
  String get timePadLeft {
    return toString().padLeft(2, '0');
  }
}
