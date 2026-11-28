class InvidiousServiceError extends Error {
  String message;

  InvidiousServiceError(this.message);

  @override
  String toString() => 'InvidiousServiceError: $message';
}
