/// A Dart implementation of the Jinja templating language,
library;

/// ported from llama.cpp's minimal jinja implementation.
///
/// Focused on zero-dependency and input marking for security.

export 'src/parser.dart' show ParserException;
export 'src/template.dart';
export 'src/types/jinja_string.dart';
export 'src/types/value.dart';
