import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/features/chat/models/link_preview.dart';

void main() {
  group('LinkPreview', () {
    group('fromJson', () {
      test('parses all fields', () {
        final json = {
          'url': 'https://example.com',
          'title': 'Example Title',
          'description': 'Example description',
          'image': 'https://example.com/img.jpg',
          'siteName': 'Example',
        };
        final preview = LinkPreview.fromJson(json);
        expect(preview.url, 'https://example.com');
        expect(preview.title, 'Example Title');
        expect(preview.description, 'Example description');
        expect(preview.image, 'https://example.com/img.jpg');
        expect(preview.siteName, 'Example');
      });

      test('handles null optional fields', () {
        final json = {
          'url': 'https://example.com',
          'title': null,
          'description': null,
          'image': null,
          'siteName': null,
        };
        final preview = LinkPreview.fromJson(json);
        expect(preview.url, 'https://example.com');
        expect(preview.title, isNull);
        expect(preview.description, isNull);
        expect(preview.image, isNull);
        expect(preview.siteName, isNull);
      });

      test('handles missing optional fields', () {
        final json = {'url': 'https://example.com'};
        final preview = LinkPreview.fromJson(json);
        expect(preview.url, 'https://example.com');
        expect(preview.title, isNull);
        expect(preview.description, isNull);
        expect(preview.image, isNull);
        expect(preview.siteName, isNull);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        const preview = LinkPreview(
          url: 'https://example.com',
          title: 'Title',
          description: 'Desc',
          image: 'https://example.com/img.jpg',
          siteName: 'Example',
        );
        final json = preview.toJson();
        expect(json['url'], 'https://example.com');
        expect(json['title'], 'Title');
        expect(json['description'], 'Desc');
        expect(json['image'], 'https://example.com/img.jpg');
        expect(json['siteName'], 'Example');
      });

      test('omits null fields', () {
        const preview = LinkPreview(url: 'https://example.com');
        final json = preview.toJson();
        expect(json['url'], 'https://example.com');
        expect(json.containsKey('title'), isFalse);
        expect(json.containsKey('description'), isFalse);
        expect(json.containsKey('image'), isFalse);
        expect(json.containsKey('siteName'), isFalse);
      });
    });

    group('roundtrip', () {
      test('fromJson(toJson()) preserves data', () {
        const original = LinkPreview(
          url: 'https://example.com',
          title: 'Title',
          description: 'Desc',
          image: 'https://example.com/img.jpg',
          siteName: 'Example',
        );
        final restored = LinkPreview.fromJson(original.toJson());
        expect(restored.url, original.url);
        expect(restored.title, original.title);
        expect(restored.description, original.description);
        expect(restored.image, original.image);
        expect(restored.siteName, original.siteName);
      });
    });
  });

  group('URL detection regex', () {
    final urlRegex = RegExp(r'https?://[^\s]+');

    test('detects https URL', () {
      final match = urlRegex.firstMatch('Check https://example.com');
      expect(match?.group(0), 'https://example.com');
    });

    test('detects http URL', () {
      final match = urlRegex.firstMatch('Visit http://example.com');
      expect(match?.group(0), 'http://example.com');
    });

    test('detects URL with path and query', () {
      final match = urlRegex.firstMatch('See https://example.com/path?q=1&b=2');
      expect(match?.group(0), 'https://example.com/path?q=1&b=2');
    });

    test('extracts first URL from multi-URL text', () {
      final match = urlRegex.firstMatch('https://a.com and https://b.com');
      expect(match?.group(0), 'https://a.com');
    });

    test('returns null for no URL', () {
      final match = urlRegex.firstMatch('No URL here');
      expect(match, isNull);
    });

    test('returns null for ftp URL', () {
      final match = urlRegex.firstMatch('ftp://example.com');
      expect(match, isNull);
    });

    test('returns null for bare domain', () {
      final match = urlRegex.firstMatch('example.com');
      expect(match, isNull);
    });

    test('detects URL at beginning of text', () {
      final match = urlRegex.firstMatch('https://example.com is great');
      expect(match?.group(0), 'https://example.com');
    });

    test('detects URL at end of text', () {
      final match = urlRegex.firstMatch('Visit https://example.com');
      expect(match?.group(0), 'https://example.com');
    });

    test('detects URL in middle of text', () {
      final match = urlRegex.firstMatch('Go to https://example.com now');
      expect(match?.group(0), 'https://example.com');
    });
  });
}

