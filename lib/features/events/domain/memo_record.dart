import 'dart:convert';

import '../../../l10n/app_localizations.dart';

/// Structured payload for a memo event (UX-033).
///
/// Multi-memo structure replacing legacy single daily diary.
/// Stored in [ActivityEntity.structuredDataJson] under schema `mlmd.memo` version 1.
class MemoRecord {
  const MemoRecord({
    this.recordId,
    this.childId,
    required this.occurredAt,
    required this.content,
    this.inputSource = 'typed',
    this.legacyTitle,
    this.rawSttText,
    this.createdByAuthorProfileId,
    this.createdByDeviceProfileId,
    this.createdAt,
    this.lastModified,
  });

  static const schema = 'mlmd.memo';
  static const version = 1;

  final String? recordId;
  final String? childId;
  final DateTime occurredAt;

  /// Main body content of the memo.
  final String content;

  /// Input source: 'typed', 'stt', or 'mixed'.
  final String inputSource;

  /// Preserved title from legacy diary migration.
  final String? legacyTitle;

  /// Preserved original uncorrected text from STT input.
  final String? rawSttText;

  final String? createdByAuthorProfileId;
  final String? createdByDeviceProfileId;
  final DateTime? createdAt;
  final DateTime? lastModified;

  MemoRecord copyWith({
    String? recordId,
    String? childId,
    DateTime? occurredAt,
    String? content,
    String? inputSource,
    String? legacyTitle,
    bool clearLegacyTitle = false,
    String? rawSttText,
    bool clearRawSttText = false,
    String? createdByAuthorProfileId,
    String? createdByDeviceProfileId,
    DateTime? createdAt,
    DateTime? lastModified,
  }) {
    return MemoRecord(
      recordId: recordId ?? this.recordId,
      childId: childId ?? this.childId,
      occurredAt: occurredAt ?? this.occurredAt,
      content: content ?? this.content,
      inputSource: inputSource ?? this.inputSource,
      legacyTitle: clearLegacyTitle ? null : legacyTitle ?? this.legacyTitle,
      rawSttText: clearRawSttText ? null : rawSttText ?? this.rawSttText,
      createdByAuthorProfileId:
          createdByAuthorProfileId ?? this.createdByAuthorProfileId,
      createdByDeviceProfileId:
          createdByDeviceProfileId ?? this.createdByDeviceProfileId,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  /// Summary representation for timeline and details view.
  String buildDetails(AppLocalizations loc) {
    return content.trim();
  }

  Map<String, Object?> toJson() => {
    'schema': schema,
    'version': version,
    if (recordId != null) 'recordId': recordId,
    if (childId != null) 'childId': childId,
    'occurredAt': occurredAt.toIso8601String(),
    'content': content,
    'inputSource': inputSource,
    if (legacyTitle?.trim().isNotEmpty == true)
      'legacyTitle': legacyTitle!.trim(),
    if (rawSttText?.trim().isNotEmpty == true) 'rawSttText': rawSttText!.trim(),
    if (createdByAuthorProfileId != null)
      'createdByAuthorProfileId': createdByAuthorProfileId,
    if (createdByDeviceProfileId != null)
      'createdByDeviceProfileId': createdByDeviceProfileId,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (lastModified != null) 'lastModified': lastModified!.toIso8601String(),
  };

  String encode() => jsonEncode(toJson());

  static MemoRecord? decode(String value) {
    if (value.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic> ||
          decoded['schema'] != schema ||
          decoded['version'] != version) {
        return null;
      }
      final occurredAtStr = decoded['occurredAt'] as String?;
      final occurredAt = occurredAtStr != null
          ? DateTime.tryParse(occurredAtStr)
          : null;
      if (occurredAt == null) return null;

      final content = decoded['content'] as String? ?? '';
      final inputSource = decoded['inputSource'] as String? ?? 'typed';
      final legacyTitle = decoded['legacyTitle'] as String?;
      final rawSttText = decoded['rawSttText'] as String?;
      final recordId = decoded['recordId'] as String?;
      final childId = decoded['childId'] as String?;
      final createdByAuthorProfileId =
          decoded['createdByAuthorProfileId'] as String?;
      final createdByDeviceProfileId =
          decoded['createdByDeviceProfileId'] as String?;
      final createdAtStr = decoded['createdAt'] as String?;
      final createdAt = createdAtStr != null
          ? DateTime.tryParse(createdAtStr)
          : null;
      final lastModifiedStr = decoded['lastModified'] as String?;
      final lastModified = lastModifiedStr != null
          ? DateTime.tryParse(lastModifiedStr)
          : null;

      return MemoRecord(
        recordId: recordId,
        childId: childId,
        occurredAt: occurredAt,
        content: content,
        inputSource: inputSource,
        legacyTitle: legacyTitle,
        rawSttText: rawSttText,
        createdByAuthorProfileId: createdByAuthorProfileId,
        createdByDeviceProfileId: createdByDeviceProfileId,
        createdAt: createdAt,
        lastModified: lastModified,
      );
    } catch (_) {
      return null;
    }
  }
}
