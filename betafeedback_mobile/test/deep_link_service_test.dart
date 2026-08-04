import 'package:flutter_test/flutter_test.dart';

import 'package:betafeedback_mobile/services/deep_link_service.dart';

void main() {
  group('DeepLinkService.parseProjectId', () {
    test('parses https open links', () {
      expect(
        DeepLinkService.parseProjectId(
          Uri.parse('https://betafeedback.com/open/projects/abc-123'),
        ),
        'abc-123',
      );
      expect(
        DeepLinkService.parseProjectId(
          Uri.parse('https://www.betafeedback.com/open/projects/abc-123'),
        ),
        'abc-123',
      );
    });

    test('parses custom scheme links', () {
      expect(
        DeepLinkService.parseProjectId(
          Uri.parse('betafeedback://projects/abc-123'),
        ),
        'abc-123',
      );
      expect(
        DeepLinkService.parseProjectId(
          Uri.parse('betafeedback://open/projects/abc-123'),
        ),
        'abc-123',
      );
      expect(
        DeepLinkService.parseProjectId(
          Uri.parse('betafeedback:///projects/abc-123'),
        ),
        'abc-123',
      );
    });

    test('ignores unrelated urls', () {
      expect(
        DeepLinkService.parseProjectId(Uri.parse('https://betafeedback.com/')),
        isNull,
      );
      expect(
        DeepLinkService.parseProjectId(Uri.parse('https://example.com/open/projects/x')),
        isNull,
      );
    });
  });
}
