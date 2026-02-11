import 'dart:io';
import 'package:test/test.dart';
import 'package:dinja/dinja.dart';

void main() {
  group('Mistral Template Tests', () {
    test('Renders Ministral-3B with role alternation check', () {
      final templateName = 'Ministral-3-3B-Reasoning.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);

      final data = {
        'bos_token': JinjaString.from('<s>', isSafe: true),
        'eos_token': JinjaString.from('</s>', isSafe: true),
        'messages': [
          {'role': 'system', 'content': 'Sys'},
          {'role': 'user', 'content': 'User'},
          {'role': 'assistant', 'content': 'Asst'},
        ],
      };

      final output = template.render(data);
      expect(output, contains('[SYSTEM_PROMPT]Sys[/SYSTEM_PROMPT]'));
      expect(output, contains('[INST]User[/INST]'));
      expect(output, contains('Asst'));

      // Test role alternation failure
      final badData = {
        'bos_token': JinjaString.from('<s>', isSafe: true),
        'eos_token': JinjaString.from('</s>', isSafe: true),
        'messages': [
          {'role': 'user', 'content': 'A'},
          {'role': 'user', 'content': 'B'},
        ],
      };
      expect(() => template.render(badData), throwsException);
    });

    test('Renders Mistral Nemo with role checks', () {
      final templateName = 'mistralai-Mistral-Nemo-Instruct-2407.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);

      final data = {
        'bos_token': JinjaString.from('<s>', isSafe: true),
        'eos_token': JinjaString.from('</s>', isSafe: true),
        'messages': [
          {'role': 'user', 'content': 'Hello'},
          {'role': 'assistant', 'content': 'Hi'},
          {'role': 'user', 'content': 'Bye'},
        ],
        'tools': [
          {
            'type': 'function',
            'function': {
              'name': 'tool',
              'description': 'desc',
              'parameters': {},
            },
          },
        ],
      };

      final output = template.render(data);
      expect(output, contains('[AVAILABLE_TOOLS]['));
      expect(output, contains('"name": "tool"'));
      expect(output, contains('[/AVAILABLE_TOOLS][INST]Bye[/INST]'));
    });

    test('Renders Mistral Small 24B', () {
      final templateName = 'Mistral-Small-3.2-24B-Instruct-2506.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);

      final data = {
        'bos_token': JinjaString.from('<s>', isSafe: true),
        'messages': [
          {'role': 'system', 'content': 'Sys'},
          {'role': 'user', 'content': 'Hello'},
        ],
      };
      // Uses [INST] format
      final output = template.render(data);
      expect(output, contains('<s>[SYSTEM_PROMPT]Sys[/SYSTEM_PROMPT]'));
      expect(output, contains('[INST]Hello[/INST]'));
    });

    test('Renders Mistral Small 24B with tool calls', () {
      final templateName = 'Mistral-Small-3.2-24B-Instruct-2506.jinja';
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
        'bos_token': JinjaString.from('<s>', isSafe: true),
        'eos_token': JinjaString.from('</s>', isSafe: true),
        'tools': tools,
        'messages': [
          {'role': 'user', 'content': 'Call tool'},
          {
            'role': 'assistant',
            'tool_calls': [
              {
                'id': '123456789', // Must be 9 chars
                'type': 'function',
                'function': {'name': 'my_tool', 'arguments': {}},
              },
            ],
          },
          {
            'role': 'tool',
            'tool_call_id': '123456789',
            'content': 'Tool result',
          },
        ],
      };

      final output = template.render(data);
      expect(output, contains('[AVAILABLE_TOOLS]'));
      expect(output, contains('[TOOL_CALLS]my_tool[CALL_ID]123456789[ARGS]{}'));
      expect(
        output,
        contains(
          '[TOOL_RESULTS]123456789[TOOL_CONTENT]Tool result[/TOOL_RESULTS]',
        ),
      );
    });

    test('Renders Mistral Reasoning 14B', () {
      final templateName = 'mistralai-Ministral-3-14B-Reasoning-2512.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);

      final data = {
        'bos_token': JinjaString.from('<s>', isSafe: true),
        'messages': [
          {'role': 'system', 'content': 'System'},
          {'role': 'user', 'content': 'User'},
        ],
      };
      // Uses [SYSTEM_PROMPT] and [INST]
      final output = template.render(data);
      expect(output, contains('<s>[SYSTEM_PROMPT]System[/SYSTEM_PROMPT]'));
      expect(output, contains('[INST]User[/INST]'));
    });

    test('Renders Unsloth Mistral', () {
      final templateName = 'unsloth-mistral-Devstral-Small-2507.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);

      // Seems to be standard Mistral or ChatML-like?
      // Actually it's just Mistral v3 style
      final data = {
        'bos_token': JinjaString.from('<s>', isSafe: true),
        'messages': [
          {'role': 'system', 'content': 'Sys'},
          {'role': 'user', 'content': 'Hi'},
        ],
      };

      final output = template.render(data);
      expect(output, contains('<s>[SYSTEM_PROMPT]Sys[/SYSTEM_PROMPT]'));
      expect(output, contains('[INST]Hi[/INST]'));
    });

    test('Renders Nemotron', () {
      // Nemotron templates: NVIDIA-Nemotron-3-Nano-30B-A3B-BF16, NVIDIA-Nemotron-Nano-v2
      for (final templateName in [
        'NVIDIA-Nemotron-3-Nano-30B-A3B-BF16.jinja',
        'NVIDIA-Nemotron-Nano-v2.jinja',
      ]) {
        final source = File(
          'test/fixtures/templates/$templateName',
        ).readAsStringSync();
        final template = Template(source);

        final data = {
          'bos_token': JinjaString.from(
            '<bos>',
            isSafe: true,
          ), // Nemotron v2/3 use specific start tokens often
          'messages': [
            {'role': 'system', 'content': 'Sys'},
            {'role': 'user', 'content': 'User'},
            {'role': 'assistant', 'content': 'Asst'},
          ],
        };

        final output = template.render(data);
        // Check for common markers found in these files
        expect(output, contains('Sys'));
        expect(output, contains('User'));
        expect(output, contains('Asst'));
      }
    });
  });
}
