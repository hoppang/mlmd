import 'package:objectbox/objectbox.dart';

/// 두 원본 활동 사이의 중복 후보와 사용자 결정을 보존합니다.
@Entity()
class DuplicateReviewEdgeEntity {
  static const statusPending = 'pending';
  static const statusSameEvent = 'sameEvent';
  static const statusDistinctEvents = 'distinctEvents';

  @Id()
  int id;

  /// 정렬한 두 활동 UUID를 결합한 결정적 키입니다.
  @Index()
  String pairKey;

  String recordAId;
  String recordBId;
  String status;
  String signatureA;
  String signatureB;
  int revisionA;
  int revisionB;
  String detectionReasonsJson;

  @Property(type: PropertyType.date)
  DateTime detectedAt;

  String detectorVersion;
  String? representativeRecordId;
  String? logicalGroupId;

  @Property(type: PropertyType.date)
  DateTime? deferredAt;

  String? resolvedByAuthorProfileId;
  String? resolvedByDeviceProfileId;

  @Property(type: PropertyType.date)
  DateTime? resolvedAt;

  DuplicateReviewEdgeEntity({
    this.id = 0,
    required this.pairKey,
    required this.recordAId,
    required this.recordBId,
    this.status = statusPending,
    required this.signatureA,
    required this.signatureB,
    required this.revisionA,
    required this.revisionB,
    required this.detectionReasonsJson,
    required this.detectedAt,
    required this.detectorVersion,
    this.representativeRecordId,
    this.logicalGroupId,
    this.deferredAt,
    this.resolvedByAuthorProfileId,
    this.resolvedByDeviceProfileId,
    this.resolvedAt,
  });
}
