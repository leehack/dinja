import 'dart:io';
import 'package:test/test.dart';
import 'package:dinja/dinja.dart';

void main() {
  group('Functionary Template Tests', () {
    test('Renders Functionary v3.2 with typescript generation', () {
      final templateName = 'meetkai-functionary-medium-v3.2.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);

      final data = {
        'bos_token': JinjaString.from('<|begin_of_text|>', isSafe: true),
        'add_generation_prompt': true,
        'tools': [
          {
            'type': 'function',
            'function': {
              'name': 'get_weather',
              'description': 'Get weather',
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
        'messages': [
          {'role': 'user', 'content': 'London'},
        ],
      };

      final output = template.render(data);
      expect(
        output,
        contains('<|begin_of_text|><|start_header_id|>system<|end_header_id|>'),
      );
      expect(output, contains('namespace functions {'));
      expect(output, contains('type get_weather = (_: {'));
      expect(output, contains('location: string,'));
      expect(output, contains('}) => any;'));
      expect(
        output,
        contains(
          '<|start_header_id|>user<|end_header_id|>\n\nLondon<|eot_id|>',
        ),
      );
      expect(
        output,
        contains('<|start_header_id|>assistant<|end_header_id|>\n\n>>>'),
      );
    });

    test('Renders Functionary v3.1 with tool calls', () {
      final templateName = 'meetkai-functionary-medium-v3.1.jinja';
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
                  'arguments': JinjaString.from('{"k":"v"}', isSafe: true),
                },
              },
            ],
          },
        ],
        'tools': tools,
      });

      // Check for v3.1 specific format
      expect(output, contains('Use the function \'my_tool\''));
      expect(output, contains('<function=my_tool>{"k":"v"}</function>'));
    });
  });
}
