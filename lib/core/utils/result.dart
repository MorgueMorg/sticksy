import '../errors/app_exception.dart';

class Result<T> {
  const Result._({this.data, this.error});

  final T? data;
  final AppException? error;

  bool get isSuccess => data != null && error == null;

  static Result<T> success<T>(T data) => Result<T>._(data: data);

  static Result<T> failure<T>(String message) =>
      Result<T>._(error: AppException(message));
}
