## 1.1.0

- Added `package:dinja/ast.dart` for template analysis without importing `src/`: `parseTemplate`, which parses a template into a `Program`; the AST node types; and `LexerException` and `ParserException`. `package:dinja/dinja.dart` is unchanged.
- Fixed string equality to compare content only: `''.strip() == ''` is now true, and `safe` or input-marked strings equal plain ones.
- Removed a debug `print` to stdout when a `for` loop iterates a function; the error now names the function.
- Fixed tests with one unparenthesized argument, such as `1 is eq 1` and `'a' is in ['a']`, which failed to parse. As in Jinja2, a value after a test without a comma is now its argument: `[x is odd 1]` means `[x is odd(1)]`.
- Fixed `unique` to compare items with Python equality: `[1, '1']` keeps both, `[1, 1.0, true]` keeps one. It now ignores string case by default, as Jinja2 does.
- Fixed a `ParserException` at the end of the template reporting position `-1`; it now reports the end of the template.
- Fixed an incomplete expression at the end of the template, such as `{{ 1 +`, throwing `RangeError` instead of `ParserException`.
- Fixed `ParserException` from `Template` on templates with `\r\n` or a trailing newline: its `source`, `pos`, `line` and `col` now all refer to the normalized text, as with `parseTemplate`.
- Changed `unique` to follow Jinja2's signature, `unique(case_sensitive=false, attribute=none)`: the first positional argument is now `case_sensitive`, not `attribute`. `unique` now also deduplicates the characters of a string and the keys of a dict.
- Fixed input marking being dropped by `~`, string repetition (`*`), `replace`, `capitalize`, `title`, `string`, `indent` and the last piece of `split` (first of `rsplit`), matching llama.cpp. Input-marked text from these is now escaped on output like `{{ value }}`. `join` still drops the marking, as in llama.cpp.
- Fixed double escaping when an escaped block, such as a `{% set %}` block or macro output, is joined with `+` to plain text.

## 1.0.0

- Initial release of Dinja.
- Minimal Jinja2 implementation ported from llama.cpp.
- Support for LLM chat templates.
- Secure input marking system.
- Fixed unused declaration in `nodes.dart`.
- Fixed `not in` operator logic for Maps.
- Fixed duplicate key in `builtins.dart`.
- Added cross-compatibility generation script (`script/generate_cross_test.py`).
