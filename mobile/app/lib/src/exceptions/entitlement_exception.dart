/// Thrown when the backend returns 403 with error: 'entitlement_required'.
///
/// This is the app-wide version — caught by the Dio interceptor in
/// [BackendService] and re-thrown so screens can show the subscription
/// paywall instead of a raw DioException.
class EntitlementRequiredException implements Exception {
  final String message;
  const EntitlementRequiredException([
    this.message = 'Active subscription required.',
  ]);

  @override
  String toString() => message;
}
