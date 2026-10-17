enum HistoryKind { ride, food }

class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.meta,
    required this.status,
    required this.amountVnd,
  });

  final String id;
  final HistoryKind kind;
  final String title;
  final String meta;
  final String status;
  final int? amountVnd;
}
