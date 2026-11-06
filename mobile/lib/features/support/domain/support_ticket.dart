import 'dart:typed_data';

/// Help-center tickets (S021–S023), backed by `/v1/support/tickets`.
enum SupportCategory {
  ride('RIDE'),
  food('FOOD'),
  payment('PAYMENT'),
  account('ACCOUNT'),
  safety('SAFETY'),
  other('OTHER');

  const SupportCategory(this.wire);
  final String wire;

  static SupportCategory fromWire(Object? value) => SupportCategory.values
      .firstWhere((c) => c.wire == value, orElse: () => SupportCategory.other);
}

enum SupportStatus {
  open('OPEN'),
  inProgress('IN_PROGRESS'),
  resolved('RESOLVED'),
  closed('CLOSED');

  const SupportStatus(this.wire);
  final String wire;

  bool get isActive => this == open || this == inProgress;

  static SupportStatus fromWire(Object? value) => SupportStatus.values
      .firstWhere((s) => s.wire == value, orElse: () => SupportStatus.open);
}

enum SupportPriority {
  low('LOW'),
  normal('NORMAL'),
  high('HIGH'),
  urgent('URGENT');

  const SupportPriority(this.wire);
  final String wire;

  static SupportPriority fromWire(Object? value) => SupportPriority.values
      .firstWhere((p) => p.wire == value, orElse: () => SupportPriority.normal);
}

enum SupportRelatedType {
  ride('RIDE'),
  foodOrder('FOOD_ORDER');

  const SupportRelatedType(this.wire);
  final String wire;

  static SupportRelatedType? fromWire(Object? value) {
    for (final type in SupportRelatedType.values) {
      if (type.wire == value) return type;
    }
    return null;
  }
}

/// `ACTIVE` = open/in progress, `DONE` = resolved/closed.
enum SupportListFilter { all, active, done }

/// Max files per message (backend DEC-PROD-020).
const supportMaxAttachments = 3;

/// Stored attachment metadata; bytes via [SupportRepository.attachment].
class SupportAttachment {
  const SupportAttachment({
    required this.index,
    required this.label,
    required this.contentType,
    required this.sizeBytes,
  });

  final int index;
  final String label;
  final String contentType;
  final int sizeBytes;

  bool get isImage => contentType.startsWith('image/');
}

/// A file picked in the composer, sent as base64.
class SupportUpload {
  const SupportUpload({
    required this.contentType,
    required this.contentBase64,
    this.label,
  });

  final String contentType;
  final String contentBase64;
  final String? label;

  Map<String, Object?> toJson() => {
    if (label != null) 'label': label,
    'contentType': contentType,
    'contentBase64': contentBase64,
  };
}

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.fromStaff,
    required this.body,
    required this.createdAt,
    this.attachments = const [],
  });

  final String id;
  final bool fromStaff;
  final String body;
  final DateTime createdAt;
  final List<SupportAttachment> attachments;
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.code,
    required this.category,
    required this.subject,
    required this.status,
    required this.priority,
    required this.awaitingRequester,
    required this.lastMessageAt,
    required this.createdAt,
    this.relatedType,
    this.relatedId,
    this.preview,
    this.resolvedAt,
    this.closedAt,
    this.messages = const [],
  });

  final String id;
  final String code;
  final SupportCategory category;
  final String subject;
  final SupportStatus status;
  final SupportPriority priority;

  /// The latest message is from DealGo support ("Đã phản hồi").
  final bool awaitingRequester;
  final DateTime lastMessageAt;
  final DateTime createdAt;
  final SupportRelatedType? relatedType;
  final String? relatedId;
  final String? preview;
  final DateTime? resolvedAt;
  final DateTime? closedAt;
  final List<SupportMessage> messages;
}

class SupportTicketPage {
  const SupportTicketPage({
    required this.items,
    required this.total,
    required this.activeCount,
    required this.doneCount,
    this.page = 1,
  });

  final List<SupportTicket> items;
  final int total;
  final int activeCount;
  final int doneCount;
  final int page;
}

class NewSupportTicket {
  const NewSupportTicket({
    required this.category,
    required this.subject,
    required this.description,
    required this.role,
    this.relatedType,
    this.relatedId,
    this.attachments = const [],
  });

  final SupportCategory category;
  final String subject;
  final String description;
  final List<SupportUpload> attachments;

  /// CUSTOMER / DRIVER / MERCHANT — the app shell the user writes from.
  final String role;
  final SupportRelatedType? relatedType;
  final String? relatedId;
}

abstract interface class SupportRepository {
  Future<SupportTicketPage> list({
    required String accessToken,
    SupportListFilter filter = SupportListFilter.all,
    int page = 1,
    int limit = 50,
  });

  Future<SupportTicket> get({required String accessToken, required String id});

  Future<SupportTicket> create({
    required String accessToken,
    required NewSupportTicket ticket,
  });

  Future<SupportTicket> addMessage({
    required String accessToken,
    required String id,
    required String body,
    List<SupportUpload> attachments = const [],
  });

  /// Bytes of one attachment on my ticket (authorised download).
  Future<Uint8List> attachment({
    required String accessToken,
    required String ticketId,
    required String messageId,
    required int index,
  });
}
