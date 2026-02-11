import 'dart:io';
import 'package:test/test.dart';
import 'package:dinja/dinja.dart';

void main() {
  group('Cohere Template Tests', () {
    test('Renders Cohere Command R+ with tool usage and macros', () {
      final templateName = 'CohereForAI-c4ai-command-r-plus-tool_use.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);

      final data = {
        'bos_token': JinjaString.from('<BOS>', isSafe: true),
        'messages': [
          {'role': 'user', 'content': 'Help me'},
        ],
        'tools': [
          {
            'name': 'my_tool',
            'description': 'desc',
            'parameters': {
              'type': 'object',
              'properties': {
                'arg1': {'type': 'string', 'description': 'arg1 desc'},
              },
              'required': ['arg1'],
            },
          },
        ],
        'add_generation_prompt': true,
      };

      final output = template.render(data);
      expect(output, contains('<BOS>'));
      expect(output, contains('## Available Tools'));
      // new_tool_parser uses json_to_python_type, so "string" -> "str"
      expect(output, contains('def my_tool(arg1: str) -> List[Dict]:'));
      expect(
        output,
        contains(
          '<|START_OF_TURN_TOKEN|><|USER_TOKEN|>Help me<|END_OF_TURN_TOKEN|>',
        ),
      );
      expect(output, contains('<|CHATBOT_TOKEN|>'));
    });

    test('Renders Cohere 7B with tool calls', () {
      final templateName =
          'CohereForAI-c4ai-command-r7b-12-2024-tool_use.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);

      // Define tool
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

      final output = template.render({
        'messages': [
          {'role': 'user', 'content': 'Call tool'},
          {
            'role': 'assistant',
            'tool_calls': [
              {
                'function': {'name': 'my_tool', 'arguments': {}},
              },
            ],
            'tool_plan': 'I will call my_tool',
          },
        ],
        'tools': tools,
      });

      expect(
        output,
        contains('<|START_THINKING|>I will call my_tool<|END_THINKING|>'),
      );
      expect(output, contains('<|START_ACTION|>['));
      expect(output, contains('"tool_name": "my_tool"'));
      expect(output, contains('<|END_ACTION|>'));
    });
  });
}
