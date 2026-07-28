import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/features/tracking/domain/tracking_models.dart';
import 'package:mlmd/objectbox.g.dart';
import 'package:mlmd/repositories/tracking_repository.dart';

void main() {
  late Directory directory;
  late Store store;
  late TrackingRepositoryImpl repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('tracking-test-');
    store = await openStore(directory: directory.path);
    repository = TrackingRepositoryImpl.fromStore(store);
  });

  tearDown(() async {
    store.close();
    await directory.delete(recursive: true);
  });

  test('기록 방식 변경 이력을 보존하고 해당 시점의 방식을 조회한다', () {
    repository.setMode(
      childId: 'child-a',
      eventCategory: 'feeding',
      mode: TrackingMode.detailed,
      changedAt: DateTime(2026, 7, 1),
    );
    repository.setMode(
      childId: 'child-a',
      eventCategory: 'feeding',
      mode: TrackingMode.dailyCheckIn,
      changedAt: DateTime(2026, 7, 10),
    );

    expect(
      repository.modeFor('child-a', 'feeding', at: DateTime(2026, 7, 5)),
      TrackingMode.detailed,
    );
    expect(
      repository.modeFor('child-a', 'feeding', at: DateTime(2026, 7, 15)),
      TrackingMode.dailyCheckIn,
    );
  });

  test('일별 완전성 응답은 같은 아이·날짜·항목에서 갱신된다', () {
    final first = repository.saveCoverage(
      childId: 'child-a',
      localDate: DateTime(2026, 7, 20, 23),
      eventCategory: 'feeding',
      coverage: TrackingCoverage.partial,
    );
    final updated = repository.saveCoverage(
      childId: 'child-a',
      localDate: DateTime(2026, 7, 20, 8),
      eventCategory: 'feeding',
      coverage: TrackingCoverage.mostlyComplete,
      relativeState: TrackingRelativeState.less,
      memo: '실제로 덜 먹음',
    );

    expect(updated.id, first.id);
    expect(updated.coverage, TrackingCoverage.mostlyComplete.name);
    expect(updated.relativeState, TrackingRelativeState.less.name);
    expect(updated.memo, '실제로 덜 먹음');
  });
}
