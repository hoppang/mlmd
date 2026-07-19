class DiaryTransferException implements Exception {
  final String code;
  final String message;
  final Object? cause;

  const DiaryTransferException(this.code, this.message, [this.cause]);

  @override
  String toString() => 'DiaryTransferException($code): $message';
}
