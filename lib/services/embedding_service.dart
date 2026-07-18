import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_embedder/flutter_embedder.dart';
import '../utils/logger.dart';

/// Riverpod에서 사용할 EmbeddingService 프로바이더.
/// main.dart에서 스토어 초기화와 함께 주입해야 합니다.
final embeddingServiceProvider = Provider<EmbeddingService>((ref) {
  throw UnimplementedError(
    'embeddingServiceProvider가 초기화되지 않았습니다. main.dart에서 재정의해주십시오.',
  );
});

class EmbeddingService {
  static final EmbeddingService _instance = EmbeddingService._internal();
  factory EmbeddingService() => _instance;
  EmbeddingService._internal();

  Isolate? _worker;
  ReceivePort? _responses;
  SendPort? _commands;
  final Map<int, Completer<List<double>?>> _pending = {};
  int _nextRequestId = 0;
  Object? _initializationError;

  bool get isAvailable =>
      _worker != null && _responses != null && _commands != null;
  Object? get initializationError => _initializationError;

  /// 임베딩 모델 및 토크나이저 파일을 로컬 영구 디렉터리로 복사하고 초기화합니다.
  Future<void> init() async {
    if (_commands != null) return;

    try {
      await _initModel();
      _initializationError = null;
    } catch (error, stackTrace) {
      _commands = null;
      _initializationError = error;
      logger.e(
        'EmbeddingService initialization failed; semantic search is disabled.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _initModel() async {
    // 로컬 앱 지원 디렉터리 경로 확보
    final appDir = await getApplicationSupportDirectory();
    final modelFile = File(p.join(appDir.path, 'model_quantized.onnx'));
    final tokenizerFile = File(p.join(appDir.path, 'tokenizer.json'));

    // 1. 모델 파일 복사 (없을 경우)
    if (!await modelFile.exists() || await modelFile.length() == 0) {
      logger.i('Copying model_quantized.onnx to dynamic library space...');
      final data = await rootBundle.load('assets/models/model_quantized.onnx');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await modelFile.writeAsBytes(bytes);
      logger.i('Finished copying model.');
    }

    // 2. 토크나이저 파일 복사 (없을 경우)
    if (!await tokenizerFile.exists() || await tokenizerFile.length() == 0) {
      logger.i('Copying tokenizer.json to dynamic library space...');
      final data = await rootBundle.load('assets/models/tokenizer.json');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await tokenizerFile.writeAsBytes(bytes);
      logger.i('Finished copying tokenizer.');
    }

    // 3. 전용 isolate에서 FFI 런타임과 모델을 한 번만 로드합니다.
    await _startWorker(modelFile.path, tokenizerFile.path);
    logger.i('EmbeddingService successfully initialized.');
  }

  Future<void> _startWorker(String modelPath, String tokenizerPath) async {
    final responses = ReceivePort();
    final ready = Completer<void>();
    _responses = responses;

    responses.listen((message) {
      final values = message as List<Object?>;
      switch (values[0]) {
        case 'ready':
          _commands = values[1] as SendPort;
          if (!ready.isCompleted) ready.complete();
        case 'init-error':
          if (!ready.isCompleted) {
            ready.completeError(StateError(values[1] as String));
          }
        case 'result':
          final id = values[1] as int;
          final completer = _pending.remove(id);
          if (completer == null) return;
          final error = values[3] as String?;
          if (error != null) {
            completer.completeError(StateError(error));
          } else {
            completer.complete((values[2] as List?)?.cast<double>());
          }
      }
    });

    _worker = await Isolate.spawn(_embeddingWorkerMain, <Object?>[
      responses.sendPort,
      modelPath,
      tokenizerPath,
      Platform.isWindows ? 'onnxruntime.dll' : null,
    ], debugName: 'mlmd-embedding-worker');
    await ready.future;
  }

  /// 일반 텍스트(문서/본문) 임베딩 벡터 추출 (E5 모델 기준 "passage: " 접두사 자동 추가)
  Future<List<double>?> getEmbedding(String text) => _embed('passage: $text');

  /// 검색어 쿼리용 임베딩 벡터 추출 (E5 모델 기준 "query: " 접두사 자동 추가)
  Future<List<double>?> getQueryEmbedding(String query) =>
      _embed('query: $query');

  Future<List<double>?> _embed(String formattedText) {
    final commands = _commands;
    if (commands == null) return Future.value(null);

    final id = _nextRequestId++;
    final completer = Completer<List<double>?>();
    _pending[id] = completer;
    commands.send(<Object?>['embed', id, formattedText]);
    return completer.future;
  }
}

Future<void> _embeddingWorkerMain(List<Object?> args) async {
  final responses = args[0] as SendPort;
  final modelPath = args[1] as String;
  final tokenizerPath = args[2] as String;
  final nativeLibraryPath = args[3] as String?;

  try {
    if (nativeLibraryPath != null) {
      await initFlutterEmbedder(path: nativeLibraryPath);
    } else {
      await initFlutterEmbedder();
    }
    final embedder = BgeEmbedder.create(
      modelPath: modelPath,
      tokenizerPath: tokenizerPath,
    );
    final commands = ReceivePort();
    responses.send(<Object?>['ready', commands.sendPort]);

    await for (final message in commands) {
      final values = message as List<Object?>;
      if (values[0] != 'embed') continue;
      final id = values[1] as int;
      final text = values[2] as String;
      try {
        final result = embedder.embed(texts: [text]);
        responses.send(<Object?>[
          'result',
          id,
          result.isEmpty ? null : result.first,
          null,
        ]);
      } catch (error) {
        responses.send(<Object?>['result', id, null, error.toString()]);
      }
    }
  } catch (error) {
    responses.send(<Object?>['init-error', error.toString()]);
  }
}
