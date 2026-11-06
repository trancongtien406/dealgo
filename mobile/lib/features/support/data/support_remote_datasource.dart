import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/dio_mapper.dart';
import '../domain/support_ticket.dart';

class DioSupportRemoteDataSource implements SupportRepository {
  DioSupportRemoteDataSource({required this.dio});

  final Dio dio;

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  @override
  Future<SupportTicketPage> list({
    required String accessToken,
    SupportListFilter filter = SupportListFilter.all,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.supportTickets,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (filter == SupportListFilter.active) 'state': 'ACTIVE',
          if (filter == SupportListFilter.done) 'state': 'DONE',
        },
        options: _auth(accessToken),
      );
      return decodeSupportPage(requireSuccessData(response.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<SupportTicket> get({
    required String accessToken,
    required String id,
  }) async {
    try {
      final response = await dio.get<Object?>(
        ApiPaths.supportTicket(id),
        options: _auth(accessToken),
      );
      return decodeSupportTicket(requireSuccessData(response.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<SupportTicket> create({
    required String accessToken,
    required NewSupportTicket ticket,
  }) async {
    try {
      final response = await dio.post<Object?>(
        ApiPaths.supportTickets,
        data: {
          'category': ticket.category.wire,
          'subject': ticket.subject,
          'description': ticket.description,
          'role': ticket.role,
          if (ticket.relatedType != null && ticket.relatedId != null) ...{
            'relatedType': ticket.relatedType!.wire,
            'relatedId': ticket.relatedId,
          },
          if (ticket.attachments.isNotEmpty)
            'attachments': [for (final a in ticket.attachments) a.toJson()],
        },
        options: _auth(accessToken),
      );
      return decodeSupportTicket(requireSuccessData(response.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<SupportTicket> addMessage({
    required String accessToken,
    required String id,
    required String body,
    List<SupportUpload> attachments = const [],
  }) async {
    try {
      final response = await dio.post<Object?>(
        ApiPaths.supportTicketMessages(id),
        data: {
          'body': body,
          if (attachments.isNotEmpty)
            'attachments': [for (final a in attachments) a.toJson()],
        },
        options: _auth(accessToken),
      );
      return decodeSupportTicket(requireSuccessData(response.data));
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }

  @override
  Future<Uint8List> attachment({
    required String accessToken,
    required String ticketId,
    required String messageId,
    required int index,
  }) async {
    try {
      final response = await dio.get<List<int>>(
        ApiPaths.supportTicketAttachment(ticketId, messageId, index),
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
          responseType: ResponseType.bytes,
        ),
      );
      return Uint8List.fromList(response.data ?? const []);
    } on DioException catch (error) {
      throw apiExceptionFromDio(error);
    }
  }
}

Never _malformed() => throw const ApiException(
  statusCode: 502,
  message: 'Malformed support ticket',
  errorCode: 'MALFORMED_RESPONSE',
);

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

SupportTicket decodeSupportTicket(Map<String, Object?> data) {
  final id = data['id'];
  final code = data['code'];
  final subject = data['subject'];
  final created = _date(data['createdAt']);
  if (id is! String || code is! String || subject is! String) {
    _malformed();
  }
  if (created == null) {
    _malformed();
  }
  final rawMessages = data['messages'];
  final messages = <SupportMessage>[
    if (rawMessages is List)
      for (final raw in rawMessages)
        if (raw is Map)
          SupportMessage(
            id: '${raw['id']}',
            fromStaff: raw['author'] == 'STAFF',
            body: raw['body'] is String ? raw['body'] as String : '',
            createdAt: _date(raw['createdAt']) ?? created,
            attachments: _attachments(raw['attachments']),
          ),
  ];
  final preview = data['lastMessagePreview'];
  final relatedId = data['relatedId'];
  return SupportTicket(
    id: id,
    code: code,
    category: SupportCategory.fromWire(data['category']),
    subject: subject,
    status: SupportStatus.fromWire(data['status']),
    priority: SupportPriority.fromWire(data['priority']),
    awaitingRequester: data['awaitingRequester'] == true,
    lastMessageAt: _date(data['lastMessageAt']) ?? created,
    createdAt: created,
    relatedType: SupportRelatedType.fromWire(data['relatedType']),
    relatedId: relatedId is String ? relatedId : null,
    preview: preview is String && preview.isNotEmpty ? preview : null,
    resolvedAt: _date(data['resolvedAt']),
    closedAt: _date(data['closedAt']),
    messages: messages,
  );
}

List<SupportAttachment> _attachments(Object? raw) => [
  if (raw is List)
    for (final (i, item) in raw.indexed)
      if (item is Map)
        SupportAttachment(
          index: item['index'] is num ? (item['index'] as num).toInt() : i,
          label: item['label'] is String ? item['label'] as String : '',
          contentType: item['contentType'] is String
              ? item['contentType'] as String
              : 'application/octet-stream',
          sizeBytes: item['sizeBytes'] is num
              ? (item['sizeBytes'] as num).toInt()
              : 0,
        ),
];

SupportTicketPage decodeSupportPage(Map<String, Object?> data) {
  final items = data['items'];
  int count(String key) => data[key] is num ? (data[key] as num).toInt() : 0;
  final tickets = <SupportTicket>[
    if (items is List)
      for (final raw in items)
        if (raw is Map) decodeSupportTicket(raw.cast<String, Object?>()),
  ];
  return SupportTicketPage(
    items: tickets,
    total: data['total'] is num ? count('total') : tickets.length,
    activeCount: count('activeCount'),
    doneCount: count('doneCount'),
    page: count('page') == 0 ? 1 : count('page'),
  );
}

/// In-memory support desk for mock mode and widget tests. Mirrors the backend
/// rules the UI depends on: open-ticket cap, RESOLVED → reopen, CLOSED → 409.
class FakeSupportRepository implements SupportRepository {
  FakeSupportRepository({List<SupportTicket>? seed, this.maxOpen = 5})
    : _tickets = [...?seed];

  final List<SupportTicket> _tickets;
  final int maxOpen;
  final created = <NewSupportTicket>[];
  final sentAttachments = <List<SupportUpload>>[];

  /// Bytes the fake serves for any attachment download.
  Uint8List attachmentBytes = Uint8List(0);
  ApiException? failNext;
  var _serial = 0;

  List<SupportTicket> get tickets => List.unmodifiable(_tickets);

  void _maybeFail() {
    final error = failNext;
    if (error != null) {
      failNext = null;
      throw error;
    }
  }

  @override
  Future<SupportTicketPage> list({
    required String accessToken,
    SupportListFilter filter = SupportListFilter.all,
    int page = 1,
    int limit = 50,
  }) async {
    _maybeFail();
    final sorted = [..._tickets]
      ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    final active = sorted.where((t) => t.status.isActive).length;
    final items = switch (filter) {
      SupportListFilter.all => sorted,
      SupportListFilter.active =>
        sorted.where((t) => t.status.isActive).toList(),
      SupportListFilter.done =>
        sorted.where((t) => !t.status.isActive).toList(),
    };
    final start = (page - 1) * limit;
    final slice = items.skip(start).take(limit).toList(growable: false);
    return SupportTicketPage(
      items: slice,
      total: items.length,
      activeCount: active,
      doneCount: sorted.length - active,
      page: page,
    );
  }

  @override
  Future<SupportTicket> get({
    required String accessToken,
    required String id,
  }) async {
    _maybeFail();
    return _tickets.firstWhere(
      (t) => t.id == id,
      orElse: () => throw const ApiException(
        statusCode: 404,
        message: 'Support ticket not found',
        errorCode: 'SUPPORT_TICKET_NOT_FOUND',
      ),
    );
  }

  @override
  Future<SupportTicket> create({
    required String accessToken,
    required NewSupportTicket ticket,
  }) async {
    _maybeFail();
    if (_tickets.where((t) => t.status.isActive).length >= maxOpen) {
      throw const ApiException(
        statusCode: 409,
        message: 'Too many open support tickets',
        errorCode: 'SUPPORT_TICKET_LIMIT_REACHED',
      );
    }
    created.add(ticket);
    _serial += 1;
    final now = DateTime.now();
    final saved = SupportTicket(
      id: 'ticket-$_serial',
      code: 'DG-000000-${_serial.toString().padLeft(4, '0')}',
      category: ticket.category,
      subject: ticket.subject,
      status: SupportStatus.open,
      priority: ticket.category == SupportCategory.safety
          ? SupportPriority.high
          : SupportPriority.normal,
      awaitingRequester: false,
      lastMessageAt: now,
      createdAt: now,
      relatedType: ticket.relatedType,
      relatedId: ticket.relatedId,
      preview: ticket.description,
      messages: [
        SupportMessage(
          id: 'msg-$_serial',
          fromStaff: false,
          body: ticket.description,
          createdAt: now,
          attachments: _fakeRefs(ticket.attachments),
        ),
      ],
    );
    _tickets.add(saved);
    return saved;
  }

  @override
  Future<SupportTicket> addMessage({
    required String accessToken,
    required String id,
    required String body,
    List<SupportUpload> attachments = const [],
  }) async {
    _maybeFail();
    sentAttachments.add(attachments);
    final index = _tickets.indexWhere((t) => t.id == id);
    if (index < 0) {
      throw const ApiException(
        statusCode: 404,
        message: 'Support ticket not found',
        errorCode: 'SUPPORT_TICKET_NOT_FOUND',
      );
    }
    final current = _tickets[index];
    if (current.status == SupportStatus.closed) {
      throw const ApiException(
        statusCode: 409,
        message: 'This support ticket is closed',
        errorCode: 'SUPPORT_TICKET_CLOSED',
      );
    }
    final now = DateTime.now();
    final next = SupportTicket(
      id: current.id,
      code: current.code,
      category: current.category,
      subject: current.subject,
      status: current.status == SupportStatus.resolved
          ? SupportStatus.inProgress
          : current.status,
      priority: current.priority,
      awaitingRequester: false,
      lastMessageAt: now,
      createdAt: current.createdAt,
      relatedType: current.relatedType,
      relatedId: current.relatedId,
      preview: body,
      closedAt: current.closedAt,
      messages: [
        ...current.messages,
        SupportMessage(
          id: 'msg-${current.messages.length + 1}-$id',
          fromStaff: false,
          body: body,
          createdAt: now,
          attachments: _fakeRefs(attachments),
        ),
      ],
    );
    _tickets[index] = next;
    return next;
  }

  @override
  Future<Uint8List> attachment({
    required String accessToken,
    required String ticketId,
    required String messageId,
    required int index,
  }) async {
    _maybeFail();
    return attachmentBytes;
  }

  static List<SupportAttachment> _fakeRefs(List<SupportUpload> uploads) => [
    for (final (i, upload) in uploads.indexed)
      SupportAttachment(
        index: i,
        label: upload.label ?? 'attachment-${i + 1}',
        contentType: upload.contentType,
        sizeBytes: (upload.contentBase64.length * 3) ~/ 4,
      ),
  ];
}
