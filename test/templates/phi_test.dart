import 'dart:io';
import 'package:test/test.dart';
import 'package:dinja/dinja.dart';

void main() {
  group('Phi Template Tests', () {
    test('Renders Phi-4 with simple formatting', () {
      final templateName = 'Phi-4-mini-instruct-reasoning.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);

      final data = {
        'messages': [
          {'role': 'system', 'content': 'Sys', 'tools': 'ToolJSON'},
          {'role': 'user', 'content': 'User'},
        ],
        'add_generation_prompt': true,
      };

      final output = template.render(data);
      expect(output, contains('<|system|>Sys<|tool|>ToolJSON<|/tool|><|end|>'));
      expect(output, contains('<|user|>User<|end|>'));
      expect(output, contains('<|assistant|>'));
    });
  });
}
