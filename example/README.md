# dinja examples

## Render a chat template

[`chat_template_example.dart`](chat_template_example.dart) renders a trimmed Qwen2.5-style chat template with a system message, a user turn, a tool definition and `add_generation_prompt`.

```dart
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
```

`dart run example/chat_template_example.dart` prints the prompt:

```text
<|im_start|>system
You are a helpful assistant.

# Tools

<tools>
{"type": "function", "function": {"name": "get_weather", "parameters": {"type": "object", "properties": {"city": {"type": "string"}}}}}
</tools><|im_end|>
<|im_start|>user
What is the weather in Paris?<|im_end|>
<|im_start|>assistant

```

## More examples

- [`example.dart`](example.dart): the smallest render. `dart run example/example.dart` prints `Hello World!`.
- [`security_example.dart`](security_example.dart): a plain string is not escaped, a `JinjaString.user` value is, and `markSafe()` turns escaping off. Run it with `dart run example/security_example.dart`.
