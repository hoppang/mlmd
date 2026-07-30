import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef TopUndoCallback = FutureOr<void> Function();

class TopUndoAction {
  const TopUndoAction({required this.id, required this.callback});

  final int id;
  final TopUndoCallback callback;
}

class TopUndoNotifier extends Notifier<TopUndoAction?> {
  int _nextId = 0;

  @override
  TopUndoAction? build() => null;

  void arm(TopUndoCallback callback) {
    state = TopUndoAction(id: _nextId++, callback: callback);
  }

  void clear() {
    state = null;
  }

  Future<void> execute() async {
    final action = state;
    if (action == null) return;
    state = null;
    await Future.sync(action.callback);
  }
}

final topUndoProvider = NotifierProvider<TopUndoNotifier, TopUndoAction?>(
  TopUndoNotifier.new,
);
