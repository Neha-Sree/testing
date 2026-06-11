import 'mom_api_host.dart';

/// Shared API base URL for REST, WebSocket, and uploaded media.
/// Override with `--dart-define=MOM_API_BASE_URL=http://host:port`.
String momApiBaseUrl() {
  const fromEnv = String.fromEnvironment('MOM_API_BASE_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  return 'http://${momApiDefaultLoopbackHost()}:8000';
}

/// Build a fetchable URL for a file stored under backend `/uploads/`.
String momUploadUrl(String relativePath) {
  final clean = relativePath.replaceFirst(RegExp(r'^/+'), '');
  return '${momApiBaseUrl()}/uploads/$clean';
}
