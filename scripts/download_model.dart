import 'dart:io';

void main() async {
  final targetDir = Directory('assets/models');
  if (!await targetDir.exists()) {
    await targetDir.create(recursive: true);
    print('Created directory assets/models');
  }

  final client = HttpClient();

  // Xenova/multilingual-e5-small 모델 (384차원 다국어 임베딩 모델)
  final tokenizerUrl = 'https://huggingface.co/Xenova/multilingual-e5-small/resolve/main/tokenizer.json';
  final modelUrl = 'https://huggingface.co/Xenova/multilingual-e5-small/resolve/main/onnx/model_quantized.onnx';

  await downloadFile(client, tokenizerUrl, File('assets/models/tokenizer.json'));
  await downloadFile(client, modelUrl, File('assets/models/model_quantized.onnx'));

  client.close();
  print('All downloads finished.');
}

Future<void> downloadFile(HttpClient client, String url, File file) async {
  if (await file.exists() && await file.length() > 0) {
    print('${file.path} already exists. Skipping download.');
    return;
  }

  print('Downloading $url to ${file.path}...');
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();

    if (response.statusCode == 200) {
      final sink = file.openWrite();
      await response.pipe(sink);
      print('Downloaded ${file.path} successfully.');
    } else {
      print('Failed to download $url. Status code: ${response.statusCode}');
      if (await file.exists()) {
        await file.delete();
      }
    }
  } catch (e) {
    print('Error downloading ${file.path}: $e');
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }
}
