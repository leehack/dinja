## Unreleased

- Added `package:dinja/ast.dart` for template analysis without importing `src/`: `parseTemplate`, which parses a template into a `Program`; the AST node types; and `LexerException` and `ParserException`. `package:dinja/dinja.dart` is unchanged.
- Fixed string equality to compare content only: `''.strip() == ''` is now true, and `safe` or input-marked strings equal plain ones.
- Removed a debug `print` to stdout when a `for` loop iterates a function; the error now names the function.

## 1.0.0

- Initial release of Dinja.
- Minimal Jinja2 implementation ported from llama.cpp.
- Support for LLM chat templates.
- Secure input marking system.
- Fixed unused declaration in `nodes.dart`.
- Fixed `not in` operator logic for Maps.
- Fixed duplicate key in `builtins.dart`.
- Added cross-compatibility generation script (`script/generate_cross_test.py`).
