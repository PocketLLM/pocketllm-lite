import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/utils/url_validator.dart';

void main() {
  group('UrlValidator', () {
    test('allows http and https', () {
      expect(UrlValidator.isSecureUrlString('https://google.com'), isTrue);
      expect(UrlValidator.isSecureUrlString('http://example.com'), isTrue);
    });

    test('allows mailto', () {
      expect(UrlValidator.isSecureUrlString('mailto:user@example.com'), isTrue);
    });

    test('blocks javascript scheme', () {
      expect(UrlValidator.isSecureUrlString('javascript:alert(1)'), isFalse);
    });

    test('blocks file scheme', () {
      expect(UrlValidator.isSecureUrlString('file:///etc/passwd'), isFalse);
    });

    test('blocks unknown schemes', () {
      expect(UrlValidator.isSecureUrlString('custom:action'), isFalse);
    });

    test('handles invalid uris', () {
      expect(UrlValidator.isSecureUrlString('::not a uri::'), isFalse);
      expect(UrlValidator.isSecureUrlString(null), isFalse);
    });

    test('handles mixed case schemes', () {
      expect(UrlValidator.isSecureUrlString('HTTPS://GOOGLE.COM'), isTrue);
      expect(UrlValidator.isSecureUrlString('JavaScript:alert(1)'), isFalse);
    });
  });
}
