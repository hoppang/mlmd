import 'dart:io';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';

import '../utils/logger.dart';

Future<void> registerLocalModelIfNeeded() async {
  await FlutterGemma.initialize(inferenceEngines: [LiteRtLmEngine()]);
  if (FlutterGemma.hasActiveModel()) {
    logger.i('[LLM] 기존 활성 모델을 사용합니다.');
    return;
  }

  final candidatePaths = <String>[
    if (Platform.isWindows)
      '${Platform.environment['USERPROFILE']}\\Downloads\\gemma4-e2b-it.litertlm',
    if (Platform.isAndroid) '/sdcard/Download/gemma4-e2b-it.litertlm',
    if (Platform.isMacOS)
      '${Platform.environment['HOME']}/Downloads/gemma4-e2b-it.litertlm',
  ];

  String? foundPath;
  for (final path in candidatePaths) {
    if (await File(path).exists()) {
      foundPath = path;
      break;
    }
  }

  if (foundPath == null) {
    logger.w('[LLM] 모델 파일을 찾을 수 없습니다. 제목 자동 생성이 비활성화됩니다.');
    logger.i('[LLM] 다음 위치에 파일을 놓아주세요: ${candidatePaths.join(", ")}');
    return;
  }

  logger.i('[LLM] 모델 파일 발견: $foundPath — 등록 중...');
  try {
    await FlutterGemma.installModel(
      modelType: ModelType.gemma4,
      fileType: ModelFileType.litertlm,
    ).fromFile(foundPath).install();
    logger.i('[LLM] 모델 등록 완료.');
  } catch (error) {
    logger.e('[LLM] 모델 등록 실패: $error');
  }
}
