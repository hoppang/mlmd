# 임베딩 모델 안내 (ML Models)

이 디렉터리에는 온디바이스 텍스트 임베딩을 위한 모델 및 토크나이저 파일이 위치해야 합니다.
대용량 파일들이기 때문에 Git에는 업로드되지 않습니다.

## 파일 설치 방법

프로젝트 루트 폴더에서 아래 Dart 스크립트를 실행하면 필요한 파일들이 이 폴더에 자동으로 다운로드됩니다.

```bash
dart run scripts/download_model.dart
```

### 다운로드되는 파일
1. `tokenizer.json` (다국어 임베딩 토크나이저)
2. `model_quantized.onnx` (Xenova/multilingual-e5-small 양자화 ONNX 임베딩 모델)
