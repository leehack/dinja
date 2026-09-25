import 'jinja_string.dart';
import 'value.dart';

/// Escapes [s] for the inside of a JSON string, as llama.cpp's
/// `value_to_json` does: only `"`, `\` and control characters, plus every
/// non-ASCII code unit when [ensureAscii] is true.
String jsonEscape(String s, {bool ensureAscii = false}) {
  final out = StringBuffer();
  for (final c in s.codeUnits) {
    switch (c) {
      case 0x22:
        out.write(r'\"');
      case 0x5c:
        out.write(r'\\');
      case 0x08:
        out.write(r'\b');
      case 0x0c:
        out.write(r'\f');
      case 0x0a:
        out.write(r'\n');
      case 0x0d:
        out.write(r'\r');
      case 0x09:
        out.write(r'\t');
      default:
        if (c < 0x20 || (ensureAscii && c > 0x7f)) {
          out.write('\\u${c.toRadixString(16).padLeft(4, '0')}');
        } else {
          out.writeCharCode(c);
        }
    }
  }
  return out.toString();
}

/// Converts [value] to its llama.cpp string form, where strings are quoted
/// as list and dict items are.
///
/// A string item keeps its input marking unless it is safe, so printing a
/// list escapes its input-marked items but not its quotes.
JinjaString reprOf(JinjaValue value) {
  final parts = <JinjaStringPart>[];
  _writeRepr(parts, value);
  return JinjaString(parts);
}

void _writeRepr(List<JinjaStringPart> parts, JinjaValue v) {
  void add(String s) => parts.add(JinjaStringPart(s, false));
  void addItems(List<JinjaValue> items) {
    for (var i = 0; i < items.length; i++) {
      if (i > 0) add(', ');
      _writeRepr(parts, items[i]);
    }
  }

  if (v is JinjaStringValue) {
    final s = v.value;
    final json = s.toString().contains("'");
    final quote = json ? '"' : "'";
    add(quote);
    for (final p in s.parts) {
      parts.add(
        JinjaStringPart(
          json ? jsonEscape(p.val) : p.val,
          p.isInput && !s.isSafe,
        ),
      );
    }
    add(quote);
  } else if (v is JinjaList) {
    add('[');
    addItems(v.items);
    add(']');
  } else if (v is JinjaTuple) {
    add('(');
    addItems(v.items);
    add(')');
  } else if (v is JinjaMap) {
    add('{');
    var first = true;
    for (final e in v.items.entries) {
      if (!first) add(', ');
      first = false;
      _writeRepr(parts, e.key);
      add(': ');
      _writeRepr(parts, e.value);
    }
    add('}');
  } else {
    add(v.asRepr);
  }
}
