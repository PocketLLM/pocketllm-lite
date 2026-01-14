class UrlValidator {
  static const List<String> _allowedSchemes = ['http', 'https', 'mailto'];

  /// Checks if the provided [Uri] has a secure/allowed scheme.
  static bool isSecureUrl(Uri? uri) {
    if (uri == null) return false;
    // scheme is usually lowercase, but good to be sure
    return _allowedSchemes.contains(uri.scheme.toLowerCase());
  }

  /// Checks if the provided URL string is a valid URI and has a secure scheme.
  static bool isSecureUrlString(String? url) {
    if (url == null) return false;
    final uri = Uri.tryParse(url);
    return isSecureUrl(uri);
  }
}
