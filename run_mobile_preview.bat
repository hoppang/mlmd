@echo off
flutter run -d windows ^
  --dart-define=MOBILE_PREVIEW=true ^
  --dart-define=MOBILE_PREVIEW_WIDTH=412 ^
  --dart-define=MOBILE_PREVIEW_HEIGHT=915
