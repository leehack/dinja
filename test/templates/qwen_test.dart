import 'dart:io';
import 'package:test/test.dart';
import 'package:dinja/dinja.dart';

void main() {
  group('Qwen Template Tests', () {
    test('Renders Qwen3 with namespace, tools, lstrip', () {
      final templateName = 'Qwen3-4B.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);

      final data = {
        'tools': [
          {'name': 'my_tool', 'description': 'desc', 'parameters': {}},
        ],
        'messages': [
          {'role': 'system', 'content': 'System instruction'},
          {'role': 'user', 'content': 'Help me'},
        ],
        'add_generation_prompt': true,
      };

      final output = template.render(data);
      expect(output, contains('<|im_start|>system'));
      expect(output, contains('System instruction'));
      expect(output, contains('<tools>'));
      expect(output, contains('my_tool'));
      expect(output, contains('<|im_start|>user'));
      expect(output, contains('Help me'));
      expect(output, contains('<|im_start|>assistant'));
    });

    test('Renders Qwen 2.5 and 3 variants', () {
      // Qwen-Qwen2.5-7B-Instruct.jinja
      // Qwen-Qwen3-0.6B.jinja
      // Qwen-QwQ-32B.jinja
      // Qwen3-Coder.jinja
      // All follow standard Qwen ChatML format

      final variants = [
        'Qwen-Qwen2.5-7B-Instruct.jinja',
        'Qwen-Qwen3-0.6B.jinja',
        'Qwen-QwQ-32B.jinja',
        'Qwen3-Coder.jinja',
      ];

      for (final templateName in variants) {
        final source = File(
          'test/fixtures/templates/$templateName',
        ).readAsStringSync();
        final template = Template(source);

        final data = {
          'messages': [
            {'role': 'system', 'content': 'Sys'},
            {'role': 'user', 'content': 'User'},
          ],
          'add_generation_prompt': true,
        };

        final output = template.render(data);
        expect(output, contains('<|im_start|>assistant\n'));
      }
    });

    test('Renders Qwen 2.5 with tool calls', () {
      final templateName = 'Qwen-Qwen2.5-7B-Instruct.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);

      final tools = [
        {
          'type': 'function',
          'function': {
            'name': 'my_tool',
            'description': 'desc',
            'parameters': {},
          },
        },
      ];

      final data = {
        'tools': tools,
        'messages': [
          {'role': 'user', 'content': 'Call tool'},
          {
            'role': 'assistant',
            'tool_calls': [
              {
                'type': 'function',
                'function': {
                  'name': 'my_tool',
                  'arguments': {'a': 1},
                },
              },
            ],
          },
          {'role': 'tool', 'content': 'Tool result'},
        ],
      };

      final output = template.render(data);
      // Check system prompt injection of tools
      expect(output, contains('<tools>'));
      expect(output, contains('my_tool'));

      // Check assistant tool call
      expect(output, contains('<|im_start|>assistant'));
      expect(output, contains('<tool_call>'));
      expect(output, contains('"name": "my_tool"'));
      expect(output, contains('"arguments": {"a":1}'));
      expect(output, contains('</tool_call>'));

      // Check tool response (wrapped in user role)
      expect(output, contains('<|im_start|>user'));
      expect(output, contains('<tool_response>'));
      expect(output, contains('Tool result'));
      expect(output, contains('</tool_response>'));
    });
  });
}
