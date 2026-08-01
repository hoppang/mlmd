import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';

import '../utils/logger.dart';

/// Initializes local inference and optionally installs a model explicitly
/// trusted by both its path and SHA-256 digest.
///
/// Production startup does not scan Downloads or other shared directories.
/// A developer may opt in with [trustedModelPath] and [expectedSha256], or the
/// corresponding `MLMD_LOCAL_MODEL_PATH` and `MLMD_LOCAL_MODEL_SHA256`
/// environment variables on desktop builds.
Future<void> registerLocalModelIfNeeded({
  String? trustedModelPath,
  String? expectedSha256,
}) async {
  await FlutterGemma.initialize(inferenceEngines: [LiteRtLmEngine()]);
  if (FlutterGemma.hasActiveModel()) {
    logger.i('[LLM] An active local model is already registered.');
    return;
  }

  final path =
      trustedModelPath ?? Platform.environment['MLMD_LOCAL_MODEL_PATH'];
  final expected =
      (expectedSha256 ?? Platform.environment['MLMD_LOCAL_MODEL_SHA256'])
          ?.trim()
          .toLowerCase();
  if (path == null || path.trim().isEmpty || expected == null) {
    logger.i(
      '[LLM] No explicitly trusted local model was configured; '
      'local generation remains disabled.',
    );
    return;
  }
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(expected)) {
    logger.e('[LLM] The configured local model SHA-256 is invalid.');
    return;
  }

  final file = File(path);
  try {
    if (!await file.exists()) {
      logger.w('[LLM] The configured local model file does not exist.');
      return;
    }
    final actual = (await crypto.sha256.bind(file.openRead()).first).toString();
    if (actual != expected) {
      logger.e('[LLM] Local model integrity verification failed.');
      return;
    }
    await FlutterGemma.installModel(
      modelType: ModelType.gemma4,
      fileType: ModelFileType.litertlm,
    ).fromFile(file.path).install();
    logger.i('[LLM] Verified local model registration completed.');
  } catch (error) {
    logger.e('[LLM] Local model registration failed: $error');
  }
}
