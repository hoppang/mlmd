import 'package:objectbox/objectbox.dart';

@Entity()
class DeviceProfileEntity {
  @Id()
  int id;

  @Index()
  String deviceProfileId;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  /// 현재 앱 설치를 가리키는 로컬 상태다. 가져온 기기 프로필은 현재 기기가
  /// 되지 않으며 재설치한 앱은 항상 새로운 UUID를 만든다.
  bool isCurrent;

  /// 작성자 태그는 실제 공유 이력이 생긴 뒤에만 노출하기 위한 로컬 상태다.
  bool hasSharedHistory;

  DeviceProfileEntity({
    this.id = 0,
    required this.deviceProfileId,
    required this.createdAt,
    this.isCurrent = false,
    this.hasSharedHistory = false,
  });
}
