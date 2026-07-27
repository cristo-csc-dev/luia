String formatCommentDate(DateTime date, {DateTime? now}) {
  final localDate = date.toLocal();
  final currentTime = (now ?? DateTime.now()).toLocal();
  final difference = currentTime.difference(localDate);

  if (difference.isNegative || difference.inHours < 1) {
    return 'Hace menos de 1 h';
  }

  if (difference.inHours < 24) {
    return 'Hace ${difference.inHours} h';
  }

  if (difference.inDays < 7) {
    return 'Hace ${difference.inDays} d';
  }

  final day = localDate.day.toString().padLeft(2, '0');
  final month = localDate.month.toString().padLeft(2, '0');
  return '$day/$month/${localDate.year}';
}
