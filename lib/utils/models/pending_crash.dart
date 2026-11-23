/// An uncaught error saved until the user is offered to report it on next launch.
class PendingCrash {
  const PendingCrash({required this.error, required this.stackTrace});

  final String error;
  final String stackTrace;

  Map<String, dynamic> toJson() => {'error': error, 'stackTrace': stackTrace};

  factory PendingCrash.fromJson(Map<String, dynamic> json) => PendingCrash(
    error: json['error'] as String? ?? '',
    stackTrace: json['stackTrace'] as String? ?? '',
  );
}
