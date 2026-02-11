import 'dart:io';
import 'package:test/test.dart';
import 'package:dinja/dinja.dart';

void main() {
  group('Gemma Template Tests', () {
    test('Renders Gemma 3 with raise_exception and loop checks', () {
      final templateName = 'gemma-3-4b-it.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);

      final data = {
        'bos_token': JinjaString.from('<bos>', isSafe: true),
        'messages': [
          {'role': 'user', 'content': 'Hello'},
          {'role': 'assistant', 'content': 'Hi'},
        ],
        'add_generation_prompt': true,
      };

      final output = template.render(data);
      expect(output, contains('<bos>'));
      expect(output, contains('<start_of_turn>user\nHello<end_of_turn>'));
      expect(output, contains('<start_of_turn>model\nHi<end_of_turn>'));
      expect(output, contains('<start_of_turn>model'));
    });

    test('Gemma 3 raises exception on invalid role order', () {
      final templateName = 'gemma-3-4b-it.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);

      final data = {
        'bos_token': JinjaString.from('<bos>', isSafe: true),
        'messages': [
          {'role': 'user', 'content': 'Hello'},
          {'role': 'user', 'content': 'User again?!'},
        ],
      };

      expect(
        () => template.render(data),
        throwsException,
      ); // conversation roles must alternate
    });

    test('Renders FunctionGemma w/ macros and recursion', () {
      final templateName = 'functiongemma-270m-it.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);

      // Complex tool definition for macro testing
      final data = {
        'bos_token': JinjaString.from('<bos>', isSafe: true),
        'tools': [
          {
            'function': {
              'name': 'get_weather',
              'description': 'Description',
              'parameters': {
                'type': 'object',
                'properties': {
                  'loc': {'type': 'string', 'description': 'Location'},
                },
                'required': ['loc'],
              },
            },
          },
        ],
        'messages': [
          {'role': 'user', 'content': 'Weather in London?'},
          {
            'role': 'assistant',
            'tool_calls': [
              {
                'function': {
                  'name': 'get_weather',
                  'arguments': {'loc': 'London'},
                },
              },
            ],
          },
        ],
      };

      final output = template.render(data);
      expect(output, contains('<start_function_declaration>'));
      expect(output, contains('declaration:get_weather'));
      expect(
        output,
        contains(
          'properties:{loc:{description:<escape>Location<escape>,type:<escape>STRING<escape>}}',
        ),
      );
      expect(
        output,
        contains(
          '<start_function_call>call:get_weather{loc:<escape>London<escape>}',
        ),
      );
    });

    test('Renders Gemma-3n with content blocks', () {
      final templateName = 'gemma-3n-E4B-it.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);

      final data = {
        'bos_token': JinjaString.from('<bos>', isSafe: true),
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'Hello'},
              {'type': 'image'},
            ],
          },
          {'role': 'assistant', 'content': 'World'},
        ],
      };

      final output = template.render(data);
      expect(output, contains('<start_of_turn>user\nHello'));
      expect(output, contains('<image_soft_token>'));
      expect(output, contains('<start_of_turn>model\nWorld'));
    });
  });
}
