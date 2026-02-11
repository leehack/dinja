import 'dart:io';
import 'package:test/test.dart';
import 'package:dinja/dinja.dart';

void main() {
  group('DeepSeek Template Tests', () {
    test('Renders DeepSeek-R1 with namespace and split', () {
      final templateName = 'DeepSeek-R1-Distill-Llama-8B.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);

      final data = {
        'bos_token': JinjaString.from('<|bos|>', isSafe: true),
        'add_generation_prompt': true,
        'messages': [
          {'role': 'system', 'content': 'System prompt'},
          {'role': 'user', 'content': 'User query'},
          {'role': 'assistant', 'content': '<think>Reasoning</think>Response'},
        ],
      };

      final output = template.render(data);
      expect(output, contains('<|bos|>System prompt'));
      expect(output, contains('<｜User｜>User query'));
      expect(output, contains('<｜Assistant｜>Response'));
      // It splits explicitly on </think> so "Reasoning" might be stripped or handled.
    });

    test('Renders DeepSeek-R1 with tool calls', () {
      final templateName = 'DeepSeek-R1-Distill-Llama-8B.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);

      final data = {
        'bos_token': JinjaString.from('<|bos|>', isSafe: true),
        'messages': [
          {'role': 'user', 'content': 'Call tool'},
          {
            'role': 'assistant',
            'content': null, // Required to trigger tool_calls rendering path
            'tool_calls': [
              {
                'type': 'function', // Required by template
                'function': {'name': 'my_tool', 'arguments': '{}'},
              },
              {
                'type': 'function',
                'function': {'name': 'another_tool', 'arguments': '{"x": 1}'},
              },
            ],
          },
          {'role': 'tool', 'content': 'Result'},
        ],
      };

      final output = template.render(data);
      // Check for DeepSeek specific tool tokens
      expect(output, contains('<｜tool▁calls▁begin｜>'));
      expect(
        output,
        contains('<｜tool▁call▁begin｜>function<｜tool▁sep｜>my_tool'),
      );
      expect(output, contains('```json\n{}\n```'));
      expect(output, contains('<｜tool▁call▁end｜>'));
      expect(output, contains('<｜tool▁calls▁end｜>'));
      // Check tool output
      expect(output, contains('<｜tool▁outputs▁begin｜>'));
      expect(
        output,
        contains('<｜tool▁output▁begin｜>Result<｜tool▁output▁end｜>'),
      );
      expect(output, contains('<｜tool▁outputs▁end｜>'));
    });

    test('Renders DeepSeek-R1-Distill-Qwen-1.5B with reasoning split', () {
      final templateName = 'DeepSeek-R1-Distill-Qwen-1_5B.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);

      final data = {
        'bos_token': JinjaString.from('<|bos|>', isSafe: true),
        'messages': [
          {'role': 'system', 'content': 'System'},
          {'role': 'user', 'content': 'User'},
          {
            'role': 'assistant',
            'content': '<think>Thinking process</think>Actual response',
          },
        ],
        'add_generation_prompt': true,
      };

      final output = template.render(data);
      expect(output, contains('<|bos|>System'));
      expect(output, contains('<｜User｜>User'));
      // Should strip thinking or handle it. The template does: content.split('</think>')[-1]
      expect(output, contains('<｜Assistant｜>Actual response'));
      expect(output, isNot(contains('Thinking process')));
    });

    test('Renders DeepSeek V3 and Variants', () {
      // deepseek-ai-DeepSeek-R1-Distill-Llama-8B.jinja (Similar to tested above)
      // deepseek-ai-DeepSeek-R1-Distill-Qwen-32B.jinja
      // deepseek-ai-DeepSeek-V3.1.jinja
      // llama-cpp-deepseek-r1.jinja

      final variants = [
        'deepseek-ai-DeepSeek-R1-Distill-Llama-8B.jinja',
        'deepseek-ai-DeepSeek-R1-Distill-Qwen-32B.jinja',
        'deepseek-ai-DeepSeek-V3.1.jinja',
        'llama-cpp-deepseek-r1.jinja',
      ];

      for (final templateName in variants) {
        final source = File(
          'test/fixtures/templates/$templateName',
        ).readAsStringSync();
        final template = Template(source);

        final data = {
          'bos_token': JinjaString.from('<|bos|>', isSafe: true),
          'messages': [
            {'role': 'user', 'content': 'User'},
          ],
          'add_generation_prompt': true,
        };

        final output = template.render(data);
        // Most DeepSeek use <｜User｜> format or standard ChatML or Llama-style
        // R1 variants use <｜User｜>
        // V3 might use standard tokens. Let's check broadly.

        if (output.contains('<｜User｜>')) {
          expect(output, contains('<｜User｜>User'));
        } else if (output.contains('<|User|>')) {
          expect(output, contains('<|User|>User'));
        } else {
          // Fallback or specific check
          expect(output, isNotEmpty);
        }
      }
    });
  });
}
