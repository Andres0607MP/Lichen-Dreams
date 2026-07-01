String getDefaultBaseUrl() {
  final host = Uri.base.host;
  if (host.isNotEmpty) {
    return '${Uri.base.scheme}://$host:8000';
  }
  return 'http://localhost:8000';
}
