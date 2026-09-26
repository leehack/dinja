[![pub package](https://img.shields.io/pub/v/dinja.svg)](https://pub.dev/packages/dinja)
[![pub points](https://img.shields.io/pub/points/dinja.svg)](https://pub.dev/packages/dinja/score)
[![Build Status](https://github.com/leehack/dinja/actions/workflows/dart.yml/badge.svg)](https://github.com/leehack/dinja/actions/workflows/dart.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/leehack/dinja/branch/main/graph/badge.svg)](https://codecov.io/gh/leehack/dinja)

# dinja

dinja renders LLM chat templates in Dart: give it a model's Jinja chat template and a conversation, and it returns the prompt string. It is a port of llama.cpp's `common/jinja` engine.

```bash
dart pub add dinja
```

## Render a chat template

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

Output, identical to what llama.cpp and Python Jinja2 render:

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

Real templates come from the `chat_template` field of a model's `tokenizer_config.json` on huggingface.co, or from the `tokenizer.chat_template` key in GGUF metadata. Pass that string to `Template` unchanged.

## Why dinja

- **llama.cpp parity.** dinja follows `common/jinja`, the engine llama-server renders chat templates with. llama.cpp's Jinja test suite, 290 cases whose expected output also matches Python Jinja2 3.1.6, is ported case for case: dinja matches all 279 cases that llama.cpp runs byte for byte. The other 11 are cases llama.cpp skips as not implemented.
- **Real templates.** The tests parse and render 45 distinct chat templates from real models, including Llama 3.x, Qwen2.5, Qwen3, Mistral, Gemma, DeepSeek R1, Phi, gpt-oss, Kimi K2 and GLM. With these and the templates in llama.cpp's `models/templates`, 86 distinct in all, dinja gives the same output as llama.cpp 7fe450e1 byte for byte, or raises the same template error, in four conversations: system prompt with tools, user only, multi-turn, and a tool call with its result.
- **Input marking.** Values wrapped in `JinjaString.user` are escaped on output, and `renderJinjaResult` reports which parts of the output came from input.
- **Web and Wasm.** Pure Dart, depending only on `meta`. The parser, runtime and llama.cpp tests also pass in Chrome, compiled to JavaScript and to Wasm.
- **Used by [llamadart](https://pub.dev/packages/llamadart)**, a llama.cpp runtime for Dart and Flutter, to render chat templates.

## Input marking

Wrap untrusted values in `JinjaString.user`. They are escaped when rendered; a plain `String` is treated as template text and is not.

Input text keeps its marking through filters, `~`, loops, macros and `{% set %}` and `{% filter %}` blocks, and is escaped once, when the template outputs it. So a filter sees it as it was passed in: `{% filter length %}{{ name }}{% endfilter %}` counts the characters of `name`, not of its escaped form. `tojson` and `join` escape only the input text in their output, not the JSON's quotes or the template's separator. `| safe` and `markSafe()` turn escaping off.

```dart
import 'package:dinja/dinja.dart';

void main() {
  final template = Template('Hello {{ name }}');
  const html = '<script>alert(1)</script>';
  print(template.render({'name': JinjaString.user(html)}));
  print(template.render({'name': html}));

  final result = template.renderJinjaResult({'name': JinjaString.user('Bob')});
  print(result.parts.where((part) => part.isInput).map((part) => part.val));
}
```

```text
Hello &lt;script&gt;alert(1)&lt;/script&gt;
Hello <script>alert(1)</script>
(Bob)
```

## Analyzing templates

`package:dinja/ast.dart` parses a template into an AST without rendering it, for tools that inspect templates, for example to detect which features a chat template uses.

```dart
import 'package:dinja/ast.dart';

void main() {
  final program = parseTemplate(
    '{% if tools %}{{ tools | length }}{% endif %}',
  );
  for (final statement in program.body) {
    print(statement.type);
  }
}
```

```text
If
```

## dinja and package:jinja

[jinja](https://pub.dev/packages/jinja) ports Jinja as a general-purpose, server-side template engine with template inheritance. dinja targets LLM chat templates: it tracks llama.cpp's engine and output, adds input marking, and leaves out inheritance and template loading.

## Scope

dinja implements the Jinja that chat templates use, not all of Jinja2:

- A template is a single string: `extends`, `block`, `include`, `import`, `raw` and `with` throw a `ParserException`.
- Plain strings are never escaped; only `JinjaString.user` values are.
- Some Jinja2 features llama.cpp lacks are missing here too; for example, `'%s'|format(x)` returns `%s`.
- `strftime_now` formats the system clock's current time in the local time zone, as C `strftime` does in llama.cpp. `%Z` is Dart's `DateTime.timeZoneName`, whose format depends on the platform: on the web it is the browser's name for the zone, such as `Eastern Daylight Time` where llama.cpp gives `EDT`.
