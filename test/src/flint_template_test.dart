@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:dinja/dinja.dart';
import 'package:test/test.dart';

void main() {
  final source = File('test/fixtures/flint/Flint.jinja').readAsStringSync();
  final fixture =
      jsonDecode(
            File('test/fixtures/flint/render_upstream.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  for (final entry in (fixture['cases'] as List).cast<Map<String, dynamic>>()) {
    test('exact Flint template matches upstream ${entry['name']}', () {
      final context =
          jsonDecode(jsonEncode(entry['request'])) as Map<String, dynamic>;
      // llama.cpp parses object arguments before passing them to the template.
      for (final message in (context['messages'] as List)) {
        for (final call in (message['tool_calls'] as List? ?? const [])) {
          final function = call['function'] as Map<String, dynamic>;
          function['arguments'] = jsonDecode(function['arguments'] as String);
        }
      }
      final original = jsonEncode(context);
      expect(Template(source).render(context), entry['prompt']);
      expect(jsonEncode(context), original);
    });
  }
}
