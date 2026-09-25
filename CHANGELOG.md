## Unreleased

- Added `package:dinja/ast.dart` for template analysis without importing `src/`: `parseTemplate`, which parses a template into a `Program`; the AST node types; and `LexerException` and `ParserException`. `package:dinja/dinja.dart` is unchanged.
- Fixed string equality to compare content only: `''.strip() == ''` is now true, and `safe` or input-marked strings equal plain ones.
- Removed a debug `print` to stdout when a `for` loop iterates a function; the error now names the function.
- Fixed tests with one unparenthesized argument, such as `1 is eq 1` and `'a' is in ['a']`, which failed to parse. As in Jinja2, a value after a test without a comma is now its argument: `[x is odd 1]` means `[x is odd(1)]`.
- Fixed `unique` to compare items with Python equality: `[1, '1']` keeps both, `[1, 1.0, true]` keeps one. It now ignores string case by default, as Jinja2 does.
- Fixed a `ParserException` at the end of the template reporting position `-1`; it now reports the end of the template.

## 1.0.0

- Initial release of Dinja.
- Minimal Jinja2 implementation ported from llama.cpp.
- Support for LLM chat templates.
- Secure input marking system.
- Fixed unused declaration in `nodes.dart`.
- Fixed `not in` operator logic for Maps.
- Fixed duplicate key in `builtins.dart`.
- Added cross-compatibility generation script (`script/generate_cross_test.py`).
