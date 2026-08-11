import '../errors/app_exception.dart';

/// Tiny success/failure wrapper.
///
/// The previous version defined success as `data != null`, so any operation
/// returning null — or `void` — silently reported failure. Success is now an
/// explicit flag.
class Result<T> {
  const Result._({required this.isSuccess, T? data, this.error})
      : _data = data;

  final bool isSuccess;
  final T? _data;
  final AppException? error;

  bool get isFailure => !isSuccess;

  /// Payload of a successful result. Only read this after checking [isSuccess].
  T get value => _data as T;

  /// Nullable accessor for callers that don't want to branch first.
  T? get data => _data;

  String get errorMessage => error?.message ?? 'Something went wrong.';

  static Result<T> success<T>(T data) => Result<T>._(isSuccess: true, data: data);

  static Result<T> failure<T>(String message) =>
      Result<T>._(isSuccess: false, error: AppException(message));

  /// Runs [action] and converts any throw into a failure with [fallback].
  static Future<Result<T>> guard<T>(
    Future<T> Function() action, {
    String? fallback,
  }) async {
    try {
      return Result.success<T>(await action());
    } catch (error) {
      final message = error.toString().trim();
      return Result.failure<T>(
        message.isEmpty ? (fallback ?? 'Something went wrong.') : message,
      );
    }
  }
}
