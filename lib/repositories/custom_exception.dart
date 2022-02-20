class CustomException implements Exception {
  final String? message;

  const CustomException({this.message = 'Something went wrong!'});

  set state(CustomException state) {}

  @override
  String toString() => 'CustomException { message: $message }';
}
