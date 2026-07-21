import 'dart:async';

import '../../../models/record_draft_entity.dart';
import '../../../repositories/record_draft_repository.dart';

enum DraftSaveStatus { idle, saving, saved, failed }

class DraftAutosaveController {
  DraftAutosaveController({
    required this.repository,
    required this.draftId,
    required this.draftKind,
    required this.recordType,
    required this.capturePayload,
    required this.hasMeaningfulChanges,
    required this.onStatusChanged,
    required this.onDraftListChanged,
    this.targetRecordId,
    this.baseLastModified,
    this.payloadSchemaVersion = 1,
    RecordDraftEntity? existingDraft,
    this.debounceDuration = const Duration(milliseconds: 500),
  }) : _createdAt = existingDraft?.createdAt ?? DateTime.now(),
       _hasPersistedDraft = existingDraft != null;

  final RecordDraftRepository repository;
  final String draftId;
  final String draftKind;
  final String recordType;
  final String? targetRecordId;
  final DateTime? baseLastModified;
  final int payloadSchemaVersion;
  final String Function() capturePayload;
  final bool Function() hasMeaningfulChanges;
  final void Function(DraftSaveStatus status) onStatusChanged;
  final void Function() onDraftListChanged;
  final Duration debounceDuration;

  final DateTime _createdAt;
  Timer? _timer;
  bool _hasPersistedDraft;
  bool _finished = false;

  void schedule() {
    if (_finished) return;
    _timer?.cancel();
    _timer = Timer(debounceDuration, () => flush());
  }

  bool flush() {
    if (_finished) return true;
    _timer?.cancel();
    _timer = null;

    if (!hasMeaningfulChanges()) {
      if (_hasPersistedDraft) {
        repository.deleteDraft(draftId);
        _hasPersistedDraft = false;
        onDraftListChanged();
      }
      onStatusChanged(DraftSaveStatus.idle);
      return true;
    }

    onStatusChanged(DraftSaveStatus.saving);
    try {
      final now = DateTime.now();
      repository.saveDraft(
        RecordDraftEntity(
          draftId: draftId,
          draftKind: draftKind,
          recordType: recordType,
          targetRecordId: targetRecordId,
          payloadSchemaVersion: payloadSchemaVersion,
          fieldPayloadJson: capturePayload(),
          baseLastModified: baseLastModified,
          createdAt: _createdAt,
          lastSavedAt: now,
        ),
      );
      _hasPersistedDraft = true;
      onStatusChanged(DraftSaveStatus.saved);
      onDraftListChanged();
      return true;
    } catch (_) {
      onStatusChanged(DraftSaveStatus.failed);
      return false;
    }
  }

  void markCommitted() {
    _timer?.cancel();
    _timer = null;
    _hasPersistedDraft = false;
    _finished = true;
    onDraftListChanged();
  }

  void discard() {
    _timer?.cancel();
    _timer = null;
    if (_hasPersistedDraft) repository.deleteDraft(draftId);
    _hasPersistedDraft = false;
    _finished = true;
    onDraftListChanged();
    onStatusChanged(DraftSaveStatus.idle);
  }

  void dispose() {
    if (!_finished) flush();
    _timer?.cancel();
  }
}
