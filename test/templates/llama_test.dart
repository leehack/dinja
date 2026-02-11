import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:dinja/dinja.dart';

void main() {
  group('Llama Template Tests', () {
    test('Renders Llama-3.2 with sample data', () {
      final templateName = 'Llama-3_2-3B-Instruct.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);

      final data = {
        'bos_token': JinjaString.from('<|begin_of_text|>', isSafe: true),
        'date_string': '26 Jul 2024',
        'tools_in_user_message': false,
        'messages': [
          {'role': 'system', 'content': 'You are a helpful assistant.'},
          {'role': 'user', 'content': 'What is the weather?'},
        ],
        'tools': [
          {
            'type': 'function',
            'function': {
              'name': 'get_weather',
              'description': 'Get current weather',
              'parameters': {
                'type': 'object',
                'properties': {
                  'location': {'type': 'string'},
                },
                'required': ['location'],
              },
            },
          },
        ],
      };

      final output = template.render(data);
      expect(output, contains('<|start_header_id|>system<|end_header_id|>'));
      expect(output, contains('You are a helpful assistant.'));
      expect(output, contains('You have access to the following functions'));
      expect(output, contains('get_weather'));
    });

    test('Renders Llama-3.2 with tools in user message', () {
      final templateName = 'Llama-3_2-3B-Instruct.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);

      final data = {
        'bos_token': JinjaString.from('<|begin_of_text|>', isSafe: true),
        'date_string': '26 Jul 2024',
        'tools_in_user_message': true, // Enable this path
        'messages': [
          {'role': 'system', 'content': 'System'},
          {'role': 'user', 'content': 'User query'},
        ],
        'tools': [
          {
            'type': 'function',
            'function': {
              'name': 'my_tool',
              'description': 'desc',
              'parameters': {},
            },
          },
        ],
      };

      final output = template.render(data);
      expect(output, contains('<|start_header_id|>system<|end_header_id|>'));
      // When tools are in user message, system prompt should NOT contain tool definitions
      expect(
        output,
        isNot(contains('You have access to the following functions')),
      );

      expect(output, contains('<|start_header_id|>user<|end_header_id|>'));
      // Tool definitions should be here
      expect(output, contains('Given the following functions'));
      expect(output, contains('my_tool'));
      expect(output, contains('User query'));
    });

    test('Renders Llama-3.1-8B and 3.3-70B with tool definitions', () {
      // Logic is identical for 3.1 and 3.3
      for (final templateName in [
        'meta-llama-Llama-3.1-8B-Instruct.jinja',
        'meta-llama-Llama-3.3-70B-Instruct.jinja',
      ]) {
        final source = File(
          'test/fixtures/templates/$templateName',
        ).readAsStringSync();
        final template = Template(source);

        final data = {
          'bos_token': JinjaString.from('<|begin_of_text|>', isSafe: true),
          'tools_in_user_message': false,
          'messages': [
            {'role': 'user', 'content': 'Hello'},
          ],
          'tools': [
            {
              'type': 'function',
              'function': {
                'name': 'tool_name',
                'description': 'desc',
                'parameters': {'type': 'object', 'properties': {}},
              },
            },
          ],
        };

        final output = template.render(data);
        expect(output, contains('<|start_header_id|>system<|end_header_id|>'));
        expect(output, contains('tool_name'));
        expect(
          output,
          contains('<|start_header_id|>user<|end_header_id|>\n\nHello'),
        );
      }
    });

    test('Renders Hermes 2 Pro & 3 Tool Use', () {
      // Hermes templates expect specific tool format
      // They use <tool_code> blocks
      for (final templateName in [
        'NousResearch-Hermes-2-Pro-Llama-3-8B-tool_use.jinja',
        'NousResearch-Hermes-3-Llama-3.1-8B-tool_use.jinja',
      ]) {
        final source = File(
          'test/fixtures/templates/$templateName',
        ).readAsStringSync();
        final template = Template(source);

        final data = {
          'bos_token': JinjaString.from('<|begin_of_text|>', isSafe: true),
          'tools': [
            {
              'type': 'function',
              'function': {
                'name': 'search',
                'description': 'Search web',
                'parameters': {
                  'type': 'object',
                  'properties': {
                    'query': {'type': 'string'},
                  },
                  'required': ['query'],
                },
              },
            },
          ],
          'messages': [
            {'role': 'user', 'content': 'Search for apples'},
          ],
        };

        final output = template.render(data);
        expect(output, contains('<|im_start|>system'));
        expect(output, contains('You are a function calling AI model'));
        expect(output, contains('<tools>'));
        expect(output, contains('"name": "search"'));
        expect(output, contains('<|im_start|>user\nSearch for apples'));
      }
    });

    test('Renders Firefunction v2', () {
      final templateName = 'fireworks-ai-llama-3-firefunction-v2.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);

      final tools = [
        {
          'type': 'function',
          'function': {
            'name': 'my_func',
            'description': 'desc',
            'parameters': {},
          },
        },
      ];

      final data = {
        'bos_token': JinjaString.from('<|begin_of_text|>', isSafe: true),
        'messages': [
          {'role': 'user', 'content': 'Call function'},
        ],
        'tools': tools,
        'functions': jsonEncode(tools),
        'datetime': '2024-01-01',
      };

      final output = template.render(data);
      expect(output, contains('<|start_header_id|>system<|end_header_id|>'));
      // Firefunction injects specific system prompt about functions
      expect(
        output,
        contains('You are a helpful assistant with access to functions.'),
      );
      expect(output, contains('my_func'));
    });

    test('Renders Firefunction v2 with assistant tool calls', () {
      final templateName = 'fireworks-ai-llama-3-firefunction-v2.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);

      final tools = [
        {
          'type': 'function',
          'function': {
            'name': 'my_func',
            'description': 'desc',
            'parameters': {},
          },
        },
      ];

      final data = {
        'bos_token': JinjaString.from('<|begin_of_text|>', isSafe: true),
        'messages': [
          {'role': 'user', 'content': 'Call function'},
          // Assistant message making a tool call
          {
            'role': 'assistant',
            'tool_calls': [
              {
                'type': 'function',
                'function': {'name': 'my_func', 'arguments': '{"a": 1}'},
              },
            ],
          },
        ],
        'tools': tools,
        'functions': jsonEncode(tools),
        'datetime': '2024-01-01',
      };

      final output = template.render(data);
      expect(output, contains('<|start_header_id|>assistant<|end_header_id|>'));
      // Check for functools marker
      expect(output, contains('functools['));
      expect(output, contains('"name": "my_func"'));
      expect(output, contains('"arguments": {"a": 1}'));
    });
  });
}
