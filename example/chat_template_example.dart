import 'package:dinja/dinja.dart';

// A trimmed Qwen2.5-style ChatML template.
const chatTemplate = r'''
{%- if tools %}
    {{- '<|im_start|>system\n' + messages[0].content + '\n\n# Tools\n\n<tools>' }}
    {%- for tool in tools %}
        {{- '\n' + tool | tojson }}
    {%- endfor %}
    {{- '\n</tools><|im_end|>\n' }}
{%- else %}
    {{- '<|im_start|>system\n' + messages[0].content + '<|im_end|>\n' }}
{%- endif %}
{%- for message in messages[1:] %}
    {{- '<|im_start|>' + message.role + '\n' + message.content + '<|im_end|>\n' }}
{%- endfor %}
{%- if add_generation_prompt %}
    {{- '<|im_start|>assistant\n' }}
{%- endif %}
''';

void main() {
  final prompt = Template(chatTemplate).render({
    'messages': [
      {'role': 'system', 'content': 'You are a helpful assistant.'},
      {'role': 'user', 'content': 'What is the weather in Paris?'},
    ],
    'tools': [
      {
        'type': 'function',
        'function': {
          'name': 'get_weather',
          'parameters': {
            'type': 'object',
            'properties': {
              'city': {'type': 'string'},
            },
          },
        },
      },
    ],
    'add_generation_prompt': true,
  });
  print(prompt);
}
