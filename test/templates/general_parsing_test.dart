import 'dart:io';
import 'package:test/test.dart';
import 'package:dinja/dinja.dart';

void main() {
  group('Template Compatibility - General Parsing', () {
    final fixturesDir = Directory('test/fixtures/templates');

    if (!fixturesDir.existsSync()) {
      print('Warning: Fixtures directory not found at ${fixturesDir.path}');
      return;
    }

    final files = fixturesDir.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.jinja'),
    );

    for (final file in files) {
      test('Parses ${file.uri.pathSegments.last}', () {
        final content = file.readAsStringSync();
        try {
          final template = Template(content);
          expect(template, isNotNull);
        } catch (e) {
          fail('Failed to parse ${file.path}: $e');
        }
      });
    }
  });
}
