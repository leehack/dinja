# Dinja

A minimal, zero-dependency Jinja templating engine for Dart, ported from `llama.cpp`. Focused on security, efficiency, and input marking.

## Features

- **Zero-Dependency**: No external dependencies beyond the Dart SDK.
- **Security-First**: Built with specific "Input Marking" to prevent injection attacks when rendering user input.
- **Lightweight**: Ported from `llama.cpp`'s minimal Jinja implementation.
- **Chat Template Support**: Specifically designed to faithfully render the complex chat templates used in LLM inference (e.g., Mistral, Llama 3).

## Scope

This project is a **minimal** implementation of Jinja2. It does *not* support the full Jinja2 specification (e.g., custom tags, complex inheritance hierarchies, or filesystem loading are out of scope).

The primary goal is to support **LLM Chat Templates** and basic string rendering efficiently and securely in Dart.

## Security: Input Marking

Dinja uses a taint-tracking mechanism similar to `MarkupSafe` in Python but adapted for this specific use case.

- **`JinjaString`**: A wrapper around strings that tracks which parts come from the template (safe) and which come from user input (unsafe).
- **Automatic Escaping**: untrusted user input is automatically escaped when rendered, while template structure remains untouched.

```dart
final template = Template('Hello {{ name }}');
// "name" contains HTML/special chars
final result = template.render({'name': '<script>alert(1)</script>'});
// Output: Hello &lt;script&gt;alert(1)&lt;/script&gt;
```

## Getting started

Add `dinja` to your `pubspec.yaml`:

```yaml
dependencies:
  dinja: ^1.0.0
```

## Usage

### Simple Rendering

```dart
import 'package:dinja/dinja.dart';

void main() {
  final template = Template('Hello, {{ name }}!');
  final result = template.render({'name': 'World'});
  print(result); // Hello, World!
}
```

### Complex Templates

```dart
import 'package:dinja/dinja.dart';

void main() {
  final templateText = '''
{% for user in users %}
- {{ user.name }} ({{ user.role }})
{% endfor %}
''';
  final template = Template(templateText);
  final users = [
    {'name': 'Alice', 'role': 'Admin'},
    {'name': 'Bob', 'role': 'User'},
  ];
  final result = template.render({'users': users});
  print(result);
}
```

### Rendering Chat Templates

Dinja is optimized for rendering chat templates (like those found in `tokenizer_config.json` for HuggingFace models).

```dart
import 'package:dinja/dinja.dart';

void main() {
  // A simplified Mistral-like template
  final templateSrc = "{{ bos_token }}{% for m in messages %}[INST] {{ m['content'] }} [/INST]{% endfor %}";
  final template = Template(templateSrc);

  final output = template.render({
    'bos_token': '<s>',
    'messages': [
      {'role': 'user', 'content': 'Hello!'},
      {'role': 'user', 'content': 'What is the capital of France?'}
    ]
  });

  print(output);
  // Output: <s>[INST] Hello! [/INST][INST] What is the capital of France? [/INST]
}
```

## Additional information

This package is a direct port of the minimal Jinja implementation found in `llama.cpp`. It aims to provide the same functionality while adhering to Dart best practices.
