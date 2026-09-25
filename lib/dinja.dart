/// A Jinja engine for LLM chat templates, ported from llama.cpp's
/// `common/jinja`.
///
/// Values wrapped in [JinjaString.user] are marked as input and escaped when
/// rendered.
library;

export 'src/parser.dart' show ParserException;
export 'src/template.dart';
export 'src/types/jinja_string.dart';
export 'src/types/value.dart';
