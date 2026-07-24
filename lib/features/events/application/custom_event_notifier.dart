import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/shared_custom_event_definition_entity.dart';
import '../../../repositories/custom_event_repository.dart';

class CustomEventCatalogState {
  const CustomEventCatalogState({
    this.definitions = const [],
    this.pinnedTypeIds = const [],
  });

  final List<SharedCustomEventDefinitionEntity> definitions;
  final List<String> pinnedTypeIds;

  bool isPinned(String customEventTypeId) =>
      pinnedTypeIds.contains(customEventTypeId);

  List<SharedCustomEventDefinitionEntity> get pinnedDefinitions {
    final byId = {
      for (final definition in definitions)
        definition.customEventTypeId: definition,
    };
    return [
      for (final id in pinnedTypeIds)
        if (byId[id] case final SharedCustomEventDefinitionEntity definition)
          definition,
    ];
  }
}

class CustomEventCatalogNotifier extends Notifier<CustomEventCatalogState> {
  @override
  CustomEventCatalogState build() {
    ref.watch(customEventRepositoryProvider);
    return _load();
  }

  SharedCustomEventDefinitionEntity create(String name) {
    final result = ref.read(customEventRepositoryProvider).create(name);
    state = _load();
    return result;
  }

  void rename(String customEventTypeId, String name) {
    ref.read(customEventRepositoryProvider).rename(customEventTypeId, name);
    state = _load();
  }

  void archive(String customEventTypeId) {
    ref
        .read(customEventRepositoryProvider)
        .setArchived(customEventTypeId, archived: true);
    state = _load();
  }

  void setPinned(String customEventTypeId, {required bool pinned}) {
    ref
        .read(customEventRepositoryProvider)
        .setPinned(customEventTypeId, pinned: pinned);
    state = _load();
  }

  void reload() => state = _load();

  CustomEventCatalogState _load() {
    final repository = ref.read(customEventRepositoryProvider);
    return CustomEventCatalogState(
      definitions: repository.getDefinitions(),
      pinnedTypeIds: repository.getPinnedTypeIds(),
    );
  }
}

final customEventCatalogProvider =
    NotifierProvider<CustomEventCatalogNotifier, CustomEventCatalogState>(
      CustomEventCatalogNotifier.new,
      dependencies: [customEventRepositoryProvider],
    );
