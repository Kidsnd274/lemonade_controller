class LemonadeApiException implements Exception {
  final int? statusCode;
  final String? code;
  final String message;

  const LemonadeApiException(this.message, {this.statusCode, this.code});

  bool get isUnsupported => statusCode == 404 || statusCode == 405;
  bool get isAuthenticationError => statusCode == 401 || statusCode == 403;
  bool get isPinnedSlotsError =>
      statusCode == 409 && code == 'slots_pinned_error';

  @override
  String toString() => message;
}
