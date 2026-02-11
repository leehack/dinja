import 'dart:io';
import 'package:test/test.dart';
import 'package:dinja/dinja.dart';

void main() {
  group('LFM Template Tests', () {
    test('Renders LFM2.5 with thinking stripping and system prompt extraction', () {
      final templateName = 'LFM2_5-1_2B-Thinking.jinja';
      final source = File(
        'test/fixtures/templates/$templateName',
      ).readAsStringSync();
      final template = Template(source);

      // define tools to check system prompt injection
      final data = {
        'bos_token': JinjaString.from('<|bos|>', isSafe: true),
        'messages': [
          {'role': 'system', 'content': 'Sys'},
          {'role': 'user', 'content': 'Q'},
          // Past assistant message with thinking
          {
            'role': 'assistant',
            'content': '<think>Past thought</think>Past ans',
          },
          {'role': 'user', 'content': 'Q2'},
        ],
        'tools': ['tool1', 'tool2'], // Simple string tools for test
        'add_generation_prompt': true,
        'keep_past_thinking': false,
      };

      final output = template.render(data);

      // System prompt + tools
      expect(
        output,
        contains(
          '<|im_start|>system\nSys\nList of tools: [tool1, tool2]<|im_end|>',
        ),
      );

      // Past thinking should be stripped because it is not the last assistant message?
      // Wait, logic is: loop.index0 != ns.last_assistant_index.
      // Here last_assistant_index is -1 (init) then loop finds assistant at index 2.
      // So last_assistant_index = 2.
      // When rendering index 2: loop.index0 (2) == ns.last_assistant_index (2).
      // So logic `loop.index0 != ns.last_assistant_index` is FALSE.
      // Thus checking "not keep_past_thinking" AND FALSE -> FALSE.
      // So last message thinking is KEPT.

      // Let's add another assistant message to verify stripping of the FIRST one.
      final data2 = {
        'bos_token': JinjaString.from('<|bos|>', isSafe: true),
        'messages': [
          {'role': 'user', 'content': 'Q1'},
          {'role': 'assistant', 'content': '<think>Old thought</think>Old ans'},
          {'role': 'user', 'content': 'Q2'},
          {'role': 'assistant', 'content': '<think>New thought</think>New ans'},
        ],
        'keep_past_thinking': false,
      };

      final output2 = template.render(data2);
      expect(output2, contains('Old ans'));
      expect(output2, isNot(contains('Old thought'))); // Should be stripped
      expect(
        output2,
        contains('New thought'),
      ); // Should be kept (last assistant)
    });
  });
}
