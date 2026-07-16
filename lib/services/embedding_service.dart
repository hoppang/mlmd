import 'dart:io';
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

  BgeEmbedder? _embedder;

  /// 임베딩 모델 및 토크나이저 파일을 로컬 영구 디렉터리로 복사하고 초기화합니다.
  Future<void> init() async {
    if (_embedder != null) return;

    // flutter_embedder FFI 런타임 초기화
    if (Platform.isWindows) {
      await initFlutterEmbedder(path: 'onnxruntime.dll');
    } else {
      await initFlutterEmbedder();
    }

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

    // 3. FFI를 통한 BgeEmbedder 인스턴스 로드
    _embedder = BgeEmbedder.create(
      modelPath: modelFile.path,
      tokenizerPath: tokenizerFile.path,
    );
    logger.i('EmbeddingService successfully initialized.');
  }

  /// 일반 텍스트(문서/본문) 임베딩 벡터 추출 (E5 모델 기준 "passage: " 접두사 자동 추가)
  List<double>? getEmbedding(String text) {
    if (_embedder == null) {
      throw StateError('EmbeddingService가 초기화되지 않았습니다. init()을 먼저 호출해 주세요.');
    }

    // E5 임베딩 모델 특성상 본문에는 'passage: ' 접두사 필수 사용
    final formattedText = 'passage: $text';
    final result = _embedder!.embed(texts: [formattedText]);
    if (result.isEmpty) return null;

    return result.first.toList();
  }

  /// 검색어 쿼리용 임베딩 벡터 추출 (E5 모델 기준 "query: " 접두사 자동 추가)
  List<double>? getQueryEmbedding(String query) {
    if (_embedder == null) {
      throw StateError('EmbeddingService가 초기화되지 않았습니다. init()을 먼저 호출해 주세요.');
    }

    // E5 임베딩 모델 특성상 검색 쿼리에는 'query: ' 접두사 필수 사용
    final formattedText = 'query: $query';
    final result = _embedder!.embed(texts: [formattedText]);
    if (result.isEmpty) return null;

    return result.first.toList();
  }
}
