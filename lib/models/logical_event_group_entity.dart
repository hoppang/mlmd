import 'package:objectbox/objectbox.dart';

/// 같은 사건으로 확인된 원본들의 논리 표시 단위입니다.
///
/// 원본 활동은 수정하거나 삭제하지 않습니다.
@Entity()
class LogicalEventGroupEntity {
  @Id()
  int id;

  @Index()
  String groupId;

  String memberRecordIdsJson;
  String representativeRecordId;
  String memberRevisionsJson;
  String resolvedByAuthorProfileId;
  String resolvedByDeviceProfileId;

  @Property(type: PropertyType.date)
  DateTime resolvedAt;

  LogicalEventGroupEntity({
    this.id = 0,
    required this.groupId,
    required this.memberRecordIdsJson,
    required this.representativeRecordId,
    required this.memberRevisionsJson,
    required this.resolvedByAuthorProfileId,
    required this.resolvedByDeviceProfileId,
    required this.resolvedAt,
  });
}
