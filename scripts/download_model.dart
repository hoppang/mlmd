import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:mlmd/utils/logger.dart';

const _repository = 'Xenova/multilingual-e5-small';

Future<void> main(List<String> arguments) async {
  final options = _parseOptions(arguments);
  final revision = _required(options, 'revision');
  if (!RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(revision)) {
    throw const FormatException(
      '--revision must be a full 40-character commit SHA.',
    );
  }

  final targetDirectory = Directory(options['target-dir'] ?? 'assets/models');
  await targetDirectory.create(recursive: true);
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  try {
    await downloadVerifiedFile(
      client: client,
      uri: Uri.https(
        'huggingface.co',
        '/$_repository/resolve/$revision/tokenizer.json',
      ),
      target: File(
        '${targetDirectory.path}${Platform.pathSeparator}tokenizer.json',
      ),
      expectedSha256: _requiredHash(options, 'tokenizer-sha256'),
      expectedSize: _requiredSize(options, 'tokenizer-size'),
    );
    await downloadVerifiedFile(
      client: client,
      uri: Uri.https(
        'huggingface.co',
        '/$_repository/resolve/$revision/onnx/model_quantized.onnx',
      ),
      target: File(
        '${targetDirectory.path}${Platform.pathSeparator}model_quantized.onnx',
      ),
      expectedSha256: _requiredHash(options, 'model-sha256'),
      expectedSize: _requiredSize(options, 'model-size'),
    );
  } finally {
    client.close(force: true);
  }
  logger.i('All model assets were downloaded and verified.');
}

Future<void> downloadVerifiedFile({
  required HttpClient client,
  required Uri uri,
  required File target,
  required String expectedSha256,
  required int expectedSize,
}) async {
  if (await target.exists()) {
    final currentSize = await target.length();
    if (currentSize == expectedSize &&
        await _sha256(target) == expectedSha256) {
      logger.i('${target.path} is already verified.');
      return;
    }
  }

  final temporary = File('${target.path}.part');
  if (await temporary.exists()) await temporary.delete();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Download failed with HTTP ${response.statusCode}.',
        uri: uri,
      );
    }
    if (response.contentLength > expectedSize) {
      throw const FormatException('Remote file exceeds the expected size.');
    }

    final sink = temporary.openWrite();
    var received = 0;
    try {
      await for (final chunk in response) {
        received += chunk.length;
        if (received > expectedSize) {
          throw const FormatException(
            'Downloaded file exceeds the expected size.',
          );
        }
        sink.add(chunk);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (received != expectedSize) {
      throw FormatException(
        'Downloaded size $received does not match expected size $expectedSize.',
      );
    }
    if (await _sha256(temporary) != expectedSha256) {
      throw const FormatException(
        'Downloaded file failed SHA-256 verification.',
      );
    }

    // Only a fully downloaded and verified temporary file may replace the
    // destination. The old asset remains intact until this point.
    await temporary.rename(target.path);
    logger.i('Downloaded and verified ${target.path}.');
  } catch (_) {
    if (await temporary.exists()) await temporary.delete();
    rethrow;
  }
}

Future<String> _sha256(File file) async =>
    (await crypto.sha256.bind(file.openRead()).first).toString();

Map<String, String> _parseOptions(List<String> arguments) {
  final result = <String, String>{};
  for (final argument in arguments) {
    if (!argument.startsWith('--') || !argument.contains('=')) {
      throw FormatException('Expected --name=value, received: $argument');
    }
    final separator = argument.indexOf('=');
    result[argument.substring(2, separator)] = argument.substring(
      separator + 1,
    );
  }
  return result;
}

String _required(Map<String, String> options, String name) {
  final value = options[name];
  if (value == null || value.isEmpty) {
    throw FormatException('Missing required option --$name=value.');
  }
  return value;
}

String _requiredHash(Map<String, String> options, String name) {
  final value = _required(options, name).toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw FormatException('--$name must be a 64-character SHA-256 digest.');
  }
  return value;
}

int _requiredSize(Map<String, String> options, String name) {
  final value = int.tryParse(_required(options, name));
  if (value == null || value <= 0 || value > 1024 * 1024 * 1024) {
    throw FormatException('--$name must be between 1 byte and 1 GiB.');
  }
  return value;
}
