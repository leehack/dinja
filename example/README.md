# Dinja Examples

This directory contains examples of how to use the `dinja` package.

## Basic Usage

See `example.dart` for a minimal "Hello World" example.

```bash
dart example/example.dart
```

## Chat Templates

`chat_template_example.dart` demonstrates how to render a complex chat template (like those used for Llama 3 or Mistral) with logic, loops, and special tokens.

```bash
dart example/chat_template_example.dart
```

## Security & Escaping

`security_example.dart` shows that plain strings are not escaped, that values wrapped in `JinjaString.user` are, and how to mark user input as safe.

```bash
dart example/security_example.dart
```
