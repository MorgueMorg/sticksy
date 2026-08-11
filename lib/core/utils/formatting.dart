import 'dart:math' as math;

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
  final index = math
      .min((math.log(bytes) / math.log(1024)).floor(), suffixes.length - 1);
  final size = bytes / math.pow(1024, index);
  final text = index == 0 ? size.toStringAsFixed(0) : size.toStringAsFixed(1);
  return '$text ${suffixes[index]}';
}

String formatRelativeDate(DateTime date) {
  final difference = DateTime.now().difference(date);
  if (difference.inSeconds < 60) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  if (difference.inDays < 365) return '${(difference.inDays / 7).floor()}w ago';
  return '${(difference.inDays / 365).floor()}y ago';
}

String pluralise(int count, String singular, [String? plural]) {
  if (count == 1) return '1 $singular';
  return '$count ${plural ?? '${singular}s'}';
}
