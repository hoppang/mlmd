class ActiveDraftRegistry {
  ActiveDraftRegistry._();

  static final instance = ActiveDraftRegistry._();

  final Set<bool Function()> _flushCallbacks = {};

  void register(bool Function() flush) {
    _flushCallbacks.add(flush);
  }

  void unregister(bool Function() flush) {
    _flushCallbacks.remove(flush);
  }

  bool flushAll() {
    var succeeded = true;
    for (final flush in _flushCallbacks.toList(growable: false)) {
      if (!flush()) succeeded = false;
    }
    return succeeded;
  }
}
