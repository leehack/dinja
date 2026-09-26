import 'jinja_string.dart';
import 'repr.dart';
import 'value.dart';

/// Whether [s] has input-marked text that is escaped on output.
bool hasRawInput(JinjaString s) => !s.isSafe && s.parts.any((p) => p.isInput);

/// [s] as unescaped text. The text of a safe string is final, so its
/// input-marked parts become template text.
JinjaString rawOf(JinjaString s) {
  if (!s.isSafe) return s;
  return JinjaString([
    for (final p in s.parts) p.isInput ? JinjaStringPart(p.val, false) : p,
  ]);
}

/// The string form of [v] that keeps the input marking of the strings in it:
/// a string itself, a list, tuple or dict as [reprOf], anything else as
/// template text.
JinjaString stringOf(JinjaValue v) {
  if (v is JinjaStringValue) return v.value;
  if (v is JinjaList || v is JinjaTuple || v is JinjaMap) return reprOf(v);
  return JinjaString.template(v.toString());
}

/// Joins [pieces] as unescaped text.
///
/// Without input-marked text the result is one template part, as a plain
/// string is; otherwise each character keeps the marking of its piece.
JinjaString joinRaw(Iterable<JinjaString> pieces) {
  final parts = <JinjaStringPart>[];
  for (final part in [for (final piece in pieces) ...rawOf(piece).parts]) {
    if (part.val.isEmpty) continue;
    if (parts.isNotEmpty && parts.last.isInput == part.isInput) {
      parts.last = JinjaStringPart(parts.last.val + part.val, part.isInput);
    } else {
      parts.add(part);
    }
  }
  if (!parts.any((p) => p.isInput)) {
    return JinjaString.template(parts.map((p) => p.val).join());
  }
  return JinjaString(parts);
}

/// The characters of [s], each keeping its input marking.
List<JinjaValue> charsOf(JinjaString s) => [
  for (final p in rawOf(s).parts)
    for (final c in p.val.split(''))
      JinjaStringValue(JinjaString([JinjaStringPart(c, p.isInput)])),
];
