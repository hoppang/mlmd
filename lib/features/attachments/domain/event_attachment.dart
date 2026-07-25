import 'dart:convert';

enum AttachmentType {
  general,
  prescriptionBag,
  vaccinationRecord,
  other,
}

enum AttachmentSourceKind {
  gallery,
  filePicker,
  inAppCamera,
}

class EventAttachment {
  const EventAttachment({
    required this.attachmentId,
    required this.recordId,
    required this.attachmentType,
    required this.fileName,
    required this.mimeType,
    required this.sourceKind,
    required this.managedOriginalUri,
    this.managedOptimizedUri,
    this.thumbnailUri,
    this.createdByAuthorProfileId,
    this.createdByDeviceProfileId,
    required this.createdAt,
    this.deletedAt,
  });

  static const schema = 'mlmd.attachment';
  static const version = 1;

  final String attachmentId;
  final String recordId;
  final AttachmentType attachmentType;
  final String fileName;
  final String mimeType;
  final AttachmentSourceKind sourceKind;
  final String managedOriginalUri;
  final String? managedOptimizedUri;
  final String? thumbnailUri;
  final String? createdByAuthorProfileId;
  final String? createdByDeviceProfileId;
  final DateTime createdAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  EventAttachment copyWith({
    String? attachmentId,
    String? recordId,
    AttachmentType? attachmentType,
    String? fileName,
    String? mimeType,
    AttachmentSourceKind? sourceKind,
    String? managedOriginalUri,
    String? managedOptimizedUri,
    String? thumbnailUri,
    String? createdByAuthorProfileId,
    String? createdByDeviceProfileId,
    DateTime? createdAt,
    DateTime? deletedAt,
  }) {
    return EventAttachment(
      attachmentId: attachmentId ?? this.attachmentId,
      recordId: recordId ?? this.recordId,
      attachmentType: attachmentType ?? this.attachmentType,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      sourceKind: sourceKind ?? this.sourceKind,
      managedOriginalUri: managedOriginalUri ?? this.managedOriginalUri,
      managedOptimizedUri: managedOptimizedUri ?? this.managedOptimizedUri,
      thumbnailUri: thumbnailUri ?? this.thumbnailUri,
      createdByAuthorProfileId:
          createdByAuthorProfileId ?? this.createdByAuthorProfileId,
      createdByDeviceProfileId:
          createdByDeviceProfileId ?? this.createdByDeviceProfileId,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  String encode() => jsonEncode({
        'schema': schema,
        'version': version,
        'attachmentId': attachmentId,
        'recordId': recordId,
        'attachmentType': attachmentType.name,
        'fileName': fileName,
        'mimeType': mimeType,
        'sourceKind': sourceKind.name,
        'managedOriginalUri': managedOriginalUri,
        if (managedOptimizedUri != null)
          'managedOptimizedUri': managedOptimizedUri,
        if (thumbnailUri != null) 'thumbnailUri': thumbnailUri,
        if (createdByAuthorProfileId != null)
          'createdByAuthorProfileId': createdByAuthorProfileId,
        if (createdByDeviceProfileId != null)
          'createdByDeviceProfileId': createdByDeviceProfileId,
        'createdAt': createdAt.toIso8601String(),
        if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
      });

  static EventAttachment? decode(String value) {
    if (value.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic> ||
          decoded['schema'] != schema ||
          decoded['version'] != version) {
        return null;
      }

      final attachmentId = decoded['attachmentId'] as String?;
      final recordId = decoded['recordId'] as String?;
      final attachmentTypeName = decoded['attachmentType'] as String?;
      final fileName = decoded['fileName'] as String?;
      final mimeType = decoded['mimeType'] as String?;
      final sourceKindName = decoded['sourceKind'] as String?;
      final managedOriginalUri = decoded['managedOriginalUri'] as String?;
      final createdAtStr = decoded['createdAt'] as String?;

      if (attachmentId == null ||
          recordId == null ||
          attachmentTypeName == null ||
          fileName == null ||
          mimeType == null ||
          sourceKindName == null ||
          managedOriginalUri == null ||
          createdAtStr == null) {
        return null;
      }

      final attachmentType = AttachmentType.values
          .where((e) => e.name == attachmentTypeName)
          .firstOrNull;
      final sourceKind = AttachmentSourceKind.values
          .where((e) => e.name == sourceKindName)
          .firstOrNull;
      final createdAt = DateTime.tryParse(createdAtStr);

      if (attachmentType == null || sourceKind == null || createdAt == null) {
        return null;
      }

      final deletedAtStr = decoded['deletedAt'] as String?;

      return EventAttachment(
        attachmentId: attachmentId,
        recordId: recordId,
        attachmentType: attachmentType,
        fileName: fileName,
        mimeType: mimeType,
        sourceKind: sourceKind,
        managedOriginalUri: managedOriginalUri,
        managedOptimizedUri: decoded['managedOptimizedUri'] as String?,
        thumbnailUri: decoded['thumbnailUri'] as String?,
        createdByAuthorProfileId:
            decoded['createdByAuthorProfileId'] as String?,
        createdByDeviceProfileId:
            decoded['createdByDeviceProfileId'] as String?,
        createdAt: createdAt,
        deletedAt: deletedAtStr != null ? DateTime.tryParse(deletedAtStr) : null,
      );
    } catch (_) {
      return null;
    }
  }
}
