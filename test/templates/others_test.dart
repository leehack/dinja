import 'dart:io';
import 'package:test/test.dart';
import 'package:dinja/dinja.dart';

void main() {
  group('Other Templates Tests', () {
    test('Renders Apertus', () {
      final templateName = 'Apertus-8B-Instruct.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);
      final output = template.render({
        'messages': [
          {'role': 'user', 'content': 'Hi'},
        ],
      });
      expect(output, contains('Hi'));
    });

    test('Renders ByteDance Seed', () {
      final templateName = 'ByteDance-Seed-OSS.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);
      final output = template.render({
        'messages': [
          {'role': 'user', 'content': 'Hi'},
        ],
      });
      expect(output, contains('Hi'));
    });

    test('Renders Granite 3.3 with tools and documents', () {
      final templateName = 'ibm-granite-granite-3.3-2B-Instruct.jinja';
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
      final documents = [
        {'doc_id': '1', 'text': 'Doc content'},
      ];

      final output = template.render({
        'messages': [
          {'role': 'user', 'content': 'Hi'},
        ],
        'tools': tools, // Will match available_tools logic
        'documents': documents,
        'add_generation_prompt': true,
      });

      expect(
        output,
        contains('<|start_of_role|>available_tools<|end_of_role|>'),
      );
      expect(output, contains('my_tool'));
      expect(
        output,
        contains(
          '<|start_of_role|>document {"document_id": "1"}<|end_of_role|>',
        ),
      );
      expect(output, contains('Doc content'));
      expect(output, contains('<|start_of_role|>assistant<|end_of_role|>'));
    });

    test('Renders Kimi Variants', () {
      // Kimi-K2-Instruct.jinja
      // Kimi-K2-Thinking.jinja
      // moonshotai-Kimi-K2.jinja
      for (final templateName in [
        'Kimi-K2-Instruct.jinja',
        'Kimi-K2-Thinking.jinja',
        'moonshotai-Kimi-K2.jinja',
      ]) {
        final source = File(
          'test/fixtures/templates/$templateName',
        ).readAsStringSync();
        final template = Template(source);
        final output = template.render({
          'messages': [
            {'role': 'user', 'content': 'Hi'},
          ],
          'bos_token': JinjaString.from('<s>', isSafe: true),
        });
        expect(output, contains('Hi'));
      }
    });

    test('Renders LFM2 (original)', () {
      final templateName = 'llama-cpp-lfm2.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);
      final output = template.render({
        'messages': [
          {'role': 'user', 'content': 'Hi'},
        ],
      });
      expect(output, contains('Hi'));
    });

    test('Renders RWKV World', () {
      final templateName = 'llama-cpp-rwkv-world.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);
      final output = template.render({
        'messages': [
          {'role': 'user', 'content': 'Hi'},
        ],
      });
      expect(output, contains('Hi'));
    });

    test('Renders Functionary v3.1', () {
      final templateName = 'meetkai-functionary-medium-v3.1.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);
      final output = template.render({
        'messages': [
          {'role': 'user', 'content': 'Hi'},
        ],
      });
      expect(output, contains('Hi'));
    });

    test('Renders Phi 3.5 Mini', () {
      final templateName = 'microsoft-Phi-3.5-mini-instruct.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);
      final output = template.render({
        'messages': [
          {'role': 'user', 'content': 'Hi'},
        ],
      });
      expect(output, contains('Hi'));
    });

    test('Renders MiMo VL', () {
      final templateName = 'MiMo-VL.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);
      final output = template.render({
        'messages': [
          {'role': 'user', 'content': 'Hi'},
        ],
      });
      expect(output, contains('Hi'));
    });

    test('Renders MiniMax M2 with tools', () {
      final templateName = 'MiniMax-M2.jinja';
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

      final output = template.render({
        'messages': [
          {'role': 'user', 'content': 'Call tool'},
          {
            'role': 'assistant',
            'tool_calls': [
              {
                'function': {
                  'name': 'my_tool',
                  'arguments': {'x': 1},
                },
              },
            ],
          },
        ],
        'tools': tools,
      });

      // MiniMax uses <invoke>
      expect(output, contains('<tools>'));
      expect(output, contains('<invoke name="my_tool">'));
      expect(output, contains('<parameter name="x">1</parameter>'));
      expect(output, contains('</invoke>'));
    });

    test('Renders OpenAI GPT OSS', () {
      final templateName = 'openai-gpt-oss-120b.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);
      final output = template.render({
        'messages': [
          {'role': 'user', 'content': 'Hi'},
        ],
      });
      expect(output, contains('Hi'));
    });

    test('Renders Unsloth Apriel', () {
      final templateName = 'unsloth-Apriel-1.5.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);
      final output = template.render({
        'messages': [
          {'role': 'user', 'content': 'Hi'},
        ],
      });
      expect(output, contains('Hi'));
    });

    test('Renders Solar 100B with tools', () {
      final templateName = 'upstage-Solar-Open-100B.jinja';
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

      final output = template.render({
        'messages': [
          {'role': 'user', 'content': 'Call'},
          {
            'role': 'assistant',
            'tool_calls': [
              {
                'id': 'a1b2c3d4e5',
                'function': {'name': 'my_tool', 'arguments': {}},
              },
            ],
          },
        ],
        'tools': tools,
        'default_system_prompt': true,
      });

      expect(
        output,
        contains('## Provider System Prompt'),
      ); // Default verification
      expect(output, contains('<|tools:begin|>'));
      expect(
        output,
        contains('<|tool_call:begin|>a1b2c3d4e5<|tool_call:name|>my_tool'),
      );
    });

    test('Renders GLM 4.6 with tools and thinking', () {
      final templateName = 'GLM-4.6.jinja';
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

      final output = template.render({
        'messages': [
          {'role': 'user', 'content': 'Call'},
          {
            'role': 'assistant',
            'content': JinjaString.from('<think>Reasons</think>'),
            'tool_calls': [
              {
                'function': {
                  'name': 'my_tool',
                  'arguments': {'k': 'v'},
                },
              },
            ],
          },
        ],
        'tools': tools,
        'enable_thinking': true,
      });

      expect(output, contains('<tools>'));
      expect(output, contains('<think>Reasons</think>'));
      expect(output, contains('<tool_call>my_tool'));
      expect(output, contains('<arg_key>k</arg_key>'));
      expect(output, contains('<arg_value>v</arg_value>'));
    });

    test('Renders Gemma 2', () {
      final templateName = 'google-gemma-2-2b-it.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);
      final output = template.render({
        'messages': [
          {'role': 'user', 'content': 'Hi'},
        ],
        'bos_token': JinjaString.from('<bos>', isSafe: true),
      });
      expect(output, contains('Hi'));
    });

    test('Renders Cohere 7B', () {
      final templateName =
          'CohereForAI-c4ai-command-r7b-12-2024-tool_use.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);
      final output = template.render({
        'messages': [
          {'role': 'user', 'content': 'Hi'},
        ],
        'bos_token': JinjaString.from('<BOS>', isSafe: true),
      });
      expect(output, contains('Hi'));
    });
  });
}
