import 'dart:convert';

enum AttachmentType { general, prescriptionBag, vaccinationRecord, other }

enum AttachmentSourceKind { gallery, filePicker, inAppCamera }

enum AttachmentShareQuality { original, reduced }

enum AttachmentExportMode {
  recordsOnly,
  originalAttachments,
  reducedAttachments,
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
    this.originalByteSize,
    this.optimizedByteSize,
    this.thumbnailByteSize,
    this.originalSha256,
    this.missingReason,
  });

  static const schema = 'mlmd.attachment';
  static const version = 2;

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
  final int? originalByteSize;
  final int? optimizedByteSize;
  final int? thumbnailByteSize;
  final String? originalSha256;
  final String? missingReason;

  bool get isDeleted => deletedAt != null;
  bool get isImage => mimeType.toLowerCase().startsWith('image/');
  bool get keepsOriginalQuality =>
      attachmentType == AttachmentType.prescriptionBag ||
      attachmentType == AttachmentType.vaccinationRecord;
  bool get isAvailable => missingReason == null;

  EventAttachment copyWith({
    String? attachmentId,
    String? recordId,
    AttachmentType? attachmentType,
    String? fileName,
    String? mimeType,
    AttachmentSourceKind? sourceKind,
    String? managedOriginalUri,
    Object? managedOptimizedUri = _unset,
    Object? thumbnailUri = _unset,
    Object? createdByAuthorProfileId = _unset,
    Object? createdByDeviceProfileId = _unset,
    DateTime? createdAt,
    Object? deletedAt = _unset,
    Object? originalByteSize = _unset,
    Object? optimizedByteSize = _unset,
    Object? thumbnailByteSize = _unset,
    Object? originalSha256 = _unset,
    Object? missingReason = _unset,
  }) {
    return EventAttachment(
      attachmentId: attachmentId ?? this.attachmentId,
      recordId: recordId ?? this.recordId,
      attachmentType: attachmentType ?? this.attachmentType,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      sourceKind: sourceKind ?? this.sourceKind,
      managedOriginalUri: managedOriginalUri ?? this.managedOriginalUri,
      managedOptimizedUri: identical(managedOptimizedUri, _unset)
          ? this.managedOptimizedUri
          : managedOptimizedUri as String?,
      thumbnailUri: identical(thumbnailUri, _unset)
          ? this.thumbnailUri
          : thumbnailUri as String?,
      createdByAuthorProfileId: identical(createdByAuthorProfileId, _unset)
          ? this.createdByAuthorProfileId
          : createdByAuthorProfileId as String?,
      createdByDeviceProfileId: identical(createdByDeviceProfileId, _unset)
          ? this.createdByDeviceProfileId
          : createdByDeviceProfileId as String?,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: identical(deletedAt, _unset)
          ? this.deletedAt
          : deletedAt as DateTime?,
      originalByteSize: identical(originalByteSize, _unset)
          ? this.originalByteSize
          : originalByteSize as int?,
      optimizedByteSize: identical(optimizedByteSize, _unset)
          ? this.optimizedByteSize
          : optimizedByteSize as int?,
      thumbnailByteSize: identical(thumbnailByteSize, _unset)
          ? this.thumbnailByteSize
          : thumbnailByteSize as int?,
      originalSha256: identical(originalSha256, _unset)
          ? this.originalSha256
          : originalSha256 as String?,
      missingReason: identical(missingReason, _unset)
          ? this.missingReason
          : missingReason as String?,
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
    if (managedOptimizedUri != null) 'managedOptimizedUri': managedOptimizedUri,
    if (thumbnailUri != null) 'thumbnailUri': thumbnailUri,
    if (createdByAuthorProfileId != null)
      'createdByAuthorProfileId': createdByAuthorProfileId,
    if (createdByDeviceProfileId != null)
      'createdByDeviceProfileId': createdByDeviceProfileId,
    'createdAt': createdAt.toIso8601String(),
    if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
    if (originalByteSize != null) 'originalByteSize': originalByteSize,
    if (optimizedByteSize != null) 'optimizedByteSize': optimizedByteSize,
    if (thumbnailByteSize != null) 'thumbnailByteSize': thumbnailByteSize,
    if (originalSha256 != null) 'originalSha256': originalSha256,
    if (missingReason != null) 'missingReason': missingReason,
  });

  static EventAttachment? decode(String value) {
    if (value.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic> ||
          decoded['schema'] != schema ||
          (decoded['version'] != 1 && decoded['version'] != version)) {
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
        deletedAt: deletedAtStr != null
            ? DateTime.tryParse(deletedAtStr)
            : null,
        originalByteSize: decoded['originalByteSize'] as int?,
        optimizedByteSize: decoded['optimizedByteSize'] as int?,
        thumbnailByteSize: decoded['thumbnailByteSize'] as int?,
        originalSha256: decoded['originalSha256'] as String?,
        missingReason: decoded['missingReason'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

const Object _unset = Object();
