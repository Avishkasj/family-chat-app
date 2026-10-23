import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'theme/extension.dart';

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

extension DateFormatting on BuildContext {
  String get _locale => Localizations.localeOf(this).toLanguageTag();

  String formatTime(DateTime time) => DateFormat.jm(_locale).format(time);

  /// "Today", "Yesterday", weekday within a week, else a date.
  String formatDay(DateTime time) {
    final now = DateTime.now();
    if (isSameDay(time, now)) return l10n.today;
    if (isSameDay(time, now.subtract(const Duration(days: 1)))) {
      return l10n.yesterday;
    }
    if (now.difference(time).inDays < 7) {
      return DateFormat.EEEE(_locale).format(time);
    }
    return DateFormat.yMMMd(_locale).format(time);
  }

  /// Compact timestamp for conversation lists.
  String formatListTime(DateTime time) {
    final now = DateTime.now();
    if (isSameDay(time, now)) return formatTime(time);
    if (now.difference(time).inDays < 7) return formatDay(time);
    return DateFormat.yMd(_locale).format(time);
  }

  String formatLastSeen(DateTime? time) {
    if (time == null) return l10n.offlineStatus;
    final when = isSameDay(time, DateTime.now())
        ? formatTime(time)
        : '${formatDay(time)} ${formatTime(time)}';
    return l10n.lastSeen(when);
  }
}
