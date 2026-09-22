## Unreleased

- Added `package:dinja/ast.dart`, exposing the lexer, parser and AST node types so template analysis can reach them without importing `src/`. `package:dinja/dinja.dart` is unchanged.

## 1.0.0

- Initial release of Dinja.
- Minimal Jinja2 implementation ported from llama.cpp.
- Support for LLM chat templates.
- Secure input marking system.
- Fixed unused declaration in `nodes.dart`.
- Fixed `not in` operator logic for Maps.
- Fixed duplicate key in `builtins.dart`.
- Added cross-compatibility generation script (`script/generate_cross_test.py`).
